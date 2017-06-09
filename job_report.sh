#!/bin/bash 
# calibration_mgmt.sh
# Script to watch calibration jobs running on Odyssey
#
# usage: calibration_mgmt.sh <jobname>

#### GLOBALS ####
SACCT=/usr/bin/sacct
ARGS=("-P --noheader") 	# SACCT arguments required for parsing
ARGS+=($SACCT_ARGS)		# SACCT arguments from env

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
# print second value of jobid, e.g. 80384829_141,80384829_224 => 141,224
	list=($@)

	for l in ${list[@]}; do
		printf "$l,"
	done
	printf "\n"
}

print_sorted_jobs() {
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
	((h=${1}/3600))
	((m=(${1}%3600)/60))
	((s=${1}%60))
	printf "%02d:%02d:%02d\n" $h $m $s
}

# process completed runs
run_times() {
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

	output_dir=$WORK_DIR/output
	prefix=batch_

	run_times ${runs[@]}
	
	passed=()
	passed_runs=()
	failed=()
	failed_runs=()
	for run in ${runs[@]}; do
		IFS='|' read -ra split <<< "$run"
		jobid=${split[$JOBID]}
		str=$(cat "$output_dir/$prefix$jobid.err")
		if [ "$str" = "" ]; then
			continue
		fi
		if [ "$str" = "PARTNERSHIP CALIBRATION PASSED: true" ]; then
			passed+=($jobid)
			passed_runs+=($run)
		else
			failed+=($jobid)
			failed_runs+=($run)
		fi
	done

	echo "Passed Calibration: ${#passed[@]}"
	if [ ${#passed[@]} -gt 0 ]; then
		pretty_print_tabs ${passed[@]}
		run_times ${passed_runs[@]}
	fi

	echo "Failed Calibration: ${#failed[@]}"
	if [ ${#failed[@]} -gt 0 ]; then
		run_times ${failed_runs[@]}
		printf 'Pass/Fail Ratio: %.2f\n' "$(echo "scale=2;${#passed[@]} / ${#failed[@]}" | bc)"
	fi

	echo ""
}

handle_failed() {
	runs=($@)

	output_dir=$WORK_DIR/output
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
	print_sorted_jobs ${list[@]}

	echo ""
}

handle_running() {
	runs=($@)

	list=()	
	for run in ${runs[@]}; do
		IFS='|' read -ra split <<< "$run"
		list+=(${split[$JOBID]})
	done

	echo "Running jobs: "
	pretty_print_tabs ${list[@]}

	echo ""
}

run_batch() {
	echo "run_batch() $JOB_NAME $WORK_DIR"
	return

	cd $WORK_DIR
	sbatch $JOB_NAME --array=$BATCH_RANGE ./run_trans_model_batches.sh ./batches/$BATCH_PREFIX$batch

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
if [ $# -lt 1 ]; then
	echo "usage: calibraiton_mgmt.sh <job_name,job_name,...> [job_dir] [--verbose]"
	echo "job_name list must output to the same job_dir"
	echo "Define SACCT_ARGS to add more sacct parameters"
	exit 1
fi

JOB_NAMES_ARG="--name=$1"

if [ -z $2 ]; then
WORK_DIR=$PWD
else
WORK_DIR=$2
fi

VERBOSE=0
while test $# -gt 0
do
    case "$1" in
        --verbose) 	
			echo "$1" 
			VERBOSE=1
            ;;
        --*) echo "bad option $1"
            ;;
        *) 
            ;;
    esac
    shift
done

# Get the list of runs with the name $2 
echo "Finding jobs using: $SACCT ${ARGS[@]} $JOB_NAMES_ARG"

COMPLETED=()
FAILED=()
TIMEOUT=()
RUNNING=()
PENDING=()
OTHER=()

all=$($SACCT ${ARGS[@]} $JOB_NAMES_ARG)
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
		if [ ${split[$STATE]} = "COMPLETED" ]; then
			COMPLETED+=($run)
		elif [ ${split[$STATE]} = "FAILED" ]; then
			FAILED+=($run)
		elif [ ${split[$STATE]} = "TIMEOUT" ]; then
			TIMEOUT+=($run)
		elif [ ${split[$STATE]} = "RUNNING" ]; then
			RUNNING+=($run)
		elif [ ${split[$STATE]} = "PENDING" ]; then
			PENDING+=($run)
		else
			OTHER+=($run)
		fi
    fi
done

echo "${#COMPLETED[@]} COMPLETED jobs"
if [[ ${#COMPLETED[@]} > 0 ]]; then
    handle_completed ${COMPLETED[@]}
fi

echo "${#FAILED[@]} FAILED jobs"
if [[ ${#FAILED[@]} > 0 ]]; then
	handle_failed ${FAILED[@]}
fi

echo "${#TIMEOUT[@]} TIMEOUT jobs"
if [[ ${#TIMEOUT[@]} > 0 ]]; then
    handle_failed ${TIMEOUT[@]}
fi

echo "${#RUNNING[@]} RUNNING jobs"
if [[ ${#RUNNING[@]} > 0 ]]; then
    handle_running ${RUNNING[@]}
fi

echo "${#PENDING[@]} PENDING jobs"

if [[ ${#OTHER[@]} > 0 ]]; then
	echo "${#OTHER[@]} jobs  with untracked status"
	handle_other ${OTHER[@]}
fi

exit 0
