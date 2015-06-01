drop table if exists maniphest_task_to_project;
drop table if exists maniphest_transaction;
drop table if exists maniphest_task;
drop table if exists phabricator_column;
drop table if exists phabricator_project;

create table phabricator_project (
       id int,
       name text,
       phid text primary key
);

create table phabricator_column (
       id int,
       phid text primary key,
       name text,
       project_phid text references phabricator_project
);

create table maniphest_task (
       id int,
       phid text primary key
);

create table maniphest_transaction (
       id int,
       phid text primary key,
       object_phid text references maniphest_task,
       transaction_type text,
       new_value text,
       date_modified timestamp
);

create table maniphest_task_to_project (
       task_phid text references maniphest_task,
       project_phid text references phabricator_project,
       primary key (task_phid, project_phid)
);

