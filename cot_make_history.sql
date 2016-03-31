/* COT has a custom version of generic_make_history because it assigns a default for Strategic tagging */

INSERT INTO task_history_recat(
SELECT scope,
       date,
       id,
       title,
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

UPDATE task_history_recat
   SET maint_type = 'Strategic'
 WHERE scope = :'scope_prefix'
   AND maint_type = '';
