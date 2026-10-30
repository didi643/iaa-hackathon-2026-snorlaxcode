# Iteration SAM 3 (`sam_iteration_03`)

**Run id** `20261022_1159` | **Generated** 2026-10-22 14:01 | **Git commit** `e3373d1 + uncommitted changes in R/` | **Submission file** `submission_20261022_1159.csv`

**Change in this iteration:** SAM 3 rebuild with per-peril frequency x severity (GLM, LightGBM, XGBoost) using report-share exposure offsets, observed capped claim severity, claim-history features, per-peril report-lag IBNR and a fitted trend to 2025 (capped at +/-10% a year); line Tweedie bags (LightGBM, XGBoost); greedy blend chosen on calibrated D2 over three rolling folds; written_premium and noise fields excluded.

> **Warning:** generated from uncommitted code.

## Phase 0 - is the old framework off track?
### Predicted 2025 cost per exposure-year of past submissions vs their public D2

| submission | motor | buildings | contents | public_d2 |
|---|---|---|---|---|
| #1 iteration_01 | 518.1190 | 425.0838 | 113.2029 | 0.1190 |
| #2 iteration_02 | 498.8029 | 434.2517 | 119.1349 | 0.1215 |
| #3 sam_iteration_01 | 518.1190 | 411.7918 | 111.8020 | 0.1188 |
| this run (sam_iteration_03) | 603.2618 | 487.4396 | 125.1663 |  |

### Replay of iteration 1 (GLM) and iteration 2 (XGBoost) in the new validation (combined D2, all lines)
Public order is iteration 2 > iteration 1. Replay ranks XGBoost above GLM in every fold: **FALSE**.

| valid_year | d2_legacy_glm | d2_legacy_xgb | d2_flat_legacy_glm | d2_flat_legacy_xgb | xgb_beats_glm |
|---|---|---|---|---|---|
| 2022 | 0.1054 | 0.1035 | 0.1383 | 0.1364 | FALSE |
| 2023 | 0.1059 | 0.1017 | 0.1416 | 0.1375 | FALSE |
| 2024 | 0.0950 | 0.0983 | 0.1268 | 0.1299 | TRUE |

### Level sensitivity (2023 fold, blend scaled by a constant, combined D2)

| scale | d2_combined | d2_combined_flat |
|---|---|---|
| 0.8500 | 0.0993 | 0.1352 |
| 0.9000 | 0.1019 | 0.1377 |
| 0.9500 | 0.1035 | 0.1393 |
| 1 | 0.1043 | 0.1400 |
| 1.0500 | 0.1044 | 0.1401 |
| 1.1000 | 0.1038 | 0.1395 |
| 1.1500 | 0.1027 | 0.1384 |

## Reproducibility
Submission MD5 `a6b3a87a02708a8f0acadafdedc30bf4`. The submitted blend per line is saved in `models/sam_iteration_03/fitted/<line>_blend.rds` (boosters embedded). Prepared data: `data/sam03/` (rebuild with this script).

```r
source("R/0_setup.R"); source("R/model_io.R")
art  <- load_model("models/sam_iteration_03/fitted", "motor_blend")
pred <- pmax(score_model(art, arrow::read_parquet("data/sam03/test_motor.parquet")), 0)
```

Replication check: **passed**

| line | model | rows | max_abs_diff |
|---|---|---|---|
| motor | blend | 254,986 | 0 |
| buildings | blend | 184,155 | 0 |
| contents | blend | 187,498 | 0 |

## Settings
| setting | value |
|---|---|
| Training years (final fit) | 2021-2024 |
| Validation folds | fit < 2022 / 2023 / 2024, score that year |
| Selection | greedy forward blend (10 x 0.1) per line on mean calibrated D2 over the three folds |
| Large losses | claim-level cap at p99.5 per line x peril; per-peril loading = cost / capped cost |
| IBNR | frequency-only per line x peril x policy year from the 2021-22 report-lag distribution; effective exposure = exposure / IBNR factor; severity uses observed capped claims |
| Long-tail perils | buildings.subsidence, motor.bodily_injury (2023 open share > 15%): severity on policy years < 2023, frequency with a 2024 dummy |
| Trend | policy_year term in each per-peril frequency and severity GLM, capped at +/-10% a year; tree models take the GLM level |
| GLM | 6 quantile bins, levels < 0.5% exposure merged to base; frequency on all claim rows + 3e+05 sampled zero rows (reweighted) |
| LightGBM | learning_rate=0.05, num_leaves=15, min_data_in_leaf=500, feature_fraction=0.7, bagging_fraction=0.8, bagging_freq=1, lambda_l2=10, cat_smooth=50, cat_l2=10, min_data_per_group=500, max_cat_threshold=32, verbosity=-1, deterministic=1, force_col_wise=1, num_threads=12 |
| XGBoost line Tweedie | motor: max_depth=3, learning_rate=0.05, min_child_weight=500, subsample=0.7, colsample_bytree=0.6, reg_lambda=5, tweedie_variance_power=1.7; buildings: max_depth=3, learning_rate=0.03, min_child_weight=200, subsample=0.8, colsample_bytree=0.7, reg_lambda=10, tweedie_variance_power=1.5; contents: max_depth=3, learning_rate=0.05, min_child_weight=500, subsample=0.7, colsample_bytree=0.7, reg_lambda=1, tweedie_variance_power=1.5 |
| XGBoost per-peril | line settings with count:poisson and min_child_weight=10 |
| Bagging | 3 seeds per-peril, 5 seeds line Tweedie; member 1 early-stops on a 10% policy holdout |
| Excluded features | row_id, policy_id, customer_id, address_id, period_start, period_end, exposure, exposure_raw, renewal_decision, surname, date_of_birth, policy_year, customer_service_contacts, written_premium, discount_applied, email_domain, vehicle_colour, document_preference, marketing_consent, campaign_code, branch_id, marketing_segment |
| Quick mode | FALSE |
| Seed | 2026 + offsets by line, model, year and peril (fit_seed()) |

