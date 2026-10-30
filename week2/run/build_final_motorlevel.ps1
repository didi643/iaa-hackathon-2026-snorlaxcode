# build_final_motorlevel.ps1 : build the week 2 FINAL file "motorlevel_l_full" (submission #31, public 0.16840; 30 Oct 2026).
# Run from the repo root.
#   Default : only the last step, week2/R/30_final_from_components.R: rebuilds #12 line_ensemble (pre-probing base and
#             fallback) and #31 from the two cached component predictions and checks both MD5s. Seconds.
#   -Full   : first rebuild the components from raw data (week2/run/build_final_halfway.ps1 -Full: steps 01-06, the
#             x20_tblend motor chain, the re-tuned b8_combo_f buildings/contents chain; that script also writes the
#             set-aside probed file lvl_half at its end), then the default step, then week2/R/29_motor_level.R
#             (factor derivation, 2024 back-test scorecard, L1-L3 files). Several hours.
#   powershell -File week2\run\build_final_motorlevel.ps1 [-Full]
# Method: week2/docs/final_model_method_week2.md (section 8A)
param([switch]$Full)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")
$R = $(if ($env:RSCRIPT) { $env:RSCRIPT } else { "Rscript" })
$L = "week2\run\logs"; New-Item -ItemType Directory -Force $L | Out-Null

function RunR([string]$script, [string]$log) {
  $ErrorActionPreference = "Continue"
  & $R $script *> "$L\$log.log"
  $exit = $LASTEXITCODE
  $ErrorActionPreference = "Stop"
  if ($exit -ne 0) { Get-Content "$L\$log.log" -Tail 15; throw "$script failed (exit $exit)" }
}

if ($Full) { & .\week2\run\build_final_halfway.ps1 -Full }

foreach ($t in "x20_tblend", "rt_var_b8_floor_corrected") {
  if (-not (Test-Path "data\week_2\optionB\final\$t\pred_2025_peril.parquet")) { throw "Missing component ${t}: run with -Full" }
}
RunR "week2\R\30_final_from_components.R" "final_30_from_components"
Get-Content "$L\final_30_from_components.log" | Select-String "^(OK|FAIL)|F_BI|motor total"

if ($Full) {
  # 29 reads #12 from week2/output/submission; on a fresh clone use the byte-identical rebuild from step 30.
  $s12 = "week2\output\submission\submission_20261028_week2_optionB_line_ensemble.csv"
  if (-not (Test-Path $s12)) { Copy-Item "week2\output\final_rebuild\submission_week2_line_ensemble_12.csv" $s12 }
  RunR "week2\R\29_motor_level.R" "final_29_motor_level"
  Get-Content "$L\final_29_motor_level.log" | Select-String "^L_(BI|NB|FULL) ->"
}
