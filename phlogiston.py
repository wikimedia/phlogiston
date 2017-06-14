#!/usr/bin/python3

import bisect
import configparser
import csv
import datetime
from dateutil import relativedelta as rd
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
    global DEBUG
    global VERBOSE
    DEBUG = False
    VERBOSE = False
    start_date = ''
    scope_prefix = ''
    dbname = 'phlogiston'
    today = datetime.datetime.now().date()

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
            start_date = read_date(arg)
        elif opt in ("-v", "--verbose"):
            VERBOSE = True

    conn = psycopg2.connect('dbname={0}'.format(dbname))
    conn.autocommit = True

    if initialize:
        do_initialize(conn)

    if load_data:
        load(conn, end_date)

    if scope_prefix:
        config = configparser.ConfigParser()
        config_filename = '{0}_scope.py'.format(scope_prefix)
        config.read(config_filename)

        try:
            scope_title = config['vars']['scope_title']
        except KeyError as e:
            print('Config file {0} is missing required parameter(s): {1}'.
                  format(scope_prefix, e))
            sys.exit(1)

        show_points = True
        if config.has_option('vars', 'show_points'):
            if not config.getboolean('vars', 'show_points'):
                show_points = False

        show_count = True
        if config.has_option('vars', 'show_count'):
            if not config.getboolean('vars', 'show_count'):
                show_count = False

        default_points = None
        if config.has_option('vars', 'default_points'):
            default_points = config['vars']['default_points']

        backlog_resolved_cutoff = None
        if config.has_option('vars', 'backlog_resolved_cutoff'):
            input_brc = config['vars']['backlog_resolved_cutoff']
            if isinstance(read_date(input_brc), datetime.date):
                backlog_resolved_cutoff = read_date(input_brc)
            if input_brc.lower() in ['default', 'true', 't', 'yes', '1']:
                backlog_resolved_cutoff = start_of_quarter(today)

        status_report_start = start_of_quarter(today)
        if config.has_option('vars', 'status_report_start'):
            input_srs = config['vars']['status_report_start']
            if isinstance(input_srs, int):
                status_report_start = today - rd.relativedelta(days=input_srs)
            elif isinstance(read_date(input_srs), datetime.date):
                status_report_start = read_date(input_srs)

        status_report_project = None
        if config.has_option('vars', 'status_report_project'):
            status_report_project = config['vars']['status_report_project']

        retroactive_categories = False
        if config.has_option('vars', 'retroactive_categories'):
            if config.getboolean('vars', 'retroactive_categories'):
                retroactive_categories = True

        retroactive_points = False
        if config.has_option('vars', 'retroactive_points'):
            if config.getboolean('vars', 'retroactive_points'):
                retroactive_points = True

        if not start_date:
            if config.has_option('vars', 'start_date'):
                start_date = read_date(config['vars']['start_date'])
            if not start_date:
                start_date = start_of_quarter(today) - rd.relativedelta(months=+3)

    if reconstruct_data:
        if scope_prefix:
            reconstruct(conn, default_points,
                        start_date, end_date,
                        scope_prefix, incremental,
                        status_report_project)
        else:
            print("Reconstruct specified without a scope_prefix.\n Please specify a scope_prefix with --scope_prefix.")  # noqa
    if run_report:
        if scope_prefix:
            report(conn, dbname, scope_prefix,
                   scope_title, default_points,
                   retroactive_categories, retroactive_points,
                   backlog_resolved_cutoff, show_points, show_count, start_date,
                   status_report_start, status_report_project)
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


def do_initialize(conn):
    cur = conn.cursor()
    cur.execute(open("loading_tables.sql", "r").read())
    cur.execute(open("loading_functions.sql", "r").read())
    cur.execute(open("reconstruction_tables.sql", "r").read())
    cur.execute(open("reconstruction_functions.sql", "r").read())
    cur.execute(open("reporting_tables.sql", "r").read())
    cur.execute(open("reporting_functions.sql", "r").read())


