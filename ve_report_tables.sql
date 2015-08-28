/* This script assumes that all tasks in the database are relevant to the VisualEditor team */

/* Apply some filtering to the raw data */

UPDATE ve_task_history
   SET status = '"open"'
 WHERE status = '"stalled"';

DELETE FROM ve_task_history
 WHERE status = '"duplicate"'
    OR status = '"invalid"'
    OR status = '"declined"';

/* Apply current work breakdown to historical data.  VE has used both
project and projectcolumn to categorize work; this script condenses
both into a single new field called category. */

/* ##################################################################
Roll up the task history from individual tasks to cumulative totals.

Each row is the cumulative point total for one day for one project and
projectcolumn and status 

Convert project and projectcolumn to category.  

Remove invalid work: work with status="invalid" or status="declined". */

DROP TABLE IF EXISTS ve_tall_backlog;
 
/* Query 1

Between January 2015 and June 2015, planned VE work was tracked in
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

/* Query 2
Prior to January 2015, all VE work was tracked in the VisualEditor
project and was not further categorized. Any "resolved" work in that project
prior to Jan 2015, or between Jan 2015 and June 18, 2015 while the "Q# Blocker"
projects were in use, is unplanned.  This query and the next query should together
cover all work in the VisualEditor project prior to June 18, 2015.*/

INSERT INTO ve_tall_backlog (date, category, status, points) (
SELECT date,
       category,
       status,
       SUM(points) as points
  FROM (
SELECT date,
       'TR0: Interrupt'::text as category,
       status,
       points
  FROM ve_task_history
 WHERE project = 'VisualEditor'
   AND status = '"resolved"'
   AND date < '2015-06-18') AS ve_old_interrupt
GROUP BY status, category, date);

/* Query 3 */

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
   AND status = '"open"'
   AND date < '2015-06-18') as ve_old_other
 GROUP BY status, category, date);

/* Query 4 
Since June 18, 2018, any task in the VisualEditor project with a
projectcolumn starting TR is categorized.  Any other tasks in the
VisualEditor project are uncategorized. */

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

/* Query 5 */

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
   AND date >= '2015-06-18'
   AND status = '"open"') AS ve_new_uncategorized
GROUP BY status, category, date);

/* Query 6
This query should catch mis-categorized stories */

INSERT INTO ve_tall_backlog (date, category, status, points) (
SELECT date,
       category,
       status,
       SUM(points) as points
  FROM (
SELECT date,
       CAST('Miscategorized' AS text) as category,
       CASE WHEN status='"stalled"' then CAST('"open"' as text)
            ELSE status
       END as status,
       points
  FROM ve_task_history
 WHERE project = 'VisualEditor'
   AND projectcolumn NOT SIMILAR TO 'TR%'
   AND date >= '2015-06-18'
   AND status = '"resolved"') AS ve_miscategorized
GROUP BY status, category, date);

COPY (
SELECT date,
       category,
       SUM(points) as points
  FROM ve_tall_backlog
 WHERE category NOT SIMILAR TO 'TR0%'
 GROUP BY category, date
) to '/tmp/ve_backlog_no_interrupt.csv' DELIMITER ',' CSV HEADER;

COPY (
SELECT date,
       SUM(points) as points
  FROM ve_tall_backlog
 WHERE category NOT SIMILAR TO 'TR0%'
   AND status = '"resolved"'
 GROUP BY date
) to '/tmp/ve_burnup_no_interrupt.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
   Maintenance fraction
Divide all resolved work into Maintenance or New Project, by week. */

DROP TABLE IF EXISTS ve_maintenance_week;
DROP TABLE IF EXISTS ve_maintenance_delta;

SELECT DATE_TRUNC('week', date) as week,
       CASE WHEN category = 'TR0: Interrupt' then 'Maintenance'
            ELSE 'New Project'
       END as type,
       SUM(points) AS points
 INTO ve_maintenance_week
 FROM ve_tall_backlog
 WHERE status = '"resolved"'
 GROUP BY type, week
 ORDER BY week, type;

SELECT week,
       type,
       (points - lag(points) OVER (ORDER BY week)) as maint_points,
       NULL::int as new_points
  INTO ve_maintenance_delta
  FROM ve_maintenance_week
 WHERE type='Maintenance'
 ORDER BY week, type;

UPDATE ve_maintenance_delta a
   SET new_points = (SELECT points
                       FROM (SELECT week,
                                    points - lag(points) OVER (ORDER BY week) as points
                               FROM ve_maintenance_week
                              WHERE type='New Project') as b
                      WHERE a.week = b.week);

