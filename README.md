# phab_task_history

# generate a csv file with one row per task per day for VE-related projects, collapsing multi-project tasks to belong to just one project

time python3 load_transactions_from_dump.py --report --verbose --project PHID-PROJ-ly2ydkopj6mc3byztenf,PHID-PROJ-nz5zs2camiseltyuemsj,PHID-PROJ-e5pkst3uyzpxifwwj7qb,PHID-PROJ-dafezmpv6huxg3taml24 --output phab_20150702.csv
