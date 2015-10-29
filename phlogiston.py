#!/usr/bin/python3

import configparser
import csv
import datetime
import json
import os.path
import psycopg2
import sys, getopt
import subprocess
import time

def main(argv):
    try:
        opts, args = getopt.getopt(argv, "cde:hlp:rv", ["reconstruct", "debug", "enddate", "help", "load", "project=", "report", "verbose"])
    except getopt.GetoptError as e:
        print(e)
        usage()
        sys.exit(2)
    load_data = False
    reconstruct_data = False
    run_report = False
    DEBUG = False
    VERBOSE = False
    default_points = 5
    project_source = ''
    end_date = datetime.datetime.now().date()
    for opt, arg in opts:
        if opt in ("-c", "--reconstruct"):
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
        elif opt in ("-p", "--project"):
            project_source = arg
        elif opt in ("-r", "--report"):
            run_report = True
        elif opt in ("-v", "--verbose"):
            VERBOSE = True
    conn = psycopg2.connect("dbname=phab")
    conn.autocommit = True

    if load_data:
        load(conn, end_date, VERBOSE, DEBUG)

    if project_source:
        config = configparser.ConfigParser()
        config.read(project_source)
        source_prefix = config.get("vars", "source_prefix")
        source_title = config.get("vars", "source_title")
        default_points = config.get("vars", "default_points")
        category_list = config.get("vars", "category_list")
        project_name_list = tuple(config.get("vars", "project_list").split(','))
        start_date = datetime.datetime.strptime(config.get("vars", "start_date"), "%Y-%m-%d").date()

    if reconstruct_data:
        if project_source:
            reconstruct(conn, VERBOSE, DEBUG, default_points, project_name_list, start_date, end_date, source_prefix)
        else:
            print("Reconstruct specified without a project.  Please specify a project with --project.")
    if run_report:
        if project_source:
            report(conn, VERBOSE, DEBUG, source_prefix, source_title, default_points, project_name_list, category_list)
        else:
            print("Report specified without a project.  Please specify a project with --project.")
    conn.close()

def usage():
   print("""Usage:\n
  --debug to work on a small subset of data\n
  --enddate ending date for loading and reconstruction; defaults to now\n
  --help for this message.\n
  --load to load data.  This will wipe existing data in the reporting database.\n
  --project Name of a Python file containing metadata specific to the project to be analyzed.  Reconstruct and report will not function without a project.\n
  --report Process data in SQL, generate graphs in R, and output a set of png files.\n
  --verbose to show extra messages\n
  --reconstruct Reprocess the loaded data to reconstruct a historical record day by day, in the database\n
  --startdate The date reconstruction should start, as YYYY-MM-DD""")
  
