drop table if exists task_history;

create table task_history (
       date timestamp,
       title text,
       status text,
       project text,
       projectcolumn text,
       points int
);     

create index on task_history (project);
create index on task_history (projectcolumn);
create index on task_history (status);
create index on task_history (date);



