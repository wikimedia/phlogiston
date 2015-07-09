# This script reads a JSON file produced by https://gerrit.wikimedia.org/r/#/c/214398/2/wmfphablib/phabdb.py
# and reloads a postgresql database containing the data
# and outputs a flat file containing a denormalized report of the task history
# with one row for each task for each day since the data started
# Data is available at  http://dumps.wikimedia.org/other/misc/phabricator_public.dump

import psycopg2
import csv
import json
import time
import datetime
import sys, getopt
import subprocess
import datetime

def main(argv):
    try:
        opts, args = getopt.getopt(argv, "cdehlo:p:rv", ["reconstruct", "debug", "defaultpoints", "help", "load", "output=", "project=", "report", "verbose"])
    except getopt.GetoptError as e:
        print(e)
        usage()
        sys.exit(2)
    load_data = False
    reconstruct_data = False
    run_report = False
    DEBUG = False
    VERBOSE = False
    OUTPUT_FILE = ''
    project_filter = None
    default_points = 10
    for opt, arg in opts:
        if opt in ("-c", "--reconstruct"):
            reconstruct_data = True
        elif opt in ("-d", "--debug"):
            DEBUG = True
        elif opt in ("-e", "--defaultpoints"):
            default_points = arg
        elif opt in ("-h", "--help"):
            usage()
            sys.exit()
        elif opt in ("-l", "--load"):
            load_data = True
        elif opt in ("-o", "--output"):
            OUTPUT_FILE = arg
        elif opt in ("-p", "--project"):
            project_filter = arg
        elif opt in ("-r", "--report"):
            run_report = True
        elif opt in ("-v", "--verbose"):
            VERBOSE = True
    conn = psycopg2.connect("dbname=phab")
    conn.autocommit = True
    if load_data:
        load(conn, VERBOSE, DEBUG)
    if reconstruct_data:
        reconstruct(conn, VERBOSE, DEBUG, OUTPUT_FILE, project_filter, default_points)
    if run_report:
        report(conn, VERBOSE, DEBUG)
    conn.close()

def usage():
   print("""Usage:\n
  --debug to work on a small subset of data\n
  --help for this message.\n
  --load to load data.  This will wipe existing data in the reporting database.\n
  --output FILE.  This will produce a csv dump of the fully denormalized data (one line per task per projectcolumn per day).
  --project comma-separated list of PHID to include. Tasks belonging to multiple PHIDs are assigned only to the first in this list.  Applies only to reporting, not loading.\n
  --report Process data in SQL, generate graphs in R, and output a set of png files.\n
  --verbose to show extra messages\n
  --reconstruct Reprocess the loaded data to reconstruct a historical record day by day, in the database""")
   
