CREATE OR REPLACE FUNCTION phl_find_recently_closed() RETURNS void AS $$
DECLARE
  weekrow record;
BEGIN

    FOR weekrow IN SELECT DISTINCT date
                     FROM phl_task_history
                    WHERE EXTRACT(day from date) IN (1,15)
                    ORDER BY date
    LOOP

        INSERT INTO phl_recently_closed (
            SELECT date,
                   project || ' ' || projectcolumn as category,
                   sum(points),
                   count(title)
              FROM phl_task_history
             WHERE status = '"resolved"'
               AND date = weekrow.date
               AND id NOT IN (SELECT id
                                FROM phl_task_history
                               WHERE status = '"resolved"'
                                 AND date = weekrow.date - interval '15 days' )
             GROUP BY date, project, projectcolumn);
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;

/* Apply some filtering to the raw data */

UPDATE phl_task_history
   SET status = '"open"'
 WHERE status = '"stalled"';

DELETE FROM phl_task_history
 WHERE status = '"duplicate"'
    OR status = '"invalid"'
    OR status = '"declined"';

/* ##################################################################
Roll up the task history from individual tasks to cumulative totals.

Each row is the cumulative point total for one day for one project and
projectcolumn and status  */

DROP TABLE IF EXISTS phl_tall_backlog;

SELECT date,
       project as category,
       status,
       COUNT(title) as count,
       SUM(points) as points,
       maint_type
  INTO phl_tall_backlog
  FROM phl_task_history
 GROUP BY status, category, maint_type, date;

COPY (
SELECT date,
       category,
       SUM(points) as points
  FROM phl_tall_backlog
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/phl_backlog.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       SUM(count) as count
  FROM phl_tall_backlog
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/phl_backlog_count.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(points) as points
  FROM phl_tall_backlog
 WHERE status = '"resolved"'
 GROUP BY date
 ORDER BY date
) to '/tmp/phl_burnup.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(count) as count
  FROM phl_tall_backlog
 WHERE status = '"resolved"'
 GROUP BY date
 ORDER BY date
) to '/tmp/phl_burnup_count.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       SUM(points) as points
  FROM phl_tall_backlog
 WHERE status = '"resolved"'
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/phl_burnup_categories.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       SUM(count) as count
  FROM phl_tall_backlog
 WHERE status = '"resolved"'
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/phl_burnup_categories_count.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Burnup and Velocity */

DROP TABLE IF EXISTS phl_velocity_week;
DROP TABLE IF EXISTS phl_velocity_delta;

SELECT date,
       SUM(points) AS points
  INTO phl_velocity_week
  FROM phl_tall_backlog
 WHERE status = '"resolved"'
   AND EXTRACT(dow from date) = 0 
   AND date >= current_date - interval '3 months'
 GROUP BY date
 ORDER BY date;

SELECT date,
       (points - lag(points) OVER (ORDER BY date)) as points,
       NULL::int as velocity
  INTO phl_velocity_delta
  FROM phl_velocity_week
 ORDER BY date;

UPDATE phl_velocity_delta a
   SET velocity = (SELECT points
                       FROM (SELECT date,
                                    points - lag(points) OVER (ORDER BY date) as points
                               FROM phl_velocity_week
                             ) as b
                      WHERE a.date = b.date);

COPY (
SELECT date,
       velocity
  FROM phl_velocity_delta
) TO '/tmp/phl_velocity.csv' DELIMITER ',' CSV HEADER;

DROP TABLE IF EXISTS phl_velocity_count_week;
DROP TABLE IF EXISTS phl_velocity_count_delta;

SELECT date,
       sum(count) as count
  INTO phl_velocity_count_week
  FROM phl_tall_backlog
 WHERE status = '"resolved"'
   AND EXTRACT(dow from date) = 0 
   AND date >= current_date - interval '3 months'
 GROUP BY date
 ORDER BY date;

SELECT date,
       (count - lag(count) OVER (ORDER BY date)) as count,
       NULL::int as velocity
  INTO phl_velocity_count_delta
  FROM phl_velocity_count_week
 ORDER BY date;

UPDATE phl_velocity_count_delta a
   SET velocity = (SELECT count
                       FROM (SELECT date,
                                    count - lag(count) OVER (ORDER BY date) as count
                               FROM phl_velocity_count_week
                             ) as b
                      WHERE a.date = b.date);

COPY (
SELECT date,
       velocity
  FROM phl_velocity_count_delta
) TO '/tmp/phl_velocity_count.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Backlog growth calculations */

DROP TABLE IF EXISTS phl_backlog_size;

SELECT date,
       SUM(points) AS points,
       SUM(count) as count
  INTO phl_backlog_size
  FROM phl_tall_backlog
 WHERE status != '"resolved"'
   AND EXTRACT(dow from date) = 0 
 GROUP BY date
 ORDER BY date;

COPY (
SELECT date,
       (points - lag(points) OVER (ORDER BY date)) as points
  FROM phl_backlog_size
 ORDER BY date
) to '/tmp/phl_net_growth.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       (count - lag(count) OVER (ORDER BY date)) as count
  FROM phl_backlog_size
 ORDER BY date
) to '/tmp/phl_net_growth_count.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
   Maintenance fraction
Divide all resolved work into Maintenance or New Project, by week. */

DROP TABLE IF EXISTS phl_maintenance_week;
DROP TABLE IF EXISTS phl_maintenance_delta;

SELECT date,
       maint_type,
       SUM(points) as points
  INTO phl_maintenance_week
  FROM phl_tall_backlog
  WHERE status = '"resolved"'
   AND EXTRACT(dow FROM date) = 0
   AND date >= current_date - interval '3 months'
 GROUP BY maint_type, date
 ORDER BY date, maint_type;