## Data checks (rebuilt from raw)
| dataset | check | n | expected_from_handover | action |
|---|---|---|---|---|
| customers | duplicate customer_id | 0 |  | none expected |
| addresses | duplicate address_id | 0 |  | none expected |
| weather | duplicate address_id x year | 0 |  | none expected |
| claims | 9-digit claim_id duplicating another claim | 604 | 604 | dropped |
| claims | recoveries > incurred | 0 |  | none expected |
| claims | report_date before loss_date | 0 |  | none expected |
| claims | non-repudiated claims with net cost <= 0 | 1 |  | not counted as claims (frequency x severity uses claims with cost > 0) |
| claims | loss_date 2020-12-01 (spike) | 252 | 252 | excluded (no policy row) |
| policies_motor | customer_id shorter than 8 chars | 98,110 | 98,110 | left-padded to 8 |
| policies_motor | exposure inconsistent with period dates | 5,736 | 5,653 | recomputed as days / 365 |
| policies_motor | period_end before period_start | 0 |  | none expected |
| policies_motor | years_licensed > driver_age - 16 | 2,962 |  | capped at driver_age - 16 |
| policies_motor | duplicate row_id | 0 |  | none expected |
| policies_motor | customer_id not in customers | 0 |  | none expected after padding |
| policies_motor | address_id not in addresses | 0 |  | none expected |
| policies_motor | rows without weather | 0 |  | none expected |
| test_motor | customer_id shorter than 8 chars | 25,554 | 25,554 | left-padded to 8 |
| test_motor | exposure inconsistent with period dates | 0 | 0 | recomputed as days / 365 |
| test_motor | period_end before period_start | 0 |  | none expected |
| test_motor | years_licensed > driver_age - 16 | 755 |  | capped at driver_age - 16 |
| test_motor | duplicate row_id | 0 |  | none expected |
| test_motor | customer_id not in customers | 0 |  | none expected after padding |
| test_motor | address_id not in addresses | 0 |  | none expected |
| test_motor | rows without weather | 0 |  | none expected |
| claims_motor | claims matching more than one row | 0 |  | none expected |
| claims_motor | claims matching no policy row | 296 | 297 | excluded |
| policies_buildings | customer_id shorter than 8 chars | 0 |  | left-padded to 8 |
| policies_buildings | exposure inconsistent with period dates | 4,182 | 4,128 | recomputed as days / 365 |
| policies_buildings | period_end before period_start | 0 |  | none expected |
| policies_buildings | sum_insured > cap and divisible by 1000 | 1,395 | 1,395 | candidates for the /1000 fix |
| policies_buildings | of which /1000 lands in the normal train range | 1,395 |  | divided by 1000 |
| policies_buildings | construction_type codes T / W | 85,556 |  | mapped to timber (checked below) |
| policies_buildings | duplicate row_id | 0 |  | none expected |
| policies_buildings | customer_id not in customers | 0 |  | none expected after padding |
| policies_buildings | address_id not in addresses | 0 |  | none expected |
| policies_buildings | rows without weather | 0 |  | none expected |
| test_buildings | customer_id shorter than 8 chars | 0 |  | left-padded to 8 |
| test_buildings | exposure inconsistent with period dates | 0 | 0 | recomputed as days / 365 |
| test_buildings | period_end before period_start | 0 |  | none expected |
| test_buildings | sum_insured > cap and divisible by 1000 | 370 | 370 | candidates for the /1000 fix |
| test_buildings | of which /1000 lands in the normal train range | 370 |  | divided by 1000 |
| test_buildings | construction_type codes T / W | 22,261 |  | mapped to timber (checked below) |
| test_buildings | duplicate row_id | 0 |  | none expected |
| test_buildings | customer_id not in customers | 0 |  | none expected after padding |
| test_buildings | address_id not in addresses | 0 |  | none expected |
| test_buildings | rows without weather | 0 |  | none expected |
| claims_buildings | claims matching more than one row | 0 |  | none expected |
| claims_buildings | claims matching no policy row | 67 | 67 | excluded |
| policies_buildings | claim frequency, construction code stone | 0.043 |  | T and W should match timber-like frequency |
| policies_buildings | claim frequency, construction code brick | 0.042 |  | T and W should match timber-like frequency |
| policies_buildings | claim frequency, construction code T | 0.045 |  | T and W should match timber-like frequency |
| policies_buildings | claim frequency, construction code non_standard | 0.059 |  | T and W should match timber-like frequency |
| policies_buildings | claim frequency, construction code W | 0.045 |  | T and W should match timber-like frequency |
| policies_contents | customer_id shorter than 8 chars | 0 |  | left-padded to 8 |
| policies_contents | exposure inconsistent with period dates | 4,311 | 4,253 | recomputed as days / 365 |
| policies_contents | period_end before period_start | 0 |  | none expected |
| policies_contents | sum_insured > cap and divisible by 1000 | 1,402 | 1,402 | candidates for the /1000 fix |
| policies_contents | of which /1000 lands in the normal train range | 1,402 |  | divided by 1000 |
| policies_contents | duplicate row_id | 0 |  | none expected |
| policies_contents | customer_id not in customers | 0 |  | none expected after padding |
| policies_contents | address_id not in addresses | 0 |  | none expected |
| policies_contents | rows without weather | 0 |  | none expected |
| test_contents | customer_id shorter than 8 chars | 0 |  | left-padded to 8 |
| test_contents | exposure inconsistent with period dates | 0 | 0 | recomputed as days / 365 |
| test_contents | period_end before period_start | 0 |  | none expected |
| test_contents | sum_insured > cap and divisible by 1000 | 360 | 360 | candidates for the /1000 fix |
| test_contents | of which /1000 lands in the normal train range | 360 |  | divided by 1000 |
| test_contents | duplicate row_id | 0 |  | none expected |
| test_contents | customer_id not in customers | 0 |  | none expected after padding |
| test_contents | address_id not in addresses | 0 |  | none expected |
| test_contents | rows without weather | 0 |  | none expected |
| claims_contents | claims matching more than one row | 0 |  | none expected |
| claims_contents | claims matching no policy row | 50 | 50 | excluded |

## Per-peril IBNR, caps, trend and loading
IBNR factor by policy year (inverse reporting probability from the 2021-22 report-lag distribution):

| line | peril | long_tail | 2021 | 2022 | 2023 | 2024 |
|---|---|---|---|---|---|---|
| buildings | accidental_damage | FALSE | 1 | 1 | 1.001 | 1.027 |
| buildings | escape_of_water | FALSE | 1 | 1 | 1.002 | 1.061 |
| buildings | fire | FALSE | 1 | 1 | 1.001 | 1.010 |
| buildings | flood | FALSE | 1 | 1 | 1.001 | 1.014 |
| buildings | storm | FALSE | 1 | 1 | 1.002 | 1.044 |
| buildings | subsidence | TRUE | 1 | 1.000 | 1.016 | 1.602 |
| contents | accidental_damage | FALSE | 1 | 1 | 1.001 | 1.031 |
| contents | escape_of_water | FALSE | 1 | 1 | 1.002 | 1.047 |
| contents | flood | FALSE | 1 | 1 | 1.003 | 1.030 |
| contents | theft | FALSE | 1 | 1 | 1.001 | 1.012 |
| motor | bodily_injury | TRUE | 1.000 | 1.005 | 1.057 | 1.736 |
| motor | glass_hail | FALSE | 1 | 1 | 1.002 | 1.017 |
| motor | own_damage | FALSE | 1 | 1 | 1.001 | 1.028 |
| motor | theft | FALSE | 1 | 1 | 1.001 | 1.012 |
| motor | third_party_prop | FALSE | 1 | 1 | 1.002 | 1.049 |

Final fit (2021-24): fitted vs used (capped) annual trend, 2024 immaturity relativity for long-tail perils, severity claims and loading:

| line | peril | long_tail | freq_trend_fitted | freq_trend_used | imm_2024_rel | sev_trend_fitted | sev_trend_used | sev_claims | loading |
|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | FALSE | -0.054 | -0.054 |  | 0.082 | 0.082 | 48,258 | 1.010 |
| motor | third_party_prop | FALSE | -0.053 | -0.053 |  | 0.078 | 0.078 | 32,963 | 1.006 |
| motor | bodily_injury | TRUE | -0.062 | -0.062 | 1.008 | 0.045 | 0.045 | 4,285 | 1.036 |
| motor | theft | FALSE | -0.015 | -0.015 |  | 0.064 | 0.064 | 6,119 | 1.007 |
| motor | glass_hail | FALSE | -0.019 | -0.019 |  | 0.080 | 0.080 | 15,643 | 1.006 |
| buildings | storm | FALSE | 0.007 | 0.007 |  | 0.067 | 0.067 | 7,762 | 1.009 |
| buildings | flood | FALSE | -0.025 | -0.025 |  | 0.048 | 0.048 | 2,219 | 1.008 |
| buildings | escape_of_water | FALSE | 0.001 | 0.001 |  | 0.069 | 0.069 | 10,065 | 1.007 |
| buildings | subsidence | TRUE | 0.008 | 0.008 | 1.179 | 0.048 | 0.048 | 617 | 1.001 |
| buildings | fire | FALSE | 0.054 | 0.054 |  | -0.048 | -0.048 | 1,107 | 1.008 |
| buildings | accidental_damage | FALSE | -0.000 | -0.000 |  | 0.016 | 0.016 | 3,825 | 1.006 |
| contents | theft | FALSE | 0.011 | 0.011 |  | 0.031 | 0.031 | 7,626 | 1.008 |
| contents | escape_of_water | FALSE | -0.001 | -0.001 |  | 0.016 | 0.016 | 5,366 | 1.008 |
| contents | accidental_damage | FALSE | -0.009 | -0.009 |  | 0.025 | 0.025 | 9,063 | 1.004 |
| contents | flood | FALSE | -0.029 | -0.029 |  | 0.057 | 0.057 | 1,615 | 1.009 |

