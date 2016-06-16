/* This is the generic conversion of data from historical
reconstruction, where each line equals one task on one day, to
summarized data, where each line equals a subtotal of data for one
combination of date, category, status, and maintenance type.

It assumes that each column in each project is one category of
interest.  If a task has an 'ancestor' task (technically, a "Blocks"
ancestor) in the Category project, that task title is also used to
differentiate categories.

Scopes that don't work this way (because they don't use
projectcolumn to track separate categories, or because they have a
heterogeneous history, or because they track maintenance type in some
other way) should implement their custom logic in a version of this
file called [prefix]_make_history.sql.*/

INSERT INTO task_history_recat(
SELECT scope,
       date,
       id,
       COALESCE(project,'') || ' ' ||
       COALESCE(projectcolumn,'') || ' ' ||
       COALESCE(category_title,'') as category,
       status,
       points,
       maint_type
  FROM task_history
 WHERE scope = :'scope_prefix');

/* Filter out statuses that are probably ignorable. */

UPDATE task_history_recat
   SET status = '"open"'
 WHERE status = '"stalled"'
   AND scope = :'scope_prefix';

DELETE FROM task_history_recat
 WHERE (status = '"duplicate"'
    OR status = '"invalid"'
    OR status = '"declined"')
   AND scope = :'scope_prefix';
