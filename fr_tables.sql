DROP TABLE IF EXISTS fr_tall_status;

SELECT date,
       status,
       sum(points) as points
  INTO fr_tall_status
  FROM task_history
 GROUP BY date, status;

COPY fr_tall_status to '/tmp/fr_status.csv' DELIMITER ',' CSV
HEADER;

/* Entire Backlog

*/ 

DROP TABLE IF EXISTS fr_tall_backlog;

SELECT date,
       project,
       sum(points) as points
  INTO fr_tall_backlog
  FROM task_history
 WHERE status != '"invalid"' AND status != '"declined"'
 GROUP BY project, date;

COPY fr_tall_backlog to '/tmp/fr_backlog.csv' DELIMITER ',' CSV
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
  TO '/tmp/fr_velocity.csv' DELIMITER ',' CSV HEADER;

/* Total backlog */

DROP TABLE IF EXISTS total_backlog;

SELECT date,
       sum(points) AS points
  INTO total_backlog
  FROM fr_tall_backlog
 GROUP BY date
 ORDER BY date;

COPY (
SELECT tb.date,
       tb.points - b.done AS points
  FROM total_backlog tb, burnup b
 WHERE tb.date = b.date
 ORDER BY date
) to '/tmp/fr_net_growth.csv' DELIMITER ',' CSV HEADER;

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
TO '/tmp/fr_histogram.csv' CSV HEADER;

COPY (SELECT date,
             sum(points) as points
        FROM task_history
       WHERE status = '"resolved"'
    GROUP BY date
    ORDER BY date)
TO '/tmp/fr_burnup.csv' DELIMITER ',' CSV HEADER;
