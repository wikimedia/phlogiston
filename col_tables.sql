/* This script assumes that all tasks in the database are relevant to the VisualEditor team */

/* Apply some filtering to the raw data */

UPDATE col_task_history
   SET status = '"open"'
 WHERE status = '"stalled"';

DELETE FROM col_task_history
 WHERE status = '"duplicate"'
    OR status = '"invalid"'
    OR status = '"declined"';

/* ##################################################################
Roll up the task history from individual tasks to cumulative totals.

Each row is the cumulative point total for one day for one project and
projectcolumn and status  */

DROP TABLE IF EXISTS col_tall_backlog;

/* For Collaboration, each project = 1 sprint = 1 category */

SELECT date,
       project as category,
       status,
       COUNT(title) as count,
       SUM(points) as points
  INTO col_tall_backlog
  FROM col_task_history
 GROUP BY status, category, date;

COPY (
SELECT date,
       category,
       SUM(points) as points
  FROM col_tall_backlog
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/col_backlog.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       SUM(count) as count
  FROM col_tall_backlog
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/col_backlog_count.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(points) as points
  FROM col_tall_backlog
 WHERE status = '"resolved"'
 GROUP BY date
 ORDER BY date
) to '/tmp/col_burnup.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       SUM(points) as points
  FROM col_tall_backlog
 WHERE status = '"resolved"'
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/col_burnup_categories.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       SUM(count) as count
  FROM col_tall_backlog
 WHERE status = '"resolved"'
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/col_burnup_categories_count.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Burnup and Velocity */

DROP TABLE IF EXISTS col_velocity_week;
DROP TABLE IF EXISTS col_velocity_delta;

SELECT date,
       SUM(points) AS points
  INTO col_velocity_week
  FROM col_tall_backlog
 WHERE status = '"resolved"'
   AND EXTRACT(dow from date) = 0 
   AND date >= current_date - interval '3 months'
 GROUP BY date
 ORDER BY date;

SELECT date,
       (points - lag(points) OVER (ORDER BY date)) as points,
       NULL::int as velocity
  INTO col_velocity_delta
  FROM col_velocity_week
 ORDER BY date;

UPDATE col_velocity_delta a
   SET velocity = (SELECT points
                       FROM (SELECT date,
                                    points - lag(points) OVER (ORDER BY date) as points
                               FROM col_velocity_week
                             ) as b
                      WHERE a.date = b.date);

COPY (
SELECT date,
       velocity
  FROM col_velocity_delta
) TO '/tmp/col_velocity.csv' DELIMITER ',' CSV HEADER;


/* ####################################################################
Backlog growth calculations */

DROP TABLE IF EXISTS col_backlog_size;

SELECT date,
       SUM(points) AS points
  INTO col_backlog_size
  FROM col_tall_backlog
 WHERE status != '"resolved"'
   AND EXTRACT(dow from date) = 0 
 GROUP BY date
 ORDER BY date;

COPY (
SELECT date,
       (points - lag(points) OVER (ORDER BY date)) as points
  FROM col_backlog_size
 ORDER BY date
) to '/tmp/col_net_growth.csv' DELIMITER ',' CSV HEADER;

/*
/* ####################################################################
   Maintenance fraction
Divide all resolved work into Maintenance or New Project, by week. */

DROP TABLE IF EXISTS col_maintenance_week;
DROP TABLE IF EXISTS col_maintenance_delta;

SELECT date,
       CASE WHEN category = 'TR0: Interrupt' then 'Maintenance'
            ELSE 'New Project'
       END as type,
       SUM(points) as points
  INTO col_maintenance_week
  FROM col_tall_backlog
  WHERE status = '"resolved"'
   AND EXTRACT(dow FROM date) = 0
   AND date >= current_date - interval '3 months'
  GROUP BY type, date
 ORDER BY date, type;

SELECT date,
       type,
       (points - lag(points) OVER (ORDER BY date)) as maint_points,
       NULL::int as new_points
  INTO col_maintenance_delta
  FROM col_maintenance_week
 WHERE type='Maintenance'
 ORDER BY date, type;

UPDATE col_maintenance_delta a
   SET new_points = (SELECT points
                       FROM (SELECT date,
                                    points - lag(points) OVER (ORDER BY date) as points
                               FROM col_maintenance_week
                              WHERE type='New Project') as b
                      WHERE a.date = b.date);

COPY (
SELECT date,
       maint_frac
  FROM (
SELECT date,
       maint_points::float / (maint_points + new_points) as maint_frac
  FROM col_maintenance_delta
  ) as col_maintenance_fraction
) TO '/tmp/col_maintenance_fraction.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT ROUND(100 * maint_points::decimal / (maint_points + new_points),0) as "Total Maintenance Fraction"
  FROM (SELECT sum(maint_points) as maint_points
          FROM col_maintenance_delta) as x
 CROSS JOIN 
       (SELECT sum(new_points)  as new_points
	  FROM col_maintenance_delta) as y
) TO '/tmp/col_maintenance_fraction_total.csv' DELIMITER ',' CSV;

