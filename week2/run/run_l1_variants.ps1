# Lasso-like regularization experiments on the existing x20 baseline.
param([string]$Tag = "l1f02", [string]$L1 = "0.02", [string]$MaxFactors = "4")
$ErrorActionPreference = "Continue"
$R = $(if ($env:RSCRIPT) { $env:RSCRIPT } else { "Rscript" })
$L = "week2\run\logs"; $env:DT_THREADS="1"; $env:OMP_WAIT_POLICY="passive"; $env:TREND_FLOOR_FREQ="motor"; $env:TREND_MODE="blend_freq"; $env:L1_FACTOR_FREQ=$L1; $env:L1_FACTOR_SEV="0"; $env:MAX_FACTORS=$MaxFactors
function Step($script, $vars) {
  foreach($k in $vars.Keys){Set-Item "env:$k" $vars[$k]}
  $log="$L\l1_${Tag}_${script}.log"; & $R "week2\R\$script.R" *> $log; $exit=$LASTEXITCODE
  foreach($k in $vars.Keys){Remove-Item "env:$k" -ErrorAction SilentlyContinue}
  if($exit -ne 0){Get-Content $log -Tail 20; throw "$script failed exit $exit"}
}
Step "07_emerging_adjust" @{RUN_TAG="${Tag}_core"}
Step "14_blend_severity" @{RUN_TAG=$Tag;BLEND_A="${Tag}_core";BLEND_B="fin_sevem";BLEND_W="0.5";BLEND_RELEVEL="1";BLEND_PERILS="motor/own_damage,motor/glass_hail,motor/bodily_injury,contents/escape_of_water"}
Step "08_loadings_2025" @{RUN_TAG=$Tag}
Step "09_validate_compare" @{RUN_TAG=$Tag}
Step "13_compare_runs" @{RUN_A=$Tag;RUN_B="x20_tblend";EXP="L1_$Tag";NOTE="lasso-like factor soft threshold"}
Step "21_x21_scorecard" @{RUN_TAG=$Tag;REF="x20_tblend";MODEL="OPTB_$($Tag.ToUpper())";DESC="lasso-like factor soft threshold";RECORD="1"}
Step "15_candidate_from_tag" @{SOURCE_TAG=$Tag}
