# Handoff to Claude Code - IAA Hackathon 2026: IBNR and frequency x severity experiments

Prepared 22 Oct 2026 from the review of every `week1/R/4_models_*.R` script, the submission log in `week1/docs/workflow.md`,
`week1/docs/model_variations_register.xlsx` and `week1/docs/iteration_summary.xlsx`. Read this file first, then
`week1/docs/workflow.md` (Step 6 and the submission log) and the two workbooks.

## 1. Task and rules (unchanged)

- Predict the 2025 expected ULTIMATE claim cost per row of `test_motor`, `test_buildings`, `test_contents`
  (net of excess and recoveries, repudiated claims excluded). One CSV `row_id,prediction`, 626,639 rows, >= 0.
- Metric: Tweedie D² (p = 1.5), higher = better. Public board = part of the test set; final ranking may use the rest.
- Work in **R** (data.table, arrow, xgboost, lightgbm, ggplot2). Python only if R cannot do a step.
- Every script sources `week1/R/0_setup.R`. Earlier iteration scripts are **frozen**: copy, rename, change.
  New iterations: `week1/R/4_models_iter<name><NN>.R` -> `week1/models/<name>_iteration_<NN>/`. Never write into another
  iteration's folder or cache (`data/week_1/sam02` belongs to SAM 2, `data/week_1/sam03` to SAM 3).
- **Excess is a model feature in every test** (`voluntary_excess`, monotone -1 on frequency; drop
  `compulsory_excess` - it is constant). No ground-up rebuild.
- Guardrails: no `renewal_decision`, `customer_service_contacts` (leakage), `written_premium` (current price),
  marketing / noise fields; drop `noise_probe` before any final fit.

## 2. Where we are (public scores, 22 Oct)

| # | Iteration | Public D² | What it is |
|---|---|---|---|
| 9 | SAM 3 | **0.12818** (best) | SAM 2 + frequency IBNR via effective exposure (exposure / IBNR factor) |
| 7 | SAM 2 | 0.12796 | Raw rebuild, claim-history features, per-peril trended GLM level, LGB/XGB bags, greedy blend |
| 6 | WENDY 4 | 0.12671 | Per-peril Poisson GBM freq x Gamma GBM/GLM sev (vs Tweedie), ultimate frequency (report-share volume), sev trend |
| 8 | WENDY 5 | 0.12636 | WENDY 4 + random-search tuning + method chosen on policy-grouped CV (mixes years) - worse |
| 5 | BEN 1 | 0.12224 | XGB Tweedie per line, feature fixes, trend, time-fold tuning |
| 2 | ITER 2 | 0.12149 | XGB Tweedie per line |
| 4 | WENDY 3 | 0.12132 | XGB Tweedie per peril |
| 1 | ITER 1 | 0.11904 | GLM freq x sev per line, no trend |
| 3 | SAM 1 | 0.11876 | GLM/LightGBM blend |
| - | WENDY 4 on SAM 2-clean data | not submitted | local reported 2024 identical to WENDY 4 -> cleaning made no difference |
| - | WENDY 6 (H2O AutoML) | running | same basis/folds as WENDY 5 |

What moved the public score (details: `iteration_summary.xlsx`, sheets Change_Levers and BEN1_Ladder):
- **Keep:** per-peril frequency x severity; ultimate-level frequency (IBNR inside the frequency exposure); trend
  to 2025; claim-history features; expanding window (fit 2021-24); light / no tuning; per-line blend of GLM + XGB.
- **Stop:** LightGBM components (weight 0 in SAM 3); Tweedie-only per-peril trees; heavy random-search tuning;
  method choice on CV that mixes years; rolling windows; choosing on the 2023 fold alone.
- SAM 3's gain over SAM 2 (+0.00022) came from **down-weighting immature 2024 rows** (same expected rate, weight
  exposure / f instead of exposure). Severity was already observed capped claims in SAM 2.
- In SAM 3's own components, the motor GLM ranks best (d2_cal 0.0538 vs blend 0.0535) -> keep a GLM in motor.

## 3. Local validation protocol (use for every experiment)

Reference implementation: `week1/R/4_check_reported_w4.R` (re-scores a WENDY 4-style script without refitting the code)
and `week1/R/4_check_reported_compare.R` (paired policy bootstrap). Re-use their output format.

1. Folds: fit 2021-22 -> score 2023; fit 2021-23 -> score 2024 (optionally fit 2021 -> 2022 as a third).
2. Score the SAME predictions on three actual bases:
   - `reported_raw` = booked cost at 31 Dec 2024 (`y_cost_<peril>`, no 2m limit) - same basis as SAM 2 / SAM 3;
   - `reported_adj` = WENDY 4 claim basis (open-claim recoveries, 2m single-claim limit);
   - `developed` = reported_adj / report share.
3. Primary selection score = **mean of 2023 and 2024 on `reported_raw`** (it ranked WENDY 4 < SAM 3 correctly,
   2024 alone did not). Report developed too.
