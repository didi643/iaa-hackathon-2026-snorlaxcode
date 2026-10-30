# Workflow and methodology - IAA Hackathon 2026

Goal: predict the 2025 expected ultimate claim cost (risk premium, CU) for every row in `test_motor`,
`test_buildings` and `test_contents`, and document the method with clear validation and guardrails.
Task rules, data specification and known data traps are in [kaggle_iaa_2026_handover.md](../kaggle_iaa_2026_handover.md).

| Step | What | Where |
|---|---|---|
| 1 | Claude project with context, goals and data specs | Claude (manual) |
| 2 | Repository set-up with the team | Azure DevOps repo (manual) |
| 3 | Column EDA of the raw data (one plot per column) | `week1/R/1_eda.R` section 9 -> `week1/output/1_1_eda/` |
| 4 | Column plots after cleaning (raw vs cleaned, model features) | `week1/R/2_clean.R` section 6 -> `week1/output/2_1_clean_eda/` |
| 5 | Incidence rate dimensions (report + graphs) | `week1/R/3_incidence.R` -> `week1/output/3_incidence/` |
| 6 | Model iterations + submission | `week1/R/4_models_iterXX.R` -> `week1/models/iteration_XX/`, `week1/output/4_models/`, `week1/output/submission/` |
| - | Website of all docs and step reports | `week1/R/5_build_site.R` -> `week1/output/site/index.html` |

`week1/R/0_setup.R` holds shared paths, constants (valuation date, cap quantile, Tweedie power, seed), the
`NON_FEATURES` exclusion list and helpers. It is sourced by every script; change settings there, not in the scripts.

---

## Step 1 - Claude project: context, goals and data specs

Purpose: give the AI assistant the same context the team has, so answers are grounded in the actual data
and rules rather than generic advice.

1. Create a Claude project named `IAA Hackathon 2026`.
2. Upload as project knowledge:
   - `kaggle_iaa_2026_handover.md` (task rules, data dictionary, data traps)
   - `week1/docs/workflow.md` (this file) and `README.md`
   - after each step, the generated report: `eda_report.md`, `cleaning_report.md`, `incidence_report.md`, `model_report.md`
3. Paste these project instructions:

   > You are supporting the pricing team of an established insurer in the IAA Hackathon 2026. Goal: predict
   > the 2025 expected ultimate claim cost per policy row for motor, buildings and contents, net of excess and
   > recoveries, excluding repudiated claims. Work in R (data.table, arrow, ggplot2, lightgbm). Use the
   > handover document as the source of truth for the data specification and known data traps. Keep models
   > technically sound, explainable and practical. Always state assumptions, flag leakage or proxy risks, and
   > validate on time (fit 2021-23, test on 2024). Do not invent column names; check them against the data
   > dictionary. Keep the R scripts numbered and consistent with `week1/R/0_setup.R`.

4. Guardrails for AI use: do not paste raw data rows into chat; share only aggregates and reports. Every
   AI-suggested change must be run locally and checked against the step reports before it is accepted.

## Step 2 - Repository set-up with the team

1. Clone the Azure DevOps repo and open the folder in VS Code (or RStudio, working directory = repo root).
2. Download and extract the competition zip so the Parquet files sit in `data/week_1/raw data/`.
3. `data/` and `week1/output/` are git-ignored: data stays local and every team member regenerates outputs by
   running the scripts. Commit code and docs only.
4. Install R >= 4.3, then `renv::restore()` to install the package versions pinned in `renv.lock`
   (on Windows without Rtools set `options(pkgType = "binary")` first).
5. Branching: one branch per change (`feature/<topic>`), pull request into `main`, at least one reviewer.
   Re-run the affected scripts before opening a PR and mention changes in validation metrics.
6. New scripts follow the numbering (`5_...R`) and source `week1/R/0_setup.R`.

## Step 3 - Quick EDA (`week1/R/1_eda.R`)

Reads the raw Parquet files (no cleaning) and writes `week1/output/1_eda/eda_report.md` plus CSVs and plots.
The top of the report contains an expandable pre-EDA section with the raw R type, description and first 20
rows for every supplied dataset. The same column dictionary is available as `column_dictionary.csv` for
spreadsheet filtering.

| Section | What it checks |
|---|---|
| Table overview | Row and column counts vs the handover |
| Column profiles | Type, % missing, unique values, min/median/max, top values (`column_profiles.csv`) |
| Identifiers and joins | ID formats, duplicate row_ids, customer match before/after zero-padding, address and weather coverage |
| Submission ids | Sample submission row_ids match the test files exactly |
| Claims | Counts and amounts by status, peril and loss year, open share, report lag, sanity checks, largest claims |
| Drift | Train vs test means (numeric) and level shares (categorical) |
| Plots | Exposure, written premium, sum insured, claims by loss month, incurred by peril, report lag, missingness |

Findings beyond the handover (first run, 2026-10-20):
- **Trap 10 - duplicate claims:** 604 claims have a 9-digit id (`CL1xxxxxxxx`, 600 of them 2022 losses) and each
  duplicates another claim exactly (policy, peril, loss/report date, amounts).
- Raw `exposure` is stored rounded to 4 decimals.

### Column EDA of the raw data (`week1/R/1_eda.R`, section 9 at the bottom)

One plot per column so every value distribution can be seen, not only summarised: each line's policies vs
test file (2021-24 vs 2025), weather 2021-24 vs 2025, and customers, addresses and claims as one set
(identifiers and dates skipped). Writes `week1/output/1_1_eda/column_eda_report.md` (method, observations and
recommended changes, links, flagged columns) plus one page per table; the site shows them under
"Step 3 - Column EDA (raw)". The plotting helpers are shared with the post-cleaning plots in `week1/R/eda_helpers.R`:

- Continuous columns: 40 equal-width bins over the full range (outliers stretch the axis), log10(x + 1) bins
  when non-negative with a long right tail. Up to 25 distinct values: one bar per value. Categorical: top 25
  levels plus `(other)`. Missing values are their own bar. Shares are of rows, not exposure.
- Each column lists % missing, distinct values, min/median/max or most common level, means by set and, for
  two sets, the PSI = sum of (second share - first share) x ln(second share / first share). The usual reading
  (< 0.1 stable, 0.1-0.25 moderate, > 0.25 large) is a convention for the size of a shift, not a test.
- Flags: single value, one value >= 95% of rows, >= 5% missing, >= 20% zeros, > 25 levels, 2025 values not
  seen in 2021-24, moderate or large shift. The full table is `column_summary.csv`.

## Step 4 - Sensibility checks and cleaning (`week1/R/2_clean.R`)

One `clean_policy()` function is applied to both train and test so they stay consistent. Every check is
logged with its count, the handover figure (if any) and the action taken in `week1/output/2_clean/cleaning_report.md`.

| # | Issue | Assumption / action |
|---|---|---|
| 1 | Motor customer_id lost leading zeros | Left-pad to 8 characters -> 100% match to customers |
| 2 | Exposure stored as days/360 or raw days | Recompute `(period_end - period_start + 1) / 365`; raw kept as `exposure_raw` |
| 3 | sum_insured 1000x too large on ~0.2% of rows | Above 5m (buildings) / 2m (contents) and divisible by 1000 -> divide by 1000 |
| 4 | construction_type casing and codes | Normalise to brick/stone/timber/non_standard; T and W -> timber |
| 5 | Claims outside every policy row | Excluded from targets, listed in `unmatched_claims.csv` |
| 6 | Extreme open motor claim (11.9m) | Not capped here; capped in steps 5-6 |
| 7 | renewal_decision is leakage | Dropped |
| 8 | years_licensed > driver_age - 16; missing values | Capped; categorical NA -> level `missing`; numeric NA kept |
| 9 | Duplicate 9-digit claims | Dropped (`duplicate_claims_removed.csv`) |

Joins: customers (on padded customer_id), addresses (address_id), weather (address_id + calendar year of
period_start). Row counts are asserted unchanged after joins. Derived: `customer_age`, `start_month`,
`years_with_insurer`, and (used from BEN 1) `premium_index` = written_premium / exposure-weighted mean of
its line and policy year, and `wx_avg_<weather var>` = the address's 2021-24 weather average. The last two are listed
in `NEW_FEATURES` (`week1/R/0_setup.R`) and only returned by `feature_cols(dt, include_new = TRUE)`, so iterations 1-2 keep
their feature sets. `surname` and `date_of_birth` are dropped.

