#!/bin/zsh
# run_exp.sh <tag> [ENV=VAL ...] : step 7 -> 8 -> 9 for one experiment tag, then gate it against $REF (default main)
# Used for the week 2 improvement round; every run is logged by the scripts in week2/run/logs and week2/docs/optionB/experiment_log.csv
tag=$1; shift
export DT_THREADS=1 OMP_WAIT_POLICY=passive RUN_TAG=$tag
for kv in "$@"; do export "$kv"; done
for s in 07_emerging_adjust 08_loadings_2025 09_validate_compare; do
  Rscript week2/R/$s.R > week2/run/logs/exp_${tag}_$s.log 2>&1 || { echo "FAILED $s"; tail -5 week2/run/logs/exp_${tag}_$s.log; exit 1; }
done
if [ "$tag" != "main" ]; then RUN_A=$tag RUN_B=${REF:-main} EXP=${EXP:-$tag} NOTE="$NOTE" Rscript week2/R/13_compare_runs.R 2>&1 | grep -v "^[0-9][0-9]:"; fi
