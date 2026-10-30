# run_queue_stageA.ps1 : runs the stage A queue sequentially (b0_ref first), each scored against b0_ref. Run from the repo root.
#   & .\week2\week1_retune\run\run_queue_stageA.ps1
# Progress: week2\week1_retune\run\queue_progress.log (one line per finished run with minutes).
$run = ".\week2\week1_retune\run\run_retune.ps1"
$progress = "week2\week1_retune\run\queue_progress.log"
$queue = [ordered]@{
  b0_ref       = @{}
  b0_full      = @{FEATURE_OFF_KEEP="all"}
  b0_tele      = @{FEATURE_ADD="telematics_opt_in,telematics_score"}
  b0_mile      = @{FEATURE_ADD="annual_mileage"}
  b0_region    = @{FEATURE_ADD="region"}
  b0_credit    = @{FEATURE_ADD="credit_band"}
  b0_age       = @{FEATURE_ADD="driver_age,policyholder_age"}
  b1_depth_m1  = @{HP_DEPTH_ADD="-1"}
  b1_depth_p1  = @{HP_DEPTH_ADD="1"}
  b1_eta_half  = @{HP_ETA_MULT="0.5"}
  b1_mcw_x2    = @{HP_MCW_MULT="2"}
  b1_lambda20  = @{HP_REG_LAMBDA="20"}
  b1_col1      = @{HP_COLSAMPLE="1"}
  b2_mono_off  = @{MONO_OFF="1"}
  b2_band_ord  = @{AGE_BAND_ORD="1"}
  b3_loc       = @{LOC_ALL="1"}
  b3_use       = @{PROXY="mileage"}
  b3_credit    = @{PROXY="credit"}
  b3_young     = @{PROXY="age"}
  b5_recent    = @{TRAIN_FROM="2022"}
  b5_yw        = @{YEAR_WEIGHTS="0.7,0.8,0.9,1"}
  b5_dw        = @{DOMAIN_W="1"}
}
foreach ($tag in $queue.Keys) {
  $t0 = Get-Date
  & $run -Tag $tag -Env $queue[$tag] | Out-Null
  $mins = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
  "{0} {1} finished in {2} min" -f (Get-Date -Format "yyyy-MM-dd HH:mm"), $tag, $mins | Add-Content $progress
}
"{0} queue complete" -f (Get-Date -Format "yyyy-MM-dd HH:mm") | Add-Content $progress