| peril | cap | line |
|---|---|---|
| own_damage | 13,005 | motor |
| glass_hail | 5,873 | motor |
| third_party_prop | 19,750 | motor |
| bodily_injury | 187,516 | motor |
| theft | 38,460 | motor |
| storm | 19,764 | buildings |
| subsidence | 138,263 | buildings |
| accidental_damage | 6,561 | buildings |
| flood | 208,045 | buildings |
| escape_of_water | 34,856 | buildings |
| fire | 369,277 | buildings |
| accidental_damage | 4,821 | contents |
| flood | 60,320 | contents |
| escape_of_water | 16,953 | contents |
| theft | 23,478 | contents |

## XGBoost tuning (2021-22, 20% policy holdout; top 5 per line)

| line | config | max_depth | learning_rate | min_child_weight | subsample | colsample_bytree | reg_lambda | tweedie_variance_power | holdout_d2 | rounds | seconds | rank |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | 29 | 3 | 0.0500 | 500 | 0.7000 | 0.6000 | 5 | 1.7000 | 0.0562 | 232 | 18 | 1 |
| motor | 26 | 3 | 0.0500 | 500 | 0.7000 | 0.7000 | 1 | 1.7000 | 0.0561 | 262 | 9 | 2 |
| motor | 14 | 3 | 0.0500 | 50 | 0.7000 | 0.8000 | 5 | 1.7000 | 0.0559 | 262 | 8 | 3 |
| motor | 35 | 3 | 0.0300 | 200 | 0.7000 | 0.6000 | 1 | 1.5000 | 0.0557 | 438 | 12 | 4 |
| motor | 19 | 3 | 0.0300 | 200 | 0.7000 | 0.7000 | 1 | 1.7000 | 0.0556 | 342 | 10 | 5 |
| buildings | 25 | 3 | 0.0300 | 200 | 0.8000 | 0.7000 | 10 | 1.5000 | 0.0844 | 239 | 5 | 1 |
| buildings | 15 | 4 | 0.0300 | 500 | 0.8000 | 0.6000 | 1 | 1.3000 | 0.0843 | 239 | 15 | 2 |
| buildings | 37 | 3 | 0.0300 | 50 | 0.9000 | 0.8000 | 10 | 1.3000 | 0.0841 | 250 | 6 | 3 |
| buildings | 12 | 3 | 0.0500 | 200 | 0.7000 | 0.7000 | 5 | 1.3000 | 0.0840 | 185 | 12 | 4 |
| buildings | 10 | 3 | 0.0300 | 200 | 0.7000 | 0.6000 | 10 | 1.3000 | 0.0837 | 260 | 11 | 5 |
| contents | 3 | 3 | 0.0500 | 500 | 0.7000 | 0.7000 | 1 | 1.5000 | 0.0593 | 181 | 12 | 1 |
| contents | 11 | 3 | 0.0300 | 500 | 0.8000 | 0.6000 | 5 | 1.5000 | 0.0583 | 277 | 17 | 2 |
| contents | 12 | 5 | 0.0500 | 50 | 0.9000 | 0.8000 | 1 | 1.3000 | 0.0582 | 101 | 10 | 3 |
| contents | 21 | 3 | 0.0500 | 50 | 0.7000 | 0.8000 | 1 | 1.3000 | 0.0580 | 192 | 13 | 4 |
| contents | 19 | 3 | 0.0300 | 500 | 0.8000 | 0.7000 | 5 | 1.3000 | 0.0580 | 320 | 19 | 5 |

## Validation - local Kaggle metric (Tweedie D2, p = 1.5)
`d2` = raw (exposure-rate baseline, as Kaggle is believed to score), `d2_flat` = flat-mean baseline, `d2_cal` = after rescaling predictions to the actual total (ranking only), `ae_developed` = predicted / IBNR-developed actual (level). 2024 actuals are immature.

### Combined, all lines
| model | d2_2022 | d2_2023 | d2_2024 | d2_flat_2022 | d2_flat_2023 | d2_flat_2024 | ae_developed_2022 | ae_developed_2023 | ae_developed_2024 |
|---|---|---|---|---|---|---|---|---|---|
| legacy_glm | 0.1054 | 0.1059 | 0.0950 | 0.1383 | 0.1416 | 0.1268 | 0.9911 | 0.9482 | 0.9772 |
| blend | 0.1145 | 0.1043 | 0.0986 | 0.1470 | 0.1400 | 0.1303 | 0.9686 | 0.9608 | 1.0328 |
| peril_glm_notrend | 0.1108 | 0.1032 | 0.0957 | 0.1434 | 0.1390 | 0.1274 | 0.9701 | 0.9425 | 0.9819 |
| peril_glm | 0.1108 | 0.1030 | 0.0946 | 0.1434 | 0.1388 | 0.1264 | 0.9701 | 0.9619 | 1.0329 |
| legacy_xgb | 0.1035 | 0.1017 | 0.0983 | 0.1364 | 0.1375 | 0.1299 | 0.8694 | 0.8593 | 0.9249 |
| peril_xgb | 0.1145 | 0.1007 | 0.0984 | 0.1470 | 0.1365 | 0.1300 | 0.9675 | 0.9607 | 1.0332 |
| xgb_tweedie | 0.1074 | 0.1007 | 0.0968 | 0.1401 | 0.1365 | 0.1286 | 0.9701 | 0.9619 | 1.0329 |
| peril_lgb | 0.1086 | 0.0929 | 0.0942 | 0.1413 | 0.1290 | 0.1260 | 0.9677 | 0.9602 | 1.0321 |
| lgb_tweedie | 0.0992 | 0.0899 | 0.0910 | 0.1323 | 0.1262 | 0.1229 | 0.9701 | 0.9619 | 1.0329 |
| burn_trend | 0.0553 | 0.0492 | 0.0352 | 0.0899 | 0.0871 | 0.0691 | 0.9713 | 0.9746 | 1.0448 |
| burn_cost | 0.0553 | 0.0488 | 0.0371 | 0.0899 | 0.0867 | 0.0709 | 0.9712 | 0.9302 | 0.9602 |

