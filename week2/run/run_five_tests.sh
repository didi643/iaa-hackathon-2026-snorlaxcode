#!/bin/zsh
# run_five_tests.sh : rebuilds the five X20 candidates submitted as #7-#11 (26 Oct 2026). Run from anywhere; run_cred.sh cds to the repo root.
# Needs the #5 chain already built (zsh week2/run/build_final.sh: run tags fin_core, fin_sevem, final) and the earlier runs x14e (#4) and x19_hyb_bs (#6).
R=week2/run/run_cred.sh
cd "$(dirname "$0")/../.."
CAT="buildings/fire,buildings/flood,buildings/subsidence,buildings/storm,contents/flood"

# #7  x20_tblend     : credibility-weighted frequency trend (motor floor at 0 kept)
zsh $R x20_tblend TREND_MODE=blend_freq
# #8  x20_combo_attr : tblend + cat perils' frequency level on the attritional emerging complement
zsh $R x20_combo_attr TREND_MODE=blend_freq CAT_PERILS=$CAT CAT_PRIOR=attr
# #9  x20_cat_dev800 : cat perils on the developed long-run level, K 800
zsh $R x20_cat_dev800 CAT_PERILS=$CAT CAT_PRIOR=dev CAT_K=800
# #10 x20_cat_attr   : cat perils on the attritional emerging complement
zsh $R x20_cat_attr CAT_PERILS=$CAT CAT_PRIOR=attr
# #11 x20_avg456     : mean of #5 (final), #6 (x19_hyb_bs) and #4 (x14e)
OUT=x20_avg456 MODE=avg SOURCES=final,x19_hyb_bs,x14e Rscript week2/R/20_post_process.R
RUN_A=x20_avg456 RUN_B=final EXP=x20_avg456 Rscript week2/R/13_compare_runs.R

# Submission files (week2/output/submission/submission_<time>_week2_optionB_<tag>.csv + .md5)
for t in x20_tblend x20_combo_attr x20_cat_dev800 x20_cat_attr x20_avg456; do
  SOURCE_TAG=$t Rscript week2/R/15_candidate_from_tag.R
done
