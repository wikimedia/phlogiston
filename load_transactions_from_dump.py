#!/usr/bin/python3
# This script does
# --load
#  - reads a JSON file produced by https://gerrit.wikimedia.org/r/#/c/214398/2/wmfphablib/phabdb.py
#  - loads a postgresql database containing the data (or outputs a CSV file)
# --reconstruct
#  - Calls a project-specific SQL script to reconstruct the historical state
#    of the project day by day
# --report
#  - Calls a project-specific SQL script to process the data and generate csv files,
#    and an R file to graph the data as PNG files
#
# Data is available at  http://dumps.wikimedia.org/other/misc/phabricator_public.dump
# It assumes this file is saved to the parent directory
# it works in the "phab" postgresql database
# it outputs CSV and PNG to /tmp
# 
#  The reason it inputs from the parent directory and outputs to /tmp,
#  rather that the current directory, is so that these temporary files
#  don't get caught up in source control.  This should be refactored
#  to whatever is best practice.
#
# Things that might be worth refactoring
#  - status fields are all double-quote-delimited in the database, which makes the sql look stupid
#  - should probably rip out the --output option and related code since current workflow doesn't use it
#  - automate retrieving the dump
#  - softcode the rest of the file and database locations (what is best practice?)
#  - refactor the .R and .SQL to obey DRY; currently copy-pasted from VE example
#  - optimize so the whole thing doesn't take 2+ hours for VE

import psycopg2
import csv
import json
import time
import datetime
import sys, getopt
import subprocess
import configparser

def main(argv):
    try:
        opts, args = getopt.getopt(argv, "cde:hlo:p:rv", ["reconstruct", "debug", "enddate", "help", "load", "output=", "project=", "report", "verbose"])
    except getopt.GetoptError as e:
        print(e)
        usage()
        sys.exit(2)
    load_data = False
    reconstruct_data = False
    run_report = False
    DEBUG = False
    VERBOSE = False
    output_file = ''
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
        elif opt in ("-o", "--output"):
            output_file = arg
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
        prefix = config.get("vars", "prefix")
        default_points = config.get("vars", "default_points")
        project_name_list = tuple(config.get("vars", "project_list").split(','))
        task_history_table_name = '{0}_task_history'.format(prefix)
        project_csv_name = '/tmp/{0}_projects.csv'.format(prefix)
        report_tables_script = '{0}_tables.sql'.format(prefix)
        report_script = '{0}_report.R'.format(prefix)
        start_date = datetime.datetime.strptime(config.get("vars", "start_date"), "%Y-%m-%d").date()

    if reconstruct_data:
        if project_source:
            reconstruct(conn, VERBOSE, DEBUG, output_file, default_points, project_name_list, start_date, end_date, task_history_table_name, project_csv_name)
        else:
            print("Reconstruct specified without a project.  Please specify a project with --project.")
    if run_report:
        if project_source:
            report(conn, VERBOSE, DEBUG, report_tables_script, report_script)
        else:
            print("Reconstruct specified without a project.  Please specify a project with --project.")
    conn.close()

def usage():
   print("""Usage:\n
  --debug to work on a small subset of data\n
  --enddate ending date for loading and reconstruction; defaults to now\n
  --help for this message.\n
  --load to load data.  This will wipe existing data in the reporting database.\n
  --output FILE.  This will produce a csv dump of the fully denormalized data (one line per task per projectcolumn per day).\n
  --project Name of a Python file containing metadata specific to the project to be analyzed.  Reconstruct and report will not function without a project.\n
  --report Process data in SQL, generate graphs in R, and output a set of png files.\n
  --verbose to show extra messages\n
  --reconstruct Reprocess the loaded data to reconstruct a historical record day by day, in the database\n
  --startdate The date reconstruction should start, as YYYY-MM-DD""")
  
