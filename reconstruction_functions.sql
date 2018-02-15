CREATE OR REPLACE FUNCTION build_edges(
       run_date date,
       project_id_list int array) RETURNS void AS $$
DECLARE
  dayrow record;
  taskrow record;
  projrow record;
  project_id int;
BEGIN

    FOR taskrow IN SELECT id
                     FROM maniphest_task
                    ORDER BY id
    LOOP
        FOR projrow IN SELECT active_projects
                         FROM maniphest_transaction
                        WHERE date_modified <= run_date
                          AND task_id = taskrow.id
                          AND has_edge_data IS TRUE
                     ORDER BY date_modified DESC
		       LIMIT 1
        LOOP
            FOREACH project_id IN ARRAY projrow.active_projects & project_id_list
            LOOP
                IF NOT EXISTS (SELECT *
                                 FROM maniphest_edge
                                WHERE task = taskrow.id
                                  AND project = project_id
                                  AND edge_date = run_date) THEN
                    INSERT INTO maniphest_edge
                    VALUES (taskrow.id, project_id, run_date);
                END IF;
            END LOOP;
        END LOOP;
    END LOOP;     

    RETURN;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_descendents(
       root_id int,
       run_date date
) RETURNS TABLE(id int) AS $$
BEGIN
  RETURN query
  WITH RECURSIVE search_mb(parent_id, child_id, depth, path, cycle) AS (
        SELECT parent_id,
	       child_id,
	       1,
	       ARRAY[parent_id],
               false
        FROM maniphest_blocked mb
       WHERE parent_id = root_id
      UNION ALL
        SELECT mb.parent_id,
	       mb.child_id,
	       smb.depth + 1,
               path || mb.parent_id,
               mb.parent_id = ANY(path)
        FROM maniphest_blocked mb, search_mb smb
        WHERE mb.parent_id = smb.child_id AND NOT cycle
  )
  SELECT child_id FROM search_mb;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION create_phab_parent_category_edges(
       scope_prefix varchar(6),
       working_date date,
       category_id int
) RETURNS void AS $$

  INSERT INTO phab_parent_category_edge (
  SELECT $1,
         $2,
         id,
         $3
    FROM (SELECT *
            FROM get_descendents($3, $2)) as x)

$$ LANGUAGE SQL VOLATILE;


CREATE OR REPLACE FUNCTION fix_status(
       scope_prefix varchar(6)
) RETURNS void AS $$
BEGIN

    UPDATE task_on_date th
       SET status = os.status_at_load
      FROM (SELECT task_id,
                   status_at_load
              FROM (
                    SELECT mt.task_id,
                           left(max(mt.new_value),15) as trans_status,
                           count(mt.date_modified) as num_of_changes,
                           max(mta.status_at_load) as status_at_load
                     FROM maniphest_transaction mt, maniphest_task mta
                    WHERE mt.transaction_type = 'status'
                      AND mt.task_id = mta.id
                    GROUP BY task_id) as flipflops
            WHERE num_of_changes = 1
                      AND trans_status <> status_at_load) os
     WHERE th.scope = scope_prefix
       AND th.id = os.task_id;

  -- NOTE: Not sure why the query above is so convoluted; suspect it's 
  -- corrected incorrect status values in some undocumented situation
  -- In order to fix T186827 without messing with anything the above query 
  -- fixes, let's fix blanks in addition to, rather than instead of, the above.


     UPDATE task_on_date tod
        SET status = mta.status_at_load
       FROM maniphest_task mta
      WHERE tod.id = mta.id
        AND status IS NULL OR status = ''
        AND scope = scope_prefix;


END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_phab_parent_categories_by_day(
       scope_prefix varchar(6),
       working_date date,
       category_tag_id int
) RETURNS TABLE(task int) AS $$

  SELECT DISTINCT task
    FROM task_on_date t, maniphest_edge m
   WHERE t.scope = $1
     AND m.edge_date = $2
     AND t.id = m.task
     AND m.project = $3;

$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION get_edge_value(
       working_date date,
       input_task_id int
) RETURNS int[] AS $$
BEGIN
  RETURN (
        SELECT mt.active_projects
          FROM maniphest_transaction mt
         WHERE date(mt.date_modified) <= working_date
           AND mt.task_id = input_task_id
           AND mt.has_edge_data IS TRUE
         ORDER BY date_modified DESC
         LIMIT 1
               );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_projects_by_name(
       matchstring text
) RETURNS TABLE(id int, name text) AS $$

  SELECT id, name
    FROM phabricator_project
   WHERE name LIKE $1;

$$ LANGUAGE SQL STABLE;


DROP FUNCTION get_category_rules(character varying);

CREATE OR REPLACE FUNCTION get_category_rules(
       scope_prefix varchar(6)
) RETURNS TABLE(rule categoryrule, project_id_list int[], project_name_list text[], matchstring text, title text, display displayrule) AS $$

  SELECT rule, project_id_list, project_name_list, matchstring, title, display
    FROM category
   WHERE scope = $1
   ORDER BY sort_order

$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION get_tasks(
       working_date date,
       project_ids int[]
) RETURNS TABLE(id int) AS $$

  SELECT DISTINCT task
    FROM maniphest_edge
   WHERE edge_date = $1
     AND project = ANY($2);

$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION get_transaction_value(
       working_date date,
       input_transaction_type text,
       input_task_id int
) RETURNS SETOF text AS $$
BEGIN
  RETURN QUERY (
    SELECT mt.new_value
      FROM maniphest_transaction mt
     WHERE date(mt.date_modified) <= working_date
       AND mt.transaction_type = input_transaction_type
       AND mt.task_id = input_task_id
     ORDER BY date_modified DESC
         );

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION put_category_tasks_in_own_category(
       scope_prefix varchar(6),
       category_id int
) RETURNS void AS $$
BEGIN
    UPDATE task_on_date th
       SET category_title = (
               SELECT mt.title
                 FROM maniphest_task mt
                WHERE th.id = mt.id
               )
     WHERE th.id in (
               SELECT DISTINCT task
                 FROM maniphest_edge
                WHERE project = category_id)
       AND th.scope = scope_prefix;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_phab_parent_category_titles(
       scope_prefix varchar(6),
       start_date date
) RETURNS void AS $$
BEGIN
    UPDATE task_on_date th
       SET category_title = (
           SELECT string_agg(title, ' ')
             FROM (
                   SELECT th_foo.id, mt.title
                     FROM maniphest_task mt,
                          phab_parent_category_edge ppce,
                          task_on_date th_foo
                    WHERE th_foo.id = ppce.task_id
                      AND th_foo.scope = ppce.scope
                      AND th_foo.date = ppce.date
                      AND ppce.category_id = mt.id
                      AND ppce.scope = scope_prefix
                    GROUP BY th_foo.id, mt.title
                    ) as foo
            WHERE id = th.id
            )
     WHERE scope = scope_prefix
       AND date >= start_date;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION wipe_reconstruction(
       scope_prefix varchar(6)
) RETURNS void AS $$
BEGIN
    DELETE FROM task_on_date
     WHERE scope = scope_prefix;

    DELETE FROM phab_parent_category_edge
     WHERE scope = scope_prefix;
END;
$$ LANGUAGE plpgsql;


