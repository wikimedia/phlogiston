# This script exports a limited, sanitized copy of the Phabricator transaction
# table from a production Phabricator MySQL database, for purposes of offline
# analysis.

# Intended security/sanitizing measures:
# only export public data
# export only the project of interest (hard-coded to VisualEditor)
# export only limited amounts of metadata, excluding content and titles

import MySQLdb as dbapi
import csv

dbServer='localhost'
dbPass=''
dbSchema='phabricator_project'
dbUser='root'

query=text(
    "SELECT * "
      "FROM phabricator_maniphest.maniphest_transaction trans, "
          " phabricator_maniphest.maniphest_task task "
     "WHERE task.phid = trans.objectphid "
       "AND task.viewPolicy = 'public'"

db=dbapi.connect(host=dbServer,user=dbUser,passwd=dbPass)
cur=db.cursor()
cur.execute(dbQuery)
result=cur.fetchall()

c = csv.writer(open("maniphest_transaction.csv","wb"))
for row in result:
    c.writerow(row)

# TODO: repeat for project and columns
