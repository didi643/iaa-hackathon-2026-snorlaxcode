# Build isolated week 2 submissions from the validated b8_combo_f baseline and compare variations.
# Run from repo root. Outputs use rt_var_* tags and are never submitted automatically.
$ErrorActionPreference = "Stop"
$R = $(if ($env:RSCRIPT) { $env:RSCRIPT } else { "Rscript" })
$root = "week2\week1_retune"; $base = "b8_combo_f"
$variants = [ordered]@{
  b8_current = @{ TREND_MODE = "blend_freq"; TREND_FLOOR_FREQ = "motor" }
  b8_chosen  = @{ TREND_MODE = "chosen"; TREND_FLOOR_FREQ = "motor" }
  b8_line_sev = @{ TREND_MODE = "line_sev"; TREND_FLOOR_FREQ = "motor" }
}
function Step($script, $vars, $tag) {
  foreach ($k in $vars.Keys) { Set-Item "env:$k" $vars[$k] }
  $log = "$root\run\logs\var_${tag}_${script}.log"
  $ErrorActionPreference = "Continue"
  & $R "week2\R\$script.R" *> $log
  $exit = $LASTEXITCODE
  $ErrorActionPreference = "Stop"
  if ($exit -ne 0) { Get-Content $log -Tail 20; throw "$script failed for $tag (exit $exit)" }
  foreach ($k in $vars.Keys) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
}
foreach ($name in $variants.Keys) {
  $tag = "var_$name"; $t = "rt_$tag"
  if (Test-Path "data\week_2\optionB\final\$t\pred_2025_peril.parquet") { Write-Output "$name already complete"; continue }
  $env:BASE_DIR = "data/week_2/week1_retune"; $env:BASE_TAG = $base; $env:BASE_DIAG_DIR = "week2/week1_retune/output/b8_combo_f"
  $env:OUT_ROOT = "$root/output/var_$name"; $env:DOCS_ROOT = "$root/docs/var_$name"
  $env:DT_THREADS = "1"; $env:OMP_WAIT_POLICY = "passive"
  New-Item -ItemType Directory -Force $env:OUT_ROOT,$env:DOCS_ROOT | Out-Null
  foreach ($input_dir in "03_features", "04_ibnr_trend") {
    if (-not (Test-Path "$env:OUT_ROOT/$input_dir")) {
      Copy-Item "$root/output/chain_b8_combo_f/$input_dir" "$env:OUT_ROOT/$input_dir" -Recurse -Force
    }
  }
  Step "06_score_emerging_baseline" @{} $name
  Step "07_emerging_adjust" @{ RUN_TAG = "${t}_core" } $name
  Step "14_blend_severity" @{ RUN_TAG = $t; BLEND_A = "${t}_core"; BLEND_B = "fin_sevem"; BLEND_W = "0.5"; BLEND_RELEVEL = "1"; BLEND_PERILS = "motor/own_damage,motor/glass_hail,motor/bodily_injury,contents/escape_of_water" } $name
  Step "08_loadings_2025" @{ RUN_TAG = $t; TREND_MODE = $variants[$name].TREND_MODE; TREND_FLOOR_FREQ = "motor" } $name
  Step "09_validate_compare" @{ RUN_TAG = $t } $name
  Step "13_compare_runs" @{ RUN_A = $t; RUN_B = "rt_b8_combo_f"; EXP = "VAR_$name"; NOTE = "b8_combo_f trend variation" } $name
  Step "21_x21_scorecard" @{ RUN_TAG = $t; REF = "rt_b8_combo_f"; MODEL = "OPTB_VAR_$name"; DESC = "b8_combo_f trend variation"; RECORD = "1" } $name
  New-Item -ItemType Directory -Force "$env:OUT_ROOT/submission" | Out-Null
  $env:SOURCE_TAG = $t; Step "15_candidate_from_tag" @{} $name
  Remove-Item env:BASE_DIR,env:BASE_TAG,env:BASE_DIAG_DIR,env:OUT_ROOT,env:DOCS_ROOT -ErrorAction SilentlyContinue
}
