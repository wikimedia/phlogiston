drop table if exists phab_task_to_project;
drop table if exists phab_transaction;
drop table if exists phab_task;
drop table if exists phab_column;
drop table if exists phab_project;

create table phab_project (
       id int,
       name text,
       phid text primary key
);

create table phab_column (
       id int,
       phid text primary key,
       name text,
       project_phid text references phab_project
);

create table phab_task (
       id int,
       phid text primary key
);

create table phab_transaction (
       id int,
       phid text primary key,
       object_phid text references phab_task,
       transaction_type text,
       new_value text,
       date_modified timestamp
);

create table phab_task_to_project (
       task_phid text references phab_task,
       project_phid text references phab_project,
       primary key (task_phid, project_phid)
);

