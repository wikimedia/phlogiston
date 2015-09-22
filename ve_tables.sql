/* This script assumes that all tasks in the database are relevant to the VisualEditor team */

/* Apply some filtering to the raw data */

UPDATE ve_task_history
   SET status = '"open"'
 WHERE status = '"stalled"';

DELETE FROM ve_task_history
 WHERE status = '"duplicate"'
    OR status = '"invalid"'
    OR status = '"declined"';

/* ##################################################################
Roll up the task history from individual tasks to cumulative totals.

Each row is the cumulative point total for one day for one project and
projectcolumn and status 

Apply current work breakdown to historical data.  VE has used both
project and projectcolumn to categorize work; this script condenses
both into a single new field called category. */

DROP TABLE IF EXISTS ve_tall_backlog;
 
/* Between January 2015 and June 2015, planned VE work was tracked in
projects called "VisualEditor 2014/15 Q3 blockers" and
"VisualEditor 2014/15 Q4 blockers".   This query should get everything
from those projects. */

SELECT date,
       project as category,
       status,
       SUM(points) as points
  INTO ve_tall_backlog
  FROM ve_task_history
 WHERE project != 'VisualEditor'
 GROUP BY status, category, date;

/* Prior to 18 June 2015, VE work in the VisualEditor project was not
organized around the interrupt or maintenance, so all work in that
project prior to that date can be considered General Backlog,
regardless of state or column.  The nested select is required to
accurately group by category, after category is forced to a constant
in the inner select. */

INSERT INTO ve_tall_backlog (date, category, status, points) (
SELECT date,
       category,
       status,
       SUM(points) as points
  FROM (
SELECT date,
       CAST('General Backlog' AS text) as category,
       status,
       points
  FROM ve_task_history
 WHERE project = 'VisualEditor'
   AND date < '2015-06-18') as ve_old_other
 GROUP BY status, category, date);

/* Since June 18, 2018, the projectcolumn in the VisualEditor project
should be accurate, so any VE task in a Tranche should use the tranche
as the category. */

INSERT INTO ve_tall_backlog (date, category, status, points) (
SELECT date,
       projectcolumn as category,
       status,
       SUM(points) as points
  FROM ve_task_history
 WHERE project = 'VisualEditor'
   AND projectcolumn SIMILAR TO 'TR%'
   AND date >= '2015-06-18'
GROUP BY status, category, date);

/* Any other tasks in the VisualEditor project (i.e., any task after
June 18th and not in a tranche) should be old data getting cleaned up.
We will essentially ignore them by placing them in General Backlog.
*/

INSERT INTO ve_tall_backlog (date, category, status, points) (
SELECT date,
       category,
       status,
       SUM(points) as points
  FROM (
SELECT date,
       CAST('General Backlog' AS text) as category,
       status,
       points
  FROM ve_task_history
 WHERE project = 'VisualEditor'
   AND projectcolumn NOT SIMILAR TO 'TR%'
   AND date >= '2015-06-18') AS ve_new_uncategorized
GROUP BY status, category, date);

COPY (
SELECT date,
       category,
       SUM(points) as points
  FROM ve_tall_backlog
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/ve_backlog.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       SUM(points) as points
  FROM ve_tall_backlog
 WHERE category <> 'General Backlog'
   AND category NOT SIMILAR TO 'TR0%'
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/ve_backlog_zoomed.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(points) as points
  FROM ve_tall_backlog
 WHERE status = '"resolved"'
 GROUP BY date
 ORDER BY date
) to '/tmp/ve_burnup.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       SUM(points) as points
  FROM ve_tall_backlog
 WHERE status = '"resolved"'
 GROUP BY date, category
 ORDER BY date, category
) to '/tmp/ve_burnup_categories.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(points) as points
  FROM ve_tall_backlog
 WHERE status = '"resolved"'
   AND category NOT LIKE 'TR0%'
   AND category NOT LIKE 'General Backlog'
GROUP BY date
 ORDER BY date
) to '/tmp/ve_burnup_zoomed.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
   Maintenance fraction
Divide all resolved work into Maintenance or New Project, by week. */

DROP TABLE IF EXISTS ve_maintenance_week;
DROP TABLE IF EXISTS ve_maintenance_delta;

