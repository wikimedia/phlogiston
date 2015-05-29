drop table project;
drop table column;

create table project (
       id int,
       name text,
       phid text primary key
)

create table column (
       id int,
       phid text primary key,
       name text,
       status text,
       project_phid text references project,
       
)
