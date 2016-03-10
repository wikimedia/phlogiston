/* This is the generic conversion of data from historical
reconstruction, where each line equals one task on one day, to
summarized data, where each line equals a subtotal of data for one
combination of date, category, status, and maintenance type.

It assumes that each column in each project is one category of
interest.  If a task has an 'ancestor' task (technically, a "Blocks"
ancestor) in the Milestone project, that task title is also used to
differentiate categories.

Projects that don't work this way (because they don't use
projectcolumn to track separate categories, or because they have a
heterogeneous history, or because they track maintenance type in some
other way) should implement their custom logic in a version of this
file called [prefix]_make_history.sql.*/

INSERT INTO task_history_recat(
SELECT source,
       date,
       id,
       title,
       COALESCE(project,'') || ' ' ||
       COALESCE(projectcolumn,'') || ' ' ||
       COALESCE(milestone_title,'') as category,
       status,
       points,
       maint_type
  FROM task_history
 WHERE source = :'prefix');

/* Make categorization retroactive - most recent categorization is
applied to complete history of each task, as if it always had that
category */

UPDATE task_history_recat t
   SET category = t0.category
  FROM task_history_recat t0
 WHERE t0.date = (SELECT MAX(date)
                    FROM task_history_recat
                   WHERE source = :'prefix')
   AND t0.source = :'prefix'
   AND t.source = :'prefix'
   AND t0.id = t.id;

/* Filter out statuses that are probably ignorable. */

UPDATE task_history_recat
   SET status = '"open"'
 WHERE status = '"stalled"'
   AND source = :'prefix';

DELETE FROM task_history_recat
 WHERE (status = '"duplicate"'
    OR status = '"invalid"'
    OR status = '"declined"')
   AND source = :'prefix';
