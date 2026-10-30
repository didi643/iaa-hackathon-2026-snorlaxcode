# Week 2 handover for Claude Code: emerging market, Option B (developed baseline + emerging adjustments)

Prepared 25 Oct 2026 for Wendy's Kaggle IAA Hackathon 2026 repo: `/Users/wendylow/Claude/Kaggle_2026`.

Read this whole file before doing anything. Then read `week_2/CLAUDE.md`, the repo-root `CLAUDE.md` and `final_week1_R_Script/README.md` (the week 1 final model).

---

## 0. Ground rules (non-negotiable)

1. **Work only inside `week_2/`.** Create everything there: scripts, outputs, models, docs and data caches.
   - Read-only: `data/week_1/`, `data/week_2/`, `R/`, `final_week1_R_Script/`, `python/`, `models/`, `output/`, `docs/`.
   - Don't edit, move or delete anything outside `week_2/`.
   - To reuse a week 1 script, **copy** it into `week_2/R/` under a new name, and say in its header which file it was copied from.
2. **R only, for every run.** Use `Rscript week_2/R/<script>.R`, run from the repo root, with data.table, arrow, xgboost, lightgbm, readxl and splines.
   - No Python for any modelling, cleaning or scoring step.
   - Use only packages already in Wendy's R library. If a package is missing, stop and ask; don't install anything.
3. **Document every step as you go, not at the end.**
   - **`week_2/docs/step_log.md`:** one section per step, with:
     - date and time (SGT) and the script that ran;
     - inputs (path + MD5) and outputs (paths);
     - the key numbers and the decision taken, with the reason;
     - run time.
   - **`week_2/docs/decision_register.csv`:** columns `id, date, step, decision, alternatives_considered, evidence (file), status`.
   - **`week_2/docs/assumptions_week2.xlsx`:** every assumption with its value, source (developed / emerging / judgement) and sensitivity. Write it with `writexl` or `openxlsx`, whichever is installed.
   - **Script headers:** every script starts with a header giving purpose, inputs, outputs, run command and expected run time (the week 1 style).
   - **Run log:** every script writes a log to `week_2/run/logs/<script>.log` and appends start/end lines to `week_2/run/status.log`.
4. **Reproducibility.**
   - Fixed seeds.
   - Record `sessionInfo()` and package versions to `week_2/run/session_info.txt` at each step.
   - Record an MD5 for every input and output file.
5. **No Kaggle submissions.** Write candidate files to `week_2/output/submission/` and ask Wendy before anything is submitted; public submissions are limited.
6. **Don't invent anything.** If something is unclear, such as a column's meaning or whether a field may be used, write it in the step log as an open question and ask Wendy. Don't guess.
7. **Git:** work on a new branch `week2_optionB` created from `update_v3`. Commit after each step, with the step number in the message. Don't push unless Wendy asks.
   - Don't commit data, `*.parquet`, `*.rds` or files over 50 MB (`.gitignore` already blocks `/data/`, `*.parquet`, `*.rds`).

---

## 1. Task

**Week 2: "The New Market".** Predict the 2025 expected **ultimate** claim cost for every row in `emerging/test_motor`, `test_buildings` and `test_contents`.

**What the target covers**
- All claims with a loss date in the row's period.
- Net of the policy excess and of recoveries.
- Including claims not yet reported (IBNR).
- Excluding repudiated (declined) claims.
- It is a total for the row, not an annual rate. It is the risk premium, not the premium charged.

**Scoring and submission**
- Metric: Tweedie D2, power 1.5.
- Submission: one CSV, header `row_id,prediction`, every row in `emerging/sample_submission.parquet` (209,063 rows), all predictions ≥ 0.

**What the judges want to see**
- How the team identifies what changed between the markets.
- What it decides to carry over from Part 1.
- How it communicates the remaining uncertainty.

So the documentation is part of the deliverable, not an extra.

---

## 2. Data

| Market | Path | Contents |
|---|---|---|
| Developed | `data/week_1/` | Part 1 data, 2021–24. The Part 2 `developed/` folder is byte-identical; all 11 files were checked by MD5 on 25 Oct. |
| Emerging | `data/week_2/emerging/` | policies_{motor,buildings,contents}, test_*, claims, customers, addresses, weather, sample_submission, plus two new files: `expenses.parquet` and `reference_policies.parquet` |

### Profiling already done (Python, 25 Oct; repeat it in R in step 1 and confirm)

**Size**

| | Emerging 2023–24 | Developed |
|---|---|---|
| Claims | 9,258 | 163,150 |
| Exposure, motor / buildings / contents | ~54k / 34k / 39k | |
| Claims per peril | 52 (buildings subsidence) to 2,712 (motor OD) | |

- Buildings fire 70, flood 81, subsidence 52 claims; motor BI 450.

