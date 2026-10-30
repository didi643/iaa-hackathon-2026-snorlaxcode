# WENDY 7 experiment log - reasoning per step

Goal set by Wendy (22 Oct): raise local D2 (mean 2023-24, reported_raw, ALL) towards 0.25 and public D2 towards 0.20.
Starting point: SAM 3 public 0.12818 / local 0.1015; WENDY 4 public 0.12671 / local 0.1008.

Ground rules kept throughout: one change per run; judge on the local protocol (handoff section 3) with a paired
policy bootstrap; no leakage fields (`customer_service_contacts`, `renewal_decision`), no `written_premium`, no
tuning to the public board; no Kaggle submission without Wendy's approval.

## Step 0 - environment
- R 4.6.1 (Homebrew) had none of arrow / xgboost / lightgbm / readxl / ggplot2: installed from CRAN source.
- `data/week_1/clean/` did not exist: ran `week1/R/2_clean.R` and `week1/R/3_incidence.R` (needed by the WENDY 4 engine).

## Step 1 - tooling
- `week1/R/oof_io.R`: writes / reads `row_preds.parquet` (line level) and `row_preds_peril.parquet` (per peril and method),
  scores them on the three bases, and bootstraps the difference in **mean 2023-24** D2 between two runs (policies
  resampled once per draw for both folds, so the folds stay correlated). Reason: every later blend (backlog C) and
  every keep / drop decision needs the same row predictions and the same noise band.
