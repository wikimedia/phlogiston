#!/bin/bash
mode=""
projects=""

function show_help {
    echo "Usage: ./batch_phlog.bash -m [mode] -p [project1] -p [project2]" 
}

while getopts "h?m:p:" opt; do
    case "$opt" in
        h|\?)
           show_help
           exit 0
           ;;
        m) mode=$OPTARG
           ;;
        p) project_list+=("$OPTARG")
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

if [[ "$mode" == "complete" || "$mode" == "incremental" ]]
then
    cd ${HOMEDIR}
    echo "$(date): Downloading new Phabricator dump"
    rm phabricator_public.dump
    wget -nv http://dumps.wikimedia.org/other/misc/phabricator_public.dump
    cd ${PHLOGDIR}
    echo "$(date): Loading loading new Phabricator dump"
    time python3 phlogiston.py --load --verbose 2>&1
fi

cd ${PHLOGDIR}
case "$mode" in
    complete)
        for project in ${project_list[@]}; do
            echo "$(date): Starting complete reconstruction and report of ${project}"
            time python3 phlogiston.py --reconstruct --report --verbose --project ${project}_source.py 2>&1
            echo "$(date): Done with complete reconstruction and report of ${project}"
        done
        ;;
    incremental)
        for project in ${project_list[@]}; do
            echo "$(date): Starting incremental reconstruction and report of ${project}"
            time python3 phlogiston.py --reconstruct --incremental --report --verbose --project ${project}_source.py  2>&1
            echo "$(date): Done with incremental reconstruction and report of ${project}"
        done
        ;;
    rerecon)
        for project in ${project_list[@]}; do
            echo "$(date): Starting incremental reconstruction and report of ${project}"
            time python3 phlogiston.py --reconstruct --incremental --report --verbose --project ${project}_source.py  2>&1
            echo "$(date): Done with incremental reconstruction and report of ${project}"
        done
        ;;
    reports)
        for project in ${project_list[@]}; do
            echo "$(date): Starting report of ${project}"
            time python3 phlogiston.py --report --verbose --project ${project}_source.py  2>&1
            echo "$(date): Done with report of ${project}"
        done
esac