SELECT date,
       maint_type,
       (points - lag(points) OVER (ORDER BY date)) as maint_points,
       NULL::int as new_points
  INTO phl_maintenance_delta
  FROM phl_maintenance_week
 WHERE maint_type='Maintenance'
 ORDER BY date, maint_type;

UPDATE phl_maintenance_delta a
   SET new_points = (SELECT points
                       FROM (SELECT date,
                                    points - lag(points) OVER (ORDER BY date) as points
                               FROM phl_maintenance_week
                              WHERE maint_type='New Functionality') as b
                      WHERE a.date = b.date);

COPY (
SELECT date,
       maint_frac
  FROM (
SELECT date,
       maint_points::float / nullif((maint_points + new_points),0) as maint_frac
  FROM phl_maintenance_delta
  ) as phl_maintenance_fraction
) TO '/tmp/phl_maintenance_fraction.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT ROUND(100 * maint_points::decimal / nullif((maint_points + new_points),0),0) as "Total Maintenance Fraction"
  FROM (SELECT sum(maint_points) as maint_points
          FROM phl_maintenance_delta) as x
 CROSS JOIN 
       (SELECT sum(new_points)  as new_points
	  FROM phl_maintenance_delta) as y
) TO '/tmp/phl_maintenance_fraction_total.csv' DELIMITER ',' CSV;

/* by count */

DROP TABLE IF EXISTS phl_maintenance_count_week;
DROP TABLE IF EXISTS phl_maintenance_count_delta;

SELECT date,
       maint_type,
       sum(count) as count
  INTO phl_maintenance_count_week
  FROM phl_tall_backlog
  WHERE status = '"resolved"'
   AND EXTRACT(dow FROM date) = 0
   AND date >= current_date - interval '3 months'
 GROUP BY maint_type, date
 ORDER BY date, maint_type;

SELECT date,
       maint_type,
       (count - lag(count) OVER (ORDER BY date)) as maint_count,
       NULL::int as new_count
  INTO phl_maintenance_count_delta
  FROM phl_maintenance_count_week
 WHERE maint_type='Maintenance'
 ORDER BY date, maint_type;

UPDATE phl_maintenance_count_delta a
   SET new_count = (SELECT count
                       FROM (SELECT date,
                                    count - lag(count) OVER (ORDER BY date) as count
                               FROM phl_maintenance_count_week
                              WHERE maint_type='New Functionality') as b
                      WHERE a.date = b.date);

COPY (
SELECT date,
       maint_frac
  FROM (
SELECT date,
       maint_count::float / nullif((maint_count + new_count),0) as maint_frac
  FROM phl_maintenance_count_delta
  ) as phl_maintenance_count_fraction
) TO '/tmp/phl_maintenance_count_fraction.csv' DELIMITER ',' CSV HEADER;


COPY (
SELECT ROUND(100 * maint_count::decimal / nullif((maint_count + new_count),0),0) as "Total Maintenance Fraction"
  FROM (SELECT sum(maint_count) as maint_count
          FROM phl_maintenance_count_delta) as x
 CROSS JOIN 
       (SELECT sum(new_count)  as new_count
	  FROM phl_maintenance_count_delta) as y
) TO '/tmp/phl_maintenance_count_fraction_total.csv' DELIMITER ',' CSV;

/* Assumes that data is current; in theory we could use max_date in the
data as the baseline instead of current_data but that's probably
something for the plpgsql port */

COPY (
SELECT SUM(velocity)/3 AS min_velocity
  FROM (SELECT velocity 
          FROM phl_velocity_delta
         WHERE date >= current_date - interval '3 months'
           AND velocity <> 0 
         ORDER BY velocity 
         LIMIT 3) as x)
TO '/tmp/phl_min.csv' DELIMITER ',' CSV;

COPY (
SELECT SUM(velocity)/3 AS max_velocity
  FROM (SELECT velocity 
          FROM phl_velocity_delta
         WHERE date >= current_date - interval '3 months'
           AND velocity <> 0 
         ORDER BY velocity DESC
         LIMIT 3) as x)
TO '/tmp/phl_max.csv' DELIMITER ',' CSV;

COPY (
SELECT AVG(velocity) AS avg_velocity
  FROM (SELECT velocity 
          FROM phl_velocity_delta
         WHERE date >= current_date - interval '3 months'
           AND velocity <> 0 
         ORDER BY velocity)
         as x)
TO '/tmp/phl_avg.csv' DELIMITER ',' CSV;

COPY (
SELECT category,
       SUM(points) AS open_backlog
  FROM phl_tall_backlog
 WHERE status='"open"'
   AND date=(SELECT MAX(date)
               FROM phl_task_history)
 GROUP BY category
 ORDER BY category)
 TO '/tmp/phl_backlog_current.csv' DELIMITER ',' CSV HEADER;


/* Report on the most recent date to catch some simple errors */
COPY (
SELECT MAX(date)
  FROM phl_task_history)
TO '/tmp/phl_max_date.csv' DELIMITER ',' CSV;

/* ####################################################################
Recently Closed */

DROP TABLE IF EXISTS phl_recently_closed;

CREATE TABLE phl_recently_closed (
    date date,
    category text,
    points int,
    count int
);

SELECT * FROM phl_find_recently_closed();

COPY (
SELECT date,
       category,
       points,
       count
  FROM phl_recently_closed
 ORDER BY date, category
) to '/tmp/phl_recently_closed.csv' DELIMITER ',' CSV HEADER;