DROP TABLE IF EXISTS tall_status;

SELECT date,
       status,
       sum(points) as points
  INTO tall_status
  FROM fr_task_history
 GROUP BY date, status;

COPY tall_status to '/tmp/FR_status.csv' DELIMITER ',' CSV
HEADER;

/* Entire Backlog

These charts focus on planned work.  Planned work is all work in one of the VE "blockers" projects.  Since the blocker projects started being used in late January, 2015, all work in the "VisualEditor" project after that point is unplanned.
*/ 

DROP TABLE IF EXISTS tall_backlog;

SELECT date,
       project,
       sum(points) as points
  INTO tall_backlog
  FROM fr_task_history
 WHERE status != '"invalid"' AND status != '"declined"'
 GROUP BY project, date;

COPY tall_backlog to '/tmp/FR_backlog.csv' DELIMITER ',' CSV
HEADER;

/* Velocity */

DROP TABLE IF EXISTS burnup;
DROP TABLE IF EXISTS burnup_week;
DROP TABLE IF EXISTS burnup_week_row;

SELECT date,
       sum(points) AS Done
  INTO burnup
  FROM fr_task_history
 WHERE status='"resolved"'
 GROUP BY date;

SELECT date_trunc('week', date) AS week,
       sum(points)/7 AS Done
  INTO burnup_week
  FROM fr_task_history
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
  TO '/tmp/FR_velocity.csv' DELIMITER ',' CSV HEADER;

/* Total backlog */

DROP TABLE IF EXISTS total_backlog;
DROP TABLE IF EXISTS net_growth;
DROP TABLE IF EXISTS growth_delta;

SELECT date,
       sum(points) AS points
  INTO total_backlog
  FROM tall_backlog
 GROUP BY date
 ORDER BY date;

COPY (
SELECT tb.date,
       tb.points - b.done AS points
  FROM total_backlog tb, burnup b
 WHERE tb.date = b.date
 ORDER BY date
) to '/tmp/FR_net_growth.csv' DELIMITER ',' CSV HEADER;

DROP TABLE IF EXISTS histogram;

SELECT title,
       max(project) as project,
       max(points) as points
  INTO histogram
  FROM fr_task_history
 WHERE status != '"invalid"' and status != '"declined"'
 GROUP BY title;

COPY (SELECT count(title),
             project,
             points
             FROM histogram
    GROUP BY project, points
    ORDER BY project, points)
TO '/tmp/FR_histogram.csv' CSV HEADER;

COPY (SELECT date,
             sum(points) as points
        FROM fr_task_history
       WHERE status = '"resolved"'
    GROUP BY date
    ORDER BY date)
TO '/tmp/FR_burnup.csv' DELIMITER ',' CSV HEADER;
