COPY (
SELECT date,
       t.category,
       MAX(z.sort_order) as sort_order,
       SUM(points) as points,
       SUM(count) as count,
       max(z.display) as display
  FROM task_on_date_agg t, category z
 WHERE t.scope = :'scope_prefix'
   AND z.scope = :'scope_prefix'
   AND t.scope = z.scope
   AND t.category = z.title
 GROUP BY date, t.category
 ORDER BY sort_order, date
) TO '/tmp/phlog/backlog.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       sort_order,
       points,
       count,
       SUM(points) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_points,
       SUM(count) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_count
  FROM get_backlog(:'scope_prefix', 'open', 'normal', False)
) TO '/tmp/phlog/burn_open.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       sort_order,
       points,
       count,
       SUM(points) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_points,
       SUM(count) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_count
  FROM get_backlog(:'scope_prefix', 'resolved', 'cutoff', False)
) TO '/tmp/phlog/burn_done.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       sort_order,
       points,
       count,
       SUM(points) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_points,
       SUM(count) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_count
  FROM get_backlog(:'scope_prefix', 'resolved', 'lastq', False)
) TO '/tmp/phlog/burn_done_lastq.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       sort_order,
       points,
       count,
       SUM(points) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_points,
       SUM(count) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_count
  FROM get_backlog(:'scope_prefix', 'open', 'normal', True)
) TO '/tmp/phlog/burn_open_showhidden.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       sort_order,
       points,
       count,
       SUM(points) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_points,
       SUM(count) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_count
  FROM get_backlog(:'scope_prefix', 'resolved', 'cutoff', True)
) TO '/tmp/phlog/burn_done_showhidden.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       sort_order,
       points,
       count,
       SUM(points) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_points,
       SUM(count) OVER (PARTITION BY date ORDER BY sort_order, category) AS label_count
  FROM get_backlog(:'scope_prefix', 'resolved', 'lastq', True)
) TO '/tmp/phlog/burn_done_showhidden_lastq.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(points) as points,
       SUM(count) as count
  FROM task_on_date_agg
 WHERE status = 'resolved'
   AND scope = :'scope_prefix'
   AND category IN (SELECT category
                      FROM category
                     WHERE scope = :'scope_prefix'
                       AND display = 'show')
 GROUP BY date
 ORDER BY date
) TO '/tmp/phlog/burnup.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(points) as points,
       SUM(count) as count
  FROM task_on_date_agg
 WHERE status = 'resolved'
   AND scope = :'scope_prefix'
   AND category IN (SELECT category
                      FROM category
                     WHERE scope = :'scope_prefix')
 GROUP BY date
 ORDER BY date
) TO '/tmp/phlog/burnup_showhidden.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       SUM(points) as points,
       SUM(count) as count
  FROM task_on_date_agg
 WHERE status = 'resolved'
   AND scope = :'scope_prefix'
   AND category in (SELECT category
                      FROM category
                     WHERE scope = :'scope_prefix')
 GROUP BY date, category
 ORDER BY category, date
) TO '/tmp/phlog/burnup_categories.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT COUNT(*),
       category_title,
       project,
       projectcolumn
  FROM task_on_date
 WHERE scope = :'scope_prefix'
 GROUP BY category_title, project, projectcolumn
 ORDER BY category_title, project, projectcolumn
) TO '/tmp/phlog/category_possibilities.txt';

/* ####################################################################
   Maintenance fraction
Divide all resolved work into Maintenance or New Project, by week. */

DELETE FROM maintenance_week where scope = :'scope_prefix';
DELETE FROM maintenance_delta where scope = :'scope_prefix';

INSERT INTO maintenance_week (
SELECT scope,
       date,
       maint_type,
       SUM(points) as points,
       SUM(count) as count
  FROM task_on_date_agg
 WHERE status = 'resolved'
   AND EXTRACT(epoch FROM age(date))/604800 = ROUND(
       EXTRACT(epoch FROM age(date))/604800)
   AND date >= current_date - interval '3 months'
   AND scope = :'scope_prefix'
 GROUP BY maint_type, date, scope
);

INSERT INTO maintenance_delta (
SELECT scope,
       date,
       maint_type,
       (points - lag(points) OVER (ORDER BY date)) as maint_points,
       null,
       (count - lag(count) OVER (ORDER BY date)) as maint_count
  FROM maintenance_week
 WHERE maint_type='Maintenance'
   AND scope = :'scope_prefix'
 ORDER BY date, maint_type, scope
);


