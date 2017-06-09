JOB_DIR=/n/seage_lab/esurface/Calibration/simulations/Calibration
OUTPUT="$HOME/.${JOB_NAME}_output"
SACCT_ARGS="--name=pre_calibraiton" $HOME/scripts/job_report.sh $JOB_NAME $JOB_DIR > "$OUTPUT"
mail -s "CALIBRATION REPORT" esurface@hsph.harvard.edu < "$OUTPUT"
