#!/bin/bash
# job_report_ext.sh
# Script to extend job_report.sh
#
# Use this script to add funtionality to the job_report script

_ext_handle_passed_and_failed() {
    runs=($@)
    num_runs=${#runs[@]}

    output_dir=$WORK_DIR
    prefix=batch_

    passed=()
    passed_runs=()
    failed_checks=()
    failed_incidence=()
    failed=()
    for run in ${runs[@]}; do
		IFS='|' read -ra split <<< "$run" 
        jobid=${split[$JOBID]}
        str=$(cat "$output_dir/$prefix$jobid.err")
        if [[ "$str" = *"PARTNERSHIP CALIBRATION PASSED: true"* ]]; then
            str_1=$(cat "$output_dir/$prefix$jobid.out")
            if [[ "$str_1" = *"INCIDENCE CALIBRATION FAILED"* ]]; then
                failed_incidence+=($run)
            else
                passed+=($jobid)
                passed_runs+=($run)
            fi
        elif [[ "$str" = *"PARTNERSHIP CALIBRATION PASSED: false"* ]]; then
            failed_checks+=($run)
            failed+=($jobid)
        fi
    done

    if [ ${#failed_checks[@]} -gt 0 ]; then
        printf "Failed Checks: ${#failed_checks[@]} jobs"
        printf ' @ %.1f%%\n' "$(echo "scale=2; 100 * ${#failed_checks[@]} / $num_runs" | bc)" 
        run_times ${failed_checks[@]}
        if [ $ARRAY -eq 1 ]; then
            print_sorted_jobs ${failed[@]}
        fi
    fi
    
    if [ ${#failed_incidence[@]} -gt 0 ]; then
        printf "Failed Incidence: ${#failed_incidence[@]} jobs"
        printf ' @ %.1f%%\n' "$(echo "scale=2; 100 * ${#failed_incidence[@]} / $num_runs" | bc)"
        run_times ${failed_incidence[@]}
    fi
    
    if [ ${#passed[@]} -gt 0 ]; then
        printf "Passed Calibration: ${#passed[@]} jobs"
        printf ' @ %.1f%%\n' "$(echo "scale=2; 100 * ${#passed[@]} / $num_runs" | bc)"
        run_times ${passed_runs[@]}
        if [ $ARRAY -eq 1 ]; then
            print_sorted_jobs ${passed[@]}
        fi
    fi
}
