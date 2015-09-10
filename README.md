# phab_task_history

## Purpose:
Generate burnup, cycle time, and other charts from Phabricator.  Intended for experimental prototyping and proof of concept for similar functionality to built into Phabricator.  Also a platform to do complex scripted data handling for Phab projects prior to reporting.

## Typical usage:
```
wget http://dumps.wikimedia.org/other/misc/phabricator_public.dump
cd phab_task_history
./load_transactions_from_dump.py --load --reconstruct --report --project ve_source.py
```

## Environment:
```
foo/                              <- dump goes here
foo/phab_task_history/            <- program goes here
/tmp/                             <- PNG output goes here
Postgresql database named "phab"  <- data goes here
```

## Installation Notes:

1. Get an account and shell access on WMF Labs with Ubuntu 14.04 host
2. Install prerequisites on the system.  As root:
  1. Follow instructions to add Postgresql backport to get 9.4: http://www.postgresql.org/download/linux/ubuntu/
  2. Get access to newer R
     * ```echo deb http://cran.es.r-project.org/bin/linux/ubuntu trusty/ > /etc/apt/sources.list.d/r.list
       gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9
       gpg -a --export E084DAB9 | sudo apt-key add -```
  3. Install ubuntu packages
     * ```apt-get install nginx postgresql-9.4 python3-pip python3-psycopg2 python3-dev
    apt-get build-dep python3-psycopg2 r-base-core r-base-script```
  4. Install R packages.
     * ```R
       install.packages(c("ggplot2"))
       quit()```
3. Set up database.
   1. As user postgres,
     * `createuser -s phlogiston`
   2. As user phlogiston,
     * `createdb phab`
4. Install virtualenv and packages.  As phlogiston, 
     * ```pip3 install virtualenv
   pip3 install psycopg2```
5. Run this script.  As phlogiston:
     * ```virtualenv phlab
   source phlab/bin/activate```

