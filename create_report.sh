#!/bin/bash

usage() {
    echo "usage: create_report.sh [-adhn] <--name <name>> [--append <dir>] [--dir <dir>] <job_id[,job_id]>"
}

create_config() {
JOB_IDS=$IDS
JOB_DATE="$(date +%Y-%m-%dT%H:%M)"
cat << EOT > ${BATCH_NAME}_report_config.sh
#!/usr/bin/env bash

BATCH_NAME=$BATCH_NAME
JOB_IDS=$JOB_IDS
JOB_DIR=$JOB_DIR
JOB_DATE=$JOB_DATE
OUTPUT="\$HOME/reports/.${BATCH_NAME}_output"

EOT
}

create_report() {

cat << EOT > ${BATCH_NAME}_report.sh
#!/usr/bin/env bash

source $PWD/${BATCH_NAME}_report_config.sh

if [[ -n \$JOB_DATE ]]; then
JOB_DATE_ARG="-S \${JOB_DATE}"
fi

\$HOME/job_submittion/slurm_mgr.sh \$JOB_DATE_ARG --name=$BATCH_NAME --jobs=\$JOB_IDS --array --dir \$JOB_DIR --verbose > "\$OUTPUT"
mail -s "$BATCH_NAME REPORT" esurface@hsph.harvard.edu < "\$OUTPUT"

EOT

chmod 755 ${BATCH_NAME}_report.sh

}

append_ids() {
    source $CONFIG
    if [[ -z $JOB_IDS ]]; then
        # Add the job ids env var if missing
        if [[ $(grep "JOB_IDS" $CONFIG) ]]; then
            sed -i "s/JOB_IDS=.*/JOB_IDS=${IDS}/" $CONFIG
        else
            echo "JOB_IDS=${IDS}" >> $CONFIG
        fi
    else
        # Add the job ids in sorted order
        JOB_IDS=$(echo $JOB_IDS,$IDS)
        JOB_IDS=$(echo $JOB_IDS | tr , "\n" | sort | uniq | tr "\n" , ; echo ) # sed 's/,$/\n/'
        sed -i "s/JOB_IDS=.*/JOB_IDS=${JOB_IDS}/" $CONFIG
    fi

    if [[ -z $JOB_DATE ]]; then
        # Add the job date if it is missing
        JOB_DATE="$(date +%Y-%m-%dT%H:%M)"
        if [[ $(grep "JOB_DATE" $CONFIG) ]]; then
            sed -i "s/JOB_DATE=.*/JOB_DATE=${JOB_DATE}/" $CONFIG
        else
            echo "JOB_DATE=${JOB_DATE}" >> $CONFIG
        fi
    fi

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
            CONFIG=$1
            if [[ -z $CONFIG ]]; then
                echo "$CONFIG does not exist"
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
            BATCH_NAME=$1
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

if [[ -z $APPEND ]] && [[ -z $BATCH_NAME ]]; then
echo "No job name specified"
usage
exit 1
fi

if [[ -z $IDS ]]; then
echo "No jobs specified"
usage
exit 1
fi

if [[ -z $JOB_DIR ]]; then
JOB_DIR=$PWD
fi

if [[ $IDS =~ [^[:digit:]$] ]]; then
    echo "$IDS is not a properly formed slurm id"
    exit 1
fi

if [[ -n $APPEND ]]; then
    append_ids 
else
    create_config
fi

if [[ ! -e ${BATCH_NAME}_report.sh ]]; then
   create_report
fi
