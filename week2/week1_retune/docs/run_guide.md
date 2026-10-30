# Week 1 re-tune: run guide

All commands from the repo root, in PowerShell. Nothing here reads or writes `week1/`. Plan and rules: `retune_plan.md`.
Register of every run: `retune_register.csv`.

## Order

```powershell
# 0. Reference (1 bag): every stage A variant is scored against it
& .\week2\week1_retune\run\run_retune.ps1 -Tag b0_ref

# 1. A variant (validation only, scored vs b0_ref, register row updated)
& .\week2\week1_retune\run\run_retune.ps1 -Tag b1_depth_m1 -Env @{HP_DEPTH_ADD="-1"}

# 2. Info-only ablation (developed-only fields put back; never handed to week 2)
& .\week2\week1_retune\run\run_retune.ps1 -Tag b0_region -Env @{FEATURE_ADD="region"}

# 3. Second seed for a close call (then compare the two scores by hand in the register)
& .\week2\week1_retune\run\run_retune.ps1 -Tag b1_depth_m1_s2 -SeedOffset 11 -Env @{HP_DEPTH_ADD="-1"}

# 4. A variant that passed gate A: final fit + hand-off files, then the week 2 chain (stage B)
& .\week2\week1_retune\run\run_retune.ps1 -Tag b1_depth_m1_f -Final -Bags 5 -Env @{HP_DEPTH_ADD="-1"}
& .\week2\week1_retune\run\run_retune_stageB.ps1 -Tag b1_depth_m1_f

# 5. Hyperparameter tuning (long; resumable; one line at a time is fine)
& .\week2\week1_retune\run\run_retune.ps1 -Tag b7_tune -NoScore -Env @{TUNE="1"; LINES_ONLY="motor"}
```

Smoke tests: add `FAST="1"` and `LINES_ONLY="contents"` to `-Env` (about one minute).

## Switches (`-Env`)

`HP_DEPTH_ADD`, `HP_ETA_MULT`, `HP_MCW_MULT`, `HP_REG_LAMBDA`, `HP_COLSAMPLE`, `HP_SUBSAMPLE`, `MONO_OFF=1`, `AGE_BAND_ORD=1`,
`LOC_ALL=1`, `PROXY=mileage,credit,age`, `TRAIN_FROM=2022`, `YEAR_WEIGHTS=0.7,0.8,0.9,1`, `DOMAIN_W=1`,
`FEATURE_ADD=region,...` / `FEATURE_OFF_KEEP=all` (info only), `SPEC_OVERRIDE=<csv: line,peril,param,value>`,
`TUNE=1` (+ `TUNE_N_FREQ`, `TUNE_N_SEV`), `LINES_ONLY`, `FAST=1`. Defaults reproduce the week 2 baseline.

## Resuming after an interruption

Every runner is resumable. After a crash, reboot or stop, run the same queue script again from the repo root:

```powershell
& .\week2\week1_retune\run\run_queue_stageA.ps1   # stage A list
& .\week2\week1_retune\run\run_queue_next.ps1     # combined run, tuning, tuned run
```

- A finished fit (model card present) is skipped; a fit with no register score is only re-scored; the line `already complete, skipped` is printed.
- A run interrupted mid-fit restarts that one variant from its beginning (6 to 20 minutes lost at most).
- Tuning (`TUNE=1`) resumes at the first peril not in `output/<tag>/tune_summary.csv`; only the peril in progress is repeated.
- `-Force` on `run_retune.ps1` redoes a variant on purpose.

## Where things land

| What | Where |
|---|---|
| Model card, fitted models | `week2/week1_retune/models/<tag>/` |
| Scores, row predictions, bootstrap, tuning logs | `week2/week1_retune/output/<tag>/` |
| Hand-off files for week 2 (`-Final`) | `data/week_2/week1_retune/<tag>/` |
| Stage B outputs | `week2/week1_retune/output/chain_<tag>/`, `docs/chain_<tag>/`; caches `data/week_2/optionB/{adjust,final,valid_rows}/rt_<tag>*` |
| Console logs | `week2/week1_retune/run/logs/` |
| Step log (inputs and outputs with MD5) | `week2/week1_retune/docs/step_log.md` |

## After a run

1. Stage A: the score script prints the verdict and fills the register row (gate A, checks 1-3).
2. Fill checks 4 (second seed) and, after stage B, 5 and 7 and the emerging columns by hand, then set `decision`.
3. Promotion to week 2 (adopted variants only): copy `data/week_2/week1_retune/<tag>/` to `data/week_2/optionB/rt_<tag>/`, log
   the decision in `week2/docs/optionB/decision_register.csv`, and build with `BASE_TAG=rt_<tag>`.
