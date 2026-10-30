#!/bin/zsh
# X18: motor frequency trend floored at 0 (own damage was -5%/yr, TPP -3.4%/yr), on the #4 (x14e) basis. Gate vs sub4
cd "$(dirname "$0")/../.."
export DT_THREADS=1 OMP_WAIT_POLICY=passive
L=week2/run/logs
blend4() { RUN_TAG=$1 BLEND_A=$2 BLEND_B=x11e_ssel BLEND_W=0.5 BLEND_PERILS=motor/own_damage,motor/glass_hail,motor/bodily_injury,contents/escape_of_water BLEND_RELEVEL=1 Rscript week2/R/14_blend_severity.R > $L/exp_$1_14.log 2>&1 }
s89() { RUN_TAG=$1 TREND_FLOOR_FREQ=$2 Rscript week2/R/08_loadings_2025.R > $L/exp_$1_08_loadings_2025.log 2>&1 && RUN_TAG=$1 Rscript week2/R/09_validate_compare.R > $L/exp_$1_09_validate_compare.log 2>&1 }
gate() { RUN_A=$1 RUN_B=sub4 EXP=$2 NOTE=$3 Rscript week2/R/13_compare_runs.R 2>&1 | grep -v "^[0-9][0-9]:" > $L/grid_$2.txt }
# X18a: floor in the 2024 -> 2025 projection only (step 8); steps 7 and the fold are #4's
( blend4 x18a main && s89 x18a motor && gate x18a X18a_motor_floor_proj "#4 + motor freq trend floor 0 in the 2025 projection only" ) &
# X18b: floor everywhere (step 7 fit and 2024 projection, step 8 2025 projection)
( RUN_TAG=x18b7 TREND_FLOOR_FREQ=motor Rscript week2/R/07_emerging_adjust.R > $L/exp_x18b7_07.log 2>&1 && blend4 x18b x18b7 && s89 x18b motor && gate x18b X18b_motor_floor_all "#4 + motor freq trend floor 0 in step 7 fit and step 8 projection" ) &
wait; echo GRID_DONE
