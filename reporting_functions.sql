CREATE OR REPLACE FUNCTION calculate_velocities(
    scope_prefix varchar(6)
    ) RETURNS date AS $$
DECLARE
  past_dates date[];
  future_dates date[];
  weekday date;
  most_recent_data date;
  oldest_data date;
  weekrow record;
  tranche record;
  weeks_ahead int;
  min_points_vel float;
  avg_points_vel float;
  max_points_vel float;
  min_count_vel float;
  avg_count_vel float;
  max_count_vel float;
  min_points_grow float;
  avg_points_grow float;
  max_points_grow float;
  min_count_grow float;
  avg_count_grow float;
  max_count_grow float;
  threew_max_points_grow float;
  threem_max_points_grow float;
  threew_max_count_grow float;
  threem_max_count_grow float;
  threew_avg_points_grow float;
  threem_avg_points_grow float;
  threew_avg_count_grow float;
  threem_avg_count_grow float;
BEGIN

    DELETE FROM velocity where scope = scope_prefix;

    SELECT MAX(date)
      INTO most_recent_data
      FROM task_on_date_agg
     WHERE scope = scope_prefix
       AND count > 0;

    -- get a start date that is an exact number of weeks back
    SELECT most_recent_data - (age_interval * interval '1 weeks')
      INTO oldest_data
      FROM 
           (SELECT (EXTRACT(days FROM (most_recent_data - min_data_date)) / 7)::int as age_interval
             FROM 
                  (SELECT MIN(date) AS min_data_date
                    FROM task_on_date_agg
                   WHERE scope = scope_prefix
                     AND range = 'normal'
                     AND count > 0) AS sub1) AS sub2;

    SELECT ARRAY(
    SELECT date_trunc('day', dd)::date
      INTO past_dates
      FROM GENERATE_SERIES
           (oldest_data,
            most_recent_data,
            '1 week'::interval) dd
    );

    SELECT ARRAY(
    SELECT date_trunc('day', dd)::date
      INTO future_dates
      FROM GENERATE_SERIES
           (most_recent_data,
            most_recent_data + interval '13 weeks',
            '1 week'::interval) dd
    );

    -- load historical data into velocity
    INSERT INTO velocity (
    SELECT scope,
           category,
           date,
           date_trunc('week', date) as week,
           date_trunc('month', date) as month,
           date_trunc('quarter', date) as quarter,
           SUM(points) AS points_total,
           SUM(count) AS count_total
      FROM task_on_date_agg
     WHERE range = 'normal'
       AND date = ANY (past_dates)
       AND scope = scope_prefix
     GROUP BY date, scope, category);

    -- load resolved data velocity
    UPDATE velocity v
       SET points_resolved = sum_points_resolved,
           count_resolved = sum_count_resolved
      FROM (SELECT scope,
                   date,
                   category,
                   SUM(points) AS sum_points_resolved,
                   SUM(count) AS sum_count_resolved
              FROM task_on_date_agg
             WHERE range = 'normal'
               AND status = 'resolved'
               AND scope = scope_prefix
             GROUP BY scope, date, category) as t
     WHERE t.date = v.date
       AND t.category = v.category
       AND t.scope = v.scope
       AND v.scope = scope_prefix;

    -- calculate deltas for historical data
    UPDATE velocity
       SET delta_points_resolved = COALESCE(subq.delta_points_resolved,0),
           delta_count_resolved = COALESCE(subq.delta_count_resolved,0),
           delta_points_total = COALESCE(subq.delta_points_total,0),
           delta_count_total = COALESCE(subq.delta_count_total,0)
      FROM (SELECT scope,
                   date,
                   category,
                   count_resolved - lag(count_resolved) OVER
                       (PARTITION BY scope, category ORDER BY date) as delta_count_resolved,
                   points_resolved - lag(points_resolved) OVER
                       (PARTITION BY scope, category ORDER BY date) as delta_points_resolved,
                   count_total - lag(count_total) OVER
                       (PARTITION BY scope, category ORDER BY date) as delta_count_total,
                   points_total - lag(points_total) OVER
                       (PARTITION BY scope, category ORDER BY date) as delta_points_total
      FROM velocity
     WHERE scope = scope_prefix) as subq
     WHERE velocity.scope = subq.scope
       AND velocity.date = subq.date
       AND velocity.category = subq.category;   

    -- calculate retrocasts and forecasts up to current day
    FOREACH weekday IN ARRAY past_dates
    LOOP
        FOR tranche IN SELECT DISTINCT category
                         FROM task_on_date_agg
                        WHERE range = 'normal'
                          AND date = weekday
                          AND scope = scope_prefix
                        ORDER BY category
        LOOP
            SELECT SUM(total::float)/3
              INTO min_points_vel
              FROM (SELECT CASE WHEN delta_points_resolved < 0 THEN 0
                           ELSE delta_points_resolved
                           END AS total
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 months'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_points_resolved 
                     LIMIT 3) AS x;

            SELECT SUM(delta_points_resolved::float)/3
              INTO max_points_vel
              FROM (SELECT delta_points_resolved
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 months'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_points_resolved DESC
                     LIMIT 3) AS x;

            SELECT AVG(delta_points_resolved::float)
              INTO avg_points_vel
              FROM velocity subqv
             WHERE subqv.date > weekday - interval '3 weeks'
               AND subqv.date <= weekday
               AND subqv.scope = scope_prefix
               AND subqv.category = tranche.category;

            SELECT SUM(total::float)/3
              INTO threew_max_points_grow
              FROM (SELECT CASE WHEN delta_points_total < 0 THEN 0
                           ELSE delta_points_total
                           END AS total
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 weeks'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_points_total DESC
                     LIMIT 3) AS x;

            SELECT SUM(total::float)/3
              INTO threem_max_points_grow
              FROM (SELECT CASE WHEN delta_points_total < 0 THEN 0
                           ELSE delta_points_total
                           END AS total
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 months'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_points_total DESC
                     LIMIT 3) AS x;

            SELECT AVG(total::float)
              INTO threew_avg_points_grow
              FROM (SELECT CASE WHEN delta_points_total < 0 THEN 0
                           ELSE delta_points_total
                           END AS total
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 weeks'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category) AS x;

            SELECT AVG(total::float)
              INTO threem_avg_points_grow
              FROM (SELECT CASE WHEN delta_points_total < 0 THEN 0
                           ELSE delta_points_total
                           END AS total
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 months'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category) as x;

            SELECT SUM(total::float)/3 AS min_count_vel
              INTO min_count_vel
              FROM (SELECT CASE WHEN delta_count_resolved < 0 THEN 0
                           ELSE delta_count_resolved
                           END AS total
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 months'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_count_resolved 
                     LIMIT 3) AS x;

            SELECT SUM(delta_count_resolved::float)/3 AS max_count_vel
              INTO max_count_vel
              FROM (SELECT delta_count_resolved
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 months'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_count_resolved DESC
                     LIMIT 3) AS x;

            SELECT AVG(delta_count_resolved::float)
              INTO avg_count_vel
              FROM velocity subqv
             WHERE subqv.date > weekday - interval '3 weeks'
               AND subqv.date <= weekday
               AND subqv.scope = scope_prefix
               AND subqv.category = tranche.category;

            SELECT SUM(total::float)/3
              INTO threew_max_count_grow
              FROM (SELECT CASE WHEN delta_count_total < 0 THEN 0
                           ELSE delta_count_total
                           END AS total
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 weeks'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_count_total DESC
                     LIMIT 3) AS x;

            SELECT SUM(total::float)/3
              INTO threem_max_count_grow
              FROM (SELECT CASE WHEN delta_count_total < 0 THEN 0
                           ELSE delta_count_total
                           END AS total
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 months'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category
                     ORDER BY subqv.delta_count_total DESC
                     LIMIT 3) AS x;

            SELECT AVG(total::float)
              INTO threew_avg_count_grow
              FROM (SELECT CASE WHEN delta_count_total < 0 THEN 0
                           ELSE delta_count_total
                           END AS total
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 weeks'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category) AS x;

            SELECT AVG(total::float)
              INTO threem_avg_count_grow
              FROM (SELECT CASE WHEN delta_count_total < 0 THEN 0
                           ELSE delta_count_total
                           END AS total
                      FROM velocity subqv
                     WHERE subqv.date > weekday - interval '3 months'
                       AND subqv.date <= weekday
                       AND subqv.scope = scope_prefix
                       AND subqv.category = tranche.category) as x;

            SELECT threew_avg_points_grow
              INTO avg_points_grow;

            SELECT GREATEST(threem_avg_points_grow, threem_max_points_grow)
              INTO max_points_grow;

            SELECT threew_avg_count_grow
              INTO avg_count_grow;

            SELECT GREATEST(threem_avg_count_grow, threem_max_count_grow)
              INTO max_count_grow;

            UPDATE velocity
               SET pes_points_vel = min_points_vel,
                   nom_points_vel = GREATEST(avg_points_vel,1),
                   opt_points_vel = GREATEST(max_points_vel,2),
                   pes_count_vel = min_count_vel,
                   nom_count_vel = GREATEST(avg_count_vel,1),
                   opt_count_vel = GREATEST(max_count_vel,2),
                   opt_points_total_growrate = 0,
                   nom_points_total_growrate = avg_points_grow,
                   pes_points_total_growrate = max_points_grow,
                   opt_count_total_growrate = 0,
                   nom_count_total_growrate = avg_count_grow,
                   pes_count_total_growrate = max_count_grow,
                   threem_max_points_growrate = threem_max_points_grow,
                   threew_max_points_growrate = threew_max_points_grow,
                   threem_max_count_growrate = threem_max_count_grow,
                   threew_max_count_growrate = threew_max_count_grow
             WHERE scope = scope_prefix
               AND category = tranche.category
               AND date = weekday;

        END LOOP;
    END LOOP;

    -- generate actual forecast in weeks for all historical data
    -- (for everything but the current week, this is technically a retrocast)
    -- Forecast is size of open backlog divided by velocity
    -- Velocity is forecast velocity, with a minimum of 1 point or story per week,
    -- minus forecast backlog growth

    UPDATE velocity
       SET pes_points_fore = ROUND((points_total - points_resolved)::float /
                                   NULLIF((pes_points_vel - pes_points_total_growrate),0)),
           nom_points_fore = ROUND((points_total - points_resolved)::float /
                                   NULLIF((nom_points_vel - nom_points_total_growrate),0)),
           opt_points_fore = ROUND((points_total - points_resolved)::float /
                                   NULLIF((opt_points_vel - opt_points_total_growrate),0))
     WHERE scope = scope_prefix
       AND points_resolved < points_total;

    UPDATE velocity
       SET pes_points_fore = NULL
     WHERE pes_points_fore <= 0
       AND scope = scope_prefix;

    UPDATE velocity
       SET nom_points_fore = NULL
     WHERE nom_points_fore <= 0
       AND scope = scope_prefix;

    UPDATE velocity
       SET opt_points_fore = NULL
     WHERE opt_points_fore <= 0
       AND scope = scope_prefix;


    UPDATE velocity
       SET pes_count_fore = ROUND((count_total - count_resolved)::float /
                                   NULLIF((pes_count_vel - pes_count_total_growrate),0)),
           nom_count_fore = ROUND((count_total - count_resolved)::float /
                                   NULLIF((nom_count_vel - nom_count_total_growrate),0)),
           opt_count_fore = ROUND((count_total - count_resolved)::float /
                                   NULLIF((opt_count_vel - opt_count_total_growrate),0))
     WHERE scope = scope_prefix
       AND count_resolved < count_total;

    UPDATE velocity
       SET pes_count_fore = NULL
     WHERE pes_count_fore <= 0
       AND scope = scope_prefix;

    UPDATE velocity
       SET nom_count_fore = NULL
     WHERE nom_count_fore <= 0
       AND scope = scope_prefix;

    UPDATE velocity
       SET opt_count_fore = NULL
     WHERE opt_count_fore <= 0
       AND scope = scope_prefix;
       
       
    -- convert # of weeks in future to specific date
    
    UPDATE velocity
       SET pes_points_date = date_trunc('day', date + (pes_points_fore * interval '1 week')),
           nom_points_date = date_trunc('day', date + (nom_points_fore * interval '1 week')),
           opt_points_date = date_trunc('day', date + (opt_points_fore * interval '1 week')),
           pes_count_date = date_trunc('day', date + (pes_count_fore * interval '1 week')),
           nom_count_date = date_trunc('day', date + (nom_count_fore * interval '1 week')),
           opt_count_date = date_trunc('day', date + (opt_count_fore * interval '1 week'))
     WHERE scope = scope_prefix;

    -- calculate future projections based on today's forecasts
    -- include today to get zero-based forecast viz lines

    FOR tranche IN SELECT DISTINCT category
                     FROM task_on_date_agg
                    WHERE scope = scope_prefix
                      AND range = 'normal'
                    ORDER BY category
    LOOP

        FOREACH weekday IN ARRAY future_dates
        LOOP
            weeks_ahead := EXTRACT(EPOCH FROM date_trunc('day', weekday) - date_trunc('day', most_recent_data)) / 604800;
            INSERT INTO velocity (scope, category, date,
                   pes_points_growviz, nom_points_growviz, opt_points_growviz,
                   pes_count_growviz, nom_count_growviz, opt_count_growviz,
                   pes_points_velviz, nom_points_velviz, opt_points_velviz,
                   pes_count_velviz, nom_count_velviz, opt_count_velviz) (
            SELECT scope, category, weekday,
                   points_total + (pes_points_total_growrate * weeks_ahead),
                   points_total + (nom_points_total_growrate * weeks_ahead),
                   points_total + (opt_points_total_growrate * weeks_ahead),
                   count_total + (pes_count_total_growrate * weeks_ahead),
                   count_total + (nom_count_total_growrate * weeks_ahead),
                   count_total + (opt_count_total_growrate * weeks_ahead),
                   points_resolved + (pes_points_vel * weeks_ahead),
                   points_resolved + (nom_points_vel * weeks_ahead),
                   points_resolved + (opt_points_vel * weeks_ahead),
                   count_resolved + (pes_count_vel * weeks_ahead),
                   count_resolved + (nom_count_vel * weeks_ahead),
                   count_resolved + (opt_count_vel * weeks_ahead)
              FROM velocity
             WHERE scope = scope_prefix
               AND category = tranche.category
               AND date = most_recent_data
               AND count_total IS NOT NULL);

        END LOOP;
    END LOOP;

    RETURN most_recent_data;
END;
$$ LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS get_backlog(varchar(6), text, varchar(6), boolean);

CREATE OR REPLACE FUNCTION get_backlog (
       scope_prefix varchar(6),
       status_input text,
       cutoff_range agg_range,
       show_hidden boolean

) RETURNS TABLE(date timestamp, category text, sort_order int, points numeric, count numeric) AS $$
BEGIN
    RETURN QUERY
    SELECT t.date,
           t.category,
           MAX(z.sort_order) as sort_order,
           SUM(t.points)::numeric as points,
           SUM(t.count)::numeric as count
      FROM task_on_date_agg t, category z
     WHERE t.scope = scope_prefix
       AND t.range = cutoff_range
       AND z.scope = scope_prefix
       AND t.scope = z.scope
       AND t.category = z.title
       AND t.status = status_input
       AND (show_hidden = True OR z.display = 'show')
     GROUP BY t.date, t.category
     ORDER BY t.date, sort_order;
END;
$$ LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS get_categories(varchar(6));

CREATE OR REPLACE FUNCTION get_categories(
    scope_prefix varchar(6)
    ) RETURNS TABLE (
    title text,
    display displayrule)
AS $$
BEGIN
    RETURN QUERY
    SELECT foo.title,
           foo.display
      FROM (SELECT z.title,
                   max(z.display) as display,
                   max(z.sort_order) as sort_order,
                   sum(t.count) as xcount
              FROM category z, task_on_date_agg t
             WHERE z.scope = scope_prefix
               AND t.range = 'normal'
               AND z.scope = t.scope
               AND z.title = t.category
             GROUP BY z.title) as foo
     WHERE xcount > 0
    ORDER BY sort_order;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_forecast_weeks(
    scope_prefix varchar(6)
    ) RETURNS TABLE (
    category text,
    pp int, np int, op int, 
    pc int, nc int, oc int)
AS $$
BEGIN
	RETURN QUERY
        SELECT v.category,
               pes_points_fore,
               nom_points_fore,
               opt_points_fore,
               pes_count_fore,
               nom_count_fore,
               opt_count_fore
          FROM velocity v, category z
         WHERE v.scope = scope_prefix
           AND v.scope = z.scope
           AND v.category = z.title
           AND v.count_total IS NOT NULL
           AND v.date = (SELECT MAX(date)
                           FROM velocity
                          WHERE scope = scope_prefix
                            AND count_total IS NOT NULL)
         ORDER BY sort_order;

END;
$$ LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS get_open_task_list(varchar(6));
CREATE OR REPLACE FUNCTION get_open_task_list(
    scope_prefix varchar(6)
    ) RETURNS TABLE (
    id int,
    title text,
    category text,
    date_added timestamp,
    date_last_changed timestamp with time zone)
AS $$
BEGIN
    RETURN QUERY
    SELECT thr.id,
           mt.title,
           thr.category,
	   date_trunc('day', (SELECT MIN(date) FROM task_on_date_recategorized thr1 WHERE thr1.id = thr.id)) AS date_added,
	   date_trunc('day', (SELECT MAX(date_modified)
                                FROM maniphest_transaction
                               WHERE task_id = thr.id
                                 AND transaction_type IN ('core:columns', 'status', 'core:edge'))) AS date_last_changed
      FROM task_on_date_recategorized thr LEFT OUTER JOIN maniphest_task mt USING (id)
     WHERE scope = scope_prefix
       AND thr.status = 'open'
       AND thr.date = (SELECT MAX(date)
                         FROM task_on_date_recategorized
                        WHERE scope = scope_prefix)
        ORDER BY thr.category, date_added, mt.title;

END;
$$ LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS get_recently_closed_tasks(varchar(6));
CREATE OR REPLACE FUNCTION get_recently_closed_tasks(
    scope_prefix varchar(6)
    ) RETURNS TABLE (
    id int,
    title text,
    date date, 
    category text,
    points int)
AS $$
BEGIN
    RETURN QUERY
    SELECT rct.id,
           mt.title,
           rct.date,
           rct.category,
	   rct.points
      FROM recently_closed_task rct LEFT OUTER JOIN maniphest_task mt USING (id)
     WHERE rct.scope = scope_prefix
  ORDER BY rct.category, rct.date, rct.id;

END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_status_report(character varying, int, date, date);
CREATE OR REPLACE FUNCTION get_status_report(
    scope_prefix varchar(6),
    status_report_project int,
    initial_date date,
    final_date date
    ) RETURNS TABLE (
    id int,
    title text,
    category text,
    scope text,
    status text,
    points text,
    sort_order int)
AS $$
BEGIN

    -- the innermost query, q1, generates a list of all tasks in scope for the report.
    -- The UNION is to generate a universe of tasks that belong in the report, either
    -- because they were in scope on the start date, or because they were in scope
    -- on the end date.
    -- the next query, q2, provides a place to run subqueries to get the previous status
    -- and parent previous status
    -- the outermost query includes the business logic to convert status comparisons
    -- between start and finish dates into scope determinations.
    -- The fact of which task is the parent task is determined from maniphest_blocked,
    -- and note that maniphest_blocked, unlike the other tables, does not have 
    -- historical data reconstructed from transactions.

    RETURN QUERY
    SELECT q2.id,
           q2.title,
           q2.category,
	   CASE WHEN (q2.previous_status IS NULL or q2.previous_status = '')
                 AND q2.parent_previous_status = 'open'  THEN 'Elaborated'
                WHEN q2.previous_status IS NULL or q2.previous_status = ''
                                                         THEN 'Screep'
                WHEN q2.previous_status = 'open'
                  OR q2.previous_status = 'resolved'     THEN 'In-Scope'
                ELSE 'Unknown'
           END as scope,
           CASE WHEN q2.cut_status = True            THEN 'Cut'
                WHEN q2.previous_status = 'resolved'
                 AND q2.status = 'open'              THEN 'Reopened'
                WHEN q2.status = 'resolved'          THEN 'Done'
                WHEN q2.status = 'open'              THEN 'Open'
                ELSE q2.status
           END as status,
           q2.points,
           c.sort_order
      FROM (
	    SELECT q1.id,
                   q1.parent_id,
	           q1.title,
	           q1.category,
	           q1.status,
                   (SELECT todr2pre.status
                      FROM task_on_date_recategorized as todr2pre,
                           maniphest_edge me2pre
                     WHERE todr2pre.id = q1.id
                       AND todr2pre.date = initial_date
                       AND todr2pre.scope = scope_prefix
                       AND todr2pre.id = me2pre.task
                       AND me2pre.date = initial_date
                       AND me2pre.project = status_report_project) AS previous_status,
		   (SELECT todr2par.status
                      FROM task_on_date_recategorized as todr2par,
                           maniphest_edge me2par
                     WHERE todr2par.id = q1.parent_id
                       AND todr2par.date = initial_date
                       AND todr2par.scope = scope_prefix
                       AND todr2par.id = me2par.task
                       AND me2par.date = initial_date
                       AND me2par.project = status_report_project) AS parent_previous_status,
 	           q1.points,
		   q1.cut_status
              FROM (SELECT DISTINCT ON (todr1.id) todr1.id,
		           mt1.title,
		           todr1.category,
		           todr1.status,
		           mt1.story_points as points,
                           mb.parent_id,
			   False as cut_status
		      FROM task_on_date_recategorized todr1
                        LEFT OUTER JOIN maniphest_task mt1 USING (id)
                        LEFT OUTER JOIN category z1 ON (z1.title = todr1.category)
                        LEFT OUTER JOIN maniphest_blocked mb ON (
                          mb.child_id = todr1.id)
		     WHERE todr1.scope = scope_prefix
		       AND todr1.date = final_date
		       AND todr1.id IN (SELECT task
		                         FROM maniphest_edge me
                                        WHERE me.date = final_date
                                          AND project = status_report_project)
                    UNION
                    SELECT DISTINCT ON (todr1a.id) todr1a.id,
		           mt1a.title,
		           todr1a.category,
		           todr1a.status,
		           mt1a.story_points as points,
			   Null,
                           True as cut_status
		      FROM task_on_date_recategorized todr1a
                        LEFT OUTER JOIN maniphest_task mt1a USING (id)
                        LEFT OUTER JOIN category z1a ON (z1a.title = todr1a.category)
		     WHERE todr1a.scope = scope_prefix
		       AND todr1a.date = initial_date
		       AND todr1a.id IN (SELECT task
		                         FROM maniphest_edge me
                                        WHERE me.date = initial_date
                                          AND project = status_report_project)
		       AND todr1a.id NOT IN (SELECT task
   		                              FROM maniphest_edge me
                                             WHERE me.date = final_date
                                               AND project = status_report_project)
                   ) as q1
           ) as q2
      LEFT OUTER JOIN category c ON (q2.category = c.title AND c.scope = scope_prefix)
     WHERE q2.previous_status != 'resolved' OR q2.previous_status IS NULL
     ORDER BY sort_order, status;

END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_unpointed_tasks(varchar(6));
CREATE OR REPLACE FUNCTION get_unpointed_tasks(
    scope_prefix varchar(6)
    ) RETURNS TABLE (
    id int,
    title text,
    category text,
    status text,
    date_added timestamp,
    date_last_changed timestamp with time zone)
AS $$
BEGIN
    RETURN QUERY
    SELECT thr.id,
           mt.title,
           thr.category,
           thr.status,
	   date_trunc('day', (SELECT MIN(thr1.date) FROM task_on_date_recategorized thr1 WHERE thr1.id = thr.id)) AS date_added,
	   date_trunc('day', (SELECT MAX(mt1.date_modified)
                                FROM maniphest_transaction mt1
                               WHERE mt1.task_id = thr.id
                                 AND mt1.transaction_type IN ('core:columns', 'status', 'core:edge'))) AS date_last_changed
      FROM task_on_date_recategorized thr 
           LEFT OUTER JOIN maniphest_task mt USING (id)
           LEFT OUTER JOIN category z ON (z.title = thr.category)
     WHERE thr.scope = scope_prefix
       AND thr.date = (SELECT MAX(date)
                         FROM task_on_date_recategorized
                        WHERE scope = scope_prefix)
       AND thr.id IN (SELECT mt.id
                        FROM maniphest_task mt
                       WHERE story_points IS NULL)
     ORDER BY z.sort_order, thr.status, thr.id;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION load_tasks_to_recategorize(
    scope_prefix varchar(6)
) RETURNS void AS $$

  INSERT INTO task_on_date_recategorized(
    SELECT scope,
           date,
           id,
	   NULL,
           project_id,
           projectcolumn,
           category_title,
           status,
           points,
           maint_type
      FROM task_on_date
     WHERE scope = $1
  );

  UPDATE task_on_date_recategorized
     SET status = 'open'
   WHERE status = 'stalled'
     AND scope = $1;

  DELETE FROM task_on_date_recategorized
   WHERE (status = 'duplicate'
      OR status = 'invalid'
      OR status = 'declined')
     AND scope = $1;

$$ LANGUAGE SQL VOLATILE;


CREATE OR REPLACE FUNCTION populate_recently_closed(
    scope_prefix varchar(6),
    start_date date,
    end_date date
    ) RETURNS void AS $$
DECLARE
  daterow record;
BEGIN

  FOR daterow IN SELECT date
                   FROM GENERATE_SERIES(
                        (start_date::date + '1 day'::interval),
                        end_date::date,
                        '1 day'::interval) as date
    LOOP

        INSERT INTO recently_closed (
             SELECT scope_prefix as scope,
                    date,
                    date_trunc('week', date) as week,
                    date_trunc('month', date) as month,
                    date_trunc('quarter', date) as quarter,
                    category,
                    SUM(points) AS points,
                    COUNT(id) AS count
               FROM task_on_date_recategorized
              WHERE status = 'resolved'
                AND date = daterow.date
                AND scope = scope_prefix
                AND id NOT IN (SELECT id
                                 FROM task_on_date_recategorized
                                WHERE status = 'resolved'
                                  AND scope = scope_prefix
                                  AND date = daterow.date - interval '1 day')
              GROUP BY date, category);

    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION populate_recently_closed_task(
    scope_prefix varchar(6)
    ) RETURNS void AS $$
DECLARE
  daterow record;
BEGIN

    FOR daterow IN SELECT DISTINCT date
                     FROM task_on_date_recategorized
                    WHERE scope = scope_prefix
                      AND date > now() - interval '14 days'
                    ORDER BY date
    LOOP

        INSERT INTO recently_closed_task (
             SELECT scope_prefix as scope,
                    thr.date,
                    thr.id,
                    thr.category,
		    thr.points as points
              FROM task_on_date_recategorized thr LEFT OUTER JOIN maniphest_task mt USING (id)
             WHERE thr.status = 'resolved'
               AND thr.date = daterow.date
               AND thr.scope = scope_prefix
               AND thr.id NOT IN (SELECT id
                                    FROM task_on_date
                                   WHERE status = 'resolved'
                                     AND scope = scope_prefix
                                     AND date = daterow.date - interval '1 day' )
               
             );
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION purge_leftover_and_omitted_task_on_date_rec(
    scope_prefix varchar(6)
    ) RETURNS void as $$
BEGIN

    DELETE FROM task_on_date_recategorized
     WHERE scope = scope_prefix
       AND category IS NULL;


    DELETE FROM task_on_date_recategorized
     WHERE category IN
           (SELECT title
              FROM category
             WHERE scope = scope_prefix
               AND display = 'omit');

    -- this query is hard-coded for the current contents of force_status_list
    -- if that list ever grows beyond 1 item, this query must be re-written
    UPDATE task_on_date_recategorized
       SET status = 'resolved'
     WHERE category IN
           (SELECT title
              FROM category
             WHERE scope = scope_prefix
               AND force_status = 'resolved');

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION reload_recat(
    scope_prefix varchar(6)
    ) RETURNS void as $$
BEGIN
    DELETE FROM task_on_date_recategorized WHERE scope = scope_prefix;

    /* INCOMPLETE */

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION recategorize_by_column(
    scope_prefix varchar(6),
    project_id_input int[],
    title text,
    matchstring text
) RETURNS void as $$
BEGIN

  UPDATE task_on_date_recategorized todr
     SET category = title
    FROM maniphest_edge me1
   WHERE todr.scope = scope_prefix
     AND me1.project = project_id_input[1]
     AND me1.task = todr.id
     AND me1.date = todr.date
     AND todr.category IS NULL
     AND todr.projectcolumn LIKE '%' || matchstring || '%';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION recategorize_by_parenttask(
    scope_prefix varchar(6),
    project_id_input int[],
    title text,
    matchstring text
) RETURNS void as $$
BEGIN

  UPDATE task_on_date_recategorized todr
     SET category = title
    FROM maniphest_edge me1
   WHERE todr.scope = scope_prefix
     AND me1.project = project_id_input[1]
     AND me1.task = todr.id
     AND me1.date = todr.date
     AND todr.category IS NULL
     AND todr.phab_category_title LIKE '%' || matchstring || '%';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION recategorize_by_project(
    scope_prefix varchar(6),
    project_id_input int[],
    title text
) RETURNS void as $$
BEGIN

  UPDATE task_on_date_recategorized todr
     SET category = title
    FROM maniphest_edge me1
   WHERE todr.scope = scope_prefix
     AND me1.project = project_id_input[1]
     AND me1.task = todr.id
     AND me1.date = todr.date
     AND todr.category IS NULL;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION recategorize_by_intersection(
    scope_prefix varchar(6),
    project_id int[],
    title text
) RETURNS void as $$

  UPDATE task_on_date_recategorized todr
     SET category = $3
    FROM maniphest_edge me1, maniphest_edge me2
   WHERE todr.scope = scope_prefix
     AND me1.project = $2[1]
     AND me1.task = todr.id
     AND me1.date = todr.date
     AND me2.project = $2[2]
     AND me2.task = todr.id
     AND me2.date = todr.date
     AND todr.category IS NULL;

$$ LANGUAGE SQL VOLATILE;


CREATE OR REPLACE FUNCTION set_category_retroactive(
    scope_prefix varchar(6)
    ) RETURNS void AS $$
DECLARE taskrow record;
BEGIN

FOR taskrow in SELECT id, category
                 FROM task_on_date_recategorized
                WHERE date = (SELECT MAX(date)
                                FROM task_on_date_recategorized
                               WHERE scope = scope_prefix)
                  AND scope = scope_prefix
  LOOP
    UPDATE task_on_date_recategorized t
       SET category = taskrow.category
     WHERE t.id = taskrow.id
       AND scope = scope_prefix;

  END LOOP;
  RETURN;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION set_points_retroactive(
    scope_prefix varchar(6)
    ) RETURNS void AS $$
BEGIN

    UPDATE task_on_date_recategorized t
       SET points = t0.points
      FROM task_on_date_recategorized t0
     WHERE t0.date = (SELECT MAX(date)
                        FROM task_on_date_recategorized
                       WHERE scope = scope_prefix)
       AND t0.scope = scope_prefix
       AND t.scope = scope_prefix
       AND t0.id = t.id;

    RETURN;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION wipe_reporting(
       scope_prefix varchar(6)
) RETURNS void AS $$
BEGIN
    DELETE FROM task_on_date_recategorized
     WHERE scope = scope_prefix;

    DELETE FROM task_on_date_agg
     WHERE scope = scope_prefix;

    DELETE FROM recently_closed
     WHERE scope = scope_prefix;

    DELETE FROM recently_closed_task
     WHERE scope = scope_prefix;

    DELETE FROM maintenance_week
     WHERE scope = scope_prefix;

    DELETE FROM maintenance_delta
     WHERE scope = scope_prefix;

    DELETE FROM velocity
     WHERE scope = scope_prefix;

    DELETE FROM open_backlog_size
     WHERE scope = scope_prefix;

END;
$$ LANGUAGE plpgsql;
