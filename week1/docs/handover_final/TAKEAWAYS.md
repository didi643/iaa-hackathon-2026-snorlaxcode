# IAA Hackathon 2026 Part 1 - takeaways and handover (24 Oct 2026)

Metric: Tweedie deviance D² (p = 1.5) on row cost; public leaderboard = ~33% of the 2025 test rows, private = the other
~67%. Detailed run-by-run history: `docs/workflow.md` (submission log + private results), `docs/iteration_summary_motor.xlsx`,
`docs/model_variations_register_motor.xlsx` (motor-track copies with the MOTOR / late-submission rows; Wendy's copies are
`docs/iteration_summary.xlsx` and `docs/model_variations_register.xlsx`), `docs/wendy07_experiment_log.md`, Wendy's `handover/w9_handover/w9_handover/HANDOVER_W9.md`.

---

## 0. Quick start - get the submitted file back

```
Rscript docs/handover_final/replicate/replicate_final_submission.R
```

Runs in seconds from any folder (needs R with `data.table` and `arrow`; inside this repo it uses the renv library).
It rebuilds the final chosen submission from `replicate/inputs/`, writes `replicate/output/submission_final_replicated.csv`
and checks it against `submissions/submission_20261023_1636_w9_motor2_pre_m0.5.csv` - expected output:
`MD5 148a9f430289965107f40175dd2953ca ... Replication OK`.

| Folder / file | Content |
|---|---|
| `TAKEAWAYS.md` | This document |
| `MANIFEST.csv` | Every file in this folder with size and MD5 |
| `submissions/` | The final chosen submission (public 0.12965, private 0.13923) and the best-private file (MOTOR 7, private 0.13933) |
| `replicate/` | `replicate_final_submission.R` + `inputs/` (WENDY 9 panel 2025 rows per line, MOTOR 2 2025 predictions, Kaggle row order) |
| `rebuilt_models/` | Every model behind the submission refit from raw data on 24 Oct (section 6, "Full rebuild") |
| `scripts/` | Frozen copies of every script in the chain, `rebuild_all.ps1` (full rebuild) and `run_full_pipeline.ps1` |

---

## 1. Final outcome

| Rank (private) | Submission | Public | Private |
|---|---|---|---|
| 1 | MOTOR 7 in the WENDY 9 + MOTOR 2 pipeline (`submission_20261023_2223_w9_m2_motor07_A_FAIL.csv`) | 0.12904 | **0.13933** |
| 2 | WENDY 9 + MOTOR 2 motor member m 0.5 (`submission_20261023_1636_w9_motor2_pre_m0.5.csv`) | **0.12965** | 0.13923 |
| 3 | 0.12965 file + buildings stretch k 1.075 | 0.12888 | 0.13898 |
| 4 | WENDY 9 + MOTOR 2 per peril + stretch per line | 0.12826 | 0.13881 |
| 5 | `wendy08_w9best` | 0.12952 | 0.13872 |
| 6 | WENDY 9 | 0.12964 | 0.13864 |
| ... | WENDY 8 0.13842, WENDY 7 final 0.13817, final2 0.13781, SAM 3 0.13744, SAM 2 0.13739, BEN 3 0.13696, WENDY 4 0.13631, ... iteration 1 0.12679 | | |

Progress over the week (private): iteration 1 0.1268 -> SAM 2/3 0.1374 -> WENDY 7 0.1382 -> WENDY 9 0.1386 ->
WENDY 9 + MOTOR 2 0.1392 -> + MOTOR 7 0.1393.

**Final chosen submission:** `submission_20261023_1636_w9_motor2_pre_m0.5.csv` (MD5 `148a9f430289965107f40175dd2953ca`),
public 0.12965 (best public), private **0.13923** (2nd best private, 0.0001 below MOTOR 7). It was chosen on public
score, which was the information available before the private scores were revealed.

