DROP TABLE IF EXISTS task_milestone;
DROP TABLE IF EXISTS task_history;

CREATE TABLE task_history (
       source varchar(6),
       date timestamp,
       id int,
       title text,
       status text,
       project text,
       projectcolumn text,
       points int,
       maint_type text,
       priority text,
       milestone_title text
       );

CREATE INDEX ON task_history (source);
CREATE INDEX ON task_history (project);
CREATE INDEX ON task_history (projectcolumn);
CREATE INDEX ON task_history (milestone_title);
CREATE INDEX ON task_history (status);
CREATE INDEX ON task_history (date);
CREATE INDEX ON task_history (id);
CREATE INDEX ON task_history (date,id);

CREATE TABLE task_milestone (
       source varchar(6),
       date timestamp,
       task_id int,
       milestone_id int
);

CREATE INDEX ON task_milestone (task_id);
CREATE INDEX ON task_milestone (task_id, source);
CREATE INDEX ON task_milestone (milestone_id);
CREATE INDEX ON task_milestone (source);
