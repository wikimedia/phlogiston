# This script reads Phabricator transaction data from a MySQL database
# and outputs a denormalized table containing with one row for each task
# for each day

# It is a proof of concept script not intended for use in a production environment
# Things that are incomplete:
#  - Points field isn't coded
#  - assumes there is only one column per project per task; this may not be true
#  - assumes there is only one project per task; this is definitely not true
#  - some output fields are excessively quoted

# database connection is hardcoded to pull from root@mysql locally
# if Phabricator mysql is on another host, set up ssh tunnel first with
# ssh -p 2222 -n -N -f -L 3306:localhost:3306 vagrant@127.0.0.1

import csv
import json
import time
import sqlalchemy
from sqlalchemy import create_engine, Table, Column, Integer, String, MetaData, ForeignKey
from sqlalchemy.sql import select, func, text

from sqlalchemy.types import VARBINARY, DateTime

metadata = MetaData()

######################################################################
# Get Project and Column Names
######################################################################

# Task information is in phabricator_maniphest.maniphest_transaction.
# Project names are in phabricator_project.project
# column names are in phabricator_project.project_column
# Phabricator does not use foreign keys.  Historical Project ID and column ID
# are in a JSON field in maniphest_transaction.
# Rather than join in the database, just get a list of them and join in this script
# this breaks the historicity, in that Project and Column will be set according to their
# name as of runtime, not their name as of the date of each transaction, but
# that shouldn't matter for purposes of burndowns or cycle time.

phab_engine = create_engine('mysql+mysqlconnector://root@localhost/phabricator_project?charset=utf8')
conn = phab_engine.connect()

project = Table('project', metadata,
                Column('phid', VARBINARY),
                Column('name', String)
            )

column = Table('project_column', metadata,
                 Column('phid', VARBINARY),
                 Column('name', String)
             )

query = select([project.c.phid, project.c.name])
project_results = conn.execute(query)

project_dict = {}

for row in project_results.fetchall():
    phid = row[0].decode('utf-8')
    project = row[1]
    project_dict[phid] = project

query = select([column.c.phid, column.c.name])
column_results = conn.execute(query)
column_dict = {}

for row in column_results.fetchall():
    phid = row[0].decode('utf-8')
    column = row[1].decode('utf-8')
    column_dict[phid] = column

######################################################################
# Get the task data
######################################################################

phab_engine = create_engine('mysql+mysqlconnector://root@localhost/phabricator_maniphest?charset=utf8')
conn = phab_engine.connect()

task = Table('maniphest_task', metadata,
             Column('phid', VARBINARY),
             Column('title', String)
)
 
trans = Table('maniphest_transaction', metadata,
              Column('transactionType', String),
              Column('objectPHID', None, ForeignKey('maniphest_task.phid')),
              Column('newValue', String),
              Column('dateModified', DateTime)
)


# get a list of all days in the data

query = select([func.from_unixtime(trans.c.dateModified,"%Y%m%d").label('date')]).\
               group_by("date")

result = conn.execute(query)

csvwriter = csv.writer(open('test.csv', 'w'), delimiter=',')
csvwriter.writerow(["Date","ID", "Title", "Project", "Status", "Column", "Points"])

for row in result:
    # for each day, get a list of all task ids in transactions up to and including this day
    
    # bump working day by one because the cutoff is midnight at the start of the day,
    # but we want midnight at the end of the day
    working_date = int(row[0]) + 1
    
    query = select([func.distinct(trans.c.objectPHID)]).\
            where(func.from_unixtime(trans.c.dateModified,"%Y%m%d") <= working_date)
    result = conn.execute(query)
    
    for row in result:
        # for each task id, populate a row in output
        # for each relevant variable of the task, use the most recent value
        # that is no later than that day.  (So, if that variable didn't change that day,
        # use the last time it was changed.)

        taskid = row[0].decode('utf-8')

        ##########################################################
        # Title
        ##########################################################
        
        simple_query = text(
            "SELECT mt.newValue "
            "FROM maniphest_transaction mt "
            "WHERE mt.dateModified = (SELECT max(mt1.dateModified) "
            "FROM maniphest_transaction mt1 "
            "WHERE mt1.objectPHID = :taskid "
            "AND mt1.transactionType = :transaction_type "
            "AND mt1.dateModified <= UNIX_TIMESTAMP(:working_date)) "
            "AND mt.transactionType = :transaction_type "
            "AND mt.objectPHID = :taskid")
        
        title = conn.execute(simple_query, taskid=taskid, working_date=working_date, transaction_type='title').first()
        if title:
            pretty_title = title[0].decode('utf-8')
        else:
            pretty_title = ""

        ##########################################################
        # Status
        ##########################################################

        status_raw = conn.execute(simple_query, taskid=taskid, working_date=working_date, transaction_type='status').first()
        if status_raw:
            pretty_status = status_raw[0].decode('utf-8')
        else:
            pretty_status = ""
            
        ##########################################################
        # Project and column
        ##########################################################
      
        # TODO: this will return only one column, which I guess is a problem if the task is
        # in multiple projects, different column for each.  Probably the right thing to do
        # is to create a separate row for each different project?

        pc_raw = conn.execute(simple_query, taskid=taskid, working_date=working_date, transaction_type='projectcolumn').fetchall()
        
        pretty_column = ""
        pretty_project = ""

        if pc_raw:
            pc_semiraw = pc_raw[0]['newValue'].decode('utf-8')
            pc_json = json.loads(pc_semiraw)
            raw_column = str(pc_json['columnPHIDs'][0])
            raw_project = str(pc_json['projectPHID'])

            try:
                pretty_column = column_dict[raw_column]
            except KeyError as e:
                pretty_column = "{raw_column}| error {e}".format(raw_column=raw_column, e=e)

            try:
                pretty_project = project_dict[raw_project]
            except KeyError as e:
                pretty_project = "{raw_project}| error {e}".format(raw_project=raw_project, e=e)

        ##########################################################
        # Points
        ##########################################################
        pretty_points = "TODO"
        
        csvwriter.writerow([working_date, taskid, pretty_title, pretty_status, pretty_project, pretty_column, pretty_points])