### Mean over folds by line
| line | model | d2 | d2_cal | d2_flat | ae_developed |
|---|---|---|---|---|---|
| buildings | blend | 0.0708 | 0.0710 | 0.1073 | 0.9633 |
| buildings | peril_xgb | 0.0703 | 0.0705 | 0.1068 | 0.9620 |
| buildings | legacy_xgb | 0.0664 | 0.0675 | 0.1031 | 0.8736 |
| buildings | peril_glm | 0.0670 | 0.0672 | 0.1036 | 0.9663 |
| buildings | peril_glm_notrend | 0.0670 | 0.0672 | 0.1037 | 0.9278 |
| buildings | peril_lgb | 0.0668 | 0.0669 | 0.1035 | 0.9613 |
| buildings | xgb_tweedie | 0.0664 | 0.0666 | 0.1031 | 0.9663 |
| buildings | lgb_tweedie | 0.0621 | 0.0623 | 0.0989 | 0.9663 |
| buildings | legacy_glm | 0.0597 | 0.0595 | 0.0967 | 0.9802 |
| buildings | burn_trend | -0.0002 | 0 | 0.0392 | 0.9485 |
| buildings | burn_cost | -0.0008 | 0 | 0.0386 | 0.8953 |
| contents | blend | 0.0663 | 0.0667 | 0.0971 | 0.9818 |
| contents | peril_xgb | 0.0648 | 0.0651 | 0.0956 | 0.9815 |
| contents | xgb_tweedie | 0.0628 | 0.0633 | 0.0937 | 0.9820 |
| contents | peril_glm_notrend | 0.0626 | 0.0632 | 0.0935 | 0.9556 |
| contents | peril_glm | 0.0628 | 0.0631 | 0.0936 | 0.9820 |
| contents | peril_lgb | 0.0622 | 0.0625 | 0.0931 | 0.9814 |
| contents | legacy_glm | 0.0598 | 0.0605 | 0.0907 | 0.9509 |
| contents | legacy_xgb | 0.0570 | 0.0590 | 0.0881 | 0.9061 |
| contents | lgb_tweedie | 0.0569 | 0.0573 | 0.0879 | 0.9820 |
| contents | burn_trend | -0.0007 | 0 | 0.0322 | 0.9704 |
| contents | burn_cost | -0.0010 | 0 | 0.0319 | 0.9375 |
| motor | legacy_glm | 0.0519 | 0.0538 | 0.0889 | 0.9747 |
| motor | blend | 0.0496 | 0.0535 | 0.0867 | 1.0060 |
| motor | peril_xgb | 0.0477 | 0.0516 | 0.0849 | 1.0063 |
| motor | peril_glm_notrend | 0.0480 | 0.0505 | 0.0852 | 0.9914 |
| motor | peril_glm | 0.0470 | 0.0505 | 0.0843 | 1.0057 |
| motor | legacy_xgb | 0.0460 | 0.0496 | 0.0833 | 0.8907 |
| motor | xgb_tweedie | 0.0449 | 0.0487 | 0.0822 | 1.0057 |
| motor | peril_lgb | 0.0381 | 0.0422 | 0.0757 | 1.0059 |
| motor | lgb_tweedie | 0.0320 | 0.0359 | 0.0699 | 1.0057 |
| motor | burn_cost | -0.0026 | 0 | 0.0366 | 0.9945 |
| motor | burn_trend | -0.0044 | 0 | 0.0348 | 1.0329 |

### Raw D2 by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.0662 | 0.0714 | 0.0748 |
| buildings | burn_cost | -0.0004 | -0.0009 | -0.0010 |
| buildings | burn_trend | -0.0004 | 0.0000 | -0.0001 |
| buildings | legacy_glm | 0.0483 | 0.0622 | 0.0687 |
| buildings | legacy_xgb | 0.0564 | 0.0699 | 0.0730 |
| buildings | lgb_tweedie | 0.0582 | 0.0613 | 0.0666 |
| buildings | peril_glm | 0.0627 | 0.0685 | 0.0697 |
| buildings | peril_glm_notrend | 0.0627 | 0.0685 | 0.0698 |
| buildings | peril_lgb | 0.0634 | 0.0660 | 0.0710 |
| buildings | peril_xgb | 0.0653 | 0.0708 | 0.0748 |
| buildings | xgb_tweedie | 0.0602 | 0.0663 | 0.0726 |
| contents | blend | 0.0638 | 0.0710 | 0.0642 |
| contents | burn_cost | 0.0000 | -0.0022 | -0.0009 |
| contents | burn_trend | 0.0000 | -0.0021 | -0.0001 |
| contents | legacy_glm | 0.0555 | 0.0631 | 0.0608 |
| contents | legacy_xgb | 0.0511 | 0.0611 | 0.0589 |
| contents | lgb_tweedie | 0.0519 | 0.0613 | 0.0574 |
| contents | peril_glm | 0.0585 | 0.0679 | 0.0620 |
| contents | peril_glm_notrend | 0.0585 | 0.0678 | 0.0616 |
| contents | peril_lgb | 0.0609 | 0.0671 | 0.0586 |
| contents | peril_xgb | 0.0627 | 0.0697 | 0.0619 |
| contents | xgb_tweedie | 0.0609 | 0.0659 | 0.0618 |
| motor | blend | 0.0595 | 0.0428 | 0.0465 |
| motor | burn_cost | -0.0001 | -0.0002 | -0.0075 |
| motor | burn_trend | -0.0001 | -0.0000 | -0.0131 |
| motor | legacy_glm | 0.0553 | 0.0557 | 0.0446 |
| motor | legacy_xgb | 0.0468 | 0.0417 | 0.0495 |
| motor | lgb_tweedie | 0.0359 | 0.0219 | 0.0383 |
| motor | peril_glm | 0.0557 | 0.0431 | 0.0422 |
| motor | peril_glm_notrend | 0.0557 | 0.0436 | 0.0448 |
| motor | peril_lgb | 0.0496 | 0.0229 | 0.0419 |
| motor | peril_xgb | 0.0605 | 0.0357 | 0.0469 |
| motor | xgb_tweedie | 0.0491 | 0.0403 | 0.0452 |

### Calibrated D2 by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.0664 | 0.0714 | 0.0752 |
| buildings | burn_cost | 0 | 0 | 0 |
| buildings | burn_trend | 0 | 0 | 0 |
| buildings | legacy_glm | 0.0474 | 0.0624 | 0.0687 |
| buildings | legacy_xgb | 0.0589 | 0.0702 | 0.0732 |
| buildings | lgb_tweedie | 0.0583 | 0.0614 | 0.0671 |
| buildings | peril_glm | 0.0631 | 0.0685 | 0.0700 |
| buildings | peril_glm_notrend | 0.0631 | 0.0686 | 0.0698 |
| buildings | peril_lgb | 0.0636 | 0.0660 | 0.0712 |
| buildings | peril_xgb | 0.0655 | 0.0708 | 0.0752 |
| buildings | xgb_tweedie | 0.0603 | 0.0663 | 0.0730 |
| contents | blend | 0.0638 | 0.0719 | 0.0642 |
| contents | burn_cost | 0 | 0 | 0 |
| contents | burn_trend | 0 | 0 | 0 |
| contents | legacy_glm | 0.0554 | 0.0647 | 0.0614 |
| contents | legacy_xgb | 0.0533 | 0.0643 | 0.0594 |
| contents | lgb_tweedie | 0.0520 | 0.0623 | 0.0575 |
| contents | peril_glm | 0.0584 | 0.0691 | 0.0619 |
| contents | peril_glm_notrend | 0.0584 | 0.0693 | 0.0620 |
| contents | peril_lgb | 0.0609 | 0.0680 | 0.0585 |
| contents | peril_xgb | 0.0627 | 0.0708 | 0.0618 |
| contents | xgb_tweedie | 0.0609 | 0.0671 | 0.0617 |
| motor | blend | 0.0594 | 0.0431 | 0.0579 |
| motor | burn_cost | 0 | 0 | 0 |
| motor | burn_trend | 0 | 0 | 0 |
| motor | legacy_glm | 0.0556 | 0.0560 | 0.0499 |
| motor | legacy_xgb | 0.0507 | 0.0457 | 0.0525 |
| motor | lgb_tweedie | 0.0359 | 0.0223 | 0.0496 |
| motor | peril_glm | 0.0559 | 0.0435 | 0.0522 |
| motor | peril_glm_notrend | 0.0559 | 0.0439 | 0.0518 |
| motor | peril_lgb | 0.0496 | 0.0232 | 0.0538 |
| motor | peril_xgb | 0.0605 | 0.0361 | 0.0583 |
| motor | xgb_tweedie | 0.0492 | 0.0407 | 0.0563 |

