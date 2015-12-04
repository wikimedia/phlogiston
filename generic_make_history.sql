/* This is the generic conversion of data from historical reconstruction, where each line equals one task on one day, to summarized data, where each line equals a subtotal of data for one combination of date, category, status, and maintenance type.

It assumes that each column in each project is one category of interest.

If maintenance type has been tracked using the WorkType projects in Phabricator, it will be converted here.

Projects that don't work this way (because they don't use projectcolumn to track separate categories, or because they have a heterogeneous history, or because they track maintenance type in some other way) should implement their custom logic in a version of this file called [prefix]_make_history.sql.*/

/* Filter out statuses that are probably ignorable. */

UPDATE task_history
   SET status = '"open"'
 WHERE status = '"stalled"'
   AND source = :'prefix';

DELETE FROM task_history
 WHERE (status = '"duplicate"'
    OR status = '"invalid"'
    OR status = '"declined"')
   AND source = :'prefix';

INSERT INTO tall_backlog(
SELECT source,
       date,
       project || ' ' || projectcolumn || ' ' || parent_title as category,
       status,
       SUM(points) as points,
       COUNT(title) as count,
       maint_type
  FROM task_history
 WHERE source = :'prefix'
 GROUP BY status, category, maint_type, date, source);
