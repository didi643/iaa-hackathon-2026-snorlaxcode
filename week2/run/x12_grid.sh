#!/bin/zsh
# X12: emerging-only severity for motor only (X11 showed motor gains, property losses)
cd "$(dirname "$0")/../.."
run() { EXP=$1 NOTE=$2 zsh week2/run/run_exp.sh "${@:3}" > week2/run/logs/grid_$1.txt 2>&1 }
run X12a_motor_sevsel "sev = emerging GLM greedy (3 steps), motor only" x12a_msel SEV_MODE=em_select SEV_LINES=motor &
run X12b_motor_sevsel5 "sev = emerging GLM greedy (5 steps), motor only" x12b_msel5 SEV_MODE=em_select SEV_LINES=motor EM_SEV_STEPS=5 &
run X12c_motor_sevrich "sev = emerging GLM for motor perils >= 1000 claims, flat others" x12c_mrich SEV_MODE=em_rich SEV_LINES=motor &
run X12d_motor_sevsel_l100 "sev = emerging GLM greedy, motor only, ridge 100" x12d_msel_l100 SEV_MODE=em_select SEV_LINES=motor LAMBDA_SEV=100 &
wait
echo GRID_DONE
