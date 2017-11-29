#!/bin/bash 
# job_report.sh
# Script to report information on array jobs running on Odyssey
#

usage() {	
echo "usage: [SACCT_ARGS=args] job_report.sh [sacct_args] [--array] [--dir <job_dir>] [--verbose] 
 
 sacct_args: Add arguments for /usr/bin/sacct by passing arguments inline
	They can also be passed by setting SACCT_ARGS as an environment variable 
--array: Flag to signal that jobs to report on are from sbatch --array
--dir=dir: value should be the directory containing the .err and .out files generated by SLURM
 --verbose: Add this flag to see more information on failed runs
"
}

# source external scripts for additional functionality
source $HOME/reports/job_report_ext.sh

#### GLOBALS ####
SACCT=/usr/bin/sacct
SACCT_ARGS+=("-P --noheader") # Add required SACCT arguments for parsing

# Keep the format and indexes aligned
export SACCT_FORMAT='jobid,state,partition,submit,start,end'
JOBID=0		# Use to find the corresponding batch directory
STATE=1		# Job state
PARTITION=2	# Where is the job running?
SUBMIT=3	# Submit time
START=4		# Start time
END=5		# End time

#### Helper funtions for printing ####
pretty_print_tabs() {
# print a tab separated list of jobs in five columns	
	list=($@)
	
	count=1
	mod=5
	for l in ${list[@]}; do
		printf "\t$l"
		if (( $count % $mod == 0 )); then
			printf "\n"
		fi
		((count+=1))
	done
	printf "\n"
}