4. Save `row_preds.parquet` per run: `valid_year, line, row_id, policy_id, exposure, pred, reported_raw,
   reported_adj, developed` (line level) and, new, a per-peril version (`pred_<peril>`), so blends can be chosen later.
5. Compare candidates with `week1/R/4_check_reported_compare.R` (policy bootstrap, 200 draws). A change counts only if
   |difference| > 2 x bootstrap SE. Record it in `iteration_summary.xlsx` sheet **Submit_Gate**
   (B1 = noise threshold; replace the 0.001 placeholder with the measured 2 x SE).

Reference local scores (reported_raw, mean 2023-24, ALL): SAM 3 0.1015, SAM 2 0.1014, WENDY 4 0.1008
(WENDY 4: 2023 0.1028 / 2024 0.0988; motor 2023 hit by the 11.9m bodily-injury claim).

## 4. Experiment backlog

Start from the **WENDY 4 engine** (`week1/R/4_models_iterwendy04.R`: workbook-driven, per peril, freq x sev / Tweedie)
because every assumption is a setting; port the winners into the SAM 3 pipeline afterwards. Change one thing per run.

### A. IBNR treatment (late reporting)
Only one valuation date exists, but every claim has `loss_date` and `report_date`, so **reported-count triangles
can be built** (loss period x reporting delay). Incurred / paid development cannot (no history of case estimates).

