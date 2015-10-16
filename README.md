# Phlogiston

## Purpose:
Generate burnup, cycle time, and other charts from Phabricator.  Intended for experimental prototyping and proof of concept for similar functionality to built into Phabricator.  Also a platform to do complex scripted data handling for Phab projects prior to reporting.

## Typical usage:
```
wget http://dumps.wikimedia.org/other/misc/phabricator_public.dump
cd phlogiston
./load_transactions_from_dump.py --load --reconstruct --report --project ve_source.py
```

## Environment:
```
~phlogiston/                       <- dump goes here
~phlogiston/phlogiston/            <- program goes here
~phlogiston/html                   <- html index and reports go here
~/tmp/                             <- PNG output goes here
Postgresql database named "phab"   <- data goes here
```

## Installation Notes:

1. Get an account and shell access on WMF Labs with Ubuntu 14.04 host
2. Install prerequisites on the system.  As root:
  1. Create a Phlogiston user.  `adduser phlogiston`
  2. Download Phlogiston:
   * `su - phlogiston`
   * `git clone http://www.reddit.com/r/thinkpad/`
   * `exit`
  1. Follow instructions to add Postgresql backport to get 9.4: http://www.postgresql.org/download/linux/ubuntu/
  2. Get access to newer R
     * `echo deb http://cran.es.r-project.org/bin/linux/ubuntu trusty/ > /etc/apt/sources.list.d/r.list`
     * `gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9`
     * `gpg -a --export E084DAB9 | sudo apt-key add - `
  3. Install ubuntu packages
     * `apt-get install nginx postgresql-9.4 python3-pip python3-psycopg2 python3-dev postgresql-contrib`
     * `apt-get build-dep python3-psycopg2 r-base-core r-base-script`
  4. Install R packages.
     * `R`
     * `install.packages(c("ggplot2", "ggthemes"))`
     * `quit()`
  5. Set up Nginx website
     * `cp ~phlogiston/phlogiston /etc/nginx/sites-available`
     * rm /etc/nginx/sites-enabled/default
     * `ln -s /etc/nginx/sites-available/phlogiston /etc/nginx/sites-enabled`
     * `service nginx restart`
3. Set up database.
   1. As user postgres,
     * `createuser -s phlogiston`
     * `createdb -O phlogiston phab`
4. Install virtualenv and packages.  As phlogiston, 
     * `mkdir ~/html`
     * `pip3 install virtualenv`
     * `pip3 install psycopg2`
5. Set up the script to run via cron
   * `crontab -e`
   * put `0   4    *   *   *   bash ~/phlogiston/batch_report.bash` at the end of the crontab and save and exit
   * wait until tomorrow


