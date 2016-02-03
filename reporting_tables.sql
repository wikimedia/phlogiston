DROP TABLE IF EXISTS category_list;

CREATE TABLE category_list (
       source varchar(6),
       sort_order int,
       category text,
       matchstring text,
       zoom boolean
);

DROP TABLE IF EXISTS tall_backlog;

CREATE TABLE tall_backlog (
       source varchar(6),
       date timestamp,
       category text,
       status text,
       points int,
       count int,
       maint_type text
);

DROP TABLE IF EXISTS recently_closed;

CREATE TABLE recently_closed (
    source varchar(6),
    date date,
    category text,
    points int,
    count int
);

DROP TABLE IF EXISTS recently_closed_task;

CREATE TABLE recently_closed_task (
    source varchar(6),
    date date,
    id int,
    title text,
    category text
);

DROP TABLE IF EXISTS maintenance_week;
DROP TABLE IF EXISTS maintenance_delta;

CREATE TABLE maintenance_week (
    source varchar(6),
    date timestamp,
    maint_type text,
    points int,
    count int
);

CREATE TABLE maintenance_delta (
    source varchar(6),
    date timestamp,
    maint_type text,
    maint_points int,
    new_points int,
    maint_count int,
    new_count int
);

DROP TABLE IF EXISTS velocity;

CREATE TABLE velocity (
    source varchar(6),
    category text,
    date timestamp,
    points_resolved int,
    count_resolved int,
    points_open int,
    count_open int,
    delta_points int,
    delta_count int,
    opt_points_vel int,
    nom_points_vel int,
    pes_points_vel int,
    opt_count_vel int,
    nom_count_vel int,
    pes_count_vel int,
    opt_points_fore int,
    nom_points_fore int,
    pes_points_fore int,
    opt_count_fore int,
    nom_count_fore int,
    pes_count_fore int,
    opt_points_date timestamp,
    nom_points_date timestamp,
    pes_points_date timestamp,
    opt_count_date timestamp,
    nom_count_date timestamp,
    pes_count_date timestamp
);

DROP TABLE IF EXISTS open_backlog_size;

CREATE TABLE open_backlog_size (
    source varchar(6),
    category text,
    date timestamp,
    points int,
    count int,
    delta_points int,
    delta_count int
);