**Final chosen model** = per line:
1. WENDY 9 peril blend: per peril `w x LightGBM ladder + (1 - w) x WENDY 7 C5`, summed to the line
   (motor w: own_damage 0, TPP 1, BI 0, theft 0, glass_hail 1).
2. Line blend `b = LW x peril sum + (1 - LW) x SAM 3` (LW motor 0.9, buildings 0.7, contents 0.9).
3. Motor only: `b = 0.5 x b + 0.5 x MOTOR 2` (MOTOR 2 run `20261023_1359` rescaled to the total of b).
4. Credibility on own-policy history `M = (A + N) / (A + E)` (A = 8 / 5 / 5), rescaled to keep the line total.

Built by `R/6_blend_w9_motor2.R pre 0.5` from the WENDY 9 handover panel. MOTOR 7 (best private) differs only in step 1
for motor: TPP = average of 3 frequency versions, BI = MOTOR 2 spline GLM, theft = 50% average, each rescaled to the
WENDY 9 peril total.

---

## 2. Validation - the most important lesson

1. **Public leaderboard (33%) was too noisy to choose between close models.** Paired noise on the public part is about
   ±0.001. Examples (public vs private change):
   - WENDY 9 -> + MOTOR 2 member: public +0.00001, private **+0.0006**
   - WENDY 7 final2 -> motor replaced by MOTOR 2: public -0.0004, private **+0.0005**
   - 0.12965 file -> MOTOR 7: public -0.0006, private **+0.0001**
   - WENDY 7 final -> final2: public +0.00001, private **-0.0004**
2. **Local folds used for tuning are optimistic.** Gains measured on the same 2023-24 folds the settings were chosen on
   shrank a lot (MOTOR 2 member local +0.0016 -> private +0.0006).
3. **Post-hoc calibration tuned on the folds lost on both public and private:** dispersion stretch `q^k` (buildings
   k 1.075: local +0.0004 with bootstrap z 3.5, private -0.00025), per-peril re-weighting + k (local +0.002, private
   -0.0004). Local "significance" does not protect against choosing on the scoring folds.
4. **What worked: choose on one year, decide on another.** MOTOR 4/7: all choices on the 2023 fold (fit 2021-22),
   one decision on the untouched 2024 fold (fit 2021-23) scored against developed (IBNR-adjusted) cost, policy-clustered
   SE. It predicted the right direction (+0.0004 expected, +0.0001 private) where public pointed the wrong way.
5. **Score immature years on developed actuals.** 2024 reported cost is immature (motor BI only ~56% reported); score
   2024 on `reported / reported share` (developed) for level questions, and report both.
6. Rules to keep: decide from the held-out local test, not from public; a public move < 0.001 means nothing; never
   tune weights, stretches or levels on the folds you report.

---

## 3. Data and target learnings

- **Target** (confirmed by the organisers): expected ultimate cost net of excess and recoveries, excluding declined
  claims. `incurred_to_date` and `paid_to_date` are already net of excess but **before** recoveries -> use
  `incurred - recoveries`, repudiated = 0. Do not subtract the excess again.
- **Recoveries are only booked at settlement** (no open claim has one). Only motor own_damage (23.6% of incurred on
  closed claims) and motor theft (4.0%) recover; 2024 own_damage as booked is ~5.5% too high. WENDY 7 C5 deducts
  expected recoveries on open claims (`open_claim_recovery_adjust = Y`); MOTOR 1-7 do not (small effect, but fix it).
- **IBNR:** frequency on `exposure x reported share` (chain-ladder report pattern per peril, averaged over the row's
  days) works better than grossing up claims. Recommended pattern: `output/3b_ibnr/recommended_daily_share.csv`.
- **Bodily injury level:** open and closed BI claims have the same average severity in every loss year (0.97 / 0.91 /
  1.04, excluding one 11.9m claim), so case reserves look unbiased and the 2023-24 BI cost drop is real. Level ~200
  per exposure-year (W9/C5) was right; +20% / +45% BI probes were not needed.