def load(conn, end_date, VERBOSE, DEBUG):
    cur = conn.cursor()

    # reload the database tables
    cur.execute(open("rebuild_working_tables.sql", "r").read())

    with open('../phabricator_public.dump') as dump_file:
       data = json.load(dump_file)

    ######################################################################
    # Load project and project column data
    ######################################################################
    project_insert = ("""INSERT INTO phabricator_project (id, name, phid)
                VALUES (%(id)s, %(name)s, %(phid)s)""")
    if VERBOSE:
        print("Trying to load {count} projects".format(count=len(data['project']['projects'])))
    for row in data['project']['projects']:
       cur.execute(project_insert, {'id':row[0] , 'name':row[1], 'phid':row[2] })

    cur.execute("SELECT phid, id from phabricator_project")
    project_phid_to_id_dict = dict(cur.fetchall())

    column_insert = ("""INSERT INTO phabricator_column (id, name, phid, project_phid)
                VALUES (%(id)s, %(name)s, %(phid)s, %(project_phid)s)""")
    if VERBOSE:
        print("Trying to load {count} projectcolumns".format(count=len(data['project']['columns'])))
    for row in data['project']['columns']:
        cur.execute(column_insert, {'id':row[0] , 'name':row[2], 'phid':row[1], 'project_phid':row[5] 
                     })
    ######################################################################
    # Load transactions and edges
    ######################################################################
    
    if VERBOSE:
        print("Trying to load tasks, transactions, and edges for {count} tasks".
              format(count=len(data['task'].keys())))

    transaction_insert = ("""
      INSERT INTO maniphest_transaction (
             id, phid, task_id, object_phid, transaction_type, 
             new_value, date_modified, active_projects)
      VALUES (%(id)s, %(phid)s, %(task_id)s, %(object_phid)s, %(transaction_type)s,
              %(new_value)s, %(date_modified)s, %(active_projects)s)""")

    task_insert = (""" 
      INSERT INTO maniphest_task (id, phid, title, story_points)
      VALUES (%(task_id)s, %(phid)s, %(title)s, %(story_points)s) """)

    for task_id in data['task'].keys():
        if DEBUG:
            if task_id != '85782':
                continue
            else:
                print(task_id)

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
                    active_proj = list()
                    # If this is an edge transaction, parse out the list of transactions
                    # 
                    if trans_type == 'core:edge':
                        jblob = json.loads(new_value)
                        if jblob:
                            for key in jblob.keys():
                                try:
                                    if jblob[key]['type'] == 41:
                                        proj_id = project_phid_to_id_dict[key]
                                        active_proj.append(proj_id)
                                except:
                                    print("Error loading {0}".format(jblob))
                    
                    cur.execute(transaction_insert,
                                {'id': trans[0] ,
                                 'phid': trans[1],
                                 'task_id': task_id,
                                 'object_phid': trans[3],
                                 'transaction_type': trans_type,
                                 'new_value': new_value,
                                 'date_modified': date_mod,
                                 'active_projects': active_proj})

    ######################################################################
    # generate denormalized transaction/edge data
    ######################################################################

    cur.execute("SELECT build_edges()")
    cur.close()

    #    oldest_data_query = """SELECT date(min(date_modified)) from maniphest_transaction"""
    #    cur.execute(oldest_data_query)
    #    working_date = cur.fetchone()[0]
    #    while working_date <= end_date:
    #        query_date = working_date + datetime.timedelta(days=1)

        
