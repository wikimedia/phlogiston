DROP TABLE IF EXISTS tall_status;

SELECT date,
       status,
       sum(points) as points
  INTO tall_status
  FROM an_task_history
 GROUP BY date, status;

COPY tall_status to '/tmp/AN_status.csv' DELIMITER ',' CSV
HEADER;

/* Entire Backlog

These charts focus on planned work.  Planned work is all work in one of the VE "blockers" projects.  Since the blocker projects started being used in late January, 2015, all work in the "VisualEditor" project after that point is unplanned.
*/ 

DROP TABLE IF EXISTS tall_backlog;

SELECT date,
       project,
       sum(points) as points
  INTO tall_backlog
  FROM an_task_history
 WHERE status != '"invalid"' AND status != '"declined"'
 GROUP BY project, date;

COPY tall_backlog to '/tmp/AN_backlog.csv' DELIMITER ',' CSV
HEADER;

/* Velocity */

DROP TABLE IF EXISTS burnup;
DROP TABLE IF EXISTS burnup_week;
DROP TABLE IF EXISTS burnup_week_row;

SELECT date,
       sum(points) AS Done
  INTO burnup
  FROM an_task_history
 WHERE status='"resolved"'
 GROUP BY date;

SELECT date_trunc('week', date) AS week,
       sum(points)/7 AS Done
  INTO burnup_week
  FROM an_task_history
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
  TO '/tmp/AN_velocity.csv' DELIMITER ',' CSV HEADER;

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
) to '/tmp/AN_net_growth.csv' DELIMITER ',' CSV HEADER;

DROP TABLE IF EXISTS histogram;

SELECT title,
       max(project) as project,
       max(points) as points
  INTO histogram
  FROM an_task_history
 WHERE status != '"invalid"' and status != '"declined"'
 GROUP BY title;

COPY (SELECT count(title),
             project,
             points
             FROM histogram
    GROUP BY project, points
    ORDER BY project, points)
TO '/tmp/AN_histogram.csv' CSV HEADER;

COPY (SELECT date,
             sum(points) as points
        FROM an_task_history
       WHERE status = '"resolved"'
    GROUP BY date
    ORDER BY date)
TO '/tmp/AN_burnup.csv' DELIMITER ',' CSV HEADER;

DROP TABLE IF EXISTS an_leadtime;

SELECT date AS resolve_date,
       (SELECT min(date)
          FROM an_task_history th2
         WHERE th2.title = th1.title
           AND status = '"open"') as open_date
  INTO an_leadtime
  FROM
      ( SELECT th.date,
               th.title,
               lag(th.title) OVER (ORDER BY title, th.date ASC) as prev_title,
               th.status,
               lag(th.status) OVER (ORDER BY title, th.date ASC) as prev_status
          FROM an_task_history th
      ORDER BY title, date ASC) as th1
 WHERE prev_status = '"open"' AND status='"resolved"' AND title=prev_title;

COPY (SELECT count(*),
             width_bucket(extract(days from (resolve_date - open_date)),1,70,7) as leadtime,
             date_trunc('week', resolve_date) AS week
        FROM an_leadtime
       GROUP BY leadtime, week
       ORDER by week, leadtime)
TO '/tmp/AN_leadtime.csv' DELIMITER ',' CSV HEADER;
