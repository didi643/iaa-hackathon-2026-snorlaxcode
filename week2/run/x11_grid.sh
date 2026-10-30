#!/bin/zsh
# X11 grid: developed-only frequency and emerging-only severity (Wendy, 26 Oct 2026)
cd "$(dirname "$0")/../.."
run() { EXP=$1 NOTE=$2 zsh week2/run/run_exp.sh "${@:3}" > week2/run/logs/grid_$1.txt 2>&1 }
run X11a_freqdev "freq = developed baseline only; sev = main" x11a_fdev FREQ_MODE=developed &
run X11b_freqdev_sevflat "freq = developed only; sev = one emerging mean per peril" x11b_fdev_sflat FREQ_MODE=developed SEV_MODE=em_flat &
run X11c_freqdev_sevsel "freq = developed only; sev = emerging GLM, greedy factors" x11c_fdev_ssel FREQ_MODE=developed SEV_MODE=em_select &
run X11d_sevflat "freq = main; sev = one emerging mean per peril" x11d_sflat SEV_MODE=em_flat &
wait
run X11e_sevsel "freq = main; sev = emerging GLM, greedy factors" x11e_ssel SEV_MODE=em_select &
run X11f_sevrich "freq = main; sev = emerging GLM for >=1000-claim perils, flat otherwise" x11f_srich SEV_MODE=em_rich &
run X11g_freqlvl_sevsel "freq = developed x emerging level (no factors); sev = emerging GLM greedy" x11g_flvl_ssel FREQ_MODE=level SEV_MODE=em_select &
run X11h_sevem_fixed "freq = main; sev = emerging GLM fixed factors (X4a on current main)" x11h_sem SEV_MODE=emerging &
wait
echo GRID_DONE
