# BEN's own steps (`week1/R/ben/`)

Cleaning and feature steps used by BEN's iterations from BEN 2 on. They live in this folder and write to their own
folders, so they never change what other iterations read. This page records **what differs from the shared
pipeline** and **how to import it later without clashing**.

| File | What it is |
|---|---|
| `week1/R/ben/ben_helpers.R` | Settings (type maps, history window) and helpers: `read_ben()`, `ben_out()`; chain-ladder IBNR helpers `dev_shares()`, `row_share()` (BEN 3). Source after `week1/R/0_setup.R`. |
| `week1/R/ben/ben_clean.R` | Step script (BEN 2). Run after `week1/R/2_clean.R` and `week1/R/3_incidence.R`: `Rscript week1/R/ben/ben_clean.R` |
| `week1/R/ben/ben_h2o.R` | h2o helpers for BEN 2 v3 (AutoML per peril): start h2o on a 64-bit JDK 17 (`BEN_JAVA_HOME`, else `~/tools/jdk-17*`), tune, refit, save/reload MOJOs |
| `week1/R/ben/ben3_study.R` | BEN 3 groundwork, read-only: excess, recoveries, open vs closed claims, monthly chain-ladder IBNR (per year vs per row, backtest at 31 Dec 2023), developed level and trend per line -> `week1/output/ben/ben3_study/` |
| `week1/R/ben/ben3_features.R` | BEN 3 groundwork, read-only: candidate point-in-time features and their signal beyond claims history; customer-table snapshot check -> `week1/output/ben/ben3_features/` |
| `week1/R/ben/ben3_data.R` | BEN 3 data step -> `data/week_1/ben3/` (see "BEN 3" below) |
| `week1/R/ben/ben4_data.R` | BEN 4 data step -> `data/week_1/ben4/`: point-in-time features and capped, chain-ladder-developed per-peril targets (see "BEN 4" below) |
| `week1/R/ben/ben4_tune.R` | BEN 4 tuning check for the LightGBM line Tweedie (categorical encoding, noise fields, tree size) -> `week1/output/ben/ben4/tune_<line>.csv` |
| `week1/R/ben/ben4_blend.R` | BEN 4 follow-up: per-line blend of all five BEN 4 variants on saved row-level predictions -> `week1/output/ben/ben4/blend_report.md` |
| `week1/R/ben/ben4_level.R` | BEN 4 follow-up: motor level sensitivity on the folds and a candidate with motor scaled to SAM 3's level -> `week1/output/ben/ben4/motor_level_sensitivity.csv` |

| Reads (shared, unchanged) | Writes (BEN only, git-ignored) |
|---|---|
| `data/week_1/clean/{train,test}_<line>.parquet`, `data/week_1/clean/claims_matched.parquet` | `data/week_1/ben/{train,test}_<line>.parquet`: the clean tables with the changes below |
| `data/week_1/raw data/policies_<line>.parquet` (`renewal_decision` only, BEN 3 and BEN 4) | `data/week_1/ben3/{train,test}_<line>.parquet`, `data/week_1/ben3/claims_pos.parquet`; `data/week_1/ben4/{train,test}_<line>.parquet` |
| `data/week_1/ben/{train,test}_<line>.parquet` (type fixes, BEN 4) | `week1/output/ben/ben4/`: data report, caps, loading, signal, tuning, row-level predictions, blend report, run logs |
| | `week1/output/ben/`: `ben_clean_report.md`, `feature_types.csv`, `history_summary.csv`, `history_signal.csv`, `ibnr_cost_by_peril.csv`; `ben3_study/`, `ben3_features/`, `ben3_data/` |

Run order with BEN 2: `week1/R/1_eda.R` -> `week1/R/2_clean.R` -> `week1/R/3_incidence.R` -> `week1/R/ben/ben_clean.R` -> `week1/R/4_models_iterben02.R`.
Run order with BEN 3: `week1/R/2_clean.R` -> `week1/R/ben/ben3_data.R` -> `week1/R/4_models_iterben03.R` (the two BEN 3 studies are optional and
only write reports).
Run order with BEN 4: `week1/R/2_clean.R` -> `week1/R/ben/ben_clean.R` -> `week1/R/ben/ben4_data.R` -> `week1/R/4_models_iterben04.R` (quick test:
`B4_QUICK=1`) -> optionally `week1/R/ben/ben4_blend.R`. `week1/R/ben/ben4_tune.R` only writes a comparison table.