def load(conn, end_date, VERBOSE, DEBUG):
    cur = conn.cursor()

    # reload the database tables
    cur.execute(open("rebuild_working_tables.sql", "r").read())

    if VERBOSE:
        print("Loading dump file")
    with open('../phabricator_public.dump') as dump_file:
       data = json.load(dump_file)

    ######################################################################
    # Load project and project column data
    ######################################################################
    if VERBOSE:
        print("Load {count} projects".format(count=len(data['project']['projects'])))

    project_insert = ("""INSERT INTO phabricator_project (id, name, phid)
                VALUES (%(id)s, %(name)s, %(phid)s)""")
    for row in data['project']['projects']:
       cur.execute(project_insert, {'id':row[0] , 'name':row[1], 'phid':row[2] })

    cur.execute("SELECT phid, id from phabricator_project")
    project_phid_to_id_dict = dict(cur.fetchall())

    column_insert = ("""INSERT INTO phabricator_column (id, name, phid, project_phid)
                VALUES (%(id)s, %(name)s, %(phid)s, %(project_phid)s)""")
    if VERBOSE:
        print("Load {count} projectcolumns".format(count=len(data['project']['columns'])))
    for row in data['project']['columns']:
        cur.execute(column_insert, {'id':row[0] , 'name':row[2], 'phid':row[1], 'project_phid':row[5] 
                     })

    ######################################################################
    # Load transactions and edges
    ######################################################################
    
    transaction_insert = ("""
      INSERT INTO maniphest_transaction (
             id, phid, task_id, object_phid, transaction_type, 
             new_value, date_modified, has_edge_data, active_projects)
      VALUES (%(id)s, %(phid)s, %(task_id)s, %(object_phid)s, %(transaction_type)s,
              %(new_value)s, %(date_modified)s, %(has_edge_data)s, %(active_projects)s)""")

    task_insert = (""" 
      INSERT INTO maniphest_task (id, phid, title, story_points)
      VALUES (%(task_id)s, %(phid)s, %(title)s, %(story_points)s) """)

    if VERBOSE:
        print("Load tasks, transactions, and edges for {count} tasks".
              format(count=len(data['task'].keys())))
        if DEBUG:
            print("DEBUG: loading only tasks ending in 01")

    for task_id in data['task'].keys():

        if DEBUG and int(task_id) % 100 != 1:
            continue

        task = data['task'][task_id]
        if task['info']:
            task_phid = task['info'][1]
            title = task['info'][7]
        else:
            task_phid = ''
            title = ''
        if task['storypoints']:
            story_points = task['storypoints'][2]
        else:
            story_points = None            
        cur.execute(task_insert, {'task_id': task_id,
                                  'phid': task_phid,
                                  'title': title,
                                  'story_points': story_points})

        transactions = task['transactions']
        for trans_key in list(transactions.keys()):
            if transactions[trans_key]:
                for trans in transactions[trans_key]:
                    trans_type = trans[6]
                    new_value = trans[8]
                    date_mod = time.strftime('%m/%d/%Y %H:%M:%S', time.gmtime(trans[11]))
                    # If this is an edge transaction, parse out the list of transactions
                    has_edge_data = False
                    active_proj = list()
                    if trans_type == 'core:edge':
                        jblob = json.loads(new_value)
                        if jblob:
                            for key in jblob.keys():
                                try:
                                    if jblob[key]['type'] == 41:
                                        has_edge_data = True
                                        proj_id = project_phid_to_id_dict[key]
                                        active_proj.append(proj_id)
                                except:
                                    print("Error loading {0}".format(trans))
                    
                    cur.execute(transaction_insert,
                                {'id': trans[0] ,
                                 'phid': trans[1],
                                 'task_id': task_id,
                                 'object_phid': trans[3],
                                 'transaction_type': trans_type,
                                 'new_value': new_value,
                                 'date_modified': date_mod,
                                 'has_edge_data': has_edge_data,
                                 'active_projects': active_proj})

    max_date_query = """SELECT MAX(date_modified)
                          FROM maniphest_transaction"""

    cur.execute(max_date_query)
    max_date = cur.fetchone()[0]
    script_dir = os.path.dirname(__file__)
    f = open('{0}../html/max_date.csv'.format(script_dir), 'w')
    f.write(max_date.strftime('%c'))
    cur.close()