- **One 11.9m BI claim** dominates the 2023 fold; cap claims (p99.5) and spread the excess as a loading; check results
  with and without it.
- **Leakage / noise fields** to exclude: `customer_service_contacts` (claim calls), `written_premium`,
  `discount_applied`, `renewal_decision`, `compulsory_excess` (constant), marketing fields, `noise_probe`.
- **Telematics:** only `telematics_opt_in` (12-13% of rows) and `telematics_score` (1-100); both are **fixed for the
  life of a policy** (no year-on-year change). The score carries some own_damage signal beyond opt-in (A/E 1.03 -> 0.71
  low to high score in 2023) but adds only ~+0.0003 to own_damage peril D2 and nothing to BI (MOTOR 6).
- **Claim history:** own-policy prior claims count is the strongest history feature; splitting it by collision / other
  perils, cross-line customer history and fraud-repairer flags added nothing on top (MOTOR 3, WENDY 8).

---

## 4. Model learnings

### What added value
| Change | Evidence |
|---|---|
| Per-peril frequency x severity instead of one line model | WENDY 4 -> 7, SAM 2 -> 3 |
| Report-share exposure for IBNR, chain-ladder pattern | SAM 3 (+0.0002 public), WENDY 7 |
| `voluntary_excess` in frequency and severity of every peril | WENDY 7 C4 |
| Blending different model families per line (WENDY 7 C4 + SAM 3) | vs SAM 3: +0.0011 public, +0.0007 private |
| Own-policy credibility `(A + N) / (A + E)` after the blend | WENDY 8 (+0.0006 private) |
| Spline GLM motor model as a 50% motor member (MOTOR 2) | private +0.0006 |
| BI frequency pooled with TPP (BI = TPP rate x small BI relativity GLM) | BI peril D2 0.070 / 0.062 vs 0.059 / 0.054 |
| Averaging model versions per peril (MOTOR 7) | better peril D2 in both years for 4 of 5 motor perils |

### What did not add value
- Post-hoc stretch / re-weighting tuned on the folds (see section 2).
- Penalised GAM for BI (MOTOR 5): smooths shrink to linear; the spline GLM already captures the shape.
- Plain LightGBM vs spline GLM for motor frequency: GLM as good or better (except theft); LightGBM started from the GLM
  (init score) helps TPP only.
- Telematics feature engineering (MOTOR 6), split claim history (MOTOR 3), premium_index (SAM 5), heavy tuning
  (WENDY 5: below WENDY 4 on public and private), deeper trees, top-K pruning, seasonality, severity trend variants (WENDY 9 ladder).
- Swapping a whole line to another model at a different level (splices #10, MOTOR 2 at SAM level) - level changes are
  risky; keep the best level and change only the ranking.

### Where the remaining headroom is (`R/6_peril_headroom.R`)
All-line D² gained per +0.01 peril D² inside the final pipeline:

| Peril | Payoff per +0.01 | Current peril D² |
|---|---|---|
| contents theft | 0.00046 | 0.035 |
| buildings escape_of_water | 0.00029 | 0.041 |
| buildings fire | 0.00027 | 0.027 (only ~290 claims / yr) |
| motor bodily_injury | 0.00022 | 0.055 |
| buildings flood, motor TPP, contents escape_of_water | ~0.00015 | |
| motor own_damage / theft / glass_hail | ~0 (already covered by the MOTOR 2 member) | |

---

## 5. How to improve next time (priority order)

1. **Set up the held-out protocol on day 1.** Choose everything on fold A (e.g. 2023), decide once on fold B (2024,
   developed actuals), policy-clustered SE, pre-registered rule. Use public only as a sanity check.
2. **Work the high-payoff perils:** contents theft (address / area theft rates, own theft history, security and
   occupancy fields, sum insured per room), buildings escape_of_water (history counts - Wendy's F6 recipe -, property
   age x freezing days), then buildings fire (simple GLM / stumps, pooled with all-peril propensity).
3. **Average, don't pick.** Average model versions / seeds per peril (MOTOR 7) and blend model families (GLM + GBM +
   SAM-style) rather than selecting one winner on noisy folds.