def load(conn, end_date):
    cur = conn.cursor()
    cur.execute(open("loading_tables.sql", "r").read())

    log('Dump file load starting', 'load')
    with open('../phabricator_public.dump') as dump_file:
        data = json.load(dump_file)

    ######################################################################
    # Load project and project column data
    ######################################################################

    project_count = len(data['project']['projects'])
    log('{0} projects loading'.format(project_count), 'load')

    project_insert = ("""INSERT INTO phabricator_project
                VALUES (%(id)s, %(name)s, %(phid)s)""")
    for row in data['project']['projects']:
        cur.execute(project_insert,
                    {'id': row[0], 'name': row[1], 'phid': row[2]})

    cur.execute("SELECT phid, id from phabricator_project")
    project_phid_to_id_dict = dict(cur.fetchall())

    column_insert = ("""INSERT INTO phabricator_column
                VALUES (%(id)s, %(phid)s, %(name)s, %(project_phid)s)""")
    column_count = len(data['project']['columns'])
    log('{0} columns loading'.format(column_count), 'load')
    for row in data['project']['columns']:
        phid = row[1]
        project_phid = row[5]
        if project_phid in project_phid_to_id_dict:
            cur.execute(column_insert,
                        {'id': row[0], 'phid': phid,
                         'name': row[2], 'project_phid': project_phid})
        else:
            print("Data error for column {0}: project {1} doesn't exist.Skipping.".
                  format(phid, project_phid))

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

    task_count = len(data['task'].keys())
    log('Tasks, transactions, and edges for {0} tasks loading'.format(task_count), 'load')

    for task_id in data['task'].keys():
        task = data['task'][task_id]
        if task['info']:
            task_phid = task['info'][1]
            status_at_load = task['info'][4]
            title = task['info'][6]
            story_points = task['info'][10]
        else:
            task_phid = ''
            status_at_load = ''
            title = ''
            story_points = ''
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
        quote_trans_table = {ord('"'): None}
        for trans_key in list(transactions.keys()):
            if transactions[trans_key]:
                for trans in transactions[trans_key]:
                    trans_type = trans[6]
                    raw_new_value = trans[8]
                    if trans_type == 'status':
                        new_value = raw_new_value.translate(quote_trans_table)
                    else:
                        new_value = raw_new_value
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
                                        print("Data error for transaction {0}: project {1} doesn't exist. Skipping.".format(trans[1], key))  # noqa
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

    cur.execute('SELECT convert_blocked_phid_to_id_sql()')
    cur.close()
    log('Dump file load finished.', 'load')


def reconstruct(conn, default_points,
                start_date, end_date, scope_prefix, incremental,
                status_report_project):

    cur = conn.cursor()

    import_recategorization_file(conn, scope_prefix)
    project_id_list = get_project_list(conn, scope_prefix)[0]
    lookups = {}
    lookups['project_id_list'] = project_id_list

    ######################################################################
    # preload project and column for fast lookup
    ######################################################################

    cur.execute("""SELECT name, phid
                   FROM phabricator_project
                  WHERE id IN %(project_id_list)s""",
                {'project_id_list': tuple(project_id_list)})
    lookups['project_name_to_phid_dict'] = dict(cur.fetchall())
    cur.execute("""SELECT name, id
                     FROM phabricator_project
                    WHERE id IN %(project_id_list)s""",
                {'project_id_list': tuple(project_id_list)})
    project_name_to_id_dict = dict(cur.fetchall())
    lookups['project_id_to_name_dict'] = {
        value: key for key, value in project_name_to_id_dict.items()}

    cur.execute("""SELECT pc.phid, pc.name
                     FROM phabricator_column pc,
                          phabricator_project pp
                    WHERE pc.project_phid = pp.phid
                      AND pp.id = ANY(%(project_id_list)s)""",
                {'project_id_list': project_id_list})
    lookups['column_dict'] = dict(cur.fetchall())
    # In addition to scope_prefix-specific projects, include special, global tags
    reconstruction_id_list = list(project_id_list)
    for i in PHAB_TAGS.keys():
        reconstruction_id_list.extend([PHAB_TAGS[i]])
    # make sure every project in the status report list is also included
    if status_report_project:
        if status_report_project not in reconstruction_id_list:
            reconstruction_id_list.extend(status_report_project)

    ######################################################################
    # Generate denormalized data
    ######################################################################
    # Generate denormalized edge data.  This is edge data for only the
    # projects of interest, but goes into a shared table for
    # simplicity.

    if incremental:
        try:
            start_date = get_max_date(conn, scope_prefix)
        except AttributeError:
            print("No data available for incremental run.\nProbably this reconstruction should be run without --incremental.")  # noqa
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
        log('Maniphest_edge creation for {0}'.format(working_date), scope_prefix)

        cur.execute('SELECT build_edges(%(date)s, %(project_id_list)s)',
                    {'date': working_date,
                     'project_id_list': reconstruction_id_list})

        working_date += datetime.timedelta(days=1)

    ######################################################################
    # Reconstruct historical state of tasks
    ######################################################################

    working_date = start_date
    while working_date <= end_date:
        log('Task reconstruction for {0}'.format(working_date), scope_prefix)

        # because working_date is midnight at the beginning of the
        # day, increment the count before using it so that the
        # effective date used is midnight at the end of the day
        working_date += datetime.timedelta(days=1)

        cur.execute('SELECT get_tasks(%(working_date)s, %(project_ids)s)',
                    {'working_date': working_date,
                     'project_ids': project_id_list})
        for row in cur.fetchall():
            task_id = row[0]
            reconstruct_task_on_date(cur, task_id, working_date, scope_prefix, default_points, **lookups)  # noqa

        # Use as-is data to reconstruct certain relationships for working data
        # see https://phabricator.wikimedia.org/T115936#1847188
        cur.execute('SELECT * from get_phab_parent_categories_by_day(%(scope_prefix)s, %(working_date)s, %(category_tag_id)s)',  # noqa
                    {'scope_prefix': scope_prefix,
                     'working_date': working_date,
                     'category_tag_id': PHAB_TAGS['category']})
        for row in cur.fetchall():
            category_id = row[0]
            cur.execute('SELECT create_phab_parent_category_edges(%(scope_prefix)s, %(working_date)s, %(category_id)s)',  # noqa
                        {'scope_prefix': scope_prefix,
                         'category_id': category_id,
                         'working_date': working_date})

    log('Phab parent category titles updating', scope_prefix)
    cur.execute("SELECT update_phab_parent_category_titles(%s, %s)", (scope_prefix, start_date))  # noqa
    cur.execute("SELECT put_category_tasks_in_own_category(%s, %s)",
                (scope_prefix, PHAB_TAGS['category']))

    log('Corrupted task status info correcting', scope_prefix)

    cur.execute("SELECT fix_status(%s)", (scope_prefix,))
    cur.close()

    log('Reconstruction finished.', scope_prefix)