def reconstruct(conn, VERBOSE, DEBUG, default_points, project_name_list, start_date, end_date, source_prefix):
    cur = conn.cursor()

    ######################################################################
    # preload project and column for fast lookup
    ######################################################################

    cur.execute("""SELECT name, phid 
                   FROM phabricator_project
                  WHERE name IN %(project_name_list)s""",
                { 'project_name_list': project_name_list } )
    project_name_to_phid_dict = dict(cur.fetchall())
    cur.execute("""SELECT name, id 
                     FROM phabricator_project
                    WHERE name IN %(project_name_list)s""",
                { 'project_name_list': project_name_list } )
    project_name_to_id_dict = dict(cur.fetchall())
    project_id_to_name_dict = {value: key for key, value in project_name_to_id_dict.items()}

    project_id_list = list() 
    for project_name in project_name_list:
        project_id_list.append(project_name_to_id_dict[project_name])
    
    cur.execute("""SELECT pc.phid, pc.name
                     FROM phabricator_column pc,
                          phabricator_project pp
                    WHERE pc.project_phid = pp.phid
                      AND pp.id = ANY(%(project_id_list)s)""",
                { 'project_id_list': project_id_list } )
    column_dict = dict(cur.fetchall())

    ######################################################################
    # Generate denormalized data
    ######################################################################
    # Generate denormalized edge data.  This is edge data for only the
    # projects of interest, but goes into a shared table for
    # simplicity.
    
    if not start_date:
        oldest_data_query = """SELECT date(min(date_modified)) from maniphest_transaction"""
        cur.execute(oldest_data_query)
        start_date = cur.fetchone()[0]
    working_date = start_date

    # In addition to project-specific projects, include WorkType tags
    id_list_with_worktypes = list(project_id_list)
    id_list_with_worktypes.extend([1453, 1454])
    while working_date <= end_date:
        query_date = working_date + datetime.timedelta(days=1)
        if VERBOSE:
            print('{0}: Making maniphest_edge for {1}'.format(datetime.datetime.now(), query_date))
        cur.execute('SELECT build_edges(%(date)s, %(project_id_list)s)',
                    { 'date': query_date, 'project_id_list': id_list_with_worktypes } )
        working_date += datetime.timedelta(days=1)

    ######################################################################
    # Reconstruct historical state of tasks

    cur.execute('SELECT wipe_reconstruction(%(source_prefix)s)', { 'source_prefix': source_prefix})

    working_date = start_date
        
    transaction_values_query = """
        SELECT mt.new_value 
          FROM maniphest_transaction mt 
         WHERE date(mt.date_modified) <= %(query_date)s
           AND mt.transaction_type = %(transaction_type)s 
           AND mt.task_id = %(task_id)s
         ORDER BY date_modified DESC """

    edge_values_query = """
        SELECT mt.active_projects
          FROM maniphest_transaction mt 
         WHERE date(mt.date_modified) <= %(query_date)s
           AND mt.task_id = %(task_id)s
           AND mt.has_edge_data IS TRUE
         ORDER BY date_modified DESC
         LIMIT 1 """

    while working_date <= end_date:
        # because working_date is midnight at the beginning of the day, use a date at
        # the midnight at the end of the day to make the queries line up with the date label
        query_date = working_date + datetime.timedelta(days=1)
        if VERBOSE:
            print("Reconstructing data for {0}".format(working_date))

        task_on_day_query = """SELECT DISTINCT task
                                 FROM maniphest_edge
                                WHERE project = ANY(%(project_ids)s)
                                  AND edge_date = %(query_date)s"""

        cur.execute(task_on_day_query, {'query_date': query_date , 'project_ids': project_id_list})
        for row in cur.fetchall():
            task_id = row[0]

            # ----------------------------------------------------------------------
            # Title and Points
            # currently points are a separate field not in transaction data
            # this means historical points charts are actually retroactive
            # Title could be tracked retroactively but this code doesn't make that effort
            # ----------------------------------------------------------------------
            task_query = """SELECT title, story_points
                              FROM maniphest_task
                             WHERE id = %(task_id)s"""
            cur.execute(task_query, {'task_id': task_id, 'query_date': query_date, 'transaction_type': 'status'})
            task_info = cur.fetchone()
            pretty_title = task_info[0]
            try:
                pretty_points = int(task_info[1])
            except:
                pretty_points = default_points
            # for each relevant variable of the task, use the most recent value
            # that is no later than that day.  (So, if that variable didn't change that day,
            # use the last time it was changed.  If it changed multiple times, use the final value)

            # ----------------------------------------------------------------------
            # Status
            # ----------------------------------------------------------------------
            cur.execute(transaction_values_query, {'query_date': query_date, 'transaction_type': 'status', 'task_id': task_id})
            status_raw= cur.fetchone()
            pretty_status = ""
            if status_raw:
                pretty_status = status_raw[0]

            # ----------------------------------------------------------------------
            # Project & Maintenance Type
            # ----------------------------------------------------------------------
            cur.execute(edge_values_query, {'task_id': task_id, 'query_date': query_date})
            edges = cur.fetchall()[0][0]
            pretty_project = ''

            if 1453 in edges:
                maint_type = 'New Functionality'
            elif 1454 in edges:
                maint_type = 'Maintenance'
            else:
                maint_type = ''
            
            best_edge = ''
            # Reduce the list of edges to only the single best match,
            # where best = earliest in the specified project list
            for project in edges:
                if project in project_id_list:
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
            pretty_column = ''
            # ----------------------------------------------------------------------
            # Column
            # ----------------------------------------------------------------------
            cur.execute(transaction_values_query, {'query_date': query_date, 'transaction_type': 'projectcolumn', 'task_id': task_id})
            pc_trans_list = cur.fetchall()
            for pc_trans in pc_trans_list:
                jblob = json.loads(pc_trans[0])
                if project_phid in jblob['projectPHID']:
                    column_phid = jblob['columnPHIDs'][0]
                    pretty_column = column_dict[column_phid]
                    break

            denorm_query = """
                INSERT INTO task_history VALUES (
                %(source)s,
                %(query_date)s,
                %(id)s,
                %(title)s,
                %(status)s,
                %(project)s,
                %(projectcolumn)s,
                %(points)s,
                %(maint_type)s)"""

            cur.execute(denorm_query, {'source': source_prefix, 'query_date': query_date, 'id': task_id, 'title': pretty_title, 'status': pretty_status, 'project': pretty_project, 'projectcolumn': pretty_column, 'points': pretty_points, 'maint_type': maint_type })
    
        working_date += datetime.timedelta(days=1)
    cur.close()

