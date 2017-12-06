#!/bin/bash

usage() {
    echo "usage: create_report.sh [-adhn] [--append <dir>] [--dir <dir>] <--name <name>> [<job_id>,[job_id]]"
}

create_new() {
cat << EOT >> ${JOB_NAME}_report.sh
JOB_NAME="$JOB_NAME"
JOB_DIR=$JOB_DIR
JOB_IDS="--jobs=$JOB_IDS"
JOB_DATE="-S $(date +%Y-%m-%dT%H:%M)"
OUTPUT="\$HOME/reports/.\${JOB_NAME}_output"
\$HOME/reports/job_report.sh $JOB_DATE --name=\$JOB_NAME \$JOB_IDS --array --dir \$JOB_DIR --verbose > "\$OUTPUT"
mail -s "\$JOB_NAME REPORT" esurface@hsph.harvard.edu < "\$OUTPUT"

EOT

chmod 755 ${JOB_NAME}_report.sh

}

append_ids() {
echo 'not implemented'
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
        *)
            JOB_IDS=($1)
            ;;
    esac
    shift
done

if [[ -z $JOB_NAME ]]; then
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

if [[ -e $APPEND ]]; then
append_ids $REPORT $JOB_IDS
else
create_new $JOB_IDS $JOB_NAME $JOB_DIR
fi