def reconstruct(conn, VERBOSE, DEBUG, output_file, default_points, project_name_list, start_date, end_date, task_history_table_name, project_csv_name):
    cur = conn.cursor()
    # preload project and column for fast lookup within Python
    cur.execute("SELECT name, phid from phabricator_project")
    project_name_to_phid_dict = dict(cur.fetchall())
    project_phid_to_name_dict = {value: key for key, value in project_name_to_phid_dict.items()}

    cur.execute("SELECT phid, name from phabricator_column")
    column_dict = dict(cur.fetchall())

    project_phid_list = list()
    f = open(project_csv_name, 'w')
    for project_name in project_name_list:
        f.write( "{0}\n".format(project_name) )
        project_phid_list.append(project_name_to_phid_dict[project_name])
    f.close()
    
    ######################################################################
    # Generate denormalized data
    ######################################################################
    # get the oldest date in the data and walk forward day by day from there

    header= ["Date","ID", "Title", "Status", "Project", "Column", "Points"]
    # reload the database tables
    task_history_ddl = """DROP TABLE IF EXISTS {0} ;

                          CREATE TABLE {0} (
                                 date timestamp,
                                 id int,
                                 title text,
                                 status text,
                                 project text,
                                 projectcolumn text,
                                 points int,
                                 maint_type text
                          )     ;

                          CREATE INDEX ON {0} (project) ;
                          CREATE INDEX ON {0} (projectcolumn) ;
                          CREATE INDEX ON {0} (status) ;
                          CREATE INDEX ON {0} (date) ;
                          CREATE INDEX ON {0} (id) ;
                          CREATE INDEX ON {0} (date,id) ;"""

    # Putting variables directly into SQL without escaping is vulnerable, but the only
    # variable we're adding is from the config file so exposure is limited
    unsafe_ddl = task_history_ddl.format(task_history_table_name)
    cur.execute(unsafe_ddl)

    if output_file:
        csvwriter = csv.writer(open(output_file, 'w'), delimiter=',')
        csvwriter.writerow(header)

    if not start_date:
        oldest_data_query = """SELECT date(min(date_modified)) from maniphest_transaction"""
        cur.execute(oldest_data_query)
        start_date = cur.fetchone()[0]
    working_date = start_date
        
    transaction_values_query = """
        SELECT mt.new_value 
          FROM maniphest_transaction mt 
         WHERE date(mt.date_modified) <= %(query_date)s
           AND mt.transaction_type = %(transaction_type)s 
           AND mt.object_phid = %(object_phid)s
         ORDER BY date_modified DESC """

    edge_values_query = """
        SELECT mt.active_projects
          FROM maniphest_transaction mt 
         WHERE date(mt.date_modified) <= %(query_date)s
           AND mt.object_phid = %(object_phid)s
         ORDER BY date_modified DESC """

    while working_date <= end_date:
        # because working_date is midnight at the beginning of the day, use a date at
        # the midnight at the end of the day to make the queries line up with the date label
        query_date = working_date + datetime.timedelta(days=1)
        if VERBOSE:
            print(working_date)
        task_on_day_query = """SELECT distinct(mt.object_phid) 
                                 FROM maniphest_transaction mt, 
                                      maniphest_edge me
                                WHERE mt.object_phid = me.task_phid 
                                  AND me.project_phid = ANY(%(project_phid)s)
                                  AND date(mt.date_modified) <= %(query_date)s"""

        cur.execute(task_on_day_query, {'query_date': query_date , 'project_phid': project_phid_list})
        for row in cur.fetchall():
            object_phid = row[0]
            # ----------------------------------------------------------------------
            # Title and Points
            # currently points are a separate field not in transaction data
            # this means historical points charts are actually retroactive
            # Title could be tracked retroactively but this code doesn't make that effort
            # ----------------------------------------------------------------------
            task_query = """SELECT title, story_points, id
                              FROM maniphest_task
                             WHERE phid = %(object_phid)s"""
            cur.execute(task_query, {'object_phid': object_phid, 'query_date': query_date, 'transaction_type': 'status'})
            task_info = cur.fetchone()
            pretty_title = task_info[0]
            task_id = task_info[2]
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
            cur.execute(transaction_values_query, {'object_phid': object_phid, 'query_date': query_date, 'transaction_type': 'status'})
            status_raw= cur.fetchone()
            pretty_status = ""
            if status_raw:
                pretty_status = status_raw[0]

            # ----------------------------------------------------------------------
            # Project & Maintenance Type
            # ----------------------------------------------------------------------
            cur.execute(edge_values_query, {'object_phid': object_phid, 'query_date': query_date})
            edges = cur.fetchall()
            import ipdb; ipdb.set_trace()
            edges_list = list()
            proj_dict = ""

            for trans_project in proj_dict:
                edges_list.append(trans_project)
            pretty_project = ""
            if 'PHID-PROJ-mm2dn7n5cs42tainm2rs' in edges_list:
                maint_type = 'New Functionality'
            elif 'PHID-PROJ-mcew7gqzloqahg6qgt2j' in edges_list:
                maint_type = 'Maintenance'
            else:
                maint_type = ''
            
            reportable_edges = list()
            # Reduce the list of edges to only the single best match,
            # where best = earliest in the specified project list
            for project in project_phid_list:
                if project in edges_list:
                    reportable_edges.append(project)
                    break

            if len(reportable_edges)>1:
                print("DEBUG: object {0}, reportable_edges{1}".format(object_phid, reportable_edges))
            for edge in reportable_edges:
                project_phid = edge
                pretty_project = project_phid_to_name_dict[project_phid]
                pretty_column = ''
                # ----------------------------------------------------------------------
                # Column
                # ----------------------------------------------------------------------
                cur.execute(transaction_values_query, {'object_phid': object_phid, 'query_date': query_date, 'transaction_type': 'projectcolumn'})
                pc_trans_list = cur.fetchall()
                for pc_trans in pc_trans_list:
                    jblob = json.loads(pc_trans[0])
                    if project_phid in jblob['projectPHID']:
                        column_phid = jblob['columnPHIDs'][0]
                        pretty_column = column_dict[column_phid]
                        break

                output_row = [query_date, object_phid, pretty_title, pretty_status, pretty_project, pretty_column, pretty_points]
                denorm_query = """
                    INSERT INTO {0} VALUES (
                    %(query_date)s,
                    %(id)s,
                    %(title)s,
                    %(status)s,
                    %(project)s,
                    %(projectcolumn)s,
                    %(points)s,
                    %(maint_type)s)"""

                unsafe_denorm_query = denorm_query.format(task_history_table_name)
                cur.execute(unsafe_denorm_query, {'query_date': query_date, 'id': task_id, 'title': pretty_title, 'status': pretty_status, 'project': pretty_project, 'projectcolumn': pretty_column, 'points': pretty_points, 'maint_type': maint_type })

                if output_file:
                    csvwriter.writerow(output_row)

        working_date += datetime.timedelta(days=1)
    cur.close()

def report(conn, VERBOSE, DEBUG, report_tables_script, report_script):
    cur = conn.cursor()
    cur.execute(open(report_tables_script, "r").read())
    subprocess.Popen("Rscript {0}".format(report_script), shell = True)

if __name__ == "__main__":
    main(sys.argv[1:])
