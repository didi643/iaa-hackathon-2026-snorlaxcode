#!/bin/zsh
# X14: per-peril severity blend picked by the 5-fold severity CV (sev_cv_x14_cv.csv)
cd "$(dirname "$0")/../.."
export DT_THREADS=1 OMP_WAIT_POLICY=passive
bl() { tag=$1; exp=$2; note=$3; shift 3
  ( export RUN_TAG=$tag "$@"
    Rscript week2/R/14_blend_severity.R > week2/run/logs/exp_${tag}_14.log 2>&1 &&
    Rscript week2/R/08_loadings_2025.R > week2/run/logs/exp_${tag}_08_loadings_2025.log 2>&1 &&
    Rscript week2/R/09_validate_compare.R > week2/run/logs/exp_${tag}_09_validate_compare.log 2>&1 &&
    RUN_A=$tag RUN_B=main EXP=$exp NOTE=$note Rscript week2/R/13_compare_runs.R 2>&1 | grep -v "^[0-9][0-9]:" ) > week2/run/logs/grid_$exp.txt 2>&1 }
bl x14e X14e_pick_z15_relevel "X14b (motor OD, glass, BI, contents EoW 50/50) relevelled to #2 per-peril totals" BLEND_B=x11e_ssel BLEND_W=0.5 BLEND_PERILS=motor/own_damage,motor/glass_hail,motor/bodily_injury,contents/escape_of_water BLEND_RELEVEL=1 &
bl x13r X13r_motor50_relevel "X13b (#3, all motor 50/50) relevelled to #2 per-peril totals" BLEND_B=x12a_msel BLEND_W=0.5 BLEND_LINES=motor BLEND_RELEVEL=1 &
bl x14f X14f_pick_shape_relevel "X14a (motor OD, glass) relevelled" BLEND_B=x11e_ssel BLEND_W=0.5 BLEND_PERILS=motor/own_damage,motor/glass_hail BLEND_RELEVEL=1 &
wait; echo GRID_DONE