def report(conn, dbname, scope_prefix,
           scope_title, default_points,
           retroactive_categories, retroactive_points,
           backlog_resolved_cutoff, show_points, show_count, start_date,
           status_report_start, status_report_project):

    cur = conn.cursor()
    log('Report Starting', scope_prefix)
    report_date = datetime.datetime.now().date()
    current_quarter_start = start_of_quarter(report_date)
    next_quarter_start = current_quarter_start + rd.relativedelta(months=+3)
    previous_quarter_start = current_quarter_start + rd.relativedelta(months=-3)
    month_before_current_q_start = current_quarter_start + rd.relativedelta(months=-1)
    month_after_current_q_end = current_quarter_start + rd.relativedelta(months=+4)
    three_months_ago = report_date + rd.relativedelta(months=-3)

    # This config file is loaded during reconstruction.  Reload it here to
    # make it possible to run reporting without reconstruction
    check_for_empty_task_on_date(conn, scope_prefix)
    reset_reporting_tables(conn, scope_prefix)
    log('Recategorization Starting', scope_prefix)
    recategorize(conn, scope_prefix)
    log('Applying Retroactive values, if any', scope_prefix)
    if retroactive_categories:
        set_categories_retroactively(conn, scope_prefix)
    if retroactive_points:
        set_points_retroactively(conn, scope_prefix)
    log('Populating Recently Closed', scope_prefix)
    populate_recently_closed(conn, scope_prefix, start_date)
    log('Aggregating task records', scope_prefix)
    aggregate_task_on_date(conn, scope_prefix, backlog_resolved_cutoff)
    log('Generating CSVs', scope_prefix)
    generate_reporting_files(conn, scope_prefix, dbname)

    ######################################################################
    # for each category, generate burnup charts
    ######################################################################

    log('Tranche Reports starting', scope_prefix)
    cur.execute('SELECT * FROM get_categories(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})
    cat_list = cur.fetchall()
    colors = []
    proc = subprocess.check_output("Rscript get_palette.R {0}".
                                   format(len(cat_list)), shell=True)
    color_output = proc.decode().split()
    for item in color_output:
        if '#' in item:
            colors.append(item)

    i = 0
    for cat_entry in reversed(cat_list):
        category = cat_entry[0]
        try:
            color = colors[i]
        except:
            color = '"#DDDDDD"'

        tranche_args = {'scope_prefix': scope_prefix,
                        'i': i,
                        'color': color,
                        'category': category,
                        'report_date': report_date,
                        'chart_start': previous_quarter_start,
                        'chart_end': month_after_current_q_end,
                        'current_quarter_start': current_quarter_start,
                        'next_quarter_start': next_quarter_start}

        tranche_command = "Rscript make_tranche_chart.R {scope_prefix} {i} {color} \"{category}\" {report_date} {chart_start} {chart_end} {current_quarter_start} {next_quarter_start}"  # noqa
        if DEBUG:
            print("DEBUG: {0}".format(tranche_command.format(**tranche_args)))
        subprocess.call(tranche_command.format(**tranche_args), shell=True)

        i += 1

    log('Additional reports starting', scope_prefix)

    cur.execute('SELECT * FROM get_forecast_weeks(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})
    forecast_rows = cur.fetchall()
    forecast_html = Template(open('html/forecast.html').read())
    file_path = '../html/{0}_current_forecasts.html'.format(scope_prefix)

    script_dir = os.path.dirname(__file__)
    forecast_output = open(os.path.join(script_dir, file_path), 'w')
    forecast_output.write(forecast_html.render(
        {'forecast_rows': forecast_rows,
         'show_points': show_points,
         'show_count': show_count}))
    forecast_output.close()

    cur.execute('SELECT * FROM get_open_task_list(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})
    open_tasks_rows = cur.fetchall()
    open_tasks_html = Template(open('html/open_tasks.html').read())
    file_path = '../html/{0}_open_by_category.html'.format(scope_prefix)
    open_tasks_output = open(os.path.join(script_dir, file_path), 'w')
    open_tasks_output.write(open_tasks_html.render(
        {'open_tasks_rows': open_tasks_rows,
         'title': scope_title}))
    open_tasks_output.close()

    cur.execute('SELECT * FROM get_unpointed_tasks(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})
    unpointed_tasks_rows = cur.fetchall()
    unpointed_html = Template(open('html/unpointed.html').read())
    file_path = '../html/{0}_unpointed.html'.format(scope_prefix)
    unpointed_output = open(os.path.join(script_dir, file_path), 'w')
    unpointed_output.write(unpointed_html.render(
        {'unpointed_tasks_rows': unpointed_tasks_rows,
         'title': scope_title,
         }))
    unpointed_output.close()

    cur.execute('SELECT * FROM get_recently_closed_tasks(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})
    recently_closed_tasks_rows = cur.fetchall()
    recently_closed_html = Template(open('html/recently_closed.html').read())
    file_path = '../html/{0}_recently_closed.html'.format(scope_prefix)
    recently_closed_output = open(os.path.join(script_dir, file_path), 'w')
    recently_closed_output.write(recently_closed_html.render(
        {'recently_closed_tasks_rows': recently_closed_tasks_rows,
         'title': scope_title,
         }))
    recently_closed_output.close()

    if status_report_project:
        final_status_date = get_max_date(conn, scope_prefix)
        initial_status_date = status_report_start
        initial_status_date_lastq = previous_quarter_start
        final_status_date_lastq = current_quarter_start
        status_report_project_name = get_project_name(conn, status_report_project)
        date_list = [(initial_status_date, final_status_date, ''),
                     (initial_status_date_lastq, final_status_date_lastq, '_lastq')]
        for start_date, end_date, lastq in date_list:
            cur.execute('SELECT * FROM get_status_report(\
                             %(scope_prefix)s,\
                             %(status_report_project)s,\
                             %(start_date)s,\
                             %(end_date)s)',
                        {'scope_prefix': scope_prefix,
                         'status_report_project': status_report_project,
                         'start_date': start_date,
                         'end_date': end_date})
            query_rows = cur.fetchall()
            statuses = set(tuple([(row[2], row[6]) for row in query_rows]))
            status_count = len(statuses)
            status_list = sorted(statuses, key=lambda item: item[1], reverse=True)
            status_style_dict = {}
            for i, status in enumerate(status_list):
                value = int((i/status_count) * 30)
                status_style_dict[status[0]] = value
            status_report_rows = []
            for row in query_rows:
                new_row = list(row)
                new_row.append(status_style_dict[row[2]])
                status_report_rows.append(new_row)

            status_report_html = Template(open('html/status_report.html').read())
            file_path = '../html/{0}_status_report{1}.html'.format(scope_prefix, lastq)
            script_dir = os.path.dirname(__file__)
            status_report_output = open(os.path.join(script_dir, file_path), 'w')
            status_report_output.write(status_report_html.render(
                {'status_report_rows': status_report_rows,
                 'title': scope_title,
                 'status_report_project_name': status_report_project_name,
                 'start_date': start_date,
                 'end_date': end_date}))
            status_report_output.close()

    ######################################################################
    # Make the summary charts
    ######################################################################

    log('Summary charts starting', scope_prefix)

    for i in [True, False]:
        if i:
            # show hidden is true.  make a much bigger chart.
            chart_start = start_date
        else:
            # show hidden is false.  Set up smaller chart.
            chart_start = month_before_current_q_start
        # TODO: rewrite to use **kwargs?  see previous rscript invocation
        command = """Rscript make_charts.R {0} "{1}" {2} {3} {4} {5}\
        {6} {7} {8} {9}""".format(scope_prefix, scope_title, i,
                                  report_date, current_quarter_start, next_quarter_start,
                                  previous_quarter_start, chart_start,
                                  month_after_current_q_end, three_months_ago),
        if DEBUG:
            print("DEBUG: {0}".format(command))

        subprocess.call(command, shell=True)

    ######################################################################
    # Update dates
    ######################################################################

    max_trans_date_query = """
        SELECT MAX(date_modified), now()
          FROM task_on_date tod, maniphest_transaction mt
         WHERE tod.scope = %(scope_prefix)s
           AND tod.id = mt.task_id"""

    cur.execute(max_trans_date_query, {'scope_prefix': scope_prefix})
    result = cur.fetchone()
    max_date = result[0]
    now_db = result[1]
    utc = pytz.utc
    pt = pytz.timezone('America/Los_Angeles')
    max_date_utc = max_date.astimezone(utc).strftime('%a %Y-%b-%d %I:%M %p')
    max_date_pt = max_date.astimezone(pt).strftime('%a %Y-%b-%d %I:%M %p')
    now_utc = now_db.astimezone(utc).strftime('%a %Y-%b-%d %I:%M %p')
    now_pt = now_db.astimezone(pt).strftime('%a %Y-%b-%d %I:%M %p')

    date_row_html = Template(open('html/date_row.html').read())
    date_row_output = open(os.path.join(script_dir, '../html/{0}_date_row.html'.format(scope_prefix)), 'w')  # noqa
    date_row_output.write(date_row_html.render(
        {'max_date_pt': max_date_pt,
         'now_pt': now_pt
         }))
    date_row_output.close()

    cur.execute('SELECT * FROM get_category_rules(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})
    category_rules_list = cur.fetchall()
    project_list = get_project_list(conn, scope_prefix)
    project_name_list = zip(project_list[0], project_list[1])
    rules_html = Template(open('html/rules.html').read())
    rules_output = open(os.path.join(script_dir, '../html/{0}_rules.html'.format(scope_prefix)), 'w')  # noqa
    rules_output.write(rules_html.render(
        {'title': scope_title,
         'start_date': start_date,
         'project_name_list': project_name_list,
         'category_rules_list': category_rules_list,
         'category_id': PHAB_TAGS['category']
         }))
    rules_output.close()

    report_html = Template(open('html/report.html').read())
    report_output = open(os.path.join(script_dir, '../html/{0}_report.html'.format(scope_prefix)), 'w')  # noqa
    report_output.write(report_html.render(
        {'title': scope_title,
         'scope_prefix': scope_prefix,
         'default_points': default_points,
         'show_points': show_points,
         'show_count': show_count,
         'max_date_pt': max_date_pt,
         'max_date_utc': max_date_utc,
         'now_pt': now_pt,
         'now_utc': now_utc,
         'category_count': len(cat_list),
         'category_list': cat_list,
         'rev_category_list': reversed(cat_list),
         'retroactive_categories': retroactive_categories,
         'retroactive_points': retroactive_points,
         'backlog_resolved_cutoff': backlog_resolved_cutoff,
         }))
    report_output.close()

    cur.close()
    log('Report finished.', scope_prefix)


def aggregate_task_on_date(conn, scope_prefix, backlog_resolved_cutoff):
    """ Create three different datasets, all stuffed into the same table and
    differentiated by scope and range.  The datasets aggregating the daily data
    three ways: with no cutoff, with the specified cutoff, and with a cutoff
    three months before specified.
    """
    cur = conn.cursor()
    tod_agg_common = """INSERT INTO task_on_date_agg (
                        SELECT scope,
                               %(range)s,
                               date,
                               category,
                               status,
                               SUM(points) as points,
                               COUNT(id) as count,
                               maint_type
                          FROM task_on_date_recategorized
                         WHERE scope = %(scope_prefix)s
                               {cutoff_clause}
                         GROUP BY status, category, maint_type, date, scope)"""
    cur.execute(tod_agg_common.format(cutoff_clause=''), {
        'scope_prefix': scope_prefix,
        'range': 'normal'
    })

    if backlog_resolved_cutoff:
        tod_cutoff_clause = """AND id NOT IN (SELECT id
                                                FROM task_on_date th
                                               WHERE date = %(backlog_resolved_cutoff)s
                                                 AND scope = %(scope_prefix)s
                                                 AND status = 'resolved') """

        tod_agg_common_cutoff = tod_agg_common.format(cutoff_clause=tod_cutoff_clause)
        backlog_resolved_cutoff_lastq = backlog_resolved_cutoff\
            - datetime.timedelta(days=91)
        cur.execute(tod_agg_common_cutoff,
                    {
                        'scope_prefix': scope_prefix,
                        'range': 'cutoff',
                        'backlog_resolved_cutoff': backlog_resolved_cutoff,
                    })

        cur.execute(tod_agg_common_cutoff,
                    {
                        'scope_prefix': scope_prefix,
                        'range': 'lastq',
                        'backlog_resolved_cutoff': backlog_resolved_cutoff_lastq,
                    })

    else:
        # If there's no cutoff, stuff data into the table anyway
        # so that retrieval doesn't have to change
        cur.execute(tod_agg_common.format(cutoff_clause=''), {
            'scope_prefix': scope_prefix,
            'range': 'cutoff'
        })

        cur.execute(tod_agg_common.format(cutoff_clause=''), {
            'scope_prefix': scope_prefix,
            'range': 'lastq'
        })


def check_for_empty_task_on_date(conn, scope_prefix):
    cur = conn.cursor()
    size_query = """SELECT count(*)
                      FROM task_on_date
                     WHERE scope = %(scope_prefix)s"""
    cur.execute(size_query, {'scope_prefix': scope_prefix})
    data_size = cur.fetchone()[0]
    if data_size == 0:
        print("ERROR: no data in task_on_date for {0}".format(scope_prefix))
        sys.exit(-1)


def generate_reporting_files(conn, scope_prefix, dbname):
    # working around dynamic filename constructions limitations in
    # psql rather than try to write the file /tmp/foo/report.csv,
    # write the file /tmp/phlog/report.csv and then move it to
    # /tmp/foo/report.csv
    # note that all the COPY commands in the psql scripts run
    # server-side as user postgres

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

    subprocess.call('cp /tmp/{0}/maintenance_fraction_total_by_points.csv ~/html/{0}_maintenance_fraction_total_by_points.csv'.format(scope_prefix), shell=True)  # noqa
    subprocess.call('cp /tmp/{0}/maintenance_fraction_total_by_count.csv ~/html/{0}_maintenance_fraction_total_by_count.csv'.format(scope_prefix), shell=True)  # noqa
    subprocess.call('cp /tmp/{0}/category_possibilities.txt ~/html/{0}_category_possibilities.txt'.format(scope_prefix), shell=True)  # noqa


def get_max_date(conn, scope_prefix):
    cur = conn.cursor()
    max_date_query = """SELECT MAX(date)
                          FROM task_on_date_recategorized
                         WHERE scope = %(scope_prefix)s"""
    cur.execute(max_date_query, {'scope_prefix': scope_prefix})
    max_date = cur.fetchone()[0].date()
    return max_date


def get_project_list(conn, scope_prefix):
    """Given a scope, return a list (by id) of all categories mentioned
    in the rules.  Should handle project ids, exact project name matches,
    and project name wildcards.  Also returns the names."""

    cur = conn.cursor()
    project_id_list = []
    category_id_query = """SELECT project_id_list
                             FROM category
                            WHERE scope = %(scope_prefix)s
                            ORDER BY sort_order"""

    cur.execute(category_id_query, {'scope_prefix': scope_prefix})
    for row in cur.fetchall():
        result_list = row[0]
        for id in result_list:
            if id not in project_id_list:
                project_id_list.append(id)

    project_name_list = []
    for project_id in project_id_list:
        name = get_project_name(conn, project_id)
        project_name_list.append(name)

    return project_id_list, project_name_list


def get_project_name(conn, project_id):
    cur = conn.cursor()
    project_name_query = """SELECT name
                              FROM phabricator_project
                             WHERE id = %(project_id)s"""

    cur.execute(project_name_query, {'project_id': project_id})
    try:
        result = cur.fetchone()[0]
    except:
        result = ""

    return result


def import_recategorization_file(conn, scope_prefix):
    """ Reload the recategorization file into the database"""

    cur = conn.cursor()

    cur.execute('DELETE FROM category WHERE scope = %(scope_prefix)s',
                {'scope_prefix': scope_prefix})

    insert_sql = """INSERT INTO category VALUES (
                    %(scope)s,
                    %(sort_order)s,
                    %(rule)s,
                    %(project_id_list)s,
                    %(project_name_list)s,
                    %(matchstring)s,
                    %(title)s,
                    %(display)s,
                    %(include_in_status)s)"""

    recat_file = '{0}_recategorization.csv'.format(scope_prefix)
    if not os.path.isfile(recat_file):
        raise Exception('Missing recat file {0}'.recat_file)
    with open(recat_file, 'rt') as f:
        reader = csv.DictReader(f)
        counter = 0
        valid_rule_list = ['ProjectByID', 'ProjectByName', 'ProjectsByWildcard',
                           'Intersection', 'ProjectColumn', 'ParentTask']
        for line in reader:

            try:
                matchstring = line['matchstring']
            except (KeyError,  TypeError):
                matchstring = ''

            rule = line['rule']
            if rule not in valid_rule_list:
                raise Exception('Error in recat file {0} line {1}: {2} is not a valid rule.  Must be one of {3}'.format(recat_file, counter, rule, valid_rule_list))  # noqa
                quit()

            try:
                title = line['title']
            except KeyError:
                title = ''

            id_list = []
            try:
                if line['id']:
                    id_list = [int(i) for i in line['id'].split()]
            except KeyError:
                pass

            display = True
            input_display = ''
            try:
                input_display = line['display']
            except KeyError:
                pass

            if input_display:
                if input_display.lower() in ['false', 'f', 'no', '0']:
                    display = False

            include_in_status = False
            input_iis = ''
            try:
                input_iis = line['include_in_status']
            except KeyError:
                pass

            if input_iis:
                if input_iis.lower() in ['true', 't', 'yes', '1']:
                    include_in_status = True

            if rule != 'Intersection' and len(id_list) > 1:
                raise Exception('Error in recat file {0} line {1}: {2} is not a valid rule.  This type of rule should have only one id specified'.format(recat_file, counter, line))  # noqa
            if rule == 'ProjectsByWildcard':
                wildcard_match = '%{0}%'.format(matchstring)
                cur.execute("SELECT * FROM get_projects_by_name(%s)", (wildcard_match,))
                for row in cur.fetchall():
                    project_id = row[0]
                    name = row[1]

                    try:
                        cur.execute(insert_sql,
                                    {'scope': scope_prefix,
                                     'sort_order': counter,
                                     'rule': 'ProjectByID',
                                     'project_id_list': [project_id, ],
                                     'project_name_list': [name, ],
                                     'matchstring': '',
                                     'title': name,
                                     'display': display,
                                     'include_in_status': include_in_status})
                        counter += 1
                    except psycopg2.IntegrityError as E:
                        print('Skipping a duplicate category produced by rule {0}: {1}'.
                              format(line, E))
            elif rule == 'ProjectByName':
                cur.execute("SELECT * FROM get_projects_by_name(%s)", (matchstring,))
                row = cur.fetchone()
                try:
                    project_id = row[0]
                except TypeError:
                    raise Exception('Error in recat file {0} line {1}: {2} is not a valid rule.  No matching project found for name {3}'.format(recat_file, counter, line, matchstring))  # noqa

                try:
                    cur.execute(insert_sql,
                                {'scope': scope_prefix,
                                 'sort_order': counter,
                                 'rule': 'ProjectByID',
                                 'project_id_list': [project_id, ],
                                 'project_name_list': [matchstring, ],
                                 'matchstring': '',
                                 'title': title,
                                 'display': display,
                                 'include_in_status': include_in_status})
                    counter += 1
                except psycopg2.IntegrityError as E:
                    print('Skipping a duplicate category produced by rule {0}: {1}'.
                          format(line, E))
            else:
                name_list = {}
                cur.execute("SELECT name FROM phabricator_project WHERE id = ANY(%s)",
                            (id_list,))
                result = cur.fetchall()
                name_list = [x[0] for x in result]

                try:
                    cur.execute(insert_sql,
                                {'scope': scope_prefix,
                                 'sort_order': counter,
                                 'rule': rule,
                                 'project_id_list': id_list,
                                 'project_name_list': name_list,
                                 'matchstring': matchstring,
                                 'title': line['title'],
                                 'display': display,
                                 'include_in_status': include_in_status})
                    counter += 1
                except psycopg2.IntegrityError as E:
                    print('Skipping a duplicate category produced by rule {0}: {1}'.
                          format(line, E))


def log(message, scope_prefix):
    """ TODO: convert this into native logging """
    if VERBOSE:
        print('{0} {1}: {2}'.
              format(scope_prefix,
                     datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                     message))


def populate_recently_closed(conn, scope_prefix, start_date):
    cur = conn.cursor()
    end_date = get_max_date(conn, scope_prefix)
    cur.execute('SELECT populate_recently_closed(%(scope_prefix)s,\
                %(start_date)s,\
                %(end_date)s)',
                {'scope_prefix': scope_prefix,
                 'start_date': start_date,
                 'end_date': end_date})
    cur.execute('SELECT populate_recently_closed_task(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})


def read_date(input_string):
    try:
        output_date = datetime.datetime.strptime(input_string, "%Y-%m-%d").date()
        return output_date
    except:
        return None


def recategorize(conn, scope_prefix):
    """ Categorize all tasks in a scope according to the recategorization configuration"""

    cur = conn.cursor()

    cur.execute('SELECT * FROM get_category_rules(%(scope_prefix)s)', {'scope_prefix': scope_prefix})  # noqa

    for row in cur.fetchall():
        rule = row[0]
        project_id_list = row[1]
        matchstring = row[3]
        title = row[4]
        scope_prefix = scope_prefix

        if rule == "ProjectByID":
            cur.execute('SELECT recategorize_by_project(%(scope_prefix)s, %(project_id_list)s, %(title)s)',  # noqa
                        {'scope_prefix': scope_prefix,
                         'project_id_list': project_id_list,
                         'title': title})
        elif rule == "Intersection":
            cur.execute('SELECT recategorize_by_intersection(%(scope_prefix)s, %(project_id_list)s, %(title)s)',  # noqa
                        {'scope_prefix': scope_prefix,
                         'project_id_list': project_id_list,
                         'title': title})
        elif rule == "ProjectColumn":
            cur.execute('SELECT recategorize_by_column(%(scope_prefix)s, %(project_id_list)s, %(title)s, %(matchstring)s)',  # noqa
                        {'scope_prefix': scope_prefix,
                         'project_id_list': project_id_list,
                         'title': title,
                         'matchstring': matchstring})
        elif rule == "ParentTask":
            cur.execute('SELECT recategorize_by_parenttask(%(scope_prefix)s, %(project_id_list)s, %(title)s, %(matchstring)s)',  # noqa
                        {'scope_prefix': scope_prefix,
                         'project_id_list': project_id_list,
                         'title': title,
                         'matchstring': matchstring})
        else:
            raise Exception("Invalid categorization rule {0}".format(rule))
            sys.exit()

    cur.execute('SELECT purge_leftover_task_on_date(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})


def reconstruct_task_on_date(cur, task_id, working_date, scope_prefix,
                             default_points, project_id_list,
                             project_id_to_name_dict,
                             project_name_to_phid_dict, column_dict):

    # ----------------------------------------------------------------------
    # Maniphest_task provides as-is information about tasks.  It's used here
    # to provide points and title.
    # Points data prior to Feb 2016 was not recorded transactionally and is
    # only available here, so we use this to supplement transactional points
    # data.
    # Title could be tracked through transactions but this code doesn't
    # make that effort, instead using the as-is title retroactively.
    # ----------------------------------------------------------------------
    task_info_query = """SELECT title, story_points
    FROM maniphest_task
    WHERE id = %(task_id)s"""
    cur.execute(task_info_query,
                {'task_id': task_id,
                 'working_date': working_date,
                 'transaction_type': 'status'})
    task_info = cur.fetchone()
    try:
        points_from_info = int(task_info[1])
    except:
        points_from_info = None

    # For all other fields, use transactional data:
    # For each relevant variable of the task, use the most
    # recent value that is no later than that day.  (So, if
    # that variable didn't change that day, use the last time
    # it was changed.  If it changed multiple times, use the
    # final value)

    # ----------------------------------------------------------------------
    # Status
    # ----------------------------------------------------------------------
    cur.execute("SELECT * FROM get_transaction_value(%s, %s, %s)",
                (working_date, 'status', task_id))
    status_raw = cur.fetchone()
    pretty_status = ""
    if status_raw:
        pretty_status = status_raw[0]

    # ----------------------------------------------------------------------
    # Priority
    # ----------------------------------------------------------------------
    cur.execute("SELECT * FROM get_transaction_value(%s, %s, %s)",
                (working_date, 'priority', task_id))
    priority_raw = cur.fetchone()
    pretty_priority = ""
    if priority_raw:
        pretty_priority = priority_raw[0]

    # ----------------------------------------------------------------------
    # Story Points
    # ----------------------------------------------------------------------
    cur.execute("SELECT * FROM get_transaction_value(%s, %s, %s)",
                (working_date, 'points', task_id))
    points_raw = cur.fetchone()
    try:
        points_from_trans = int(points_raw[0])
    except:
        points_from_trans = None

    if isinstance(points_from_trans, int):
        pretty_points = points_from_trans
    elif isinstance(points_from_info, int):
        pretty_points = points_from_info
    else:
        pretty_points = default_points

    # ----------------------------------------------------------------------
    # Project & Maintenance Type
    # ----------------------------------------------------------------------
    cur.execute("SELECT * FROM get_edge_value(%s, %s)",
                (working_date, task_id))
    edges = cur.fetchall()[0][0]
    pretty_project = ''

    if not edges:
        log('Task {0} has no edges.'.format(task_id), 'load')
        return
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
        return

    pretty_project = project_id_to_name_dict[best_edge]
    project_phid = project_name_to_phid_dict[pretty_project]

    # ----------------------------------------------------------------------
    # Column
    # ----------------------------------------------------------------------
    pretty_column = ''
    cur.execute("SELECT * FROM get_transaction_value(%s, %s, %s)",
                (working_date, 'core:columns', task_id))
    pc_trans_list = cur.fetchall()
    for pc_trans in pc_trans_list:
        jblob = json.loads(pc_trans[0])[0]
        if project_phid in jblob['boardPHID']:
            column_phid = jblob['columnPHID']
            pretty_column = column_dict[column_phid]
            break

    denorm_insert = """
        INSERT INTO task_on_date VALUES (
        %(scope_prefix)s,
        %(working_date)s,
        %(id)s,
        %(status)s,
        %(project_id)s,
        %(project)s,
        %(projectcolumn)s,
        %(points)s,
        %(maint_type)s,
        %(priority)s)"""

    cur.execute(denorm_insert,
                {'scope_prefix': scope_prefix,
                 'working_date': working_date,
                 'id': task_id,
                 'status': pretty_status,
                 'project_id': best_edge,
                 'project': pretty_project,
                 'projectcolumn': pretty_column,
                 'points': pretty_points,
                 'maint_type': maint_type,
                 'priority': pretty_priority})


def reset_reporting_tables(conn, scope_prefix):
    cur = conn.cursor()
    cur.execute('SELECT wipe_reporting(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})

    cur.execute('SELECT load_tasks_to_recategorize(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})


def set_categories_retroactively(conn, scope_prefix):
    cur = conn.cursor()
    cur.execute('SELECT set_category_retroactive(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})


def set_points_retroactively(conn, scope_prefix):
    cur = conn.cursor()
    cur.execute('SELECT set_points_retroactive(%(scope_prefix)s)',
                {'scope_prefix': scope_prefix})


def start_of_quarter(input_date):
    quarter_start = [datetime.date(input_date.year, month, 1) for month in (1, 4, 7, 10)]

    index = bisect.bisect(quarter_start, input_date)
    return quarter_start[index - 1]


if __name__ == "__main__":
    main(sys.argv[1:])
