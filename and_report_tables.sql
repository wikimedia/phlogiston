/* This script assumes that all tasks in the database are relevant to the Android team */


/* ####################################################################
Entire Backlog
Each row is the point total of valid work for one day for one project.
Valid work includes both open and closed tasks.
Invalid work is work with status="invalid" or status="declined".*/

DROP TABLE IF EXISTS tall_backlog;

SELECT date,
       project,
       SUM(points) as points
  INTO tall_backlog
  FROM task_history
 WHERE status != '"invalid"'
   AND status != '"declined"'
 GROUP BY project, date;

COPY tall_backlog to '/tmp/and_backlog.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Status distribution of all tasks each day, weighted by points */

COPY (SELECT date,
       status,
       SUM(points) as points
  FROM task_history
 GROUP BY date, status) TO '/tmp/and_status.csv' DELIMITER ',' CSV HEADER;


/* ####################################################################
Burnup and Velocity */

DROP TABLE IF EXISTS burnup;
DROP TABLE IF EXISTS burnup_week;
DROP TABLE IF EXISTS burnup_week_row;

SELECT date,
       SUM(points) AS points
  INTO burnup
  FROM task_history
 WHERE status='"resolved"'
 GROUP BY date
 ORDER BY date;

COPY (SELECT * FROM burnup) TO '/tmp/and_burnup.csv' DELIMITER ',' CSV HEADER;

SELECT DATE_TRUNC('week', date) AS week,
       SUM(points)/7 AS Done
  INTO burnup_week
  FROM task_history
 WHERE date > NOW() - interval '12 months'
   AND status='"resolved"'
 GROUP BY 1
 ORDER BY 1;

SELECT week, done, row_number() over () AS rnum
  INTO burnup_week_row
  FROM burnup_week;

COPY (SELECT v2.week, GREATEST(v2.done - v1.done, 0) AS velocity
        FROM burnup_week_row AS v1
        JOIN burnup_week_row AS v2 ON (v1.rnum + 1 = v2.rnum))
  TO '/tmp/and_velocity.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Backlog growth calculations */

DROP TABLE IF EXISTS total_backlog;
DROP TABLE IF EXISTS net_growth;
DROP TABLE IF EXISTS growth_delta;

SELECT date,
       SUM(points) AS points
  INTO total_backlog
  FROM tall_backlog
 GROUP BY date
 ORDER BY date;

COPY (
SELECT tb.date,
       tb.points - b.points AS points
  FROM total_backlog tb, burnup b
 WHERE tb.date = b.date
 ORDER BY date
) to '/tmp/and_net_growth.csv' DELIMITER ',' CSV HEADER;


/* ####################################################################
Task Size Histograms */

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
TO '/tmp/and_histogram.csv' CSV HEADER;


/* ####################################################################
Lead Time */

DROP TABLE IF EXISTS and_leadtime;

SELECT points,
       date AS resolved_date,
       (SELECT min(date)
          FROM task_history th2
         WHERE th2.title = th1.title
           AND status = '"open"') as open_date
  INTO and_leadtime
  FROM
      ( SELECT th.date,
               th.points,
               th.title,
               lag(th.title) OVER (ORDER BY title, th.date ASC) as prev_title,
               th.status,
               lag(th.status) OVER (ORDER BY title, th.date ASC) as prev_status
          FROM task_history th
      ORDER BY title, date ASC) as th1
 WHERE prev_status = '"open"' AND status='"resolved"' AND title=prev_title;

COPY (SELECT SUM(points) as points,
             width_bucket(extract(days from (resolved_date - open_date)),1,70,7) as leadtime,
             date_trunc('week', resolved_date) AS week
        FROM and_leadtime
       GROUP BY leadtime, week
       ORDER by week, leadtime)
TO '/tmp/and_leadtime.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date_trunc('week', resolved_date) AS week,
            count(points) as count,
            points
       FROM and_leadtime
      GROUP BY points, week
      ORDER BY week, points)
TO '/tmp/and_histopoints.csv' DELIMITER ',' CSV HEADER;
