-- Tables for reconstructing

DROP TABLE IF EXISTS task_history;

CREATE TABLE task_history (
       source varchar(6),
       date timestamp,
       id int,
       title text,
       status text,
       project text,
       projectcolumn text,
       points int,
       maint_type text,
       priority text
       );

CREATE INDEX ON task_history (project) ;
CREATE INDEX ON task_history (projectcolumn) ;
CREATE INDEX ON task_history (status) ;
CREATE INDEX ON task_history (date) ;
CREATE INDEX ON task_history (id) ;
CREATE INDEX ON task_history (date,id) ;

CREATE OR REPLACE FUNCTION wipe_reconstruction(
       source_param varchar(6)
) RETURNS void AS $$
BEGIN
    DELETE FROM task_history
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
