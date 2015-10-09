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
       old_value text,
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

/* obviously it would be better to get this working than to use cut and paste */

CREATE OR REPLACE FUNCTION find_recently_closed(
    source_table regclass,
    target_table regclass) RETURNS void AS $$
DECLARE
  weekrow record;
BEGIN

    EXECUTE format('
    FOR weekrow IN SELECT DISTINCT date
                     FROM %I
                    WHERE EXTRACT(dow from date_modified) = 0
                    ORDER BY date
    LOOP

        INSERT INTO %I (
            SELECT date,
                   projectcolumn,
                   sum(points),
                   sum(title)
              FROM %I
             WHERE status = ''"resolved"''
               AND date = weekrow.date
               AND id NOT IN (SELECT id
                                FROM %I
                               WHERE status = ''"resolved"''
                                 AND date = weekrow.date - interval ''1 week'' )
             GROUP BY date, projectcolumn
             )
    END LOOP', source_table, target_table, source_table, source_table);

    RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ve_find_recently_closed() RETURNS void AS $$
DECLARE
  weekrow record;
BEGIN

    FOR weekrow IN SELECT DISTINCT date
                     FROM ve_task_history
                    WHERE EXTRACT(day from date) IN (1,15)
                    ORDER BY date
    LOOP

        INSERT INTO ve_recently_closed (
            SELECT date,
                   project || ' ' || projectcolumn as category,
                   sum(points),
                   count(title)
              FROM ve_task_history
             WHERE status = '"resolved"'
               AND date = weekrow.date
               AND id NOT IN (SELECT id
                                FROM ve_task_history
                               WHERE status = '"resolved"'
                                 AND date = weekrow.date - interval '1 month' )
             GROUP BY date, project, projectcolumn);
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;
