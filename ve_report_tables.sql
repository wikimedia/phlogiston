/* This script assumes that all tasks in the database are relevant to the VisualEditor team */

/* ####################################################################
Entire Backlog
Each row is the point total of valid work for one day for one project.
Valid work includes both open and closed tasks.
Invalid work is work with status="invalid" or status="declined".

 1) Prior to 2015-06-18, planned work is all work in one of the VE "blockers" projects.
 2) After that date, planned work is all work in TR% projectcolumn of the VisualEditor 
    project, except work in TR0 */ 

<<<<<<< HEAD
COPY tall_status to '/tmp/ve_status.csv' DELIMITER ',' CSV
HEADER;
=======
DROP TABLE IF EXISTS tall_backlog;
>>>>>>> 809425dd6f08088be4eb7f8c3b504d90bdc35178

/* the blocker projects */

SELECT date,
       project,
       SUM(points) as points
  INTO tall_backlog
  FROM task_history
<<<<<<< HEAD
 WHERE project = 'VisualEditor' and status='"resolved"'
   AND date < '2015-01-30'
 GROUP BY date, status;

COPY resolved_ve to '/tmp/ve_interrupt.csv' DELIMITER ',' CSV HEADER;
=======
 WHERE project != 'VisualEditor'
   AND status != '"invalid"'
   AND status != '"declined"'
 GROUP BY project, date;

/* the interrupt pseudo-project */
>>>>>>> 809425dd6f08088be4eb7f8c3b504d90bdc35178

INSERT INTO tall_backlog (date, project, points) (
  SELECT date,
         'VisualEditor Interrupt',
         SUM(points) as points
    FROM ve_interrupt
   GROUP BY date
   ORDER BY date);

/* all planned work since Tranches went into use */

INSERT INTO tall_backlog (date, project, points) (
  SELECT date,
         projectcolumn,
         SUM(points) as points
        FROM task_history
       WHERE project = 'VisualEditor'
         AND date >= '2015-06-18'
         AND projectcolumn SIMILAR TO 'TR%'
         AND projectcolumn NOT SIMILAR TO 'TR0%'
         AND status != '"invalid"'
         AND status != '"declined"'
    GROUP BY date, projectcolumn);

/* All other work */

INSERT INTO tall_backlog (date, project, points) (
  SELECT date,
         'VisualEditor General Backlog',
         SUM(points) as points
    FROM task_history
   WHERE project = 'VisualEditor'
     AND projectcolumn NOT SIMILAR TO 'TR%'
     AND status != '"resolved"'
     AND status != '"invalid"'
     AND status != '"declined"'
   GROUP BY date
   ORDER BY date);

COPY tall_backlog to '/tmp/ve_backlog.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Status distribution of all tasks each day, weighted by points */

COPY (SELECT date,
       status,
       SUM(points) as points
  FROM task_history
 GROUP BY date, status) TO '/tmp/ve_status.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Total points as of each day of all completed "Interrupt" work.  Interrupt work is defined as 
 1) Any resolved task in the VisualEditor project that is not in any of the Tranche projectcolumns
 2) Any resolved task in the TR0 projectcolumn of the VisualEditor project */

DROP TABLE IF EXISTS ve_interrupt;

SELECT date,
       SUM(points) as points
  INTO ve_interrupt
  FROM task_history
 WHERE project = 'VisualEditor'
   AND status='"resolved"'
   AND projectcolumn NOT SIMILAR TO '%TR%'
 GROUP BY date
 ORDER BY date;

INSERT INTO ve_interrupt (date, points) (
  SELECT date,
         SUM(points) as points
    FROM task_history
   WHERE projectcolumn SIMILAR TO '%TR0%'
     AND status = '"resolved"'
   GROUP BY date);
   
COPY (
  SELECT date,
         SUM(points) as points
    FROM ve_interrupt
   GROUP BY date
   ORDER BY date
) TO '/tmp/ve_interrupt.csv' DELIMITER ',' CSV HEADER;

<<<<<<< HEAD
COPY tall_backlog to '/tmp/ve_backlog.csv' DELIMITER ',' CSV
HEADER;
=======
>>>>>>> 809425dd6f08088be4eb7f8c3b504d90bdc35178

/* ####################################################################
Burnup and Velocity */

