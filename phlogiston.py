#!/usr/bin/python3

import configparser
import csv
import datetime
import html
import json
import os.path
import psycopg2
import sys
import pytz
import getopt
import subprocess
import time

from jinja2 import Template

def main(argv):
    try:
        opts, args = getopt.getopt(
            argv, "b:cde:hilnp:rs:v",
            ["dbname=", "reconstruct", "debug", "enddate", "help", "initialize",
             "load", "incremental", "scope_prefix=", "report", "startdate=",
             "verbose"])
    except getopt.GetoptError as e:
        print(e)
        usage()
        sys.exit(2)
    initialize = False
    load_data = False
    reconstruct_data = False
    run_report = False
    incremental = False
    DEBUG = False
    VERBOSE = False
    start_date = ''
    scope_prefix = ''
    dbname = 'phab'

    # Wikimedia Phabricator constants
    # https://phabricator.wikimedia.org/T119473
    global PHAB_TAGS
    PHAB_TAGS = dict(epic=942,
                     new=1453,
                     maint=1454,
                     category=1656)

    end_date = datetime.datetime.now().date()
    for opt, arg in opts:
        if opt in ("-b", "--dbname"):
            dbname = arg
        elif opt in ("-c", "--reconstruct"):
            reconstruct_data = True
        elif opt in ("-d", "--debug"):
            DEBUG = True
        elif opt in ("-e", "--end-date"):
            end_date = arg
        elif opt in ("-h", "--help"):
            usage()
            sys.exit()
        elif opt in ("-l", "--load"):
            load_data = True
        elif opt in ("-i", "--initialize"):
            initialize = True
        elif opt in ("-n", "--incremental"):
            incremental = True
        elif opt in ("-p", "--scope_prefix"):
            scope_prefix = arg
        elif opt in ("-r", "--report"):
            run_report = True
        elif opt in ("-s", "--startdate"):
            start_date = datetime.datetime.strptime(arg, "%Y-%m-%d").date()
        elif opt in ("-v", "--verbose"):
            VERBOSE = True

    conn = psycopg2.connect('dbname={0}'.format(dbname))
    conn.autocommit = True

    if initialize:
        do_initialize(conn, VERBOSE, DEBUG)

    if load_data:
        load(conn, end_date, VERBOSE, DEBUG)

    if scope_prefix:
        config = configparser.ConfigParser()
        config_filename = '{0}_scope.py'.format(scope_prefix)
        config.read(config_filename)

        try:
            scope_title = config['vars']['scope_title']
            project_name_list =  [x.strip() for x in config['vars']['project_list'].split(',')]
        except KeyError as e:
            print('Config file {0} is missing required parameter(s): {1}'.
                  format(scope_prefix, e))
            sys.exit(1)

        show_points = True
        if config.has_option('vars', 'show_points'):
            if not config.getboolean('vars','show_points'):
                show_points = False

        show_count = True
        if config.has_option('vars', 'show_count'):
            if not config.getboolean('vars','show_count'):
                show_count = False

        if config.has_option('vars', 'default_points'):
            default_points = config['vars']['default_points']
        else:
            default_points = ''

        if config.has_option('vars', 'backlog_resolved_cutoff'):
            backlog_resolved_cutoff = config['vars']['backlog_resolved_cutoff']
        else:
            backlog_resolved_cutoff = None

        if config.has_option('vars', 'retroactive_categories'):
            retroactive_categories = config['vars']['retroactive_categories']
        else:
            retroactive_categories = False

        if not start_date:
            try:
                start_date = datetime.datetime.strptime(
                    config['vars']['start_date'], "%Y-%m-%d").date()
            except KeyError:
                print('start_date must be in the config file or command line options')
                sys.exit(1)

    if reconstruct_data:
        if scope_prefix:
            reconstruct(conn, VERBOSE, DEBUG, default_points,
                        project_name_list, start_date, end_date,
                        scope_prefix, incremental)
        else:
            print("Reconstruct specified without a scope_prefix.\n Please specify a scope_prefix with --scope_prefix.")  # noqa
    if run_report:
        if scope_prefix:
            report(conn, dbname, VERBOSE, DEBUG, scope_prefix,
                   scope_title, default_points, project_name_list,
                   retroactive_categories, backlog_resolved_cutoff,
                   show_points, show_count)
        else:
            print("Report specified without a scope_prefix.\nPlease specify a scope_prefix with --scope_prefix.")  # noqa
    conn.close()

    if not (initialize or load_data or reconstruct_data or run_report):
        usage()
        sys.exit()


