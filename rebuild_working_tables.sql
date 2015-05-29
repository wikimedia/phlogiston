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
       status text,
       project_phid text references phab_project
);