## What is different from the shared pipeline

### 1. Data types match each column's meaning for tree models
XGBoost turns every feature into a number and splits on "less than / greater than", so a number must carry a real
order. The shared tables keep the raw types; `data/week_1/ben/` changes these:

| Column(s) | Shared `data/week_1/clean/` | `data/week_1/ben/` | Why |
|---|---|---|---|
| `credit_band` | text A-E (models rank levels by claim rate) | integer A=1 ... E=5 | ordered scale; keep the natural order |
| `energy_rating` | text A-G + `missing` | integer A=1 ... G=7, `missing` -> NA | ordered scale; missing is routed by the model, not given an arbitrary rank |
| `urban_density` | text | rural=1 < suburban=2 < urban=3 < dense_urban=4 | ordered scale |
| `security_level` | text + `missing` | standard=1 < locks=2 < alarm_and_locks=3, `missing` -> NA | ordered scale |
| `cover_type` | text | third_party_only=1 < third_party_fire_theft=2 < comprehensive=3 | breadth of cover |
| `branch_id` | integer 1-25 | text (category) | a label: branch 20 is not "more" than branch 3 |
| `start_month` | integer 1-12 | text (category) | December is not "far" from January |

Unchanged on purpose: true numbers and counts (ages, `ncb_years`, `flood_zone` 1-5, `vehicle_value_group`, excesses,
sums insured, weather), yes/no columns (0/1), and nominal text (region, occupation, make/model, ...), which BEN's
models encode as levels ordered by a credibility-weighted cost rate. Settings: `BEN_ORDINAL`, `BEN_AS_CATEGORY` in
`ben_helpers.R`.

### 2. Claims history known when the row starts (new columns)
Non-repudiated claims with a loss in the **365 days before the row starts** and **reported before it starts**, so only
information available at the time is used. 2021 rows are NA (no claims before 2021 in the data), so every year uses
the same one-year look-back. **Known issue (fix before reuse):** claims stop at the valuation date (2024-12-31), so test
rows starting after January see a shorter window than training rows - see "Open points".

| Column | Counts |
|---|---|
| `hist_policy_claims`, `hist_policy_cost` | the same policy's claims and their net cost |
| `hist_customer_other_claims` | the same customer's claims on their policies in the other two lines |
| `hist_address_property_claims` | buildings and contents claims at the same address on other policies |

Idea from Sam's iteration 2 (prior policy / customer / address claims), rebuilt here on the shared clean tables.

### 3. IBNR by peril on cost (new table, `week1/output/ben/ibnr_cost_by_peril.csv`)
The shared `ibnr_factors_by_peril.csv` (`week1/R/3_incidence.R`) grosses up claim **counts**. Late-reported claims are
larger (motor: about 19,500 average when reported after 90 days vs about 2,600 within 30 days), so for **cost**
models BEN 2 v2 uses factors weighted by claim cost (capped at p99.9 per peril). Both are in the table:
`ibnr_count` (should match the shared factors) and `ibnr_factor` (cost-weighted).
**In practice they differ by at most 0.04** (e.g. bodily injury 2024: 1.80 vs 1.76), so this change had no real effect.
What does matter is the timing of each row's exposure within its year - see "BEN 3".

## Importing into the shared pipeline later (no clash)
Each change can move on its own; none is needed by the others.

| Change | Where it would go | How to keep earlier iterations reproducible |
|---|---|---|
| Type fixes | `week1/R/2_clean.R`, as new columns (e.g. `credit_band_ord`) rather than overwriting | add the new columns to `NEW_FEATURES` in `week1/R/0_setup.R`, and drop the originals only for iterations that ask (`feature_cols(dt, include_new = TRUE)`) |
| Claims history | `week1/R/2_clean.R`, a section after the joins | `hist_*` columns into `NEW_FEATURES` |
| Cost IBNR | `week1/R/3_incidence.R`, a column next to `ibnr_factor` in `ibnr_factors_by_peril.csv` | a new column name, so scripts reading `ibnr_factor` are unaffected |

Then point BEN's scripts back at `read_clean()` and delete `data/week_1/ben/`. Until then, nothing in `week1/R/ben/`, `data/week_1/ben/` or
`week1/output/ben/` is read by anyone else's scripts.

