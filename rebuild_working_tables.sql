DROP TABLE IF EXISTS maniphest_edge;
DROP TABLE IF EXISTS maniphest_transaction;
DROP TABLE IF EXISTS maniphest_task;
DROP TABLE IF EXISTS phabricator_column;
DROP TABLE IF EXISTS phabricator_project;

CREATE TABLE phabricator_project (
       id int primary key,
       name text,
       phid text unique
);

CREATE TABLE maniphest_task (
       id int primary key,
       phid text unique,
       title text,
       story_points text
);

CREATE TABLE phabricator_column (
       id int primary key,
       phid text unique,
       name text,
       project_phid text references phabricator_project (phid)
);

CREATE TABLE maniphest_transaction (
       id int primary key,
       phid text unique,
       task_id int,
       object_phid text,
       transaction_type text,
       old_value text,
       new_value text,
       date_modified timestamp,
       active_projects int array
);

CREATE INDEX ON maniphest_transaction (object_phid, date(date_modified));

CREATE TABLE maniphest_edge (
       task int references maniphest_task,
       project int references phabricator_project,
       edge_date date,
       PRIMARY KEY (task, project, edge_date)
);

CREATE INDEX ON maniphest_edge (task, project, edge_date);
CREATE INDEX ON maniphest_edge (task);
CREATE INDEX ON maniphest_edge (project);

CREATE OR REPLACE FUNCTION build_edges() RETURNS void AS $$
BEGIN

FOR day IN SELECT DISTINCT date_modified
              FROM maniphest_transaction
	     ORDER BY date_modified LOOP
    FOR task IN SELECT ID
                  FROM maniphest_task LOOP
        FOR project_list IN SELECT active_projects
	                 FROM maniphest_transaction
			WHERE date(date_modified) <= day
			  AND mt.id = task
			ORDER BY date_modified DESC
			LIMIT 1 LOOP
	    FOREACH project IN ARRAY project_list LOOP
      	        INSERT task, project, day
 	          INTO maniphest_edge
	    END LOOP;
        END LOOP;
    END LOOP;    
END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
