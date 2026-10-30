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
bl x17a X17a_tpp_flat "motor TPP severity flat (emerging mean shape), relevelled to #2's TPP total" BLEND_B=x11d_sflat BLEND_W=1 BLEND_PERILS=motor/third_party_prop BLEND_RELEVEL=1 &
bl x17b X17b_tpp_half "motor TPP severity half-flattened (50/50), relevelled" BLEND_B=x11d_sflat BLEND_W=0.5 BLEND_PERILS=motor/third_party_prop BLEND_RELEVEL=1 &
bl x17c X17c_weak_flat "half-flattened severity for perils with CV severity D2 < 0.005 (motor TPP, buildings AD, contents AD), relevelled" BLEND_B=x11d_sflat BLEND_W=0.5 BLEND_PERILS=motor/third_party_prop,buildings/accidental_damage,contents/accidental_damage BLEND_RELEVEL=1 &
wait; echo GRID_DONE
