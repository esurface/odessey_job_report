#!/bin/bash
# job_report_ext.sh
# Script to extend job_report.sh
#
# Use this script to add funtionality to the job_report script

_ext_handle_passed_and_failed() {
    runs=($@)

    output_dir=$WORK_DIR
    prefix=batch_

    passed=()
    passed_runs=()
    failed=()
    failed_runs=()
    for run in ${runs[@]}; do
		IFS='|' read -ra split <<< "$run" 
        jobid=${split[$JOBID]}
        str=$(cat "$output_dir/$prefix$jobid.err")
        if [[ "$str" = *"PARTNERSHIP CALIBRATION PASSED: true"* ]]; then
            passed+=($jobid)
            passed_runs+=($run)
        elif [[ "$str" = *"PARTNERSHIP CALIBRATION PASSED: false"* ]]; then
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

}
