#!/bin/sh
# make_kaggle_dataset.sh ------------------------------------------------------------------------------------------------
# Stage the private Kaggle dataset the notebook snorlaxcode_final_week1_week2.ipynb reads:
#   Week 1: the frozen panels, the MOTOR 2 predictions and the row order (week1/docs/handover_final/replicate/inputs)
#   Week 2: the two cached component predictions (renamed so they do not clash) and the step 8 loadings
#   both  : the two submitted final files, for the checks
# Run    : sh kaggle/make_kaggle_dataset.sh            (from the repo root)
# Output : kaggle/dataset/ (git-ignored). Upload its data files as a new private Kaggle dataset, in the browser or with
#          `kaggle datasets create -p kaggle/dataset` (put your username in dataset-metadata.json first).
set -e
D=kaggle/dataset
rm -rf "$D"; mkdir -p "$D"
cp week1/docs/handover_final/replicate/inputs/* "$D/"
cp data/week_2/optionB/final/x20_tblend/pred_2025_peril.parquet "$D/x20_tblend_pred_2025_peril.parquet"
cp data/week_2/optionB/final/rt_var_b8_floor_corrected/pred_2025_peril.parquet "$D/rt_var_b8_floor_corrected_pred_2025_peril.parquet"
cp week2/output/08_loadings/x20_tblend/loadings.csv "$D/loadings.csv"
cp final_files/week1_submission_20261023_1636_w9_motor2_pre_m0.5.csv final_files/week2_submission_20261030_0905_week2_motorlevel_l_full.csv "$D/"
cat > "$D/dataset-metadata.json" <<'JSON'
{
  "title": "SnorlaxCode final components",
  "id": "YOUR_KAGGLE_USERNAME/snorlaxcode-final-components",
  "licenses": [{"name": "other"}]
}
JSON
ls -la "$D"