**2025 test portfolio**
- 76% new business, against 12–15% in training. The insurer takes on a broker portfolio.
- Test exposure is about 1.5 times the 2024 exposure.
- Test new business looks like the training new business on age band and cover type mix.

**Fields that differ**

| Table | Developed only | Emerging only |
|---|---|---|
| policies_motor | `driver_age`, `annual_mileage`, `telematics_score`, `telematics_opt_in` | `driver_age_band` |
| policies_buildings / policies_contents | `policyholder_age` | `policyholder_age_band` |
| customers | `credit_band`, `date_of_birth` | `gender` |
| addresses, weather | same columns in both | |

- Age bands are `17-24`, `25-34`, `35-49`, `50-64`, `65+`.
- Region codes are E01–E06 in emerging and R01–R12 in developed, with no mapping.
- **`gender`:** whether it may be used is a regulatory question. Ask Wendy before using it; the default is excluded, with a decision row in the register.

**Data quality traps found**
1. **Exposure in days:** about 150 rows per line (motor 189, buildings 117, contents 146) have exposure > 1, up to 365. Recompute exposure from `period_start`/`period_end` and log the rows changed.
2. **Claims outside any period:** 34 claims have loss dates in 2021–22, before the emerging book existed. Check they match no policy period, then drop them and log it.
3. **`renewal_decision`:** exists in training only, and is future information. Never use it as a feature. It may be used to understand lapses.
4. **Leakage and noise fields:** in Part 1, `customer_service_contacts` included claim calls, a leakage trap. Re-check it in emerging. Keep excluding `compulsory_excess`, `written_premium`, `customer_service_contacts` and the marketing/noise fields (email_domain, branch_id, campaign_code, marketing_segment, vehicle_colour) unless a documented test says otherwise.
5. **Re-run every Part 1 check** from `R/2_clean.R` on the emerging data: duplicates, key integrity, unmatched claims, negative amounts, repudiated status and so on.

**Experience differences (2023–24, net incurred, repudiated excluded; confirm in R)**

| | Developed | Emerging |
|---|---|---|
| Motor frequency | about 0.094–0.11 | about 0.123–0.13 (renewals) |
| Motor average claim | about 3,500–4,230 | about 2,200 |
| Buildings fire average claim | 51.7k | 62.1k |
| Buildings flood average claim | 31.4k | 26.3k |
| Report lag, median / p90 days | about 9 / 42 (motor) | about 9 / 41 (motor) |

- Emerging new-business frequency in motor: 0.209 against 0.130 for renewals in 2023, but only 0.143 against 0.123 in 2024, on 1.5–2.7k vehicle-years.
- Developed motor new-business frequency is a steady 1.3–1.5 times renewals.
- Reporting delays are about the same in both markets.

**New files**
- `expenses.parquet` holds loadings for both markets: fixed expense, variable expense, commission by channel, premium tax, cat reinsurance, profit margin.
- `reference_policies.parquet` holds 20 rows from the emerging test set (7 motor, 7 buildings, 6 contents) with mixed-line columns.
- Their purpose is not stated in the brief we have: probably a worked premium build-up for the documentation. **Ask Wendy** before using them for anything except an illustrative premium build-up.

---

## 3. Method: Option B (decided by Wendy, 25 Oct)

**The idea**
- Build the base relativities from the large developed book, using **only the fields both markets share**.
- Score every emerging row with it.
- Fit small, credibility-shrunk adjustments on the emerging data: level, the factors that behave differently, new business.
- Add loadings for 2025: trend, IBNR, large-loss load, and new-business mix if not already in the model.

**Why not score the emerging rows with the week 1 models as they are**
- Those models need `driver_age`, `annual_mileage`, telematics, `credit_band` and the R-region codes, none of which the emerging data has.
- Plugging in band midpoints or averages biases non-linear models, worst in the 17–24 band.
- So the developed baseline is **refitted** on harmonised features instead.

### Step plan (one script per step, numbered)

