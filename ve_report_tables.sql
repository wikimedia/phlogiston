/* VisualEditor project only */

DROP TABLE IF EXISTS tall_status;

SELECT date,
       status,
       sum(points) as points
  INTO tall_status
  FROM task_history
 GROUP BY date, status;

COPY tall_status to '/tmp/ve_status.csv' DELIMITER ',' CSV
HEADER;

DROP TABLE IF EXISTS resolved_ve;

SELECT date,
       sum(points) as points
  INTO resolved_ve
  FROM task_history
 WHERE project = 'VisualEditor' and status='"resolved"'
   AND date < '2015-01-30'
 GROUP BY date, status;

COPY resolved_ve to '/tmp/ve_interrupt.csv' DELIMITER ',' CSV HEADER;


/* Entire Backlog

These charts focus on planned work.  Planned work is all work in one of the VE "blockers" projects.  Since the blocker projects started being used in late January, 2015, all work in the "VisualEditor" project after that point is unplanned.
*/ 

DROP TABLE IF EXISTS tall_backlog;

SELECT date,
       project,
       sum(points) as points
  INTO tall_backlog
  FROM task_history
 WHERE (project != 'VisualEditor' AND status != '"invalid"' AND status != '"declined"')
    OR (project = 'VisualEditor' AND (status ='"open"' OR status = '"stalled"'))
 GROUP BY project, date;

INSERT INTO tall_backlog (date, project, points) (
SELECT date,
       'VisualEditor Interrupt',
       sum(points)
  FROM task_history
 WHERE project = 'VisualEditor'
   AND status = '"resolved"'
   AND projectcolumn NOT LIKE '%TR%'
 GROUP BY date);

COPY tall_backlog to '/tmp/ve_backlog.csv' DELIMITER ',' CSV
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
  TO '/tmp/ve_velocity.csv' DELIMITER ',' CSV HEADER;

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
) to '/tmp/ve_net_growth.csv' DELIMITER ',' CSV HEADER;

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
TO '/tmp/ve_burnup.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             sum(points) as points
        FROM task_history
       WHERE status = '"resolved"'
         AND projectcolumn SIMILAR TO '%TR(0|1|2|3|4)%'
    GROUP BY date
    ORDER BY date)
TO '/tmp/ve_tranche_burnup.csv' DELIMITER ',' CSV HEADER;


COPY (SELECT date,
             sum(points) as points,
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR0%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR0.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             sum(points) as points,
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR1%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR1.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             sum(points) as points,
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR2%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR2.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             sum(points) as points,
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR3%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR3.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             sum(points) as points,
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR4%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR4.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             sum(points) as points,
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR5%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR5.csv' DELIMITER ',' CSV HEADER;


DROP TABLE IF EXISTS tall_tranche_backlog;

SELECT date,
       project || ' ' || projectcolumn as project,
       sum(points) as points
  INTO tall_tranche_backlog
  FROM task_history
 WHERE project = 'VisualEditor'
   AND date > '2015-06-19'
   AND projectcolumn like '%TR%'
   AND status != '"invalid"' AND status != '"declined"'
GROUP BY project, projectcolumn, date;

COPY tall_tranche_backlog to '/tmp/ve_tranche_backlog.csv' DELIMITER ',' CSV
HEADER;

DROP TABLE IF EXISTS tall_tranche_status;

SELECT date,
       project || ' ' || projectcolumn || ' ' || status as project,
       sum(points) as points
  INTO tall_tranche_status
  FROM task_history
 WHERE project = 'VisualEditor'
   AND date > '2015-06-19'
   AND projectcolumn like '%TR%'
   AND status != '"invalid"' AND status != '"declined"'
GROUP BY project, projectcolumn, date, status;

COPY tall_tranche_status to '/tmp/ve_tranche_status.csv' DELIMITER ',' CSV
HEADER;

SELECT title, ('2015-07-15' - min(th1.date)) as age
  FROM task_history th1
 WHERE th1.status='"open"'
   AND th1.title in (SELECT th2.title
                       FROM task_history th2
                      WHERE th2.date = '2015-07-15'
                        AND th2.status = '"resolved"')
 GROUP BY title;


