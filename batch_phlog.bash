#!/bin/bash
mode=""
source_list=""

function show_help {
    echo "Usage: ./batch_phlog.bash -m mode -s scope [-s scope]" 
}

while getopts "h?m:s:" opt; do
    case "$opt" in
        h|\?)
           show_help
           exit 0
           ;;
        m) mode=$OPTARG
           ;;
        s) source_list+=("$OPTARG")
           ;;
    esac
done

if [[ "$mode" == report ]]
then
    mode="reports"
fi

if ! [[ "$mode" == "complete" || "$mode" == "incremental" || "$mode" == "reports" || "$mode" == "rerecon" ]]
then
   echo "Mode must be complete, incremental, or report[s]"
   exit -1
fi
   
PHLOGDIR=$HOME/phlogiston

echo "$(date): Starting"
echo "$(date): Git Pull"
cd ${PHLOGDIR}
git pull

function load_dump {
    echo "$(date): Downloading new Phabricator dump"
    cd ${HOMEDIR}
    rm phabricator_public.dump
    wget -nv http://dumps.wikimedia.org/other/misc/phabricator_public.dump
    echo "$(date): Loading loading new Phabricator dump"
    cd ${PHLOGDIR}
    python3 -u phlogiston.py --load --verbose 2>&1
}

case "$mode" in
    complete)
        load_dump
        reconstruct_flag="--reconstruct"
        action="Complete Reconstruction and Report"
        ;;
    incremental)
        load_dump
        reconstruct_flag="--reconstruct --incremental"
        action="Incremental Reconstruction and Report"
        ;;
    rerecon)
        reconstruct_flag="--reconstruct"
        action="Complete Reconstruction and Report"
        ;;
    reports)
        reconstruct_flag=""
        action="Report"
        ;;
esac

cd ${PHLOGDIR}
for scope in ${scope_list[@]}; do
    echo "$(date): Starting ${action} for ${scope}"
    python3 -u phlogiston.py ${reconstruct_flag} --report --verbose --scope_prefix ${scope} 2>&1
    echo "$(date): Done with ${action} for ${scope}"
done