### Level: predicted / developed actual by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.958 | 0.995 | 0.937 |
| buildings | burn_cost | 0.952 | 0.908 | 0.825 |
| buildings | burn_trend | 0.952 | 0.971 | 0.922 |
| buildings | legacy_glm | 1.049 | 0.978 | 0.913 |
| buildings | legacy_xgb | 0.868 | 0.899 | 0.853 |
| buildings | lgb_tweedie | 0.962 | 0.999 | 0.938 |
| buildings | peril_glm | 0.962 | 0.999 | 0.938 |
| buildings | peril_glm_notrend | 0.962 | 0.944 | 0.878 |
| buildings | peril_lgb | 0.956 | 0.993 | 0.935 |
| buildings | peril_xgb | 0.956 | 0.993 | 0.936 |
| buildings | xgb_tweedie | 0.962 | 0.999 | 0.938 |
| contents | blend | 1.009 | 0.923 | 1.014 |
| contents | burn_cost | 1.000 | 0.900 | 0.913 |
| contents | burn_trend | 1.000 | 0.903 | 1.009 |
| contents | legacy_glm | 1.009 | 0.917 | 0.927 |
| contents | legacy_xgb | 0.910 | 0.876 | 0.933 |
| contents | lgb_tweedie | 1.008 | 0.923 | 1.015 |
| contents | peril_glm | 1.008 | 0.923 | 1.015 |
| contents | peril_glm_notrend | 1.008 | 0.919 | 0.939 |
| contents | peril_lgb | 1.008 | 0.923 | 1.013 |
| contents | peril_xgb | 1.009 | 0.922 | 1.014 |
| contents | xgb_tweedie | 1.008 | 0.923 | 1.015 |
| motor | blend | 0.969 | 0.948 | 1.101 |
| motor | burn_cost | 0.977 | 0.947 | 1.060 |
| motor | burn_trend | 0.977 | 0.987 | 1.134 |
| motor | legacy_glm | 0.958 | 0.936 | 1.029 |
| motor | legacy_xgb | 0.864 | 0.835 | 0.972 |
| motor | lgb_tweedie | 0.969 | 0.947 | 1.101 |
| motor | peril_glm | 0.969 | 0.947 | 1.101 |
| motor | peril_glm_notrend | 0.969 | 0.945 | 1.060 |
| motor | peril_lgb | 0.968 | 0.948 | 1.101 |
| motor | peril_xgb | 0.968 | 0.949 | 1.102 |
| motor | xgb_tweedie | 0.969 | 0.947 | 1.101 |

### Trend vs no trend (per-peril GLM)
| line | model | d2_2022 | d2_2023 | d2_2024 | ae_developed_2022 | ae_developed_2023 | ae_developed_2024 |
|---|---|---|---|---|---|---|---|
| buildings | peril_glm | 0.0627 | 0.0685 | 0.0697 | 0.9616 | 0.9992 | 0.9380 |
| buildings | peril_glm_notrend | 0.0627 | 0.0685 | 0.0698 | 0.9616 | 0.9438 | 0.8779 |
| contents | peril_glm | 0.0585 | 0.0679 | 0.0620 | 1.0085 | 0.9229 | 1.0147 |
| contents | peril_glm_notrend | 0.0585 | 0.0678 | 0.0616 | 1.0085 | 0.9193 | 0.9392 |
| motor | peril_glm | 0.0557 | 0.0431 | 0.0422 | 0.9693 | 0.9474 | 1.1005 |
| motor | peril_glm_notrend | 0.0557 | 0.0436 | 0.0448 | 0.9693 | 0.9452 | 1.0597 |

### Overfitting check: calibrated D2 on training rows vs validation year
| valid_year | line | model | d2_cal_train | d2_cal_valid | gap |
|---|---|---|---|---|---|
| 2022 | buildings | lgb_tweedie | 0.1537 | 0.0583 | 0.0954 |
| 2023 | buildings | lgb_tweedie | 0.1075 | 0.0614 | 0.0461 |
| 2024 | buildings | lgb_tweedie | 0.1116 | 0.0671 | 0.0445 |
| 2022 | buildings | peril_glm | 0.0780 | 0.0631 | 0.0149 |
| 2023 | buildings | peril_glm | 0.0767 | 0.0685 | 0.0082 |
| 2024 | buildings | peril_glm | 0.0775 | 0.0700 | 0.0074 |
| 2022 | buildings | peril_lgb | 0.1239 | 0.0636 | 0.0603 |
| 2023 | buildings | peril_lgb | 0.1202 | 0.0660 | 0.0542 |
| 2024 | buildings | peril_lgb | 0.1155 | 0.0712 | 0.0443 |
| 2022 | buildings | peril_xgb | 0.1020 | 0.0655 | 0.0365 |
| 2023 | buildings | peril_xgb | 0.0938 | 0.0708 | 0.0230 |
| 2024 | buildings | peril_xgb | 0.0905 | 0.0752 | 0.0153 |
| 2022 | buildings | xgb_tweedie | 0.1130 | 0.0603 | 0.0527 |
| 2023 | buildings | xgb_tweedie | 0.0838 | 0.0663 | 0.0174 |
| 2024 | buildings | xgb_tweedie | 0.1070 | 0.0730 | 0.0340 |
| 2022 | contents | lgb_tweedie | 0.1083 | 0.0520 | 0.0562 |
| 2023 | contents | lgb_tweedie | 0.1206 | 0.0623 | 0.0584 |
| 2024 | contents | lgb_tweedie | 0.1280 | 0.0575 | 0.0705 |
| 2022 | contents | peril_glm | 0.0877 | 0.0584 | 0.0293 |
| 2023 | contents | peril_glm | 0.0679 | 0.0691 | -0.0013 |
| 2024 | contents | peril_glm | 0.0769 | 0.0619 | 0.0150 |
| 2022 | contents | peril_lgb | 0.1520 | 0.0609 | 0.0911 |
| 2023 | contents | peril_lgb | 0.0971 | 0.0680 | 0.0290 |
| 2024 | contents | peril_lgb | 0.1034 | 0.0585 | 0.0450 |
| 2022 | contents | peril_xgb | 0.1047 | 0.0627 | 0.0419 |
| 2023 | contents | peril_xgb | 0.0894 | 0.0708 | 0.0186 |
| 2024 | contents | peril_xgb | 0.0922 | 0.0618 | 0.0304 |
| 2022 | contents | xgb_tweedie | 0.1145 | 0.0609 | 0.0536 |
| 2023 | contents | xgb_tweedie | 0.1038 | 0.0671 | 0.0368 |
| 2024 | contents | xgb_tweedie | 0.1129 | 0.0617 | 0.0512 |
| 2022 | motor | lgb_tweedie | 0.0753 | 0.0359 | 0.0394 |
| 2023 | motor | lgb_tweedie | 0.1099 | 0.0223 | 0.0876 |
| 2024 | motor | lgb_tweedie | 0.1203 | 0.0496 | 0.0707 |
| 2022 | motor | peril_glm | 0.0533 | 0.0559 | -0.0026 |
| 2023 | motor | peril_glm | 0.0583 | 0.0435 | 0.0148 |
| 2024 | motor | peril_glm | 0.0521 | 0.0522 | -0.0001 |
| 2022 | motor | peril_lgb | 0.0827 | 0.0496 | 0.0332 |
| 2023 | motor | peril_lgb | 0.0718 | 0.0232 | 0.0486 |
| 2024 | motor | peril_lgb | 0.0492 | 0.0538 | -0.0045 |
| 2022 | motor | peril_xgb | 0.0734 | 0.0605 | 0.0129 |
| 2023 | motor | peril_xgb | 0.0757 | 0.0361 | 0.0396 |
| 2024 | motor | peril_xgb | 0.0567 | 0.0583 | -0.0016 |
| 2022 | motor | xgb_tweedie | 0.0820 | 0.0492 | 0.0328 |
| 2023 | motor | xgb_tweedie | 0.0902 | 0.0407 | 0.0495 |
| 2024 | motor | xgb_tweedie | 0.0915 | 0.0563 | 0.0353 |

