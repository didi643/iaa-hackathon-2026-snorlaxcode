#!/bin/zsh
# x20_grid.sh : X20 (26 Oct 2026) - simplification, trend and cat-peril complement tests on the #5 chain (run_cred.sh), gated vs final
cd "$(dirname "$0")/../.."
R=week2/run/run_cred.sh
CAT="buildings/fire,buildings/flood,buildings/subsidence,buildings/storm,contents/flood"
jobs_list=(
 "x20_noblend BLEND_W=0"
 "x20_mf1 MAX_FACTORS=1" "x20_mf2 MAX_FACTORS=2"
 "x20_tlsev TREND_MODE=line_sev" "x20_tblend TREND_MODE=blend_freq"
 "x20_cat_dev CAT_PERILS=$CAT CAT_PRIOR=dev" "x20_cat_dev800 CAT_PERILS=$CAT CAT_PRIOR=dev CAT_K=800"
 "x20_cat_devinf CAT_PERILS=$CAT CAT_PRIOR=dev CAT_K=1000000"
 "x20_cat_attr CAT_PERILS=$CAT CAT_PRIOR=attr" "x20_cat_attr800 CAT_PERILS=$CAT CAT_PRIOR=attr CAT_K=800"
)
i=0
for j in "${jobs_list[@]}"; do
  a=(${=j}); (zsh $R ${a[1]} ${a[2,-1]} NOTE="X20 ${a[2,-1]}" > week2/run/logs/x20_${a[1]}.out 2>&1) &
  i=$((i+1)); if (( i % 5 == 0 )); then wait; fi
done
wait
echo GRID_DONE
