# run_retune_stageB.ps1 : stage B, the week 2 emerging chain on a re-tuned baseline, isolated from every existing week 2 run.
#   powershell -File week2\week1_retune\run\run_retune_stageB.ps1 -Tag b1_depth_m1   (needs stage A run with -Final: hand-off files)
# Mirrors run_x21_win.ps1 (x20_tblend chain: 06, 07 core, 07 sevem, 14, 08, 09, then 13 vs x20_tblend). Outputs:
#   OUT_ROOT = week2/week1_retune/output/chain_<tag>, DOCS_ROOT = week2/week1_retune/docs/chain_<tag>; the data caches are tag-keyed
#   (data/week_2/optionB/{adjust,final,valid_rows}/rt_<tag>*), so no existing week 2 run is overwritten.
param([Parameter(Mandatory)][string]$Tag, [string]$Ref = "x20_tblend")
$ErrorActionPreference = "Continue"
$R = $(if ($env:RSCRIPT) { $env:RSCRIPT } else { "Rscript" })
$root = "week2\week1_retune"; $out = "$root\output\chain_$Tag"; $docs = "$root\docs\chain_$Tag"
New-Item -ItemType Directory -Force "$out", "$docs", "$root\run\logs" | Out-Null
foreach ($d in "04_ibnr_trend", "03_features") { if (Test-Path "week2\output\$d") { Copy-Item "week2\output\$d" "$out\$d" -Recurse -Force } }   # read-only inputs the steps expect under OUT_ROOT
$t = "rt_$Tag"
$env:OUT_ROOT = $out; $env:DOCS_ROOT = $docs
$env:BASE_DIR = "data/week_2/week1_retune"; $env:BASE_TAG = $Tag; $env:BASE_DIAG_DIR = "$root/output/$Tag"
$env:DT_THREADS = "1"; $env:OMP_WAIT_POLICY = "passive"; $env:TREND_FLOOR_FREQ = "motor"; $env:TREND_MODE = "blend_freq"
function Step($script, $vars) {
  foreach ($k in $vars.Keys) { Set-Item -Path "env:$k" -Value $vars[$k] }
  $log = "$root\run\logs\$Tag.$script.log"
  cmd /c "`"$R`" week2\R\$script.R > `"$log`" 2>&1"
  "[$Tag] $script exit $LASTEXITCODE"
  foreach ($k in $vars.Keys) { Remove-Item -Path "env:$k" -ErrorAction SilentlyContinue }
}
Step "06_score_emerging_baseline" @{}
Step "07_emerging_adjust" @{ RUN_TAG = "${t}_core" }
# fin_sevem (emerging-only severity GLM, no developed offset) is reused as in run_x21_win.ps1
Step "14_blend_severity" @{ RUN_TAG = $t; BLEND_A = "${t}_core"; BLEND_B = "fin_sevem"; BLEND_W = "0.5"; BLEND_RELEVEL = "1"; BLEND_PERILS = "motor/own_damage,motor/glass_hail,motor/bodily_injury,contents/escape_of_water" }
Step "08_loadings_2025" @{ RUN_TAG = $t }
Step "09_validate_compare" @{ RUN_TAG = $t }
Step "13_compare_runs" @{ RUN_A = $t; RUN_B = $Ref; EXP = "RT_$Tag"; NOTE = "week 1 re-tune $Tag vs $Ref" }
Remove-Item env:OUT_ROOT, env:DOCS_ROOT, env:BASE_DIR, env:BASE_TAG, env:BASE_DIAG_DIR -ErrorAction SilentlyContinue