### Segment A/E of the blend (level removed per line; 1 = right relative price)
| line | segment | level | exposure | ae_2023 | ae_2024 |
|---|---|---|---|---|---|
| buildings | hist_pol_n | 0 | 278,461.014 | 0.969 | 0.967 |
| buildings | hist_pol_n | 1 | 19,745.315 | 1.277 | 1.216 |
| buildings | hist_pol_n | 2 | 1,540.868 | 1.761 | 1.389 |
| buildings | hist_pol_n | 3 | 157.622 | 2.087 | 1.394 |
| buildings | new_business | FALSE | 272,802.258 | 1.008 | 0.992 |
| buildings | new_business | TRUE | 27,102.562 | 0.919 | 1.082 |
| contents | hist_pol_n | 0 | 280,343.293 | 0.967 | 0.989 |
| contents | hist_pol_n | 1 | 18,140.847 | 1.367 | 1.091 |
| contents | hist_pol_n | 2 | 1,350.901 | 1.593 | 0.863 |
| contents | hist_pol_n | 3 | 106.671 | 0.149 | 2.200 |
| contents | new_business | FALSE | 272,872.805 | 0.990 | 1.009 |
| contents | new_business | TRUE | 27,068.907 | 1.101 | 0.914 |
| motor | driver_age | [0,25) | 53,987.041 | 0.825 | 0.922 |
| motor | driver_age | [25,35) | 73,253.537 | 1.516 | 1.013 |
| motor | driver_age | [35,50) | 73,266.926 | 0.903 | 1.015 |
| motor | driver_age | [50,65) | 73,917.564 | 0.910 | 1.021 |
| motor | driver_age | [65,Inf) | 125,042.414 | 0.925 | 1.047 |
| motor | hist_pol_n | 0 | 322,217.088 | 1.030 | 0.971 |
| motor | hist_pol_n | 1 | 59,976.984 | 0.845 | 1.055 |
| motor | hist_pol_n | 2 | 12,763.726 | 1.006 | 0.947 |
| motor | hist_pol_n | 3 | 4,509.685 | 1.349 | 1.358 |
| motor | ncb_years | (-Inf,0] | 17,642.841 | 0.982 | 1.083 |
| motor | ncb_years | (0,3] | 92,279.929 | 0.853 | 0.925 |
| motor | ncb_years | (3,6] | 72,292.312 | 1.546 | 1.025 |
| motor | ncb_years | (6,9] | 60,441.992 | 0.914 | 1.031 |
| motor | ncb_years | (9, Inf] | 156,810.408 | 0.917 | 1.034 |
| motor | new_business | FALSE | 363,280.252 | 1.007 | 1.004 |
| motor | new_business | TRUE | 36,187.230 | 0.952 | 0.973 |
| motor | vehicle_age | (-Inf,3] | 28,076.293 | 0.950 | 1.073 |
| motor | vehicle_age | (12, Inf] | 64,911.699 | 0.821 | 0.862 |
| motor | vehicle_age | (3,7] | 153,642.485 | 1.154 | 1.050 |
| motor | vehicle_age | (7,12] | 142,880.718 | 0.915 | 1.010 |

## Blend weights
| line | lgb_tweedie | peril_glm | peril_lgb | peril_xgb | xgb_tweedie |
|---|---|---|---|---|---|
| buildings | 0 | 0.20 | 0 | 0.70 | 0.10 |
| contents | 0 | 0.30 | 0 | 0.40 | 0.30 |
| motor | 0 | 0.40 | 0 | 0.40 | 0.20 |

## 2025 test predictions (final fit on 2021-24)
| line | model | weight | predicted_total | predicted_burn_cost | p50_row | p90_row | p99_row | max_row |
|---|---|---|---|---|---|---|---|---|
| motor | peril_glm | 0.40 | 120,521,674.46 | 602.66 | 374.41 | 927.37 | 2,064.39 | 6,885.33 |
| motor | peril_lgb | 0 | 120,721,704.21 | 603.66 | 405.22 | 863.25 | 1,919.30 | 10,202.34 |
| motor | peril_xgb | 0.40 | 120,823,605.58 | 604.17 | 392.21 | 890.46 | 1,992.41 | 8,630.99 |
| motor | lgb_tweedie | 0 | 120,521,674.46 | 602.66 | 395.73 | 895.50 | 1,899.87 | 10,931.36 |
| motor | xgb_tweedie | 0.20 | 120,521,674.46 | 602.66 | 382.39 | 914.79 | 2,016.89 | 7,207.39 |
| motor | burn_trend |  | 125,424,352.36 | 627.17 | 627.17 | 627.17 | 627.17 | 627.17 |
| motor | burn_cost |  | 108,930,584.85 | 544.70 | 544.70 | 544.70 | 544.70 | 544.70 |
| motor | blend | 1 | 120,642,446.91 | 603.26 | 386.27 | 908.47 | 1,978.88 | 7,277.96 |
| buildings | peril_glm | 0.20 | 73,320,572.91 | 488.01 | 318.95 | 702.03 | 2,079.89 | 8,536.26 |
| buildings | peril_lgb | 0 | 73,031,660.40 | 486.09 | 318.77 | 683.23 | 2,162.42 | 25,624.22 |
| buildings | peril_xgb | 0.70 | 73,198,075.29 | 487.19 | 310.51 | 717.58 | 2,134.25 | 13,070.16 |
| buildings | lgb_tweedie | 0 | 73,320,572.91 | 488.01 | 315.09 | 712.32 | 2,132.01 | 7,371.56 |
| buildings | xgb_tweedie | 0.10 | 73,320,572.91 | 488.01 | 308.26 | 721.84 | 2,193.37 | 12,213.49 |
| buildings | burn_trend |  | 75,278,105.10 | 501.04 | 501.04 | 501.04 | 501.04 | 501.04 |
| buildings | burn_cost |  | 62,751,650.57 | 417.67 | 417.67 | 417.67 | 417.67 | 417.67 |
| buildings | blend | 1 | 73,234,824.58 | 487.44 | 313.62 | 710.93 | 2,116.15 | 11,207.40 |
| contents | peril_glm | 0.30 | 18,817,401.77 | 125.35 | 77.19 | 187.54 | 519.14 | 3,807.78 |
| contents | peril_lgb | 0 | 18,751,969.82 | 124.91 | 78.40 | 179.70 | 531.28 | 5,667.13 |
| contents | peril_xgb | 0.40 | 18,749,975.76 | 124.90 | 78.22 | 181.34 | 527.98 | 3,535.03 |
| contents | lgb_tweedie | 0 | 18,817,401.77 | 125.35 | 79.61 | 185.97 | 492.05 | 3,215.88 |
| contents | xgb_tweedie | 0.30 | 18,817,401.77 | 125.35 | 78.78 | 184.89 | 500.30 | 3,946.18 |
| contents | burn_trend |  | 18,868,753.35 | 125.69 | 125.69 | 125.69 | 125.69 | 125.69 |
| contents | burn_cost |  | 16,702,409.98 | 111.26 | 111.26 | 111.26 | 111.26 | 111.26 |
| contents | blend | 1 | 18,790,431.37 | 125.17 | 78.47 | 183.72 | 511.57 | 2,983.74 |