UPDATE maintenance_delta a
   SET new_points = (SELECT points
                       FROM (SELECT date,
                                    points - lag(points) OVER (ORDER BY date) as points
                               FROM maintenance_week
                              WHERE maint_type='New Functionality'
                                AND scope = :'scope_prefix') as b
                      WHERE a.date = b.date
                        AND scope = :'scope_prefix');

UPDATE maintenance_delta a
   SET new_count = (SELECT count
                       FROM (SELECT date,
                                    count - lag(count) OVER (ORDER BY date) as count
                               FROM maintenance_week
                              WHERE maint_type='New Functionality'
                                AND scope = :'scope_prefix') as b
                      WHERE a.date = b.date
                        AND scope = :'scope_prefix');

COPY (
SELECT scope,
       date,
       maint_type,
       count - LAG(count) OVER (PARTITION BY maint_type ORDER BY date) AS count,
       points - LAG(points) OVER (PARTITION BY maint_type ORDER BY date) AS points
  FROM maintenance_week
 WHERE scope = :'scope_prefix'
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
 WHERE scope = :'scope_prefix' ) as maintenance_fraction
) TO '/tmp/phlog/maintenance_fraction.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT ROUND(100 * maint_points::decimal / nullif((maint_points + new_points),0),0) as "Total Maintenance Fraction by Points"
  FROM (SELECT sum(maint_points) as maint_points
          FROM maintenance_delta
         WHERE scope = :'scope_prefix') as x
 CROSS JOIN 
       (SELECT sum(new_points)  as new_points
	     FROM maintenance_delta
         WHERE scope = :'scope_prefix') as y
) TO '/tmp/phlog/maintenance_fraction_total_by_points.csv' DELIMITER ',' CSV;

COPY (
SELECT ROUND(100 * maint_count::decimal / nullif((maint_count + new_count),0),0) as "Total Maintenance Fraction by Count"
  FROM (SELECT sum(maint_count) as maint_count
          FROM maintenance_delta
         WHERE scope = :'scope_prefix') as x
 CROSS JOIN 
       (SELECT sum(new_count)  as new_count
	     FROM maintenance_delta
         WHERE scope = :'scope_prefix') as y
) TO '/tmp/phlog/maintenance_fraction_total_by_count.csv' DELIMITER ',' CSV;

/* ####################################################################
Burnup and Velocity and Forecasts */

SELECT calculate_velocities(:'scope_prefix');

COPY (
SELECT date,
       category,
       delta_points_resolved as points,
       delta_count_resolved as count
  FROM velocity
 WHERE scope = :'scope_prefix'
 ORDER BY category, date
) TO '/tmp/phlog/tranche_velocity.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       opt_points_vel,
       nom_points_vel,
       pes_points_vel
  FROM velocity
 WHERE scope = :'scope_prefix'
 ORDER BY category, date
) TO '/tmp/phlog/tranche_velocity_points.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       category,
       opt_count_vel,
       nom_count_vel,
       pes_count_vel
  FROM velocity
 WHERE scope = :'scope_prefix'
 ORDER BY category, date
) TO '/tmp/phlog/tranche_velocity_count.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       EXTRACT(epoch FROM age(date))/604800 AS weeks_old,
       v.category,
       z.display,
       sort_order,
       points_resolved,
       count_resolved,
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
       opt_count_date,
       pes_points_growviz,
       nom_points_growviz,
       opt_points_growviz,
       pes_count_growviz,
       nom_count_growviz,
       opt_count_growviz,
       pes_points_velviz,
       nom_points_velviz,
       opt_points_velviz,
       pes_count_velviz,
       nom_count_velviz,
       opt_count_velviz,
       CASE WHEN points_resolved < points_total THEN
       TO_CHAR(points_resolved::float / NULLIF(points_total,0) * 100,'99') || '%' END AS points_pct_complete,
       CASE WHEN count_resolved < count_total THEN
       TO_CHAR(count_resolved::float / NULLIF(count_total,0) * 100,'99') || '%' END AS count_pct_complete
  FROM velocity v, category z
 WHERE z.title = v.category
   AND z.scope = :'scope_prefix'
   AND v.scope = :'scope_prefix'
 ORDER BY date
) to '/tmp/phlog/forecast.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT z.title as category,
       z.display,
       (SELECT SUM(points)
          FROM task_on_date_agg
         WHERE scope = :'scope_prefix'
           AND category = z.title
           AND date = (SELECT MAX(date) FROM task_on_date_agg WHERE scope = :'scope_prefix')) AS points_total,
       (SELECT SUM(count)
          FROM task_on_date_agg
         WHERE scope = :'scope_prefix'
           AND category = z.title
           AND date = (SELECT MAX(date) FROM task_on_date_agg WHERE scope = :'scope_prefix')) AS count_total,
       z.sort_order,
       first.first_open_date,
       last.last_open_date + INTERVAL '1 week' as resolved_date
  FROM category z
  LEFT OUTER JOIN (SELECT category,
                          MIN(date) as first_open_date
                     FROM task_on_date_agg
                    WHERE scope = :'scope_prefix'
                      AND status = 'open'
                    GROUP BY category) AS first ON (z.title = first.category)
  LEFT OUTER JOIN (SELECT category,
                          MAX(date) as last_open_date
                     FROM task_on_date_agg
                    WHERE scope = :'scope_prefix'
                      AND status = 'open'
                    GROUP BY category) AS last ON (z.title = last.category AND
                                                date_trunc('day', last_open_date) <> (SELECT MAX(date) FROM task_on_date_agg WHERE scope = :'scope_prefix'))
