/* VisualEditor project only */

DROP TABLE IF EXISTS tall_status;

SELECT date,
       status,
       sum(points) as point_total
  INTO tall_status
  FROM task_history
 GROUP BY date, status;

COPY tall_status to '/tmp/VE_status.csv' DELIMITER ',' CSV
HEADER;

DROP TABLE IF EXISTS resolved_ve;

SELECT date,
       sum(points) as point_total
  INTO resolved_ve
  FROM task_history
 WHERE project = 'VisualEditor' and status='"resolved"'
 GROUP BY date, status;

COPY resolved_ve to '/tmp/VE_interrupt.csv' DELIMITER ',' CSV HEADER;

/* Entire Backlog

These charts focus on planned work.  Planned work is all work in one of the VE "blockers" projects.  Since the blocker projects started being used in late January, 2015, all work in the "VisualEditor" project after that point is unplanned.
*/ 

DROP TABLE IF EXISTS tall_backlog;

SELECT date,
       project,
       sum(points) as point_total
  INTO tall_backlog
  FROM task_history
 WHERE (project != 'VisualEditor' AND status != '"invalid"' AND status != '"declined"')
    OR (project = 'VisualEditor' AND (status ='"open"' OR status = '"stalled"'))
 GROUP BY project, date;

INSERT INTO tall_backlog (date, project, point_total) (
SELECT date,
       'VisualEditor Interrupt',
       sum(points)
  FROM task_history
 WHERE project = 'VisualEditor'
   AND status = '"resolved"'
 GROUP BY date);

COPY tall_backlog to '/tmp/VE_backlog.csv' DELIMITER ',' CSV
HEADER;

/* Velocity */

DROP TABLE IF EXISTS burnup;
DROP TABLE IF EXISTS burnup_week;
DROP TABLE IF EXISTS burnup_week_row;

SELECT date,
       sum(points) AS Done
  INTO burnup
  FROM task_history
 WHERE status='"resolved"'
 GROUP BY date;

SELECT date_trunc('week', date) AS week,
       sum(points)/7 AS Done
  INTO burnup_week
  FROM task_history
 WHERE date > now() - interval '12 months'
   AND status='"resolved"'
 GROUP BY 1
 ORDER BY 1;

SELECT week, done, row_number() over () AS rnum
  INTO burnup_week_row
  FROM burnup_week;

COPY (SELECT v2.week, GREATEST(v2.done - v1.done, 0) AS velocity
        FROM burnup_week_row AS v1
        JOIN burnup_week_row AS v2 ON (v1.rnum + 1 = v2.rnum))
  TO '/tmp/VE_velocity.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT burnup.date,
             (Done - point_total) AS total_points
        FROM burnup, resolved_ve
       WHERE burnup.date = resolved_ve.date
       ORDER by date) 
  TO '/tmp/VE_interrupt_delta.csv' DELIMITER ',' CSV HEADER;

/* Total backlog */

DROP TABLE IF EXISTS total_backlog;
DROP TABLE IF EXISTS net_growth;

SELECT date,
       sum(point_total) AS points
  INTO total_backlog
  FROM tall_backlog
 GROUP BY date
 ORDER BY date;

SELECT tb.date,
       tb.points - b.done AS net_points,
       row_number() over () as rnum
  INTO net_growth
  FROM total_backlog tb, burnup b
 WHERE tb.date = b.date
 ORDER BY date;

COPY (
SELECT ng1.date,
       GREATEST(ng2.net_points - ng1.net_points) as growth
  FROM net_growth AS ng1
  JOIN net_growth AS ng2 ON (ng1.rnum + 1 = ng2.rnum)
) to '/tmp/VE_net_growth.csv' DELIMITER ',' CSV HEADER;


DROP TABLE IF EXISTS histogram;

SELECT title,
       max(project) as project,
       max(points) as points
  INTO histogram
  FROM task_history
 WHERE status != '"invalid"' and status != '"declined"'
 GROUP BY title;

COPY (SELECT count(title),
             project,
             points
             FROM histogram
    GROUP BY project, points
    ORDER BY project, points)
TO '/tmp/histogram.csv' CSV HEADER;

COPY (SELECT date,
             sum(points) as points
        FROM task_history
       WHERE status = '"resolved"'
    GROUP BY date
    ORDER BY date)
TO '/tmp/VE_burnup.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             sum(points) as points
        FROM task_history
       WHERE status = '"resolved"'
         AND projectcolumn SIMILAR TO '%TR(0|1|2|3|4)%'
    GROUP BY date
    ORDER BY date)
TO '/tmp/VE_tranche_burnup.csv' DELIMITER ',' CSV HEADER;

DROP TABLE IF EXISTS tall_tranche_backlog;

SELECT date,
       project || ' ' || projectcolumn as project,
       sum(points) as point_total
  INTO tall_tranche_backlog
  FROM task_history
 WHERE project = 'VisualEditor'
   AND date > '2015-06-19'
   AND projectcolumn like '%TR%'
   AND status != '"invalid"' AND status != '"declined"'
GROUP BY project, projectcolumn, date;

COPY tall_tranche_backlog to '/tmp/VE_tranche_backlog.csv' DELIMITER ',' CSV
HEADER;

DROP TABLE IF EXISTS tall_tranche_status;

SELECT date,
       project || ' ' || projectcolumn || ' ' || status as project,
       sum(points) as point_total
  INTO tall_tranche_status
  FROM task_history
 WHERE project = 'VisualEditor'
   AND date > '2015-06-19'
   AND projectcolumn like '%TR%'
   AND status != '"invalid"' AND status != '"declined"'
GROUP BY project, projectcolumn, date, status;

COPY tall_tranche_status to '/tmp/VE_tranche_status.csv' DELIMITER ',' CSV
HEADER;
