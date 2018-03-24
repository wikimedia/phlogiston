CREATE EXTENSION IF NOT EXISTS intarray;

DROP TABLE IF EXISTS maniphest_blocked;
DROP TABLE IF EXISTS maniphest_edge;
DROP TABLE IF EXISTS maniphest_edge_transaction;
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
       story_points text,
       status_at_load text
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
       task_id int references maniphest_task,
       object_phid text,
       transaction_type text,
       old_value text,
       new_value text,
       date_modified timestamp with time zone,
       metadata text
);

CREATE INDEX on maniphest_transaction (date_modified, transaction_type, task_id);
CREATE INDEX on maniphest_transaction (transaction_type, task_id);
CREATE INDEX on maniphest_transaction (task_id);

CREATE TABLE maniphest_edge_transaction (
       task_id int references maniphest_task,
       date_modified timestamp with time zone,
       old_value int[],
       new_value int[],
       metadata text,
       edges int[]
);

CREATE INDEX ON maniphest_edge_transaction (task_id, date_modified);

CREATE TABLE maniphest_edge(
       task int references maniphest_task,
       project int references phabricator_project,
       date date,
       unique (task, project, date)
);

-- No RI for this table because otherwise we would have to load all
-- tasks before any blocks
DROP TABLE IF EXISTS maniphest_blocked_phid;

CREATE TABLE maniphest_blocked_phid (
       blocked_date date,
       blocks_phid text,
       blocked_by_phid text
);

CREATE INDEX ON maniphest_blocked_phid (blocks_phid);
CREATE INDEX ON maniphest_blocked_phid (blocked_by_phid);

CREATE TABLE maniphest_blocked (
       blocked_date date,
       parent_id int references maniphest_task (id),
       child_id int references maniphest_task (id)
);

CREATE INDEX ON maniphest_blocked (parent_id);
CREATE INDEX ON maniphest_blocked (child_id);