## BEN 2 outcome (2026-10-22, run `20261022_1438`)
v0 (BEN 1 v6, one XGBoost Tweedie per line) was selected in every line, so the BEN 2 submission is byte-identical to
BEN 1 (MD5 `34dc2c9da29db5062b2ea2cabe3cf928`, public 0.12224). Line D² 2023 / 2024 (reported actuals):

| Line | v0 (BEN 1) | v1 per-peril XGB | v2 + BEN data | v3 h2o per peril |
|---|---|---|---|---|
| motor | 0.0384 / 0.0514 | 0.0119 / 0.0510 | 0.0097 / 0.0512 | 0.0511 / -1.32 |
| buildings | 0.0686 / 0.0731 | 0.0625 / 0.0719 | 0.0605 / 0.0707 | 0.0587 / 0.0614 |
| contents | 0.0625 / 0.0625 | 0.0534 / 0.0592 | 0.0578 / 0.0595 | 0.0606 / 0.0539 |

- v1 / v2: per-peril XGBoost reused the line's tuned settings; sparse perils stopped early and totals came out low
  (buildings 2023 pred/actual 0.83). Per-peril tuning plus a level step (balance factor or GLM) are needed.
- v3: h2o 3.44 AutoML is not usable for this problem as is. Its Tweedie GLMs use an identity link (near-flat,
  D² ~ 0); its Tweedie GBMs predict about half the total with near-zero predictions on some rows (D² -0.1 to -3000 per
  peril on 2022; leaf-step caps and larger leaves did not help); GBMs fail outright with monotone constraints; no
  XGBoost on Windows. The extra log-link Tweedie GLM candidate won 13 of 15 perils and is strong on flood (D² ~0.4),
  motor own damage (0.16) and accidental damage (0.14), but flat on fire and subsidence. Motor 2024 blew up
  (third_party_prop predictions 2.9 million x actual), most likely from unbounded numeric inputs such as
  `hist_policy_cost` in a log-link GLM. Confirmed in BEN 3's review: the 11.9m open bodily-injury claim (loss
  2023-06-25) becomes `hist_policy_cost` = 11,894,277 on one 2024 motor row.

## Open points (for BEN 3; status after BEN 3 in brackets)
- **History window vs the valuation date.** Share of rows with a prior policy claim, motor: test Q4 0.31% vs train
  2024 Q4 3.00% (Q1 matches: 10.0% vs 10.2%), so about 15% of test rows look claim-free when they may not be. Fix:
  count claims reported before 1 January of the row's policy year, for train and test alike. [Done in BEN 3: losses in
  the previous calendar year reported by 1 January; test Q4 2.4% vs train 2.2%.]
- **Validation basis.** Selection uses reported actuals while predictions are ultimate, which penalises the variants
  that develop more; `d2_developed` uses count IBNR even for cost-IBNR variants. Agree one basis with the team (WENDY 4
  uses developed actuals). [BEN 3 chooses per peril on developed actuals and reports D² on reported actuals for
  comparison with SAM 3.]
- **Training weight vs the metric.** Rate targets weighted by exposure are the Tweedie MLE, but the Kaggle metric is
  unweighted on row totals, which equals weighting rates by exposure^(2 - p) = sqrt(exposure). Worth one experiment.
- **GLM inputs must be bounded:** cap or log money amounts (`hist_policy_cost`, sums insured) before log-link GLMs.
  [BEN 3: history cost is log1p of costs capped at 50k; GLM numerics are binned into sextiles.]
- IBNR curves come from 2021-22 losses, so long-tail perils (bodily injury) are likely under-developed; reported
  claim costs are taken as final (no IBNER). [BEN 3: monthly chain ladder on all accident months instead; open claims
  checked against closed ones of the same peril, year and report delay (ratio 1.03-1.09), so no IBNER loading.]
- History uses a fixed one-year look-back; a longer window would leave 2022 rows partly empty.
- `make_model` (300 levels), `previous_insurer` and `occupation` stay as cost-ordered categories; the leakage screen
  showed little out-of-time signal for them, so they are candidates to drop or group.

## BEN 3 (2026-10-22)

