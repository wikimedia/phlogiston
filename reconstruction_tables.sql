DROP TABLE IF EXISTS phab_parent_category_edge;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS task_on_date;
DROP TABLE IF EXISTS maniphest_edge;

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
DROP TYPE IF EXISTS displayrule CASCADE;

CREATE TYPE categoryrule AS ENUM ('ProjectByID', 'ProjectByName', 'ProjectsByWildcard', 'Intersection', 'ProjectColumn', 'ParentTask');
CREATE TYPE displayrule AS ENUM ('show', 'hide', 'omit');

CREATE TABLE category (
       scope varchar(6),
       sort_order int,
       rule categoryrule,
       project_id_list integer[],
       project_name_list text[],
       matchstring text,
       title text,
       display displayrule,
       include_in_status boolean,
       UNIQUE (scope, sort_order),
       UNIQUE (scope, rule, project_id_list, matchstring)
);

CREATE TABLE maniphest_edge (
       task int,
       project int,
       edge_date date
);

-- TODO: maybe add the indexes after all rows are added?
CREATE INDEX ON maniphest_edge (task, project, edge_date);
CREATE INDEX ON maniphest_edge (task);
CREATE INDEX ON maniphest_edge (project);
CREATE INDEX ON maniphest_edge (edge_date);

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