def usage():
    print("""Usage:\n
At least one of:
  --initialize       to create or recreate database tables and stored
                     procedures.\n
  --load             Load data from dump. This will wipe the previously
                     loaded data, but not any reconstructed data.\n
  --reconstruct      Use the loaded data to reconstruct a historical
                     record day by day, in the database.  This will wipe
                     previously reconstructed data for this scope_prefix unless
                     --incremental is also used.\n
  --report           Process data in SQL, generate graphs in R, and
                     output html and png in the ~/html directory.\n

Optionally:
  --debug        to work on a small subset of data and see extra information.\n
  --enddate      ending date for loading and reconstruction, as YYYY-MM-DD.
                 Defaults to now.\n
  --help         for this message.\n
  --incremental  Reconstruct only new data since the last reconstruction for
                 this scope_prefix.  Faster.\n
  --scope_prefix Unique prefix, six letters or fewer, labeling the scope of
                 Phabricator projects to be included in the report.  There must
                 be a configuration file named [prefix]_scope.py.  This is 
                 required for reconstruct and report.\n
  --startdate    The date reconstruction should start, as YYYY-MM-DD.\n
  --verbose      Show progress messages.\n""")


def do_initialize(conn, VERBOSE, DEBUG):
    cur = conn.cursor()
    cur.execute(open("loading_tables.sql", "r").read())
    cur.execute(open("reconstruction_tables.sql", "r").read())
    cur.execute(open("reconstruction_functions.sql", "r").read())
    cur.execute(open("reporting_tables.sql", "r").read())
    cur.execute(open("reporting_functions.sql", "r").read())


def load(conn, end_date, VERBOSE, DEBUG):
    cur = conn.cursor()
    cur.execute(open("loading_tables.sql", "r").read())

    if VERBOSE:
        print('{0} Loading dump file'.format(datetime.datetime.now()))
    with open('../phabricator_public.dump') as dump_file:
        data = json.load(dump_file)

    ######################################################################
    # Load project and project column data
    ######################################################################
    if VERBOSE:
        count = len(data['project']['projects'])
        print("{0} Load {1} projects".format(datetime.datetime.now(), count))

    project_insert = ("""INSERT INTO phabricator_project
                VALUES (%(id)s, %(name)s, %(phid)s)""")
    for row in data['project']['projects']:
        cur.execute(project_insert,
                    {'id': row[0], 'name': row[1], 'phid': row[2]})

    cur.execute("SELECT phid, id from phabricator_project")
    project_phid_to_id_dict = dict(cur.fetchall())

    column_insert = ("""INSERT INTO phabricator_column
                VALUES (%(id)s, %(phid)s, %(name)s, %(project_phid)s)""")
    if VERBOSE:
        count = len(data['project']['columns'])
        print("{0} Load {1} projectcolumns".format(datetime.datetime.now(), count))
    for row in data['project']['columns']:
        phid = row[1]
        project_phid = row[5]
        if project_phid in project_phid_to_id_dict:
            cur.execute(column_insert,
                        {'id': row[0], 'phid': phid,
                         'name': row[2], 'project_phid': project_phid})
        else:
            print("Data error for column {0}: project {1} doesn't exist.Skipping.".format(phid, project_phid))

    ######################################################################
    # Load transactions and edges
    ######################################################################

    transaction_insert = """
      INSERT INTO maniphest_transaction
      VALUES (%(id)s, %(phid)s, %(task_id)s, %(object_phid)s,
              %(transaction_type)s, %(new_value)s, %(date_modified)s,
              %(has_edge_data)s, %(active_projects)s)"""

    task_insert = """
      INSERT INTO maniphest_task
      VALUES (%(task_id)s, %(phid)s, %(title)s, %(story_points)s, %(status_at_load)s) """

    blocked_insert = """
      INSERT INTO maniphest_blocked_phid
      VALUES (%(date)s, %(phid)s, %(blocked_phid)s) """

    if VERBOSE:
        print("{0} Load tasks, transactions, and edges for {1} tasks".
              format(datetime.datetime.now(),len(data['task'].keys())))

    for task_id in data['task'].keys():
        task = data['task'][task_id]
        if task['info']:
            task_phid = task['info'][1]
            status_at_load = task['info'][4]
            title = task['info'][6]
        else:
            task_phid = ''
            status_at_load = ''
            title = ''
        if task['storypoints']:
            story_points = task['storypoints'][2]
        else:
            story_points = None
        cur.execute(task_insert, {'task_id': task_id,
                                  'phid': task_phid,
                                  'title': title,
                                  'story_points': story_points,
                                  'status_at_load': status_at_load})

        # Load blocked info for this task. When transactional data
        # becomes available, this should use that instead
        for edge in task['edge']:
            if edge[1] == 3:
                blocked_phid = edge[2]
                cur.execute(blocked_insert,
                            {'date': datetime.datetime.now().date(),
                             'phid': task_phid,
                             'blocked_phid': blocked_phid})

        # Load transactions for this task
        transactions = task['transactions']
        for trans_key in list(transactions.keys()):
            if transactions[trans_key]:
                for trans in transactions[trans_key]:
                    trans_type = trans[6]
                    new_value = trans[8]
                    date_mod = time.strftime('%m/%d/%Y %H:%M:%S',
                                             time.gmtime(trans[11]))
                    # If this is an edge transaction, parse out the
                    # list of transactions
                    has_edge_data = False
                    active_proj = list()
                    if trans_type == 'core:edge':
                        jblob = json.loads(new_value)
                        if jblob:
                            for key in jblob.keys():
                                if int(jblob[key]['type']) == 41:
                                    has_edge_data = True
                                    if key in project_phid_to_id_dict:
                                        proj_id = project_phid_to_id_dict[key]
                                        active_proj.append(proj_id)
                                    else:
                                        print("Data error for transaction {0}: project {1} doesn't exist. Skipping.".format(trans[1], key))
                    cur.execute(transaction_insert,
                                {'id': trans[0],
                                 'phid': trans[1],
                                 'task_id': task_id,
                                 'object_phid': trans[3],
                                 'transaction_type': trans_type,
                                 'new_value': new_value,
                                 'date_modified': date_mod,
                                 'has_edge_data': has_edge_data,
                                 'active_projects': active_proj})

    convert_blocked_phid_to_id_sql = """
        INSERT INTO maniphest_blocked
        SELECT mb.blocked_date, mt1.id, mt2.id
          FROM maniphest_blocked_phid mb,
               maniphest_task mt1,
               maniphest_task mt2
         WHERE mb.blocks_phid = mt1.phid
           AND mb.blocked_by_phid = mt2.phid"""

    cur.execute(convert_blocked_phid_to_id_sql)
    cur.close()


