# This script reads a JSON file produced by https://gerrit.wikimedia.org/r/#/c/214398/2/wmfphablib/phabdb.py
# and reloads a postgresql database containing the data
# and outputs a flat file containing a denormalized report of the task history
# with one row for each task for each day since the data started
#
# requires pyscopg2.  On ubuntu: apt-get install python3-psycopg2

import psycopg2
import csv
import json
import time
import datetime
import sys, getopt
from pprint import pprint

def main(argv):
    try:
        opts, args = getopt.getopt(argv, "vhlr", ["verbose", "help", "load", "report"])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    load_data = False
    run_report = False
    DEBUG = False
    for opt, arg in opts:
        if opt in ("-h", "--help"):
           usage()
           sys.exit()
        elif opt in ("-v", "--verbose"):
           DEBUG = True
        elif opt in ("-l", "--load"):
           load_data = True
        elif opt in ("-r", "--report"):
           run_report = True

    conn = psycopg2.connect("dbname=phab")
    conn.autocommit = True

    if load_data:
        load(conn, DEBUG)
    if run_report:
        report(conn, DEBUG)

    conn.close()

def usage():
   print("""Usage:\n
  --help for this message.\n
  --load to load data.  This will wipe existing data in the reporting database.\n
  --report to make report.
  --verbose to show debugging (and also to operate on a smaller set of data)""")
   
def load(conn, DEBUG):
    cur = conn.cursor()
    with open('../phabricator_public.dump') as dump_file:
       data = json.load(dump_file)

    # reload the database tables
    cur.execute(open("rebuild_working_tables.sql", "r").read())

    ######################################################################
    # Load project and project column data
    ######################################################################
    project_query = ("""INSERT INTO phabricator_project (id, name, phid)
                VALUES (%(id)s, %(name)s, %(phid)s)""")

    for row in data['project']['projects']:
       cur.execute(project_query, {'id':row[0] , 'name':row[1], 'phid':row[2] })

    if DEBUG:
        print("Loaded {count} projects".format(count=len(data['project']['projects'])))

    column_query = ("""INSERT INTO phabricator_column (id, name, phid, project_phid)
                VALUES (%(id)s, %(name)s, %(phid)s, %(project_phid)s)""")

    for row in data['project']['columns']:
       cur.execute(column_query, {'id':row[0] , 'name':row[2], 'phid':row[1], 'project_phid':row[5] })

    if DEBUG:
        print("Loaded {count} projectcolumns".format(count=len(data['project']['columns'])))

    ######################################################################
    # Load tasks and edges and transactions
    ######################################################################

    task_query = (
        """INSERT INTO maniphest_task (id, phid)
                VALUES (%(id)s, %(phid)s)
        """)

    for task in data['task'].keys():
        print(task)
        # add the task
        try:
            task_phid = data['task'][task]['edge'][0][0]
            cur.execute(task_query, {'id':task , 'phid':task_phid })
        except IndexError as e:
            if DEBUG:
                print("Index Error for task {task}: {e}".format(task=task, e=e))
            break
            # this task has no project.  Skip this task altogether

        edge_query = ("""INSERT INTO maniphest_task_to_project (task_phid, project_phid)
                    VALUES (%(task_phid)s, %(project_phid)s)""")

        for edge in data['task'][task]['edge']:
            try:
                cur.execute(edge_query, {'task_phid':edge[0] , 'project_phid':edge[2] })
            except psycopg2.IntegrityError:
               pass
               # this is a case where the task has the same project two or more times            

        transaction_query = (
           """INSERT INTO maniphest_transaction (id, phid, object_phid, transaction_type, new_value, date_modified)
                    VALUES (%(id)s, %(phid)s, %(object_phid)s, %(transaction_type)s, %(new_value)s, %(date_modified)s)""")

        for row in data['task'][task]['transactions'].keys():
            if data['task'][task]['transactions'][row]:
                for trans in data['task'][task]['transactions'][row]:
                    cur.execute(transaction_query, {'id':trans[0] , 'phid':trans[1], 'object_phid':trans[3], 'transaction_type':trans[6], 'new_value':trans[8], 'date_modified': time.strftime('%m/%d/%Y %H:%M:%S', time.gmtime(trans[11])) })
    if DEBUG:
        print("Read {count} tasks.  (Not all tasks may have been imported.)".format(count=len(data['task'].keys())))
    cur.close()
    
def report(conn, DEBUG):
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

    oldest_data_query = """SELECT date(min(date_modified)) from maniphest_transaction"""

    cur.execute(oldest_data_query)
    result=cur.fetchone()[0]
    working_date = result
    working_date = datetime.date(2014,9,19)
    csvwriter = csv.writer(open('test.csv', 'w'), delimiter=',')
    csvwriter.writerow(["Date","ID", "Title", "Project", "Status", "Column", "Points"])

    target_date = datetime.datetime.now().date()
    if DEBUG:
        target_date = datetime.date(2014, 10, 21)
        
    while working_date <= target_date:
        if DEBUG:
            print(working_date)
        # generate a list of all tasks that have been created by this date
        # assumes that the transaction data includes the creation of all tasks, i.e.,
        # goes back all the way

        # TODO: DEBUG
        task_on_day_query = """SELECT distinct(object_phid) FROM maniphest_transaction WHERE date(date_modified) <= %(working_date)s AND object_phid = 'PHID-TASK-ewnlk4lkha5fx3wfn3k6'"""
        cur.execute(task_on_day_query, {'working_date': working_date })

        for row in cur.fetchall():

            # for each relevant variable of the task, use the most recent value
            # that is no later than that day.  (So, if that variable didn't change that day,
            # use the last time it was changed.  If it changed multiple times, use the final value)
            # TODO: order to make sure the final value is selected
            taskid = row[0]
            print(taskid)
            task_attribute_query = """
                SELECT mt.new_value 
                  FROM maniphest_transaction mt 
                 WHERE mt.date_modified = (SELECT max(mt1.date_modified) 
                                            FROM maniphest_transaction mt1 
                                           WHERE mt1.object_phid = %(taskid)s 
                                             AND mt1.transaction_type = %(transaction_type)s 
                                             AND mt1.date_modified <= %(working_date)s)
                   AND mt.transaction_type = %(transaction_type)s 
                   AND mt.object_phid = %(taskid)s"""

            cur.execute(task_attribute_query, {'taskid': taskid, 'working_date': working_date, 'transaction_type': 'status'})
            status_raw= cur.fetchone()
            
            if status_raw:
                pretty_status = status_raw[0]
            else:
                pretty_status = ""

            pretty_points = "Points TODO"

            cur.execute(task_attribute_query, {'taskid': taskid, 'working_date': working_date, 'transaction_type': 'projectcolumn'})
            pc_raw = cur.fetchall()
            
            pprint(pc_raw)

            pretty_column = ""
            pretty_project = ""

            if pc_raw:
                pc_semiraw = pc_raw[0]
                pc_json = json.loads(pc_semiraw)
                raw_project = str(pc_json['projectPHID'])
                print(pc_json['columnPHIDS'].length())
                
                raw_column = str(pc_json['columnPHIDs'][0])
                pretty_project = project_dict[raw_project]
                pretty_column = column_dict[raw_column]

            
            csvwriter.writerow([working_date, taskid, pretty_status, pretty_project, pretty_column, pretty_points])

        working_date += datetime.timedelta(days=1)

    cur.close()

if __name__ == "__main__":
    main(sys.argv[1:])