SELECT date,
       CASE WHEN category = 'TR0: Interrupt' then 'Maintenance'
            ELSE 'New Project'
       END as type,
       SUM(points) as points
  INTO ve_maintenance_week
  FROM ve_tall_backlog
  WHERE status = '"resolved"'
   AND EXTRACT(dow FROM date) = 0
   AND date >= current_date - interval '3 months'
  GROUP BY type, date
 ORDER BY date, type;

SELECT date,
       type,
       (points - lag(points) OVER (ORDER BY date)) as maint_points,
       NULL::int as new_points
  INTO ve_maintenance_delta
  FROM ve_maintenance_week
 WHERE type='Maintenance'
 ORDER BY date, type;

UPDATE ve_maintenance_delta a
   SET new_points = (SELECT points
                       FROM (SELECT date,
                                    points - lag(points) OVER (ORDER BY date) as points
                               FROM ve_maintenance_week
                              WHERE type='New Project') as b
                      WHERE a.date = b.date);

COPY (
SELECT date,
       maint_frac
  FROM (
SELECT date,
       maint_points::float / (maint_points + new_points) as maint_frac
  FROM ve_maintenance_delta
  ) as ve_maintenance_fraction
) TO '/tmp/ve_maintenance_fraction.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT ROUND(100 * maint_points::decimal / (maint_points + new_points),0) as "Total Maintenance Fraction"
  FROM (SELECT sum(maint_points) as maint_points
          FROM ve_maintenance_delta) as x
 CROSS JOIN 
       (SELECT sum(new_points)  as new_points
	  FROM ve_maintenance_delta) as y
) TO '/tmp/ve_maintenance_fraction_total.csv' DELIMITER ',' CSV;

/* ####################################################################
Burnup and Velocity */

DROP TABLE IF EXISTS ve_velocity_week;
DROP TABLE IF EXISTS ve_velocity_delta;

SELECT date,
       SUM(points) AS points
  INTO ve_velocity_week
  FROM ve_tall_backlog
 WHERE status = '"resolved"'
   AND EXTRACT(dow from date) = 0 
   AND date >= current_date - interval '3 months'
 GROUP BY date
 ORDER BY date;

SELECT date,
       (points - lag(points) OVER (ORDER BY date)) as points,
       NULL::int as velocity
  INTO ve_velocity_delta
  FROM ve_velocity_week
 ORDER BY date;

UPDATE ve_velocity_delta a
   SET velocity = (SELECT points
                       FROM (SELECT date,
                                    points - lag(points) OVER (ORDER BY date) as points
                               FROM ve_velocity_week
                             ) as b
                      WHERE a.date = b.date);

COPY (
SELECT date,
       velocity
  FROM ve_velocity_delta
) TO '/tmp/ve_velocity.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Backlog growth calculations */

DROP TABLE IF EXISTS ve_backlog_size;

SELECT date,
       SUM(points) AS points
  INTO ve_backlog_size
  FROM ve_tall_backlog
 WHERE status != '"resolved"'
   AND EXTRACT(dow from date) = 0 
 GROUP BY date
 ORDER BY date;

COPY (
SELECT date,
       (points - lag(points) OVER (ORDER BY date)) as points
  FROM ve_backlog_size
 ORDER BY date
) to '/tmp/ve_net_growth.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Lead Time

These queries are for a variety of age-of-backlog charts.  They are slow,
and not essential and so disabled for the moment.

This is also used for statistics of recently resolved tasks (histo-whatever)
since it's the only way to identify recently resolved tasks 
 */

-- DROP TABLE IF EXISTS ve_leadtime;
-- DROP TABLE IF EXISTS ve_statushist;
-- DROP TABLE IF EXISTS ve_openage_specific;

-- SELECT th.date,
--        th.points,
--        th.id,
--        lag(th.id) OVER (ORDER BY th.id, th.date ASC) as prev_id,
--        th.status,
--        lag(th.status) OVER (ORDER BY th.id, th.date ASC) as prev_status
--   INTO ve_statushist
--   FROM ve_task_history th
--  ORDER BY th.id, th.date ASC;

-- SELECT id,
--        status,
--        prev_status,
--        points,
--        date AS resolve_date,
--        (SELECT min(date)
--           FROM ve_task_history th2
--          WHERE th2.id = th1.id
--            AND status = '"open"') as open_date
--   INTO ve_leadtime
--   FROM ve_statushist as th1
--  WHERE prev_status = '"open"'
--    AND status = '"resolved"'
--    AND id = prev_id;

