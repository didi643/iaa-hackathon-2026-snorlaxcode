#!/bin/zsh
# X13: geometric severity blend, developed-shape (main) x emerging-only GLM (x12a_msel motor; x11e_ssel all lines)
cd "$(dirname "$0")/../.."
export DT_THREADS=1 OMP_WAIT_POLICY=passive
bl() { tag=$1; exp=$2; note=$3; shift 3
  ( export RUN_TAG=$tag "$@"
    Rscript week2/R/14_blend_severity.R > week2/run/logs/exp_${tag}_14.log 2>&1 &&
    Rscript week2/R/08_loadings_2025.R > week2/run/logs/exp_${tag}_08_loadings_2025.log 2>&1 &&
    Rscript week2/R/09_validate_compare.R > week2/run/logs/exp_${tag}_09_validate_compare.log 2>&1 &&
    RUN_A=$tag RUN_B=main EXP=$exp NOTE=$note Rscript week2/R/13_compare_runs.R 2>&1 | grep -v "^[0-9][0-9]:" ) > week2/run/logs/grid_$exp.txt 2>&1 }
bl x13a X13a_blend_m25 "sev blend w 0.25 emerging GLM, motor" BLEND_B=x12a_msel BLEND_W=0.25 BLEND_LINES=motor &
bl x13b X13b_blend_m50 "sev blend w 0.50 emerging GLM, motor" BLEND_B=x12a_msel BLEND_W=0.5 BLEND_LINES=motor &
bl x13c X13c_blend_m75 "sev blend w 0.75 emerging GLM, motor" BLEND_B=x12a_msel BLEND_W=0.75 BLEND_LINES=motor &
bl x13d X13d_blend_all50 "sev blend w 0.50 emerging GLM, all lines" BLEND_B=x11e_ssel BLEND_W=0.5 BLEND_LINES=motor,buildings,contents &
bl x13e X13e_blend_all25 "sev blend w 0.25 emerging GLM, all lines" BLEND_B=x11e_ssel BLEND_W=0.25 BLEND_LINES=motor,buildings,contents &
wait; echo GRID_DONE
