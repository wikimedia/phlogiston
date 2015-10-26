-- Tables for loading

CREATE EXTENSION IF NOT EXISTS intarray;

DROP TABLE IF EXISTS maniphest_edge;
DROP TABLE IF EXISTS maniphest_transaction;
DROP TABLE IF EXISTS maniphest_task;
DROP TABLE IF EXISTS phabricator_column;
DROP TABLE IF EXISTS phabricator_project;

CREATE TABLE phabricator_project (
       id int primary key,
       name text,
       phid text unique
);

CREATE TABLE maniphest_task (
       id int primary key,
       phid text unique,
       title text,
       story_points text
);

CREATE TABLE phabricator_column (
       id int primary key,
       phid text unique,
       name text,
       project_phid text references phabricator_project (phid)
);

CREATE TABLE maniphest_transaction (
       id int primary key,
       phid text unique,
       task_id int,
       object_phid text,
       transaction_type text,
       new_value text,
       date_modified timestamp,
       has_edge_data boolean,
       active_projects int array
);

CREATE INDEX ON maniphest_transaction (task_id, date_modified, has_edge_data);

CREATE TABLE maniphest_edge (
       task int references maniphest_task,
       project int references phabricator_project,
       edge_date date
);

-- TODO: maybe add the indexes after all rows are added?
CREATE INDEX ON maniphest_edge (task, project, edge_date);
CREATE INDEX ON maniphest_edge (task);
CREATE INDEX ON maniphest_edge (project);

-- Tables for reconstructing

DROP TABLE IF EXISTS task_history;

CREATE TABLE task_history (
       source varchar(5),
       date timestamp,
       id int,
       title text,
       status text,
       project text,
       projectcolumn text,
       points int,
       maint_type text
);

CREATE INDEX ON task_history (project) ;
CREATE INDEX ON task_history (projectcolumn) ;
CREATE INDEX ON task_history (status) ;
CREATE INDEX ON task_history (date) ;
CREATE INDEX ON task_history (id) ;
CREATE INDEX ON task_history (date,id) ;


CREATE OR REPLACE FUNCTION wipe_reconstruction(
       source_param varchar(5)
) RETURNS void AS $$
BEGIN
    DELETE FROM task_history
     WHERE source = source_param;
END;
$$ LANGUAGE plpgsql;

-- Tables for reporting

DROP TABLE IF EXISTS tall_backlog;

CREATE TABLE tall_backlog (
       source varchar(5),
       date timestamp,
       category text,
       status text,
       points int,
       count int,
       maint_type text
);

DROP TABLE IF EXISTS recently_closed;

CREATE TABLE recently_closed (
    source varchar(5),
    date date,
    category text,
    points int,
    count int
);

DROP TABLE IF EXISTS maintenance_week;
DROP TABLE IF EXISTS maintenance_delta;

CREATE TABLE maintenance_week (
    source varchar(5),
    date timestamp,
    maint_type text,
    points int,
    count int
);

CREATE TABLE maintenance_delta (
    source varchar(5),
    date timestamp,
    maint_type text,
    maint_points int,
    new_points int,
    maint_count int,
    new_count int
);

CREATE OR REPLACE FUNCTION wipe_reporting(
       source_param varchar(5)
) RETURNS void AS $$
BEGIN
    DELETE FROM tall_backlog
     WHERE source = source_param;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION build_edges(
       run_date date,
       project_id_list int array) RETURNS void AS $$
DECLARE
  dayrow record;
  taskrow record;
  projrow record;
  project_id int;
BEGIN

    FOR taskrow IN SELECT id
                     FROM maniphest_task
                    ORDER BY id
    LOOP
        FOR projrow IN SELECT active_projects
                         FROM maniphest_transaction
                        WHERE date_modified <= run_date
                          AND task_id = taskrow.id
                          AND has_edge_data IS TRUE
                     ORDER BY date_modified DESC
                        LIMIT 1
        LOOP
            FOREACH project_id IN ARRAY projrow.active_projects & project_id_list
            LOOP
                INSERT INTO maniphest_edge
                     VALUES (taskrow.id, project_id, run_date);
            END LOOP;
        END LOOP;
    END LOOP;     

    RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION find_recently_closed(
    source_prefix varchar(5)
    ) RETURNS void AS $$
DECLARE
  weekrow record;
BEGIN

    FOR weekrow IN SELECT DISTINCT date
                     FROM task_history
                    WHERE EXTRACT(dow from date) IN (1, 15)
                    ORDER BY date
    LOOP

        INSERT INTO recently_closed (
            SELECT source_prefix as source,
                   date,
                   project || ' ' || projectcolumn as category,
                   sum(points) AS points,
                   count(title) as count
              FROM task_history
             WHERE status = '"resolved"'
               AND date = weekrow.date
               AND source = source_prefix
               AND id NOT IN (SELECT id
                                FROM task_history
                               WHERE status = '"resolved"'
                                 AND source = source_prefix
                                 AND date = weekrow.date - interval '15 days' )
             GROUP BY date, project, projectcolumn
             );
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;
