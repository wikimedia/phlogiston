COPY (
SELECT date,
       category,
       SUM(points) as points,
       SUM(count) as count
  FROM tall_backlog
 WHERE source = :'prefix'
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/phlog/backlog.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(points) as points,
       SUM(count) as count
  FROM tall_backlog
 WHERE status = '"resolved"'
   AND source = :'prefix'
 GROUP BY date
 ORDER BY date
) to '/tmp/phlog/burnup.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       SUM(points) as points
  FROM tall_backlog
 WHERE status = '"resolved"'
   AND source = :'prefix'
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/phlog/burnup_categories.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
   Maintenance fraction
Divide all resolved work into Maintenance or New Project, by week. */

DROP TABLE IF EXISTS maintenance_week;
DROP TABLE IF EXISTS maintenance_delta;

SELECT date,
       CASE WHEN category = 'TR0: Interrupt' then 'Maintenance'
            ELSE 'New Project'
       END as type,
       SUM(points) as points
  INTO maintenance_week
  FROM tall_backlog
  WHERE status = '"resolved"'
   AND EXTRACT(dow FROM date) = 0
   AND date >= current_date - interval '3 months'
   AND source = :'prefix'
 GROUP BY type, date
 ORDER BY date, type;

SELECT date,
       type,
       (points - lag(points) OVER (ORDER BY date)) as maint_points,
       NULL::int as new_points
  INTO maintenance_delta
  FROM maintenance_week
 WHERE type='Maintenance'
 ORDER BY date, type;

UPDATE maintenance_delta a
   SET new_points = (SELECT points
                       FROM (SELECT date,
                                    points - lag(points) OVER (ORDER BY date) as points
                               FROM maintenance_week
                              WHERE type='New Project') as b
                      WHERE a.date = b.date);

COPY (
SELECT date,
       maint_frac
  FROM (
SELECT date,
       maint_points::float / (maint_points + new_points) as maint_frac
  FROM maintenance_delta
  ) as maintenance_fraction
) TO '/tmp/phlog/maintenance_fraction.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT ROUND(100 * maint_points::decimal / (maint_points + new_points),0) as "Total Maintenance Fraction"
  FROM (SELECT sum(maint_points) as maint_points
          FROM maintenance_delta) as x
 CROSS JOIN 
       (SELECT sum(new_points)  as new_points
	  FROM maintenance_delta) as y
) TO '/tmp/phlog/maintenance_fraction_total.csv' DELIMITER ',' CSV;

/* ####################################################################
Burnup and Velocity */

DROP TABLE IF EXISTS velocity_week;
DROP TABLE IF EXISTS velocity_delta;

SELECT date,
       SUM(points) AS points,
       SUM(count) AS count
  INTO velocity_week
  FROM tall_backlog
 WHERE status = '"resolved"'
   AND EXTRACT(dow from date) = 0 
   AND date >= current_date - interval '3 months'
 GROUP BY date
 ORDER BY date;

SELECT date,
       (points - lag(points) OVER (ORDER BY date)) as points,
       (count - lag(count) OVER (ORDER BY date)) as count,
       NULL::int as velocity_points,
       NULL::int as velocity_count
  INTO velocity_delta
  FROM velocity_week
 ORDER BY date;

UPDATE velocity_delta a
   SET velocity_points = (SELECT points
                       FROM (SELECT date,
                                    points - lag(points) OVER (ORDER BY date) as points
                               FROM velocity_week
                             ) as b
                      WHERE a.date = b.date);

UPDATE velocity_delta a
   SET velocity_count = (SELECT count
                       FROM (SELECT date,
                                    count - lag(count) OVER (ORDER BY date) as count
                               FROM velocity_week
                             ) as b
                      WHERE a.date = b.date);

COPY (
SELECT date,
       velocity_points,
       velocity_count
  FROM velocity_delta
) TO '/tmp/phlog/velocity.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Backlog growth calculations */

DROP TABLE IF EXISTS backlog_size;

SELECT date,
       SUM(points) AS points
  INTO backlog_size
  FROM tall_backlog
 WHERE status != '"resolved"'
   AND EXTRACT(dow from date) = 0 
 GROUP BY date
 ORDER BY date;

COPY (
SELECT date,
       (points - lag(points) OVER (ORDER BY date)) as points
  FROM backlog_size
 ORDER BY date
) to '/tmp/phlog/net_growth.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Recently Closed */

DROP TABLE IF EXISTS recently_closed;

CREATE TABLE recently_closed (
    date date,
    category text,
    points int,
    task_count int
);

COPY (
SELECT date,
       category,
       points
  FROM recently_closed
 ORDER BY date, category
) to '/tmp/phlog/recently_closed.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Lead Time

These queries are for a variety of age-of-backlog charts.  They are slow,
and not essential and so disabled for the moment.

This is also used for statistics of recently resolved tasks (histo-whatever)
since it's the only way to identify recently resolved tasks 
 */

