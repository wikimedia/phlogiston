COPY (
SELECT date,
       t.category,
       MAX(z.sort_order) as sort_order,
       SUM(points) as points,
       SUM(count) as count,
       BOOL_OR(z.zoom) as zoom
  FROM tall_backlog t, category_list z
 WHERE t.source = :'prefix'
   AND z.source = :'prefix'
   AND t.source = z.source
   AND t.category = z.category
 GROUP BY date, t.category
 ORDER BY sort_order, date
) TO '/tmp/phlog/backlog.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(points) as points,
       SUM(count) as count
  FROM tall_backlog
 WHERE status = '"resolved"'
   AND source = :'prefix'
   AND category IN (SELECT category
                      FROM category_list
                     WHERE source = :'prefix'
                       AND zoom = True)
 GROUP BY date
 ORDER BY date
) TO '/tmp/phlog/burnup_zoom.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(points) as points,
       SUM(count) as count
  FROM tall_backlog
 WHERE status = '"resolved"'
   AND source = :'prefix'
   AND category IN (SELECT category
                      FROM category_list
                     WHERE source = :'prefix')
 GROUP BY date
 ORDER BY date
) TO '/tmp/phlog/burnup.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       SUM(points) as points,
       SUM(count) as count
  FROM tall_backlog
 WHERE status = '"resolved"'
   AND source = :'prefix'
   AND category in (SELECT category
                      FROM category_list
                     WHERE source = :'prefix')
 GROUP BY date, category
 ORDER BY category, date
) TO '/tmp/phlog/burnup_categories.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT COUNT(*),
       milestone_title,
       project,
       projectcolumn
  FROM task_history
 WHERE source = :'prefix'
 GROUP BY milestone_title, project, projectcolumn
 ORDER BY milestone_title, project, projectcolumn
) TO '/tmp/phlog/category_possibilities.txt';

/* ####################################################################
   Maintenance fraction
Divide all resolved work into Maintenance or New Project, by week. */

DELETE FROM maintenance_week where source = :'prefix';
DELETE FROM maintenance_delta where source = :'prefix';

INSERT INTO maintenance_week (
SELECT source,
       date,
       maint_type,
       SUM(points) as points,
       SUM(count) as count
  FROM tall_backlog
 WHERE status = '"resolved"'
   AND EXTRACT(epoch FROM age(date - INTERVAL '1 day'))/604800 = ROUND(
       EXTRACT(epoch FROM age(date - INTERVAL '1 day'))/604800)
   AND date >= current_date - interval '3 months'
   AND source = :'prefix'
 GROUP BY maint_type, date, source
);

INSERT INTO maintenance_delta (
SELECT source,
       date,
       maint_type,
       (points - lag(points) OVER (ORDER BY date)) as maint_points,
       null,
       (count - lag(count) OVER (ORDER BY date)) as maint_count
  FROM maintenance_week
 WHERE maint_type='Maintenance'
   AND source = :'prefix'
 ORDER BY date, maint_type, source
);



UPDATE maintenance_delta a
   SET new_points = (SELECT points
                       FROM (SELECT date,
                                    points - lag(points) OVER (ORDER BY date) as points
                               FROM maintenance_week
                              WHERE maint_type='New Functionality'
                                AND source = :'prefix') as b
                      WHERE a.date = b.date
                        AND source = :'prefix');

UPDATE maintenance_delta a
   SET new_count = (SELECT count
                       FROM (SELECT date,
                                    count - lag(count) OVER (ORDER BY date) as count
                               FROM maintenance_week
                              WHERE maint_type='New Functionality'
                                AND source = :'prefix') as b
                      WHERE a.date = b.date
                        AND source = :'prefix');

COPY (
SELECT source,
       date,
       maint_type,
       count - LAG(count) OVER (PARTITION BY maint_type ORDER BY date) AS count,
       points - LAG(points) OVER (PARTITION BY maint_type ORDER BY date) AS points
  FROM maintenance_week
 WHERE source = :'prefix'
 ORDER BY date, maint_type
 ) TO '/tmp/phlog/maintenance_proportion.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       maint_frac_points,
       maint_frac_count
  FROM (
SELECT date,
       maint_points::float / nullif((maint_points + new_points),0) as maint_frac_points,
       maint_count::float / nullif((maint_count + new_count),0) as maint_frac_count
  FROM maintenance_delta
 WHERE source = :'prefix' ) as maintenance_fraction
) TO '/tmp/phlog/maintenance_fraction.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT ROUND(100 * maint_points::decimal / nullif((maint_points + new_points),0),0) as "Total Maintenance Fraction by Points"
  FROM (SELECT sum(maint_points) as maint_points
          FROM maintenance_delta
         WHERE source = :'prefix') as x
 CROSS JOIN 
       (SELECT sum(new_points)  as new_points
	     FROM maintenance_delta
         WHERE source = :'prefix') as y
) TO '/tmp/phlog/maintenance_fraction_total_by_points.csv' DELIMITER ',' CSV;

