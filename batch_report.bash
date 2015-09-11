#!/bin/bash
rm phabricator_public.dump
wget http://dumps.wikimedia.org/other/misc/phabricator_public.dump
cd ~/phab_task_history
cd phab_task_history
python3 load_transactions_from_dump.py --load 
python3 load_transactions_from_dump.py --reconstruct --report --project ve_source.py 
python3 load_transactions_from_dump.py --reconstruct --report --project and_source.py 
python3 load_transactions_from_dump.py --reconstruct --report --project ios_source.py 
python3 load_transactions_from_dump.py --reconstruct --report --project an_source.py 