| Step | Script | What it does | Done when |
|---|---|---|---|
| 0 | `week_2/R/00_setup_week2.R` | Paths, logging, seeds, `sessionInfo()`, MD5 helper. Every week 2 script sources it. **Separate from the week 1 `R/0_setup.R`, which must not be changed.** | Writes `week_2/run/session_info.txt` |
| 1 | `01_profile_emerging.R` | Profile both markets in R: row counts, key integrity, column differences, the traps in section 2, experience by year × new business × line × peril, report lags, and how far emerging weather/address values fall inside the developed ranges. | `week_2/output/01_profile/` (CSV tables + `profile_report.md`); the section 2 numbers confirmed or corrected in the step log |
| 2 | `02_clean_week2.R` | Clean **both** markets with one shared function, adapted from `R/2_clean.R` (copied, not edited). Fix the traps, build the target as in week 1 (incurred − recoveries, repudiated = 0, net of excess), and add `market` = developed / emerging. | `week_2/data/clean/{developed,emerging}_{train,test}_<line>.parquet`, claims tables and a cleaning report |
| 3 | `03_harmonise_features.R` | Build the **shared feature set**. See the rules below. | `week_2/output/03_features/feature_map.csv` (column, developed source, emerging source, transform, kept / dropped, reason) |
| 4 | `04_ibnr_trend_week2.R` | Reporting patterns per peril from developed lags (thick); check them against emerging lags. Frequency and severity trends from developed, with emerging 2023→24 alongside. | Report shares and trend table with the decision on which to use, plus sensitivities |
| 5 | `05_developed_baseline.R` | Fit the **developed baseline** per peril on developed 2021–24 with the shared features only. See the recipe below. | Per-peril baseline frequency and severity; developed validation scores |
| 6 | `06_score_emerging_baseline.R` | Score every emerging training and test row with the baseline. Report A/E by line and peril, then by every factor (age band, cover, new business, channel, property type, weather bands and so on). | A/E tables and charts: the "what changed" evidence |
| 7 | `07_emerging_adjust.R` | Per peril, GLMs on the emerging data with offset log(baseline), frequency and severity separately. See the details below. | Adjustment coefficients with their credibility, and validation scores |
| 8 | `08_loadings_2025.R` | New-business loading, trend to 2025, IBNR, large-loss load. Each with a credibility blend of the emerging estimate and the developed prior, and a written rationale. | Loadings table and sensitivity grid |
| 9 | `09_validate_compare.R` | Validation protocol (section 4). Compare against benchmarks. | Scorecard and bootstrap verdicts |
| 10 | `10_final_week2.R` | Build the 2025 submission file: checks on rows, NA and ≥ 0, burn per line and peril against 2023–24 emerging, and the uncertainty ranges. | `week_2/output/submission/submission_<runid>_week2_optionB.csv` + MD5. **Not submitted.** |
| 11 | `11_docs_week2.R` | Build the documentation pack (section 5). | Docs complete |

### Rules for step 3 (feature harmonisation)

**Age**
- Create `driver_age_band` and `policyholder_age_band` in the developed data from the exact age, using **exactly** the emerging bands.
- Check the band edges against the emerging data first: is 24 in `17-24` and 25 in `25-34`?
- Then drop the exact age.

**Fields to drop from developed**
- Drop `annual_mileage`, `telematics_*`, `credit_band`, `date_of_birth`, and `cust_age` or any age built from the date of birth.
- Drop `region`. Codes don't map, so geography comes from the shared physical address fields (flood_zone, distance_to_river_km, elevation_m, soil_type, urban_density and so on) and the weather fields.
- Log, per line, how much developed predictive power the dropped fields carried. For example, compare developed validation D2 with all fields against shared fields only. This is part of the uncertainty story.

**Categories**
- For every categorical field, compare the category levels between markets.
- Map identical levels.
- Flag levels found only in emerging and send them to an "other" level; log them. `make_model` is the likely problem.

**Claim history**
- Allowed only if built the same way in both markets and known at row start.
- Emerging history is at most two years, and only about 24% of test rows are renewals.

**`gender`:** excluded unless Wendy approves.

### Recipe for step 5 (developed baseline)

- Start from the WENDY 7 C5 engine, `R/4_models_iterwendy07.R` with `docs/assumptions_wendy07_final2.xlsx`.
  - Copy both into `week_2/` as `week_2/R/05_developed_baseline.R` and `week_2/inputs/assumptions_week2_baseline.xlsx`.
  - In the workbook, edit the `Features_*` sheets to the shared feature set from step 3.
- Use **1 bag** (C5 used 5) to keep run time reasonable, and record that.
  - Run time to expect: C5 took about 24 minutes on the Mac at 5 bags, and 72 minutes inside the 11-hour Windows rebuild.
- Keep the week 1 per-peril method (frequency × severity or Tweedie), caps, large-loss loading and trend treatment unless step 4 says otherwise. Record any change.
- Use the same out-of-time folds as week 1: 2021–22 → 2023 and 2021–23 → 2024.
  - Report developed D2 with shared features against the week 1 C5 (0.1026, mean of 2023 and 2024, all lines, reported_raw), so the cost of losing those fields is known.
- Fit the final baseline on 2021–24. Save the models and the per-row frequency and severity predictions for emerging training and test rows. Use the model's own predict path; don't rebuild it.
- **Level:** don't use the developed intercept as the emerging level. The level is re-estimated in step 7. The baseline supplies relativities only.

### Details for step 7 (emerging adjustment)

