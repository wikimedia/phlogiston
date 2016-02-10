#!/usr/bin/python3

import argparse
import datetime
import subprocess

def run_command(command, dir, output):
    output.write('{0}: Starting {1}\n'.format(datetime.datetime.now().strftime('%Y-%b-%d %I:%M:%S %p'), command))
    try:
        byte_out = subprocess.check_output(command,
                                         shell=True,
                                         cwd=dir,
                                         stderr=subprocess.STDOUT)
        result = byte_out.decode('utf-8')
    except subprocess.CalledProcessError as e:
        result = 'Failed with {0}'.format(e.output)
    output.write('{0}\n'.format(result))

parser = argparse.ArgumentParser(description='Run phlogiston.py for multiple projects.  Complete mode reinitializes the database, downloads the latest Phabricator dump, loads it into Phlogiston, uses it to completely reconstruct all specified project histories, and generates reports.  Incremental mode downloads the dump, loads it, reconstructs new project data since the last load, and generates reports.  Reports only generates reports.  All modes begin with git pull.')
parser.add_argument('--projects', nargs='*', help="A list of projects to be processed")
parser.add_argument('mode', nargs=1, choices=['complete', 'incremental', 'reports'], help="Mode of operation")
args = parser.parse_args()

homedir = subprocess.check_output("echo $HOME", shell=True).decode('utf-8').strip()
phlogdir = '{0}/phlogiston'.format(homedir)
mode = args.mode[0]

f = open('{0}/phlog.log'.format(homedir), 'a+', 1)
f.write('{0}: Starting\n'.format(datetime.datetime.now().strftime('%Y-%b-%d %I:%M:%S %p')))
run_command('git pull', phlogdir, f)

if mode == 'complete':
    run_command('./phlogiston.py --initialize', phlogdir, f)

if mode == 'complete' or mode == 'incremental':
    run_command('rm phabricator_public.dump', homedir, f)
    run_command('wget -nv http://dumps.wikimedia.org/other/misc/phabricator_public.dump', homedir, f)
    run_command('./phlogiston.py --load --verbose', phlogdir, f)
    
if mode == 'complete':
    for project in args.projects:
        run_command('./phlogiston.py --reconstruct --report --verbose --project {0}_source.py'.format(project), phlogdir, f)
        
if mode == 'incremental':
    for project in args.projects:
        run_command('./phlogiston.py --reconstruct --incremental --report --verbose --project {0}_source.py'.format(project), phlogdir, f)
        
if mode == 'complete' or mode == 'incremental' or mode == 'reports':
    for project in args.projects:
        run_command('./phlogiston.py --report --verbose --project {0}_source.py'.format(project), phlogdir, f)

