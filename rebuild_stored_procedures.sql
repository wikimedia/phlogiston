CREATE OR REPLACE FUNCTION wipe_reconstruction(
       source_param varchar(6)
) RETURNS void AS $$
BEGIN
    DELETE FROM task_history
     WHERE source = source_param;
END;
$$ LANGUAGE plpgsql;

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

CREATE OR REPLACE FUNCTION find_recently_closed_daily(
    source_prefix varchar(6)
    ) RETURNS void AS $$
DECLARE
  daterow record;
BEGIN

    DELETE FROM recently_closed
     WHERE source = source_prefix;

    FOR daterow IN SELECT DISTINCT date
                     FROM task_history
                    WHERE source = source_prefix
                    ORDER BY date
    LOOP

        INSERT INTO recently_closed_individual (
             SELECT source_prefix as source,
                    date,
		    id,
		    title,
                    project || ' ' || projectcolumn as category
              FROM task_history
             WHERE status = '"resolved"'
               AND date = daterow.date
               AND source = source_prefix
               AND id NOT IN (SELECT id
                                FROM task_history
                               WHERE status = '"resolved"'
                                 AND source = source_prefix
                                 AND date = daterow.date - interval '1 day' )
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
