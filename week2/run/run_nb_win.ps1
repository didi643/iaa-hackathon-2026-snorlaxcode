# run_nb_win.ps1 : NB round (27 Oct 2026, 2025 take-on treatment). Step 8 new-business variants on the x20_tblend model
#   (adjust tag x20nb = exact x20_tblend reproduction + insample23): 22 backtest on 2024 -> 08 (2025, ADJ_TAG) -> 09 -> 13 gate vs REF
#   -> 21 per-peril scorecard vs REF.
# Use (from the repo root, in-process so -Env passes):
#   & .\week2\run\run_nb_win.ps1 -Tag nb_cur -Exp NB0 -Ref x20_tblend -Note "..." -Env @{NB_K="300"}
param([string]$Tag, [string]$Exp = $Tag, [string]$Note = "", [string]$Ref = "x20_tblend", [string]$Model = "", [string]$Adj = "x20nb", [hashtable]$Env = @{})
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")
$R = $(if ($env:RSCRIPT) { $env:RSCRIPT } else { "Rscript" })
$L = "week2\run\logs"
$env:DT_THREADS = "1"; $env:OMP_WAIT_POLICY = "passive"; $env:TREND_FLOOR_FREQ = "motor"; $env:TREND_MODE = "blend_freq"
foreach ($k in @("NB_K", "NB_PRIOR", "NB_LEVEL", "NB_KP", "NB_PPRIOR")) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
foreach ($k in $Env.Keys) { Set-Item "env:$k" $Env[$k] }
function Step([string]$script, [hashtable]$vars) {
  foreach ($k in $vars.Keys) { Set-Item "env:$k" $vars[$k] }
  $log = "$L\nb_${Tag}_$script.log"
  $ErrorActionPreference = "Continue"
  & $R "week2\R\$script.R" *> $log
  $ErrorActionPreference = "Stop"
  if ($LASTEXITCODE -ne 0) { Write-Output "FAILED $script"; Get-Content $log -Tail 8; exit 1 }
  Write-Output ("{0} ok {1}" -f $script, (Get-Date -Format HH:mm:ss))
}
Step "22_nb_backtest" @{ RUN_TAG = $Tag; ADJ_TAG = $Adj }
Step "08_loadings_2025" @{ RUN_TAG = $Tag; ADJ_TAG = $Adj }
Step "09_validate_compare" @{ RUN_TAG = $Tag }
Step "13_compare_runs" @{ RUN_A = $Tag; RUN_B = $Ref; EXP = $Exp; NOTE = $Note }
Get-Content "$L\nb_${Tag}_13_compare_runs.log" | Select-String -Pattern "experiment|mix_2025|as_is" | Select -First 4 | % Line
if ($Model -eq "") { $Model = "OPTB_" + $Tag.ToUpper() }
Step "21_x21_scorecard" @{ RUN_TAG = $Tag; REF = $Ref; MODEL = $Model; DESC = $Note; RECORD = "1" }