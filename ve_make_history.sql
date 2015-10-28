UPDATE task_history
   SET status = '"open"'
 WHERE status = '"stalled"'
   AND source = :'prefix';

DELETE FROM task_history
 WHERE (status = '"duplicate"'
    OR status = '"invalid"'
    OR status = '"declined"')
   AND source = :'prefix';

/* ##################################################################
Apply current work breakdown to historical data.  VE has used both
project and projectcolumn to categorize work; this script condenses
both into a single new field called category. */
 
/* Between January 2015 and June 2015, planned VE work was tracked in
projects called "VisualEditor 2014/15 Q3 blockers" and
"VisualEditor 2014/15 Q4 blockers".   This query should get everything
from those projects. */

INSERT INTO tall_backlog (source, date, category, status, points, count)
SELECT source,
       date,
       project as category,
       status,
       SUM(points) as points,
       COUNT(title) as count
  FROM task_history
 WHERE project != 'VisualEditor'
   AND source = :'prefix'
 GROUP BY status, category, date;

/* Prior to 18 June 2015, VE work in the VisualEditor project was not
organized around the interrupt or maintenance, so all work in that
project prior to that date can be considered Uncategorized,
regardless of state or column.  The nested select is required to
accurately group by category, after category is forced to a constant
in the inner select. */

INSERT INTO tall_backlog (source, date, category, status, points, count) (
SELECT as source,
       date,
       category,
       status,
       SUM(points) as points,
       COUNT(title) as count
  FROM (
SELECT date,
       CAST('Uncategorized' AS text) as category,
       status,
       points,
       count
  FROM task_history
 WHERE project = 'VisualEditor'
   AND date < '2015-06-18') as ve_old_other
   AND source = :'prefix'
   GROUP BY status, category, date);

/* Since June 18, 2018, the projectcolumn in the VisualEditor project
should be accurate, so any VE task in a Tranche should use the tranche
as the category. */

INSERT INTO tall_backlog (source, date, category, status, points, count) (
SELECT source,
       date,
       projectcolumn as category,
       status,
       SUM(points) as points,
       COUNT(title) as count
  FROM task_history
 WHERE project = 'VisualEditor'
   AND projectcolumn SIMILAR TO 'TR%'
   AND source = :'prefix'
   AND date >= '2015-06-18'
GROUP BY status, category, date);

/* Any other tasks in the VisualEditor project (i.e., any task after
June 18th and not in a tranche) should be old data getting cleaned up.
We will essentially ignore them by placing them in Uncategorized.
*/

INSERT INTO tall_backlog (source, date, category, status, points, count) (
SELECT source,
       date,
       category,
       status,
       SUM(points) as points
       COUNT(title) as count
  FROM (
SELECT source,
       date,
       CAST('Uncategorized' AS text) as category,
       status,
       points
  FROM task_history
 WHERE project = 'VisualEditor'
   AND projectcolumn NOT SIMILAR TO 'TR%'
   AND source = :'prefix'
   AND date >= '2015-06-18') AS ve_new_uncategorized
GROUP BY status, category, date);


UPDATE tall_backlog
   SET maint_type = 'Maintenance'
 WHERE category = 'TR0: Interrupt'
   AND source = :'prefix';

UPDATE tall_backlog
   SET maint_type = 'New Functionality'
 WHERE category <> 'TR0: Interrupt'
   AND source = :'prefix';


/*
UPDATE recently_closed
   SET category = CASE WHEN category LIKE '%Q3%' THEN 'VE is usable and has acceptable performance'
                       WHEN category LIKE '%Q4%' THEN 'VE is more stable and A/B tested'
                       WHEN category LIKE '%TR1%' THEN 'VE defaults on for wp_en new users and IPs'
                       WHEN category LIKE '%TR2%' THEN 'Mobile MVP released'
                       WHEN category LIKE '%TR3%' THEN 'Language support defaults on for ja, ko, ar, fa, hi, zh_yue'
                       WHEN category LIKE '%TR4%' THEN 'Link Editor is better'
                       WHEN category LIKE '%TR5%' THEN 'Charts, formulae, sheet music, and media available or improved in VE'
                       ELSE 'Other'
                       END;
*/