def load(conn, VERBOSE, DEBUG):
    cur = conn.cursor()
    with open('../phabricator_public.dump') as dump_file:
       data = json.load(dump_file)

    # reload the database tables
    cur.execute(open("rebuild_working_tables.sql", "r").read())

    ######################################################################
    # Load transactions and edges
    ######################################################################
    
    if VERBOSE:
        print("Trying to load tasks, transactions, and edges for {count} tasks".format(count=len(data['task'].keys())))

    for task_id in data['task'].keys():
        task = data['task'][task_id]
        task_phid = ''
        title = ''
        story_points = None
        if task['info']:
            task_phid = task['info'][1]
            title = task['info'][7]
        if task['storypoints']:
            story_points = task['storypoints'][2]
        task_insert = (""" INSERT INTO maniphest_task (id, phid, title, story_points)
                                VALUES (%(task_id)s, %(phid)s, %(title)s, %(story_points)s) """)
        cur.execute(task_insert, {'task_id': task_id, 'phid': task_phid, 'title': title, 'story_points': story_points})
        edges = task['edge']
        import ipdb; ipdb.set_trace()

        for edge in edges:
        # edge is membership in a project.  This ought to be transactional, but until the data is better understood,
        # this only records adding of a project to a task, not removing
            edge_insert = (
                """INSERT INTO maniphest_edge (task_phid, project_phid, date_modified)
                        VALUES (%(task_phid)s, %(project_phid)s, %(date_modified)s)""")
            cur.execute(edge_insert, {'task_phid':task_phid , 'project_phid':edge[2], 'date_modified': time.strftime('%m/%d/%Y %H:%M:%S', time.gmtime(edge[3])) })

        transactions = task['transactions']
        for trans_key in list(transactions.keys()):
            if transactions[trans_key]:
                for trans in transactions[trans_key]:
                    transaction_insert = (
                        """INSERT INTO maniphest_transaction (id, phid, task_id, object_phid, transaction_type, new_value, date_modified)
                        VALUES (%(id)s, %(phid)s, %(task_id)s, %(object_phid)s, %(transaction_type)s, %(new_value)s, %(date_modified)s)""")
                    cur.execute(transaction_insert, {'id':trans[0] , 'phid':trans[1], 'task_id': task_id, 'object_phid':trans[3], 'transaction_type':trans[6], 'new_value':trans[8], 'date_modified': time.strftime('%m/%d/%Y %H:%M:%S', time.gmtime(trans[11])) })

        
    ######################################################################
    # Load project and project column data
    ######################################################################
    project_insert = ("""INSERT INTO phabricator_project (id, name, phid)
                VALUES (%(id)s, %(name)s, %(phid)s)""")
    if VERBOSE:
        print("Trying to load {count} projects".format(count=len(data['project']['projects'])))
    for row in data['project']['projects']:
       cur.execute(project_insert, {'id':row[0] , 'name':row[1], 'phid':row[2] })

    column_insert = ("""INSERT INTO phabricator_column (id, name, phid, project_phid)
                VALUES (%(id)s, %(name)s, %(phid)s, %(project_phid)s)""")
    if VERBOSE:
        print("Trying to load {count} projectcolumns".format(count=len(data['project']['columns'])))
    for row in data['project']['columns']:
       cur.execute(column_insert, {'id':row[0] , 'name':row[2], 'phid':row[1], 'project_phid':row[5] })

    cur.close()
   
def reconstruct(conn, VERBOSE, DEBUG, OUTPUT_FILE, project_filter, default_points):
    cur = conn.cursor()
    cur.execute(open("rebuild_bi_tables.sql", "r").read())

    # preload project and column for fast lookup within Python
    cur.execute("SELECT phid, name from phabricator_project")
    project_dict = dict(cur.fetchall())
    cur.execute("SELECT phid, name from phabricator_column")
    column_dict = dict(cur.fetchall())

    project_list = ""
    if project_filter:
        project_list = tuple(project_filter.split(","))
    
    ######################################################################
    # Generate denormalized data
    ######################################################################
    # get the oldest date in the data and walk forward day by day from there

    header= ["Date","ID", "Title", "Status", "Project", "Column", "Points"]
    # reload the database tables
    cur.execute(open("rebuild_bi_tables.sql", "r").read())
    if OUTPUT_FILE:
        csvwriter = csv.writer(open(OUTPUT_FILE, 'w'), delimiter=',')
        csvwriter.writerow(header)

    oldest_data_query = """SELECT date(min(date_modified)) from maniphest_transaction"""
    cur.execute(oldest_data_query)
    working_date = cur.fetchone()[0]
    target_date = datetime.datetime.now().date()
    if DEBUG:
#        working_date = datetime.date(2015,2,23)
        target_date = datetime.date(2015,3,1)

    while working_date <= target_date:
        # because working_date is midnight at the beginning of the day, use a date at
        # the midnight at the end of the day to make the queries line up with the date label
        query_date = working_date + datetime.timedelta(days=1)
        if VERBOSE:
            print()
            print(query_date,end="")
        task_on_day_query = """SELECT distinct(mt.object_phid) 
                                 FROM maniphest_transaction mt"""
        if project_filter:
            task_on_day_query += """, maniphest_edge me
                                WHERE mt.object_phid = me.task_phid 
                                  AND me.project_phid IN %(project_phid)s
                                  AND """
        else:
            task_on_day_query += """ WHERE """
        task_on_day_query += """ date(mt.date_modified) <= %(query_date)s"""

        if DEBUG:
            task_on_day_query = """SELECT distinct(object_phid) FROM maniphest_transaction WHERE date(date_modified) <= %(query_date)s AND object_phid = 'PHID-TASK-h27s7yvr62xzheogrrv7'"""

        cur.execute(task_on_day_query, {'query_date': query_date , 'project_phid': project_list})

        for row in cur.fetchall():
            object_phid = row[0]
            # ----------------------------------------------------------------------
            # Title and Points
            # currently points are a separate field not in transaction data
            # this means historical points charts are actually retroactive
            # Title could be tracked retroactively but this code doesn't make that effort
            # ----------------------------------------------------------------------
            task_query = """SELECT title, story_points
                              FROM maniphest_task
                             WHERE phid = %(object_phid)s"""
            cur.execute(task_query, {'object_phid': object_phid, 'query_date': query_date, 'transaction_type': 'status'})
            task_info = cur.fetchone()
            pretty_title = task_info[0]
            try:
                pretty_points = int(task_info[1])
            except:
                pretty_points = default_points
            # for each relevant variable of the task, use the most recent value
            # that is no later than that day.  (So, if that variable didn't change that day,
            # use the last time it was changed.  If it changed multiple times, use the final value)
            transaction_values_query = """
                SELECT mt.new_value 
                  FROM maniphest_transaction mt 
                 WHERE date(mt.date_modified) <= %(query_date)s
                   AND mt.transaction_type = %(transaction_type)s 
                   AND mt.object_phid = %(object_phid)s
              ORDER BY date_modified DESC """

            # ----------------------------------------------------------------------
            # Status
            # ----------------------------------------------------------------------
            cur.execute(transaction_values_query, {'object_phid': object_phid, 'query_date': query_date, 'transaction_type': 'status'})
            status_raw= cur.fetchone()
            pretty_status = ""
            if status_raw:
                pretty_status = status_raw[0]

            # ----------------------------------------------------------------------
            # Project
            # ----------------------------------------------------------------------
            edge_query = """
            SELECT me.project_phid
              FROM maniphest_edge me
             WHERE me.task_phid = %(object_phid)s
               AND date(me.date_modified) <= %(query_date)s
            """
            cur.execute(edge_query, {'object_phid': object_phid, 'query_date': query_date, 'transaction_type': 'status', 'project_list': project_list})
            edges = cur.fetchall()
            edges_list = [i[0] for i in edges]
            pretty_project = ""
            reportable_edges = []

            if DEBUG:
                for edge in edges_list:
                    print(project_dict[edge], " ", end="")
#                print("PROJECT")
#                for project in project_list:
#                    print(project_dict[project])

            if project_list:
                # if a list of projects is specified, reduce the list
                # of edges to only the single best match, where best =
                # earliest in the specified project list
#                import ipdb; ipdb.set_trace()
                for project in project_list:
                    if project in edges_list:
                        reportable_edges.append(project)
                        break
            else:
                reportable_edges = edges_list

#            if DEBUG:
#                print(reportable_edges)

            for edge in reportable_edges:
                project_phid = edge
                pretty_project = project_dict[project_phid]
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
                    INSERT INTO task_history VALUES (
                    %(query_date)s,
                    %(title)s,
                    %(status)s,
                    %(project)s,
                    %(projectcolumn)s,
                    %(points)s)"""
                cur.execute(denorm_query, {'query_date': query_date, 'title': pretty_title, 'status': pretty_status, 'project': pretty_project, 'projectcolumn': pretty_column, 'points': pretty_points })

                if OUTPUT_FILE:
                    csvwriter.writerow(output_row)

        working_date += datetime.timedelta(days=1)
    cur.close()

def report(conn, VERBOSE, DEBUG):
    cur = conn.cursor()
    cur.execute(open("rebuild_report_tables.sql", "r").read())
    subprocess.Popen("Rscript report.R", shell = True)

if __name__ == "__main__":
    main(sys.argv[1:])