/* ####################################################################
Lead Time

These queries are for a variety of age-of-backlog charts.  They are slow,
and not essential and so disabled for the moment.

This is also used for statistics of recently resolved tasks (histo-whatever)
since it's the only way to identify recently resolved tasks 
 */

-- DROP TABLE IF EXISTS col_leadtime;
-- DROP TABLE IF EXISTS col_statushist;
-- DROP TABLE IF EXISTS col_openage_specific;

-- SELECT th.date,
--        th.points,
--        th.id,
--        lag(th.id) OVER (ORDER BY th.id, th.date ASC) as prev_id,
--        th.status,
--        lag(th.status) OVER (ORDER BY th.id, th.date ASC) as prev_status
--   INTO col_statushist
--   FROM col_task_history th
--  ORDER BY th.id, th.date ASC;

-- SELECT id,
--        status,
--        prev_status,
--        points,
--        date AS resolcol_date,
--        (SELECT min(date)
--           FROM col_task_history th2
--          WHERE th2.id = th1.id
--            AND status = '"open"') as open_date
--   INTO col_leadtime
--   FROM col_statushist as th1
--  WHERE prev_status = '"open"'
--    AND status = '"resolved"'
--    AND id = prev_id;

-- /* This takes forever and the data isn't very useful.
-- DROP TABLE IF EXISTS col_openage;
-- SELECT id,
--        points,
--        date,
--        (SELECT min(date)
--           FROM col_task_history th2
--          WHERE th2.id = th1.id
--            AND status = '"open"') as open_date
--   INTO col_openage
--   FROM col_task_history as th1
--  WHERE status = '"open"'; */

-- SELECT id,
--        points,
--        date,
--        (SELECT min(date)
--           FROM col_task_history th2
--          WHERE th2.id = th1.id
--            AND status = '"open"') as open_date
--   INTO col_openage_specific
--   FROM col_task_history as th1
--  WHERE status = '"open"'
--    AND NOT (project='VisualEditor' AND projectcolumn NOT SIMILAR TO 'TR%');

-- COPY (SELECT SUM(points)/7 as points,
--              width_bucket(extract(days from (current_date - open_date)),1,365,12) as age,
--              date_trunc('week', date) as week
--         FROM col_openage_specific
--        GROUP BY age, week
--        ORDER by week, age)
-- TO '/tmp/col_age_of_backlog_specific.csv' DELIMITER ',' CSV HEADER;

-- COPY (SELECT SUM(points) as points,
--              width_bucket(extract(days from (resolcol_date - open_date)),1,70,7) as leadtime,
--              date_trunc('week', resolcol_date) AS week
--         FROM col_leadtime
--        GROUP BY leadtime, week
--        ORDER by week, leadtime)
-- TO '/tmp/col_leadtime.csv' DELIMITER ',' CSV HEADER;

-- COPY (SELECT date_trunc('week', resolcol_date) AS week,
--             count(points) as count,
--             points
--        FROM col_leadtime
--       GROUP BY points, week
--       ORDER BY week, points)
-- TO '/tmp/col_age_of_resolved_count.csv' DELIMITER ',' CSV HEADER;

-- COPY (SELECT date_trunc('week', resolcol_date) AS week,
--             sum(points) as sumpoints,
--             points
--        FROM col_leadtime
--       GROUP BY points, week
--       ORDER BY week, points)
-- TO '/tmp/col_age_of_resolved.csv' DELIMITER ',' CSV HEADER;
*/

/* Queries actually used for forecasting - data is copied to spreadsheet */

/* Assumes that data is current; in theory we could use max_date in the
data as the baseline instead of current_data but that's probably
something for the plpgsql port */

COPY (
SELECT SUM(velocity)/3 AS min_velocity
  FROM (SELECT velocity 
          FROM col_velocity_delta
         WHERE date >= current_date - interval '3 months'
           AND velocity <> 0 
         ORDER BY velocity 
         LIMIT 3) as x)
TO '/tmp/col_min.csv' DELIMITER ',' CSV;

COPY (
SELECT SUM(velocity)/3 AS max_velocity
  FROM (SELECT velocity 
          FROM col_velocity_delta
         WHERE date >= current_date - interval '3 months'
           AND velocity <> 0 
         ORDER BY velocity DESC
         LIMIT 3) as x)
TO '/tmp/col_max.csv' DELIMITER ',' CSV;

COPY (
SELECT AVG(velocity) AS avg_velocity
  FROM (SELECT velocity 
          FROM col_velocity_delta
         WHERE date >= current_date - interval '3 months'
           AND velocity <> 0 
         ORDER BY velocity)
         as x)
TO '/tmp/col_avg.csv' DELIMITER ',' CSV;

COPY (
SELECT category,
       SUM(points) AS open_backlog
  FROM col_tall_backlog
 WHERE status='"open"'
   AND date=(SELECT MAX(date)
               FROM col_task_history)
 GROUP BY category
 ORDER BY category)
 TO '/tmp/col_backlog_current.csv' DELIMITER ',' CSV HEADER;


/* Report on the most recent date to catch some simple errors */
COPY (
SELECT MAX(date)
  FROM col_task_history)
TO '/tmp/col_max_date.csv' DELIMITER ',' CSV;


