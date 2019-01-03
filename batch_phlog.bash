#!/bin/bash
mode=""
scope_list=""
load=""

function show_help {
    echo """Usage: ./batch_phlog.bash -m mode -l load -s scope [-s scope]

mode must be one of:
  * reconstruct: Reconstruct the complete history of all specified scopes.  Also report on each one.  Could take hours per scope.
  * incremental: Reconstruct new history for specified scopes based on the dates in the data.  Also report on each one.  Usually takes less than an hour per scope.
  * reports: Report on each specified scope.

load must be one of:
  * true:  Download a fresh database dump and load it into Phlogiston for use in reconstructions.  Takes an hour.
  * false:  Don't.

scope must match the name of a *scope*_scope.py and *scope*_recategorization.csv file
"""
}

function load_dump {
    echo "$(date): Downloading new Phabricator dump"
    cd ${HOMEDIR}
    rm phabricator_public.dump
    wget -nv http://dumps.wikimedia.org/other/misc/phabricator_public.dump
    echo "$(date): Loading loading new Phabricator dump"
    cd ${PHLOGDIR}
    python3 -u phlogiston.py --load --verbose 2>&1
}

while getopts "h?l:m:s:" opt; do
    case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        l) load=$OPTARG
            ;;
        m) mode=$OPTARG
            ;;
        s) scope_list+=("$OPTARG")
            ;;
    esac
done

if ! [[ "$mode" == "reconstruct" || "$mode" == "incremental" || "$mode" == "reports" ]]
then
    echo "Mode must be reconstruct, incremental, or reports"
    exit -1
fi

if ! [[ "$load" == "true" || "$load" == "false" ]]
then
    echo "Load must be true or false."
    exit -1
fi

if [[ "$mode" == "reports" && "$load" == "true" ]]
then
    echo "Doing a fresh load will not affect reports, so you probably don't want to do this and waste an hour.  To get new data into reports, you must load and reconstruct"
    exit -1
fi

PHLOGDIR=$HOME/phlogiston

echo "$(date): Entering phlogiston python virtual environment"
source ~/p_env/bin/activate
echo "$(date): Git Pull"
cd ${PHLOGDIR}
git pull

if [[ "$load" == "true" ]]
then
    load_dump
fi

case "$mode" in
    reconstruct)
        reconstruct_flag="--reconstruct"
        action="Complete Reconstruction and Report"
        ;;
    incremental)
        reconstruct_flag="--reconstruct --incremental"
        action="Incremental Reconstruction and Report"
        ;;
    reports)
        reconstruct_flag=""
        action="Report"
        ;;
esac

cd ${PHLOGDIR}
for scope in ${scope_list[@]}; do
    start_datetime=`date '+%s'`
    echo "$(date): Starting ${action} for ${scope}"
    python3 -u phlogiston.py ${reconstruct_flag} --report --verbose --scope_prefix ${scope} 2>&1
    end_datetime=`date '+%s'`
    let duration=end_datetime-start_datetime
    minutes=$((duration/60))

    echo "$(date) : Done with ${action} for ${scope}.  ${minutes} minutes total."
done
