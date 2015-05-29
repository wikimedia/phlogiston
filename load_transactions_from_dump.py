# This script reads a JSON file produced by https://gerrit.wikimedia.org/r/#/c/214398/2/wmfphablib/phabdb.py
# and reloads a postgresql database containing the data
# and outputs a flat file containing a denormalized report of the task history
# with one row for each task for each day since the data started
#
# requires pyscopg2.  On ubuntu: apt-get install python3-psycopg2

import psycopg2
import csv
import json
from pprint import pprint

conn = psycopg2.connect("dbname=phab")
cur = conn.cursor()

with open('../phabricator_public.dump') as dump_file:
    data = json.load(dump_file)

# reload the database tables
cur.execute(open("rebuild_working_tables.sql", "r").read())
conn.commit()

######################################################################
# Load project and project column data
######################################################################
    
# 0 SELECT id,
# 1        name
# 2        phid
# 3        dateCreated
# 4        dateModified
# 5        icon
# 6        color
#     FROM project

query = (
    """INSERT INTO 
for phab_project in data['project']['projects']:
    


# 0 SELECT id,
# 1        phid,
# 2        name,
# 3        status,
# 4        sequence,
# 5        projectPHID,
# 6        dateCreated,
# 7        dateModified,
# 8        properties
#     FROM project_column"
  

######################################################################
# Get the task data
######################################################################

# trans = Table('maniphest_transaction', metadata,
#               Column('transactionType', String),
#               Column('objectPHID', None, ForeignKey('maniphest_task.phid')),
#               Column('newValue', String),
#               Column('dateModified', DateTime)
# )


# # get a list of all days in the data
# # TODO: should get the oldest date, and then walk through all dates up to today (or date specified in command line) so that there are no gaps

# query = select([func.from_unixtime(trans.c.dateModified,"%Y%m%d").label('date')]).\
#                group_by("date")

# result = conn.execute(query)

# csvwriter = csv.writer(open('test.csv', 'w'), delimiter=',')
# csvwriter.writerow(["Date","ID", "Title", "Project", "Status", "Column", "Points"])

# for row in result:
#     # for each day, get a list of all task ids in transactions up to and including this day
    
#     # bump working day by one because the cutoff is midnight at the start of the day,
#     # but we want midnight at the end of the day
#     working_date = int(row[0]) + 1
    
#     query = select([func.distinct(trans.c.objectPHID)]).\
#             where(func.from_unixtime(trans.c.dateModified,"%Y%m%d") <= working_date)
#     result = conn.execute(query)
    
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