4. **Rebuild the blend weights honestly.** WENDY 9 peril weights, LW and the MOTOR 2 m 0.5 were all chosen on the
   2023-24 folds; re-choose them on one fold and check on the other (expect some shrinkage; Wendy found weight picks
   swap sign between years).
5. **Fix recoveries in the MOTOR models** (deduct 23.6% / 4.0% expected recoveries from open own_damage / theft).
6. **IBNER for long-tail perils** (BI, subsidence): open-claim development was assumed adequate; a development check by
   report year would firm this up.
7. **Process:** one shared panel of row-level fold predictions for every model (Wendy's `panel_<line>.parquet` format)
   made blending and A/B tests take minutes - build it from the start; keep runs reproducible (seeds, saved models,
   MD5 of every submission).

---

## 6. Where things are

| What | Path |
|---|---|
| Final chosen submission | `docs/handover_final/submissions/submission_20261023_1636_w9_motor2_pre_m0.5.csv` (MD5 `148a9f430289965107f40175dd2953ca`) |
| Best private (not chosen) | `docs/handover_final/submissions/submission_20261023_2223_w9_m2_motor07_A_FAIL.csv` (MD5 `a6e9d344a557ae31479108b30372cae8`) |
| WENDY 9 panel, blend code, reference | `handover/w9_handover/w9_handover/`; Wendy's current scripts `R/4_models_iterwendy08.R`, `R/4_models_iterwendy09.R`, `R/4_ladder_wendy09.R` |
| MOTOR 1 / 2 (spline GLM motor) | `R/4_models_itermotor01.R`, `R/4_models_itermotor02.R` -> `models/motor_iteration_01/02/` |
| MOTOR 2 into WENDY 9 (the final chosen file) | `R/6_blend_w9_motor2.R pre 0.5` |
| MOTOR 4 / 6 (LightGBM ladder on MOTOR features, telematics) | `R/4_models_itermotor04.R`, `R/4_models_itermotor06.R` (~25 min each) |
| MOTOR 7 (version averaging, no refit) | `R/6_motor_version_avg.R` (needs MOTOR 4 and 6 components) |
| Held-out evaluation and file writer | `R/6_w9_motor04_eval.R` (env `MOTOR04_DIR`, `EVAL_TAG`, `M4_VERS`) |
| Diagnostics | `R/6_peril_headroom.R`, `R/6_telematics_study.R`, `R/6_w9_motor_peril_check.R`, `R/3b_ibnr_study.R` |
| Run history and private results | `docs/workflow.md` (submission log, final results table) |

### Replicating the final submission

| Level | How | Time | Verified |
|---|---|---|---|
| A. From frozen inputs (self-contained) | `Rscript docs/handover_final/replicate/replicate_final_submission.R` (section 0) | seconds | yes - identical file, MD5 `148a9f430289965107f40175dd2953ca` |
| B. Full rebuild from raw data | `powershell -File docs/handover_final/scripts/rebuild_all.ps1` (restartable; progress in `rebuild/status.log`) | ~7 h | yes - run end to end on 24 Oct, results below |

### Full rebuild (24 Oct 2026, `scripts/rebuild_all.ps1`)

Run in a separate worktree from the raw Kaggle data, stage by stage:

| Stage | Script | Time | Check against the original |
|---|---|---|---|
| clean | `R/2_clean.R` | 5 min | |
| ibnr | `R/3b_ibnr_study.R` | 20 min | |
| sam3 | `R/4_models_itersam03.R` | 239 min | local D² 2022 / 2023 / 2024 0.1145 / 0.1046 / 0.0986 (original 0.1145 / 0.1043 / 0.0986); replication check passed |
| sam4data | copy of SAM 3's prepared data | - | |
| c5 | `R/4_models_iterwendy07.R` (final2 workbook, `RUN_TAG=c5`, `FINAL_FIT=1`) | 115 min | mean 2023-24 reported D² 0.1027 (original card 0.1026) |
| w9panel | `scripts/rebuild/build_w9_panel_2025.R` (Wendy's R port of WENDY 9) | 2-7 min | vs the submitted (Python) panel: N identical; E Spearman 0.99; ladder components level within 1%, Spearman 0.997-0.999 (subsidence 0.95) |
| motor2 | `R/4_models_itermotor02.R` | 43 min | **byte-identical** 2025 predictions (MD5 `643afe3be9f7755b881ed1a902fde717`) |
| blend | `replicate/replicate_final_submission.R` with `PANEL_DIR`, `M2_TEST` | seconds | see below |

Rebuilt submission vs the submitted file (`rebuilt_models/final/comparison_vs_submitted.csv`):

| Line | Total ratio | Pearson | Spearman | Median abs. difference | 99th pct abs. difference |
|---|---|---|---|---|---|
| motor | 0.9985 | 0.9996 | 0.9998 | 0.9% | 4.0% |
| buildings | 1.0005 | 0.9997 | 0.9995 | 1.3% | 6.5% |
| contents | 0.9997 | 0.9988 | 0.9996 | 1.3% | 6.6% |

Not byte-identical (SAM 3's tuning is time-budgeted, LightGBM / XGBoost threading, and WENDY 9 was originally built in
Python), but the same model to within ~1% per row. `rebuilt_models/` holds the refit models:

| Folder | Content |
|---|---|
| `sam3/` | SAM 3 fitted blends per line (`*_blend.rds`, load with `R/model_io.R`), model card, summary |
| `motor2/` | MOTOR 2 fitted model `motor02_peril.rds` (scored by `score_art2` in `R/4_models_itermotor02.R`), card, summary |
| `wendy07_c5/` | WENDY 7 C5 model card, scores, chosen methods, IBNR tables. The fitted C5 models (`fitted/*.rds`, 15 files, 1.4 GB) are too large for git - archived on Samuel's laptop in `Kaggle_IAA_handover_archive/wendy07_c5_fitted/` (next to the repo folder), together with `rebuild_outputs/` (rebuilt panel, C5 / SAM 3 / MOTOR 2 2025 predictions, stage logs); copy that folder to shared storage |
| `wendy09_ladder/` | WENDY 9 ladder LightGBM models (`<line>_<peril>_{freq,sev}.txt`, load with `lgb.load`) for the 8 perils with ladder weight > 0, plus `ladder_components_2025.csv` |
| `wendy08_history/` | Own-policy claim history N and expected count E per row (`history_<line>.parquet`) used by the credibility step |
| `final/` | Rebuilt submission, comparison with the submitted file, rebuild status log |

Where the remaining differences come from (one rebuilt component swapped in at a time, share of the row-level change):
buildings - WENDY 9 ladder 69% (subsidence alone 50%), C5 14%; contents - ladder 57% (flood 36%, escape_of_water 17%),
C5 31% (theft 27%); motor - C5 40% (bodily_injury 37%, also the -0.15% total), ladder TPP 28%, history E 25%.
MOTOR 2 is identical and SAM 3 identical for buildings / contents.

**Open item for Wendy - Python WENDY 9.** Rerunning WENDY 9 with the original Python (instead of the R port) would remove
most of the buildings / contents differences, but the handed-over `python_wendy09/` code is incomplete. Still needed from
Wendy's workspace (`/home/claude/w8`): `fe.py` (data load, features, category codes), `bench.py` (`BASE_EXCL`), the Python
WENDY 8 code that writes `hd_<line>.parquet` (N, E, `Np_<peril>`, `N_d0.6` / `E_d0.6` ...) and `claims_rows_<line>.parquet`,
and the `lad/` folder (`assemble_combo.json`, `sam3_test.parquet`). With those, `final_w9.py fit` + `build` reproduce her
panel; add them to `scripts/wendy09/python/`.

`docs/handover_final/scripts/` holds frozen copies of every script in the chain: `R/` (setup, cleaning, IBNR, SAM 3/4,
WENDY 7, MOTOR 1/2, blend, and the MOTOR 4/6/7 route), `wendy09/` (Wendy's WENDY 8/9 R ports, Python code, blend
scripts, weights and her handover note), `assumptions_wendy07_final2.xlsx` (C5 settings) and `features_used.csv`
(MOTOR 1 frequency features used by MOTOR 2). Raw data (`data/week_1/`) is not committed - download it from Kaggle.

Rebuild the MOTOR 7 file: `Rscript R/4_models_itermotor04.R`, `Rscript R/6_telematics_study.R`,
`Rscript R/4_models_itermotor06.R`, `Rscript R/6_motor_version_avg.R`, then
`MOTOR04_DIR=models/motor_iteration_07 EVAL_TAG=motor07 M4_VERS=glm,lgb,boost,avg3,avg2,m46 Rscript R/6_w9_motor04_eval.R`
(R 4.6.1 with renv; run from the repo root; the `components.parquet` files are >100 MB and not committed).

---

## 7. Private leaderboard analysis (24 Oct)

The full list shows the motor work helped on private even though public barely moved, and our two best private scores
are the MOTOR 7 file and the 0.12965 file.

**Top private scores:**

| File | Public | Private |
|---|---|---|
| MOTOR 7 averaged motor perils | 0.12904 | **0.13933** |
| WENDY 9 + MOTOR 2, m0.5 (the 0.12965 file) | **0.12965** | 0.13923 |
| Buildings stretch k 1.075 | 0.12888 | 0.13898 |
| Per-peril MOTOR 2 weights + stretch | 0.12826 | 0.13881 |
| `wendy08_w9best` | 0.12952 | 0.13872 |
| WENDY 9 | 0.12964 | 0.13864 |
| WENDY 8 (final2 + credibility) | 0.12945 | 0.13842 |
| final2 with MOTOR 2 motor | 0.12887 | 0.13830 |
| WENDY 7 final | 0.12924 | 0.13817 |
| WENDY 7 final2 | 0.12925 | 0.13781 |

**What the private scores show:**
- **MOTOR 2 helped every time it was added, which public hid.**

  | Change | Public | Private |
  |---|---|---|
  | WENDY 9 → WENDY 9 + MOTOR 2 (m0.5) | +0.00001 | +0.0006 |
  | final2 → final2 with MOTOR 2 motor | −0.0004 | +0.0005 |
  | 0.12965 file → MOTOR 7 | −0.0006 | +0.0001 |

- **Public often ranked submissions differently from private:**
  - WENDY 7 final and final2 were equal on public, but final2 was 0.0004 worse on private.
  - Wendy's own files, which looked best on public (0.1295–0.1296), all scored below our motor-blend files on private.
- **Adjustments tuned on the 2023–24 years lost on private as well:**
  - The buildings stretch lost 0.00025 against the 0.12965 file.
  - The per-peril weights with stretch lost 0.0004.
- **Choosing on one year and checking on the other worked.** It gave the right direction for MOTOR 7, while public
  pointed the wrong way.

**For future rounds:**
- Decide from the local held-out-year check, not the public score; a difference under 0.001 on public doesn't mean
  anything.
- Don't stretch or re-weight predictions using the same years you score on.
- Averaging versions of a model (MOTOR 7) is a cheap, safe gain.

The full public / private table for every team submission is in `docs/workflow.md` (submission log, "Final results").