DROP TABLE IF EXISTS burnup;
DROP TABLE IF EXISTS burnup_week;
DROP TABLE IF EXISTS burnup_week_row;

SELECT date,
       SUM(points) AS Done
  INTO burnup
  FROM task_history
 WHERE status='"resolved"'
 GROUP BY date
 ORDER BY date;

COPY (SELECT * FROM burnup) TO '/tmp/ve_burnup.csv' DELIMITER ',' CSV HEADER;

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
  TO '/tmp/ve_velocity.csv' DELIMITER ',' CSV HEADER;

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
       tb.points - b.done AS points
  FROM total_backlog tb, burnup b
 WHERE tb.date = b.date
 ORDER BY date
) to '/tmp/ve_net_growth.csv' DELIMITER ',' CSV HEADER;
<<<<<<< HEAD
=======

/* ####################################################################
Task Size Histograms */
>>>>>>> 809425dd6f08088be4eb7f8c3b504d90bdc35178

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

<<<<<<< HEAD
COPY (SELECT date,
             sum(points) as points
        FROM task_history
       WHERE status = '"resolved"'
    GROUP BY date
    ORDER BY date)
TO '/tmp/ve_burnup.csv' DELIMITER ',' CSV HEADER;
=======
/* ####################################################################
Lead Time */

DROP TABLE IF EXISTS ve_leadtime;

SELECT points,
       date AS resolve_date,
       (SELECT min(date)
          FROM task_history th2
         WHERE th2.title = th1.title
           AND status = '"open"') as open_date
  INTO ve_leadtime
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
             width_bucket(extract(days from (resolve_date - open_date)),1,70,7) as leadtime,
             date_trunc('week', resolve_date) AS week
        FROM ve_leadtime
       GROUP BY leadtime, week
       ORDER by week, leadtime)
TO '/tmp/ve_leadtime.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date_trunc('week', resolve_date) AS week,
            count(points) as count,
            points
       FROM ve_leadtime
      GROUP BY points, week
      ORDER BY week, points)
TO '/tmp/ve_histopoints.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
VE-specific Tranche-based analysis (tranches are projectcolumns) */
>>>>>>> 809425dd6f08088be4eb7f8c3b504d90bdc35178

COPY (SELECT date,
             SUM(points) as points
        FROM task_history
       WHERE status = '"resolved"'
         AND projectcolumn SIMILAR TO '%TR(0|1|2|3|4)%'
    GROUP BY date
    ORDER BY date)
TO '/tmp/ve_tranche_burnup.csv' DELIMITER ',' CSV HEADER;


COPY (SELECT date,
             SUM(points) as points,
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR0%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR0.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             SUM(points) as points,
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR1%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR1.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             SUM(points) as points,
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR2%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR2.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             SUM(points) as points,
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR3%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR3.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             SUM(points) as points,
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR4%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR4.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
<<<<<<< HEAD
             sum(points) as points,
=======
             SUM(points) as points,
>>>>>>> 809425dd6f08088be4eb7f8c3b504d90bdc35178
             status
        FROM task_history
       WHERE projectcolumn SIMILAR TO '%TR5%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR5.csv' DELIMITER ',' CSV HEADER;
<<<<<<< HEAD

=======
>>>>>>> 809425dd6f08088be4eb7f8c3b504d90bdc35178

DROP TABLE IF EXISTS tall_tranche_backlog;

SELECT date,
       project || ' ' || projectcolumn as project,
       SUM(points) as points
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
       SUM(points) as points
  INTO tall_tranche_status
  FROM task_history
 WHERE project = 'VisualEditor'
   AND date > '2015-06-19'
   AND projectcolumn like '%TR%'
   AND status != '"invalid"' AND status != '"declined"'
GROUP BY project, projectcolumn, date, status;

COPY tall_tranche_status to '/tmp/ve_tranche_status.csv' DELIMITER ',' CSV
HEADER;

/* TODO: what's this for?
SELECT title, ('2015-07-15' - min(th1.date)) as age
  FROM task_history th1
 WHERE th1.status='"open"'
   AND th1.title in (SELECT th2.title
                       FROM task_history th2
                      WHERE th2.date = '2015-07-15'
                        AND th2.status = '"resolved"')
 GROUP BY title;
*/
      