pretty_print_commas() {
# print a comma separated list of jobs
# helpful for knowing which jobs to rerun
	list=($@)

	count=0
	for l in ${list[@]}; do
		printf "$l"
		((count+=1))
		if (( $count < ${#list[@]} )); then
			printf ","
		fi
	done
	printf "\n"
}

print_sorted_jobs() {
# sort and print a list of jobs
	list=($@)

    sorted=( $(
		for l in ${list[@]}; do
			IFS='_' read -ra split <<< "$l"
			echo ${split[1]}
		done | sort -nu
		) )
	pretty_print_commas ${sorted[@]}
}

convertsecs() {
# convert value of seconds to a time
	((h=${1}/3600))
	((m=(${1}%3600)/60))
	((s=${1}%60))
	printf "%02d:%02d:%02d\n" $h $m $s
}

run_times() {
# use the SUBMIT, START, and END times from sacct to calculate
# average wall time and run time for a set of jobs
	runs=($@)

	sum_wall_time=0
	sum_elapsed=0
	for run in ${runs[@]}; do
		IFS='|' read -ra split <<< "$run"
		submit_=$(date --date=${split[$SUBMIT]} +%s )
		start_=$(date --date=${split[$START]} +%s )
		end_=$(date --date=${split[$END]} +%s )
		sum_elapsed=$(( sum_elapsed + $(( $end_ - $start_ )) ))
		sum_wall_time=$((sum_wall_time + $(( $end_ - $submit_ )) ))
	done

	avg_elapsed=$(($sum_elapsed / ${#runs[@]}))
	avg_wall_time=$(($sum_wall_time / ${#runs[@]}))

	echo "	Avg Run Time: $(convertsecs $avg_elapsed)"
	echo "	Avg Wall Time: $(convertsecs $avg_wall_time)"
}

#### Run STATE handler functions ####

handle_completed() {
	runs=($@)

	if [ $VERBOSE -eq 1 ]; then
	run_times ${runs[@]}
	#_ext_handle_passed_and_failed ${runs[@]}
	echo ""
	fi	
	
}

handle_failed() {
	runs=($@)

	output_dir=$WORK_DIR
	prefix=batch_

	list=()
	for run in ${runs[@]}; do
		IFS='|' read -ra split <<< "$run"
		jobid=${split[$JOBID]}
		list+=($jobid)
	
		if [ $VERBOSE -eq 1 ]; then
			output_errs="$output_dir/$prefix$jobid.err"
			printf "	Job $jobid Failed:\t"
			if [ -e $output_errs ]; then
				echo "	$(cat $output_errs)"
			else
				echo "	Output removed"
			fi
		fi
	done

	echo "Rerun these jobs:"
	if [ $ARRAY -eq 1 ]; then
		print_sorted_jobs ${list[@]}
	else
		pretty_print_tabs ${list[@]}
	fi

	echo ""
}

handle_running() {
	runs=($@)

	list=()	
	for run in ${runs[@]}; do
		IFS='|' read -ra split <<< "$run"
		list+=(${split[$JOBID]})
	done

	if [ $VERBOSE -eq 1 ]; then
	echo "Running jobs: "
	pretty_print_tabs ${list[@]}
	fi

	echo ""
}

handle_other() {
	runs=($@)

	list=()	
	for run in ${runs[@]}; do
		IFS='|' read -ra split <<< "$run"
		jobid=${split[$JOBID]}
		state=${split[$STATE]}
		list+=("$jobid: $state")
	done
	pretty_print_tabs ${list[@]}
}

#### MAIN ####

ARRAY=0
WORK_DIR=$PWD
VERBOSE=0
while test $# -gt 0
do
    case "$1" in
        --array) 	
			ARRAY=1
            ;;
        --dir)
			shift
			if [ -z $1 ]; then
				usage
				exit 1
			fi
			WORK_DIR=$1
			;;
        --help)
			usage
			exit 1
			;;
        --verbose) 	
			VERBOSE=1
            ;;
        *)
			SACCT_ARGS+=($1)
            ;;
    esac
    shift
done

COMPLETED=()
FAILED=()
TIMEOUT=()
RUNNING=()
PENDING=()
OTHER=()

echo "Finding jobs using: $SACCT ${SACCT_ARGS[@]}"
all=$($SACCT ${SACCT_ARGS[@]})

if [[ ${#all[@]} = 0 ]]; then
	echo "No jobs found with the name '$1'"
	exit 1
fi

for run in ${all[@]}; do
    if [[ $run = *"batch"* ]]; then
        continue
    elif [[ $run = *"extern"* ]]; then
        continue
    else # process non-extern/batch jobs
    	IFS='|' read -ra split <<< "$run" # split the sacct line by '|'
        state=${split[$STATE]}
        if [[ $state = "COMPLETED" ]]; then
               COMPLETED+=($run)
        elif [[ $state = "FAILED" ]]; then
               FAILED+=($run)
        elif [[ $state = "TIMEOUT" ]]; then
               TIMEOUT+=($run)
        elif [[ $state = "RUNNING" ]]; then
               RUNNING+=($run)
        elif [[ $state = "PENDING" ]]; then
               PENDING+=($run)
        else
               OTHER+=($run)
        fi
    fi
 
done

echo "${#COMPLETED[@]} COMPLETED jobs"
if [[ ${#COMPLETED[@]} > 0 && $VERBOSE -eq 1 ]]; then
    handle_completed ${COMPLETED[@]}
fi

echo "${#FAILED[@]} FAILED jobs"
if [[ ${#FAILED[@]} > 0 && $VERBOSE -eq 1 ]]; then
	handle_failed ${FAILED[@]}
fi

echo "${#TIMEOUT[@]} TIMEOUT jobs"
if [[ ${#TIMEOUT[@]} > 0 && $VERBOSE -eq 1 ]]; then
    handle_failed ${TIMEOUT[@]}
fi

echo "${#RUNNING[@]} RUNNING jobs"
if [[ ${#RUNNING[@]} > 0 && $VERBOSE -eq 1 ]]; then
    handle_running ${RUNNING[@]}
fi

echo "${#PENDING[@]} PENDING jobs"

if [[ ${#OTHER[@]} > 0 ]]; then
	echo "${#OTHER[@]} jobs  with untracked status"
	if [[ $VERBOSE -eq 1 ]]; then
		handle_other ${OTHER[@]}
	fi
fi

exit 0
