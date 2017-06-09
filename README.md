# Script to report information on jobs running on Odyssey

For more information run:
./job_report.sh --help

Example Output:
Finding jobs using: /usr/bin/sacct -j 89401538 -P --noheader
116 COMPLETED jobs
    Avg Run Time: 00:31:38
    Avg Wall Time: 00:33:44

57 FAILED jobs
Rerun these jobs:
112,119,137,180

0 TIMEOUT jobs
0 RUNNING jobs
0 PENDING jobs

Extention:
This script can be extended by making edits to the job_report_ext.sh script. This works as a pseudo-module and allows for not changing the main script. See ./examples/job_report_ext.sh

Crontab:
This script in conjunction with 'crontab' is helpful to track the progress of long-running
jobs or batches of jobs. Set this up by creating a script for crontab to call with the job
information attached. It will automatically mail the report to the logged-in user.

See ./examples/crontab_script.sh:
JOB_DIR=/n/seage_lab/esurface/Calibration/simulations/Calibration
OUTPUT="$HOME/.${JOB_NAME}_output"
SACCT_ARGS="--name=pre_calibraiton" $HOME/scripts/job_report.sh $JOB_DIR > "$OUTPUT"
mail -s "CALIBRATION REPORT" esurface@hsph.harvard.edu < "$OUTPUT"

Run crontab -e to edit crontab and add the following code: (more info: man crontab) 
0 8 * * *     ~/scripts/crontab_script.sh
