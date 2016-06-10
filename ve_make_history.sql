/* ##################################################################
Apply current work breakdown to historical data.  VE has used both
project and projectcolumn to categorize work; this script condenses
both into a single new field called category. */
 
/* Between January 2015 and June 2015, planned VE work was tracked in
projects called "VisualEditor 2014/15 Q3 blockers" and
"VisualEditor 2014/15 Q4 blockers".   This query should get everything
from those projects. */

INSERT INTO task_history_recat (
SELECT scope,
       date,
       id,
       project as category,
       status,
       points,
       'Strategic'       
  FROM task_history
 WHERE project != 'VisualEditor'
   AND scope = :'scope_prefix');


/* Prior to 18 June 2015, VE work in the VisualEditor project was not
organized around the interrupt or maintenance, so all work in that
project prior to that date can be considered Uncategorized,
regardless of state or column. */

INSERT INTO task_history_recat(
SELECT scope,
       date,
       id,
       'Uncategorized',
       status,
       points,
       'Core'
  FROM task_history
 WHERE project = 'VisualEditor'
   AND date < '2015-06-18'
   AND scope = :'scope_prefix');

/* Since June 18, 2018, the projectcolumn in the VisualEditor project
should be accurate, so any VE task in a Tranche should use the tranche
as the category. Any other tasks in the VisualEditor project (i.e.,
any task after June 18th and not in a tranche) should be old data
getting cleaned up. */

INSERT INTO task_history_recat(
SELECT scope,
       date,
       id,
       COALESCE(project,'') || ' ' ||
       COALESCE(projectcolumn,'') || ' ' ||
       COALESCE(category_title,'') as category,
       status,
       points,
       CASE WHEN projectcolumn SIMILAR TO 'TR0%' THEN 'Core'
            WHEN projectcolumn SIMILAR TO 'TR%' THEN 'Strategic'
            ELSE 'Core' END
  FROM task_history
 WHERE project = 'VisualEditor'
   AND scope = :'scope_prefix'
   AND date >= '2015-06-18');

/* Simplify status fields */

UPDATE task_history_recat
   SET status = '"open"'
 WHERE status = '"stalled"'
   AND scope = :'scope_prefix';

DELETE FROM task_history_recat
 WHERE (status = '"duplicate"'
    OR status = '"invalid"'
    OR status = '"declined"')
   AND scope = :'scope_prefix';

