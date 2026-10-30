# build_final_halfway.ps1 : build the week 2 final model "lvl_half" (29 Oct 2026). Run from the repo root.
#   Default : only the last step (level calibration on the two cached component predictions). Seconds.
#   -Full   : rebuild everything from raw data first (steps 01-06, the x20_tblend motor chain, the re-tuned b8_combo_f
#             buildings/contents chain). Several hours (two 5-bag developed baselines).
#   powershell -File week2\run\build_final_halfway.ps1 [-Full]
# Method: week2/docs/final_model_method_week2.md
param([switch]$Full)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")
$R = $(if ($env:RSCRIPT) { $env:RSCRIPT } else { "Rscript" })
$L = "week2\run\logs"; New-Item -ItemType Directory -Force $L | Out-Null
$env:DT_THREADS = "1"; $env:OMP_WAIT_POLICY = "passive"

function Step([string]$script, [hashtable]$vars, [string]$log) {
  foreach ($k in $vars.Keys) { Set-Item "env:$k" $vars[$k] }
  $ErrorActionPreference = "Continue"
  & $R $script *> "$L\halfway_$log.log"
  $exit = $LASTEXITCODE
  $ErrorActionPreference = "Stop"
  foreach ($k in $vars.Keys) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
  if ($exit -ne 0) { Get-Content "$L\halfway_$log.log" -Tail 15; throw "$script failed (exit $exit)" }
  Write-Output ("{0,-45} ok {1}" -f $log, (Get-Date -Format HH:mm:ss))
}

if ($Full) {
  # A. Data: profile, clean both markets, shared features, emerging-only fields, IBNR + trend
  Step "week2\R\01_profile_emerging.R" @{} "01_profile"
  Step "week2\R\02_clean_week2.R" @{} "02_clean"
  Step "week2\R\03_harmonise_features.R" @{} "03_harmonise"
  Step "week2\R\03b_emerging_extra.R" @{} "03b_extra"
  Step "week2\R\04_ibnr_trend_week2.R" @{} "04_ibnr_trend"

  # B. Motor component = x20_tblend: Option B developed baseline (5 bags) + emerging chain, blended frequency trend, motor floor 0
  Step "week2\R\05_developed_baseline.R" @{ BAGS = "5"; RUN_TAG = "baseline" } "05_baseline"
  Step "week2\R\06_score_emerging_baseline.R" @{} "06_score"
  $tb = @{ TREND_MODE = "blend_freq"; TREND_FLOOR_FREQ = "motor" }
  Step "week2\R\07_emerging_adjust.R" @{ RUN_TAG = "fin_sevem"; SEV_MODE = "em_select"; TREND_FLOOR_FREQ = "motor" } "07_fin_sevem"
  Step "week2\R\07_emerging_adjust.R" ($tb + @{ RUN_TAG = "x20_tblend_core" }) "07_x20_core"
  $blend = @{ BLEND_B = "fin_sevem"; BLEND_W = "0.5"; BLEND_RELEVEL = "1";
              BLEND_PERILS = "motor/own_damage,motor/glass_hail,motor/bodily_injury,contents/escape_of_water" }
  Step "week2\R\14_blend_severity.R" ($tb + $blend + @{ RUN_TAG = "x20_tblend"; BLEND_A = "x20_tblend_core" }) "14_x20"
  Step "week2\R\08_loadings_2025.R" ($tb + @{ RUN_TAG = "x20_tblend" }) "08_x20"
  Step "week2\R\09_validate_compare.R" @{ RUN_TAG = "x20_tblend" } "09_x20"

  # C. Buildings / contents component = rt_var_b8_floor_corrected: week 1 engine re-tuned on emerging-available fields
  #    (b8_combo_f: depth -1, location fields on every peril, credit proxy, 5 bags), same emerging chain, step 8 with
  #    the x20 trend (blend_freq, motor floor 0).
  & .\week2\week1_retune\run\run_retune.ps1 -Tag b8_combo_f -Final -Bags 5 -Env @{ HP_DEPTH_ADD = "-1"; LOC_ALL = "1"; PROXY = "credit" }
  & .\week2\week1_retune\run\run_retune_stageB.ps1 -Tag b8_combo_f
  & .\week2\week1_retune\run\run_candidate_variants.ps1      # writes rt_var_b8_chosen (step 7 fit used below)
  & .\week2\week1_retune\run\run_corrected_floor.ps1         # step 8 again with blend_freq + motor floor -> rt_var_b8_floor_corrected
}

# D. Final: line_ensemble (motor from x20_tblend, buildings/contents from rt_var_b8_floor_corrected) x halfway peril levels.
#    Levels = geometric halfway between the line-calibrated levels (lvl_cal1) and the public-probe peril levels (theta,
#    week2/R/26_probe_solver.R), bounded to [0.6, 1.8]. "<line>=x" sets the line, "<line>/<peril>=x" overrides one peril.
$MULT = @(
  "motor=0.87", "motor/bodily_injury=1.41", "motor/third_party_prop=1.20", "motor/own_damage=0.60",
  "buildings/fire=1.57", "buildings/flood=1.42", "buildings/storm=1.46", "buildings/escape_of_water=0.60",
  "buildings/subsidence=1.48", "buildings/accidental_damage=1.48",
  "contents=0.70", "contents/theft=1.08"
) -join ","
foreach ($t in "x20_tblend", "rt_var_b8_floor_corrected") {
  if (-not (Test-Path "data\week_2\optionB\final\$t\pred_2025_peril.parquet")) { throw "Missing component ${t}: run with -Full" }
}
Step "week2\R\25_level_calibration.R" @{ TAG = "lvl_half"; MULT = $MULT } "25_lvl_half"
Get-Content "$L\halfway_25_lvl_half.log" | Select-String "lvl_half:"