**Target:** claims are matched to the row with the same policy_id and `period_start <= loss_date <= period_end`.
Claim net cost = `incurred_to_date - recoveries`, repudiated = 0. Row columns prefixed `y_`:
`y_cost`, `y_n_claims` (non-repudiated), `y_n_open`, `y_max_claim`, and `y_cost_<peril>` / `y_n_<peril>`.

Outputs: `data/week_1/clean/train_<line>.parquet`, `data/week_1/clean/test_<line>.parquet`, `data/week_1/clean/claims_matched.parquet`.

### Column plots after cleaning (`week1/R/2_clean.R`, section 6 at the bottom)

Runs after the cleaned tables are written; same plots and flags as the raw column EDA. Writes
`week1/output/2_1_clean_eda/clean_eda_report.md`; the site shows it under "Step 4 - Column plots after cleaning".

| Page | Compared |
|---|---|
| Cleaning: before vs after | Each transformed column, raw policies vs the same rows after cleaning: `exposure` (all lines), `years_licensed` (motor), `sum_insured` (buildings, contents), `construction_type` (buildings). The report also counts the rows each step changed (`cleaning_changes.csv`); for `construction_type` most are only `Brick` -> `brick` |
| Model features: motor / buildings / contents | Every column returned by `feature_cols()` (58-70 per line), train 2021-24 vs test 2025, grouped by source table (policy, customer, address, weather, derived) |

Observations from the column EDA (both reports list them, with the figures recomputed on every run):

| Finding | Evidence | Action (BEN 1; `NON_FEATURES` in `week1/R/0_setup.R` is unchanged so earlier iterations stay reproducible) |
|---|---|---|
| `compulsory_excess` has one value | single value in every line | excluded |
| `years_with_insurer` duplicates `renewal_count` | equal on 100% of rows | excluded |
| `customer_since_year` is a calendar year | 2025 = new business, 15% of test rows, never seen in training (PSI 1.44) | excluded; tenure stays in `renewal_count` |
| `campaign_code` tracks calendar time | missing share 0.88 (2021) -> 0.50 (2024) -> 0.41 (2025) | excluded |
| `written_premium` includes rate changes | buildings mean 297 / 315 / 332 / 349 (2021-24), 368 (2025) | replaced by `premium_index` = premium / mean of its line and policy year |
| `renewal_count` has a new top value in 2025 | about 2.8% of test rows one above the training maximum (PSI 0.34) | capped at the training maximum |
| Weather drifts | PSI 0.25-0.46 with nearly unchanged means; 2025 correlates 0.96 (temperature) / 0.80 (freezing days) with the address's 2021-24 average | address 2021-24 averages added next to the yearly values |
| T/W -> timber | timber frequency 0.046 / 0.045 / 0.047 / 0.044 across the coding switch | mapping confirmed |

## Step 5 - Incidence rate dimensions (`week1/R/3_incidence.R`)

Report: `week1/output/3_incidence/incidence_report.md`.

- **Definitions:** frequency = claims / exposure-years; severity = capped cost / claims; burn cost = cost / exposure;
  loss ratio = capped cost / (written_premium x exposure) - written_premium is treated as an annual rate.
- **Large-loss cap:** row cost capped at the line's p99.9 of positive row costs (`large_loss_caps.csv`).
- **A. By line x year** and **B. by peril x year**: trend and immaturity checks.
- **C. IBNR count factors** (`ibnr_factors.csv`, used by step 6): the 2021-22 report-lag distribution gives the
  expected share of each year's claims reported by 31 Dec 2024; factor = 1 / share. Open-claim case
  development is not included.
- **C2. IBNR by peril and adequacy check** (`ibnr_factors_by_peril.csv`, used from BEN 1;
  `frequency_developed.csv`, `open_claim_case_check.csv`). Review (2026-10-21):
  - The line factor understates late reporting where it is concentrated: 2024 factors are motor bodily_injury
    1.76 and buildings subsidence 1.50 against 1.07 / 1.05 for the lines. Per-peril factors weighted by each row's
    peril cost replace the line factor in BEN 1.
  - Developed with them, motor frequency is 0.1455 / 0.1467 / 0.1409 / 0.1390 (2021-24): late reporting explains
    the 2024 dip, and what remains is a falling trend of about 1-4% a year. Buildings and contents rise about 2% a
    year. BEN 1 adds a clamped log-linear trend to the scored year.
  - Open claims cannot be developed from one valuation date (no history of case estimates); their case estimates
    are kept as the best estimate and compared with closed claims of the same peril and year as a check.
- **C3. IBNR method study** (`week1/R/3b_ibnr_study.R` -> `week1/output/3b_ibnr/`, about 14 minutes; review 2026-10-22).
  Standalone sub-study of the late-reporting (count IBNR) allowance by line x peril; its recommended factors feed
  SAM 4 onward.
  - **Methods** (each a reporting-delay curve per line x peril): M0 = SAM 3's ECDF of 2021-22 lags (exact replica,
    max factor difference 5e-15); M1 = truncation-corrected product-limit on all loss years; M2 = monthly chain
    ladder on claim counts; M3 = parametric (lognormal / Weibull / two-lognormal mix by AIC, right-truncated MLE);
    M4 = M1 shrunk to a pooled curve (k tuned leaving the scored window out); M5 = M1 on the last two years of
    losses; M6 = M1 split by a covariate (skipped: no covariate moved P(lag > 30 days) materially).
  - **Backtest:** fit on claims reported by a pseudo-valuation date (2022-12-31, 2023-06-30, 2023-12-31) and predict
    the claims reported in the next 12 or 24 months, which are fully observed at 2024-12-31. Primary metric:
    cost-weighted mean |log(A/E)| of late-reported counts for the latest 12 loss months; SE from a Poisson bootstrap.

    | Method | Primary (lower = better) | vs M0 |
    |---|---|---|
    | M2 chain ladder | 0.0996 | -0.080 (SE 0.019) |
    | M0 current (SAM 3) | 0.1792 | - |
    | M1 truncation-corrected | 0.1809 | +0.002 |
    | M5 recent window | 0.1832 | +0.004 |
    | M4 credibility | 0.1890 | +0.010 |
    | M3 parametric | 0.1922 | +0.013 |

  - **Recommendation** (`recommended_ibnr.csv`, `recommended_daily_share.csv`): chain ladder for every peril except
    motor bodily_injury, where M0 wins by more than 2 SE and is kept. 2024 factors rise 0.3-1.2% vs SAM 3.
  - **Granularity:** one factor per policy year misallocates late claims across rows. For 2023 policies starting in
    Q4 the year factor predicted 20 late claims against 128 actual (claim-level: 148). From SAM 4 the factor is
    applied per row as the mean reported share over the row's days.
  - **Cost side:** late-reported claims are not more expensive except subsidence (cost-weighted factor about 4% above
    the count factor), so IBNR stays a frequency adjustment.
  - **Open-claim case estimates (validated 2026-10-22, no adjustment):** closed claims have paid = incurred; open
    claims have paid at about 22-24% of incurred, none with zero paid and no round or repeated reserve values. Open
    vs closed mean severity (same peril, year, report-lag band) is about 1 in 11 of 15 perils, including bodily
    injury (0.99) and subsidence (0.96). The four that differ (motor own_damage 1.44, buildings accidental_damage
    1.31, escape_of_water 1.12, fire 0.72) are on their 2021-23 severity trend once open and closed claims are
    combined, consistent with larger claims taking longer to settle rather than biased reserves. A 10% error in every
    open estimate would move 2021-24 line cost by 1.6% (motor), 1.3% (buildings), 0.5% (contents). Case estimates
    are therefore used as final; revisit only if a second valuation date is released.
- **D. One-way analysis** of every feature: exposure share and frequency, severity, burn cost and loss ratio
  relativities. Factors are ranked by the exposure-weighted spread of the burn-cost relativity
  (`factor_ranking.csv`). Plots are in `oneway_<line>/` numbered by rank. A high `lr_spread` means current
  pricing does not fully reflect the factor.

Finding: **Trap 11 - customer_service_contacts is leakage.** Rows with a claim average ~3 contacts vs ~0.4
without, and the test distribution matches no-claim rows. It is in `NON_FEATURES` and excluded from models.

## Step 6 - Model iterations (`week1/R/4_models_iterXX.R`)

Reports: `week1/output/4_models/model_report.md` (latest run) and one model card per iteration in `week1/models/iteration_XX/`.

