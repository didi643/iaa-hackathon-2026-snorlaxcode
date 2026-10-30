# Technical Guide to the Final Week 1 and Week 2 Pricing Models, Peril by Peril

**Subtitle:** Frequency and severity specification for every peril, every credibility value and level adjustment, with sources and citations

**Audience:** actuaries. Standard pricing and reserving terms are used without explanation; every method is cited where it is first used.

**Author:** Wendy Low (using Claude), Team SnorlaxCode (Samuel Lim, Wendy Low, Benedict Tan)

This version: 30 October 2026 (week 2 final changed to submission #31 `motorlevel_l_full`)
First version: 28 October 2026

---

## Table of contents

- [Abbreviations and acronyms](#abbreviations-and-acronyms)
- [Greek letters and symbols](#greek-letters-and-symbols)
- [Summary](#summary)
- [1. Scope and how to read this guide](#1-scope-and-how-to-read-this-guide)
- [2. Conventions and methods](#2-conventions-and-methods)
- [3. Week 1: the mature-market model](#3-week-1-the-mature-market-model)
  - [3.1 What the final week 1 file is](#31-what-the-final-week-1-file-is)
  - [3.2 Step 1: cleaning the data](#32-step-1-cleaning-the-data)
  - [3.3 Step 2: late-reported claims](#33-step-2-late-reported-claims)
  - [3.4 Building block A: SAM 3](#34-building-block-a-sam-3)
  - [3.5 Building block B: WENDY 7 C5](#35-building-block-b-wendy-7-c5)
  - [3.6 Building block C: MOTOR 2](#36-building-block-c-motor-2)
  - [3.7 Building block D: the WENDY 9 ladder](#37-building-block-d-the-wendy-9-ladder)
  - [3.8 Building block E: WENDY 8 claim-history credibility](#38-building-block-e-wendy-8-claim-history-credibility)
  - [3.9 The final week 1 blend](#39-the-final-week-1-blend)
  - [3.10 Week 1, peril by peril](#310-week-1-peril-by-peril)
  - [3.11 How well week 1 scores](#311-how-well-week-1-scores)
- [4. Week 2: the emerging-market model](#4-week-2-the-emerging-market-model)
  - [4.1 The problem in week 2](#41-the-problem-in-week-2)
  - [4.2 Data and fields](#42-data-and-fields)
  - [4.3 Late claims and inflation](#43-late-claims-and-inflation)
  - [4.4 The mature-market baselines](#44-the-mature-market-baselines)
  - [4.5 The emerging adjustment](#45-the-emerging-adjustment)
  - [4.6 The severity blend](#46-the-severity-blend)
  - [4.7 Moving to 2025](#47-moving-to-2025)
  - [4.8 The final step: a motor level review](#48-the-final-step-a-motor-level-review)
  - [4.8A Leaderboard probing: tried and set aside](#48a-leaderboard-probing-tried-and-set-aside)
  - [4.9 Week 2, peril by peril](#49-week-2-peril-by-peril)
  - [4.10 How well week 2 scores](#410-how-well-week-2-scores)
- [5. Every credibility value in one place](#5-every-credibility-value-in-one-place)
- [6. Known limits](#6-known-limits)
- [7. Conclusion](#7-conclusion)
- [Appendix A. Week 1 WENDY 7 C5 feature lists](#appendix-a-week-1-wendy-7-c5-feature-lists)
- [Appendix B. Week 2 fitted multipliers](#appendix-b-week-2-fitted-multipliers)
- [Bibliography](#bibliography)

---

## Abbreviations and acronyms

| Abbreviation | Meaning |
|---|---|
| A/E | actual divided by expected |
| AD | accidental damage |
| BF | Bornhuetter-Ferguson |
| BI | bodily injury (motor) |
| CL | chain ladder |
| CU | currency unit |
| CV | cross-validation |
| MD5 | Message-Digest Algorithm 5 (a file fingerprint) |
| D² | deviance explained (the Kaggle score) |
| ECDF | empirical cumulative distribution function |
| EoW | escape of water |
| GBM | gradient-boosting machine |
| GLM | generalized linear model |
| IBNER | incurred but not enough reported |
| IBNR | incurred but not reported |
| ILF | increased limit factor |
| IRLS | iteratively reweighted least squares |
| LDF | loss development factor |
| LightGBM | Light Gradient-Boosting Machine |
| LW | line weight |
| NB | new business |
| OD | own damage (motor) |
| SAM | Sam's iteration label (a project name, not an abbreviation of words) |
| SD | standard deviation |
| SE | standard error |
| TPFT | third party, fire and theft (motor cover type) |
| TPO | third party only (motor cover type) |
| TPP | third-party property (motor) |
| XGBoost | Extreme Gradient Boosting |

## Greek letters and symbols

| Symbol | Name and how to say it | Use in this guide |
|---|---|---|
| λ | lambda ("LAM-duh") | a ridge penalty, counted in claims |
| μ | mu ("mew") | a predicted mean |
| Σ | capital sigma ("SIG-muh") | "add these up" |
| η | eta ("AY-tuh") | a value on the log scale, before taking `exp` |
| φ | phi ("fye") | how much more spread out claim counts are than a Poisson count |
| θ | theta ("THAY-tuh") | the true-to-predicted cost ratio of a segment in 2025 |

---

## Summary

This guide documents the two final submissions of the IAA AI-Assisted Actuarial Hackathon 2026 on Kaggle. Both predict the 2025 risk premium of every policy as the sum over 15 perils of expected frequency × expected severity, and both are scored by Tweedie D² at power 1.5.

**Week 1** (developed market, 2021-24; file `submission_20261023_1636_w9_motor2_pre_m0.5.csv`; public 0.12965, private 0.13923) is a blend of five blocks: C5, a per-peril XGBoost / Gamma GLM frequency-severity engine driven by an assumptions workbook; the WENDY 9 LightGBM ladder; SAM 3, a line-level ensemble of GLMs and GBMs; MOTOR 2, motor spline GLMs with severity credibility and BI frequency pooled with TPP; and WENDY 8, Poisson-Gamma experience rating on each policy's own claim history. Counts are developed to ultimate with a quarterly chain ladder; severities are capped with a peril large-loss load and trended log-linearly.

**Week 2** (emerging market, 2023-24; file `submission_20261030_0905_week2_motorlevel_l_full.csv`, submission #31; public 0.16840) takes its relativities from the C5 engine refitted on the developed market (shared fields for motor; a re-tuned version for buildings and contents). Emerging levels and up to four emerging-only factors per peril are fitted as ridge-penalised GLMs with the developed prediction as offset, with credibility toward the line pool (K = 200 claims for frequency, 400 or 1,200 for severity). A credibility-weighted trend and a new-business load project to 2025. A final actuarial review of the motor level, made from the training data only, sets BI severity × 1.1159 (trend from mature loss years, severity development, benchmark large-loss load) and motor new-business rows × 1.0611 (full emerging new-business A/E). Levels read from public-leaderboard probes were tested and set aside as not real-world practice (Section 4.8A).

All credibility constants are in Section 5 and the known limits in Section 6.

---

## 1. Scope and how to read this guide

**Scope.** Section 2 sets out the conventions and the standard methods used by both models. Section 3 describes the week 1 model in build order (data, IBNR, the five blocks, the blend) and then gives a card for each of the 15 perils with every frequency and severity setting. Section 4 does the same for week 2, including the final motor level review (Section 4.8) and the probing record (Section 4.8A). Section 5 collects every credibility value, Section 6 the known limits. Appendix A lists the C5 rating factors and Appendix B the fitted week 2 multipliers.

**Main findings.** In week 1, per-peril frequency × severity with several model types, blended by peril and line, beats any single model type, and experience rating on own claim history adds a further 0.001 to 0.0014 of D². In week 2, developed-market relativities combined with credibility-weighted emerging levels beat either market's data used alone, and an actuarial review of the motor level, built only from the training data, raises the public score from 0.16690 to 0.16840.

**Source references.** Every number is read from the project file named next to it. Paths are relative to the repository root. In Section 3, paths starting `R/`, `inputs/`, `models/`, `output/` or `run/` are relative to `week1/final_week1_R_Script/`. Generated model outputs that are not kept in git (they are recreated by the rebuild) are copied, with the same relative path, under [`dummy_guide/sources/`](sources/). The companion workbook [`dummy_guide_for_the_final_models_Workbook.xlsx`](dummy_guide_for_the_final_models_Workbook.xlsx) maps each section to its source files.

**Citations.** Methods are cited in footnotes at first use (Chicago notes style); the full list is in the Bibliography. Project documents are cited by their path in this repository.

---

## 2. Conventions and methods

### 2.1 Lines, perils and exposure

| Line | Perils |
|---|---|
| Motor | own damage (OD), third-party property (TPP), bodily injury (BI), theft, glass and hail |
| Buildings | storm, flood, escape of water (EoW), subsidence, fire, accidental damage (AD) |
| Contents | theft, escape of water, accidental damage, flood |

Exposure is earned policy-years, recomputed in both weeks as `(end date − start date + 1) / 365`.[^clean] Each peril is priced as frequency × severity, the standard pure-premium approach that lets different rating factors drive different perils.[^werner][^ohlsson]

### 2.2 Claim basis

Claim cost is net incurred: `incurred to date − recoveries`; repudiated claims cost 0.[^clean] Week 1 C5 and week 2 also (a) deduct an expected recovery from open claims with no recovery booked, at the closed-claim ratio `Σ recoveries / Σ incurred` for the same line and peril, and (b) limit any single claim to 2,000,000.[^c5code] Valuation date: 31 December 2024 in both markets.

### 2.3 Score

The target is a Tweedie compound Poisson-Gamma variable with power 1.5.[^tweedie][^jorgensen] The project scores with the unit deviance and D² against a flat-rate null model:[^w2setup]

```
deviance(y, μ) = 2 × [ y^(2−p) / ((1−p)(2−p))  −  y × μ^(1−p) / (1−p)  +  μ^(2−p) / (2−p) ],   p = 1.5
D² = 1 − Σ deviance(actual, model) / Σ deviance(actual, flat rate)
```

Most policies have no claim in a year, so D² of 0.13 to 0.17 is a strong result on this data.[^w2write] With p = 1.5 the deviance penalises under-prediction of a large claim by `4y / √μ`, so the score is sensitive to the level of high-cost segments (relevant to Sections 4.8 and 4.8A).

### 2.4 Model families

- **GLMs** with log link: Poisson (or quasi-Poisson) frequency with `log(exposure × reported share)` as offset; Gamma severity on capped average claim.[^nelder][^mccullagh] Numeric fields enter as quantile bins or as natural splines.[^hastie90]
- **Gradient-boosted trees**: XGBoost[^xgb] and LightGBM[^lgbm] (Friedman's gradient boosting[^friedman]) with Poisson, Gamma or Tweedie objectives.

| Parameter | Role |
|---|---|
| `max_depth`, `num_leaves` | tree size, i.e. interaction order |
| `learning_rate` (eta) | shrinkage per tree |
| `min_child_weight` / `min_sum_hessian_in_leaf`, `min_data_in_leaf` | minimum Hessian or rows per leaf |
| `subsample` / `bagging_fraction`, `colsample_bytree` / `feature_fraction` | row and column sampling |
| `reg_lambda` / `lambda_l2` | L2 penalty on leaf values |
| rounds, early stopping | number of trees; stop when the holdout deviance stops improving |

- **Holdout by policy.** Early stopping uses 10% of *policies* (all their years together), so a policy's own later years never validate its earlier years.
- **Bagging.** Each GBM is refitted over several seeds and averaged.[^breiman]
- **Monotone constraints** fix the sign of selected relativities in XGBoost (Appendix A).
- **Balance factor.** After fitting, predictions are scaled so the training total equals the actual total.

### 2.5 Credibility and penalisation

Level credibility uses the Bühlmann form

```
Z = n / (n + K),   estimate = Z × own experience + (1 − Z) × complement
```

with `n` in claims and K fixed by judgement and tested on the following year.[^buhlmann67][^bg] The complement is chosen per use: the line pool for peril levels, the developed market for the week 2 BI large-loss load.[^boor] For factor levels inside a GLM the same effect comes from a ridge penalty λ expressed in expected claims: a level with `m` expected claims keeps about `m / (m + λ)` of its own effect.[^hoerl][^w2adj] Experience rating on own claim history (Section 3.8) uses the exact Poisson-Gamma (Bühlmann-Straub) form.[^bs][^jewell]

### 2.6 IBNR

Claim counts are developed with a volume-weighted chain ladder on a quarterly loss × report-quarter grid, tail factor 1.[^mack][^friedland] The reported share (1 / cumulative LDF) multiplies exposure, so every frequency model fits ultimate frequency and recent policy years are not treated as better risks.[^lawless] In the core models only counts are developed; IBNER on case estimates is not modelled.[^w1method] The week 2 final step adds BI severity development (Section 4.8).

### 2.7 Large-loss cap and load

Claims are capped at a high percentile of the peril; the severity model is fitted to capped claims and the excess is restored as a flat peril load `Σ uncapped / Σ capped`, the basic-limit plus excess-load logic of increased-limits pricing.[^klugman][^miccolis]

### 2.8 Trend

Frequency and severity trends are fitted log-linearly on yearly averages (severity on capped claims), clamped to a range, and used to bring each year to the projection year.[^werner]

---

## 3. Week 1: the mature-market model

This section describes the week 1 model in the order it is built, then lists every peril.

### 3.1 What the final week 1 file is

The final week 1 file is `submission_20261023_1636_w9_motor2_pre_m0.5.csv`, public score 0.12965, private score 0.13923. The R rebuild is in `week1/final_week1_R_Script/` and runs in nine stages.[^w1readme]

| Stage | Script | What it builds |
|---|---|---|
| 1 clean | `R/2_clean.R` | cleaned tables |
| 2 ibnr | `R/3b_ibnr_study.R` | chain-ladder reported shares |
| 3 sam3 | `R/4_models_itersam03.R` | block A |
| 4 sam4 | `R/4_models_itersam04.R` | SAM 3 with stage 2 shares (its total does not reach the final file, see 3.6) |
| 5 c5 | `R/4_models_iterwendy07.R` + `inputs/assumptions_wendy07_final2.xlsx` | block B |
| 6 motor2 | `R/4_models_itermotor02.R` | block C |
| 7 history | `R/5_history.R` | block E inputs |
| 8 ladder | `R/6_ladder.R` | block D |
| 9 blend | `R/9_final_blend.R` | final file |

The seed for every random draw starts from `SEED = 2026` (`R/0_setup.R:35`).

### 3.2 Step 1: cleaning the data

The same cleaning function is used for training rows and 2025 rows, so both are treated alike.[^w1method]

| Rule | What is done |
|---|---|
| Customer ID | padded with leading zeros to 8 characters |
| Exposure | recomputed as `(end − start + 1) / 365` |
| Sum insured | divided by 1,000 when above 5 million (buildings) or 2 million (contents) and divisible by 1,000 |
| Construction type | upper case; codes `T` and `W` become timber |
| Years licensed | capped at `driver_age − 16` |
| `renewal_decision` | dropped: it describes what happened after the period (it leaks the answer) |
| Duplicate claims | 604 removed |
| Unmatched claims | claims whose loss date falls in no policy period are left out (296 motor, 67 buildings, 50 contents, plus 252 on 2020-12-01) |
| Missing text values | set to the level `"missing"` |

Fields never used as rating factors: IDs, raw dates, surname, date of birth, `customer_service_contacts` (it rises after a claim, so it leaks the answer), `written_premium` and `discount_applied` (current price, not risk), `noise_probe`, and marketing fields.[^w1method] Two exceptions exist in the rebuilt code: `compulsory_excess` stays in the SAM 3 tree models and in C5, and `noise_probe` stays in the SAM 3 tree models (`R/4_models_itersam03.R:56-57`; C5 feature sheet). This differs from the project rule in `CLAUDE.md` and is recorded here as found.[^handoff]

### 3.3 Step 2: late-reported claims

**What was tested.** Six ways of estimating the reported share were back-tested at four earlier "pretend" valuation dates. The error measure was the cost-weighted mean of `|log((A + 0.5) / (E + 0.5))|`, where A is the late claims that did arrive and E is the late claims predicted.[^ibnrreport]

| Method | Error |
|---|---|
| M2 chain ladder on counts | 0.0996 |
| M0 current ECDF | 0.1792 |
| M1 truncated product-limit[^kaplan] | 0.1809 |
| M5 recent years only | 0.1832 |
| M4 credibility-weighted | 0.1890 |
| M3 parametric | 0.1922 |

**Decision rule.** Take the simplest method within 1 standard error of the best; switch a single peril only if another method wins by more than 2 standard errors. This gave the chain ladder for most perils. Motor BI kept M0 in SAM 4 and MOTOR 2. Buildings subsidence used A1 (the ECDF averaged over every day of the policy) in C5, because the thin subsidence grid made the chain ladder over-project.[^w1method]

**C5 chain-ladder design.** Quarterly grid of 2021-24 loss quarters × report quarters (16 × 16), volume-weighted factors, tail factor 1, share = 1 / cumulative factor, floored at 0.05. A row's share is the day-weighted average over the quarters it covers. Fewer than 30 claims gives share 1.[^c5code]

C5 reported shares by policy year (source: `models/wendy_iteration_07/c5/ibnr_shares_by_year.csv`):

| Peril | 2023 share | 2024 share | 2024 gross-up (1 / share) |
|---|---|---|---|
| motor OD | 0.998999 | 0.967811 | 1.03326 |
| motor TPP | 0.998569 | 0.938606 | 1.06541 |
| motor BI | 0.940337 | 0.562274 | 1.77849 |
| motor theft | 0.999056 | 0.981399 | 1.01895 |
| motor glass and hail | 0.998222 | 0.973965 | 1.02673 |
| buildings storm | 0.998098 | 0.963892 | 1.03746 |
| buildings flood | 0.999020 | 0.965051 | 1.03621 |
| buildings EoW | 0.998556 | 0.954239 | 1.04796 |
| buildings subsidence (A1) | 0.984208 | 0.669752 | 1.49309 |
| buildings fire | 0.998881 | 0.981407 | 1.01895 |
| buildings AD | 0.998867 | 0.968536 | 1.03249 |
| contents theft | 0.999006 | 0.981901 | 1.01843 |
| contents EoW | 0.998488 | 0.949841 | 1.05281 |
| contents AD | 0.998543 | 0.965867 | 1.03534 |
| contents flood | 0.997360 | 0.963824 | 1.03753 |

Motor BI stands out: only about 56% of 2024 BI claims were reported by the valuation date.

### 3.4 Building block A: SAM 3

SAM 3 is a mix of five model types, blended per line. It enters the final file at line level with weight `1 − LW` (motor 0.1, buildings 0.3, contents 0.1). Source: `R/4_models_itersam03.R` and `models/sam_iteration_03/`.

**Global settings**

| Setting | Value |
|---|---|
| Claim cap | 99.5th percentile per line × peril (`CLAIM_CAP_Q = 0.995`) |
| Long-tail rule | a peril is long-tail if more than 15% of its 2023 claims are still open; this picks motor BI and buildings subsidence |
| Long-tail severity | uses only policy years before 2023 |
| 2024 dummy | long-tail frequency GLMs get a 2024 on/off term in the final fit, set to 0 when predicting |
| Trend clamp | ±10% a year (`log(1.10)`); it did not bind for any peril |
| IBNR factor | ECDF of 2021-22 report lags; per claim `1 / max(F(lag to valuation), 0.05)`, averaged by year |
| GLM bins | numeric fields with more than 10 values become 6 quantile bins; levels with under 0.5% of weight merge into the base level |
| Zero-row sampling (GLM) | up to 300,000 zero rows, reweighted |
| Few severity claims | fewer than 1,500 claims: severity GLM keeps only its first 2 fields |
| Seeds per peril / per line | 3 / 5 |
| Early stopping | LightGBM 100 rounds, XGBoost 50 rounds, on a 10% policy holdout |
| Maximum rounds | 3,000 |

**Claim-history features (a credibility idea inside SAM 3).** For a row starting in year Y, only claims reported before 1 January Y count. The policy relativity is[^sam3code]

```
hist_pol_rel = (n + k × f0) / ( f0 × (min(past exposure, 4) + k) ),   k = 2 years
```

where `n` is the policy's past claims (capped at 3) and `f0` is the line's average frequency. With no history the value is 1. With much history it moves toward the policy's own rate. This is a Bühlmann-type credibility estimate, with k = 2 years of exposure needed for half weight.[^buhlmann67]

**The five candidate models**

| Candidate | Frequency | Severity |
|---|---|---|
| `peril_glm` | quasi-Poisson GLM per peril, weight = exposure ÷ IBNR factor | Gamma GLM per peril on capped claims |
| `peril_lgb` | LightGBM Poisson per peril (3 seeds) | Gamma GLM |
| `peril_xgb` | XGBoost Poisson per peril (3 seeds), `min_child_weight` 10 | Gamma GLM |
| `lgb_tweedie` | one LightGBM Tweedie model per line, power 1.5 (5 seeds) | (inside the Tweedie) |
| `xgb_tweedie` | one XGBoost Tweedie model per line (5 seeds) | (inside the Tweedie) |

The tree models take only the *shape* from the trees; their per-peril total is reset to the GLM total, which carries the trend.

**LightGBM settings (not tuned):** learning rate 0.05, 15 leaves, `min_data_in_leaf` 500, feature fraction 0.7, bagging fraction 0.8 every round, `lambda_l2` 10, `cat_smooth` 50, `cat_l2` 10, `min_data_per_group` 500, `max_cat_threshold` 32.

**XGBoost tuned settings** (36 / 42 / 23 settings tried for motor / buildings / contents; source: `models/sam_iteration_03/xgb_tuning.csv`):

| Line | max depth | eta | min child weight (line Tweedie; per-peril uses 10) | subsample | colsample | lambda | Tweedie power |
|---|---|---|---|---|---|---|---|
| Motor | 3 | 0.05 | 500 | 0.7 | 0.6 | 5 | 1.7 |
| Buildings | 3 | 0.03 | 200 | 0.8 | 0.7 | 10 | 1.5 |
| Contents | 3 | 0.05 | 500 | 0.7 | 0.7 | 1 | 1.5 |

**Blend.** Ten forward steps of 0.1. Each step adds 0.1 to the candidate that most raises the mean calibrated D² over the 2022, 2023, and 2024 test years.[^caruana] Final weights (source: `models/sam_iteration_03/blend_weights.csv`):

| Line | peril_glm | peril_lgb | peril_xgb | lgb_tweedie | xgb_tweedie |
|---|---|---|---|---|---|
| Motor | 0.4 | 0 | 0.4 | 0 | 0.2 |
| Buildings | 0.2 | 0 | 0.7 | 0 | 0.1 |
| Contents | 0.3 | 0 | 0.4 | 0 | 0.3 |

The per-peril SAM 3 settings (caps, trends, loads, rounds) are listed in Section 3.10.

### 3.5 Building block B: WENDY 7 C5

C5 is a per-peril engine run from an Excel settings workbook. It is the main per-peril block for most perils. Source: `R/4_models_iterwendy07.R` and `inputs/assumptions_wendy07_final2.xlsx`.

**Global settings**

| Setting | Value |
|---|---|
| Bags | 5 (seeds 2026, then 2028-2031 for bags 2-5) |
| Maximum rounds / early stopping | 3,000 / 50 rounds |
| Policy holdout | 10% |
| subsample / colsample / reg_lambda | 0.8 / 0.8 / 5 |
| Frequency objective | XGBoost `count:poisson`, weight = exposure × reported share |
| Severity objective | XGBoost `reg:gamma`, or a Gamma GLM |
| Tweedie objective | XGBoost `reg:tweedie` at the peril's power `p` |
| Severity trend clamp | −2% to +10% a year |
| Frequency trend clamp | −5% to +3% a year |
| Single-claim limit | 2,000,000 |
| Open-claim recoveries | deducted at the closed-claim ratio |
| Fewest claims for a severity model | 200 (else the plain average is used) |
| GLM rare levels | levels with under 30 claims pooled into `"other"` |
| GLM log fields | `sum_insured`, `annual_mileage`, `distance_to_river_km` enter as `log(1 + x)` |
| Structural zeros | a peril is set to 0 for a cover type only if training shows no claims there: motor glass on TPO/TPFT, motor theft on TPO |
| History fields | `hist_policy_claims_prev`, `hist_customer_claims_other_lines_prev` |

**How one C5 prediction is made**[^c5code]

1. Cap each claim at the peril's cap quantile.
2. Fit the severity trend `g` on yearly capped averages and move each claim to 2025: `cost × (1 + g)^(2025 − loss year)`.
3. Recompute the cap on trended claims; load = `Σ trended / Σ capped`.
4. Frequency: `exposure × trees × balance × frequency trend factor`.
5. Severity: `trees (or GLM) × balance × load`.
6. Peril cost = frequency × severity. For a Tweedie peril: `exposure × Tweedie trees × balance × trend × load`.
7. Average over the 5 bags.

**Credibility in C5.** C5 has no explicit `Z` weight. Its protection for thin perils is (a) Gamma GLM severity with few fields, (b) pooling rare levels under 30 claims, and (c) the 200-claim floor for any severity model, which no peril reached in the final fit.

**What C5 changed against C4.** Motor OD moved from Tweedie to frequency × severity; motor TPP dropped `freezing_days` and `rainfall_mm`; buildings EoW, motor theft, and contents theft moved to Gamma GLM severity; fire `min_child_weight` 30 → 15; buildings flood dropped `days_quote_to_inception` and `start_month`. Inherited from C2-C4: voluntary excess in both frequency and severity, chain-ladder IBNR, 5 bags, BI trend switched off.[^w7log]

### 3.6 Building block C: MOTOR 2

MOTOR 2 covers motor only. It uses smooth GLMs. Source: `R/4_models_itermotor02.R`, `models/motor_iteration_02/`.

| Setting | Value |
|---|---|
| Frequency model | Poisson GLM, offset `log(exposure × reported share)` |
| Severity model | Gamma GLM on capped average claim |
| Spline | 4 degrees of freedom (knots at 25/50/75%), values clamped to 0.5% / 99.5% |
| Spline or factor | a numeric field with more than 10 values becomes a spline; otherwise a factor (levels need 0.2% of weight) |
| Trend | centered year term, capped at ±10% a year |
| Cap | 99.5th percentile per peril |
| Robust load | `LOAD_MULT` = 5 (tested; not chosen) |
| Few severity claims | under 3,000 claims: keep only the first 3 severity fields |
| Keep rule | mean gain > 0.0005 and better in at least 2 of 3 test years |
| Credibility grid | Z ∈ {0, 0.25, 0.5, 0.75, 1} |
| XGBoost frequency | tested; final weight 0 for every peril |

**Severity credibility.** For each peril, the severity GLM's shape is shrunk toward the peril average:

```
severity = exp( η_c + Z × (η − η_c) + trend )
```

where `η` is the GLM's log prediction and `η_c` is the claim-weighted average of `η`. Z = 1 keeps the full GLM shape; Z = 0 gives every policy the same average severity. Z was chosen as the value with the highest Gamma D² over the three test years.

| Peril | Z chosen | Gamma D² at Z = 0, 0.25, 0.5, 0.75, 1 |
|---|---|---|
| OD | 1 | 0.0000, 0.0189, 0.0326, 0.0410, 0.0439 |
| TPP | 0.5 | 0.0000, 0.0007, 0.0011, 0.0009, 0.0003 |
| BI | 0 | 0.0000, −0.0009, −0.0025, −0.0047, −0.0075 |
| Theft | 1 | 0.0000, 0.0147, 0.0251, 0.0312, 0.0329 |
| Glass and hail | 0.75 | 0.0000, 0.0042, 0.0070, 0.0084, 0.0082 |

**BI frequency borrows from TPP.** BI has few claims, and BI and TPP share drivers (both come from crashes involving a third party). So the BI rate is also built as `TPP rate × a short BI relativity GLM` on 8 fields: driver age, years licensed, named young driver, vehicle use, annual mileage, region, urban density, vehicle value group. The final BI frequency is a 50/50 average of this pooled rate and BI's own GLM.[^ohlsson] Poisson D² by test year: own 0.0479 / 0.0455 / 0.0421; pooled 0.0493 / 0.0462 / 0.0429; 50/50 mix 0.0496 / 0.0466 / 0.0431.

**MOTOR 2's own blend.** `0.7 × per-peril GLMs + 0.1 × line Tweedie XGBoost + 0.2 × iteration-1 GLM`, each of the last two rescaled to the GLM total.

**Use in the final file.** The final blend reads MOTOR 2's own-level file and rescales it to the running motor total, so the SAM 4 level file does not change the submission.

### 3.7 Building block D: the WENDY 9 ladder

The ladder is LightGBM Poisson frequency × LightGBM Gamma severity. It is fitted only for the 8 perils whose ladder weight is above 0. Source: `R/w89_core.R`, `R/6_ladder.R`, `inputs/assemble_combo.json`.

**Frequency base settings** (`FREQ_BASE` then `P2A`): Poisson, learning rate 0.05, `min_data_in_leaf` 100, `min_sum_hessian_in_leaf` 60, feature fraction 0.7, bagging 0.8 every round, `lambda_l2` 10, `max_bin` 127, `cat_smooth` 20, `min_data_per_group` 200, seed 5. Recipes then change the tree size:

| Recipe | Change |
|---|---|
| G4 | 4 leaves, depth 2 |
| G5 | 2 leaves, depth 1, learning rate 0.1 (each tree uses one field: an additive model) |
| G6 | 4 leaves, depth 2, `min_sum_hessian_in_leaf` 150 |
| G8 | 8 leaves, depth 3, `min_sum_hessian_in_leaf` 6 |

**Frequency label and weight:** label = claims ÷ (exposure × share), weight = exposure × share. The share comes from the ECDF of 2021-22 lags for that peril, averaged over 16 points of the policy period, floored at 0.03. Early stopping 100 rounds on the 10% policy holdout (at least 10 rounds), refit on all 2021-24 rows, balanced to the claim count. Fields: all except `previous_insurer` and `occupation`, and except the excluded list. There is no year field, so no frequency trend.

**Motor fields with categories** are replaced by the rank of a credibility-weighted rate (target encoding with shrinkage)[^micci]:

```
rate(level) = (claims in level + 20) / (exposure in level + 20 / base rate)
```

So every level starts with 20 "pretend" claims at the line's average rate.

**Severity base settings** (`SEV_BASE`): Gamma, learning rate 0.03, 7 leaves, `min_data_in_leaf` 200, feature fraction 0.8, bagging 0.8, `lambda_l2` 10, `max_bin` 63, `cat_smooth` 50, `min_data_per_group` 100, seed 6; early stopping 100 rounds (at least 5), refit on all claims. Claims capped at the 99.5th percentile ("nearest" rule), trended by `exp(g × (2025 − loss year))`, balanced by `mean(actual) / mean(predicted)`, times the load. Recipes: **SA** fitted trend clamped to [0%, 10%], fields without `previous_insurer` / `occupation`; **S4** same trend rule, all fields; **S6** fixed 5% trend, all fields.

### 3.8 Building block E: WENDY 8 claim-history credibility

After the rating factors, a policy that has had more claims than expected is, on average, a worse risk. WENDY 8 corrects for this with an exact Poisson-Gamma credibility formula.[^bg][^jewell] Source: `R/w89_core.R:111-166`, `R/9_final_blend.R`.

- **Prior frequency λ̂.** A LightGBM Poisson claim-count model with no history fields. Settings: learning rate 0.05, 31 leaves, `min_data_in_leaf` 300, feature fraction 0.7, bagging 0.8, `lambda_l2` 10, seed 11. It is fitted out-of-fold over 4 policy folds, so a policy's own claims never feed its own expectation. Rounds by early stopping (100) on fold 0: motor 389, buildings 279, contents 227.
- **N** = the policy's own earlier claims with cost > 0, with loss date before the row starts **and** report date before `min(row start, 1 January 2025)`.
- **E** = the expected number of those claims: `λ̂ ÷ max(share at 1 Jan 2025, 0.05) × share reported by the cut-off`, summed over the policy's earlier rows. The share uses the line's report-lag ECDF averaged over 16 points of each earlier row.
- **Multiplier**

```
M = (A + N) / (A + E),   A = 8 (motor), 5 (buildings), 5 (contents)
```

*Example.* Motor, A = 8. A policy with E = 0.5 expected past claims and N = 2 actual past claims gets M = (8 + 2) / (8 + 0.5) = 1.18. A policy with N = 0 gets M = 8 / 8.5 = 0.94.

The weight given to own history is `Z = E / (A + E)`. With E = 0.5 and A = 8, Z = 0.06. A = 8 matches a spread (coefficient of variation) in true policy risk of about `1/√8` = 35%.

After multiplying, each line is rescaled so its total does not change. The history only moves cost between policies.

Mean N and E across all rows: motor 0.1918 / 0.1899, buildings 0.0593 / 0.0593, contents 0.0539 / 0.054 (`run/logs/history.log`).

### 3.9 The final week 1 blend

For each 2025 row (source: `R/9_final_blend.R:3-6, 46-53`, weights in `inputs/assemble_weights.json`):

```
1. Peril blend:   pb = Σ_p [ w_p × ladder_p + (1 − w_p) × C5_p ]
2. Line blend:    b  = LW × pb + (1 − LW) × SAM3
3. Motor only:    b  = 0.5 × b + 0.5 × MOTOR2 × Σb / ΣMOTOR2
4. Credibility:   q  = b × (A + N) / (A + E),  then  q = q × Σb / Σq
```

Averaging two partly independent predictions cannot do worse, on average, than the average of their two scores, because the Tweedie deviance is convex.[^bates][^timmermann]

| Line | LW | A |
|---|---|---|
| Motor | 0.9 | 8 |
| Buildings | 0.7 | 5 |
| Contents | 0.9 | 5 |

The ladder weight `w_p` and the resulting approximate share of each block per peril (before step 4, and treating MOTOR 2's rescale as a plain weight):

| Line | Peril | w_p | C5 share | Ladder share | SAM 3 (line level) | MOTOR 2 |
|---|---|---|---|---|---|---|
| Motor | OD | 0 | 0.45 | 0 | 0.05 | 0.5 |
| Motor | TPP | 1 | 0 | 0.45 | 0.05 | 0.5 |
| Motor | BI | 0 | 0.45 | 0 | 0.05 | 0.5 |
| Motor | theft | 0 | 0.45 | 0 | 0.05 | 0.5 |
| Motor | glass and hail | 1 | 0 | 0.45 | 0.05 | 0.5 |
| Buildings | storm | 1 | 0 | 0.70 | 0.30 | – |
| Buildings | flood | 0 | 0.70 | 0 | 0.30 | – |
| Buildings | EoW | 0 | 0.70 | 0 | 0.30 | – |
| Buildings | subsidence | 0.5 | 0.35 | 0.35 | 0.30 | – |
| Buildings | fire | 0.25 | 0.525 | 0.175 | 0.30 | – |
| Buildings | AD | 0.25 | 0.525 | 0.175 | 0.30 | – |
| Contents | theft | 0 | 0.90 | 0 | 0.10 | – |
| Contents | EoW | 0.75 | 0.225 | 0.675 | 0.10 | – |
| Contents | AD | 0 | 0.90 | 0 | 0.10 | – |
| Contents | flood | 0.75 | 0.225 | 0.675 | 0.10 | – |

SAM 3 and MOTOR 2 enter as line totals per row, not peril by peril, so their share is the same for every peril of the line.

### 3.10 Week 1, peril by peril

Each card lists the frequency and severity settings of every block that feeds the peril. Sources: SAM 3 `models/sam_iteration_03/{claim_caps,trend_by_peril,tree_rounds}.csv`; C5 `models/wendy_iteration_07/c5/diagnostics_final.csv` and the workbook `Model_Spec` and `Method_Mix` sheets; MOTOR 2 `models/motor_iteration_02/{final_config,fit_info}.csv`; ladder `models/wendy_iteration_09/ladder_details.csv`. "Rounds" are the trees in the first bag. Trends are yearly. C5 feature lists are in Appendix A. A C5 "d / eta / mcw" entry means depth / learning rate / minimum child weight.

#### Motor own damage (48,258 claims, 2021-24)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | GLM + XGBoost (1,073 rounds) + LightGBM (514, weight 0); trend −5.43% | Gamma GLM; cap 13,005.32; trend +8.15%; load 1.01043 |
| C5 (share 0.45) | XGBoost Poisson, 4 / 0.05 / 50, 715 rounds; trend +0.27% (factor about 1.0068) | XGBoost Gamma, 3 / 0.05 / 100, 145 rounds; cap 19,895.12 (q 0.999); trend +3.69%; load 1.00251 |
| MOTOR 2 (share 0.5) | Poisson GLM, 29 fields; trend switched off (fitted −1.40%) | Gamma GLM, 9 fields; Z = 1; trend switched off (fitted +8.40%); load 1.01043 |
| Ladder | not used (w = 0) | – |

#### Motor third-party property (32,963 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | XGBoost 580 rounds; trend −5.31% | Gamma GLM; cap 19,749.54; trend +7.79%; load 1.00613 |
| C5 | not used (w = 1); C5 setting 4 / 0.05 / 50 | – |
| Ladder (share 0.45) | LightGBM G4, 1,045 rounds, motor rate encoding | LightGBM Gamma S6, 41 rounds; cap 19,734.65; trend fixed +5%; load 1.00613 |
| MOTOR 2 (share 0.5) | Poisson GLM, 30 fields; trend −3.73% | Gamma GLM, 5 fields; Z = 0.5; trend +7.68%; load 1.00613 |

#### Motor bodily injury (7,512 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | long-tail: 2024 dummy 1.00835; XGBoost 393 rounds; trend −6.16% | Gamma GLM on 2021-22 only (4,285 claims); cap 187,516.02; trend +4.47%; load 1.03594 |
| C5 (share 0.45) | **Tweedie** XGBoost, power 1.6, 3 / 0.05 / 100, 111 rounds; balance 1.05285 | inside Tweedie: cap 187,505.67 (q 0.995) on 2021-23; load 1.04780; **no trend** (frequency and severity) |
| MOTOR 2 (share 0.5) | 50/50 of own GLM (23 fields, trend +4.88%) and TPP × BI-relativity GLM | Z = 0 (one average for all); all years; trend −7.66%; load 1.11472 |
| Ladder | not used (w = 0) | – |

BI trend is off in C5 because the fitted decline may come from immature case estimates (IBNER), which cannot be separated from a real fall with one valuation date.[^w1method]

#### Motor theft (6,119 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | XGBoost 693 rounds; trend −1.52% | Gamma GLM; cap 38,459.51; trend +6.41%; load 1.00651 |
| C5 (share 0.45) | XGBoost Poisson, 3 / 0.05 / 50, 383 rounds; no trend; structural zero on TPO | **Gamma GLM**, 9 fields; cap 55,461.56 (q 0.999); trend +3.48%; load 1.00169 |
| MOTOR 2 (share 0.5) | Poisson GLM, 15 fields; trend −0.14% | Gamma GLM, 4 fields; Z = 1; trend +6.16%; load 1.00651 |
| Ladder | not used | – |

#### Motor glass and hail (15,643 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | XGBoost 472 rounds; trend −1.94% | Gamma GLM; cap 5,873.07; trend +7.97%; load 1.00606 |
| C5 | not used (w = 1) | – |
| Ladder (share 0.45) | LightGBM G8, 530 rounds, motor rate encoding | LightGBM Gamma SA, 47 rounds; cap 5,876.55; trend +7.57%; load 1.00603 |
| MOTOR 2 (share 0.5) | Poisson GLM, 19 fields; trend −0.79% | Gamma GLM, 4 fields; Z = 0.75; trend +7.95%; load 1.00606 |

Structural zero: no glass claims on TPO / TPFT covers, so those rows get 0 in C5.

#### Buildings storm (7,762 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 (line share 0.3) | XGBoost 1,210 rounds; trend +0.69% | Gamma GLM; cap 19,764.17; trend +6.73%; load 1.00911 |
| C5 | not used (w = 1); C5 setting 3 / 0.05 / 50 | – |
| Ladder (share 0.70) | LightGBM G5 (one field per tree), 1,168 rounds | LightGBM Gamma SA, 101 rounds; cap 19,745.37; trend +7.93%; load 1.00911 |

#### Buildings flood (2,219 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | GLM on 8 flood fields + XGBoost 482 rounds; trend −2.52% | Gamma GLM; cap 208,045.47; trend +4.75%; load 1.00826 |
| C5 (share 0.70) | XGBoost Poisson, 3 / 0.05 / 30, 300 rounds; no trend | Gamma GLM, 11 fields; cap 241,227.87 (q 0.995); trend +6.86%; load 1.00693 |
| Ladder | not used (w = 0) | – |

#### Buildings escape of water (10,065 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | XGBoost 713 rounds; trend +0.05% | Gamma GLM; cap 34,856.35; trend +6.93%; load 1.00733 |
| C5 (share 0.70) | XGBoost Poisson, 4 / 0.05 / 50, 449 rounds | **Gamma GLM**, 10 fields; cap 57,351.84 (q 0.999); trend +8.52%; load 1.00148 |
| Ladder | not used | – |

#### Buildings subsidence (1,288 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | long-tail: 2024 dummy 1.17862; GLM on 6 fields + XGBoost 422 rounds; trend +0.83% | Gamma GLM on 2021-22 (617 claims, so only 2 fields); cap 138,263.22; trend +4.77%; load 1.00074 |
| C5 (share 0.35) | XGBoost Poisson, 3 / 0.05 / 30, 62 rounds; IBNR A1 | Gamma GLM, 12 fields, on 2021-23 (997 claims); cap 129,204.62 (q 0.995); trend +2.28%; load 1.00518 |
| Ladder (share 0.35) | LightGBM G4, 154 rounds | LightGBM Gamma S4, 111 rounds; cap 144,192.44; trend +5.97%; load 1.00369 |

#### Buildings fire (1,107 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | GLM on 10 fields + XGBoost 380 rounds; trend +5.44% | Gamma GLM, 2 fields; cap 369,276.9; trend −4.76%; load 1.00781 |
| C5 (share 0.525) | XGBoost Poisson, 3 / 0.05 / **15**, 122 rounds | Gamma GLM, 9 fields; cap 293,015.57 (q 0.99); trend −2% (clamped); load 1.01925 |
| Ladder (share 0.175) | LightGBM G5, 145 rounds | LightGBM Gamma S4, 83 rounds; cap 369,150; trend 0% (floor); load 1.00778 |

#### Buildings accidental damage (3,825 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | XGBoost 530 rounds; trend −0.02% | Gamma GLM; cap 6,560.72; trend +1.60%; load 1.00569 |
| C5 (share 0.525) | XGBoost Poisson, 3 / 0.05 / 30, 305 rounds | XGBoost Gamma, 3 / 0.05 / 100, 15 rounds; cap 9,514.43 (q 0.999); trend +2.20%; load 1.00096 |
| Ladder (share 0.175) | LightGBM G5, 781 rounds | LightGBM Gamma S6, 14 rounds; cap 6,562.64; trend +5%; load 1.00566 |

#### Contents theft (7,626 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 (line share 0.1) | XGBoost 291 rounds; trend +1.11% | Gamma GLM; cap 23,478.01; trend +3.06%; load 1.00783 |
| C5 (share 0.90) | XGBoost Poisson, 4 / 0.05 / 50, 207 rounds | **Gamma GLM**, 9 fields; cap 32,660.96 (q 0.999); trend +4.29%; load 1.00307 |
| Ladder | not used | – |

#### Contents escape of water (5,366 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | XGBoost 232 rounds; trend −0.08% | Gamma GLM; cap 16,952.69; trend +1.60%; load 1.00763 |
| C5 (share 0.225) | **Tweedie** XGBoost, power 1.5, 3 / 0.05 / 50, 197 rounds; balance 1.05264 | inside Tweedie: cap 23,973.19; trend +2.56%; load 1.00245 |
| Ladder (share 0.675) | LightGBM G6, 412 rounds | LightGBM Gamma SA, 131 rounds; cap 16,931.35; trend +2.71%; load 1.00763 |

#### Contents accidental damage (9,063 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | XGBoost 436 rounds; trend −0.90% | Gamma GLM; cap 4,821.24; trend +2.54%; load 1.00402 |
| C5 (share 0.90) | XGBoost Poisson, 3 / 0.05 / 50, 341 rounds | XGBoost Gamma, 3 / 0.05 / 100, 50 rounds; cap 6,196.54; trend +2.75%; load 1.00169 |
| Ladder | not used | – |

#### Contents flood (1,615 claims)

| Block | Frequency | Severity |
|---|---|---|
| SAM 3 | GLM on 8 flood fields + XGBoost 403 rounds; trend −2.85% | Gamma GLM; cap 60,320.20; trend +5.74%; load 1.00915 |
| C5 (share 0.225) | XGBoost Poisson, 3 / 0.05 / 30, 296 rounds | Gamma GLM, 11 fields; cap 67,334.54 (q 0.995); trend +5.64%; load 1.00886 |
| Ladder (share 0.675) | LightGBM G5, 263 rounds | LightGBM Gamma S4, 206 rounds; cap 60,545.54; trend +5.46%; load 1.00898 |

### 3.11 How well week 1 scores

The local test fits on 2021-22 to predict 2023, and on 2021-23 to predict 2024, and scores on reported claims.[^w1method] The noise threshold is about 0.0011 (two standard errors from 200 paired policy bootstrap draws).[^efron]

| Stage | D² 2023 | D² 2024 |
|---|---|---|
| C5 alone | 0.10586 | 0.09924 |
| Ladder alone | 0.10120 | 0.09864 |
| C5 × ladder per-peril blend | 0.10604 | 0.10054 |
| + SAM 3 line blend | 0.10621 | 0.10071 |
| + credibility (WENDY 8) | 0.10682 | 0.10208 |

Kaggle: public 0.12965, private 0.13923. The R rebuild matches the submitted file with totals 0.9986 (motor), 0.9999 (buildings), 0.9999 (contents), and Spearman rank correlation 0.9999 or higher (`output/final_week1/final_check.csv`). The only gap is C5, whose boosted trees round differently on Windows than on the Apple computer that made the original.[^w1readme]

---

## 4. Week 2: the emerging-market model

This section describes the final week 2 model, file `submission_20261030_0905_week2_motorlevel_l_full.csv` (submission #31), public score 0.16840.[^w2method]

### 4.1 The problem in week 2

The emerging market has only 2023 and 2024 data, about 9,100 claims over 15 perils. Some perils have 50 to 90 claims. That is too little to build a model from scratch. So the model works in four layers:[^w2method]

1. **Shape** (who is riskier than whom) from the mature market.
2. **Level** (how expensive the emerging market is) from the emerging data, weighted by credibility.
3. **2025 projection**: one year of trend, plus an allowance for new customers.
4. **Motor level review**: two actuarial factors on motor only, for bodily-injury claim size and for new customers (Section 4.8). Buildings and contents are not changed.

For each row and peril (source: `week2/docs/final_model_method_week2.md` section 1; `week2/R/08_loadings_2025.R:59-61`; `week2/R/29_motor_level.R`):[^w2motor]

```
cost = exposure
     × f_dev(x) × L_f × adj_f(x)                      frequency
     × severity (core, or 50/50 blend on 4 perils)
     × (1 + g_f) × (1 + g_s)                          one year of trend
     × NB                                             new-business load (new customers only)
     × M                                              motor level factor (motor only; 1 for buildings and contents)

core severity = s_dev(x) × L_s × adj_s(x) × load_dev
```

| Symbol | Meaning |
|---|---|
| `f_dev(x)`, `s_dev(x)` | mature-market frequency and capped severity for this profile |
| `L_f`, `L_s` | emerging level: emerging ÷ mature for the same profile |
| `adj_f(x)`, `adj_s(x)` | emerging correction multipliers for a few fields |
| `load_dev` | mature-market large-claim load |
| `g_f`, `g_s` | yearly frequency and severity trend |
| `M` | motor level factor: 1.1159 on bodily injury, × 1.0611 on new-business rows (Section 4.8) |

The model has two parts that differ only in the mature-market baseline:

| Line | Component | Baseline |
|---|---|---|
| Motor | `x20_tblend` | week 1 C5 engine on shared fields (Section 4.4.1) |
| Buildings, contents | `rt_var_b8_floor_corrected` | the same engine re-tuned for the fields the emerging market has (Section 4.4.2) |

### 4.2 Data and fields

| Item | Value |
|---|---|
| Mature (developed) training years | 2021-2024 |
| Emerging training years | 2023-2024 |
| Valuation date | 31 December 2024, both markets |
| Cleaning | one function for both markets: exposure from dates; sum insured ÷ 1,000 fix; construction codes mapped to brick / stone / timber / non-standard; occupation spellings mapped to 20 jobs plus a `self_employed` flag; claims matching no policy row left out |
| Claim basis | same as week 1 C5: recoveries deducted, open-claim recoveries at the closed ratio, single claim limited to 2,000,000, positive claims only |
| Fields dropped because the emerging data lacks them | `region`, `credit_band`, `annual_mileage`, `telematics_opt_in`, `telematics_score` |
| Fields never used | `compulsory_excess`, `written_premium`, `customer_service_contacts`, `renewal_decision`, `noise_probe`, marketing fields |
| Renamed to shared bands | `driver_age` → `driver_age_band`, `policyholder_age` → `policyholder_age_band` |
| Emerging-only fields | `gender` (approved by Wendy, decision D027) and `self_employed`; used only in the emerging adjustment |
| Seed | 2026 |

Source: `week2/docs/final_model_method_week2.md` section 3.

### 4.3 Late claims and inflation

**Late claims.** Chain ladder on mature-market claim counts, per peril, grid 2021Q1 to 2024Q4, volume-weighted factors, tail 1, share floored at 0.05. Subsidence uses the ECDF of 2021-22 lags averaged over the days of each quarter. Emerging report lags were compared with mature lags for the same loss years and found to match, so the mature pattern is applied to emerging rows.[^w2ibnr]

**Trend.** For each peril:[^w2ibnr]

```
Z_trend = emerging claims / (emerging claims + 2,000)
frequency trend = clamp( (1 − Z) × mature 2021-24 trend + Z × emerging 2023→24 change,  −5%, +3% )
severity trend  = clamp( (1 − Z) × mature 2021-24 trend + Z × emerging 2023→24 change,  −2%, +10% )
```

The mature trend is a log-linear fit; severity uses claims capped at the 99.5th percentile; the 2024 year is left out of the mature severity trend for BI and subsidence. The 2025 projection (`TREND_MODE=blend_freq`) then applies three rules:

- motor frequency trend is never below 0 (`TREND_FLOOR_FREQ=motor`);
- motor BI uses 0 for both frequency and severity trend (week 1 rule); in the final file the BI severity trend is replaced by +4.5% a year (Section 4.8);
- every other peril uses its blended trend.

Both components use the same trend table for the 2025 step. Values (source: `week2/output/04_ibnr_trend/trend_table.csv`; `week2/output/08_loadings/x20_tblend/loadings.csv`):

| Peril | Emerging claims | Z_trend | Mature freq trend | Emerging freq change | Freq trend used | Mature sev trend | Emerging sev change | Sev trend used |
|---|---|---|---|---|---|---|---|---|
| motor OD | 2,672 | 0.572 | −2.76% | −8.92% | **0** (blend −5.00%) | +3.50% | +3.93% | +3.75% |
| motor TPP | 2,193 | 0.523 | −2.50% | −4.20% | **0** (blend −3.39%) | +7.57% | +1.04% | +4.16% |
| motor BI | 449 | 0.183 | −2.43% | +7.81% | **0** | −8.80% | +4.94% | **0** |
| motor theft | 389 | 0.163 | −0.33% | −3.99% | **0** (blend −0.93%) | +3.49% | +18.95% | +6.01% |
| motor glass and hail | 1,345 | 0.402 | +2.98% | +19.04% | +3.00% (clamped) | +7.85% | +11.24% | +9.21% |
| buildings storm | 464 | 0.188 | +2.09% | +17.75% | +3.00% (clamped) | +8.23% | +11.10% | +8.77% |
| buildings flood | 80 | 0.038 | −2.74% | −11.94% | −3.09% | +6.86% | +14.55% | +7.16% |
| buildings EoW | 268 | 0.118 | +0.48% | +2.89% | +0.76% | +8.38% | −0.54% | +7.32% |
| buildings subsidence | 52 | 0.025 | +13.39% | −13.61% | +3.00% (clamped) | +2.38% | −33.14% | +1.48% |
| buildings fire | 70 | 0.034 | +6.81% | −58.99% | +3.00% (clamped) | −2.56% | −18.54% | −2.00% (clamped) |
| buildings AD | 122 | 0.057 | +2.49% | +18.12% | +3.00% (clamped) | +2.25% | +11.04% | +2.76% |
| contents theft | 406 | 0.169 | +2.65% | +11.32% | +3.00% (clamped) | +4.10% | +4.20% | +4.12% |
| contents EoW | 171 | 0.079 | +1.91% | −1.97% | +1.61% | +2.72% | −11.21% | +1.62% |
| contents AD | 335 | 0.143 | +1.43% | −0.69% | +1.12% | +2.77% | −5.80% | +1.54% |
| contents flood | 86 | 0.041 | −2.69% | −33.00% | −3.94% | +5.64% | +20.14% | +6.23% |

One detail differs between the components. When the step 7 GLMs are fitted, 2023 claims are moved to 2024 terms with a frequency trend. The motor fit (`x20_tblend_core`) uses the blended trend above. The buildings and contents fit (`rt_var_b8_chosen`) uses the step 4 "chosen" rule, which is a frequency trend of 0 for every home peril (`week2/week1_retune/run/run_candidate_variants.ps1`; `week2/R/04_ibnr_trend_week2.R:127`). Both use the blended trend for the 2025 projection.

### 4.4 The mature-market baselines

Both baselines are the week 1 C5 engine (Section 3.5), refitted on 2021-24 mature data using only shared fields, then used to score every emerging row. They give `f_dev(x)`, `s_dev(x)`, the cap, and the load. Every frequency model is an XGBoost Poisson model on ultimate counts. Severity is an XGBoost Gamma model, or a Gamma GLM where claims are too few for trees.

Global settings for both: 5 bags; maximum 3,000 rounds; early stopping 50; 10% policy holdout; subsample 0.8; colsample 0.8; `reg_lambda` 5; GLM rare-level floor 30 claims; history fields on; chain-ladder IBNR; frequency × severity for every peril (no Tweedie). Source: `week2/docs/final_model_method_week2.md` section 5.

#### 4.4.1 Motor: the Option B baseline

Shared fields only, with the C5 settings per peril (cards in Section 4.9). Mature-market test score of this shared-field baseline: 0.0976 (against 0.1026 for C5 on all fields).[^w2final5]

#### 4.4.2 Buildings and contents: the re-tuned baseline `b8_combo_f`

The emerging market has no `region` and no `credit_band`. The re-tune puts back location and payment information from fields the emerging market does have, and makes the trees smaller (source: `week2/week1_retune/R/r05_retune_baseline.R:36, 112, 130-143, 176-178`):

| Switch | Change | Reason recorded |
|---|---|---|
| `HP_DEPTH_ADD=-1` | frequency and severity tree depth reduced by 1 on every peril, never below 2 | without region, deeper trees overfit |
| `LOC_ALL=1` | `urban_density`, `flood_zone`, `wx_avg_hail_days`, `wx_avg_rainfall_mm`, `wx_avg_freezing_days`, `wx_avg_wind_exposure_index` offered on every peril | location in place of `region` |
| `PROXY=credit` | `disc_flag` (`discount_applied > 0`) and `missed_any` (`missed_payments_12m > 0`) | payment behavior in place of `credit_band` |
| `BAGS=5` | final fit on 2021-24 | |

Mature-market test score (mean of the 2023 and 2024 folds, all lines): 0.1031, against 0.1027 for the reference. It is used for buildings and contents only. For motor, a re-tuned shape scored 0.00267 lower on the public board than `x20_tblend` (submission #11, `week2/docs/week2_workflow.md`), so motor keeps the Option B baseline.

`disc_flag` is built from `discount_applied`, a field that week 1 left out as a price field rather than a risk field. It is recorded here as found.

### 4.5 The emerging adjustment

This is the core of week 2. Each peril gets its own penalized GLM, fitted by IRLS, with the baseline as offset.[^w2adj] The environment had no R package for ridge regression, so the penalty is written by hand (`pglm`, `week2/R/07_emerging_adjust.R:186-205`). The same settings are used for both components (runs `x20_tblend_core` and `rt_var_b8_chosen_core`).

| Name | Value | Meaning |
|---|---|---|
| `K_FREQ_LEVEL` | 200 | frequency level credibility, Z = n / (n + 200) |
| `K_SEV_LEVEL` | 400 | severity level credibility, Z = n / (n + 400) |
| × 3 for 5 perils | 1,200 | buildings fire, flood, subsidence; motor BI; contents flood |
| `LAMBDA` | 30 | ridge penalty per frequency factor level, in expected claims |
| `LAMBDA_SEV` | 30 | same for severity, in claims |
| `MAX_FACTORS` | 4 | most frequency fields per peril |
| Severity fields | up to 2, only for perils with at least 1,000 emerging claims (`SEV_FACTOR_MIN`) |
| Field test | fit on 2023; keep a field only if the 2024 deviance falls by more than 1 |
| Bands | numeric fields cut into 5 bands at emerging training quintiles (`_b` names) |
| History field | past claims capped at 2, missing = `"none"` |
| Fit weights | 1 |

**Frequency level.** The Poisson GLM has offset `log(f_dev × exposure × share × (1 + g_f)^(year − base year))`. Its intercept is the emerging level. The intercept is pulled toward the line's pooled level `b0 = log(Σ claims / Σ expected)` over all perils of the line, with a penalty of K "pretend" claims. So the peril keeps about Z = n / (n + 200) of its own level.

*Example.* Buildings subsidence, 52 claims: own level 1.049 (2023-24, re-tuned baseline), Z = 52 / 252 = 0.206. The fitted level is 1.060, between its own value and the buildings pool.

**Frequency fields.** Candidates are the fields that showed an emerging A/E slope in step 6, plus `new_business`, `gender`, and `self_employed` (lists in `week2/docs/optionB/final_model_week2.md` section 3.4). Fields are added one at a time (greedy forward selection), at most 4, and only while the 2024 test improves. Each field level is a dummy with ridge penalty 30.

**Severity level.** Claims are capped at `developed cap × emerging level`. Because the level depends on the cap, this is iterated 5 times. The Gamma GLM has offset `log(capped s_dev)`. The intercept is pulled toward the line's severity pool, which is the *claim-weighted* average of the perils' log levels (so one heavy peril such as fire does not set the pool for all others; decision D025), with penalty K = 400 or 1,200.

**Why K = 400 for severity and not 200.** One claim's size varies much more than whether a claim happens, so more claims are needed before an average size can be believed.

**Final fit.** 2023-24 data, base year 2024. The 2025 trend is added in step 8.

### 4.6 The severity blend

A separate run (`fin_sevem`, `SEV_MODE=em_select`) fits a Gamma GLM on emerging claims alone, with no mature offset, an unpenalized intercept, ridge 30 on field levels, and up to 3 fields chosen by the same 2023 → 2024 test. Candidates: the line's frequency candidates plus, for motor, vehicle value band, driver age band, cover type, vehicle age band, voluntary excess; for buildings, sum insured band, property type, construction type; for contents, sum insured band, high-value items, tenure. Because it has no mature offset, the same run serves both components.

**Which perils get the blend.** A 5-fold cross-validation by policy on all 2023-24 emerging claims compared the core severity with a 50/50 blend. The rule: blend gain with z above 1.5 that still holds after relevelling (source: `week2/output/07_adjust/sev_cv_x14_cv.csv`).

| Peril | z blend | z relevelled | Emerging-only fields |
|---|---|---|---|
| motor OD | 2.86 | 2.82 | vehicle value band, vehicle age band, voluntary excess |
| motor glass and hail | 2.55 | 2.51 | vehicle value band, vehicle age band, years-licensed band |
| motor BI | 1.68 | 1.92 | occupation, years-licensed band, gender |
| contents EoW | 1.84 | 1.79 | sum insured band, gender |

For these four perils (`week2/R/14_blend_severity.R:140-142`):

```
severity = core^0.5 × emerging-only^0.5
then severity × (Σ core cost / Σ blended cost) for the peril
```

The rescale means the blend changes who pays, not the peril's total.

### 4.7 Moving to 2025

**Trend.** One year: `(1 + g_f) × (1 + g_s)`, from the 2024 base year (table in Section 4.3).

**New-business load.** 77% of 2025 policies are new customers. The mature baseline already contains a new-business multiplier, so only the leftover emerging difference is loaded:[^w2nb]

```
residual A/E = (NB actual ÷ NB predicted) ÷ (line actual ÷ line predicted)
Z_NB = NB claims / (NB claims + 300)
NB load = 1 + Z_NB × (residual A/E − 1)
```

It is applied to new-business rows only, and not to a peril where step 7 already kept `new_business` as a field (motor glass and hail, contents AD), to avoid counting it twice. Values (source: `week2/output/08_loadings/x20_tblend/loadings.csv`; `week2/week1_retune/output/var_b8_floor_corrected/08_loadings/rt_var_b8_floor_corrected/loadings.csv`):

| Line | Component | NB claims 2023-24 | Residual A/E | Z_NB | NB load |
|---|---|---|---|---|---|
| Motor | `x20_tblend` | 697 | 1.23660 | 0.69910 | 1.16541 |
| Buildings | `rt_var_b8_floor_corrected` | 77 | 0.83683 | 0.20424 | 0.96667 |
| Contents | `rt_var_b8_floor_corrected` | 102 | 1.19462 | 0.25373 | 1.04938 |

**IBNR and large claims.** Already inside the frequency (ultimate basis) and the severity load; nothing is added.

**Line ensemble.** Motor rows come from `x20_tblend`; buildings and contents rows come from `rt_var_b8_floor_corrected`. This file, before the motor level review, scored 0.16690 on the public board (submission #12).

### 4.8 The final step: a motor level review

**Why this step.** Up to this point the model is the line ensemble, submission #12 (public 0.16690). We first tried to set the 2025 level from public leaderboard scores (Section 4.8A). That scored higher, but in real pricing there is no leaderboard: next year's claims are not known when the price is set. We judged probing to be cheating, even with guardrails, and set it aside (decision D035). We went back to #12 and asked: *with no leaderboard, what would an actuary check before signing off a price for a new market?* We looked at motor, the largest line (42% of the exposure).[^w2motor]

**What was checked, and what was kept.**

| Check | What the data says | Decision |
|---|---|---|
| Spread: is the week 2 ranking too flat or too steep? | Raising predictions to a power k (total kept) fits best at k ≈ 1.0 on emerging 2024 and on the mature years | ranking kept exactly |
| Late reporting | emerging and mature reporting delays match | late-claim counts unchanged |
| Bodily-injury (BI) claims inflation | step 4 chose 0. The mature market's −8.8% came from 2023-24 claims that were not yet settled. Fully settled mature years 2021-23: average BI claim 21.4k, 22.2k, 23.3k, about +4% a year; emerging 2023-24 +4.9% | +4.5% a year |
| BI late-claim growth | BI claims reported late are bigger (mature: 19.6k if reported within 30 days, 28.0k after 2 years) | growth to the emerging claims' ages |
| BI large-claim allowance | emerging large-claim load 1.024, mature 1.048: a thin book has not yet seen its large claims | use the mature load |
| New customers | 77% of 2025 motor exposure is new business (6-9% in 2023-24). The emerging new-business A/E is 1.237 but only 1.165 was applied (Z = 0.70) | apply the full 1.237 |

**The two factors.**

```
BI severity  M_BI = 1.045  × 1.0267 × 1.0168 × 1.0230 = 1.1159   (BI rows only)
                    trend    to base   late     large
                    to 2025  year      growth   claims
New business M_NB = 1.23660 ÷ 1.16541 = 1.0611                     (motor new-business rows only)
```

- *Trend to base year.* 266 of the 449 emerging BI claims are from 2023 and were brought to 2024 terms with 0 trend, so they get 4.5% × 266 / 449: 1 + 0.045 × 0.592 = 1.0267.
- *Late growth.* In the mature years, all BI claims ÷ claims reported by a given age is 1.007 at the age of the 2023 claims and 1.031 at the age of the 2024 claims; weighted by claims (266 and 183): (266 × 1.007 + 183 × 1.031) ÷ 449 = 1.0168.
- *Large claims.* Mature load ÷ emerging load = 1.04780 ÷ 1.02428 = 1.0230. The mature market's figure is the complement of credibility for a book too young to show its own.
- *New business.* Not applied where new business is already a field of the model (motor glass and hail), to avoid counting it twice.

Each factor follows standard practice: severity trend measured on fully developed loss years only[^werner]; development of claim sizes for late-reported claims from a benchmark (mature-market) pattern, as in Bornhuetter-Ferguson and Cape Cod methods for immature books[^bf][^stanard][^friedland]; a benchmark large-loss (increased-limits) load used as the complement of credibility where a thin book has not yet shown its large claims[^miccolis][^boor]; and the full new-business A/E, rather than its partially credible value, where three-quarters of the projected book is new business.[^bs][^bg]

**Result.** Motor 2025 cost per policy-year 625.1 → 684.0 (× 1.094); buildings and contents unchanged; whole file × 1.064.

**How it was judged.** Every factor was set from the training data before any submission. The 2024 fold cannot judge it: its actual claims are counted at the snapshot (not developed to ultimate) and only 9% of 2024 policies are new business. On that fold the motor A/E is already 1.012, and the factors lower motor D² a little (0.0446 → 0.0439). Three files were submitted only to check that each factor pointed the right way:

| # | Factors | Motor vs #12 | Public |
|---|---|---|---|
| 12 | none (line ensemble) | 1.000 | 0.16690 |
| 33 | BI only | 1.043 | 0.16793 |
| 32 | new business only | 1.049 | 0.16769 |
| **31** | **both (final)** | **1.094** | **0.16840** |

All three beat #12. The final is the full version, which was built as the actuarial best estimate.

**Final file.** The perils are added up per row, with the same checks as before (every sample row present, no duplicates, no missing values, all ≥ 0). `week2/R/30_final_from_components.R` rebuilds #12 and the final file from the two saved components in seconds, byte for byte (final MD5 `90120c605cee98bb3545e0b7b4b9a128`).

### 4.8A Leaderboard probing: tried and set aside

This section is kept as a record. None of it is in the final file.

**The idea.** Kaggle splits the 2025 test rows at random: 33% are scored on the public board, 67% on the private board. Both parts are the same year and book, so a level error for a line or peril shows in both. We submitted "probe" files that multiplied one line or peril, and read the true-to-predicted ratio θ of each segment from the change in public score.[^w2solver] With power p = 1.5, the deviance of one row is

```
d(y, μ) = 4 y / √μ + 4 √μ − 8 √y
```

so each probe gives one straight-line equation in the θ values, and 14 probes were solved by least squares (`week2/R/26_probe_solver.R`).

**Probes submitted** (source: `week2/output/25_level/probes.csv`):

| # | Change | Public |
|---|---|---|
| 12 | none (line ensemble) | 0.16690 |
| 14-16 | motor × 1.15; buildings × 1.30; contents × 1.30 | 0.16816; 0.17041; 0.16444 |
| 17 | motor 1.14, buildings 1.35, contents 0.93 (`lvl_cal1`) | 0.17192 |
| 18-26 | #17 plus one peril at a time × 1.3 to 1.8 | 0.17134 to 0.17203 |
| 27 | `lvl_half`: each peril halfway (log scale) between its line value and θ, within 0.6 to 1.8 | 0.17445 |

**Why it was set aside.** The θ values come from the public answers, not from anything a pricing team would know in advance. Some readings were impossible for a cost (motor own damage θ = −0.04; buildings escape of water 0.22), which shows how much a few large public claims drive them. With Tweedie scoring, a level set to fit a few extreme public claims can backfire on the private part. Most of all, it is not real-world practice. We kept the scripts and outputs as a record (`week2/R/25_level_calibration.R`, `26_probe_solver.R`, `27_private_sim.R`; decision D035) and did not use any probed factor in the final file.

### 4.9 Week 2, peril by peril

Sources: Option B baseline settings from `week2/docs/optionB/final_model_week2.md` section 3.3; re-tuned baseline from `week2/week1_retune/output/b8_combo_f/diagnostics_final.csv`; motor levels, fields, and credibility from `week2/output/07_adjust/{levels_x20_tblend,cred_x20_tblend_core}.csv`; buildings and contents from `week2/week1_retune/output/var_b8_chosen/07_adjust/{levels_rt_var_b8_chosen,cred_rt_var_b8_chosen_core}.csv` (window 2024 = final fit); M from `week2/output/29_motor_level/burn_by_peril.csv`. "d / eta / mcw" = depth / learning rate / minimum child weight. "Own level" is the raw emerging ÷ mature ratio before credibility; "level" is after credibility, from the level-only fit. "Burn" is expected 2025 cost per policy-year, before (#12) and after M (final). Fitted multipliers for every field level are in Appendix B.

#### Motor own damage (2,672 emerging claims)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (Option B) | XGBoost Poisson 4 / 0.05 / 50, 729 rounds | XGBoost Gamma 3 / 0.05 / 100, 162 rounds; cap q 0.999 = 19,895; load 1.0025 |
| Emerging level | own 1.118 → **1.123**; Z = 2,672 / 2,872 = 0.930 | own 0.624 → **0.626**; Z = 2,672 / 3,072 = 0.870 |
| Emerging fields | gender, voluntary excess, occupation | voluntary excess (core); **blend** 50/50 with emerging-only (vehicle value, vehicle age, voluntary excess) |
| Trend 2024 → 25 | 0 (blend −5.00%, floored) | +3.75% |
| NB load / M | 1.16541 / **1.0611** on NB rows | burn 107.6 → 113.1 |

#### Motor third-party property (2,193)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (Option B) | XGBoost Poisson 4 / 0.05 / 50, 391 rounds | XGBoost Gamma 3 / 0.05 / 100, 20 rounds; cap q 0.999 = 30,908; load 1.0014 |
| Emerging level | own 1.201 → **1.200**; Z = 0.916 | own 0.565 → **0.569**; Z = 0.846 |
| Emerging fields | gender, vehicle value band, self-employed | self-employed |
| Trend | 0 (blend −3.39%, floored) | +4.16% |
| NB load / M | 1.16541 / **1.0611** on NB rows | burn 205.2 → 215.8 |

#### Motor bodily injury (449)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (Option B) | XGBoost Poisson 3 / 0.05 / 100, 325 rounds | Gamma GLM, latest year left out; cap q 0.995 = 187,506; load 1.0478 |
| Emerging level | own 1.194 → **1.195**; Z = 449 / 649 = 0.692 | own 0.541 → **0.579**; K = 1,200, Z = 0.272 |
| Emerging fields | gender, no-claims-years band, voluntary excess | level only (core); **blend** 50/50 with emerging-only (occupation, years-licensed band, gender) |
| Trend | 0 | 0 |
| NB load / M | 1.16541 / **1.1159** (severity) × **1.0611** on NB rows | burn 232.5 → 272.7 |

#### Motor theft (389)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (Option B) | XGBoost Poisson 3 / 0.05 / 50, 363 rounds | Gamma GLM; cap q 0.999 = 55,462; load 1.0017 |
| Emerging level | own 1.320 → **1.277**; Z = 0.660 | own 0.671 → **0.636**; Z = 0.493 |
| Emerging fields | occupation, self-employed | none |
| Trend | 0 (blend −0.93%, floored) | +6.01% |
| NB load / M | 1.16541 / **1.0611** on NB rows | burn 50.1 → 52.7 |

#### Motor glass and hail (1,345)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (Option B) | XGBoost Poisson 3 / 0.05 / 50, 343 rounds | XGBoost Gamma 3 / 0.05 / 100, 45 rounds; cap q 0.999 = 9,593; load 1.0009 |
| Emerging level | own 1.361 → **1.339**; Z = 0.871 | own 0.601 → **0.606**; Z = 0.771 |
| Emerging fields | hail-days band, voluntary excess, vehicle value band, new business | years-licensed band (core); **blend** with emerging-only (vehicle value, vehicle age, years licensed) |
| Trend | +3.00% | +9.21% |
| NB load / M | none (new business is a field) / **1** | burn 29.7 → 29.7 |

#### Buildings storm (464)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (re-tuned) | XGBoost Poisson 2 / 0.05 / 50, 672 rounds | XGBoost Gamma 2 / 0.05 / 100, 151 rounds; cap q 0.999 = 35,330; load 1.0021 |
| Emerging level | own 1.392 → **1.280**; Z = 0.699 | own 0.632 → **0.642**; Z = 0.537 |
| Emerging fields | hail-days band, self-employed, construction type, voluntary excess | none |
| Trend | +3.00% | +8.77% |
| NB load / M | 0.96667 / **1** | burn 53.7 |

#### Buildings flood (80)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (re-tuned) | XGBoost Poisson 2 / 0.05 / 30, 383 rounds | Gamma GLM; cap q 0.995 = 241,228; load 1.0069 |
| Emerging level | own 0.750 → **0.953**; Z = 0.286 | own 0.699 → **0.654**; K = 1,200, Z = 0.063 |
| Emerging fields | construction type | level only |
| Trend | −3.09% | +7.16% |
| NB load / M | 0.96667 / **1** | burn 100.5 |

#### Buildings escape of water (268)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (re-tuned) | XGBoost Poisson 3 / 0.05 / 50, 681 rounds | Gamma GLM; cap q 0.999 = 57,352; load 1.0015 |
| Emerging level | own 0.907 → **0.969**; Z = 0.573 | own 0.566 → **0.619**; Z = 0.401 |
| Emerging fields | hail-days band | none |
| Trend | +0.76% | +7.32% |
| NB load / M | 0.96667 / **1** | burn 66.2 |

#### Buildings subsidence (52)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (re-tuned) | XGBoost Poisson 2 / 0.05 / 30, 332 rounds | Gamma GLM on 2021-23; cap q 0.995 = 129,205; load 1.0052 |
| Emerging level | own 1.049 → **1.060**; Z = 0.206 | own 0.605 → **0.651**; K = 1,200, Z = 0.042 |
| Emerging fields | none | level only |
| Trend | +3.00% | +1.48% |
| NB load / M | 0.96667 / **1** | burn 38.4 |

#### Buildings fire (70)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (re-tuned) | XGBoost Poisson 2 / 0.05 / 15, 355 rounds | Gamma GLM; cap q 0.990 = 293,016; load 1.0193 |
| Emerging level | own 1.197 → **1.094**; Z = 0.259 | own 1.157 → **0.681**; K = 1,200, Z = 0.055 |
| Emerging fields | none | level only |
| Trend | +3.00% | −2.00% |
| NB load / M | 0.96667 / **1** | burn 93.1 |

Fire shows why heavy credibility is used in step 7: its own severity ratio is 1.157, but with 70 claims it gets Z = 0.055, so the step 7 result sits near the buildings pool. The public probes pointed to a higher 2025 fire cost, but probing was set aside (Section 4.8A), so the final file keeps the credibility-weighted level.

#### Buildings accidental damage (122)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (re-tuned) | XGBoost Poisson 2 / 0.05 / 30, 312 rounds | XGBoost Gamma 2 / 0.05 / 100, 19 rounds; cap q 0.999 = 9,514; load 1.0010 |
| Emerging level | own 0.810 → **0.953**; Z = 0.379 | own 0.690 → **0.660**; Z = 0.234 |
| Emerging fields | construction type | none |
| Trend | +3.00% | +2.76% |
| NB load / M | 0.96667 / **1** | burn 5.3 |

#### Contents theft (406)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (re-tuned) | XGBoost Poisson 3 / 0.05 / 50, 316 rounds | Gamma GLM; cap q 0.999 = 32,661; load 1.0031 |
| Emerging level | own 1.103 → **1.044**; Z = 0.670 | own 0.782 → **0.794**; Z = 0.504 |
| Emerging fields | gender | none |
| Trend | +3.00% | +4.12% |
| NB load / M | 1.04938 / **1** | burn 51.9 |

#### Contents escape of water (171)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (re-tuned) | XGBoost Poisson 2 / 0.05 / 50, 380 rounds | XGBoost Gamma 2 / 0.05 / 100, 152 rounds; cap q 0.999 = 23,973; load 1.0025 |
| Emerging level | own 0.870 → **0.904**; Z = 0.461 | own 0.773 → **0.778**; Z = 0.299 |
| Emerging fields | none | none (core); **blend** with emerging-only (sum insured band, gender) |
| Trend | +1.61% | +1.62% |
| NB load / M | 1.04938 / **1** | burn 16.2 |

#### Contents accidental damage (335)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (re-tuned) | XGBoost Poisson 2 / 0.05 / 50, 834 rounds | XGBoost Gamma 2 / 0.05 / 100, 34 rounds; cap q 0.999 = 6,197; load 1.0017 |
| Emerging level | own 0.840 → **0.874**; Z = 0.626 | own 0.775 → **0.773**; Z = 0.456 |
| Emerging fields | new business | none |
| Trend | +1.12% | +1.54% |
| NB load / M | none (new business is a field) / **1** | burn 10.3 |

#### Contents flood (86)

| Part | Frequency | Severity |
|---|---|---|
| Mature baseline (re-tuned) | XGBoost Poisson 2 / 0.05 / 30, 304 rounds | Gamma GLM; cap q 0.995 = 67,335; load 1.0089 |
| Emerging level | own 0.831 → **0.902**; Z = 0.301 | own 0.831 → **0.786**; K = 1,200, Z = 0.067 |
| Emerging fields | none | level only |
| Trend | −3.94% | +6.23% |
| NB load / M | 1.04938 / **1** | burn 30.9 |

**Resulting 2025 cost per policy-year** (source: `week2/output/29_motor_level/results.csv`; buildings and contents from #12):

| Line | Before M (#12) | Final (#31) | Line multiplier |
|---|---|---|---|
| Motor | 625.1 | 684.0 | 1.094 |
| Buildings | 357.1 | 357.1 | 1.000 |
| Contents | 109.4 | 109.4 | 1.000 |

### 4.10 How well week 2 scores

The local test fits on emerging 2023 and scores emerging 2024 against claims developed to ultimate.[^w2write] For the line ensemble before the motor level review: all-lines cost D² 0.1193; motor 0.0456, buildings 0.1038, contents 0.0616 (`week2/docs/week2_workflow.md`, submission 12). The local test cannot judge the motor level review: 2024 is a different year, its actuals are counted at the snapshot rather than at ultimate, and only 9% of 2024 policies are new business. On it the review lowers motor D² slightly (0.0446 → 0.0439; all lines 0.1193 → 0.1190).

Reference points from the motor component's validation:

| Model | As the 2024 policies are | At the 2025 customer mix |
|---|---|---|
| Option B model (`x20_tblend`) | 0.151 | 0.153 |
| Levels only, no emerging fields | 0.146 | 0.151 |
| Mature model unchanged | 0.127 | 0.130 |
| Emerging data alone (simple GLMs) | 0.101 | 0.135 |
| Simulated "perfect model" | 0.149 | 0.170 |

Public board: line ensemble #12 0.16690; final #31 with the motor level review 0.16840. The probed files (set aside, Section 4.8A) scored 0.17192 (`lvl_cal1`) and 0.17445 (`lvl_half`).

---

## 5. Every credibility value in one place

This section collects every credibility constant and weight from both weeks. In each case, the larger the constant, the more data is needed before the own data is believed.

| Week | Where | Formula | Value | Applies to |
|---|---|---|---|---|
| 1 | SAM 3 history relativity | `(n + k f0) / (f0 (min(e,4) + k))` | k = 2 exposure-years; n capped at 3 | each policy's own past claims |
| 1 | C5 severity GLM | rare levels pooled | 30 claims | Gamma GLM fields |
| 1 | C5 severity model floor | plain average below this | 200 claims (not reached) | every peril |
| 1 | MOTOR 2 severity | `exp(η_c + Z (η − η_c))` | Z: OD 1, TPP 0.5, BI 0, theft 1, glass 0.75 | motor severity shape |
| 1 | MOTOR 2 BI frequency | 50/50 pooling with TPP | 0.5 | motor BI |
| 1 | MOTOR 2 few severity claims | keep first 3 fields | below 3,000 claims | motor severity |
| 1 | MOTOR 2 target encoding | (not used by any selected field) | `TE_K` = 200 | – |
| 1 | Ladder motor categories | `(n + 20) / (w + 20 / base)` | 20 pretend claims | motor category fields |
| 1 | WENDY 8 claim history | `(A + N) / (A + E)`, Z = E / (A + E) | A: motor 8, buildings 5, contents 5 | every row |
| 2 | Trend blend | `Z = n / (n + 2,000)` | 2,000 claims | every peril's trend |
| 2 | Frequency level | `Z = n / (n + K)` toward the line pool | K = 200 | every peril |
| 2 | Severity level | `Z = n / (n + K)` toward the claim-weighted line pool | K = 400; 1,200 for fire, flood, subsidence, BI, contents flood | every peril |
| 2 | Frequency field levels | ridge, about `m / (m + λ)` | λ = 30 expected claims | kept fields |
| 2 | Severity field levels | ridge | λ = 30 claims | kept fields |
| 2 | Severity fields allowed | only with enough claims | ≥ 1,000 claims, up to 2 fields | motor OD, TPP, glass |
| 2 | Severity blend | geometric weight | 0.5 | motor OD, glass, BI; contents EoW |
| 2 | New-business load | `Z = n / (n + 300)` toward 1 | K = 300 | line, NB rows |
| 2 | Final motor NB factor | full emerging A/E instead of `Z = n / (n + 300)` | Z = 1 (was 0.70): × 1.23660 ÷ 1.16541 | motor NB rows |
| 2 | Final BI large-claim load | mature load as the complement of credibility | 1.04780 instead of 1.02428 | motor BI |

Other credibility methods were tested in week 2 and did not beat these fixed constants by a measurable margin: limited fluctuation[^longley], Bühlmann-Straub with estimated parameters[^bs], and Jewell's hierarchical model.[^jewell] The limited-fluctuation version used a 90% probability of being within 5%, which needs 1,082 claims for full credibility (`week2/R/07_emerging_adjust.R:61-62`).

Final week 2 credibility weights per peril (final fit, sources: `week2/output/07_adjust/cred_x20_tblend_core.csv` for motor and `week2/week1_retune/output/var_b8_chosen/07_adjust/cred_rt_var_b8_chosen_core.csv` for buildings and contents; the Z values depend only on claim counts, so they are the same in both files):

| Peril | Claims | Z frequency (K 200) | K severity | Z severity |
|---|---|---|---|---|
| motor OD | 2,672 | 0.930 | 400 | 0.870 |
| motor TPP | 2,193 | 0.916 | 400 | 0.846 |
| motor BI | 449 | 0.692 | 1,200 | 0.272 |
| motor theft | 389 | 0.660 | 400 | 0.493 |
| motor glass and hail | 1,345 | 0.871 | 400 | 0.771 |
| buildings storm | 464 | 0.699 | 400 | 0.537 |
| buildings flood | 80 | 0.286 | 1,200 | 0.063 |
| buildings EoW | 268 | 0.573 | 400 | 0.401 |
| buildings subsidence | 52 | 0.206 | 1,200 | 0.042 |
| buildings fire | 70 | 0.259 | 1,200 | 0.055 |
| buildings AD | 122 | 0.379 | 400 | 0.234 |
| contents theft | 406 | 0.670 | 400 | 0.504 |
| contents EoW | 171 | 0.461 | 400 | 0.299 |
| contents AD | 335 | 0.626 | 400 | 0.456 |
| contents flood | 86 | 0.301 | 1,200 | 0.067 |

---

## 6. Known limits

This section lists the main open points, as recorded in the project files.[^w1method][^w2write]

1. **Motor BI level** is the largest open question in both weeks. In week 1 and in the week 2 core model its trend is 0, because a real decline and slow case-estimate development cannot be separated at one valuation date. The week 2 final step sets +4.5% a year from fully settled mature years (Section 4.8). If many emerging BI claims are under-reserved (58% open; paid ÷ incurred 0.49 against 0.69 in the mature market), even this may be low; it cannot be measured from one snapshot.
2. **C5 reproduction**: on Windows, C5 differs from the original Apple fit by about 0.5% per row (median); line totals within 0.15%.
3. **Same folds for choice and scoring**: the week 1 blend weights and A values were chosen on the 2023 and 2024 test years that also score them.
4. **Only claim counts are developed** for late reporting; claim-size development is assumed neutral, except for week 2 motor BI in the final step (× 1.0168). If the 2025 actuals are counted at a snapshot rather than at ultimate, that factor overstates.
5. **Week 2 has one year of out-of-sample evidence** (2024), and catastrophe perils (fire, flood, subsidence) swing between years.
6. **Motor frequency floor at 0** in week 2 is a judgment; the data points to falling accident rates.
7. **Motor new-business load**: the final step uses the full emerging A/E of 1.237 (697 claims) instead of 1.165. If 2025 new customers differ from 2023-24 new customers, this load is where it shows.
8. **Gender** is used in the week 2 emerging adjustment (decision D027). In a real market this would need a check against anti-discrimination rules.
9. **Rule exceptions found in the code**: `compulsory_excess` remains in SAM 3 trees and in C5; `noise_probe` remains in SAM 3 trees; the week 2 re-tuned baseline uses `disc_flag`, built from `discount_applied`.
10. **The motor level factors could not be tested on 2024.** They were set from the training data before any submission; three public submissions only confirmed the direction. Buildings and contents get no level review, although the probes (set aside) suggested buildings may be priced low.
11. **The two components differ in one trend detail**: the home fit brings 2023 to 2024 terms with a 0 frequency trend, while the motor fit uses the blended trend.

---

## 7. Conclusion

Both final models predict the expected 2025 claim cost of each policy as frequency times severity for each of the 15 perils, added up per policy. In week 1, there are four years of mature data, so the model can afford several different model types for each peril and blend them. C5 and the LightGBM ladder share the per-peril work in proportions set peril by peril. SAM 3 adds a line-level blend of GLMs and boosted trees. MOTOR 2 adds smooth motor GLMs in which BI frequency borrows from third-party property and severity shapes are shrunk by a chosen credibility weight. Last, every policy's prediction is moved up or down by its own claim history through the factor `(A + N) / (A + E)`, with the line total held fixed.

In week 2, there are only two years of emerging data. The model therefore takes the shape of the risk from the mature market and uses the emerging data for the level, peril by peril. Each emerging level is a compromise between the peril's own experience and its line's pooled experience, weighted by `n / (n + K)` with K = 200 for frequency and K = 400 or 1,200 for severity. Field-level corrections are kept only when they predict the following year better, and each is shrunk by a ridge penalty worth 30 claims. Trends blend mature and emerging evidence with weight `n / (n + 2,000)`, and new customers carry a load weighted by `n / (n + 300)`. Buildings and contents take their shape from a mature-market model re-tuned for the fields the emerging market has, while motor keeps the shared-field model. Last, the motor cost level is reviewed as an actuary would before signing off a price in a new market: bodily-injury claims inflation from fully settled years, growth of late-reported claims, a mature-market large-claim allowance, and the full new-customer experience, giving × 1.1159 on bodily-injury claim size and × 1.0611 on new-customer rows. We also tried setting levels from public leaderboard probes; it scored higher, but no real pricing team can see next year's claims, so we set it aside. In both weeks, the amount of data behind each number decides how far that number is believed.

---

## Appendix A. Week 1 WENDY 7 C5 feature lists

Source: `models/wendy_iteration_07/c5/features_used.csv` (identical to the workbook `Final_Features` sheet). (+1) means the model may only go up as the field goes up; (−1) only down. Monotone signs act only in XGBoost models.

| Peril | Frequency fields | Severity fields |
|---|---|---|
| motor OD | driver_age, years_licensed, ncb_years(−1), vehicle_value_group, vehicle_age, make_model, engine_size_cc, body_type, transmission, driver_assist, cover_type, annual_mileage(+1), overnight_parking, vehicle_use, named_young_driver(+1), telematics_opt_in, telematics_score, voluntary_excess(−1), compulsory_excess, channel, payment_method, missed_payments_12m(+1), new_business, renewal_count, days_quote_to_inception, occupation, marital_status, credit_band, prior_claims_5y(+1), licence_points(+1), years_at_address, region, urban_density, freezing_days, rainfall_mm, start_month, hist_policy_claims_prev(+1), hist_customer_claims_other_lines_prev(+1) | driver_age, vehicle_value_group(+1), vehicle_age, make_model, body_type, fuel_type, cover_type, voluntary_excess, compulsory_excess, region, urban_density |
| motor TPP | the OD list without vehicle_value_group, transmission, overnight_parking, compulsory_excess, years_at_address, freezing_days, rainfall_mm (31 fields) | driver_age, engine_size_cc, body_type, voluntary_excess, region, urban_density |
| motor BI (Tweedie uses both lists) | driver_age, years_licensed, ncb_years(−1), engine_size_cc, driver_assist, cover_type, annual_mileage(+1), vehicle_use, named_young_driver(+1), telematics_opt_in, telematics_score, voluntary_excess(−1), prior_claims_5y(+1), licence_points(+1), region, urban_density, hist_policy_claims_prev(+1), hist_customer_claims_other_lines_prev(+1) | driver_age, seats, voluntary_excess, region, urban_density |
| motor theft | driver_age, vehicle_value_group, vehicle_age, make_model, engine_size_cc, body_type, fuel_type, cover_type, overnight_parking, voluntary_excess(−1), compulsory_excess, payment_method, missed_payments_12m(+1), credit_band, prior_claims_5y(+1), years_at_address, region, urban_density, start_month, hist_policy_claims_prev(+1), hist_customer_claims_other_lines_prev(+1) | vehicle_value_group, vehicle_age, make_model, cover_type, overnight_parking, voluntary_excess, compulsory_excess, region, urban_density |
| motor glass and hail | vehicle_value_group, make_model, cover_type, annual_mileage(+1), overnight_parking, voluntary_excess(−1), compulsory_excess, prior_claims_5y(+1), region, urban_density, hail_days(+1), wind_exposure_index, freezing_days, start_month, hist_policy_claims_prev(+1), hist_customer_claims_other_lines_prev(+1) | vehicle_value_group(+1), vehicle_age, make_model, body_type, cover_type, voluntary_excess, compulsory_excess, region, hail_days |
| buildings storm | construction_type, voluntary_excess(−1), channel, days_quote_to_inception, prior_claims_5y(+1), region, urban_density, year_built, property_type, roof_type, trees_within_5m(+1), hail_days, wind_exposure_index(+1), rainfall_mm, start_month, hist_policy_claims_prev(+1), hist_customer_claims_other_lines_prev(+1) | sum_insured(+1), construction_type, voluntary_excess, compulsory_excess, region, year_built, property_type, roof_type, listed_building, bedrooms, solar_panels, wind_exposure_index |
| buildings flood | voluntary_excess(−1), prior_claims_5y(+1), region, flood_zone(+1), distance_to_river_km(−1), elevation_m(−1), property_type, basement, rainfall_mm, hist_policy_claims_prev(+1) | sum_insured, voluntary_excess, compulsory_excess, region, flood_zone, distance_to_river_km, elevation_m, property_type, basement, bedrooms, rainfall_mm |
| buildings EoW | policyholder_age, sum_insured, construction_type, occupancy, days_unoccupied(+1), voluntary_excess(−1), channel, payment_method, missed_payments_12m(+1), new_business, renewal_count, days_quote_to_inception, household_size, credit_band, prior_claims_5y(+1), years_at_address, region, urban_density, year_built, property_type, roof_type, basement, energy_rating, freezing_days(+1), mean_temperature_c, start_month, hist_policy_claims_prev(+1), hist_customer_claims_other_lines_prev(+1) | sum_insured, days_unoccupied, voluntary_excess, compulsory_excess, region, year_built, property_type, listed_building, bedrooms, freezing_days |
| buildings subsidence | construction_type, voluntary_excess(−1), prior_claims_5y(+1), region, soil_type, year_built, property_type, basement, trees_within_5m(+1), dry_summer_index(+1), rainfall_mm, mean_temperature_c, start_month, hist_policy_claims_prev(+1) | sum_insured, construction_type, voluntary_excess, compulsory_excess, region, soil_type, year_built, property_type, trees_within_5m, listed_building, bedrooms, dry_summer_index |
| buildings fire | policyholder_age, construction_type, occupancy, days_unoccupied(+1), smoke_alarms, voluntary_excess(−1), missed_payments_12m(+1), household_size, credit_band, prior_claims_5y(+1), region, urban_density, year_built, property_type, energy_rating, solar_panels, dry_summer_index(+1), wildfire_index(+1), start_month, hist_policy_claims_prev(+1) | sum_insured, construction_type, smoke_alarms, voluntary_excess, compulsory_excess, region, property_type, listed_building, bedrooms |
| buildings AD | policyholder_age, occupancy, accidental_damage_cover, voluntary_excess(−1), channel, payment_method, missed_payments_12m(+1), new_business, renewal_count, days_quote_to_inception, household_size, credit_band, prior_claims_5y(+1), years_at_address, region, urban_density, year_built, property_type, bedrooms, hist_policy_claims_prev(+1), hist_customer_claims_other_lines_prev(+1) | sum_insured(+1), accidental_damage_cover, voluntary_excess, compulsory_excess, region |
| contents theft | policyholder_age, sum_insured, tenure, security_level, high_value_items(+1), works_from_home, lodgers, bicycle_cover, voluntary_excess(−1), channel, payment_method, missed_payments_12m(+1), new_business, renewal_count, days_quote_to_inception, household_size, credit_band, prior_claims_5y(+1), years_at_address, region, urban_density, property_type, start_month, hist_policy_claims_prev(+1), hist_customer_claims_other_lines_prev(+1) | sum_insured, security_level, high_value_items, bicycle_cover, voluntary_excess, compulsory_excess, region, urban_density, bedrooms |
| contents EoW (Tweedie uses both lists) | tenure, works_from_home, voluntary_excess(−1), new_business, renewal_count, household_size, credit_band, prior_claims_5y(+1), years_at_address, region, year_built, property_type, roof_type, basement, freezing_days(+1), mean_temperature_c, start_month, hist_policy_claims_prev(+1), hist_customer_claims_other_lines_prev(+1) | sum_insured(+1), voluntary_excess, compulsory_excess, region, year_built, property_type, bedrooms, freezing_days |
| contents AD | policyholder_age, sum_insured, accidental_damage_cover, tenure, works_from_home, lodgers, voluntary_excess(−1), channel, payment_method, missed_payments_12m(+1), new_business, renewal_count, days_quote_to_inception, household_size, credit_band, prior_claims_5y(+1), region, urban_density, property_type, hist_policy_claims_prev(+1), hist_customer_claims_other_lines_prev(+1) | sum_insured(+1), accidental_damage_cover, high_value_items, voluntary_excess, compulsory_excess, region, bedrooms |
| contents flood | tenure, voluntary_excess(−1), days_quote_to_inception, prior_claims_5y(+1), region, flood_zone(+1), distance_to_river_km(−1), elevation_m(−1), property_type, basement, rainfall_mm, start_month, hist_policy_claims_prev(+1) | sum_insured, voluntary_excess, compulsory_excess, region, flood_zone, distance_to_river_km, elevation_m, property_type, basement, bedrooms, rainfall_mm |

---

## Appendix B. Week 2 fitted multipliers

These are the fitted values of the final emerging adjustment, before the motor level factor M (Section 4.8). Sources: `week2/output/07_adjust/coefficients_x20_tblend_core.csv` (motor), `week2/week1_retune/output/var_b8_chosen/07_adjust/coefficients_rt_var_b8_chosen_core.csv` (buildings and contents), `week2/output/07_adjust/coefficients_fin_sevem.csv` (emerging-only severity). Each multiplier is `exp(coefficient)`. The intercept is the peril's emerging level in the model *with* fields; it differs from the level-only value shown in Section 4.9 because the field multipliers do not average exactly to 1. Labels such as `(8,10]` are the band edges. Severity intercepts of the emerging-only models are in currency units, because those models have no mature offset.

### Motor (component `x20_tblend`)

**motor / own_damage: frequency factors (core model, run `x20_tblend_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 0.162478 | 1.176422 |
| `gender=F` | -0.188306 | 0.828361 |
| `gender=M` | 0.059750 | 1.061571 |
| `voluntary_excess=0` | 0.080924 | 1.084288 |
| `voluntary_excess=1000` | -0.093259 | 0.910958 |
| `voluntary_excess=250` | -0.018861 | 0.981316 |
| `voluntary_excess=500` | -0.097360 | 0.907230 |
| `occupation=Accountant` | -0.015937 | 0.984189 |
| `occupation=Administrator` | -0.064730 | 0.937321 |
| `occupation=Builder` | 0.107171 | 1.113125 |
| `occupation=Care worker` | -0.082673 | 0.920652 |
| `occupation=Chef` | -0.029712 | 0.970725 |
| `occupation=Doctor` | 0.118409 | 1.125704 |
| `occupation=Driver` | -0.150801 | 0.860018 |
| `occupation=Electrician` | -0.074282 | 0.928409 |
| `occupation=Engineer` | -0.076288 | 0.926550 |
| `occupation=Hairdresser` | -0.012006 | 0.988066 |
| `occupation=Manager` | 0.097948 | 1.102905 |
| `occupation=Mechanic` | -0.010346 | 0.989707 |
| `occupation=missing` | 0.007599 | 1.007628 |
| `occupation=Nurse` | 0.071355 | 1.073962 |
| `occupation=Retail assistant` | -0.048866 | 0.952309 |
| `occupation=Retired` | 0.074500 | 1.077346 |
| `occupation=Sales representative` | -0.099359 | 0.905417 |
| `occupation=Software developer` | 0.105354 | 1.111104 |
| `occupation=Student` | -0.175695 | 0.838874 |
| `occupation=Teacher` | 0.053499 | 1.054956 |
| `occupation=Unemployed` | 0.076304 | 1.079291 |

**motor / own_damage: severity factors (core model, run `x20_tblend_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.503854 | 0.604197 |
| `voluntary_excess=0` | 0.061153 | 1.063062 |
| `voluntary_excess=1000` | 0.127351 | 1.135815 |
| `voluntary_excess=250` | 0.045951 | 1.047023 |
| `voluntary_excess=500` | -0.090407 | 0.913559 |

**motor / third_party_prop: frequency factors (core model, run `x20_tblend_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 0.185022 | 1.203245 |
| `gender=F` | -0.137599 | 0.871448 |
| `gender=M` | 0.159336 | 1.172732 |
| `vehicle_value_group_b=(-Inf,8]` | -0.022713 | 0.977543 |
| `vehicle_value_group_b=(10,12]` | 0.006924 | 1.006948 |
| `vehicle_value_group_b=(12,14]` | 0.128586 | 1.137219 |
| `vehicle_value_group_b=(14, Inf]` | -0.083437 | 0.919949 |
| `vehicle_value_group_b=(8,10]` | -0.007623 | 0.992406 |
| `self_employed=FALSE` | -0.036206 | 0.964441 |
| `self_employed=TRUE` | 0.057943 | 1.059654 |

**motor / third_party_prop: severity factors (core model, run `x20_tblend_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.528764 | 0.589333 |
| `self_employed=FALSE` | -0.030191 | 0.970260 |
| `self_employed=TRUE` | -0.157893 | 0.853941 |

**motor / bodily_injury: frequency factors (core model, run `x20_tblend_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 0.179572 | 1.196705 |
| `gender=F` | -0.229208 | 0.795164 |
| `gender=M` | 0.214611 | 1.239380 |
| `ncb_years_b=(-Inf,1]` | -0.148573 | 0.861937 |
| `ncb_years_b=(1,3]` | 0.080621 | 1.083960 |
| `ncb_years_b=(12, Inf]` | -0.028443 | 0.971958 |
| `ncb_years_b=(3,8]` | 0.040114 | 1.040929 |
| `ncb_years_b=(8,12]` | 0.041685 | 1.042566 |
| `voluntary_excess=0` | 0.026027 | 1.026368 |
| `voluntary_excess=1000` | -0.101406 | 0.903566 |
| `voluntary_excess=250` | -0.049798 | 0.951422 |
| `voluntary_excess=500` | 0.110580 | 1.116926 |

**motor / bodily_injury: severity factors (core model, run `x20_tblend_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.546089 | 0.579211 |

**motor / theft: frequency factors (core model, run `x20_tblend_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 0.214312 | 1.239009 |
| `occupation=Accountant` | -0.153298 | 0.857874 |
| `occupation=Administrator` | -0.111455 | 0.894531 |
| `occupation=Builder` | 0.111739 | 1.118221 |
| `occupation=Care worker` | 0.110619 | 1.116969 |
| `occupation=Chef` | 0.088696 | 1.092748 |
| `occupation=Doctor` | -0.143112 | 0.866657 |
| `occupation=Driver` | -0.089270 | 0.914598 |
| `occupation=Electrician` | -0.082617 | 0.920704 |
| `occupation=Engineer` | 0.003949 | 1.003957 |
| `occupation=Hairdresser` | 0.159023 | 1.172365 |
| `occupation=Manager` | -0.123577 | 0.883754 |
| `occupation=Mechanic` | 0.285840 | 1.330880 |
| `occupation=missing` | -0.036363 | 0.964290 |
| `occupation=Nurse` | -0.081568 | 0.921670 |
| `occupation=Retail assistant` | -0.058419 | 0.943255 |
| `occupation=Retired` | 0.046286 | 1.047374 |
| `occupation=Sales representative` | 0.065287 | 1.067466 |
| `occupation=Software developer` | -0.059421 | 0.942310 |
| `occupation=Student` | 0.145540 | 1.156664 |
| `occupation=Teacher` | 0.115790 | 1.122760 |
| `occupation=Unemployed` | 0.023337 | 1.023611 |
| `self_employed=FALSE` | 0.006371 | 1.006391 |
| `self_employed=TRUE` | 0.210635 | 1.234461 |

**motor / theft: severity factors (core model, run `x20_tblend_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.452789 | 0.635852 |

**motor / glass_hail: frequency factors (core model, run `x20_tblend_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 0.188637 | 1.207603 |
| `hail_days_b=(-Inf,8]` | -0.166065 | 0.846991 |
| `hail_days_b=(12,16]` | -0.005099 | 0.994914 |
| `hail_days_b=(16,22]` | 0.082277 | 1.085757 |
| `hail_days_b=(22, Inf]` | 0.272892 | 1.313758 |
| `hail_days_b=(8,12]` | -0.138165 | 0.870955 |
| `voluntary_excess=0` | 0.172166 | 1.187875 |
| `voluntary_excess=1000` | -0.190371 | 0.826652 |
| `voluntary_excess=250` | 0.151225 | 1.163258 |
| `voluntary_excess=500` | -0.087180 | 0.916512 |
| `vehicle_value_group_b=(-Inf,8]` | -0.061100 | 0.940729 |
| `vehicle_value_group_b=(10,12]` | -0.072461 | 0.930102 |
| `vehicle_value_group_b=(12,14]` | -0.018720 | 0.981455 |
| `vehicle_value_group_b=(14, Inf]` | 0.085576 | 1.089344 |
| `vehicle_value_group_b=(8,10]` | 0.112544 | 1.119121 |
| `new_business=FALSE` | -0.060228 | 0.941550 |
| `new_business=TRUE` | 0.106068 | 1.111897 |

**motor / glass_hail: severity factors (core model, run `x20_tblend_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.511622 | 0.599522 |
| `years_licensed_b=(-Inf,3]` | -0.048601 | 0.952561 |
| `years_licensed_b=(14,33]` | -0.015166 | 0.984949 |
| `years_licensed_b=(3,14]` | 0.074784 | 1.077651 |
| `years_licensed_b=(33,51]` | -0.021075 | 0.979145 |
| `years_licensed_b=(51, Inf]` | 0.050539 | 1.051838 |

### Buildings and contents (component `rt_var_b8_floor_corrected`)

**buildings / storm: frequency factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 0.067669 | 1.070011 |
| `hail_days_b=(-Inf,8]` | -0.047837 | 0.953289 |
| `hail_days_b=(12,16]` | -0.163846 | 0.848873 |
| `hail_days_b=(16,22]` | 0.009071 | 1.009113 |
| `hail_days_b=(22, Inf]` | 0.372660 | 1.451590 |
| `hail_days_b=(8,12]` | -0.121081 | 0.885963 |
| `self_employed=FALSE` | 0.167450 | 1.182286 |
| `self_employed=TRUE` | -0.118482 | 0.888267 |
| `construction_type=brick` | -0.070232 | 0.932177 |
| `construction_type=non_standard` | 0.197538 | 1.218400 |
| `construction_type=stone` | -0.075102 | 0.927649 |
| `construction_type=timber` | -0.003237 | 0.996768 |
| `voluntary_excess=0` | 0.198258 | 1.219277 |
| `voluntary_excess=1000` | -0.098163 | 0.906501 |
| `voluntary_excess=250` | 0.007547 | 1.007575 |
| `voluntary_excess=500` | -0.058674 | 0.943014 |

**buildings / storm: severity factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.443027 | 0.642090 |

**buildings / flood: frequency factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 0.009598 | 1.009645 |
| `construction_type=brick` | -0.263034 | 0.768716 |
| `construction_type=non_standard` | 0.145451 | 1.156561 |
| `construction_type=stone` | -0.096756 | 0.907777 |
| `construction_type=timber` | -0.123829 | 0.883531 |

**buildings / flood: severity factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.424108 | 0.654353 |

**buildings / escape_of_water: frequency factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 0.006162 | 1.006181 |
| `hail_days_b=(-Inf,8]` | -0.084281 | 0.919173 |
| `hail_days_b=(12,16]` | -0.120551 | 0.886432 |
| `hail_days_b=(16,22]` | -0.133880 | 0.874695 |
| `hail_days_b=(22, Inf]` | -0.114343 | 0.891952 |
| `hail_days_b=(8,12]` | 0.091977 | 1.096340 |

**buildings / escape_of_water: severity factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.480246 | 0.618631 |

**buildings / subsidence: frequency factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 0.057827 | 1.059532 |

**buildings / subsidence: severity factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.429245 | 0.651000 |

**buildings / fire: frequency factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 0.090262 | 1.094461 |

**buildings / fire: severity factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.384238 | 0.680969 |

**buildings / accidental_damage: frequency factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 0.017938 | 1.018100 |
| `construction_type=brick` | -0.234745 | 0.790772 |
| `construction_type=non_standard` | -0.025019 | 0.975291 |
| `construction_type=stone` | -0.074223 | 0.928465 |
| `construction_type=timber` | 0.051417 | 1.052762 |

**buildings / accidental_damage: severity factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.416170 | 0.659568 |

**contents / theft: frequency factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.033299 | 0.967250 |
| `gender=F` | 0.184429 | 1.202532 |
| `gender=M` | 0.039985 | 1.040795 |

**contents / theft: severity factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.230697 | 0.793980 |

**contents / escape_of_water: frequency factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.100853 | 0.904066 |

**contents / escape_of_water: severity factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.250679 | 0.778272 |

**contents / accidental_damage: frequency factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.072575 | 0.929996 |
| `new_business=FALSE` | -0.118871 | 0.887922 |
| `new_business=TRUE` | 0.081446 | 1.084854 |

**contents / accidental_damage: severity factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.257537 | 0.772953 |

**contents / flood: frequency factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.103583 | 0.901601 |

**contents / flood: severity factors (core model, run `rt_var_b8_chosen_core`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | -0.240991 | 0.785848 |

### Emerging-only severity models used in the 50/50 blend


**motor / own_damage: severity factors (emerging-only model, run `fin_sevem`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 6.997808 | 1094.231513 |
| `vehicle_value_group_b=(-Inf,8]` | -0.233514 | 0.791747 |
| `vehicle_value_group_b=(10,12]` | -0.042951 | 0.957959 |
| `vehicle_value_group_b=(12,14]` | 0.082753 | 1.086274 |
| `vehicle_value_group_b=(14, Inf]` | 0.202537 | 1.224505 |
| `vehicle_value_group_b=(8,10]` | -0.008826 | 0.991213 |
| `vehicle_age_b=(-Inf,7]` | 0.193105 | 1.213011 |
| `vehicle_age_b=(11,13]` | -0.060372 | 0.941414 |
| `vehicle_age_b=(13, Inf]` | -0.234291 | 0.791131 |
| `vehicle_age_b=(7,9]` | 0.020559 | 1.020772 |
| `vehicle_age_b=(9,11]` | 0.040801 | 1.041645 |
| `vehicle_age_b=missing` | 0.040198 | 1.041017 |
| `voluntary_excess=0` | 0.011315 | 1.011379 |
| `voluntary_excess=1000` | 0.091628 | 1.095957 |
| `voluntary_excess=250` | 0.015263 | 1.015380 |
| `voluntary_excess=500` | -0.118206 | 0.888513 |

**motor / bodily_injury: severity factors (emerging-only model, run `fin_sevem`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 9.240033 | 10301.380732 |
| `occupation=Accountant` | 0.072974 | 1.075702 |
| `occupation=Administrator` | 0.071883 | 1.074530 |
| `occupation=Builder` | 0.072273 | 1.074949 |
| `occupation=Care worker` | -0.078009 | 0.924956 |
| `occupation=Chef` | 0.170831 | 1.186290 |
| `occupation=Doctor` | 0.078375 | 1.081529 |
| `occupation=Driver` | -0.022227 | 0.978018 |
| `occupation=Electrician` | -0.141898 | 0.867710 |
| `occupation=Engineer` | -0.087967 | 0.915791 |
| `occupation=Hairdresser` | -0.025599 | 0.974726 |
| `occupation=Manager` | -0.135553 | 0.873232 |
| `occupation=Mechanic` | 0.096982 | 1.101840 |
| `occupation=missing` | 0.013242 | 1.013330 |
| `occupation=Nurse` | 0.232743 | 1.262057 |
| `occupation=Retail assistant` | -0.116923 | 0.889654 |
| `occupation=Retired` | -0.203503 | 0.815867 |
| `occupation=Sales representative` | 0.055801 | 1.057387 |
| `occupation=Software developer` | -0.209802 | 0.810745 |
| `occupation=Student` | 0.211848 | 1.235960 |
| `occupation=Teacher` | 0.022417 | 1.022670 |
| `occupation=Unemployed` | -0.077887 | 0.925069 |
| `years_licensed_b=(-Inf,3]` | -0.140695 | 0.868755 |
| `years_licensed_b=(14,33]` | 0.015062 | 1.015176 |
| `years_licensed_b=(3,14]` | 0.079176 | 1.082395 |
| `years_licensed_b=(33,51]` | -0.090934 | 0.913078 |
| `years_licensed_b=(51, Inf]` | 0.137389 | 1.147275 |
| `gender=F` | 0.074837 | 1.077709 |
| `gender=M` | -0.074837 | 0.927894 |

**motor / glass_hail: severity factors (emerging-only model, run `fin_sevem`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 6.653731 | 775.672857 |
| `vehicle_value_group_b=(-Inf,8]` | -0.128834 | 0.879120 |
| `vehicle_value_group_b=(10,12]` | 0.082334 | 1.085818 |
| `vehicle_value_group_b=(12,14]` | 0.039928 | 1.040736 |
| `vehicle_value_group_b=(14, Inf]` | 0.106564 | 1.112449 |
| `vehicle_value_group_b=(8,10]` | -0.099992 | 0.904844 |
| `vehicle_age_b=(-Inf,7]` | 0.034151 | 1.034740 |
| `vehicle_age_b=(11,13]` | 0.014130 | 1.014230 |
| `vehicle_age_b=(13, Inf]` | -0.119367 | 0.887482 |
| `vehicle_age_b=(7,9]` | 0.098379 | 1.103381 |
| `vehicle_age_b=(9,11]` | -0.042131 | 0.958744 |
| `vehicle_age_b=missing` | 0.014839 | 1.014950 |
| `years_licensed_b=(-Inf,3]` | -0.045356 | 0.955657 |
| `years_licensed_b=(14,33]` | -0.034043 | 0.966530 |
| `years_licensed_b=(3,14]` | 0.071918 | 1.074567 |
| `years_licensed_b=(33,51]` | -0.032518 | 0.968005 |
| `years_licensed_b=(51, Inf]` | 0.039999 | 1.040810 |

**contents / escape_of_water: severity factors (emerging-only model, run `fin_sevem`)**

| Term | Coefficient (log scale) | Multiplier (relativity) |
|---|---|---|
| `(Intercept)` | 7.527270 | 1858.026214 |
| `sum_insured_b=(-Inf,21900]` | -0.166902 | 0.846282 |
| `sum_insured_b=(21900,30800]` | -0.167570 | 0.845717 |
| `sum_insured_b=(30800,41500]` | -0.203403 | 0.815950 |
| `sum_insured_b=(41500,56700]` | 0.052753 | 1.054169 |
| `sum_insured_b=(56700, Inf]` | 0.485122 | 1.624373 |
| `gender=F` | 0.122838 | 1.130701 |
| `gender=M` | -0.122838 | 0.884407 |

---

## Bibliography

Bates, J. M., and C. W. J. Granger. "The Combination of Forecasts." *Operational Research Quarterly* 20, no. 4 (1969): 451–468.

Boor, Joseph A. "The Complement of Credibility." *Proceedings of the Casualty Actuarial Society* 83 (1996): 1–40.

Bornhuetter, Ronald L., and Ronald E. Ferguson. "The Actuary and IBNR." *Proceedings of the Casualty Actuarial Society* 59 (1972): 181–195.

Breiman, Leo. "Bagging Predictors." *Machine Learning* 24, no. 2 (1996): 123–140.

Bühlmann, Hans. "Experience Rating and Credibility." *ASTIN Bulletin* 4, no. 3 (1967): 199–207.

Bühlmann, Hans, and Alois Gisler. *A Course in Credibility Theory and Its Applications*. Berlin: Springer, 2005.

Bühlmann, Hans, and Erwin Straub. "Glaubwürdigkeit für Schadensätze." *Mitteilungen der Vereinigung Schweizerischer Versicherungsmathematiker* 70 (1970): 111–133.

Caruana, Rich, Alexandru Niculescu-Mizil, Geoff Crew, and Alex Ksikes. "Ensemble Selection from Libraries of Models." In *Proceedings of the 21st International Conference on Machine Learning*. New York: ACM, 2004.

Chen, Tianqi, and Carlos Guestrin. "XGBoost: A Scalable Tree Boosting System." In *Proceedings of the 22nd ACM SIGKDD International Conference on Knowledge Discovery and Data Mining*, 785–794. New York: ACM, 2016.

Efron, Bradley, and Robert J. Tibshirani. *An Introduction to the Bootstrap*. New York: Chapman & Hall, 1993.

Friedland, Jacqueline. *Estimating Unpaid Claims Using Basic Techniques*. Arlington, VA: Casualty Actuarial Society, 2010.

Friedman, Jerome H. "Greedy Function Approximation: A Gradient Boosting Machine." *Annals of Statistics* 29, no. 5 (2001): 1189–1232.

Hastie, Trevor, and Robert Tibshirani. *Generalized Additive Models*. London: Chapman & Hall, 1990.

Hoerl, Arthur E., and Robert W. Kennard. "Ridge Regression: Biased Estimation for Nonorthogonal Problems." *Technometrics* 12, no. 1 (1970): 55–67.

Jewell, William S. "Credible Means Are Exact Bayesian for Exponential Families." *ASTIN Bulletin* 8, no. 1 (1974): 77–90.

Jørgensen, Bent, and Marta C. Paes de Souza. "Fitting Tweedie's Compound Poisson Model to Insurance Claims Data." *Scandinavian Actuarial Journal* 1994, no. 1 (1994): 69–93.

Kaplan, E. L., and Paul Meier. "Nonparametric Estimation from Incomplete Observations." *Journal of the American Statistical Association* 53, no. 282 (1958): 457–481.

Ke, Guolin, Qi Meng, Thomas Finley, Taifeng Wang, Wei Chen, Weidong Ma, Qiwei Ye, and Tie-Yan Liu. "LightGBM: A Highly Efficient Gradient Boosting Decision Tree." In *Advances in Neural Information Processing Systems 30*, 3146–3154. Red Hook, NY: Curran Associates, 2017.

Klugman, Stuart A., Harry H. Panjer, and Gordon E. Willmot. *Loss Models: From Data to Decisions*. 4th ed. Hoboken, NJ: Wiley, 2012.

Lawless, J. F. "Adjustments for Reporting Delays and the Prediction of Occurred but Not Reported Events." *Canadian Journal of Statistics* 22, no. 1 (1994): 15–31.

Longley-Cook, Laurence H. "An Introduction to Credibility Theory." *Proceedings of the Casualty Actuarial Society* 49 (1962): 194–221.

Low, Wendy, and project team. *Final Week 1 Model: Methodology, Guardrails and Actuarial Rationale*. SnorlaxCode project repository, 2026. `week1/final_week1_R_Script/MODEL_METHODOLOGY.md`.

Low, Wendy, and project team. *Week 2 Final Model: Full Method (Emerging Market 2025, `motorlevel_l_full`)*. SnorlaxCode project repository, 2026. `week2/docs/final_model_method_week2.md`.

Low, Wendy, and project team. *Week 2 Final Submission: The Emerging-Market Pricing Model*. SnorlaxCode project repository, 2026. `week2/docs/final_submission_writeup_week2.md`.

Mack, Thomas. "Distribution-Free Calculation of the Standard Error of Chain Ladder Reserve Estimates." *ASTIN Bulletin* 23, no. 2 (1993): 213–225.

McCullagh, Peter, and John A. Nelder. *Generalized Linear Models*. 2nd ed. London: Chapman & Hall, 1989.

Micci-Barreca, Daniele. "A Preprocessing Scheme for High-Cardinality Categorical Attributes in Classification and Prediction Problems." *ACM SIGKDD Explorations* 3, no. 1 (2001): 27–32.

Miccolis, Robert S. "On the Theory of Increased Limits and Excess of Loss Pricing." *Proceedings of the Casualty Actuarial Society* 64 (1977): 27–59.

Nelder, John A., and Robert W. M. Wedderburn. "Generalized Linear Models." *Journal of the Royal Statistical Society, Series A* 135, no. 3 (1972): 370–384.

Ohlsson, Esbjörn, and Björn Johansson. *Non-Life Insurance Pricing with Generalized Linear Models*. Berlin: Springer, 2010.

Stanard, James N. "A Simulation Test of Prediction Errors of Loss Reserve Estimation Techniques." *Proceedings of the Casualty Actuarial Society* 72 (1985): 124–148.

Timmermann, Allan. "Forecast Combinations." In *Handbook of Economic Forecasting*, vol. 1, edited by Graham Elliott, Clive W. J. Granger, and Allan Timmermann, 135–196. Amsterdam: Elsevier, 2006.

Tweedie, M. C. K. "An Index Which Distinguishes between Some Important Exponential Families." In *Statistics: Applications and New Directions*, edited by J. K. Ghosh and J. Roy, 579–604. Calcutta: Indian Statistical Institute, 1984.

Werner, Geoff, and Claudine Modlin. *Basic Ratemaking*. 5th ed. Arlington, VA: Casualty Actuarial Society, 2016.

<!-- Footnotes -->

[^werner]: Geoff Werner and Claudine Modlin, *Basic Ratemaking*, 5th ed. (Arlington, VA: Casualty Actuarial Society, 2016), chap. 7 (pure premium method) and chap. 6 (trending).
[^handoff]: Project brief and local protocol: `week1/docs/HANDOFF_claude_code.md`; project memory `CLAUDE.md`.
[^clean]: `week1/final_week1_R_Script/R/2_clean.R:151-152` (net cost, repudiated = 0); `R/w89_core.R:45, 59` (exposure).
[^ohlsson]: Esbjörn Ohlsson and Björn Johansson, *Non-Life Insurance Pricing with Generalized Linear Models* (Berlin: Springer, 2010), chaps. 2–3.
[^c5code]: `week1/final_week1_R_Script/R/4_models_iterwendy07.R:194-271` (claim basis, chain ladder), `:499-625` (claim preparation, prediction); `week2/R/00_setup_week2.R` (`claim_basis`, same rules).
[^tweedie]: M. C. K. Tweedie, "An Index Which Distinguishes between Some Important Exponential Families," in *Statistics: Applications and New Directions*, ed. J. K. Ghosh and J. Roy (Calcutta: Indian Statistical Institute, 1984), 579–604.
[^jorgensen]: Bent Jørgensen and Marta C. Paes de Souza, "Fitting Tweedie's Compound Poisson Model to Insurance Claims Data," *Scandinavian Actuarial Journal* 1994, no. 1 (1994): 69–93.
[^w2write]: Wendy Low and project team, *Week 2 Final Submission: The Emerging-Market Pricing Model* (SnorlaxCode project repository, 2026), §§1–7; `week2/docs/final_submission_writeup_week2.md`.
[^w2setup]: `week2/R/00_setup_week2.R`, functions `tweedie_dev` and `d2_tweedie`.
[^nelder]: John A. Nelder and Robert W. M. Wedderburn, "Generalized Linear Models," *Journal of the Royal Statistical Society, Series A* 135, no. 3 (1972): 370–384.
[^mccullagh]: Peter McCullagh and John A. Nelder, *Generalized Linear Models*, 2nd ed. (London: Chapman & Hall, 1989).
[^hastie90]: Trevor Hastie and Robert Tibshirani, *Generalized Additive Models* (London: Chapman & Hall, 1990).
[^friedman]: Jerome H. Friedman, "Greedy Function Approximation: A Gradient Boosting Machine," *Annals of Statistics* 29, no. 5 (2001): 1189–1232.
[^xgb]: Tianqi Chen and Carlos Guestrin, "XGBoost: A Scalable Tree Boosting System," in *Proceedings of the 22nd ACM SIGKDD International Conference on Knowledge Discovery and Data Mining* (New York: ACM, 2016), 785–794.
[^lgbm]: Guolin Ke et al., "LightGBM: A Highly Efficient Gradient Boosting Decision Tree," in *Advances in Neural Information Processing Systems 30* (Red Hook, NY: Curran Associates, 2017), 3146–3154.
[^breiman]: Leo Breiman, "Bagging Predictors," *Machine Learning* 24, no. 2 (1996): 123–140.
[^buhlmann67]: Hans Bühlmann, "Experience Rating and Credibility," *ASTIN Bulletin* 4, no. 3 (1967): 199–207.
[^bg]: Hans Bühlmann and Alois Gisler, *A Course in Credibility Theory and Its Applications* (Berlin: Springer, 2005), chaps. 2–4 (Poisson-Gamma model, Bühlmann and Bühlmann-Straub models).
[^hoerl]: Arthur E. Hoerl and Robert W. Kennard, "Ridge Regression: Biased Estimation for Nonorthogonal Problems," *Technometrics* 12, no. 1 (1970): 55–67.
[^w2adj]: `week2/R/07_emerging_adjust.R:1-16` (method), `:30-36` (constants), `:184-205` (`pglm`), `:338-345` (frequency), `:384-401` (severity).
[^mack]: Thomas Mack, "Distribution-Free Calculation of the Standard Error of Chain Ladder Reserve Estimates," *ASTIN Bulletin* 23, no. 2 (1993): 213–225.
[^friedland]: Jacqueline Friedland, *Estimating Unpaid Claims Using Basic Techniques* (Arlington, VA: Casualty Actuarial Society, 2010), chap. 7.
[^lawless]: J. F. Lawless, "Adjustments for Reporting Delays and the Prediction of Occurred but Not Reported Events," *Canadian Journal of Statistics* 22, no. 1 (1994): 15–31.
[^w1method]: Wendy Low and project team, *Final Week 1 Model: Methodology, Guardrails and Actuarial Rationale* (SnorlaxCode project repository, 2026), §§3–6, 12, 14; `week1/final_week1_R_Script/MODEL_METHODOLOGY.md`.
[^klugman]: Stuart A. Klugman, Harry H. Panjer, and Gordon E. Willmot, *Loss Models: From Data to Decisions*, 4th ed. (Hoboken, NJ: Wiley, 2012), chap. 8 (policy limits and coverage modifications).
[^w1readme]: `week1/final_week1_R_Script/README.md`.
[^ibnrreport]: `week1/final_week1_R_Script/output/3b_ibnr/report.md`; summarized in Low and project team, *Final Week 1 Model*, §6.
[^kaplan]: E. L. Kaplan and Paul Meier, "Nonparametric Estimation from Incomplete Observations," *Journal of the American Statistical Association* 53, no. 282 (1958): 457–481.
[^sam3code]: `week1/final_week1_R_Script/R/4_models_itersam03.R:315-353` (history features), `:351` (relativity), `:43-44` (k = 2, cap 3).
[^caruana]: Rich Caruana et al., "Ensemble Selection from Libraries of Models," in *Proceedings of the 21st International Conference on Machine Learning* (New York: ACM, 2004).
[^w7log]: `week1/docs/wendy07_experiment_log.md` (steps 7–18); workbook sheet `Changes_vs_WENDY4` in `inputs/assumptions_wendy07_final2.xlsx`.
[^micci]: Daniele Micci-Barreca, "A Preprocessing Scheme for High-Cardinality Categorical Attributes in Classification and Prediction Problems," *ACM SIGKDD Explorations* 3, no. 1 (2001): 27–32.
[^jewell]: William S. Jewell, "Credible Means Are Exact Bayesian for Exponential Families," *ASTIN Bulletin* 8, no. 1 (1974): 77–90.
[^bates]: J. M. Bates and C. W. J. Granger, "The Combination of Forecasts," *Operational Research Quarterly* 20, no. 4 (1969): 451–468.
[^timmermann]: Allan Timmermann, "Forecast Combinations," in *Handbook of Economic Forecasting*, vol. 1, ed. Graham Elliott, Clive W. J. Granger, and Allan Timmermann (Amsterdam: Elsevier, 2006), 135–196.
[^efron]: Bradley Efron and Robert J. Tibshirani, *An Introduction to the Bootstrap* (New York: Chapman & Hall, 1993).
[^w2ibnr]: `week2/R/04_ibnr_trend_week2.R:21-41` (chain ladder), `:111-130` (trend blend and clamps); `week2/R/00_setup_week2.R`, function `trend_mode` (X20); `week2/R/08_loadings_2025.R:31-33` (motor floor).
[^w2method]: Wendy Low and project team, *Week 2 Final Model: Full Method (Emerging Market 2025, `motorlevel_l_full`)* (SnorlaxCode project repository, 2026), §§1–10 and 8A; `week2/docs/final_model_method_week2.md`.
[^w2solver]: `week2/R/26_probe_solver.R:1-12` (method); `week2/R/25_level_calibration.R:23-33` (multipliers); `week2/output/25_level/probes.csv`.
[^w2final5]: `week2/docs/optionB/final_model_week2.md` §3.3.
[^w2motor]: `week2/R/29_motor_level.R` (factors, 2024 back-test, candidate files); `week2/R/30_final_from_components.R` (quick rebuild); `week2/output/29_motor_level/{factors,results,burn_by_peril}.csv`; `week2/docs/final_model_method_week2.md` section 8A; decisions D035-D036 in `week2/docs/optionB/decision_register.csv`.
[^w2nb]: `week2/R/nb_load_fns.R` (`nb_load_table`, defaults `NB_K` = 300, prior 1, per line); `week2/R/08_loadings_2025.R:46-61`.
[^bf]: Ronald L. Bornhuetter and Ronald E. Ferguson, "The Actuary and IBNR," *Proceedings of the Casualty Actuarial Society* 59 (1972): 181–195.
[^stanard]: James N. Stanard, "A Simulation Test of Prediction Errors of Loss Reserve Estimation Techniques," *Proceedings of the Casualty Actuarial Society* 72 (1985): 124–148 (the Cape Cod / Stanard-Bühlmann method).
[^miccolis]: Robert S. Miccolis, "On the Theory of Increased Limits and Excess of Loss Pricing," *Proceedings of the Casualty Actuarial Society* 64 (1977): 27–59.
[^boor]: Joseph A. Boor, "The Complement of Credibility," *Proceedings of the Casualty Actuarial Society* 83 (1996): 1–40.
[^longley]: Laurence H. Longley-Cook, "An Introduction to Credibility Theory," *Proceedings of the Casualty Actuarial Society* 49 (1962): 194–221.
[^bs]: Hans Bühlmann and Erwin Straub, "Glaubwürdigkeit für Schadensätze," *Mitteilungen der Vereinigung Schweizerischer Versicherungsmathematiker* 70 (1970): 111–133.
