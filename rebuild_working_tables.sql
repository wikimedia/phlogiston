DROP TABLE IF EXISTS maniphest_transaction;
DROP TABLE IF EXISTS maniphest_task;
DROP TABLE IF EXISTS maniphest_edge;
DROP TABLE IF EXISTS phabricator_column;
DROP TABLE IF EXISTS phabricator_project;

CREATE TABLE phabricator_project (
       id int,
       name text,
       phid text primary key
);

CREATE TABLE maniphest_task (
       id int,
       phid text primary key,
       title text,
       story_points text
);

CREATE TABLE phabricator_column (
       id int,
       phid text primary key,
       name text,
       project_phid text references phabricator_project
);

CREATE TABLE maniphest_transaction (
       id int,
       phid text primary key,
       task_id int,
       object_phid text,
       transaction_type text,
       new_value text,
       date_modified timestamp
);

CREATE INDEX ON maniphest_transaction (object_phid, date(date_modified));

CREATE TABLE maniphest_edge (
       task_phid text,
       project_phid text,
       date_modified timestamp
);

CREATE INDEX ON maniphest_edge (task_phid, date(date_modified));