- **Iterations:** each model iteration has its own script, `week1/R/4_models_iter01.R`, `week1/R/4_models_iter02.R`, ... Earlier
  scripts are frozen so their approach stays runnable and reproducible. To start a new iteration, copy the latest
  script to the next number, set `ITERATION` and `ITERATION_NOTE` at the top, then make the change. Append new
  candidate models at the end of `MODELS` so existing candidates keep their seeds. Re-running an iteration overwrites
  only its own card; shared helpers (`week1/R/0_setup.R`, `week1/R/model_io.R`) must stay backward compatible.
  The `week1/models/` folder is committed, so every iteration's card stays in the history and links to the submission log.
- **Iteration log:**

  | Iteration | Script | Approach |
  |---|---|---|
  | 1 | `week1/R/4_models_iter01.R` | Candidates per line (burn cost, rescaled premium, GLM frequency x severity, LightGBM Tweedie); best per line on local D² (GLM won in all lines) |
  | 2 | `week1/R/4_models_iter02.R` | XGBoost Tweedie for all three lines, same features as iteration 1's tree model; hyper-parameters per line from a random grid search with a 10-minute budget (`XGB_TUNE_SECONDS`, env var override for quick tests) on a 20% policy holdout of 2021-22 |
  | SAM 1 | `week1/R/4_models_itersam01.R` (also copied to `week1/R/4_models.R`) -> `week1/models/sam_iteration_01/` | Iteration 1 candidates plus a GLM/LightGBM blend per line. Note: the script still sets `ITERATION <- 2` and `ITER_DIR` to `week1/models/iteration_02/`, so re-running it would overwrite iteration 2's card |
  | WENDY 3 | `week1/R/4_models_iterwendy03.R` -> `week1/models/wendy_iteration_03/` | One XGBoost Tweedie model per peril (motor 5, buildings 6, contents 4 = 15 models); line prediction = sum of its peril predictions. Each peril has its own p99.9 cap and cap loading, its own IBNR count factor (step 5's method on that peril's report lags), its own grid search (15-minute total budget split by line, then equally over perils, tuned on a 20% policy holdout of 2021-23) and a balance factor (training predictions scaled to the training target, as Tweedie boosting under-predicts the total of sparse perils). Validated on a single fold: fit on 2021-23, score 2024. Saved as one `<line>_xgb_peril_sum` model per line that loads its `<line>_<peril>_xgb_tweedie` models. The card compares line D² with iteration 2 on the same folds |
  | BEN 1 | `week1/R/4_models_iterben01.R` -> `week1/models/ben_iteration_01/` | XGBoost Tweedie (from iteration 2) as a ladder of variants, each adding one change: rolling 2-year windows (2021-22 -> 2023, 2022-23 -> 2024) vs the expanding window; EDA feature fixes; IBNR by peril; trend to the scored year; tuning on a time fold with monotone constraints; feature-group drop test; model diagnostic plots |
  | WENDY 4 | `week1/R/4_models_iterwendy04.R` + `week1/docs/assumptions_wendy04.xlsx` -> `week1/models/wendy_iteration_04/` | Per-peril Poisson GBM frequency x Gamma GBM/GLM severity vs Tweedie challenger, driven by the assumption workbook; ultimate frequency via report-share volume; validated on developed actuals |
  | WENDY 4 SAM02-clean | `week1/R/4_models_iterwendy04_vsam02clean.R` -> `week1/models/wendy_iteration_04_vsam02clean/` | WENDY 4 models on SAM 2-style cleaned data (controlled cleaning test); not submitted - local reported 2024 identical to WENDY 4 |
  | WENDY 5 | `week1/R/4_models_iterwendy05.R` + `week1/docs/assumptions_wendy05.xlsx` -> `week1/models/wendy_iteration_05/` | WENDY 4 + random-search tuning per component, severity GBM vs GLM, method chosen on policy-grouped CV |
  | WENDY 6 | `week1/R/4_models_iterwendy06.R` + `week1/R/wendy_core.R` + `week1/docs/assumptions_wendy06.xlsx` -> `week1/models/wendy_iteration_06/` | H2O AutoML per peril (Poisson frequency, Gamma severity) on WENDY 5's folds (running 22 Oct) |
  | check | `week1/R/4_check_reported_w4.R`, `week1/R/4_check_reported_compare.R` -> `week1/output/4_check_reported/` | Re-score a WENDY 4-style script on reported / adjusted / developed actuals; paired policy bootstrap of two runs |
  | SAM 3 | `week1/R/4_models_itersam03.R` -> `week1/models/sam_iteration_03/` | SAM 2 challenger: per-peril frequency x severity uses reported claim counts over report-share-adjusted exposure, with observed capped severity; aggregate line Tweedie candidates remain as a benchmark |
  | WENDY 7 | `week1/R/4_models_iterwendy07.R` + `week1/docs/assumptions_wendy07.xlsx` -> `week1/models/wendy_iteration_07/<tag>/`; helpers `week1/R/oof_io.R`, `week1/R/4_compare_wendy07.R`, `week1/R/4_blend_wendy07.R`, `week1/R/4_check_ceiling.R`, `week1/R/4_check_ibnr_backtest.R`, `week1/R/4_check_sam03_oof.R`, `week1/R/4_final_wendy07.R` | WENDY 4 engine with switchable IBNR (`IBNR_METHOD`, `IBNR_OVERRIDE`), feature / Model_Spec edits, seed bagging, local protocol validation (3 bases, row predictions). Final candidate (22 Oct, submitted #10, public 0.12924): chain-ladder IBNR (subsidence A1), excess in every peril, 5 bags, BI without trend, 50/50 line blend with SAM 3 -> local mean 2023-24 reported_raw D2 0.10228 vs SAM 3 0.10135 (+0.00093, 2 SE 0.00047). Reasoning per step: `week1/docs/wendy07_experiment_log.md` |
  | SAM 4 | `week1/R/4_models_itersam04.R` -> `week1/models/sam_iteration_04/` | SAM 3 with the step 3b IBNR: chain-ladder report shares (SAM 3 ECDF for motor bodily_injury) applied per row as exposure x mean reported share over the row's days; everything else unchanged. Run `week1/R/3b_ibnr_study.R` first |
  | SAM 5 | `week1/R/4_models_itersam05.R` -> `week1/models/sam_iteration_05/` | SAM 4 plus `premium_index` (written_premium / exposure-weighted mean of its line and policy year) in the LightGBM / XGBoost models only; raw written_premium and discount_applied stay excluded, GLMs unchanged |
  | WENDY 8 / WENDY 9 | `week1/R/4_models_iterwendy08.R`, `week1/R/4_models_iterwendy09.R` + `week1/R/wendy_ladder_core.R` (R ports of the submitted Python models; exact Python code and run order: `notes/wendy08_exact_model_submitted/`, `notes/wendy09_exact_model_submitted/`) | WENDY 8 = final2 x credibility M = (a + N) / (a + E), a = 8 / 5 / 5, line totals kept (#13, public 0.12945). WENDY 9 = per-peril LightGBM frequency x severity ladder blended with WENDY 7 C5 per peril, with SAM 3 per line, then the WENDY 8 credibility (#12, public 0.12964) |
  | MOTOR 1 | `week1/R/4_models_itermotor01.R` -> `week1/models/motor_iteration_01/` | Motor only: per-peril spline GLM frequency (offset log(exposure x reported share)) x Gamma severity, per-peril feature ladder, XGBoost frequency with the GLM as base margin, line Tweedie and iteration-1 GLM replay as benchmarks |
  | MOTOR 2 | `week1/R/4_models_itermotor02.R` -> `week1/models/motor_iteration_02/` | MOTOR 1 + BI frequency pooled with TPP (50/50 with BI's own GLM), level choices per peril on developed actuals, blend with line Tweedie (0.1) and iteration-1 GLM (0.2). Motor member (m 0.5) of the 0.12965 file |
  | MOTOR 3 | `week1/R/4_models_itermotor03.R` -> `week1/models/motor_iteration_03/` | MOTOR 2 frozen + split claim history (prior collision / other claims, years since last collision). A/B in the 0.12965 pipeline (`week1/R/6_w9_ab_motor3.R`): +0.00002 (SE 0.00002) - no gain |
  | MOTOR 4 | `week1/R/4_models_itermotor04.R` -> `week1/models/motor_iteration_04/` | WENDY 9 LightGBM frequency recipes on MOTOR features + claim-history counts, three versions per peril (MOTOR 2 GLM / LightGBM / LightGBM started from the GLM), x MOTOR 2 severity. Judged by `week1/R/6_w9_motor04_eval.R`: choices on 2023, decision on held-out 2024 (developed actuals). Failed the held-out rule (see below) |
  | MOTOR 5 | `week1/R/4_models_itermotor05.R` -> `week1/models/motor_iteration_05/` | MOTOR 4 + penalised GAM (mgcv `bam`) for BI frequency (own / pooled with TPP / mix). GAM not chosen on 2023 (BI peril D2 0.0698 vs GLM 0.0705) - no gain |
  | MOTOR 6 | `week1/R/6_telematics_study.R` + `week1/R/4_models_itermotor06.R` -> `week1/models/motor_iteration_06/` | MOTOR 4 + telematics: score as a spline in the own_damage / BI GLMs and the BI-TPP pooled relativity; LightGBM gets score relative to the age band x young-driver mean and (100 - score) x mileage; score monotone. Held-out 2024 +0.00025 (SE 0.00036) - no better than MOTOR 4 |
  | MOTOR 7 | `week1/R/6_motor_version_avg.R` -> `week1/models/motor_iteration_07/` (no refit) | Per peril, average of the glm / LightGBM / LightGBM-from-GLM frequency versions (better peril D2 than any single version in both years for 4 of 5 perils). Same held-out gain as MOTOR 4 (+0.00020 developed 2024); submitted 24 Oct: public 0.12904, **private 0.13933 (best private, not selected)** |

  Named iterations (for example `WENDY 3`, `SAM 1`) use a script `week1/R/4_models_iter<name><NN>.R` and a folder
  `week1/models/<name>_iteration_<NN>/`; the same label goes in the `Iteration` column of the submission log.
- **Model card** (`week1/models/iteration_XX/model_card.md`, also on the site under Step 6), for every candidate model:
  - run id, git commit, settings (cap, IBNR, Tweedie power, GLM binning, LightGBM parameters and rounds, excluded fields)
  - accuracy: local D² by line and combined for both validation years, Gini, prediction vs actual totals
  - 2025 test predictions: total, cost per exposure-year and distribution per line and model, and which was submitted
  - features used per line and model
  - variable importance from the final fit: GLM spread of log relativities per factor, LightGBM gain share
  - GLM relativities: every level's exposure share, frequency, severity and cost relativity to the base, p-values
  - CSV copies of all of the above for feature engineering (`glm_relativities.csv`, `lgb_importance.csv`, ...)
- **Reproducibility:**
  - every candidate's final model is saved in `week1/models/iteration_XX/fitted/`: the GLM as binning rules plus
    coefficients (`.rds`), LightGBM as its tree file (`.txt`) plus a feature-encoding `.rds`
  - `week1/R/model_io.R` reloads and scores them without refitting (`load_model()`, `score_model()`)
  - each fit uses its own seed (`fit_seed()` by line, model and year), so code changes elsewhere don't change its
    random sample; LightGBM runs in deterministic mode with fixed threads
  - after each run the saved models are reloaded and must reproduce the submission exactly (replication check), and
    the card records the submission file's MD5 and warns if the code was not committed
  - checked: two separate runs of iteration 1 produced byte-identical submission files

- **Competition metric:** Tweedie D² with power 1.5, higher = better:
  $D^2 = 1 - \text{deviance(predictions)} / \text{deviance(constant-rate baseline)}$. 1 = perfect, 0 = no better
  than charging every row the same cost per exposure-year, negative = worse. Computed locally by `d2_tweedie()`
  in `week1/R/4_models_iterXX.R`, with the baseline taken as one rate (actual cost / exposure) over all scored rows. This
  matches the Kaggle description, but whether Kaggle uses an exposure-based or flat mean baseline is not confirmed.
- **Validation:** two time-based checks, fit on the years before and score the year: 2021-22 -> 2023 (more mature)
  and 2021-23 -> 2024 (immature). D² is reported per line and for all three lines together (one baseline, as in
  the submission file). Tweedie deviance, Gini and totals vs reported / IBNR-developed actuals are also shown.
- **Which line to improve:** for the submitted combination the report shows D² per line (each against its own
  baseline), the combined D², and each line's `deviance_share` of the remaining combined error. Cutting a line's
  deviance by x% lifts the combined D² by about x% × deviance_share × (1 − combined D²), so the line with the
  largest share moves the Kaggle score most. Combined D² is higher than every line's D² because the single
  baseline charges motor and contents the same rate; part of the combined score comes from getting the line
  levels right.
- **Training target:** capped row cost x IBNR factor of its year; predictions multiplied by the cap loading
  (total / capped cost) so the capped-off cost is spread back over all rows.
- **Candidates:**

  | Model | Role |
  |---|---|
  | `burn_cost` | Flat rate x exposure - the floor |
  | `premium_scaled` | Current written premium rescaled to claims cost - current-pricing benchmark |
  | `glm_freq_sev` | Quasi-Poisson frequency (offset log exposure) x Gamma severity on binned factors - explainable |
  | `lgb_tweedie` | LightGBM Tweedie on cost per exposure, weight = exposure, early stopping on a 10% policy holdout |
  | `glm_lgb_ensemble` | GLM and LightGBM blended at exposure-normalized rate level with a line-specific validation-selected weight |
  | `xgb_tweedie` | XGBoost Tweedie on cost per exposure (iteration 2 per line; WENDY 3 per peril) |
  | `peril_sum` | WENDY 3: line cost = sum of one model per peril; `load_model()` loads the line model and all its peril models |

- **Final fit and submission:** every candidate is refitted on 2021-24 and scores the test rows (summarised in the
  model card); the best model per line (highest mean D² over 2023 and 2024) forms the submission. The script asserts
  626,639 unique row_ids matching `sample_submission`, no NA, no
  negatives, and writes `week1/output/submission/submission_provisional.csv` (`row_id,prediction`) plus an archived copy
  `submission_<run id>.csv`. Each run appends its run id, models and local D² to `week1/output/4_models/run_history.csv`,
  and the report prints a ready-made row for the submission log.

First-run result (2026-10-20): `glm_freq_sev` was best in all three lines. Combined local D² 0.0944 (2024) and
0.1055 (2023) vs 0.0666 / 0.0763 for current premium; LightGBM was close but stopped early and is not yet tuned.

| Line | D² 2023 | D² 2024 | Share of remaining deviance 2023 / 2024 |
|---|---|---|---|
| motor | 0.055 | 0.045 | 48% / 45% |
| buildings | 0.062 | 0.066 | 34% / 36% |
| contents | 0.062 | 0.061 | 18% / 19% |
| combined | 0.106 | 0.094 | 100% |

Motor has the lowest D² and the largest share of the remaining error, so it is the first line to improve.

Iteration 2 implementation (2026-10-21): `week1/R/4_models.R` adds `glm_lgb_ensemble`, blending the existing
`glm_freq_sev` and `lgb_tweedie` expected cost rates. One GLM weight per line is selected from the predeclared
grid 0.0 to 1.0 in steps of 0.1 using the mean D² across the 2023 and 2024 time-based validation folds. The
ensemble competes with the existing candidates and is submitted only for lines where it has the best mean D².
Final ensemble artifacts are saved and reloaded through `week1/R/model_io.R`.

BEN 1 result (2026-10-21, run `20261021_1658`, public D² 0.12224). Each variant adds one change; local D²
2023 / 2024 (`week1/models/ben_iteration_01/variants.csv`):

| Variant | Change | Motor | Buildings | Contents |
|---|---|---|---|---|
| v0 | iteration 2 setup, expanding window | 0.0385 / 0.0496 | 0.0688 / 0.0724 | 0.0592 / 0.0589 |
| v1 | + rolling 2-year window | 0.0385 / 0.0479 | 0.0688 / 0.0696 | 0.0592 / 0.0545 |
| v2 | + EDA feature fixes | 0.0337 / 0.0482 | 0.0676 / 0.0680 | 0.0560 / 0.0567 |
| v3 | + IBNR by peril | 0.0360 / 0.0475 | 0.0676 / 0.0676 | 0.0560 / 0.0566 |
| v4 | + trend to the scored year | 0.0353 / 0.0489 | 0.0695 / 0.0695 | 0.0581 / 0.0574 |
| v5 | + tuned on a time fold, monotone constraints | 0.0384 / 0.0494 | 0.0686 / 0.0696 | 0.0625 / 0.0598 |
| v6 | v5 on the expanding window (selected in all lines) | 0.0384 / 0.0514 | 0.0686 / 0.0731 | 0.0625 / 0.0625 |

Findings:
- The rolling 2-year window loses 0.003-0.004 in 2024 in every line: more history beats recency here, so the final
  fit stays on 2021-24. (For 2023 both windows are 2021-22.)
- The EDA feature fixes cost a little on their own (mostly losing raw `written_premium` / `customer_since_year` signal)
  but are kept for robustness to 2025 drift; tuning on a time fold with monotone constraints recovers it.
- Trend helps buildings and contents; the buildings trend sits at the +5% clamp, so it is the first setting to revisit.
- Feature-group drop test (`group_drop_test.csv`): no group improved both years by more than 0.0005, so nothing was
  dropped. `premium_index` carries real signal (dropping it costs 0.007 in motor 2023, 0.003 in contents 2023).
  Near misses: motor without the marketing fields (+0.0022 / +0.0002) or `make_model` (+0.0023 / +0.0002), and
  buildings without `previous_insurer` (+0.0005 / +0.0014) - candidates to drop in the next iteration.
- Motor remains the weakest line and below iteration 1's GLM on 2023 (0.056).

SAM 4 result (2026-10-22, run `20261022_1734`, not yet submitted on its own). Same models, features, tuning and blend as
SAM 3; only the IBNR changes (step 3b chain-ladder shares, applied per row; `row_report_share()` in `week1/R/model_io.R`).

| Combined local D² | 2022 | 2023 | 2024 |
|---|---|---|---|
| SAM 3 | 0.1145 | 0.1043 | 0.0986 |
| SAM 4 | 0.1145 | 0.1047 | 0.0984 |

- Neutral: by line 2023 / 2024 motor 0.044 / 0.046 (SAM 3 0.043 / 0.047), buildings and contents unchanged; blend
  weights identical. 2025 predicted cost per exposure-year rises 0.4-0.7% (motor 607.4, buildings 489.2, contents 125.8).
- `start_month` and `new_business` were already minor features in SAM 3, so per-row factors had little to correct.
- Kept as the preferred candidate on method grounds (better-tested IBNR) at equal accuracy.
- Motor diagnostics from the SAM 4 card: the iteration 1 line GLM (`legacy_glm`, fitted in every fold as a
  benchmark) beats the motor blend on 2023 (0.0557 vs 0.0435; mean of 2022-24 0.0519 vs 0.0498), also after
  rescaling to the actual total, so it is a ranking gap. Motor 2024 is over-predicted by 10% against IBNR-developed
  actuals, but submission #10 shows this is an immaturity effect, not a level error (see the submission log).

SAM 5 result (2026-10-22, run `20261022_2213`, not submitted). SAM 4 plus `premium_index` in the tree models only,
to test whether the current premium carries risk signal the other fields miss (BEN 1's drop test suggested it did).

| Combined local D² | 2022 | 2023 | 2024 |
|---|---|---|---|
| SAM 4 | 0.1145 | 0.1047 | 0.0984 |
| SAM 5 | 0.1152 | 0.1048 | 0.0983 |

- Neutral: `premium_index` ranks 1st-3rd in every line's Tweedie models but mostly substitutes for existing fields
  (sum insured, flood zone, claim history, which BEN 1 did not have). The quick run's motor 2023 gain (+0.004) did
  not hold in the full run (0.043 vs 0.044). Buildings 2023 +0.002 only.
- Not adopted: no accuracy gain, and building the technical price from the current premium is partly circular
  and harder to explain. The guardrail stays: written_premium, premium_index and discount_applied are excluded.

**Open items for the next iteration**
- Motor (updated after SAM 4 / SAM 5 and submission #10): the gap is ranking, not level. Next: iteration 1 GLM
  (`legacy_glm`) and iteration 2 XGBoost (`legacy_xgb`) as blend candidates, and save per-row validation
  predictions so blend, trend and level changes can be tested offline without a full rerun.
- Motor: GLM frequency x severity / XGBoost blend (GLM is ahead on 2023), by-peril model for bodily_injury.
- Trend: check the clamped +5% buildings trend (severity vs frequency) before relying on it; sensitivity run without trend.
- Open-claim case development: not estimable from one valuation date; revisit if a second valuation is released.
- By-peril frequency/severity for large-loss perils (fire, flood, subsidence, bodily_injury).
- Guardrails write-up: `premium_index` (current pricing), `occupation`, `previous_insurer`, marketing fields (drop test shows small, unstable effects).

**Earlier open items (iterations 1-2)**
- Trend to 2025 (buildings/contents severity rises each year; motor 2024 frequency drop beyond IBNR).
- Open-claim case development in addition to the IBNR count factor.
- By-peril frequency/severity for large-loss perils (fire, flood, subsidence, bodily_injury).
- LightGBM tuning (learning rate, leaves, monotone constraints), further ensemble calibration, and guardrail review.
- Guardrails review: `written_premium`, `marketing_segment`, `occupation`, noise fields (email_domain, vehicle_colour).

## Submission log

One row per Kaggle submission, newest at the bottom. Public score = Tweedie D² (p = 1.5) on the public part of the
test set, **higher = better**. Local D² columns come from the same run (`run_history.csv` / model report), so each
submission can be cross-checked: a change that raises local D² on both years should also raise the public score.
The public score is expected to be higher than local 2024 D², because 2024 actuals are immature.

| # | Iteration | Date | Time (SGT) | Run id / file | Public D² | Local D² 2023 | Local D² 2024 | Local D² by line (2023 / 2024) | Methodology | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 2026-10-20 | ~14:00 | first run, `submission_20261020_1400_submitted.csv` | 0.11904 | 0.1055 | 0.0944 | motor 0.055 / 0.045; buildings 0.062 / 0.066; contents 0.062 / 0.061 | `week1/R/4_models.R` (now `week1/R/4_models_iter01.R`): `glm_freq_sev` for all three lines (quasi-Poisson frequency x Gamma severity on binned factors), refitted on 2021-24; row cost capped at p99.9 per line with cap loading; IBNR count factors on 2023-24; no trend; `customer_service_contacts` excluded (leakage) | Baseline. Local D² computed afterwards with the same method (2024 fold reproduces the original run exactly). Submitted file MD5 `b09e2076b63b23dc476c43f2693eb315`; made before the reproducibility fix, so it can only be recovered from the saved file. The iteration 1 card was re-run reproducibly at commit `94755d2` (local D² 0.1057 / 0.0947, file MD5 `956f3aa9...`) |
| 2 | 2 | 2026-10-21 | not recorded | `submission_20261021_0951.csv` | 0.12149 | 0.0997 | 0.0973 | motor 0.038 / 0.050; buildings 0.070 / 0.071; contents 0.060 / 0.057 | `week1/R/4_models_iter02.R`: XGBoost Tweedie for motor, buildings and contents; same features as the iteration 1 tree model; parameters selected by the 10-minute random grid search on a 2021-22 policy holdout; refitted on 2021-24; IBNR count factors and p99.9 cap loading | Public score improved over submission #1. Submission MD5 `64b6ce2085ed4df632435d508a9a8b9c`; replication check passed |
| 3 | SAM 1 | 2026-10-21 | 13:36 | `submission_20261021_1336.csv` | 0.11876 | 0.1071 | 0.0959 | motor 0.056 / 0.045; buildings 0.065 / 0.070; contents 0.064 / 0.062 | `week1/models/sam_iteration_01/model_card.md`: GLM and LightGBM ensemble for buildings and contents, with `glm_freq_sev` retained for motor; final models refitted on 2021-24 with IBNR count factors and p99.9 cap loading | Public score below submissions #1 and #2. Submission MD5 `f52b089f204e113912249e12679cf91e`; replication check passed |
| 4 | WENDY 3 | 2026-10-21 | ~17:15 | `submission_20261021_1650.csv` | 0.12132 | n/a | 0.0954 | motor n/a / 0.043; buildings n/a / 0.072; contents n/a / 0.059 | `week1/R/4_models_iterwendy03.R` at `adf9185` (`week1/models/wendy_iteration_03/model_card.md`): one XGBoost Tweedie model per peril (15 models), line = sum of perils; per-peril p99.9 cap, IBNR factor, 15-minute grid search on 2021-23 and balance factor; single validation fold (fit 2021-23, score 2024); refitted on 2021-24 | Public score just below submission #2 (0.12149), above #1 and #3. Same pattern as local 2024 D² (0.0954 vs 0.0973): per-peril split helps buildings (+0.001) and contents (+0.002) but costs motor (-0.006). Submission MD5 `5781d7755fa956afa482ad488b7c1796`; replication check passed |
| 5 | BEN 1 | 2026-10-21 | not recorded | `submission_20261021_1658.csv` | 0.12224 | 0.1000 | 0.0998 | motor 0.038 / 0.051; buildings 0.069 / 0.073; contents 0.062 / 0.062 | `week1/R/4_models_iterben01.R` (`week1/models/ben_iteration_01/model_card.md`; run at `af12e5f` before the rebase onto main, same code): XGBoost Tweedie, variant v6 in all lines (expanding window, final fit 2021-24); EDA feature fixes (premium_index, 2021-24 weather averages, calendar/duplicate/constant fields removed, renewal_count capped); per-peril IBNR; clamped trend to 2025 (motor -1.3%, buildings +5.0% cap, contents +4.8% a year); tuned on a 2021 -> 2022 time fold with monotone constraints; p99.9 cap loading | Best public score so far (+0.00075 vs #2, +0.00092 vs #4), in line with the local gain on both years. Submission MD5 `34dc2c9da29db5062b2ea2cabe3cf928`; replication check passed |
| 6 | WENDY 4 | 2026-10-22 | 07:52 | `submission_20261022_0715_wendy04.csv` | 0.12671 | 0.1053 | 0.1045 | motor 0.051 / 0.055; buildings 0.070 / 0.071; contents 0.070 / 0.064 | `week1/R/4_models_iterwendy04.R` at `b576105` + uncommitted changes in `week1/R/`, `week1/docs/` (`week1/models/wendy_iteration_04/model_card.md`): per-peril frequency x severity (Poisson GBM freq, Gamma GBM/GLM sev) with a Tweedie GBM challenger, selected per peril (freq_sev chosen for 12/15 perils) by mean D² over 2023-24 folds; IBNR via each peril's own report-lag ECDF so frequency targets ultimate rather than reported claims; **validation scored against developed actuals (reported / report_share), not raw reported cost like iterations 1-3** | New best public score, above WENDY 3 (0.12132) and iteration 2 (0.12149). Not directly comparable to local D² of earlier iterations: the developed-actuals scoring removes the immaturity penalty that depressed iterations 1-3's local 2024 D² (hence local 2024 jumping to 0.1045 while 2023 stayed flat at 0.1053 - a metric-definition effect, not a pure model improvement). Gini (0.502 in 2024) is flat to only marginally ahead of WENDY 3 (0.488) and iteration 2 (0.491), the fairer like-for-like comparison. Submission MD5 `e1a2b96e02f795c46f96ece3694abb5d`; no replication check implemented in this script |
| 7 | SAM 2 | 2026-10-22 | not recorded | `submission_20261021_1528.csv` | 0.12796 | 0.1045 | 0.0982 | motor 0.049 / 0.046; buildings 0.071 / 0.071; contents 0.066 / 0.067 | `week1/R/4_models_itersam02.R`: full raw-data rebuild with claim-history features, per-peril frequency x severity, per-peril IBNR and trend, LightGBM and XGBoost bags, and a calibrated blend | Best public score so far, improving over submission #2 by 0.00647. Submission replication check passed |
| 8 | WENDY 5 | 2026-10-22 | not recorded | `submission_20261022_0912_wendy05.csv` | 0.12636 | n/a (no 2023 fold; policy-grouped CV over 2021-24: 0.1118) | 0.1025 | n/a / 0.052 (motor), 0.069 (buildings), 0.063 (contents); grouped CV: motor 0.058, buildings 0.071, contents 0.073 | `week1/R/4_models_iterwendy05.R` (`week1/models/wendy_iteration_05/model_card.md`): WENDY 4 actuarial basis with random-search tuned XGBoost per component (Poisson freq, Gamma sev, Tweedie) on a policy-grouped fold; severity GBM vs GLM chosen on holdout Gamma deviance; method (freq x sev / Tweedie) chosen per peril on policy-grouped CV over all years; year-aware trends | Public score slightly below WENDY 4 (0.12671, -0.00035), so tuning and CV-based method choice did not improve the public score. Local D² is from `week1/models/wendy_iteration_05/comparison/line_scores.csv` (schemes `time_2024` = fit 2021-23, score 2024; `group_cv` = out-of-fold over 2021-24), both vs developed actuals, so like-for-like with WENDY 4 (0.1045 on 2024; WENDY 5 is 0.1025). Chose freq_sev for 13/15 perils, Tweedie for 2; severity GBM for 11, GLM for 4. Submission MD5 `33b990116f99a3b93ba90900c8864b25`; replication check passed (max abs diff ~1e-12) |
| 9 | SAM 3 | 2026-10-22 | 14:01 | `submission_20261022_1159.csv` | 0.12818 | 0.1043 | 0.0986 | motor 0.043 / 0.047; buildings 0.071 / 0.075; contents 0.071 / 0.064 | `week1/R/4_models_itersam03.R` (`week1/models/sam_iteration_03/model_card.md`): full-data SAM 2 challenger; per-peril frequency x severity uses report-share-adjusted exposure for frequency and observed capped claim severity; full 900-second XGBoost tuning; calibrated LightGBM/XGBoost blend | **New best public score**, +0.00022 over SAM 2. Full run completed; replication check passed. Submission MD5 `a6b3a87a02708a8f0acadafdedc30bf4` |
| 10 | WENDY 7 | 2026-10-22 | not recorded | `submission_20261022_2135_wendy07_final.csv` | 0.12924 | 0.1054 | 0.0992 | motor 0.043 / 0.048; buildings 0.073 / 0.075; contents 0.072 / 0.065 | `week1/R/4_models_iterwendy07.R` run c4 + `week1/R/4_final_wendy07.R` (`week1/docs/wendy07_experiment_log.md`): 0.5 x WENDY 7 C4 + 0.5 x SAM 3 per line. WENDY 7 C4 = WENDY 4 engine with chain-ladder IBNR on counts (subsidence: ECDF averaged over row days), voluntary_excess in frequency and severity of every peril, 5 seed bags per component, motor BI frequency / severity trend = none, WENDY 4 method mix; final fit 2021-24, replication check passed. **Local D² here = reported_raw basis (local protocol)**, mean 0.10228 vs SAM 3 0.10135 on the same rows | **New best public score**, +0.00106 over SAM 3 (local gain +0.00093, 2 x SE 0.00047): first submission chosen through the Submit_Gate, and local and public moved by the same amount. Submission MD5 `8535c6833aafd1299ad8d5cd9887448d` |
| 11 | WENDY 7 final2 | 2026-10-23 | not recorded | `submission_20261022_2328_wendy07_final2.csv` | 0.12925 | 0.1062 | 0.0998 | motor / buildings / contents: see WENDY 7 final2 validation below | `week1/R/4_models_iterwendy07.R` run C5 + `week1/R/4_final_wendy07.R`: per-line blend of WENDY 7 C5 and SAM 3, with weights 0.8 / 0.5 / 0.6 for motor / buildings / contents; C5 adds the accepted per-peril lab winners to C4; final fit 2021-24, replication check passed | Submitted for public scoring; public D² was 0.00001 above WENDY 7. Submission MD5 `99135ba796a021c92c186e3e7bf71d3f` |
| 12 | WENDY 9 (Python ladder) | 2026-10-23 | not recorded | `submission_20261023_wendy09.csv` | **0.12964** | 0.1068 | 0.1021 | motor 0.0453 / 0.0522; buildings 0.0738 / 0.0769; contents 0.0742 / 0.0659 (reported_raw) | `python/wendy09/` (other environment; handover `w9_handover`): per peril w x LightGBM ladder + (1 - w) x C5, per line LW x peril blend + (1 - LW) x SAM 3 (0.9 / 0.7 / 0.9), x credibility (a = 8 / 5 / 5). Details `week1/docs/model_build_final2_w8_w9.xlsx` | Recorded from the handover workbook. **Best public score.** MD5 `733f89991e074ecf6f60954adc9e5a28` |
| 13 | WENDY 8 (Python credibility) | 2026-10-23 | not recorded | `submission_20261023_wendy08_cred.csv` | 0.12945 | 0.1066 | 0.1010 | motor 0.0452 / 0.0506; buildings 0.0736 / 0.0763; contents 0.0733 / 0.0649 (reported_raw) | `python/wendy08/` (other environment): final2 x credibility M = (a + N) / (a + E), a = 8 / 5 / 5, line totals kept | Recorded from the handover workbook. R port: `week1/R/4_models_iterwendy08.R`. MD5 `0227ce61013af6efc0b60412c7f18317` |

WENDY 7 final was submitted as #10 (public 0.12924); the local protocol (mean 2023-24 reported_raw D² + paired policy bootstrap) predicted the gain over SAM 3 within 0.0002.
WENDY 7 final2 was submitted as #11 (public 0.12925): `week1/output/submission/submission_20261022_2328_wendy07_final2.csv` (MD5 `99135ba796a021c92c186e3e7bf71d3f`) = per line w x WENDY 7 C5 + (1 - w) x SAM 3 (w motor 0.8, buildings 0.5, contents 0.6); C5 = C4 + per-peril lab winners (`week1/R/4_peril_lab_wendy07.R`). Local mean 2023-24 reported_raw D² 0.10302 (2023 0.1062, 2024 0.0998) vs #10 0.10228: +0.00074 > 2 SE 0.00051. Passed the Submit_Gate against #10.
WENDY 7 documentation: every try in `week1/docs/wendy07_experiment_register.xlsx`; model workbooks `week1/docs/assumptions_wendy07_sub10.xlsx` (#10) and `week1/docs/assumptions_wendy07_final2.xlsx` (final2) - run either with `ASSUMPTIONS_XLSX=<file> FINAL_FIT=1 FINAL_METHODS=all Rscript week1/R/4_models_iterwendy07.R`.
| 10 | splice: WENDY 4 motor + SAM 4 buildings/contents | 2026-10-23 | not recorded | `submission_20261023_0054_wendy04motor_sam04.csv` | 0.12716 | n/a | n/a | n/a (motor from WENDY 4, buildings/contents from SAM 4) | `week1/R/6_splice_submission.R`: motor rows from submission #6, buildings and contents rows from SAM 4 (`submission_20261022_1734.csv`, not submitted on its own). WENDY 4 motor ranks rows like SAM 4 (Spearman 0.971) but is 14% lower in level (521 vs 607 per exposure-year), so this mainly tests the motor level | -0.00102 vs SAM 3: lowering motor to WENDY 4's level hurts, so SAM's motor level is kept and local 2024 motor over-prediction is read as an immaturity effect. Submission MD5 `d50d3692f5e0257ec150f70ace210f20` |
| - | splice: WENDY 7 final2 + MOTOR 2 motor | 2026-10-23 | not recorded | `submission_20261023_wendy07_motor2_1359.csv` | 0.12887 | n/a | n/a | motor (own protocol, reported raw) 2023 0.0539 / 2024 0.0534 | Motor rows of #11 replaced by MOTOR 2 run `20261023_1359` (`week1/R/4_models_itermotor02.R`, `week1/models/motor_iteration_02/model_card.md`) rescaled to the SAM 4 motor total (607.4 vs 571.6 per exposure-year); buildings/contents unchanged | -0.00038 vs #11. Mixes a +6% motor level change with a ranking change (Spearman 0.985), so the loss is not attributable to MOTOR 2 ranking alone. Submission MD5 `45e89e86b2fb74bace60d5b1d016542b` |
| - | WENDY 9 + MOTOR 2 (pre-credibility, m 0.5) | 2026-10-23 | ~16:40 | `submission_20261023_1636_w9_motor2_pre_m0.5.csv` | 0.12965 | 0.10920 | 0.10290 | motor 0.0505 / 0.0542 (WENDY 9: 0.0453 / 0.0522) | `week1/R/6_blend_w9_motor2.R` on the WENDY 9 handover panel (no refits): motor line blend b = 0.5 x WENDY 9 line blend + 0.5 x MOTOR 2 (rescaled to the W9 motor total), then WENDY 8 credibility M = (8+N)/(8+E); buildings/contents identical to WENDY 9. Local = Wendy's protocol (reported_raw, folds 2023 / 2024, all lines) | +0.00001 vs WENDY 9 (0.12964) while local predicted +0.0016 (2023 +0.0024, 2024 +0.0008). Public gain is within noise (about +/-0.0013); motor total unchanged vs W9, motor Spearman vs W9 0.996. Local gain is optimistic because MOTOR 2 settings were chosen on the same folds. Submission MD5 `148a9f430289965107f40175dd2953ca` |
| - | WENDY 9 + MOTOR 2 per peril + dispersion k | 2026-10-23 | ~17:10 | `submission_20261023_1707_w9_per_peril_m2_k.csv` | 0.12826 | ~0.1091 | ~0.1039 | n/a | `week1/R/6_w9_calib_stack.R`: MOTOR 2 per motor peril (weights OD / TPP / BI / theft / GH 0.25 / 1 / 1 / 0.25 / 1) + dispersion q^k per line (motor 0.95, buildings 1.10, contents 0.95), all tuned on the 2023-24 folds | -0.00139 vs 0.12965 although local was +0.0023 / +0.0018 vs WENDY 9: post-hoc weights and dispersion tuned on the folds did not transfer. Submission MD5 `5eb4e59888e6d5e4917d0cd68b86781b` |
| - | 0.12965 file + buildings dispersion k 1.075 | 2026-10-23 | ~20:15 | `submission_20261023_2010_w9_motor2_m0.5_bk1.075.csv` | 0.12888 | 0.1095 | 0.1034 | buildings only changed (ranks and totals kept) | `week1/R/6_w9_buildings_k.R`: buildings predictions stretched as q^1.075 and rescaled per line; motor / contents identical to the 0.12965 file | -0.00077 vs 0.12965 although local was +0.00031 / +0.00052 (bootstrap z 3.5): local reported_raw folds do not predict public for post-hoc calibration. Submission MD5 `426ca7762910e090745ccbb00b202b80` |

MOTOR 1 / MOTOR 2 (motor only, `week1/R/4_models_itermotor01.R`, `week1/R/4_models_itermotor02.R`): per-peril frequency x severity with spline GLMs on exposure x reported-share offsets, a per-peril feature ladder, credibility-shrunk severity (BI severity = peril average), BI frequency pooled with TPP, per-peril level choices on developed actuals (BI severity on all years) and a blend with the line Tweedie and the iteration-1 GLM replay. Motor raw D² 2022 / 2023 / 2024: MOTOR 2 0.0626 / 0.0539 / 0.0534 vs SAM 4 0.0596 / 0.0435 / 0.0463. Blending MOTOR 2 into WENDY 9 motor at m 0.5 passed Wendy's local rule (+0.0016, both folds positive) but was flat on public (0.12965 vs 0.12964); m 0.75 / 1 score higher locally (+0.0021 / +0.0023, grid in `week1/output/6_blend_w9_motor2/w9_motor2_grid.csv`) but are untested on public.

Follow-up work on 23 Oct (evening), all judged against the 0.12965 file:
- **Bodily injury level.** Open and closed BI claims have about the same severity in every loss year (0.97 / 0.91 / 1.04 excluding the 11.9m claim), so case estimates look unbiased and the 2023-24 BI cost drop looks real; WENDY 9's BI level (~200 per exposure-year) is kept. BI +20% / +45% probe files were built but not submitted.
- **MOTOR 2 vs WENDY 9 per motor peril** (`week1/R/6_w9_motor_peril_check.R`): MOTOR 2 ranks every motor peril better except theft in 2023 (calibrated peril D2, e.g. BI 0.070 / 0.062 vs 0.059 / 0.054), but re-weighting per peril on top of the line-level m 0.5 blend did not beat the 0.12965 file.
- **MOTOR 4 (held-out test).** Candidate chosen on 2023 = TPP LightGBM-from-GLM, BI MOTOR 2 GLM, theft LightGBM (each at weight 1), glass_hail GLM 0.25, rescaled to the WENDY 9 peril totals. Gain vs the 0.12965 file: 2023 +0.00126 (motor, developed); held-out 2024 +0.00018 (SE 0.00041) developed, +0.00086 (SE 0.00031) reported, all-line +0.00057 / +0.00037. Positive everywhere but fails the pre-set rule (> 2 SE on developed 2024); expected public change ~+0.0004, inside noise. File `submission_20261023_2059_w9_m2_motor04_A_FAIL.csv` (MD5 `2693eef07cd6c6b44e45ce1fbb41c4e8`), not submitted. `components.parquet` of MOTOR 4 / 5 (100-120 MB) is not committed - re-run the scripts (27 / 13 min).
- **MOTOR 5 (BI GAM).** Most smooths shrink to linear (edf ~1); only driver_age x years_licensed keeps curvature (edf ~6). Not better than the spline GLM.
- **MOTOR 6 (telematics, `week1/R/6_telematics_study.R`).** Only `telematics_opt_in` (12-13% of rows) and `telematics_score` exist, and both are fixed for the life of a policy, so year-on-year features are empty. Against MOTOR 2, own_damage A/E falls with the score (2023: 1.03 for scores 1-40 to 0.71 for 80-100) because MOTOR 2's own_damage / BI GLMs used only the opt-in flag; BI bands disagree between years. Adding the score lifts own_damage peril D2 by +0.0001 / +0.0004 and BI not at all; candidate gain vs the 0.12965 file: 2023 +0.00066, held-out 2024 +0.00025 developed (SE 0.00036), all-line +0.00036 - fails the rule, no better than MOTOR 4.
- **MOTOR 7 (version averaging, `week1/R/6_motor_version_avg.R`).** Averaging the three frequency versions per peril beats every single version on peril D2 in both years (own_damage 0.1719 / 0.1786, TPP 0.0641 / 0.0572, theft 0.0781 / 0.0897, glass_hail 0.1453 / 0.1426); BI keeps the MOTOR 2 GLM. Chosen on 2023: TPP average 1, BI GLM 1, theft average 0.5. Held-out 2024 vs the 0.12965 file: +0.00020 developed (SE 0.00041), +0.00087 reported, all-line +0.00037 - same as MOTOR 4. File `submission_20261023_2223_w9_m2_motor07_A_FAIL.csv` (MD5 `a6e9d344a557ae31479108b30372cae8`) was submitted: public 0.12904, private 0.13933 (best private).
- **Peril headroom** (`week1/R/6_peril_headroom.R` -> `week1/output/6_peril_headroom/`): all-line D2 gained per +0.01 peril D2 inside the 0.12965 pipeline - contents theft 0.00046 (peril D2 only 0.035), buildings escape_of_water 0.00029, buildings fire 0.00027, motor BI 0.00022, buildings flood 0.00015, motor TPP 0.00014, contents escape_of_water 0.00014; motor own_damage / theft / glass_hail ~0 (the MOTOR 2 member already carries their ranking). Next work should target contents theft and buildings escape_of_water, not motor.
- **Recoveries on open claims** (organisers' answer: target = incurred - recoveries, excess already netted, declined claims excluded). No open claim has a recovery booked. Only motor own_damage (closed recovery ratio 23.6%) and theft (4.0%) recover; 2024 reported own_damage cost is ~5.5% too high because 23% of it is still open. WENDY 7 C5 deducts expected recoveries on open claims (`open_claim_recovery_adjust = Y`) and WENDY 9 takes own_damage and theft from C5, so the submitted files are on the right basis; MOTOR 1-5 and the WENDY 9 ladder do not adjust (ladder only used for TPP / glass_hail, which have no recoveries).
- **Lesson.** Every post-hoc change tuned on the 2023-24 folds (line m, per-peril weights, dispersion k) was flat or negative on public. Final picks: the 0.12965 file and WENDY 9 (0.12964).

**Final submission rebuilt from raw data** (`final_week1_R_Script/`, `Rscript run_all.R`, 25 Oct, about 11 h): rebuilds `submission_20261023_1636_w9_motor2_pre_m0.5.csv` in R. SAM 3 (tuning fixed to the original number of configurations), MOTOR 2, the WENDY 9 ladder and WENDY 8 N/E (exact R port of Wendy's Python) reproduce the submitted components to 6e-8. C5 differs by a median 1-3% per row because it was originally fitted on an Apple M4 Mac (XGBoost rounding differs from Windows), so the final file is within 0.5-0.7% per row (median; totals 0.9986 / 0.9999 / 0.9999; Spearman 0.9999). Details: `final_week1_R_Script/README.md`.

**Final results (private = other ~67% of test, revealed 24 Oct), all team submissions, best private first:**

| File | Author | Public | Private | What it is |
|---|---|---|---|---|
| `submission_20261023_2223_w9_m2_motor07_A_FAIL.csv` | Samuel | 0.12904 | **0.13933** | MOTOR 7 (averaged MOTOR 4 frequency versions) in the 0.12965 pipeline; MD5 `a6e9d344a557ae31479108b30372cae8` |
| `submission_20261023_1636_w9_motor2_pre_m0.5.csv` | Samuel | **0.12965** | 0.13923 | WENDY 9 + MOTOR 2 motor member m 0.5 |
| `submission_20261023_2010_w9_motor2_m0.5_bk1.075.csv` | Samuel | 0.12888 | 0.13898 | 0.12965 file + buildings stretch k 1.075 |
| `submission_20261023_1707_w9_per_peril_m2_k.csv` | Samuel | 0.12826 | 0.13881 | W9 + MOTOR 2 per peril + stretch k per line |
| `submission_20261023_wendy09.csv` | Wendy | 0.12964 | 0.13864 | WENDY 9 |
| `submission_20261023_wendy08_cred.csv` | Wendy | 0.12945 | 0.13842 | WENDY 8 (final2 + credibility) |
| `submission_20261023_wendy07_motor2_1359.csv` | Samuel | 0.12887 | 0.13830 | final2 with motor = MOTOR 2 at SAM 4 level |
| `submission_20261022_2135_wendy07_final.csv` | Wendy | 0.12924 | 0.13817 | WENDY 7 final |
| `submission_20261022_2328_wendy07_final2.csv` | Wendy | 0.12925 | 0.13781 | WENDY 7 final2 |
| `submission_20261022_1159.csv` | Wendy | 0.12818 | 0.13744 | SAM 3 |
| `submission_20261021_1528.csv` | Samuel | 0.12796 | 0.13739 | SAM 2 |
| `submission_20261022_2141_ben03.csv` | btkh95 | 0.12698 | 0.13696 | BEN 3 |
| `submission_20261022_2319_ben04.csv` | btkh95 | 0.12656 | 0.13644 | BEN 4 |
| `submission_20261022_0715_wendy04.csv` | Wendy | 0.12671 | 0.13631 | WENDY 4 |
| `submission_20261022_0912_wendy05.csv` | Wendy | 0.12636 | 0.13616 | WENDY 5 |
| `submission_20261023_0054_wendy04motor_sam04.csv` | Samuel | 0.12716 | 0.13590 | splice WENDY 4 motor + SAM 4 |
| `submission_20261022_1109_quick.csv` | Samuel | 0.12326 | 0.13271 | quick run |
| `submission_20261021_1650.csv` | Wendy | 0.12132 | 0.13169 | WENDY 3 |
| `submission_20261021_1658.csv` / `_20261022_1145` / `_1438` | btkh95 | 0.12224 | 0.13133 | BEN 1 (same file x3) |
| `submission_20261021_0951.csv` | Wendy | 0.12149 | 0.13095 | iteration 2 |
| `submission_20261022_2124_quick_ben03.csv` | btkh95 | 0.11969 | 0.13056 | BEN 3 quick |
| `submission_20261021_1336.csv` | Samuel | 0.11876 | 0.12822 | SAM 1 |
| `submission_provisional.csv` | Wendy | 0.11904 | 0.12679 | iteration 1 |

Readings:
- **Final chosen submission: `submission_20261023_1636_w9_motor2_pre_m0.5.csv`** (public 0.12965, private 0.13923), chosen on public before private was revealed; MOTOR 7 (not chosen) was 0.0001 higher on private.
- Public (33%) ranked the late submissions wrongly: MOTOR 7 was 0.0006 below the 0.12965 file on public but 0.0001 above it on private.
- The MOTOR 2 motor work paid off on private, although public showed nothing: adding MOTOR 2 to WENDY 9 (m 0.5) +0.0006 (0.13864 -> 0.13923; public +0.00001); MOTOR 2 motor in final2 +0.0005 (0.13781 -> 0.13830; public -0.0004); MOTOR 7 on top +0.0001 (held-out 2024 estimate +0.0004).
- Post-hoc calibrations tuned on the folds lost on private too (k 1.075 -0.00025, per-peril + k -0.0004 vs the 0.12965 file).
- WENDY 7 final2 was below WENDY 7 final on private (-0.0004) although equal on public.

To add a submission:
1. Run the latest `week1/R/4_models_iterXX.R`; it archives the file as `week1/output/submission/submission_<run id>.csv` and prints the log row
   (run id, models, local D² 2023 / 2024 combined and by line) in `week1/output/4_models/model_report.md`.
2. Upload that archived file to Kaggle.
3. Add a row above with the next `#`, the model `Iteration` it came from, date, time (SGT), run id / file, public D²,
   the local D² values (combined and by line) and what changed vs the previous submission. The `Iteration` column
   links the submission to its model card; the site's Model iterations page reads it to show public next to local D².
4. Commit the log update and rebuild the site (`week1/R/5_build_site.R`).

## Viewing everything in one place (`week1/R/5_build_site.R`)

Collects `README.md`, this file, the handover and every step report (with plots) into a Quarto website,
plus the column EDA pages (one per raw table and per cleaned line) and one gallery page per line with all
ranked one-way plots from step 5. Sources are staged in
`week1/output/site_src/` and rendered to `week1/output/site/`; open `week1/output/site/index.html`. Steps whose report does
not exist yet are skipped. Re-run it after any step script to refresh the site.
