# phab_task_history

Typical usage:
'''
wget http://dumps.wikimedia.org/other/misc/phabricator_public.dump
cd phab_task_history
./load_transactions_from_dump.py --load --reconstruct --report --project ve_source.py
'''

Environment:
'''
~/foo                              <- dump goes here
~/foo/phab_task_history            <- program goes here
/tmp                               <- PNG output goes here
Postgresql database named "phab"   <- data goes here
'''