WHERE scope = :'scope_prefix'
ORDER BY sort_order
) TO '/tmp/phlog/forecast_done.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT v.week AS date,
       z.sort_order,
       MAX(v.category) AS category,
       SUM(v.delta_points_resolved) AS points,
       SUM(v.delta_count_resolved) AS count
  FROM velocity v
  LEFT OUTER JOIN category z ON v.scope = z.scope AND v.category = z.title
 WHERE v.scope = :'scope_prefix'
   AND date >= current_date - interval '3 months'
 GROUP BY week, sort_order
 ORDER BY week, sort_order
) to '/tmp/phlog/recently_closed_week.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT v.month AS date,
       z.sort_order,
       MAX(v.category) AS category,
       SUM(v.delta_points_resolved) AS points,
       SUM(v.delta_count_resolved) AS count
  FROM velocity v
  LEFT OUTER JOIN category z ON v.scope = z.scope AND v.category = z.title
 WHERE v.scope = :'scope_prefix'
 GROUP BY month, sort_order
 ORDER BY month, sort_order
) to '/tmp/phlog/recently_closed_month.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT v.quarter AS date,
       z.sort_order,
       MAX(v.category) AS category,
       SUM(v.delta_points_resolved) AS points,
       SUM(v.delta_count_resolved) AS count
  FROM velocity v
  LEFT OUTER JOIN category z ON v.scope = z.scope AND v.category = z.title
 WHERE v.scope = :'scope_prefix'
 GROUP BY quarter, sort_order
 ORDER BY quarter, sort_order
) to '/tmp/phlog/recently_closed_quarter.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Points Histogram */

COPY (
SELECT COUNT(points) as count,
       points,
       priority
  FROM (
SELECT points,
       priority
  FROM task_on_date
 WHERE id in (SELECT DISTINCT id
                FROM task_on_date
               WHERE scope = :'scope_prefix')
   AND date = (SELECT MAX(date)
                 FROM task_on_date
                WHERE scope = :'scope_prefix')
   AND status = 'resolved') AS point_query
 GROUP BY points, priority
 ORDER BY priority, points
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
--   FROM task_on_date th
--  ORDER BY th.id, th.date ASC;

-- SELECT id,
--        status,
--        prev_status,
--        points,
--        date AS resoldate,
--        (SELECT min(date)
--           FROM task_on_date th2
--          WHERE th2.id = th1.id
--            AND status = 'open') as open_date
--   INTO leadtime
--   FROM statushist as th1
--  WHERE prev_status = 'open'
--    AND status = 'resolved'
--    AND id = prev_id;

-- /* This takes forever and the data isn't very useful.
-- DROP TABLE IF EXISTS openage;
-- SELECT id,
--        points,
--        date,
--        (SELECT min(date)
--           FROM task_on_date th2
--          WHERE th2.id = th1.id
--            AND status = 'open') as open_date
--   INTO openage
--   FROM task_on_date as th1
--  WHERE status = 'open'; */

-- SELECT id,
--        points,
--        date,
--        (SELECT min(date)
--           FROM task_on_date th2
--          WHERE th2.id = th1.id
--            AND status = 'open') as open_date
--   INTO openage_specific
--   FROM task_on_date as th1
--  WHERE status = 'open'
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

