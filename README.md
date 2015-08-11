# phab_task_history

Purpose:
Generate burnup, cycle time, and other charts from Phabricator.  Intended for experimental prototyping and proof of concept for similar functionality to built into Phabricator.  Also a platform to do complex scripted data handling for Phab projects prior to reporting.

Typical usage:
```
wget http://dumps.wikimedia.org/other/misc/phabricator_public.dump
cd phab_task_history
./load_transactions_from_dump.py --load --reconstruct --report --project ve_source.py
```

Environment:
```
~/foo/                              <- dump goes here
~/foo/phab_task_history/            <- program goes here
/tmp/                               <- PNG output goes here
Postgresql database named "phab"    <- data goes here
```