- `week1/R/4_models_iterwendy07.R`: WENDY 4 engine unchanged up to section 6; adds `ibnr_method`, the protocol validation
  (3 bases, both methods fitted where the workbook allows a Tweedie challenger), a fixed method mix (WENDY 4's picks)
  so an IBNR run changes only the IBNR, and an optional final fit with a replication check.

## Step 2 - smoke test and first IBNR finding (FAST mode, chain ladder)
- Why: catch code errors cheaply before ~40 full fits per variant.
- Result: runs end to end; local ALL 0.1009 (FAST, fewer rounds).
- Actuarial finding (`week1/models/wendy_iteration_07/smoke_a2/ibnr_shares_by_year.csv`): for short-tail perils A0
  says 2024 rows are ~99.5% reported, the count chain ladder says ~95-98% (motor TPP 0.94, BI 0.56 vs 0.63,
  subsidence 0.67 vs 0.75). A0 reads the lag ECDF at the row's mid-date, ~180 days before valuation. That misses
  the Q4 2024 losses still to be reported (the ECDF is convex near 0, so F(mean lag) > mean F(lag)). A1 (average
  over the row's days) should agree with the chain ladder; both mostly affect the 2024 fold and the 2025 final fit.

## Step 3 - how much D2 is there? (`week1/R/4_check_ceiling.R`)
- Why: the 0.25 local / 0.20 public goal is ~2.5x the best result so far, so before tuning I checked whether it is
  attainable. Method: treat the row predictions as the true expected cost, simulate Poisson claim counts and Gamma
  severities (each peril's observed mean and CV) and score the predictions on the simulated actuals. That is the
  D2 of a *perfect* model if the true risk spread equals the model's. Then widen the log relativities by k.
- Result (mean of 3 simulations; local actual of the same predictions = 0.1009):

  | spread k | ALL | buildings | contents | motor |
  |---|---|---|---|---|
  | 1.0 | 0.101 | 0.065 | 0.070 | 0.040 |
  | 1.5 | 0.152 | 0.112 | 0.125 | 0.097 |
  | 2.0 | 0.219 | 0.166 | 0.182 | 0.180 |
  | 3.0 | 0.381 | 0.284 | 0.334 | 0.399 |

- Reading: the model scores on real data exactly what it would score if it were the truth, so its relativities
  are neither too flat nor over-fitted. A perfect model reaches 0.25 only if true risk differences are ~2.2x wider
  (in log terms) than any of the WENDY / SAM / BEN pipelines found. All of them, built differently, plateau at
  0.10-0.105, which points to irreducible claim noise rather than missing signal. **0.25 is not a realistic
  honest target**; gains should be expected in the +0.001-0.005 range. Leakage fields would inflate local D2 and
  are excluded on purpose (the test rows do not carry the same signal).

## Step 4 - A0 reproduction
- Why: WENDY 7 must equal WENDY 4 before any change can be attributed to the change.
- Result: actuals identical row by row; predictions correlate 0.996-0.999 with the reference re-score (xgboost
  3.2.1 here). Local mean 0.1014 vs 0.1008, mostly the 2023 motor fold. **Environment / version noise is ~0.001 on
  one fold**; a rerun in this environment reproduces 0.1014 exactly, so today's A0 (`wendy07_a0`) is the baseline.

## Step 5 - IBNR variants A1 / A2 on the local protocol
| Run | Change vs A0 | ALL | motor | buildings | contents |
|---|---|---|---|---|---|
| A0 | WENDY 4 mid-date ECDF | 0.1014 | 0.0458 | 0.0716 | 0.0672 |
| A1 | ECDF averaged over the row's days | 0.1014 | 0.0458 | 0.0717 | 0.0672 |
| A2 | chain ladder on counts (quarterly triangle) | 0.1015 | 0.0460 | 0.0717 | 0.0672 |
- Reading: expected to be flat. In the folds the training rows (2021-22, 2021-23) are almost fully reported under
  every method, so the IBNR choice barely changes them. The IBNR matters for the final fit, where 2024 is a
  quarter of the data and sets the trend.

## Step 6 - IBNR judged directly: one-year-ahead backtest (`week1/R/4_check_ibnr_backtest.R`)
- Why: local D2 cannot rank IBNR methods (step 5), but the methods disagree by 3-11% on 2024 (motor BI ultimate
  frequency per 1,000: A0 9.4 vs chain ladder 10.5, against 10.8-11.4 in 2021-23).
- Method: value at 31 Dec 2023 with only the claims reported by then, project each loss quarter to 31 Dec 2024,
  compare with the claims actually reported by 31 Dec 2024.
- Result, loss year 2023 projected / actual: A0 0.971 (short-tail perils 0.945-0.979), A1 0.998, chain ladder 0.999.
  Subsidence is the exception (A0 1.03, A1 1.06, chain ladder 1.12: sparse triangle).
- Decision: **chain ladder for every peril except buildings subsidence (A1)**, `IBNR_OVERRIDE` added.
  A0 under-states the latest year's frequency, which pushes the 2025 level and the frequency trends down.

## Step 7 - excess in every peril (B6)
- Why: an excess removes small claims (frequency) and takes a slice off every claim (severity), so it belongs in
  both parts of every peril. The workbook lacked it for motor BI entirely, for flood / storm / subsidence severity
  and for fire frequency.
- Result: ALL 0.1014 -> 0.1024 (motor +0.0018, buildings +0.0007). By peril the gains are where excess was missing:
  BI Tweedie +0.0055, fire freq_sev +0.0053, flood +0.002. Perils whose features did not change moved by up to
  +-0.0005 (column order changes xgboost's column sampling): that is the per-peril noise floor.

## Step 8 - line level (C2) and the BI "over-prediction"
- Why: motor predictions are 1.04x (2023) and 1.09x (2024) developed actuals; D2-optimal motor scale 0.92-0.96.
- Finding: the excess is motor BI (1.15x / 1.17x developed in both folds). BI severity falls from ~22k (2021-22) to
  ~18k (2023-24), median 13.4k -> 9.8k, while open claims rise to 49% / 80%: immature case estimates (IBNER). The
  developed basis develops counts only, so recent BI actuals are understated.
- Decision: **no downward level scaling**. It would raise local D2 by fitting immature actuals, while Kaggle scores
  ultimate 2025 cost.

## Step 9 - per-peril blend of freq_sev and Tweedie (B3 / C1, `week1/R/4_blend_wendy07.R`)
- Why: per peril WENDY 4 picks one method; the two models make partly independent errors, so a weighted average
  should beat either. Weights (grid 0.25) chosen by coordinate ascent on ALL-lines D2; honesty check = choose on one
  fold, score the other.
- Result on A0: cross-fold gain +0.0011 (2023 -> 2024) and +0.0011 (2024 -> 2023); in-sample 0.1014 -> 0.1027.
  Consistent in both directions, so it is kept.

## Step 10 - bootstrap noise threshold (`week1/R/4_compare_wendy07.R`, 200 policy draws, mean 2023-24, reported_raw)
| Run vs A0 | diff ALL | 2 x SE | draws better | verdict |
|---|---|---|---|---|
| A1 | +0.00004 | 0.00011 | 75% | within noise |
| A2 | +0.00014 | 0.00038 | 69% | within noise |
| B6 | +0.00102 | 0.00107 | 100% | borderline (buildings alone > 2 SE) |
- **Noise threshold for Submit_Gate B1: ~0.0011 on ALL** (replaces the 0.001 placeholder).

## Step 11 - combinations and seed bagging
| Run | Setup | ALL | motor | buildings | contents |
|---|---|---|---|---|---|
| B4 | A0 + HIST_V2 (address peril history, policy credibility) | 0.1020 | 0.0468 | 0.0722 | 0.0671 |
| C1 | chain ladder + excess + HIST_V2 | 0.1020 | 0.0471 | 0.0718 | 0.0671 |
| C2 | chain ladder (subsidence A1) + excess | 0.1018 | 0.0463 | 0.0722 | 0.0671 |
| C2 bag5 | C2 with 5 seeds / holdouts per component | 0.1017 | 0.0454 | 0.0729 | 0.0675 |
- Reading: every combination sits inside +-0.0006 of 0.1018, i.e. inside the noise band. Gains do not stack:
  B6's motor 0.0476 was partly a lucky single draw; with 5 bags motor settles at ~0.0455 while buildings
  (+0.0007) and contents (+0.0004) improve, as variance reduction should. HIST_V2 adds nothing beyond excess:
  dropped. Bagging is kept for the final fit because it lowers variance on the unseen 2025 rows.

## Step 12 - per-peril method blend re-checked on the bagged run
- Selected weights: cross-fold -0.0025 (2023 -> 2024) / +0.0004 (2024 -> 2023), so the step-9 gain did not survive.
- Fixed, unselected weights (no optimism), mean ALL: WENDY 4 mix 0.10167 > 75/25 0.10151 > 50/50 0.10100 >
  all freq_sev 0.10097 > all Tweedie 0.09929.
- Motor shows why: freq_sev wins 2023 (0.0454 vs 0.0400), Tweedie wins 2024 (0.0472 vs 0.0420). The best method
  flips by year, so any weight chosen on one year is noise for the next.
- Decision: **keep WENDY 4's per-peril method mix; no method blend.**

## Step 13 - final fit C3 and the 2025 motor level
- C3 = chain ladder (subsidence A1) + excess everywhere + 5 bags, WENDY 4 method mix, both methods fitted in the
  final fit. Local mean 0.1017 (= C2 bag5, deterministic); replication check passed (max diff 0).
- 2025 burn per exposure-year: motor 546 / buildings 488 / contents 126; SAM 3: 603 / 487 / 125.
- Motor gap traced to bodily injury: C3 predicts 177 for 2025, below every year's chain-ladder developed burn
  (2021 245, 2022 240, 2023 202, 2024 187). The final BI Tweedie fits a frequency trend of -2.7%/yr and severity
  -2%/yr on cost per exposure.
- Is the BI decline real or immaturity (IBNER)? At equal reporting delay 2023-24 BI claims are 15-20% cheaper than
  2021-22, closed claims included; but recent closed claims are the fast-settling (smaller) ones, so selection
  explains part of it. One valuation date cannot separate the two: the ultimate BI level is uncertain between
  roughly 180 and 240.
- Decisions: (1) **no trend extrapolation for BI** (`SPEC_EDITS=motor/bodily_injury:freq_trend=none,sev_trend=none`,
  run C4): hold the recent level instead of projecting an uncertain decline; (2) blend the motor level with SAM 3
  (step 14): when the right level is uncertain, the average of two levels has lower expected Tweedie deviance than
  either alone (the loss is convex).

## Step 14 - C4: BI without trend
- C4 = C3 + `SPEC_EDITS=motor/bodily_injury:freq_trend=none,sev_trend=none`. 2025 BI burn 177 -> 200 (motor line
  546 -> 569), still below the mature 2021-22 levels (240-245). Local motor 0.0454 -> 0.0448 (within noise; the
  local actuals carry the same immaturity, so a higher BI level cannot score better locally). Replication passed.
- Chosen over C3 on actuarial grounds: projecting an uncertain decline is the riskier error for an ultimate target.

## Step 15 - WENDY 7 x SAM 3 line blend (C1, `week1/R/4_check_sam03_oof.R`, `week1/R/4_final_wendy07.R`)
- Why: WENDY 4 and SAM 3 tie locally (0.10136 / 0.10135) but are built differently (WENDY: workbook-driven xgboost
  freq x sev / Tweedie per peril; SAM: GLM + xgboost per peril with claim-history features, own cleaning, greedy
  line blend). Row predictions correlate only ~0.95, so their errors partly cancel.
- SAM 3's out-of-time predictions were regenerated by running its own script up to the end of validation (cache
  redirected to `data/week_1/wendy07_sam03`, nothing of SAM 3 overwritten); its actuals equal ours row for row.
- Weight per line on the mean 2023-24 reported_raw D2 (grid 0.1): 0.5 / 0.5 in all three lines with C4.
  Cross-fold gains all positive: motor +0.00023 / +0.00092, buildings +0.00134 / +0.00015, contents +0.00095 / +0.00054.

| Candidate | local mean D2 ALL | motor | buildings | contents | vs SAM 3 (2 x SE) |
|---|---|---|---|---|---|
| SAM 3 (rerun, best public 0.12818) | 0.10135 | 0.0446 | 0.0729 | 0.0673 | - |
| WENDY 7 C4 alone | 0.10143 | 0.0448 | 0.0729 | 0.0675 | +0.00008 (0.00094), noise |
| **WENDY 7 final = 0.5 C4 + 0.5 SAM 3** | **0.10228** | 0.0456 | 0.0740 | 0.0684 | **+0.00093 (0.00047), 100% of draws** |

- 2025 burn per exposure-year of the final file: motor 586, buildings 488, contents 126.
- File: `week1/output/submission/submission_20261022_2135_wendy07_final.csv` (MD5 8535c6833aafd1299ad8d5cd9887448d),
  626,639 rows in sample order, no NA, min 0.057. **Not submitted** - Wendy decides.

## Conclusion
- Best honest local score: 0.10228 (from 0.1014 / 0.10135 at the start). The 0.25 goal is not reachable: a perfect
  model scores about what the current models score unless true risk differences are ~2.2x wider than every pipeline
  finds (step 3), and all real gains this session were +0.0003 to +0.0011.
- Expected public score of the final file: around SAM 3's 0.128 plus roughly the local gain, i.e. ~0.129-0.130,
  with extra upside or downside from the 2025 motor level (BI), which local validation cannot test. A public score
  of 0.20 should not be expected from any honest model of this data.
- Kept: chain-ladder IBNR (subsidence A1), excess in every peril, 5-seed bagging, BI without trend, WENDY 4 method
  mix, 50/50 line blend with SAM 3. Dropped: HIST_V2, per-peril method blends, downward level scaling.
- Housekeeping: `wendy07_report_share` and `wendy07_smoke_a2` outputs are from before the frozen-snapshot runs
  (smoke / possibly mixed script versions) - use `wendy07_a0` etc. instead.

## Step 16 - public result (submission #10)
- Public D2 **0.12924** (SAM 3 0.12818): +0.00106 public vs +0.00093 local. The local protocol (mean 2023-24
  reported_raw D2 with a paired policy bootstrap) predicted the public gain within 0.0002 - the gate works and is
  the tool to use for the next candidates.
- Still open: the 2025 motor BI level (the blend sits between WENDY 7 and SAM 3); BI level and longer bags are the
  next levers, with expected gains of the same order (~0.001).

# Round 2 - goal local 0.135 (set 22 Oct, after #10 public 0.12924)
Starting point: local mean 0.10228 (submission #10). Reading: +0.033 is ~30x the typical honest gain and above the
simulated ceiling (step 3), so it is not expected; the search is done carefully so that what is found is real.

## Step 17 - richer per-line stack (`week1/R/4_stack_wendy07.R`)
- Why: SAM 3 has six candidates; its peril GLM is the most different model from WENDY 7 in motor (correlation
  0.90) and the best motor model on 2023, so a stack might beat the 50/50.
- Result: in-sample 0.10256 (+0.0003 vs 50/50), weights motor 0.5 W7 / 0.3 GLM / 0.2 xgb Tweedie. Cross-fold vs
  WENDY 7 alone: motor -0.0012 / -0.0014, buildings +0.0011 / -0.0002, contents +0.0011 / +0.0005. The plain 50/50
  had positive cross-fold gains in all three lines, so the extra weights are fitting year noise.
- Decision: keep the 50/50 line blend; no richer stack.

## Step 18 - per-peril lab (`week1/R/4_peril_lab_wendy07.R`, `week1/R/4_peril_lab_select.R`)
- Why: find, peril by peril, which features / settings / method fit best, judged on what Kaggle scores (ALL-lines
  D2 with that one peril swapped into an unchanged baseline), not on the peril's own D2.
- Design: C4 settings at 1 bag, three folds (2022 / 2023 / 2024). 269 variants over 15 perils: other method, drop
  one feature group (admin, finance, realised weather, history, geography, high-cardinality, customer), add long-run
  address weather / customer_age / line extras, depth +-1, min_child_weight x0.5 / x2, cap quantile, Tweedie power,
  severity model, frequency trend on / off. Rule: mean 2023-24 gain > 0.00005, no year (incl. 2022) losing > 0.0001.
- Result: single changes move ALL D2 by +-0.0001 to 0.0006. 10 perils had a passing variant; sum of their gains
  +0.0020 (upper bound, optimistic after picking from 269). BI: every alternative loses except restoring the trend.
- Actuarial screen of the winners (a variant that only wins on immature or noisy data is a trap):
  - rejected: motor BI trend back on (+0.00057; wins because local actuals share the IBNER the trend picks up);
    buildings storm without wind / hail / rainfall (a storm model without wind is not credible; +0.00009);
    contents escape of water without freezing days (frost bursts pipes; 2022 -0.00008).
  - accepted: motor own damage freq_sev instead of Tweedie (+0.0005, both years); motor TPP without freezing days /
    rainfall (+0.00036, 2022 +0.00012); Gamma GLM severity for buildings escape of water, motor theft, contents theft;
    buildings fire min_child_weight 30 -> 15; buildings flood without days_quote_to_inception / start_month.
- Confirmation: run C5 = C4 + accepted changes, 5 bags, 2023-24 folds, final fit.
- Confirmation result (5 bags): WENDY 7 alone 0.10143 (C4) -> **0.10255 (C5)**, motor +0.0021, buildings +0.0004,
  contents +0.0004. Replication passed; 2025 burn motor 564 / buildings 488 / contents 126.

## Step 19 - new candidate: C5 x SAM 3 line blend (final2)
- Weights (grid 0.1, mean 2023-24): motor 0.8 WENDY 7, buildings 0.5, contents 0.6. Cross-fold gains vs WENDY 7
  alone all positive (motor +0.0001 / +0.0001, buildings +0.0011 / +0.0004, contents +0.0008 / +0.0005).
- Motor weight 0.5 -> 0.8 gains ~+0.0004 in 2023 and in 2024 alike (C5's motor is now better than SAM 3's), so the
  protocol's choice is kept; it lowers the 2025 motor level from 586 (#10) to 572 - the main risk to watch on public.

| Candidate | local mean D2 ALL | 2023 | 2024 | vs #10 (2 x SE) |
|---|---|---|---|---|
| #10 (0.5 C4 + 0.5 SAM 3), public 0.12924 | 0.10228 | 0.1054 | 0.0992 | - |
| C5 alone | 0.10255 | | | +0.00027 (0.00079), noise |
| **final2 (C5 x SAM 3)** | **0.10302** | 0.1062 | 0.0998 | **+0.00074 (0.00051), 100% of draws** |

- File `week1/output/submission/submission_20261022_2328_wendy07_final2.csv` (MD5 99135ba796a021c92c186e3e7bf71d3f),
  626,639 rows in sample order, no NA. Not submitted. #10's row predictions are kept in `wendy07_sub10`.
- Against the 0.135 goal: local is 0.103. The lab tried every single-peril change on the list and the combined
  honest gain was +0.0007 over #10; reaching 0.135 would need ~45 times that.

## Step 20 - status
- 23 Oct: Wendy put final2 on hold; not submitted. #10 (public 0.12924) stays the best submitted model.

## Step 21 - documentation (23 Oct)
- `week1/docs/wendy07_experiment_register.xlsx` (built by `week1/R/7_export_wendy07_register.R`): every run, blend, feature change and lab variant with settings, scores, deltas, bootstrap verdicts and decisions.
- `week1/docs/assumptions_wendy07_sub10.xlsx` (#10, submitted) and `week1/docs/assumptions_wendy07_final2.xlsx` (on hold), built by `week1/R/7_export_wendy07_workbook.R`: WENDY 4-style workbooks with every change baked in and highlighted. `week1/R/7_verify_wendy07_workbook.R` confirmed each reproduces its run setup exactly (feature map, Model_Spec, IBNR, bags, method mix). `week1/R/4_models_iterwendy07.R` now also reads ibnr_override / bags / method_mix from the workbook (environment still wins).