### Level vs previous submissions
| submission | motor | buildings | contents | public_d2 |
|---|---|---|---|---|
| #1 iteration_01 | 518.12 | 425.08 | 113.20 | 0.12 |
| #2 iteration_02 | 498.80 | 434.25 | 119.13 | 0.12 |
| #3 sam_iteration_01 | 518.12 | 411.79 | 111.80 | 0.12 |
| this run (sam_iteration_03) | 603.26 | 487.44 | 125.17 |  |

## Variable importance (line Tweedie bags)
![](tree_importance.png)

Rank of the random noise feature:

| line | model | noise_rank |
|---|---|---|
| motor | lgb_tweedie | 50 |
| motor | xgb_tweedie | 36 |
| buildings | lgb_tweedie | 32 |
| buildings | xgb_tweedie | 23 |
| contents | lgb_tweedie | 31 |
| contents | xgb_tweedie | 32 |

| Feature | Gain | rank | line | model |
|---|---|---|---|---|
| flood_score | 0.2006 | 1 | buildings | lgb_tweedie |
| previous_insurer | 0.1821 | 2 | buildings | lgb_tweedie |
| sum_insured | 0.0808 | 3 | buildings | lgb_tweedie |
| occupation | 0.0732 | 4 | buildings | lgb_tweedie |
| elevation_m | 0.0646 | 5 | buildings | lgb_tweedie |
| flood_zone | 0.0627 | 6 | buildings | lgb_tweedie |
| energy_rating | 0.0335 | 7 | buildings | lgb_tweedie |
| log_sum_insured | 0.0331 | 8 | buildings | lgb_tweedie |
| region | 0.0275 | 9 | buildings | lgb_tweedie |
| property_age | 0.0253 | 10 | buildings | lgb_tweedie |
| prior_claims_5y | 0.0180 | 11 | buildings | lgb_tweedie |
| year_built | 0.0159 | 12 | buildings | lgb_tweedie |
| distance_to_river_km | 0.0151 | 13 | buildings | lgb_tweedie |
| soil_type | 0.0136 | 14 | buildings | lgb_tweedie |
| construction_type | 0.0121 | 15 | buildings | lgb_tweedie |
| flood_score | 0.2364 | 1 | buildings | xgb_tweedie |
| sum_insured | 0.1028 | 2 | buildings | xgb_tweedie |
| flood_zone | 0.0816 | 3 | buildings | xgb_tweedie |
| elevation_m | 0.0804 | 4 | buildings | xgb_tweedie |
| log_sum_insured | 0.0397 | 5 | buildings | xgb_tweedie |
| energy_rating | 0.0327 | 6 | buildings | xgb_tweedie |
| property_age | 0.0277 | 7 | buildings | xgb_tweedie |
| prior_claims_5y | 0.0275 | 8 | buildings | xgb_tweedie |
| distance_to_river_km | 0.0229 | 9 | buildings | xgb_tweedie |
| dry_summer_index | 0.0207 | 10 | buildings | xgb_tweedie |
| year_built | 0.0177 | 11 | buildings | xgb_tweedie |
| previous_insurer | 0.0163 | 12 | buildings | xgb_tweedie |
| soil_type | 0.0158 | 13 | buildings | xgb_tweedie |
| construction_type | 0.0143 | 14 | buildings | xgb_tweedie |
| missed_payments_12m | 0.0126 | 15 | buildings | xgb_tweedie |
| flood_score | 0.1843 | 1 | contents | lgb_tweedie |
| previous_insurer | 0.1807 | 2 | contents | lgb_tweedie |
| sum_insured | 0.1307 | 3 | contents | lgb_tweedie |
| occupation | 0.0757 | 4 | contents | lgb_tweedie |
| flood_zone | 0.0671 | 5 | contents | lgb_tweedie |
| elevation_m | 0.0479 | 6 | contents | lgb_tweedie |
| region | 0.0472 | 7 | contents | lgb_tweedie |
| log_sum_insured | 0.0205 | 8 | contents | lgb_tweedie |
| prior_claims_5y | 0.0199 | 9 | contents | lgb_tweedie |
| voluntary_excess | 0.0198 | 10 | contents | lgb_tweedie |
| customer_age | 0.0182 | 11 | contents | lgb_tweedie |
| urban_density | 0.0175 | 12 | contents | lgb_tweedie |
| distance_to_river_km | 0.0135 | 13 | contents | lgb_tweedie |
| accidental_damage_cover | 0.0128 | 14 | contents | lgb_tweedie |
| policyholder_age | 0.0111 | 15 | contents | lgb_tweedie |
| flood_score | 0.1955 | 1 | contents | xgb_tweedie |
| sum_insured | 0.1503 | 2 | contents | xgb_tweedie |
| flood_zone | 0.1040 | 3 | contents | xgb_tweedie |
| elevation_m | 0.0760 | 4 | contents | xgb_tweedie |
| log_sum_insured | 0.0405 | 5 | contents | xgb_tweedie |
| region | 0.0283 | 6 | contents | xgb_tweedie |
| urban_density | 0.0248 | 7 | contents | xgb_tweedie |
| voluntary_excess | 0.0242 | 8 | contents | xgb_tweedie |
| customer_age | 0.0239 | 9 | contents | xgb_tweedie |
| prior_claims_5y | 0.0238 | 10 | contents | xgb_tweedie |
| si_per_person | 0.0231 | 11 | contents | xgb_tweedie |
| policyholder_age | 0.0202 | 12 | contents | xgb_tweedie |
| distance_to_river_km | 0.0196 | 13 | contents | xgb_tweedie |
| accidental_damage_cover | 0.0156 | 14 | contents | xgb_tweedie |
| previous_insurer | 0.0134 | 15 | contents | xgb_tweedie |
| make_model | 0.4341 | 1 | motor | lgb_tweedie |
| ncb_years | 0.1390 | 2 | motor | lgb_tweedie |
| previous_insurer | 0.0795 | 3 | motor | lgb_tweedie |
| customer_age | 0.0582 | 4 | motor | lgb_tweedie |
| annual_mileage | 0.0389 | 5 | motor | lgb_tweedie |
| years_licensed | 0.0310 | 6 | motor | lgb_tweedie |
| driver_age | 0.0304 | 7 | motor | lgb_tweedie |
| hist_pol_rel | 0.0271 | 8 | motor | lgb_tweedie |
| occupation | 0.0211 | 9 | motor | lgb_tweedie |
| prior_claims_5y | 0.0175 | 10 | motor | lgb_tweedie |
| cover_type | 0.0172 | 11 | motor | lgb_tweedie |
| region | 0.0153 | 12 | motor | lgb_tweedie |
| voluntary_excess | 0.0132 | 13 | motor | lgb_tweedie |
| vehicle_age | 0.0109 | 14 | motor | lgb_tweedie |
| hist_pol_cost | 0.0091 | 15 | motor | lgb_tweedie |
| ncb_years | 0.2259 | 1 | motor | xgb_tweedie |
| annual_mileage | 0.0646 | 2 | motor | xgb_tweedie |
| make_model | 0.0610 | 3 | motor | xgb_tweedie |
| customer_age | 0.0594 | 4 | motor | xgb_tweedie |
| years_licensed | 0.0587 | 5 | motor | xgb_tweedie |
| driver_age | 0.0425 | 6 | motor | xgb_tweedie |
| hist_pol_rel | 0.0408 | 7 | motor | xgb_tweedie |
| prior_claims_5y | 0.0318 | 8 | motor | xgb_tweedie |
| cover_type | 0.0306 | 9 | motor | xgb_tweedie |
| vehicle_age | 0.0264 | 10 | motor | xgb_tweedie |
| voluntary_excess | 0.0239 | 11 | motor | xgb_tweedie |
| region | 0.0232 | 12 | motor | xgb_tweedie |
| urban_density | 0.0195 | 13 | motor | xgb_tweedie |
| novice_driver | 0.0161 | 14 | motor | xgb_tweedie |
| telematics_score | 0.0155 | 15 | motor | xgb_tweedie |