**Frequency**, per peril: Poisson GLM with offset log(baseline frequency × exposure × reported share).
- Start with an intercept only. This is the level. Record the change in deviance and in 2024 D2.
- Add candidate factors **one at a time**, only where step 6's A/E slopes. Candidates: age band, cover type, new business, channel, property and contents fields, weather.
- Keep a factor only if it improves the 2023 → 2024 validation and makes actuarial sense.
- Use a ridge penalty (glmnet if installed, else manual shrinkage) so that factors with little data stay close to the developed relativity. This is credibility in GLM form.
- Log every factor tried: kept or rejected, with numbers.

**Severity**, per peril: Gamma GLM with offset log(baseline severity), level first.
- For sparse, heavy perils (buildings fire, flood, subsidence; motor BI; contents flood), use **only a level adjustment**: developed shape, emerging level.
- Cap claims as in week 1, and set the large-loss load from developed shape × emerging level.

**Benchmarks to build in the same step**
- **Benchmark E (emerging only):** simple per-peril GLMs on emerging data, no baseline.
- **Benchmark L (level only):** baseline × the per-peril level from step 7, with no factor adjustments.

### Step 8 loadings (each one: an emerging estimate, a developed prior, a credibility weight and the rationale)

- **New business:**
  - Emerging new business vs renewals by line and peril, weighted by credibility toward developed (motor about 1.3–1.5 times).
  - Check whether the step 7 new-business factor already covers it. Don't double count.
- **Trend to 2025:** developed trends by peril as the prior; emerging 2023 → 2024 alongside.
- **IBNR:** developed reporting pattern, checked against emerging lags. Two emerging loss years are too few for an emerging chain ladder.
- **Large-loss load:** per peril, from the developed capped-excess ratio, at the emerging level.

---

## 4. Validation protocol

Only two emerging years exist, so the honest out-of-time check is a single fold: fit on emerging 2023 (the baseline is fitted on developed only), then score emerging 2024.

- **Score on reported_raw and on developed actuals** (reported grossed up for IBNR), as in week 1.
- **Score twice:**
  - on the 2024 rows as they are;
  - on 2024 reweighted to the 2025 test mix: 76% new business, and the channel mix of the test file.
- **Paired policy bootstrap,** 200 draws. Expect noise several times larger than week 1's (week 1 was about 0.0011 on all lines). Accept a change only if it wins clearly and makes sense.
- **Compare four candidates:** B (full Option B), L (level only), E (emerging only), and a fixed 50/50 of B and E.
  - Pick on the reweighted 2024 D2, with judgement.
  - **No fine weight tuning on one fold.**
- **Check that predictions are well calibrated,** not just ranked well: A/E by line, peril, new business vs renewals, channel and age band.

---

## 5. Documentation pack (`week_2/docs/`)

| File | Content |
|---|---|
| `step_log.md` | Running log, one section per step (rule 3) |
| `decision_register.csv` | Every decision and the alternatives considered |
| `assumptions_week2.xlsx` | Every assumption with value, source, credibility weight, sensitivity |
| `what_changed.md` | Developed vs emerging, by line and peril: data fields, customer mix, climate/geography, frequency, severity, reporting, new business. Evidence: step 1 and step 6 tables |
| `what_we_carried_over.md` | For each Part 1 component (relativities, IBNR pattern, trends, caps and large-loss treatment, credibility on history, methods): **kept / adjusted / dropped**, and why |
| `uncertainty.md` | Range per line from the main uncertainties: new-business loading, trend, IBNR, large-loss load, level credibility, dropped developed fields. Low / central / high burn per exposure-year with the reasoning, plus bootstrap intervals |
| `model_card_week2.md` | Final model: structure, features, parameters, validation, 2025 burn by line and peril, file MD5 |
| `README_week2.md` | How to rerun everything from scratch, with the order and the commands |

Also add a short week 2 section to `docs/workflow.md`, the only file outside `week_2/` that may be appended to. Ask Wendy first.

---

## 6. Open questions for Wendy (ask before the step that needs them)

1. May `gender` be used (regulation)? Default: no.
2. What are `reference_policies.parquet` and `expenses.parquet` for: only an illustrative premium build-up, or something the judges require?
3. The submission limits for week 2, and when to submit.
4. Should the developed baseline be the C5 engine (default) or a simpler GLM baseline, if the C5 refit on shared features is too slow?

---

## 7. Starter prompt for Claude Code

> Read `week_2/HANDOVER_week2_optionB.md` in full, then `week_2/CLAUDE.md`, the root `CLAUDE.md` and
> `final_week1_R_Script/README.md`. Create branch `week2_optionB` from `update_v3`. Work only inside `week_2/`,
> use R for every run, and follow the step plan in section 3 one step at a time. Log each step in
> `week_2/docs/step_log.md` and `decision_register.csv` before moving to the next. Start with step 0 and step 1,
> then stop and show me the profile report before cleaning.
