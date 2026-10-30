#!/bin/zsh
# run_cred.sh <tag> [ENV=VAL ...] : X19 credibility experiment on the full final-model chain (build_final.sh with step 7 changed):
#   7 (<tag>_core, motor frequency trend floor) -> 14 (blend with fin_sevem on the four CV-picked perils, relevelled) -> 8 -> 9,
#   then gate vs REF (default final = submission #5). SKIP7=1 reuses an existing <tag>_core (e.g. written by 18_cred_select.R).
tag=$1; shift
cd "$(dirname "$0")/../.."
export DT_THREADS=1 OMP_WAIT_POLICY=passive TREND_FLOOR_FREQ=motor
for kv in "$@"; do export "$kv"; done
L=week2/run/logs
run() { Rscript week2/R/$1.R > $L/cred_${tag}_$1.log 2>&1 || { echo "FAILED $1"; tail -5 $L/cred_${tag}_$1.log; exit 1; } }
[ "$SKIP7" = "1" ] || RUN_TAG=${tag}_core run 07_emerging_adjust
RUN_TAG=$tag BLEND_A=${tag}_core BLEND_B=fin_sevem BLEND_W=${BLEND_W:-0.5} BLEND_RELEVEL=1 \
  BLEND_PERILS=motor/own_damage,motor/glass_hail,motor/bodily_injury,contents/escape_of_water run 14_blend_severity
RUN_TAG=$tag run 08_loadings_2025
RUN_TAG=$tag run 09_validate_compare
RUN_A=$tag RUN_B=${REF:-final} EXP=${EXP:-$tag} NOTE="$NOTE" Rscript week2/R/13_compare_runs.R > $L/cred_${tag}_13.log 2>&1
grep -A3 "experiment" $L/cred_${tag}_13.log | head -4
