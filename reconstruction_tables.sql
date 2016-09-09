DROP TABLE IF EXISTS phab_parent_category_edge;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS task_on_date;

CREATE TABLE task_on_date (
       scope varchar(6),
       date timestamp,
       id int,
       status text,
       project_id int,
       project text,
       projectcolumn text,
       points int,
       maint_type text,
       priority text,
       category_title text,
       UNIQUE (id, scope, date)
       );

CREATE INDEX ON task_on_date (scope);
CREATE INDEX ON task_on_date (project);
CREATE INDEX ON task_on_date (project_id);
CREATE INDEX ON task_on_date (projectcolumn);
CREATE INDEX ON task_on_date (category_title);
CREATE INDEX ON task_on_date (status);
CREATE INDEX ON task_on_date (date);
CREATE INDEX ON task_on_date (id);
CREATE INDEX ON task_on_date (date,id);


DROP TYPE IF EXISTS categoryrule CASCADE;

CREATE TYPE categoryrule AS ENUM ('ProjectByID', 'ProjectByName', 'ProjectsByWildcard', 'Intersection', 'ProjectColumn', 'ParentTask');

CREATE TABLE category (
       scope varchar(6),
       sort_order int,
       rule categoryrule,
       project_id_list integer[],
       project_name_list text[],
       matchstring text,
       title text,
       display boolean,
       UNIQUE (scope, sort_order)
);

CREATE TABLE phab_parent_category_edge (
       scope varchar(6),
       date timestamp,
       task_id int,
       category_id int
);

CREATE INDEX ON phab_parent_category_edge (task_id);
CREATE INDEX ON phab_parent_category_edge (task_id, scope);
CREATE INDEX ON phab_parent_category_edge (category_id);
CREATE INDEX ON phab_parent_category_edge (scope);
CREATE INDEX ON phab_parent_category_edge (task_id, scope, date);
