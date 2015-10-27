/* ##################################################################
Roll up the task history from individual tasks to cumulative totals.

Apply current work breakdown to historical data.  VE has used both
project and projectcolumn to categorize work; this script condenses
both into a single new field called category. */
 
/* Between January 2015 and June 2015, planned VE work was tracked in
projects called "VisualEditor 2014/15 Q3 blockers" and
"VisualEditor 2014/15 Q4 blockers".   This query should get everything
from those projects. */

SELECT 've' as source,
       date,
       project as category,
       status,
       SUM(points) as points
  INTO tall_backlog
  FROM task_history
 WHERE project != 'VisualEditor'
 GROUP BY status, category, date;

/* Prior to 18 June 2015, VE work in the VisualEditor project was not
organized around the interrupt or maintenance, so all work in that
project prior to that date can be considered Uncategorized,
regardless of state or column.  The nested select is required to
accurately group by category, after category is forced to a constant
in the inner select. */

INSERT INTO tall_backlog (source, date, category, status, points) (
SELECT 've' as source,
       date,
       category,
       status,
       SUM(points) as points
  FROM (
SELECT date,
       CAST('Uncategorized' AS text) as category,
       status,
       points
  FROM ve_task_history
 WHERE project = 'VisualEditor'
   AND date < '2015-06-18') as ve_old_other
 GROUP BY status, category, date);

/* Since June 18, 2018, the projectcolumn in the VisualEditor project
should be accurate, so any VE task in a Tranche should use the tranche
as the category. */

INSERT INTO ve_tall_backlog (source, date, category, status, points) (
SELECT 've' as source,
       date,
       projectcolumn as category,
       status,
       SUM(points) as points
  FROM ve_task_history
 WHERE project = 'VisualEditor'
   AND projectcolumn SIMILAR TO 'TR%'
   AND date >= '2015-06-18'
GROUP BY status, category, date);

/* Any other tasks in the VisualEditor project (i.e., any task after
June 18th and not in a tranche) should be old data getting cleaned up.
We will essentially ignore them by placing them in Uncategorized.
*/

INSERT INTO ve_tall_backlog (source, date, category, status, points) (
SELECT 've' as source,
       date,
       category,
       status,
       SUM(points) as points
  FROM (
SELECT date,
       CAST('Uncategorized' AS text) as category,
       status,
       points
  FROM ve_task_history
 WHERE project = 'VisualEditor'
   AND projectcolumn NOT SIMILAR TO 'TR%'
   AND date >= '2015-06-18') AS ve_new_uncategorized
GROUP BY status, category, date);




COPY (
SELECT date,
       category,
       SUM(points) as points
  FROM tall_backlog
 WHERE category <> 'Uncategorized'
   AND category NOT SIMILAR TO 'TR0%'
   AND source = ':prefix'
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/phlog/backlog_zoomed.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(points) as points
  FROM tall_backlog
 WHERE status = '"resolved"'
   AND category NOT LIKE 'TR0%'
   AND category NOT LIKE 'Uncategorized'
   AND source = ':prefix'
 GROUP BY date
 ORDER BY date
) to '/tmp/phlog/burnup_zoomed.csv' DELIMITER ',' CSV HEADER;

/*SELECT * FROM find_recently_closed(:'prefix');

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