COPY (
SELECT week,
       maint_frac
  FROM (
SELECT week,
       maint_points::float / (maint_points + new_points) as maint_frac
  FROM ve_maintenance_delta
  ) as ve_maintenance_fraction
) TO '/tmp/ve_maintenance_fraction.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Total points as of each day of all completed "Maintenance" work. */

/* not currently being used ! why not? should use this in fanciest subdivided burnup */

COPY (
SELECT date,
       SUM(points) AS points
 FROM ve_task_history
 WHERE projectcolumn='TR0: Interrupt'
   AND status = '"resolved"'
 GROUP BY date
 ORDER BY date
) TO '/tmp/ve_maintenance.csv' DELIMITER ',' CSV HEADER;

/* work in progress below this point

/* ####################################################################
Status distribution of all tasks each day, weighted by points */

COPY (SELECT date,
       status,
       SUM(points) as points
  FROM ve_task_history
 GROUP BY date, status) TO '/tmp/ve_status.csv' DELIMITER ',' CSV HEADER;


/* ####################################################################
Burnup and Velocity */

DROP TABLE IF EXISTS ve_burnup;
DROP TABLE IF EXISTS ve_burnup_week;
DROP TABLE IF EXISTS ve_burnup_week_row;
DROP TABLE IF EXISTS ve_velocity;

SELECT date,
       SUM(points) AS points
  INTO ve_burnup
  FROM ve_task_history
 WHERE status='"resolved"'
 GROUP BY date
 ORDER BY date;

COPY (SELECT * FROM ve_burnup) TO '/tmp/ve_burnup.csv' DELIMITER ',' CSV HEADER;

SELECT DATE_TRUNC('week', date) AS week,
       SUM(points)/7 AS Done
  INTO ve_burnup_week
  FROM ve_task_history
 WHERE date > NOW() - interval '12 months'
   AND status='"resolved"'
 GROUP BY 1
 ORDER BY 1;

/*SELECT week, done, row_number() over () AS rnum
#  INTO ve_burnup_week_row
#  FROM ve_burnup_week;
*/
SELECT v2.week, GREATEST(v2.done - v1.done, 0) AS velocity
  INTO ve_velocity
  FROM ve_burnup_week_row AS v1
  JOIN ve_burnup_week_row AS v2 ON (v1.rnum + 1 = v2.rnum);

COPY (SELECT * from ve_velocity) TO '/tmp/ve_velocity.csv' DELIMITER ',' CSV HEADER;

/* ####################################################################
Backlog growth calculations */

DROP TABLE IF EXISTS ve_total_backlog;
DROP TABLE IF EXISTS ve_net_growth;
DROP TABLE IF EXISTS ve_growth_delta;

SELECT date,
       SUM(points) AS points
  INTO ve_total_backlog
  FROM ve_tall_backlog
 GROUP BY date
 ORDER BY date;

COPY (
SELECT tb.date,
       tb.points - b.points AS points
  FROM ve_total_backlog tb, ve_burnup b
 WHERE tb.date = b.date
 ORDER BY date
) to '/tmp/ve_net_growth.csv' DELIMITER ',' CSV HEADER;


/* ####################################################################
Task Size Histograms */

DROP TABLE IF EXISTS ve_histogram;

SELECT title,
       max(project) as project,
       max(points) as points
  INTO ve_histogram
  FROM ve_task_history
 WHERE status != '"invalid"' and status != '"declined"'
 GROUP BY title;

COPY (SELECT count(title),
             project,
             points
             FROM ve_histogram
    GROUP BY project, points
    ORDER BY project, points)
TO '/tmp/ve_histogram.csv' CSV HEADER;


/* ####################################################################
Lead Time
This is also used for statistics of recently resolved tasks (histo-whatever)
since it's the only way to identify recently resolved tasks 
 */

DROP TABLE IF EXISTS ve_leadtime;
DROP TABLE IF EXISTS ve_statushist;
DROP TABLE IF EXISTS ve_openage_specific;

SELECT th.date,
       th.points,
       th.id,
       lag(th.id) OVER (ORDER BY th.id, th.date ASC) as prev_id,
       th.status,
       lag(th.status) OVER (ORDER BY th.id, th.date ASC) as prev_status
  INTO ve_statushist
  FROM ve_task_history th
 ORDER BY th.id, th.date ASC;

SELECT id,
       status,
       prev_status,
       points,
       date AS resolve_date,
       (SELECT min(date)
          FROM ve_task_history th2
         WHERE th2.id = th1.id
           AND status = '"open"') as open_date
  INTO ve_leadtime
  FROM ve_statushist as th1
 WHERE prev_status = '"open"'
   AND status = '"resolved"'
   AND id = prev_id;

