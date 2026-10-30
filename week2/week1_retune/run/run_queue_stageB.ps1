# run_queue_stageB.ps1 : final 5-bag fit of the finalist, hand-off files, then the week 2 emerging chain (stage B). Resumable.
#   & .\week2\week1_retune\run\run_queue_stageB.ps1
# Finalist b8_combo_f = b8_combo (depth -1, location proxy on all perils, credit proxy) at 5 bags. Progress: queue_progress.log
$run = ".\week2\week1_retune\run\run_retune.ps1"
$progress = "week2\week1_retune\run\queue_progress.log"
function Mark($msg) { "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm"), $msg | Add-Content $progress }
$combo = @{HP_DEPTH_ADD="-1"; LOC_ALL="1"; PROXY="credit"}
$t0 = Get-Date
& $run -Tag b8_combo_f -Final -Bags 5 -Env $combo -NoScore
Mark ("b8_combo_f (5 bags, final fit) finished in {0} min" -f [math]::Round(((Get-Date) - $t0).TotalMinutes, 1))
if (-not (Test-Path "week2\week1_retune\output\chain_b8_combo_f\done.flag")) {
  $t0 = Get-Date
  & .\week2\week1_retune\run\run_retune_stageB.ps1 -Tag b8_combo_f
  New-Item -ItemType File -Force "week2\week1_retune\output\chain_b8_combo_f\done.flag" | Out-Null
  Mark ("stage B chain b8_combo_f finished in {0} min" -f [math]::Round(((Get-Date) - $t0).TotalMinutes, 1))
}
Mark "stage B queue complete"
