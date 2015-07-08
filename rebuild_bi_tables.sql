drop table if exists task_history;

create table task_history (
       date timestamp,
       title text,
       status text,
       project text,
       projectcolumn text,
       points int
);     


