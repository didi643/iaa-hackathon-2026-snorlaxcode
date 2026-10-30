# run_x21_win.ps1 : Windows equivalent of run_cred.sh for the X21 feature round (27 Oct 2026), on the x20_tblend chain:
#   7 (<tag>_core: motor frequency trend floor, TREND_MODE=blend_freq, + extra env e.g. X_NEW) -> 14 (blend with fin_sevem on the
#   four CV-picked perils, relevelled) -> 8 -> 9 -> 13 gate vs REF -> 21 per-peril scorecard vs REF.
# Use (from the repo root):
#   powershell -File week2\run\run_x21_win.ps1 -Tag x21a -Exp X21a -Note "..." -Ref x20_tblend -Model OPTB_X21A -Env @{X_NEW="credit_tier"}
param([string]$Tag, [string]$Exp = $Tag, [string]$Note = "", [string]$Ref = "x20_tblend", [string]$Model = "", [hashtable]$Env = @{})
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")
$R = $(if ($env:RSCRIPT) { $env:RSCRIPT } else { "Rscript" })
$L = "week2\run\logs"
$env:DT_THREADS = "1"; $env:OMP_WAIT_POLICY = "passive"; $env:TREND_FLOOR_FREQ = "motor"; $env:TREND_MODE = "blend_freq"
foreach ($k in $Env.Keys) { Set-Item "env:$k" $Env[$k] }
function Step([string]$script, [hashtable]$vars) {
  foreach ($k in $vars.Keys) { Set-Item "env:$k" $vars[$k] }
  $log = "$L\x21_${Tag}_$script.log"
  $ErrorActionPreference = "Continue"
  & $R "week2\R\$script.R" *> $log
  $ErrorActionPreference = "Stop"
  if ($LASTEXITCODE -ne 0) { Write-Output "FAILED $script"; Get-Content $log -Tail 8; exit 1 }
  Write-Output ("{0} ok {1}" -f $script, (Get-Date -Format HH:mm:ss))
}
Step "07_emerging_adjust" @{ RUN_TAG = "${Tag}_core" }
Step "14_blend_severity" @{ RUN_TAG = $Tag; BLEND_A = "${Tag}_core"; BLEND_B = "fin_sevem"; BLEND_W = "0.5"; BLEND_RELEVEL = "1";
  BLEND_PERILS = "motor/own_damage,motor/glass_hail,motor/bodily_injury,contents/escape_of_water" }
Step "08_loadings_2025" @{ RUN_TAG = $Tag }
Step "09_validate_compare" @{ RUN_TAG = $Tag }
Step "13_compare_runs" @{ RUN_A = $Tag; RUN_B = $Ref; EXP = $Exp; NOTE = $Note }
Get-Content "$L\x21_${Tag}_13_compare_runs.log" | Select-String -Pattern "experiment|verdict|diff" | Select -First 6 | % Line
if ($Model -eq "") { $Model = "OPTB_" + $Tag.ToUpper() }
Step "21_x21_scorecard" @{ RUN_TAG = $Tag; REF = $Ref; MODEL = $Model; DESC = $Note; RECORD = "1" }