### What the studies found (`week1/output/ben/ben3_study/`, `week1/output/ben/ben3_features/`)
| Topic | Finding | Used in BEN 3 |
|---|---|---|
| Level | Every BEN submission so far predicts the lowest 2025 cost of the team in every line (motor / buildings / contents 505 / 456 / 122 vs SAM 3 603 / 487 / 125). Developed, recovery-adjusted, 2m-limited experience trended on 2021-23 gives about 548-560 / 489 / 128 | GLM sets the level, with a year trend; level compared with this anchor in the card |
| Motor trend | The +2% a year in reported motor cost 2021-23 comes only from the 11.9m claim; without it motor is flat to -1% a year. Bodily-injury severity falls about 7% a year 2021-23 (SAM 3 uses +4.5%) | Trend fitted per peril inside each GLM, all years, capped at +-10% |
| IBNR | Per-year factors (current method) and a monthly chain ladder agree on totals; the gap is timing. Backtest at 31 Dec 2023: late claims of rows starting in Q4 were 25 (buildings) vs 14.7 predicted per row and 2.3 per year | Per-row chain-ladder reported share; frequency uses exposure x share (effective exposure) |
| Open claims | Open vs closed claims of the same peril, year and report delay: 1.03-1.09x; bodily-injury severity drop also in closed (final) claims | No IBNER loading |
| Recoveries | Only own damage (30% of closed claims recover exactly 80%) and theft (13% recover 30%); open claims have none yet | Open own-damage / theft claims reduced by the closed-claim recovery ratio (motor 2024 -1.4%) |
| Excess | Already deducted. At 1,000 voluntary excess, small-claim perils fall to 0.26-0.59x frequency, third-party perils 0.67-0.90x (mostly self-selection) | Feature; frequency monotone decreasing in excess except bodily injury and third-party property |
| History window | Claims history counted at 1 January matches train and test in every start quarter | Previous calendar year, reported by 1 January |
| New features | Peril of the last claim (repeat flood 2.6-2.8x), previous row declined by the insurer (about 2x), lines held (about 5% lower with 3 lines). No signal: repudiated claims, premium move, excess change, vehicle change, moving | `hist_pol_n_<peril>`, `prev_declined`, `mid_term`, `n_lines` |
| Point in time | The customer table is one snapshot per customer, apparently recorded late (`years_at_address` above age - 18 on 14.8% of 2021 rows vs 7.9% of 2025 rows) | Kept, listed as a guardrail risk (`licence_points`, `credit_band`, `years_at_address`) |

### Data step (`week1/R/ben/ben3_data.R` -> `data/week_1/ben3/`)
Targets: claims with cost > 0 per peril (`y_npos_<peril>`), recovery-adjusted cost (`y_costadj_<peril>`), per-row
chain-ladder shares (`y_sharen_<peril>` counts, `y_sharew_<peril>` capped cost). Features: BEN type fixes, SAM's
engineered fields, history as at 1 January (`hist_pol_n`, `hist_pol_cost`, `hist_pol_n_<peril>`, `hist_cust_other_n`,
`hist_addr_flood/water/subs/storm`), `prev_declined`, `mid_term`, `n_lines`.

### Model (`week1/R/4_models_iterben03.R` -> `week1/models/ben_iteration_03/`)
One model, no variant ladder. Per peril: frequency = quasi-Poisson GLM (level, year trend) or GLM level + XGBoost Poisson
shape; severity = Gamma GLM with factors or trend only, on claims capped at p99.5 with a cap loading. The form is chosen
per peril on mean D² against developed peril cost over the 2023 and 2024 folds; trees for perils with fewer than 3,000
claims are shallower. Current pricing (`written_premium`, `premium_index`) and noise fields are excluded. Saved as
`sam02_peril` artifacts, so `week1/R/model_io.R` scores them unchanged. Results and the comparison with SAM 3: the model card.

### Result (run `20261022_2141`, about 45 minutes)
Combined D² 0.1065 / 0.0985 (2023 / 2024) against SAM 3's 0.1043 / 0.0986 on the same folds and actuals. Motor ahead
of SAM 3 in both folds (+0.006 / +0.004), contents level, buildings behind (-0.002 / -0.005). 2025 cost per
exposure-year 549 / 498 / 128 (motor / buildings / contents). Chosen forms: GLM alone for bodily injury, motor theft and
glass, buildings fire and flood, contents theft; GLM level + tree shape elsewhere.

