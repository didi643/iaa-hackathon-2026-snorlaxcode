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
bl x14a X14a_pick_shape "50/50 sev blend on CV shape winners (z_mix and z_mixrl > 2): motor OD, glass" BLEND_B=x11e_ssel BLEND_W=0.5 BLEND_PERILS=motor/own_damage,motor/glass_hail &
bl x14b X14b_pick_z15 "50/50 sev blend on CV z_mix > 1.5 shape-led: motor OD, glass, BI, contents EoW" BLEND_B=x11e_ssel BLEND_W=0.5 BLEND_PERILS=motor/own_damage,motor/glass_hail,motor/bodily_injury,contents/escape_of_water &
bl x14c X14c_pick_z15_sub "as X14b + buildings subsidence" BLEND_B=x11e_ssel BLEND_W=0.5 BLEND_PERILS=motor/own_damage,motor/glass_hail,motor/bodily_injury,contents/escape_of_water,buildings/subsidence &
bl x14d X14d_pick_shape_w75 "X14a with blend weight 0.75 on emerging" BLEND_B=x11e_ssel BLEND_W=0.75 BLEND_PERILS=motor/own_damage,motor/glass_hail &
wait; echo GRID_DONE