-- DROP TABLE IF EXISTS leadtime;
-- DROP TABLE IF EXISTS statushist;
-- DROP TABLE IF EXISTS openage_specific;

-- SELECT th.date,
--        th.points,
--        th.id,
--        lag(th.id) OVER (ORDER BY th.id, th.date ASC) as prev_id,
--        th.status,
--        lag(th.status) OVER (ORDER BY th.id, th.date ASC) as prev_status
--   INTO statushist
--   FROM task_history th
--  ORDER BY th.id, th.date ASC;

-- SELECT id,
--        status,
--        prev_status,
--        points,
--        date AS resoldate,
--        (SELECT min(date)
--           FROM task_history th2
--          WHERE th2.id = th1.id
--            AND status = '"open"') as open_date
--   INTO leadtime
--   FROM statushist as th1
--  WHERE prev_status = '"open"'
--    AND status = '"resolved"'
--    AND id = prev_id;

-- /* This takes forever and the data isn't very useful.
-- DROP TABLE IF EXISTS openage;
-- SELECT id,
--        points,
--        date,
--        (SELECT min(date)
--           FROM task_history th2
--          WHERE th2.id = th1.id
--            AND status = '"open"') as open_date
--   INTO openage
--   FROM task_history as th1
--  WHERE status = '"open"'; */

-- SELECT id,
--        points,
--        date,
--        (SELECT min(date)
--           FROM task_history th2
--          WHERE th2.id = th1.id
--            AND status = '"open"') as open_date
--   INTO openage_specific
--   FROM task_history as th1
--  WHERE status = '"open"'
--    AND NOT (project='VisualEditor' AND projectcolumn NOT SIMILAR TO 'TR%');

-- COPY (SELECT SUM(points)/7 as points,
--              width_bucket(extract(days from (current_date - open_date)),1,365,12) as age,
--              date_trunc('week', date) as week
--         FROM openage_specific
--        GROUP BY age, week
--        ORDER by week, age)
-- TO '/tmp/phlog/age_of_backlog_specific.csv' DELIMITER ',' CSV HEADER;

-- COPY (SELECT SUM(points) as points,
--              width_bucket(extract(days from (resoldate - open_date)),1,70,7) as leadtime,
--              date_trunc('week', resoldate) AS week
--         FROM leadtime
--        GROUP BY leadtime, week
--        ORDER by week, leadtime)
-- TO '/tmp/phlog/leadtime.csv' DELIMITER ',' CSV HEADER;

-- COPY (SELECT date_trunc('week', resoldate) AS week,
--             count(points) as count,
--             points
--        FROM leadtime
--       GROUP BY points, week
--       ORDER BY week, points)
-- TO '/tmp/phlog/age_of_resolved_count.csv' DELIMITER ',' CSV HEADER;

-- COPY (SELECT date_trunc('week', resoldate) AS week,
--             sum(points) as sumpoints,
--             points
--        FROM leadtime
--       GROUP BY points, week
--       ORDER BY week, points)
-- TO '/tmp/phlog/age_of_resolved.csv' DELIMITER ',' CSV HEADER;

-- /* Queries actually used for forecasting - data is copied to spreadsheet */

-- SHOULD BE REPLACED BY CONEWORMS

-- /* Assumes that data is current; in theory we could use max_date in the
-- data as the baseline instead of current_data but that's probably
-- something for the plpgsql port */

-- COPY (
-- SELECT SUM(velocity_points)/3 AS min_velocity
--   FROM (SELECT velocity_points 
--           FROM velocity_delta
--          WHERE date >= current_date - interval '3 months'
--            AND velocity_points <> 0 
--          ORDER BY velocity_points 
--          LIMIT 3) as x)
-- TO '/tmp/phlog/min.csv' DELIMITER ',' CSV;

-- COPY (
-- SELECT SUM(velocity_points)/3 AS max_velocity
--   FROM (SELECT velocity_points
--           FROM velocity_delta
--          WHERE date >= current_date - interval '3 months'
--            AND velocity_points <> 0 
--          ORDER BY velocity_points DESC
--          LIMIT 3) as x)
-- TO '/tmp/phlog/max.csv' DELIMITER ',' CSV;

-- COPY (
-- SELECT AVG(velocity_points) AS avg_velocity
--   FROM (SELECT velocity_points 
--           FROM velocity_delta
--          WHERE date >= current_date - interval '3 months'
--            AND velocity_points <> 0 
--          ORDER BY velocity_points)
--          as x)
-- TO '/tmp/phlog/avg.csv' DELIMITER ',' CSV;

-- COPY (
-- SELECT projectcolumn,
--        SUM(points) AS open_backlog
--   FROM task_history
--  WHERE projectcolumn SIMILAR TO 'TR%'
--    AND status='"open"'
--    AND date=(SELECT MAX(date)
--                FROM task_history)
--  GROUP BY projectcolumn
--  ORDER BY projectcolumn)
--  TO '/tmp/phlog/backlog_current.csv' DELIMITER ',' CSV HEADER;
