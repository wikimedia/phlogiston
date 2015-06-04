drop table if exists maniphest_transaction;
drop table if exists maniphest_task;
drop table if exists maniphest_edge;
drop table if exists phabricator_column;
drop table if exists phabricator_project;

create table phabricator_project (
       id int,
       name text,
       phid text primary key
);

create table maniphest_task (
       id int,
       phid text primary key,
       title text,
       story_points text
);

create table phabricator_column (
       id int,
       phid text primary key,
       name text,
       project_phid text references phabricator_project
);

create table maniphest_transaction (
       id int,
       phid text primary key,
       task_id int,
       object_phid text,
       transaction_type text,
       new_value text,
       date_modified timestamp
);

create index on maniphest_transaction (object_phid, date(date_modified));

create table maniphest_edge (
       task_phid text,
       project_phid text,
       date_modified timestamp
);

create index on maniphest_edge (task_phid, date(date_modified));
