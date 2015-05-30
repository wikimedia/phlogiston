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
from pprint import pprint

conn = psycopg2.connect("dbname=phab")
conn.autocommit = True
cur = conn.cursor()

# with open('../phabricator_public.dump') as dump_file:
#    data = json.load(dump_file)

# # reload the database tables
# cur.execute(open("rebuild_working_tables.sql", "r").read())

# ######################################################################
# # Load project and project column data
# ######################################################################
    
# project_query = ("""INSERT INTO phab_project (id, name, phid)
#             VALUES (%(id)s, %(name)s, %(phid)s)""")

# for row in data['project']['projects']:
#     cur.execute(project_query, {'id':row[0] , 'name':row[1], 'phid':row[2] })

# column_query = ("""INSERT INTO phab_column (id, name, phid, project_phid)
#             VALUES (%(id)s, %(name)s, %(phid)s, %(project_phid)s)""")

# for row in data['project']['columns']:
#     cur.execute(column_query, {'id':row[0] , 'name':row[2], 'phid':row[1], 'project_phid':row[5] })

# ######################################################################
# # Load tasks and edges and transactions
# ######################################################################

# task_query = (
#     """INSERT INTO phab_task (id, phid)
#             VALUES (%(id)s, %(phid)s)
#     """)

# for task in data['task'].keys():
#     # add the task
#     try:
#         task_phid = data['task'][task]['edge'][0][0]
#         cur.execute(task_query, {'id':task , 'phid':task_phid })
#     except IndexError as e:
#         break
#         # this task has no project.  Skip this task altogether
#         # print("Index Error for task {task}: {e}".format(task=task, e=e))

#     edge_query = ("""INSERT INTO phab_task_to_project (task_phid, project_phid)
#                 VALUES (%(task_phid)s, %(project_phid)s)""")

#     for edge in data['task'][task]['edge']:
#         try:
#             cur.execute(edge_query, {'task_phid':edge[0] , 'project_phid':edge[2] })
#         except psycopg2.IntegrityError as e:
#             pass
#             # this is a case where the task has the same project two or more times            

#     transaction_query = (
#         """INSERT INTO phab_transaction (id, phid, object_phid, transaction_type, new_value, date_modified)
#                 VALUES (%(id)s, %(phid)s, %(object_phid)s, %(transaction_type)s, %(new_value)s, %(date_modified)s)""")

#     for row in data['task'][task]['transactions'].keys():
#         if data['task'][task]['transactions'][row]:
#             for trans in data['task'][task]['transactions'][row]:
#                 cur.execute(transaction_query, {'id':trans[0] , 'phid':trans[1], 'object_phid':trans[3], 'transaction_type':trans[6], 'new_value':trans[8], 'date_modified': time.strftime('%m/%d/%Y %H:%M:%S', time.gmtime(trans[11])) })

######################################################################
# Generate denormalized data
######################################################################

# get the oldest date in the data and walk forward day by day from there

oldest_data_query = """SELECT date(min(date_modified)) from phab_transaction"""

cur.execute(oldest_data_query)
result=cur.fetchone()[0]
working_date = result

#csvwriter = csv.writer(open('test.csv', 'w'), delimiter=',')
#csvwriter.writerow(["Date","ID", "Title", "Project", "Status", "Column", "Points"])

while working_date <= datetime.datetime.now().date():
    print(working_date)
    working_date += datetime.timedelta(days=1)

    task_on_day_query = """SELECT distinct(object_phid) FROM phab_transaction WHERE date(date_modified) = %(working_date)s """
    cur.execute(task_on_day_query, {'working_date': working_date })
    for task in cur.fetchall():
        print(task)
   
#     for row in result:
#         # for each task id, populate a row in output
#         # for each relevant variable of the task, use the most recent value
#         # that is no later than that day.  (So, if that variable didn't change that day,
#         # use the last time it was changed.)

#         taskid = row[0].decode('utf-8')

#         ##########################################################
#         # Title
#         ##########################################################
        
#         task_attribute_query = text(
#             "SELECT mt.newValue "
#               "FROM maniphest_transaction mt "
#              "WHERE mt.dateModified = (SELECT max(mt1.dateModified) "
#                                         "FROM maniphest_transaction mt1 "
#                                        "WHERE mt1.objectPHID = :taskid "
#                                          "AND mt1.transactionType = :transaction_type "
#                                          "AND mt1.dateModified <= UNIX_TIMESTAMP(:working_date)) "
#                "AND mt.transactionType = :transaction_type "
#                "AND mt.objectPHID = :taskid")
        
#         title = conn.execute(task_attribute_query, taskid=taskid, working_date=working_date, transaction_type='title').first()
#         if title:
#             pretty_title = title[0].decode('utf-8')
#         else:
#             pretty_title = ""

#         ##########################################################
#         # Status
#         ##########################################################

#         status_raw = conn.execute(task_attribute_query, taskid=taskid, working_date=working_date, transaction_type='status').first()
#         if status_raw:
#             pretty_status = status_raw[0].decode('utf-8')
#         else:
#             pretty_status = ""
            
#         ##########################################################
#         # Project and column
#         ##########################################################
      
#         # TODO: this will return only one column, which I guess is a problem if the task is
#         # in multiple projects, different column for each.  Probably the right thing to do
#         # is to create a separate row for each different project?

#         pc_raw = conn.execute(task_attribute_query, taskid=taskid, working_date=working_date, transaction_type='projectcolumn').fetchall()
        
#         pretty_column = ""
#         pretty_project = ""

#         if pc_raw:
#             pc_semiraw = pc_raw[0]['newValue'].decode('utf-8')
#             pc_json = json.loads(pc_semiraw)
#             raw_column = str(pc_json['columnPHIDs'][0])
#             raw_project = str(pc_json['projectPHID'])

#             try:
#                 pretty_column = column_dict[raw_column]
#             except KeyError as e:
#                 pretty_column = "{raw_column}| error {e}".format(raw_column=raw_column, e=e)

#             try:
#                 pretty_project = project_dict[raw_project]
#             except KeyError as e:
#                 pretty_project = "{raw_project}| error {e}".format(raw_project=raw_project, e=e)

#         ##########################################################
#         # Points
#         ##########################################################
#         pretty_points = "TODO"
        
#         csvwriter.writerow([working_date, taskid, pretty_title, pretty_status, pretty_project, pretty_column, pretty_points])

cur.close()
conn.close()
