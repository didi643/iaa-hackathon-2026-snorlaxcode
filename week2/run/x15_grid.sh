#!/bin/zsh
# X15: frequency range multiplier (level x developed frequency^beta); X16: buildings EoW severity level credibility. Gate vs main (#2)
cd "$(dirname "$0")/../.."
run() { EXP=$1 NOTE=$2 zsh week2/run/run_exp.sh "${@:3}" > week2/run/logs/grid_$1.txt 2>&1 }
run X15a_fpow_force "freq = level x baseline^beta (ridge to beta 1), all perils" x15a_fpow FREQ_POWER=force &
run X15b_fpow_cand "baseline^beta offered as a factor to the greedy step, all perils" x15b_fpowc FREQ_POWER=cand &
run X15c_fpow_tpp "freq power forced, motor TPP only" x15c_fpow_tpp FREQ_POWER=force FREQ_POWER_PERILS=motor/third_party_prop &
run X16a_eow_k100 "buildings EoW severity level K 100 (was 400): in-sample A/E 0.88 in 2023 and 2024" x16a_eow100 K_SEV_PERIL=buildings/escape_of_water=100 &
run X16b_eow_k25 "buildings EoW severity level K 25" x16b_eow25 K_SEV_PERIL=buildings/escape_of_water=25 &
wait; echo GRID_DONE
