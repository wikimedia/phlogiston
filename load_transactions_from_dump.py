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

def main(argv):
    try:
        opts, args = getopt.getopt(argv, "dhlp:rv", ["debug", "help", "load", "project=", "report", "verbose"])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    load_data = False
    run_report = False
    DEBUG = False
    VERBOSE = False
    project_filter = None
    for opt, arg in opts:
        if opt in ("-d", "--debug"):
            DEBUG = True
        elif opt in ("-h", "--help"):
            usage()
            sys.exit()
        elif opt in ("-v", "--verbose"):
            VERBOSE = True
        elif opt in ("-l", "--load"):
            load_data = True
        elif opt in ("-r", "--report"):
            run_report = True
        elif opt in ("-p", "--project"):
            project_filter = arg

    conn = psycopg2.connect("dbname=phab")
    conn.autocommit = True

    if load_data:
        load(conn, VERBOSE, DEBUG)
    if run_report:
        report(conn, VERBOSE, DEBUG, project_filter)

    conn.close()

def usage():
   print("""Usage:\n
  --debug to work on a small subset of data
  --help for this message.\n
  --load to load data.  This will wipe existing data in the reporting database.\n
  --project PHID to filter for only tasks with the provided Project PHID.\n
  --report to make report.\n
  --verbose to show extra messages\n""")
   
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
        for edge in edges:
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
   
def report(conn, VERBOSE, DEBUG, project_filter):
    cur = conn.cursor()

    # preload project and column for fast lookup
    cur.execute("SELECT phid, name from phabricator_project")
    project_dict = dict(cur.fetchall())
    cur.execute("SELECT phid, name from phabricator_column")
    column_dict = dict(cur.fetchall())
    
    ######################################################################
    # Generate denormalized data
    ######################################################################
    # get the oldest date in the data and walk forward day by day from there
    csvwriter = csv.writer(open('test.csv', 'w'), delimiter=',')
    csvwriter.writerow(["Date","ID", "Title", "Status", "Project", "Column", "Points"])

    oldest_data_query = """SELECT date(min(date_modified)) from maniphest_transaction"""
    cur.execute(oldest_data_query)
    working_date = cur.fetchone()[0]
    target_date = datetime.datetime.now().date()
    if DEBUG:
        working_date = datetime.date(2015,2,1)
        target_date = datetime.date(2015,4, 20)

    while working_date <= target_date:
        # because working_date is midnight at the beginning of the day, use a date at
        # the midnight at the end of the day to make the queries line up with the date label
        query_date = working_date + datetime.timedelta(days=1)
        if VERBOSE:
            print(query_date)

        task_on_day_query = """SELECT distinct(mt.object_phid) 
                                 FROM maniphest_transaction mt
                                WHERE date(mt.date_modified) <= %(query_date)s"""

        if project_filter:
            task_on_day_query += """ AND mt.object_phid in (SELECT task_phid
            FROM maniphest_edge
            WHERE project_phid = %(project_phid)s)"""

        if DEBUG:
            task_on_day_query = """SELECT distinct(object_phid) FROM maniphest_transaction WHERE date(date_modified) <= %(query_date)s AND object_phid = 'PHID-TASK-bthovluuuig2pmi2xlsd'"""
            
        cur.execute(task_on_day_query, {'query_date': query_date , 'project_phid': project_filter})
        for row in cur.fetchall():
            # for each relevant variable of the task, use the most recent value
            # that is no later than that day.  (So, if that variable didn't change that day,
            # use the last time it was changed.  If it changed multiple times, use the final value)

            object_phid = row[0]
            if DEBUG:
                print(object_phid)

            # ----------------------------------------------------------------------
            # Title and Points
            # currently points are a separate field not in transaction data
            # this means historical points charts are actually retroactive
            # ----------------------------------------------------------------------

            task_query = """SELECT title, story_points
                              FROM maniphest_task
                             WHERE phid = %(object_phid)s"""

            cur.execute(task_query, {'object_phid': object_phid, 'query_date': query_date, 'transaction_type': 'status'})
            task_info = cur.fetchone()
            pretty_title = task_info[0]
            pretty_points = task_info[1]

            transaction_values_query = """
                SELECT mt.new_value 
                  FROM maniphest_transaction mt 
                 WHERE date(mt.date_modified) <= %(query_date)s
                   AND mt.transaction_type = %(transaction_type)s 
                   AND mt.object_phid = %(object_phid)s
              ORDER BY date_modified DESC"""

            # ----------------------------------------------------------------------
            # Status
            # ----------------------------------------------------------------------
            
            cur.execute(transaction_values_query, {'object_phid': object_phid, 'query_date': query_date, 'transaction_type': 'status'})
            status_raw= cur.fetchone()
            
            if status_raw:
                pretty_status = status_raw[0]
            else:
                pretty_status = ""

            # ----------------------------------------------------------------------
            # Project
            # ----------------------------------------------------------------------

            edge_query = """
            SELECT me.project_phid
              FROM maniphest_edge me
             WHERE me.task_phid = %(object_phid)s
               AND date(me.date_modified) <= %(query_date)s
            """

            cur.execute(edge_query, {'object_phid': object_phid, 'query_date': query_date, 'transaction_type': 'status'})
            edges = cur.fetchall()
            pretty_project = ""
            for edge in edges:
                raw_project = edge[0]
                pretty_project = project_dict[raw_project]

                # ----------------------------------------------------------------------
                # Column
                # ----------------------------------------------------------------------
                pretty_column = "column TODO"
                
                csvwriter.writerow([query_date, object_phid, pretty_title, pretty_status, pretty_project, pretty_column, pretty_points])

        working_date += datetime.timedelta(days=1)

    cur.close()

if __name__ == "__main__":
    main(sys.argv[1:])