def report(conn, VERBOSE, DEBUG, source_prefix, source_title, default_points, project_name_list, category_list):
    # note that all the COPY commands in the psql scripts run server-side as user postgres

    ######################################################################
    # Prepare the data
    ######################################################################

    cur = conn.cursor()
    cur.execute('SELECT wipe_reporting(%(source_prefix)s)', { 'source_prefix': source_prefix})

    # generate the summary reporting data from the reconstructed records
    report_tables_script = '{0}_make_history.sql'.format(source_prefix)
    if not os.path.isfile(report_tables_script):
        report_tables_script = 'generic_make_history.sql'
    subprocess.call("psql -d phab -f {0} -v prefix={1}".format(report_tables_script, source_prefix), shell = True)

    # perform any additional re-categorization
    zoom_list = []
    grouping_data = '{0}_recategorization.csv'.format(source_prefix)
    recat_cases = ''
    recat_else = ''
    if os.path.isfile(grouping_data):
        with open(grouping_data, 'rt') as f:
            reader = csv.reader(f)
            for row in reader:
                if row[0] == 'PhlogOther':
                    recat_else = row[1]
                else:
                    recat_cases += ' WHEN category LIKE \'{0}\' THEN \'{1}\''.format(row[0], row[1])
                try:
                    zoom = row[2]
                except:
                    zoom = False
                if zoom:
                    zoom_list.append(row[1])

        recat_query = """UPDATE {0}
                            SET category = CASE {1}
                                           ELSE '{2}'
                                           END
                          WHERE source = '{3}'"""

        unsafe_recat_query = recat_query.format('tall_backlog',recat_cases, recat_else, source_prefix)
        cur.execute(unsafe_recat_query)
    
    category_query = """SELECT DISTINCT category 
                          FROM tall_backlog 
                         WHERE source = %(source_prefix)s"""
    if zoom_list:
        category_query += """ AND category IN %(zoom_list)s"""

    cur.execute(category_query, {'source_prefix': source_prefix, 'zoom_list': tuple(zoom_list)})
    category_list = cur.fetchall()

    ######################################################################
    # Prepare all the csv files and working directories
    ######################################################################
    # working around dynamic filename constructions limitations in psql
    # rather than try to write the file /tmp/foo/report.csv,
    # write the file /tmp/phlog/report.csv and then move it to /tmp/foo/report.csv

    subprocess.call("rm -rf /tmp/{0}/".format(source_prefix), shell = True)
    subprocess.call("rm -rf /tmp/phlog/", shell = True)
    subprocess.call("mkdir -p /tmp/{0}".format(source_prefix), shell = True)
    subprocess.call("chmod g+w /tmp/{0}".format(source_prefix), shell = True)
    subprocess.call("mkdir -p /tmp/phlog", shell = True)
    subprocess.call("chmod g+w /tmp/phlog", shell = True)
    subprocess.call("psql -d phab -f make_report_csvs.sql -v prefix={0}".format(source_prefix), shell = True)

    # this recat is done twice because task_history is derived from twice, and the raw
    # data shouldn't be edited
    
    if os.path.isfile(grouping_data):
        unsafe_recat_query = recat_query.format('recently_closed',recat_cases, recat_else, source_prefix)
        cur.execute(unsafe_recat_query)

    subprocess.call("mv /tmp/phlog/* /tmp/{0}/".format(source_prefix), shell = True)
    subprocess.call("sed s/phl_/{0}_/g html/phl.html | sed s/Phlogiston/{1}/g > ~/html/{0}.html".format(source_prefix, source_title), shell = True)
    subprocess.call("cp /tmp/{0}/maintenance_fraction_total_by_points.csv ~/html/{0}_maintenance_fraction_total_by_points.csv".format(source_prefix), shell = True)
    subprocess.call("cp /tmp/{0}/maintenance_fraction_total_by_count.csv ~/html/{0}_maintenance_fraction_total_by_count.csv".format(source_prefix), shell = True)
    script_dir = os.path.dirname(__file__)
    f = open('{0}../html/{1}_projects.csv'.format(script_dir, source_prefix), 'w')
    for project_name in project_name_list:
        f.write( "{0}\n".format(project_name) )
    f.close()

    f = open('{0}../html/{1}_default_points.csv'.format(script_dir, source_prefix), 'w')
    f.write( "{0}\n".format(default_points) )
    f.close()

    ######################################################################
    # for each category, generate burnup charts
    ######################################################################
    max_tranche_height_points_query = """SELECT MAX(points)
                                     FROM (SELECT SUM(points) AS points
                                             FROM tall_backlog
                                            WHERE source = %(source_prefix)s
                                              AND category = ANY(%(zoom_list)s::text[])
                                            GROUP BY date, category) AS x"""

    cur.execute(max_tranche_height_points_query, {'source_prefix': source_prefix, 'zoom_list': zoom_list})
    max_tranche_height_points = cur.fetchone()[0]
    max_tranche_height_count_query = """SELECT MAX(count)
                                     FROM (SELECT SUM(count) AS count
                                             FROM tall_backlog
                                            WHERE source = %(source_prefix)s
                                              AND category = ANY(%(zoom_list)s::text[])
                                            GROUP BY date, category) AS x"""

    cur.execute(max_tranche_height_count_query, {'source_prefix': source_prefix, 'zoom_list': zoom_list})
    max_tranche_height_count = cur.fetchone()[0]

    colors = ['#B35806', '#E08214', '#FDB863', '#FEE0B6', '#F7F7F7', '#D8DAEB', '#B2ABD2', '#8073AC', '#542788']
    i = 0
    html_string = ""
    for item in category_list:
        if i > 8:
            # if there are more than 9 tranches, probably this data doesn't make much sense and there could be dozens more.
            break
        category = item[0]
        color = colors[i]

        subprocess.call("Rscript make_tranche_chart.R {0} {1} '{2}' '{3}' {4} {5}".format(source_prefix, i, color, category, max_tranche_height_points, max_tranche_height_count), shell = True)
        points_png_name = "{0}_tranche{1}_burnup_points.png".format(source_prefix, i)
        count_png_name = "{0}_tranche{1}_burnup_count.png".format(source_prefix, i)
        html_string = html_string + '<p><a href="{0}"><img src="{0}"/></a></p>'.format(points_png_name)
        html_string = html_string + '<p><a href="{0}"><img src="{0}"/></a></p>'.format(count_png_name)
        i += 1

    f = open('{0}../html/{1}_tranches.html'.format(script_dir, source_prefix), 'w')
    f.write( html_string)
    f.close()
    
    cur.close()

    ######################################################################
    # Make the rest of the charts
    ######################################################################
    subprocess.call("Rscript make_charts.R {0} {1}".format(source_prefix, source_title), shell = True)
    
if __name__ == "__main__":
    main(sys.argv[1:])
