# run_queue_next.ps1 : combined run, per-peril hyperparameter tuning on the combined setup, then the tuned run. Run from the repo root.
#   & .\week2\week1_retune\run\run_queue_next.ps1
# Progress: week2\week1_retune\run\queue_progress.log
$run = ".\week2\week1_retune\run\run_retune.ps1"
$progress = "week2\week1_retune\run\queue_progress.log"
$combo = @{HP_DEPTH_ADD="-1"; LOC_ALL="1"; PROXY="credit"}
function Mark($msg) { "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm"), $msg | Add-Content $progress }
$t0 = Get-Date; & $run -Tag b8_combo -Env $combo | Out-Null; Mark ("b8_combo finished in {0} min" -f [math]::Round(((Get-Date) - $t0).TotalMinutes, 1))
$t0 = Get-Date; $tune = $combo.Clone(); $tune["TUNE"] = "1"; $tune["TUNE_N_FREQ"] = "24"; $tune["TUNE_N_SEV"] = "16"
& $run -Tag b9_tune -NoScore -Env $tune | Out-Null; Mark ("b9_tune finished in {0} min" -f [math]::Round(((Get-Date) - $t0).TotalMinutes, 1))
$t0 = Get-Date; $app = $combo.Clone(); $app["SPEC_OVERRIDE"] = "week2/week1_retune/inputs/tuned_spec_b9_tune.csv"
& $run -Tag b9_applied -Env $app | Out-Null; Mark ("b9_applied finished in {0} min" -f [math]::Round(((Get-Date) - $t0).TotalMinutes, 1))
$env:TAG = "b9_applied"; $env:REF = "b8_combo"
if (-not (Test-Path "week2\week1_retune\output\b9_applied\score_vs_b8_combo.csv")) {
  & $(if ($env:RSCRIPT) { $env:RSCRIPT } else { "Rscript" }) week2\week1_retune\R\r08_score_vs_ref.R 2>&1 | Tee-Object -FilePath week2\week1_retune\run\logs\b9_applied.vs_b8_combo.log | Out-Null
}
Mark "queue complete"
