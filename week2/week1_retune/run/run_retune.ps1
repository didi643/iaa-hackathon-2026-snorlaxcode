# run_retune.ps1 : run one week 1 re-tune variant (stage A) and score it against the reference. Run from the repo root.
#   powershell -File week2\week1_retune\run\run_retune.ps1 -Tag b1_depth_m1 -Env @{HP_DEPTH_ADD="-1"} [-Ref b0_ref] [-Bags 1] [-Final] [-SeedOffset 0]
# Stage A is validation only (SKIP_FINAL=1). Add -Final to also fit 2021-24 and write the hand-off files for stage B.
# Resumable: a finished fit (model_card.md present; tuned spec for TUNE runs; hand-off files for -Final runs) is not repeated, and a
# fit without a register score is only re-scored. Re-run the same command (or the queue script) after any interruption. -Force redoes all.
param([Parameter(Mandatory)][string]$Tag, [hashtable]$Env = @{}, [string]$Ref = "b0_ref", [int]$Bags = 1, [switch]$Final, [int]$SeedOffset = 0, [switch]$NoScore, [switch]$Force)
$ErrorActionPreference = "Continue"
$R = $(if ($env:RSCRIPT) { $env:RSCRIPT } else { "Rscript" })
$root = "week2\week1_retune"
New-Item -ItemType Directory -Force "$root\run\logs" | Out-Null
$isTune = ($Env.ContainsKey("TUNE") -and $Env["TUNE"] -eq "1")
$fitDone = if ($isTune) { Test-Path "$root\inputs\tuned_spec_$Tag.csv" }
           else { (Test-Path "$root\models\$Tag\model_card.md") -and (-not $Final -or (Test-Path "data\week_2\week1_retune\$Tag\baseline_emerging_test.parquet")) }
$scored = $true
if (-not $NoScore -and $Tag -ne $Ref) {
  $row = Import-Csv "$root\docs\retune_register.csv" | Where-Object { $_.tag -eq $Tag } | Select-Object -First 1
  $scored = (-not $row) -or [bool]$row.dev_d2_all
}
if ($Force) { $fitDone = $false; $scored = $false }
if ($fitDone -and $scored) { "[$Tag] already complete, skipped"; return }
$env:RUN_TAG = $Tag; $env:BAGS = "$Bags"; $env:SEED_OFFSET = "$SeedOffset"; $env:DT_THREADS = "1"; $env:OMP_WAIT_POLICY = "passive"
$env:SKIP_FINAL = $(if ($Final) { "0" } else { "1" })
foreach ($k in $Env.Keys) { Set-Item -Path "env:$k" -Value $Env[$k] }
$ok = $true
if (-not $fitDone) {
  $log = "$root\run\logs\$Tag.console.log"
  cmd /c "`"$R`" $root\R\r05_retune_baseline.R > `"$log`" 2>&1"
  $ok = ($LASTEXITCODE -eq 0)
  "[$Tag] r05 exit $LASTEXITCODE (log $log)"
} else { "[$Tag] fit already done, scoring only" }
if ($ok -and -not $NoScore -and $Tag -ne $Ref) {
  $env:TAG = $Tag; $env:REF = $Ref
  cmd /c "`"$R`" $root\R\r08_score_vs_ref.R 2>&1" | Tee-Object -FilePath "$root\run\logs\$Tag.score.log"
}
foreach ($k in $Env.Keys) { Remove-Item -Path "env:$k" -ErrorAction SilentlyContinue }