-- /* This takes forever and the data isn't very useful.
-- DROP TABLE IF EXISTS ve_openage;
-- SELECT id,
--        points,
--        date,
--        (SELECT min(date)
--           FROM ve_task_history th2
--          WHERE th2.id = th1.id
--            AND status = '"open"') as open_date
--   INTO ve_openage
--   FROM ve_task_history as th1
--  WHERE status = '"open"'; */

-- SELECT id,
--        points,
--        date,
--        (SELECT min(date)
--           FROM ve_task_history th2
--          WHERE th2.id = th1.id
--            AND status = '"open"') as open_date
--   INTO ve_openage_specific
--   FROM ve_task_history as th1
--  WHERE status = '"open"'
--    AND NOT (project='VisualEditor' AND projectcolumn NOT SIMILAR TO 'TR%');

-- COPY (SELECT SUM(points)/7 as points,
--              width_bucket(extract(days from (current_date - open_date)),1,365,12) as age,
--              date_trunc('week', date) as week
--         FROM ve_openage_specific
--        GROUP BY age, week
--        ORDER by week, age)
-- TO '/tmp/ve_age_of_backlog_specific.csv' DELIMITER ',' CSV HEADER;

-- COPY (SELECT SUM(points) as points,
--              width_bucket(extract(days from (resolve_date - open_date)),1,70,7) as leadtime,
--              date_trunc('week', resolve_date) AS week
--         FROM ve_leadtime
--        GROUP BY leadtime, week
--        ORDER by week, leadtime)
-- TO '/tmp/ve_leadtime.csv' DELIMITER ',' CSV HEADER;

-- COPY (SELECT date_trunc('week', resolve_date) AS week,
--             count(points) as count,
--             points
--        FROM ve_leadtime
--       GROUP BY points, week
--       ORDER BY week, points)
-- TO '/tmp/ve_age_of_resolved_count.csv' DELIMITER ',' CSV HEADER;

-- COPY (SELECT date_trunc('week', resolve_date) AS week,
--             sum(points) as sumpoints,
--             points
--        FROM ve_leadtime
--       GROUP BY points, week
--       ORDER BY week, points)
-- TO '/tmp/ve_age_of_resolved.csv' DELIMITER ',' CSV HEADER;

/* Queries actually used for forecasting - data is copied to spreadsheet */

/* Assumes that data is current; in theory we could use max_date in the
data as the baseline instead of current_data but that's probably
something for the plpgsql port */

COPY (
SELECT SUM(velocity)/3 AS min_velocity
  FROM (SELECT velocity 
          FROM ve_velocity_delta
         WHERE date >= current_date - interval '3 months'
           AND velocity <> 0 
         ORDER BY velocity 
         LIMIT 3) as x)
TO '/tmp/ve_min.csv' DELIMITER ',' CSV;

COPY (
SELECT SUM(velocity)/3 AS max_velocity
  FROM (SELECT velocity 
          FROM ve_velocity_delta
         WHERE date >= current_date - interval '3 months'
           AND velocity <> 0 
         ORDER BY velocity DESC
         LIMIT 3) as x)
TO '/tmp/ve_max.csv' DELIMITER ',' CSV;

COPY (
SELECT AVG(velocity) AS avg_velocity
  FROM (SELECT velocity 
          FROM ve_velocity_delta
         WHERE date >= current_date - interval '3 months'
           AND velocity <> 0 
         ORDER BY velocity)
         as x)
TO '/tmp/ve_avg.csv' DELIMITER ',' CSV;

COPY (
SELECT projectcolumn,
       SUM(points) AS open_backlog
  FROM ve_task_history
 WHERE projectcolumn SIMILAR TO '%TR(1|2|3|4)%'
   AND status='"open"'
   AND date=(SELECT MAX(date)
               FROM ve_task_history)
 GROUP BY projectcolumn
 ORDER BY projectcolumn)
 TO '/tmp/ve_backlog_current.csv' DELIMITER ',' CSV HEADER;

/* Report on the most recent date to catch some simple errors */
COPY (
SELECT MAX(date)
  FROM ve_task_history)
TO '/tmp/ve_max_date.csv' DELIMITER ',' CSV;