Next (not done): the motor level (bodily-injury severity trend, -7.8% here vs SAM 3's +4.5%) is the biggest open
question - the public score of this file answers it; buildings tuning (it is the weak line); averaging with SAM 3 /
WENDY 4; a sqrt(exposure) weight experiment.

## BEN 4 (2026-10-23)
Goal set for this iteration: public D² of 0.3 (best was SAM 3's 0.12818), using only the competition data. Personal working
notes with every step, dead end and number: `notes/ben_iteration_04_notes.md` (local only: `notes/` is git-ignored).

### Leakage screen of the test file (nothing usable)
| Check | Finding |
|---|---|
| `declined_by_insurer` rows | 95% have a claim; 25-35k per exposure-year; 35% / 52% / 24% of motor / buildings / contents cost. The decision falls at the end of the row (rows run the full year), so a 2025 test row does not show it. Used only as history (`b4_prior_declines`) |
| Row shape in its own year | 18,978 motor test rows end in a mid-term change, ~36k end early. Burn relativity 0.88-1.07 in every line: no signal. The 1.4-2x seen first compared with renewed rows, which exclude the declined ones |
| `customer_service_contacts` in test | Mean ~0.40, as no-claim train rows: no claim information. The previous row's contacts are fine (3+ -> 1.6x) |
| Row id order | Burn by row-id decile varies only through single large claims; not used |

### Data step (`week1/R/ben/ben4_data.R` -> `data/week_1/ben4/`, 10 minutes)
On top of `data/week_1/ben/` (type fixes; the 365-day `hist_*` columns are dropped). Claims history as at 1 January
(`b4_n_prev1`, `b4_n_prev2`, `b4_n_all`, `b4_cost_all`, `b4_rate_all`, `b4_n_<peril>`, `b4_last_peril`, `b4_years_since`,
`b4_n_repudiated`, `b4_cust_other_*`, `b4_addr_other_all`), previous row (`b4_prev_decision`, `b4_prev_contacts`,
`b4_prev_exposure`, `b4_premium_move`, `b4_excess_change`, `b4_vehicle_changed`, `b4_moved`, `b4_si_ratio`), earlier
declines and contacts rate, row shape (`b4_ends_in_change`, `b4_after_change`, `b4_ends_early`, `b4_rows_in_year`),
holdings. Targets: per-peril claim cost capped at p99.9 of 2021-23 claims (`y_cap_<peril>`), loading = cost limited to
2m / capped cost (1.001-1.018), chain-ladder development per row and peril (`dev_n_<peril>`, `dev_w_<peril>`, from
`dev_shares()` / `row_share()`).

### Model (`week1/R/4_models_iterben04.R` -> `week1/models/ben_iteration_04/`, about 35 minutes)
LightGBM ladder v0-v5 (see `week1/docs/workflow.md`), folds fit 2021-22 -> 2023 and 2021-23 -> 2024, selection per line on
developed D². Text features become numbers ordered by a credibility-weighted rate of the model's own target (line: 200
exposure-years; peril: 30 expected claims): LightGBM's native categorical splits overfit (`week1/R/ben/ben4_tune.R`, motor 2023
0.022 -> 0.039). Depth-3 trees, early stopping on a 15% policy holdout, refit at 1.1x the best round, balance to the
fitted total. Trend: log-linear developed burn of the fit years, clamped to -3% / +6%. Ceiling simulation: v4's 2024
means as the truth, claims simulated with each peril's claim-size shape.

### Result (run `20261022_2319`): public D² 0.12656 (submission #16)
Combined D² 0.1033 / 0.1000 (2023 / 2024), developed 0.1042 / 0.1068; selected motor v2, buildings and contents v5;
2025 cost per exposure-year 530 / 502 / 129. Level with SAM 3 and BEN 3 locally, 0.0016 below SAM 3 in public.
- **The 0.3 target is not reachable without leakage.** Ceiling 0.097-0.104 local = the realised D²; public ≈ local + 0.025.
- The point-in-time features help motor 2024 only; sqrt(exposure) weighting and a five-variant blend (`week1/R/ben/ben4_blend.R`)
  do not pass the both-folds rule.
- Motor predicts 0.94 / 0.95 of developed actuals; public scores rise with the motor level. `week1/R/ben/ben4_level.R` writes
  `submission_20261022_2319_ben04_motor603.csv` (motor x1.139 to SAM 3's 603) as the level test; local developed D² is
  best at x1.05-1.10.
- Guardrail: `premium_index` (current pricing) is the top or second feature in every line; BEN 3 excludes it.

Next (not done): upload the motor-603 file; if it beats 0.12656 clearly, refit motor's level (bodily-injury trend) rather
than scaling; average BEN 4 with BEN 3 / SAM 3 on saved row-level predictions (BEN 3 and SAM 3 would need to save theirs).
