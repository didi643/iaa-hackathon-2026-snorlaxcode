# Rebuild only step 8 and the submission from the completed b8 adjustment, with the x20 motor frequency floor explicit.
$ErrorActionPreference = "Stop"
$R = $(if ($env:RSCRIPT) { $env:RSCRIPT } else { "Rscript" })
$tag = "rt_var_b8_floor_corrected"; $out = "week2/week1_retune/output/var_b8_floor_corrected"; $old = "rt_var_b8_chosen"
New-Item -ItemType Directory -Force "$out/03_features", "$out/04_ibnr_trend", "$out/07_adjust", "$out/submission" | Out-Null
Copy-Item "week2/week1_retune/output/var_b8_chosen/03_features/*" "$out/03_features" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item "week2/week1_retune/output/var_b8_chosen/04_ibnr_trend/*" "$out/04_ibnr_trend" -Recurse -Force
Copy-Item "week2/week1_retune/output/var_b8_chosen/07_adjust/levels_$old.csv" "$out/07_adjust/levels_$tag.csv" -Force
$env:OUT_ROOT = $out; $env:DOCS_ROOT = "week2/week1_retune/docs/var_b8_floor_corrected"
$env:RUN_TAG = $tag; $env:ADJ_TAG = $old; $env:TREND_MODE = "blend_freq"; $env:TREND_FLOOR_FREQ = "motor"; $env:DT_THREADS = "1"; $env:OMP_WAIT_POLICY = "passive"
$env:SOURCE_TAG = $tag
$ErrorActionPreference = "Continue"
& $R week2/R/08_loadings_2025.R *> "week2/week1_retune/run/logs/var_b8_floor_corrected_08.log"
$exit08 = $LASTEXITCODE
& $R week2/R/15_candidate_from_tag.R *> "week2/week1_retune/run/logs/var_b8_floor_corrected_15.log"
$exit15 = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($exit08 -ne 0) { throw "step 08 failed: $exit08" }
if ($exit15 -ne 0) { throw "step 15 failed: $exit15" }
"corrected floor candidate complete"