/* This takes forever and the data isn't very useful.
DROP TABLE IF EXISTS ve_openage;
SELECT id,
       points,
       date,
       (SELECT min(date)
          FROM ve_task_history th2
         WHERE th2.id = th1.id
           AND status = '"open"') as open_date
  INTO ve_openage
  FROM ve_task_history as th1
 WHERE status = '"open"'; */

SELECT id,
       points,
       date,
       (SELECT min(date)
          FROM ve_task_history th2
         WHERE th2.id = th1.id
           AND status = '"open"') as open_date
  INTO ve_openage_specific
  FROM ve_task_history as th1
 WHERE status = '"open"'
   AND NOT (project='VisualEditor' AND projectcolumn NOT SIMILAR TO 'TR%');

COPY (SELECT SUM(points)/7 as points,
             width_bucket(extract(days from (current_date - open_date)),1,365,12) as age,
             date_trunc('week', date) as week
        FROM ve_openage_specific
       GROUP BY age, week
       ORDER by week, age)
TO '/tmp/ve_age_of_backlog_specific.csv' DELIMITER ',' CSV HEADER;

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
TO '/tmp/ve_age_of_resolved_count.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date_trunc('week', resolve_date) AS week,
            sum(points) as sumpoints,
            points
       FROM ve_leadtime
      GROUP BY points, week
      ORDER BY week, points)
TO '/tmp/ve_age_of_resolved.csv' DELIMITER ',' CSV HEADER;


/* ####################################################################
VE-specific Tranche-based analysis (tranches are projectcolumns) */

COPY (SELECT date,
             SUM(points) as points
        FROM ve_task_history
       WHERE status = '"resolved"'
         AND projectcolumn SIMILAR TO '%TR(0|1|2|3|4)%'
    GROUP BY date
    ORDER BY date)
TO '/tmp/ve_tranche_burnup.csv' DELIMITER ',' CSV HEADER;


COPY (SELECT date,
             SUM(points) as points,
             status
        FROM ve_task_history
       WHERE projectcolumn SIMILAR TO '%TR0%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR0.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             SUM(points) as points,
             status
        FROM ve_task_history
       WHERE projectcolumn SIMILAR TO '%TR1%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR1.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             SUM(points) as points,
             status
        FROM ve_task_history
       WHERE projectcolumn SIMILAR TO '%TR2%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR2.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             SUM(points) as points,
             status
        FROM ve_task_history
       WHERE projectcolumn SIMILAR TO '%TR3%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR3.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             SUM(points) as points,
             status
        FROM ve_task_history
       WHERE projectcolumn SIMILAR TO '%TR4%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR4.csv' DELIMITER ',' CSV HEADER;

COPY (SELECT date,
             SUM(points) as points,
             status
        FROM ve_task_history
       WHERE projectcolumn SIMILAR TO '%TR5%'
         AND (status = '"open"' OR status = '"resolved"')
    GROUP BY date, status
    ORDER BY date, status)
TO '/tmp/ve_TR5.csv' DELIMITER ',' CSV HEADER;

DROP TABLE IF EXISTS tall_tranche_backlog;

SELECT date,
       project || ' ' || projectcolumn as project,
       SUM(points) as points
  INTO ve_tall_tranche_backlog
  FROM ve_task_history
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
  INTO ve_tall_tranche_status
  FROM ve_task_history
 WHERE project = 'VisualEditor'
   AND date > '2015-06-19'
   AND projectcolumn like '%TR%'
   AND status != '"invalid"' AND status != '"declined"'
GROUP BY project, projectcolumn, date, status;

COPY tall_tranche_status to '/tmp/ve_tranche_status.csv' DELIMITER ',' CSV
HEADER;

/* Queries actually used for forecasting - data is copied to spreadsheet

select sum(velocity)/3 as min_velocity from (select velocity from ve_velocity where week >= '2015-04-20' and velocity <> 0 order by velocity limit 3) as x;

select sum(velocity)/3 as max_velocity from (select velocity from ve_velocity where week >= '2015-04-20' and velocity <> 0 order by velocity desc limit 3) as x;

select avg(velocity) as avg_velocity from (select velocity from ve_velocity where week >= '2015-04-20' and velocity <> 0) as x;

select projectcolumn, sum(points) as open_backlog from ve_task_history where projectcolumn SIMILAR TO '%TR(1|2|3|4)%' and status='"open"' and date='2015-08-13' GROUP BY projectcolumn;

*/

*/
