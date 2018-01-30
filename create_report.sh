#!/bin/bash

usage() {
    echo "usage: create_report.sh [-adhn] <--name <name>> [--append <dir>] [--dir <dir>] [<job_id>,[job_id]]"
}

join_by() { 
local IFS="$1"; shift; echo "$*"; 
}

create_new() {
JOB_IDS=$IDS
JOB_DATE="$(date +%Y-%m-%dT%H:%M)"
cat << EOT > ${JOB_NAME}_report_config.sh
#!/usr/bin/env bash

JOB_NAME=$JOB_NAME
JOB_IDS=$JOB_IDS
JOB_DIR=$JOB_DIR
JOB_DATE=$JOB_DATE
OUTPUT="\$HOME/reports/.\${JOB_NAME}_output"

EOT

cat << EOT > ${JOB_NAME}_report.sh
#!/usr/bin/env bash

source $PWD/${JOB_NAME}_report_config.sh

if [[ -n \$JOB_DATE ]]; then
JOB_DATE_ARG="-S \${JOB_DATE}"
fi

\$HOME/reports/job_report.sh \$JOB_DATE_ARG --name=$JOB_NAME --jobs=\$JOB_IDS --array --dir \$JOB_DIR --verbose > "\$OUTPUT"
mail -s "$JOB_NAME REPORT" esurface@hsph.harvard.edu < "\$OUTPUT"

EOT

chmod 755 ${JOB_NAME}_report.sh

}

append_ids() {
source $REPORT
if [[ -z $JOB_IDS ]]; then
JOB_IDS=$IDS
else
JOB_IDS=$(echo $JOB_IDS,$IDS)
fi
#sort and unique the list of jobs
JOB_IDS=$(echo $JOB_IDS | tr , "\n" | sort | uniq | tr "\n" , ; echo )

cat << EOT > ${JOB_NAME}_report_config.sh
JOB_NAME=$JOB_NAME
JOB_IDS=$JOB_IDS
JOB_DIR=$JOB_DIR
JOB_DATE="$(date +%Y-%m-%dT%H:%M)"
OUTPUT="\$HOME/reports/.\${JOB_NAME}_output"

EOT

}

while test $# -gt 0
do
    case "$1" in
        -a|--append)
            APPEND=1
            shift
            if [ -z $1 ]; then
               usage
               exit 1
            fi
            REPORT=$1
            if [[ -z $REPORT ]]; then
                echo "$REPORT does not exist"
                usage
                exit 1
            fi
            ;;
        -d|--dir)
            shift
            if [ -z $1 ]; then
               usage
               exit 1
            fi
            JOB_DIR=$1
            ;;
        -h|--help)
            usage
            exit 1
            ;;
        -n|--name)
            shift
            if [ -z $1 ]; then
               usage
               exit 1
            fi
            JOB_NAME=$1
            ;;
        -*|--*)
            echo "Unknown Input $1"
            ;;
        *)
            IDS=($1)
            ;;
    esac
    shift
done

if [[ -z $APPEND && -z $JOB_NAME ]]; then
echo "No job name specified"
usage
exit 1
fi

#if [[ -z $JOB_IDS ]]; then
#echo "No jobs specified"
#usage
#exit 1
#fi

#if [[ ! $JOB_IDS =~ ^[:digit:]$ ]]; then
#echo "$JOB_IDS is not a properly formed slurm id"
#exit 1
#fi

if [[ -n $APPEND ]]; then
append_ids 
else
create_new 
fi