## Boosting rounds (final fit, early-stopping member)
| line | model | rounds |
|---|---|---|
| motor | peril_lgb.own_damage | 514 |
| motor | peril_lgb.third_party_prop | 266 |
| motor | peril_lgb.bodily_injury | 297 |
| motor | peril_lgb.theft | 263 |
| motor | peril_lgb.glass_hail | 276 |
| motor | lgb_tweedie | 173 |
| motor | peril_xgb.own_damage | 1,073 |
| motor | peril_xgb.third_party_prop | 580 |
| motor | peril_xgb.bodily_injury | 393 |
| motor | peril_xgb.theft | 693 |
| motor | peril_xgb.glass_hail | 472 |
| motor | xgb_tweedie | 334 |
| buildings | peril_lgb.storm | 425 |
| buildings | peril_lgb.flood | 245 |
| buildings | peril_lgb.escape_of_water | 266 |
| buildings | peril_lgb.subsidence | 95 |
| buildings | peril_lgb.fire | 59 |
| buildings | peril_lgb.accidental_damage | 132 |
| buildings | lgb_tweedie | 108 |
| buildings | peril_xgb.storm | 1,210 |
| buildings | peril_xgb.flood | 482 |
| buildings | peril_xgb.escape_of_water | 713 |
| buildings | peril_xgb.subsidence | 422 |
| buildings | peril_xgb.fire | 380 |
| buildings | peril_xgb.accidental_damage | 530 |
| buildings | xgb_tweedie | 327 |
| contents | peril_lgb.theft | 232 |
| contents | peril_lgb.escape_of_water | 177 |
| contents | peril_lgb.accidental_damage | 264 |
| contents | peril_lgb.flood | 296 |
| contents | lgb_tweedie | 162 |
| contents | peril_xgb.theft | 291 |
| contents | peril_xgb.escape_of_water | 232 |
| contents | peril_xgb.accidental_damage | 436 |
| contents | peril_xgb.flood | 403 |
| contents | xgb_tweedie | 221 |

## Features used
| line | model | features |
|---|---|---|
| motor | tree models | driver_age, years_licensed, ncb_years, vehicle_value_group, vehicle_age, make_model, engine_size_cc, body_type, transmission, seats, fuel_type, driver_assist, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, telematics_opt_in, telematics_score, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, previous_insurer, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer, noise_probe, young_driver, novice_driver, licence_ratio, telematics_missing, hist_pol_n, hist_pol_cost, hist_pol_exp, hist_cust_other_n, hist_addr_flood, hist_addr_water, hist_addr_subs, hist_addr_storm, hist_pol_rel |
| motor | glm_freq.own_damage | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n |
| motor | glm_freq.third_party_prop | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n |
| motor | glm_freq.bodily_injury | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n |
| motor | glm_freq.theft | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n |
| motor | glm_freq.glass_hail | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n |
| motor | glm_sev | vehicle_value_group, cover_type, vehicle_age, region, driver_age, voluntary_excess, urban_density |
| buildings | tree models | policyholder_age, sum_insured, construction_type, occupancy, days_unoccupied, smoke_alarms, accidental_damage_cover, mortgage, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, previous_insurer, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer, noise_probe, log_sum_insured, flood_score, property_age, si_per_bedroom, subsidence_score, hist_pol_n, hist_pol_cost, hist_pol_exp, hist_cust_other_n, hist_addr_flood, hist_addr_water, hist_addr_subs, hist_addr_storm, hist_pol_rel |
| buildings | glm_freq.storm | flood_zone, elevation_m, distance_to_river_km, sum_insured, bedrooms, property_age, property_type, construction_type, occupancy, prior_claims_5y, missed_payments_12m, region, urban_density, soil_type, trees_within_5m, roof_type, basement, listed_building, accidental_damage_cover, days_unoccupied, voluntary_excess, wind_exposure_index, hail_days, dry_summer_index, rainfall_mm, freezing_days, hist_pol_n, hist_addr_flood, hist_addr_water, hist_addr_storm |
| buildings | glm_freq.flood | flood_zone, elevation_m, distance_to_river_km, basement, sum_insured, region, rainfall_mm, hist_addr_flood |
| buildings | glm_freq.escape_of_water | flood_zone, elevation_m, distance_to_river_km, sum_insured, bedrooms, property_age, property_type, construction_type, occupancy, prior_claims_5y, missed_payments_12m, region, urban_density, soil_type, trees_within_5m, roof_type, basement, listed_building, accidental_damage_cover, days_unoccupied, voluntary_excess, wind_exposure_index, hail_days, dry_summer_index, rainfall_mm, freezing_days, hist_pol_n, hist_addr_flood, hist_addr_water, hist_addr_storm |
| buildings | glm_freq.subsidence | soil_type, trees_within_5m, dry_summer_index, property_age, sum_insured, region |
| buildings | glm_freq.fire | sum_insured, property_type, construction_type, occupancy, smoke_alarms, region, urban_density, listed_building, prior_claims_5y, hist_pol_n |
| buildings | glm_freq.accidental_damage | flood_zone, elevation_m, distance_to_river_km, sum_insured, bedrooms, property_age, property_type, construction_type, occupancy, prior_claims_5y, missed_payments_12m, region, urban_density, soil_type, trees_within_5m, roof_type, basement, listed_building, accidental_damage_cover, days_unoccupied, voluntary_excess, wind_exposure_index, hail_days, dry_summer_index, rainfall_mm, freezing_days, hist_pol_n, hist_addr_flood, hist_addr_water, hist_addr_storm |
| buildings | glm_sev | sum_insured, property_type, region, flood_zone, property_age, accidental_damage_cover |
| contents | tree models | policyholder_age, sum_insured, tenure, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, previous_insurer, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer, noise_probe, log_sum_insured, flood_score, si_per_person, hvi_per_10k_si, hist_pol_n, hist_pol_cost, hist_pol_exp, hist_cust_other_n, hist_addr_flood, hist_addr_water, hist_addr_subs, hist_addr_storm, hist_pol_rel |
| contents | glm_freq.theft | flood_zone, elevation_m, distance_to_river_km, sum_insured, tenure, region, policyholder_age, prior_claims_5y, urban_density, missed_payments_12m, voluntary_excess, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, property_type, household_size, hist_pol_n, hist_cust_other_n, hist_addr_flood, hist_addr_water |
| contents | glm_freq.escape_of_water | flood_zone, elevation_m, distance_to_river_km, sum_insured, tenure, region, policyholder_age, prior_claims_5y, urban_density, missed_payments_12m, voluntary_excess, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, property_type, household_size, hist_pol_n, hist_cust_other_n, hist_addr_flood, hist_addr_water |
| contents | glm_freq.accidental_damage | flood_zone, elevation_m, distance_to_river_km, sum_insured, tenure, region, policyholder_age, prior_claims_5y, urban_density, missed_payments_12m, voluntary_excess, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, property_type, household_size, hist_pol_n, hist_cust_other_n, hist_addr_flood, hist_addr_water |
| contents | glm_freq.flood | flood_zone, elevation_m, distance_to_river_km, property_type, sum_insured, region, rainfall_mm, hist_addr_flood |
| contents | glm_sev | sum_insured, high_value_items, region, tenure, accidental_damage_cover |

