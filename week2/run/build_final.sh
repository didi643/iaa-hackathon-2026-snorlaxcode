#!/bin/zsh
# build_final.sh : rebuild the week 2 final model (submission #5, public 0.16612) from the step 5 baseline onwards.
# Prerequisite (once): steps 00-06 have been run, i.e.
#   Rscript week2/R/01_profile_emerging.R; Rscript week2/R/02_clean_week2.R; Rscript week2/R/03_harmonise_features.R
#   Rscript week2/R/03b_emerging_extra.R; Rscript week2/R/04_ibnr_trend_week2.R
#   BAGS=5 RUN_TAG=baseline Rscript week2/R/05_developed_baseline.R   (about 1-2 hours)
#   Rscript week2/R/06_score_emerging_baseline.R
# Then this script runs steps 7 (twice), 14, 8, 9 and 15 under the run tags fin_core / fin_sevem / final.
# Output: week2/output/submission/submission_<time>_week2_optionB_final.csv (same predictions as submission #5).
cd "$(dirname "$0")/../.."
export DT_THREADS=${DT_THREADS:-4} OMP_WAIT_POLICY=passive
L=week2/run/logs; set -e
# 7a. Core model: developed baseline x credibility-weighted emerging levels and factors, motor frequency trend floored at 0
RUN_TAG=fin_core TREND_FLOOR_FREQ=motor Rscript week2/R/07_emerging_adjust.R > $L/final_07_core.log 2>&1
# 7b. Emerging-only severity GLM (greedy factors) - source of the emerging severity shape for four perils
RUN_TAG=fin_sevem SEV_MODE=em_select TREND_FLOOR_FREQ=motor Rscript week2/R/07_emerging_adjust.R > $L/final_07_sevem.log 2>&1
# 14. 50/50 geometric severity blend on the four CV-picked perils, each relevelled to the core model's total
RUN_TAG=final BLEND_A=fin_core BLEND_B=fin_sevem BLEND_W=0.5 BLEND_RELEVEL=1 \
  BLEND_PERILS=motor/own_damage,motor/glass_hail,motor/bodily_injury,contents/escape_of_water \
  Rscript week2/R/14_blend_severity.R > $L/final_14.log 2>&1
# 8. 2025 loadings (trend one year, new-business load), motor frequency trend floored at 0
RUN_TAG=final TREND_FLOOR_FREQ=motor Rscript week2/R/08_loadings_2025.R > $L/final_08.log 2>&1
# 9. Local validation (emerging 2023 -> 2024)
RUN_TAG=final Rscript week2/R/09_validate_compare.R > $L/final_09.log 2>&1
# 15. Submission file + checks
SOURCE_TAG=final Rscript week2/R/15_candidate_from_tag.R > $L/final_15.log 2>&1
grep "final:" $L/final_15.log