def reconstruct(conn, VERBOSE, DEBUG, default_points, project_name_list,
                start_date, end_date, scope_prefix, incremental):
    cur = conn.cursor()

    ######################################################################
    # preload project and column for fast lookup
    ######################################################################

    cur.execute("""SELECT name, phid
                   FROM phabricator_project
                  WHERE name IN %(project_name_list)s""",
                {'project_name_list': tuple(project_name_list)})
    project_name_to_phid_dict = dict(cur.fetchall())
    cur.execute("""SELECT name, id
                     FROM phabricator_project
                    WHERE name IN %(project_name_list)s""",
                {'project_name_list': tuple(project_name_list)})
    project_name_to_id_dict = dict(cur.fetchall())
    project_id_to_name_dict = {
        value: key for key, value in project_name_to_id_dict.items()}

    project_id_list = list()
    for project_name in project_name_list:
        try:
            project_id_list.append(project_name_to_id_dict[project_name])
        except KeyError:
            pass

    cur.execute("""SELECT pc.phid, pc.name
                     FROM phabricator_column pc,
                          phabricator_project pp
                    WHERE pc.project_phid = pp.phid
                      AND pp.id = ANY(%(project_id_list)s)""",
                {'project_id_list': project_id_list})
    column_dict = dict(cur.fetchall())
    # In addition to scope_prefix-specific projects, include special, global tags
    id_list_with_worktypes = list(project_id_list)
    for i in PHAB_TAGS.keys():
        id_list_with_worktypes.extend([PHAB_TAGS[i]])

    ######################################################################
    # Generate denormalized data
    ######################################################################
    # Generate denormalized edge data.  This is edge data for only the
    # projects of interest, but goes into a shared table for
    # simplicity.

    if incremental:
        max_date_query = """SELECT MAX(date)
                              FROM task_history
                             WHERE scope like %(scope_prefix)s"""
        cur.execute(max_date_query, {'scope_prefix': scope_prefix})
        try:
            start_date = cur.fetchone()[0].date()
        except AttributeError:
            print("No data available for incremental run.\nProbably this reconstruction should be run without --incremental.")
            sys.exit(1)
    else:
        cur.execute('SELECT wipe_reconstruction(%(scope_prefix)s)',
                    {'scope_prefix': scope_prefix})
        if not start_date:
            oldest_data_query = """
            SELECT DATE(min(date_modified)) FROM maniphest_transaction"""
            cur.execute(oldest_data_query)
            start_date = cur.fetchone()[0].date()

    working_date = start_date
    while working_date <= end_date:
        if VERBOSE:
            print('{0} {1}: Making maniphest_edge for {2}'.
                  format(scope_prefix, datetime.datetime.now(), working_date))
        cur.execute('SELECT build_edges(%(date)s, %(project_id_list)s)',
                    {'date': working_date,
                     'project_id_list': id_list_with_worktypes})
        working_date += datetime.timedelta(days=1)

    ######################################################################
    # Reconstruct historical state of tasks
    ######################################################################
    transaction_values_query = """
        SELECT mt.new_value
          FROM maniphest_transaction mt
         WHERE date(mt.date_modified) <= %(working_date)s
           AND mt.transaction_type = %(transaction_type)s
           AND mt.task_id = %(task_id)s
         ORDER BY date_modified DESC """

    edge_values_query = """
        SELECT mt.active_projects
          FROM maniphest_transaction mt
         WHERE date(mt.date_modified) <= %(working_date)s
           AND mt.task_id = %(task_id)s
           AND mt.has_edge_data IS TRUE
         ORDER BY date_modified DESC
         LIMIT 1 """

    working_date = start_date
    while working_date <= end_date:
        # because working_date is midnight at the beginning of the
        # day, use a date at the midnight at the end of the day to
        # make the queries line up with the date label
        if VERBOSE:
            print('{0} {1}: Reconstructing data for {2}'.
                  format(scope_prefix, datetime.datetime.now(), working_date))

        working_date += datetime.timedelta(days=1)
        task_on_day_query = """SELECT DISTINCT task
                                 FROM maniphest_edge
                                WHERE project = ANY(%(project_ids)s)
                                  AND edge_date = %(working_date)s"""
        cur.execute(task_on_day_query,
                    {'working_date': working_date,
                     'project_ids': project_id_list})
        for row in cur.fetchall():
            task_id = row[0]

            # ----------------------------------------------------------------------
            # Title and Points.  Currently points are a separate field
            # not in transaction data.  This means historical points
            # charts are actually retroactive.  Title could be tracked
            # retroactively but this code doesn't make that effort.
            # ----------------------------------------------------------------------
            task_query = """SELECT title, story_points
                              FROM maniphest_task
                             WHERE id = %(task_id)s"""
            cur.execute(task_query,
                        {'task_id': task_id,
                         'working_date': working_date,
                         'transaction_type': 'status'})
            task_info = cur.fetchone()
            pretty_title = task_info[0]
            try:
                pretty_points = int(task_info[1])
            except:
                pretty_points = default_points

            # for each relevant variable of the task, use the most
            # recent value that is no later than that day.  (So, if
            # that variable didn't change that day, use the last time
            # it was changed.  If it changed multiple times, use the
            # final value)

            # ----------------------------------------------------------------------
            # Status
            # ----------------------------------------------------------------------
            cur.execute(transaction_values_query,
                        {'working_date': working_date,
                         'transaction_type': 'status',
                         'task_id': task_id})
            status_raw = cur.fetchone()
            pretty_status = ""
            if status_raw:
                pretty_status = status_raw[0]

            # ----------------------------------------------------------------------
            # Priority
            # ----------------------------------------------------------------------
            cur.execute(transaction_values_query,
                        {'working_date': working_date,
                         'transaction_type': 'priority',
                         'task_id': task_id})
            priority_raw = cur.fetchone()
            pretty_priority = ""
            if priority_raw:
                pretty_priority = priority_raw[0]

            # ----------------------------------------------------------------------
            # Project & Maintenance Type
            # ----------------------------------------------------------------------
            cur.execute(edge_values_query,
                        {'task_id': task_id, 'working_date': working_date})
            edges = cur.fetchall()[0][0]
            pretty_project = ''

            if PHAB_TAGS['new'] in edges:
                maint_type = 'New Functionality'
            elif PHAB_TAGS['maint'] in edges:
                maint_type = 'Maintenance'
            else:
                maint_type = ''

            best_edge = ''
            # Reduce the list of edges to only the single best match,
            # where best = earliest in the specified project list
            for project in project_id_list:
                if project in edges:
                    best_edge = project
                    break

            if not best_edge:
                # This should be impossible since by this point we
                # only see tasks that have edges in the desired list.
                # However, certain transactions (gerrit Conduit
                # transactions) aren't properly parsed by Phlogiston.
                # See https://phabricator.wikimedia.org/T114021.  Skipping
                # these transactions should not affect the data for
                # our purposes.
                continue

            pretty_project = project_id_to_name_dict[best_edge]
            project_phid = project_name_to_phid_dict[pretty_project]

            # ----------------------------------------------------------------------
            # Column
            # ----------------------------------------------------------------------
            pretty_column = ''
            cur.execute(transaction_values_query,
                        {'working_date': working_date,
                         'transaction_type': 'projectcolumn',
                         'task_id': task_id})
            pc_trans_list = cur.fetchall()
            for pc_trans in pc_trans_list:
                jblob = json.loads(pc_trans[0])
                if project_phid in jblob['projectPHID']:
                    column_phid = jblob['columnPHIDs'][0]
                    pretty_column = column_dict[column_phid]
                    break

            denorm_insert = """
                INSERT INTO task_history VALUES (
                %(scope_prefix)s,
                %(working_date)s,
                %(id)s,
                %(title)s,
                %(status)s,
                %(project)s,
                %(projectcolumn)s,
                %(points)s,
                %(maint_type)s,
                %(priority)s)"""

            cur.execute(denorm_insert, {'scope_prefix': scope_prefix, 'working_date': working_date, 'id': task_id, 'title': pretty_title, 'status': pretty_status, 'priority': pretty_priority, 'project': pretty_project, 'projectcolumn': pretty_column, 'points': pretty_points, 'maint_type': maint_type})  # noqa

        # This takes the as-is blocked by relationships and
        # reconstructs them historically as if they existed every day;
        # this excess design is in case this is ever switched to do
        # full reconstruction.  see
        # https://phabricator.wikimedia.org/T115936#1847188

        categories_on_day_query = """
          SELECT DISTINCT task
            FROM task_history t, maniphest_edge m
           WHERE t.scope = %(scope_prefix)s
             AND m.edge_date = %(working_date)s
             AND t.id = m.task
             AND m.project = %(category_tag_id)s"""

        cur.execute(categories_on_day_query,
                    {'scope_prefix': scope_prefix,
                     'working_date': working_date,
                     'category_tag_id': PHAB_TAGS['category']})
        for row in cur.fetchall():
            category_id = row[0]
            task_category_insert = """
            INSERT INTO task_category (
            SELECT %(scope_prefix)s,
                   %(working_date)s,
                   id,
                   %(category_id)s
              FROM (SELECT *
                      FROM find_descendents(%(category_id)s,
                                            %(working_date)s)) as x)"""
            cur.execute(task_category_insert,
                        {'scope_prefix': scope_prefix,
                         'category_id': category_id,
                         'working_date': working_date})

    categories_sql = """
        UPDATE task_history th
           SET category_title = (
               SELECT string_agg(title, ' ') 
                 FROM (
                       SELECT th_foo.id, mt.title
                         FROM maniphest_task mt,
                              task_category tm,
                              task_history th_foo
                        WHERE th_foo.id = tm.task_id
                          AND th_foo.scope = tm.scope
                          AND th_foo.date = tm.date
                          AND tm.category_id = mt.id
                          AND tm.scope = %(scope_prefix)s
                        GROUP BY th_foo.id, mt.title
                        ) as foo
                WHERE id = th.id
                )
         WHERE scope = %(scope_prefix)s
           AND date >= %(start_date)s"""

    # Special case to put all category-tagged tasks in their own category
    category_self_sql = """
        UPDATE task_history th
           SET category_title = (
                   SELECT mt.title
                     FROM maniphest_task mt
                    WHERE th.id = mt.id
                   )
         WHERE th.id in (
                   SELECT DISTINCT task
                     FROM maniphest_edge
                    WHERE project = %(category_id)s)
               AND th.scope = %(scope_prefix)s"""

    if VERBOSE:
        print('{0} {1} Updating Category Titles'.
              format(scope_prefix, datetime.datetime.now()))
    cur.execute(categories_sql,{'scope_prefix': scope_prefix, 'start_date': start_date})
    cur.execute(category_self_sql,{'scope_prefix': scope_prefix,
                                   'category_id': PHAB_TAGS['category'] })

    correct_status_sql = """
        UPDATE task_history th
           SET status = os.status_at_load
          FROM (SELECT task_id,
                       status_at_load
                  FROM (
                        SELECT mt.task_id,
                               left(max(mt.new_value),15) as trans_status,
                               count(mt.date_modified) as num_of_changes,
                               max('"' || mta.status_at_load || '"') as status_at_load
                         FROM maniphest_transaction mt, maniphest_task mta
                        WHERE mt.transaction_type = 'status'
                          AND mt.task_id = mta.id
                        GROUP BY task_id) as flipflops
                WHERE num_of_changes = 1
                          AND trans_status <> status_at_load) os
         WHERE th.scope = %(scope_prefix)s
           AND th.id = os.task_id"""

    if VERBOSE:
        print('{0} {1}: Correcting corrupted task status info'.
                  format(scope_prefix, datetime.datetime.now()))
    cur.execute(correct_status_sql,{'scope_prefix': scope_prefix})
    cur.close()
    

