-- Tables for reconstructing
DROP TABLE IF EXISTS task_milestone;
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
       priority text,
       parent_title text
       );

CREATE INDEX ON task_history (project);
CREATE INDEX ON task_history (projectcolumn); 
CREATE INDEX ON task_history (status);
CREATE INDEX ON task_history (date);
CREATE INDEX ON task_history (id);
CREATE INDEX ON task_history (date,id);

CREATE TABLE task_milestone (
       source varchar(6),
       date timestamp,
       task_id int,
       milestone_id int
);

CREATE INDEX ON task_milestone (task_id);

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


-- currently uses edge data, which is point-in-time.  When transactional
-- data becomes available, should use that instead
CREATE OR REPLACE FUNCTION find_descendents(
       root_id int,
       run_date date
) RETURNS TABLE(id int) AS $$
BEGIN
  RETURN query
  WITH RECURSIVE search_graph(blocked_id, id, depth, path, cycle) AS (
        SELECT b.blocked_id, b.id, 1,
          ARRAY[b.id],
          false
        FROM maniphest_blocked b
       WHERE blocked_id = root_id
      UNION ALL
        SELECT b.blocked_id, b.id, sg.depth + 1,
          path || b.id,
          b.id = ANY(path)
        FROM maniphest_blocked b, search_graph sg
        WHERE b.blocked_id = sg.id AND NOT cycle
  )
  SELECT search_graph.id FROM search_graph;

END;
$$ LANGUAGE plpgsql;
