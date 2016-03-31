DROP TABLE IF EXISTS task_category;
DROP TABLE IF EXISTS task_history;

CREATE TABLE task_history (
       scope varchar(6),
       date timestamp,
       id int,
       title text,
       status text,
       project text,
       projectcolumn text,
       points int,
       maint_type text,
       priority text,
       category_title text
       );

CREATE INDEX ON task_history (scope);
CREATE INDEX ON task_history (project);
CREATE INDEX ON task_history (projectcolumn);
CREATE INDEX ON task_history (category_title);
CREATE INDEX ON task_history (status);
CREATE INDEX ON task_history (date);
CREATE INDEX ON task_history (id);
CREATE INDEX ON task_history (date,id);

CREATE TABLE task_category (
       scope varchar(6),
       date timestamp,
       task_id int,
       category_id int
);

CREATE INDEX ON task_category (task_id);
CREATE INDEX ON task_category (task_id, scope);
CREATE INDEX ON task_category (category_id);
CREATE INDEX ON task_category (scope);