def report(conn, dbname, VERBOSE, DEBUG, scope_prefix,
           scope_title, default_points, project_name_list,
           retroactive_categories, backlog_resolved_cutoff,
           show_points, show_count):
    # note that all the COPY commands in the psql scripts run
    # server-side as user postgres
  
    ######################################################################
    # Prepare the data
    ######################################################################

    cur = conn.cursor()
    size_query = """SELECT count(*)
                      FROM task_history
                     WHERE scope = %(scope_prefix)s"""
    cur.execute(size_query, {'scope_prefix': scope_prefix})
    data_size = cur.fetchone()[0]
    if data_size == 0:
        print("ERROR: no data in task_history for {0}".format(scope_prefix))
        sys.exit(-1)

    cur.execute('SELECT wipe_reporting(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})

    # generate the summary reporting data from the reconstructed records
    report_tables_script = '{0}_make_history.sql'.format(scope_prefix)
    if not os.path.isfile(report_tables_script):
        report_tables_script = 'generic_make_history.sql'
    subprocess.call("psql -d {0} -f {1} -v scope_prefix={2}".
                    format(dbname, report_tables_script, scope_prefix), shell=True)

    if backlog_resolved_cutoff:
        cur.execute('SELECT no_resolved_before_start(%(scope_prefix)s, %(backlog_resolved_cutoff)s)',
                    {'scope_prefix': scope_prefix, 'backlog_resolved_cutoff': backlog_resolved_cutoff})


    # Reload the Recategorization mapping
    recat_data = '{0}_recategorization.csv'.format(scope_prefix)
    if os.path.isfile(recat_data):
        category_save = """
        INSERT INTO category_list
        VALUES (%(scope_prefix)s, %(sort_order)s, %(category)s, %(t1)s, %(t2)s, %(matchstring)s, %(zoom)s)"""
        recat_cases = ''
        recat_else = ''
        with open(recat_data, 'rt') as f:
            reader = csv.DictReader(f)
            for line in reader:
                try:
                    matchstring = '%' + line['matchstring'] + '%'
                except (KeyError,  TypeError):
                    matchstring = ''

                t1 = None
                try:
                    if line['t1']:
                        t1 = line['t1']
                except KeyError:
                    pass

                t2 = None
                try:
                    if line['t2']:
                        t2 = line['t2']
                except KeyError:
                    pass

                if line['zoom_list'].lower() in ['true', 't', '1', 'yes', 'y']:
                    zoom = True
                else:
                    zoom = False
                cur.execute(category_save,
                            {'scope_prefix': scope_prefix,
                             'sort_order': line['sort_order'],
                             'category': line['title'],
                             't1': t1,
                             't2': t2,
                             'matchstring': matchstring,
                             'zoom': zoom})

                # build up the recategorization query
                if line['matchstring'] == 'PhlogOther':
                    recat_else = line['title']
                elif t1:
                    # if a tag is specified, handle this later
                    pass
                elif matchstring:
                    recat_cases += ' WHEN category LIKE \'{0}\' THEN \'{1}\''.format(  # noqa
                        matchstring, line['title'])
                else:
                    print('Bad line in recat file: {0}'.format(line))

        if recat_cases:
            recat_update = """UPDATE task_history_recat
                                 SET category = CASE {0}
                                                ELSE '{1}'
                                                END
                               WHERE scope =  '{2}'"""
            unsafe_recat_update = recat_update.format(recat_cases, recat_else, scope_prefix)
        else:
            recat_update = """UPDATE task_history_recat 
                                        SET category = \'{0}\'
                               WHERE scope = '{1}'"""
            unsafe_recat_update = recat_update.format(recat_else, scope_prefix)

        if VERBOSE:
            print('{0} {1}: Applying recategorization'.
                  format(scope_prefix, datetime.datetime.now()))
        cur.execute(unsafe_recat_update)
        cur.execute('SELECT apply_tag_based_recategorization(%(scope_prefix)s)',
                    {'scope_prefix': scope_prefix})

    else:
        # Build a category list from the data
        category_insert = """INSERT INTO category_list (
                         SELECT %(scope_prefix)s,
                                row_number() OVER(ORDER BY category asc),
                                category,
                                NULL,
                                NULL,
                                NULL,
                                TRUE
                           FROM (SELECT DISTINCT category
                                   FROM task_history_recat
                                  WHERE scope = %(scope_prefix)s
                                  ORDER BY category) as foo)"""
        cur.execute(category_insert, {'scope_prefix': scope_prefix})

    if retroactive_categories:
        cur.execute('SELECT set_category_retroactive(%(scope_prefix)s)',
                    {'scope_prefix': scope_prefix})

    tall_backlog_insert = """INSERT INTO tall_backlog(
                             SELECT scope,
                                    date,
                                    category,
                                    status,
                                    SUM(points) as points,
                                    COUNT(title) as count,
                                    maint_type
                               FROM task_history_recat
                              WHERE scope = %(scope_prefix)s
                              GROUP BY status, category, maint_type, date, scope)"""

    cur.execute(tall_backlog_insert, {'scope_prefix': scope_prefix})
    cur.execute('SELECT find_recently_closed(%(scope_prefix)s)', {'scope_prefix': scope_prefix})
    cur.execute('SELECT find_recently_closed_task(%(scope_prefix)s)', {'scope_prefix': scope_prefix})

    ######################################################################
    # Prepare all the csv files and working directories
    ######################################################################
    # working around dynamic filename constructions limitations in
    # psql rather than try to write the file /tmp/foo/report.csv,
    # write the file /tmp/phlog/report.csv and then move it to
    # /tmp/foo/report.csv

    subprocess.call('rm -rf /tmp/{0}/'.format(scope_prefix), shell=True)
    subprocess.call('rm -rf /tmp/phlog/', shell=True)
    subprocess.call('mkdir -p /tmp/{0}'.format(scope_prefix), shell=True)
    subprocess.call('chmod g+w /tmp/{0}'.format(scope_prefix), shell=True)
    subprocess.call('mkdir -p /tmp/phlog', shell=True)
    subprocess.call('chmod g+w /tmp/phlog', shell=True)
    subprocess.call('psql -d {0} -f make_report_csvs.sql -v scope_prefix={1}'.
                    format(dbname, scope_prefix), shell=True)
    subprocess.call('mv /tmp/phlog/* /tmp/{0}/'.
                    format(scope_prefix), shell=True)
    subprocess.call('rm ~/html/{0}_*'.format(scope_prefix), shell=True)

    script_dir = os.path.dirname(__file__)
    
    subprocess.call('cp /tmp/{0}/maintenance_fraction_total_by_points.csv ~/html/{0}_maintenance_fraction_total_by_points.csv'.format(scope_prefix), shell=True)
    subprocess.call('cp /tmp/{0}/maintenance_fraction_total_by_count.csv ~/html/{0}_maintenance_fraction_total_by_count.csv'.format(scope_prefix), shell=True)
    subprocess.call('cp /tmp/{0}/category_possibilities.txt ~/html/{0}_category_possibilities.txt'.format(scope_prefix), shell=True)

    file = '{0}_projects.csv'.format(scope_prefix)
    f = open(os.path.join(script_dir, '../html/', file), 'w')
    for project_name in project_name_list:
        f.write("{0}\n".format(project_name))
    f.close()

    file = '{0}_default_points.csv'.format(scope_prefix)
    f = open(os.path.join(script_dir, '../html/', file), 'w')
    f.write("{0}\n".format(default_points))
    f.close()

    ######################################################################
    # for each category, generate burnup charts
    ######################################################################
    cat_query = """SELECT category,
                          zoom
                     FROM (SELECT z.category,
                                  bool_or(z.zoom) as zoom,
                                  max(z.sort_order) as sort_order,
                                  sum(t.count) as xcount
                             FROM category_list z, tall_backlog t
                            WHERE z.scope = %(scope_prefix)s
                              AND z.scope = t.scope
                              AND z.category = t.category
                            GROUP BY z.category) as foo
                    WHERE xcount > 0
                   ORDER BY sort_order"""

    cur.execute(cat_query, {'scope_prefix': scope_prefix})
    cat_list = cur.fetchall()
    colors = []
    proc = subprocess.check_output("Rscript get_palette.R {0}".
                                   format(len(cat_list)), shell=True)
    color_output = proc.decode().split()
    for item in color_output:
        if '#' in item:
            colors.append(item)
    i = 0
    tab_string = '<table><tr>'
    html_string = '<div class="tabs">'
    for cat_entry in reversed(cat_list):
        category = cat_entry[0]
        try:          
            color = colors[i]
        except:
            color = '#DDDDDD'

        subprocess.call(
            'Rscript make_tranche_chart.R {0} {1} \"{2}\" \"{3}\"'.
            format(scope_prefix, i, color, category), shell=True)
        tab_string += '<td><a href="#tab{0}">{1}</a></td>'.format(i,category)
        html_string += '<p id="tab{0}"><table>'.format(i)
        points_png_name = "{0}_tranche{1}_burnup_points.png".format(scope_prefix, i)
        count_png_name = "{0}_tranche{1}_burnup_count.png".format(scope_prefix, i)
        html_string += '<tr><td><a href="{0}"><img src="{0}"/></a></td>'.format(points_png_name)
        html_string += '<td><a href="{0}"><img src="{0}"/></a></tr>\n'.format(count_png_name)
        points_png_name = "{0}_tranche{1}_velocity_points.png".format(scope_prefix, i)
        count_png_name = "{0}_tranche{1}_velocity_count.png".format(scope_prefix, i)
        html_string += '<tr><td><a href="{0}"><img src="{0}"/></a></td>'.format(points_png_name)
        html_string += '<td><a href="{0}"><img src="{0}"/></a></tr>\n'.format(count_png_name)
        points_png_name = "{0}_tranche{1}_forecast_points.png".format(scope_prefix, i)
        count_png_name = "{0}_tranche{1}_forecast_count.png".format(scope_prefix, i)
        html_string += '<tr><td><a href="{0}"><img src="{0}"/></a></td>'.format(points_png_name)
        html_string += '<td><a href="{0}"><img src="{0}"/></a></tr>\n'.format(count_png_name)
        html_string += '</table></p>\n'
        i += 1
    tab_string += '</tr></table>'
    html_string += '</div>'

    file = '{0}_tranches.html'.format(scope_prefix)
    f = open(os.path.join(script_dir, '../html/', file), 'w')
    f.write(tab_string)
    f.write(html_string)
    f.close()

    toc_string = '<p>Per-category burnups</p><ul>'
    for cat_entry in cat_list:
        category = cat_entry[0]
        zoom = cat_entry[1]
        if zoom:
            toc_string += '<li><a href="#tab{0}">{1}</a></li>'.format(i,category)
    toc_string += '</ul>'
    file_toc = '{0}_tranche_toc.html'.format(scope_prefix)
    f = open(os.path.join(script_dir, '../html/', file_toc), 'w')
    f.write(toc_string)
    f.close()

    forecast_query = """
        SELECT v.category,
               pes_points_fore,
               nom_points_fore,
               opt_points_fore,
               pes_count_fore,
               nom_count_fore,
               opt_count_fore
          FROM velocity v, category_list z
         WHERE v.scope = %(scope_prefix)s
           AND v.scope = z.scope
           AND v.category = z.category
           AND v.count_total IS NOT NULL
           AND v.date = (SELECT MAX(date)
                           FROM velocity
                          WHERE scope = %(scope_prefix)s
                            AND count_total IS NOT NULL)
         ORDER BY sort_order"""

    html_string = """<p><table border="1px solid lightgray" cellpadding="2" cellspacing="0"><tr><th rowspan="3">Category</th><th colspan="6">Weeks until completion</th></tr>
                               <tr><th colspan="3">By Points</th><th colspan="3">By Count</th></tr>
                               <tr><th>Pess.</th><th>Nominal</th><th>Opt.</th><th>Pess.</th><th>Nominal</th><th>Opt.</th></tr>"""
    cur.execute(forecast_query, {'scope_prefix': scope_prefix})
    for row in cur.fetchall():
        html_string += "<tr><td>{0}</td><td>{1}</td><td><b>{2}</b></td><td>{3}</td><td>{4}</td><td><b>{5}</b></td><td>{6}</td>".format(row[0],row[1],row[2],row[3],row[4],row[5],row[6])

    html_string += "</table></p>"

    file = '{0}_current_forecasts.html'.format(scope_prefix)
    f = open(os.path.join(script_dir, '../html/', file), 'w')
    f.write(html_string)
    f.close()

    open_task_category_query = """SELECT id,
                                         title,
                                         category
                                    FROM task_history_recat
                                   WHERE scope = %(scope_prefix)s
                                     AND status = '"open"'
                                     AND date = (SELECT MAX(date)
                                                   FROM task_history_recat
                                                  WHERE scope = %(scope_prefix)s)
                                ORDER BY category, title"""

    html_string = """<p><table border="1px solid lightgray" cellpadding="2" cellspacing="0"><tr><th>ID</th><th>Task</th><th>Category</th></tr>"""  # noqa
    cur.execute(open_task_category_query, {'scope_prefix': scope_prefix})
    for row in cur.fetchall():
        html_string += "<tr><td><a href=\"https://phabricator.wikimedia.org/T{0}\">{0}</a></td><td>{1}</td><td>{2}</td></tr>".format(row[0],html.escape(row[1]),html.escape(row[2]))

    html_string += "</table></p>"
    file = '{0}_open_by_category.html'.format(scope_prefix)
    f = open(os.path.join(script_dir, '../html/', file), 'w')
    f.write(html_string)
    f.close()
    
    recently_closed_query = """SELECT id,
                                      title,
                                      date,
                                      category
                                 FROM recently_closed_task
                                WHERE scope = %(scope_prefix)s
                             ORDER BY category, date, id"""

    html_string = """<p><table border="1px solid lightgray" cellpadding="2" cellspacing="0"><tr><th>Date</th><th>Category</th><th>Task</th></tr>"""  # noqa
    cur.execute(recently_closed_query, {'scope_prefix': scope_prefix})
    for row in cur.fetchall():
        html_string += "<tr><td>{2}</td><td>{3}</td><td><b><a href=\"https://phabricator.wikimedia.org/T{0}\">{0}: {1}</a></td></tr>".format(row[0],row[1],row[2],row[3])

    html_string += "</table></p>"
    file = '{0}_recently_closed.html'.format(scope_prefix)
    f = open(os.path.join(script_dir, '../html/', file), 'w')
    f.write(html_string)
    f.close()

    ######################################################################
    # Make the rest of the charts
    ######################################################################
    subprocess.call("Rscript make_charts.R {0} {1} {2}".
                    format(scope_prefix, scope_title, 'True'), shell=True)

    subprocess.call("Rscript make_charts.R {0} {1} {2}".
                    format(scope_prefix, scope_title, 'False'), shell=True)

    ######################################################################
    # Update dates
    ######################################################################

    max_date_query = """
        SELECT MAX(date_modified), now()
          FROM task_history th, maniphest_transaction mt
         WHERE th.scope = %(scope_prefix)s
           AND th.id = mt.task_id"""

    cur.execute(max_date_query, {'scope_prefix': scope_prefix})
    result = cur.fetchone()
    max_date = result[0]
    now_db = result[1]
    utc = pytz.utc
    pt = pytz.timezone('America/Los_Angeles')
    max_date_utc = max_date.astimezone(utc).strftime('%a %Y-%b-%d %I:%M %p') 
    max_date_pt =  max_date.astimezone(pt).strftime('%a %Y-%b-%d %I:%M %p')
    now_utc = now_db.astimezone(utc).strftime('%a %Y-%b-%d %I:%M %p')
    now_pt = now_db.astimezone(pt).strftime('%a %Y-%b-%d %I:%M %p') 

    date_row_html = Template(open('html/date_row.html').read())
    date_row_output = open(os.path.join(script_dir, '../html/{0}_date_row'.format(scope_prefix)), 'w')
    date_row_output.write(date_row_html.render(
        { 'max_date_pt': max_date_pt,
          'now_pt': now_pt
        }))
    date_row_output.close()

    report_html = Template(open('html/report.html').read())
    report_output = open(os.path.join(script_dir, '../html/{0}_report.html'.format(scope_prefix)), 'w')
    report_output.write(report_html.render(
        {'title': scope_title,
         'scope_prefix': scope_prefix,
         'show_points': show_points,
         'show_count': show_count,
         'max_date_pt': max_date_pt,
         'max_date_utc': max_date_utc,
         'now_pt': now_pt,
         'now_utc': now_utc,
        }))
    report_output.close()

    cur.close()
    
if __name__ == "__main__":
    main(sys.argv[1:])