COPY (
SELECT ROUND(100 * maint_count::decimal / nullif((maint_count + new_count),0),0) as "Total Maintenance Fraction by Count"
  FROM (SELECT sum(maint_count) as maint_count
          FROM maintenance_delta
         WHERE source = :'prefix') as x
 CROSS JOIN 
       (SELECT sum(new_count)  as new_count
	     FROM maintenance_delta
         WHERE source = :'prefix') as y
) TO '/tmp/phlog/maintenance_fraction_total_by_count.csv' DELIMITER ',' CSV;

/* ####################################################################
Backlog growth calculations */

INSERT INTO open_backlog_size (
SELECT source,
       category,
       date,
       SUM(points) AS points,
       SUM(count) AS count
  FROM tall_backlog
 WHERE status != '"resolved"'
   AND EXTRACT(epoch FROM age(date - INTERVAL '1 day'))/604800 = ROUND(
       EXTRACT(epoch FROM age(date - INTERVAL '1 day'))/604800)
   AND source = :'prefix'
 GROUP BY date, source, category);

UPDATE open_backlog_size
   SET delta_points = COALESCE(subq.delta_points,0),
       delta_count = COALESCE(subq.delta_count,0)
  FROM (SELECT source,
               date,
               category,
               count - lag(count) OVER (PARTITION BY source, category ORDER BY date) as delta_count,
               points - lag(points) OVER (PARTITION BY source, category ORDER BY date) as delta_points
	  FROM open_backlog_size
	 WHERE source = :'prefix') as subq
  WHERE open_backlog_size.source = subq.source
    AND open_backlog_size.date = subq.date
    AND open_backlog_size.category = subq.category;   

COPY (
SELECT date,
       sum(delta_points) as points,
       sum(delta_count) as count
  FROM open_backlog_size
 WHERE source = :'prefix'
 GROUP BY date
 ORDER BY date
) to '/tmp/phlog/net_growth.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Burnup and Velocity and Forecasts */

SELECT calculate_velocities(:'prefix');
			      
COPY (
SELECT date,
       sum(delta_points) as points,
       sum(delta_count) as count
  FROM velocity
 WHERE source = :'prefix'
 GROUP BY date
 ORDER BY date
) TO '/tmp/phlog/velocity.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       delta_points as points,
       delta_count as count
  FROM velocity
 WHERE source = :'prefix'
 ORDER BY category, date
) TO '/tmp/phlog/tranche_velocity.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       opt_points_vel,
       nom_points_vel,
       pes_points_vel
  FROM velocity
 WHERE source = :'prefix'
 ORDER BY category, date
) TO '/tmp/phlog/tranche_velocity_points.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       opt_count_vel,
       nom_count_vel,
       pes_count_vel
  FROM velocity
 WHERE source = :'prefix'
 ORDER BY category, date
) TO '/tmp/phlog/tranche_velocity_count.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       EXTRACT(epoch FROM age(date - INTERVAL '1 day'))/604800 as weeks_old,
       v.category,
       z.zoom,
       sort_order,
       opt_points_fore,
       nom_points_fore,
       pes_points_fore,
       opt_count_fore,
       nom_count_fore,
       pes_count_fore,
       pes_points_date,
       nom_points_date,
       opt_points_date,
       pes_count_date,
       nom_count_date,
       opt_count_date
  FROM velocity v, category_list z
 WHERE z.category = v.category
   AND z.source = :'prefix'
 ORDER BY date
) to '/tmp/phlog/forecast.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT z.category,
       z.zoom,
       z.sort_order,
       first.first_open_date,
       last.last_open_date + INTERVAL '1 week' as resolved_date
  FROM category_list z
  LEFT OUTER JOIN (SELECT category,
                          MIN(date) as first_open_date
                     FROM tall_backlog
                    WHERE source = :'prefix'
                      AND status = '"open"'
                    GROUP BY category) AS first ON (z.category = first.category)
  LEFT OUTER JOIN (SELECT category,
                          MAX(date) as last_open_date
                     FROM tall_backlog
                    WHERE source = :'prefix'
                      AND status = '"open"'
                    GROUP BY category) AS last ON (z.category = last.category AND
                                                date_trunc('day', last_open_date) <> (SELECT MAX(date) FROM tall_backlog WHERE source = :'prefix'))
WHERE source = :'prefix'
ORDER BY sort_order
) TO '/tmp/phlog/forecast_done.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Recently Closed */

COPY (
SELECT rc.date,
       z.sort_order as priority,
       '(' || z.sort_order || ') ' || rc.category as category,
       rc.points,
       rc.count
  FROM recently_closed rc LEFT OUTER JOIN category_list z USING (source, category)
 WHERE source = :'prefix'
   AND date >= current_date - interval '3 months'
 ORDER BY date, sort_order
) to '/tmp/phlog/recently_closed.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Points Histogram */

COPY (
SELECT COUNT(points) as count,
       points
  FROM (
SELECT MAX(points) as points
  FROM task_history
 WHERE id in (SELECT DISTINCT id
                FROM task_history
               WHERE source = :'prefix')
   AND status = '"resolved"'
 GROUP BY id) AS point_query
 GROUP BY points
 ORDER BY points
) to '/tmp/phlog/points_histogram.csv' DELIMITER ',' CSV HEADER;

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