| ID | Variant | Note |
|---|---|---|
| A0 | Current WENDY 4: report-share ECDF of 2021-22 lags at the row mid-date, frequency volume = exposure x share | baseline |
| A1 | Report share averaged over the row's days (not mid-date) | Code_Review CR18 |
| A2 | **Chain ladder on claim counts** per peril: loss quarter x development quarter triangle from report lags, volume-weighted age-to-age factors, tail = 1 after the longest observed lag; ultimate counts per loss quarter -> per-row factor | main new test |
| A3 | Bornhuetter-Ferguson on counts for 2024 (a priori frequency = 2021-23 trended) | stabler for BI / subsidence |
| A4 | SAM 3 weighting: rate = n x f / exposure, weight = exposure / f (vs A0's volume offset) | compare with A0 |
| A5 | Lag pattern from 2021-23 losses (lags truncated) instead of 2021-22 | more data, censoring risk |
| A6 | Drop 2024 from frequency fits of long-tail perils (BI, subsidence); keep for others | |
| A7 | Severity of immature claims: (a) all claims, (b) closed only for long-tail perils, (c) open x open/closed ratio from `open_claim_case_check.csv` | IBNER proxy |

### B. Frequency x severity mixture per peril
| ID | Variant |
|---|---|
| B1 | Frequency learner per peril: Poisson GBM (WENDY 4) vs quasi-Poisson GLM (SAM) vs 50/50 blend |
| B2 | Severity per peril: Gamma GLM vs Gamma GBM vs mean (sparse perils: fire, subsidence, flood); pick on mean reported_raw D2 |
| B3 | Method per peril: freq x sev vs Tweedie vs blend weights 0 / 0.25 / 0.5 / 0.75 / 1 |
| B4 | Add SAM's address peril history (`hist_addr_flood/water/subs/storm`) and policy history to the WENDY 4 workbook |
| B5 | Cap quantile per peril 0.99 / 0.995 / 0.999 and the 2m single-claim limit vs claim cap + loading |
| B6 | Excess fix: `voluntary_excess` in every peril's frequency and severity (WENDY 4 motor BI and SAM rare-peril / severity GLMs lack it) |

### C. Combination
- C1: per line and per peril blend of SAM 3 and WENDY 4 (and the best A/B variant) using saved row predictions,
  weights chosen on the mean 2023-24 reported_raw D2 (non-negative, sum to 1, grid 0.1).
- C2: level check per line: pred / developed actual by fold; scale sensitivity 0.95-1.05.

Known per-peril evidence (WENDY 4, `test/4_check_reported_w4` outputs, D2 vs developed):
freq_sev clearly beats Tweedie for buildings flood (0.47 vs 0.15 in 2023), contents flood, buildings fire
(Tweedie -0.08 in 2024); Tweedie wins motor own_damage and BI (narrowly) and contents escape_of_water.
Motor BI predictions are 1.2-1.5x developed actual in 2024 - check the BI level.

## 5. Known code issues to fix in new scripts (`model_variations_register.xlsx`, sheet Code_Review)
- CR12 / CR40: `noise_probe` stays in SAM 2 / 3 final trees. CR13: `customer_since_year`, `years_with_insurer`,
  `compulsory_excess`, uncapped `renewal_count` in SAM trees.
- CR27: `4_models_iterwendy04_vsam02clean.R` defaults to `data/week_1/sam02` (SAM 2's cache) - set `SAM02_DATA_DIR`.
- CR42: SAM 3 line Tweedie bags still use the IBNR-inflated target.
- CR17: WENDY 4 has no replication check (WENDY 5 has one - copy it).

## 6. Deliverables expected from each run
1. Script + `week1/models/<iteration>/` card with: settings, line_scores (3 bases x folds), peril_scores, chosen methods,
   row_preds (line and peril), 2025 burn cost per line, replication check, run time.
2. One row added to `week1/docs/workflow.md` (submission log only if submitted) and to the workbooks
   (`iteration_summary.xlsx`: Line_Scores, Submit_Gate; `model_variations_register.xlsx`: a new Variations column).
3. Do NOT submit to Kaggle unless Submit_Gate says "Submit"; ask Wendy before any submission.

## 7. Repository contents (this bundle = clean-slate starting point)

Data is NOT included: extract `iaa-ai-assisted-hackathon-2026-part-1.zip` into `data/week_1/raw data/`, then run
`week1/R/2_clean.R` and `week1/R/3_incidence.R` (needed by ITER 1-WENDY 6). SAM 2 / SAM 3 / WENDY 4 SAM02-clean rebuild
their own data from `data/week_1/raw data/`. `week1/models/` folders other than `sam_iteration_03` are not in the bundle
(regenerate by running the scripts).

| Path | What |
|---|---|
| `week1/R/0_setup.R` | Shared paths, constants (valuation date 2024-12-31, p99.9 cap, Tweedie p 1.5, seed), `NON_FEATURES`, `feature_cols()` |
| `week1/R/1_eda.R`, `week1/R/eda_helpers.R` | Raw EDA and column plots |
| `week1/R/2_clean.R` | Cleaning (traps 1-11: id padding, exposure recompute, sum_insured /1000, construction_type, unmatched / duplicate claims, leakage), claim matching, row targets `y_*`, `premium_index`, `wx_avg_*` -> `data/week_1/clean/` |
| `week1/R/3_incidence.R` | Experience by line / peril / year, large-loss caps, **IBNR count factors by line and peril** (report-lag ECDF of 2021-22 losses), developed frequency, open-claim case check, one-ways |
| `week1/R/model_io.R` | Save / load / score fitted models (ITER 1-SAM 3 types) |
| `week1/R/4_models_iter01.R`, `_iter02.R`, `_itersam01.R` (= `4_models.R`), `_iterwendy03.R`, `_iterben01.R` | Earlier iterations (frozen) |
| `week1/R/4_models_itersam02.R`, `_itersam03.R` | SAM pipeline: own raw cleaning (`data/week_1/sam02`, `data/week_1/sam03`), per-peril IBNR (inverse reporting probability), long-tail rules, trend, claim history, GLM + tree bags, greedy blend |
| `week1/R/4_models_iterwendy04.R` + `week1/docs/assumptions_wendy04.xlsx` | WENDY 4 engine (workbook-driven; IBNR as report-share volume, open-claim recoveries, 2m limit, structural zeros, severity trend) - **start here** |
| `week1/R/4_models_iterwendy04_vsam02clean.R` | WENDY 4 on SAM 2 cleaning (set `SAM02_DATA_DIR`, see CR27) |
| `week1/R/4_models_iterwendy05.R`, `week1/R/wendy_core.R`, `week1/R/4_models_iterwendy06.R` + `week1/docs/assumptions_wendy05/06.xlsx` | Tuned / AutoML variants; `wendy_core.R` = shared year-aware basis + standard comparison outputs |
| `week1/R/4_check_reported_w4.R`, `week1/R/4_check_reported_compare.R` | Local protocol (section 3) |
| `week1/R/5_build_site.R`, `week1/R/6_export_model_spreadsheet.R` | Site and SAM 2 workbook export |
| `week1/tests/` | model_io tests |
| `week1/docs/workflow.md` | Method notes and submission log (WENDY 5 row updated 22 Oct) |
| `week1/docs/model_variations_register.xlsx`, `week1/docs/iteration_summary.xlsx` | Register of every iteration's choices + code review; scores, levers, Submit_Gate, blend plan |
| `week1/models/sam_iteration_03/sam_iteration_03_model_summary.xlsx` | SAM 3 validation by component, blend weights, IBNR, trend, caps |
| `week1/output/4_check_reported/4_models_iterwendy04/` | WENDY 4 re-score: line / peril scores on 3 bases, chosen methods, `row_preds.parquet` (baseline for the compare script) |

## 8. Starter prompt for Claude Code
> Read `week1/docs/HANDOFF_claude_code.md`, `week1/docs/workflow.md` and `week1/R/4_models_iterwendy04.R`. Build a shared helper
> `week1/R/oof_io.R` that writes and reads the row_preds format in section 3, then create `week1/R/4_models_iterwendy07.R`
> (copy of WENDY 4 with an `ibnr_method` setting: report_share | report_share_days | chain_ladder | bf | sam3_weight)
> and run experiments A0-A2 first on the local protocol (no submission). Report a table of mean 2023-24
> reported_raw D2 by line and the bootstrap difference vs A0. Ask before changing shared files in `week1/R/0_setup.R`.
