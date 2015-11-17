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
       source varchar(6),
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
       source_param varchar(6)
) RETURNS void AS $$
BEGIN
    DELETE FROM task_history
     WHERE source = source_param;
END;
$$ LANGUAGE plpgsql;

-- Tables for reporting

DROP TABLE IF EXISTS zoom_list;

CREATE TABLE zoom_list (
       source varchar(6),
       sort_order int,
       category text
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
    points int,
    count int,
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
    pes_count_fore int
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
      
CREATE OR REPLACE FUNCTION wipe_reporting(
       source_param varchar(6)
) RETURNS void AS $$
BEGIN
    DELETE FROM tall_backlog
     WHERE source = source_param;

    DELETE FROM zoom_list
     WHERE source = source_param;

    DELETE FROM recently_closed
     WHERE source = source_param;

    DELETE FROM maintenance_week
     WHERE source = source_param;

    DELETE FROM maintenance_delta
     WHERE source = source_param;

    DELETE FROM velocity
     WHERE source = source_param;

    DELETE FROM open_backlog_size
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
    source_prefix varchar(6)
    ) RETURNS void AS $$
DECLARE
  weekrow record;
BEGIN

    DELETE FROM recently_closed
     WHERE source = source_prefix;

    FOR weekrow IN SELECT DISTINCT date
                     FROM task_history
                    WHERE EXTRACT(dow from date) = 0
                      AND source = source_prefix
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
                                 AND date = weekrow.date - interval '1 week' )
             GROUP BY date, project, projectcolumn
             );
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_velocities(
    source_prefix varchar(6)
    ) RETURNS void AS $$
DECLARE
  weekrow record;
  tranche record;
  min_points_vel float;
  avg_points_vel float;
  max_points_vel float;
  min_count_vel float;
  avg_count_vel float;
  max_count_vel float;
  min_points_fore float;
  avg_points_fore float;
  max_points_fore float;
  min_count_fore float;
  avg_count_fore float;
  max_count_fore float;
BEGIN

    FOR weekrow IN SELECT DISTINCT date
                     FROM velocity
                    WHERE source = source_prefix
                    ORDER BY date
    LOOP
        FOR tranche IN SELECT DISTINCT category
	                 FROM tall_backlog
			WHERE date = weekrow.date
			  AND source = source_prefix
			ORDER BY category
	LOOP
	    SELECT SUM(delta_points)/3 AS min_points_vel
              INTO min_points_vel
              FROM (SELECT delta_points
                      FROM velocity subqv
                     WHERE subqv.date >= weekrow.date - interval '3 months'
                       AND subqv.date < weekrow.date
                       AND subqv.source = source_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_points 
                     LIMIT 3) as x;

	    SELECT SUM(delta_points)/3 AS max_points_vel
              INTO max_points_vel
              FROM (SELECT delta_points
                      FROM velocity subqv
                     WHERE subqv.date >= weekrow.date - interval '3 months'
                       AND subqv.date < weekrow.date
                       AND subqv.source = source_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_points DESC
                     LIMIT 3) as x;

            SELECT AVG(delta_points)
              INTO avg_points_vel
              FROM velocity subqv
             WHERE subqv.date >= weekrow.date - interval '3 months'
               AND subqv.date < weekrow.date
               AND subqv.source = source_prefix
               AND subqv.category = tranche.category;

	    SELECT SUM(delta_count)/3 AS min_count_vel
              INTO min_count_vel
              FROM (SELECT delta_count
                      FROM velocity subqv
                     WHERE subqv.date >= weekrow.date - interval '3 months'
                       AND subqv.date < weekrow.date
                       AND subqv.source = source_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_count 
                     LIMIT 3) as x;

	    SELECT SUM(delta_count)/3 AS max_count_vel
              INTO max_count_vel
              FROM (SELECT delta_count
                      FROM velocity subqv
                     WHERE subqv.date >= weekrow.date - interval '3 months'
                       AND subqv.date < weekrow.date
                       AND subqv.source = source_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_count DESC
                     LIMIT 3) as x;

            SELECT AVG(delta_count)
              INTO avg_count_vel
              FROM velocity subqv
             WHERE subqv.date >= weekrow.date - interval '3 months'
               AND subqv.date < weekrow.date
               AND subqv.source = source_prefix
               AND subqv.category = tranche.category;

            SELECT points::float / NULLIF(min_points_vel,0)
	      INTO min_points_fore
	      FROM open_backlog_size
             WHERE source = source_prefix
	       AND date = weekrow.date
	       AND category = tranche.category;

            SELECT points::float / NULLIF(avg_points_vel,0)
	      INTO avg_points_fore
	      FROM open_backlog_size
             WHERE source = source_prefix
	       AND date = weekrow.date
	       AND category = tranche.category;

            SELECT points::float / NULLIF(max_points_vel,0)
	      INTO max_points_fore
	      FROM open_backlog_size
             WHERE source = source_prefix
	       AND date = weekrow.date
	       AND category = tranche.category;

            SELECT count::float / NULLIF(min_count_vel,0)
	      INTO min_count_fore
	      FROM open_backlog_size
             WHERE source = source_prefix
	       AND date = weekrow.date
	       AND category = tranche.category;

            SELECT count::float / NULLIF(avg_count_vel,0)
	      INTO avg_count_fore
	      FROM open_backlog_size
             WHERE source = source_prefix
	       AND date = weekrow.date
	       AND category = tranche.category;

            SELECT count::float / NULLIF(max_count_vel,0)
	      INTO max_count_fore
	      FROM open_backlog_size
             WHERE source = source_prefix
	       AND date = weekrow.date
	       AND category = tranche.category;

            UPDATE velocity
               SET pes_points_vel = round(min_points_vel),
                   nom_points_vel = round(avg_points_vel),
                   opt_points_vel = round(max_points_vel),
                   pes_count_vel = round(min_count_vel),
                   nom_count_vel = round(avg_count_vel),
                   opt_count_vel = round(max_count_vel),
		   pes_points_fore = round(min_points_fore),
		   nom_points_fore = round(avg_points_fore),
  		   opt_points_fore = round(max_points_fore),
		   pes_count_fore = round(min_count_fore),
		   nom_count_fore = round(avg_count_fore),
  		   opt_count_fore = round(max_count_fore)
             WHERE source = source_prefix
               AND category = tranche.category
               AND date = weekrow.date;
        END LOOP;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;

