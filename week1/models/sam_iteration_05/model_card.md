# Iteration SAM 5 (`sam_iteration_05`)

**Run id** `20261022_2213` | **Generated** 2026-10-23 00:24 | **Git commit** `e41be93 + uncommitted changes in R/` | **Submission file** `submission_20261022_2213.csv`

**Change in this iteration:** SAM 4 plus premium_index (written_premium relative to the exposure-weighted mean of its line and policy year, so rate changes are removed) as a feature of the LightGBM / XGBoost per-peril and line Tweedie models; raw written_premium and discount_applied stay excluded and the GLMs are unchanged. IBNR as SAM 4 (row-level report share); open-claim case estimates used as final.

> **Warning:** generated from uncommitted code.

## Phase 0 - is the old framework off track?
### Predicted 2025 cost per exposure-year of past submissions vs their public D2

| submission | motor | buildings | contents | public_d2 |
|---|---|---|---|---|
| #1 iteration_01 | 518.1190 | 425.0838 | 113.2029 | 0.1190 |
| #2 iteration_02 | 498.8029 | 434.2517 | 119.1349 | 0.1215 |
| #3 sam_iteration_01 | 518.1190 | 411.7918 | 111.8020 | 0.1188 |
| this run (sam_iteration_05) | 607.4506 | 490.1431 | 125.9662 |  |

### Replay of iteration 1 (GLM) and iteration 2 (XGBoost) in the new validation (combined D2, all lines)
Public order is iteration 2 > iteration 1. Replay ranks XGBoost above GLM in every fold: **FALSE**.

| valid_year | d2_legacy_glm | d2_legacy_xgb | d2_flat_legacy_glm | d2_flat_legacy_xgb | xgb_beats_glm |
|---|---|---|---|---|---|
| 2022 | 0.1054 | 0.1035 | 0.1383 | 0.1364 | FALSE |
| 2023 | 0.1059 | 0.1018 | 0.1416 | 0.1376 | FALSE |
| 2024 | 0.0950 | 0.0982 | 0.1268 | 0.1299 | TRUE |

### Level sensitivity (2023 fold, blend scaled by a constant, combined D2)

| scale | d2_combined | d2_combined_flat |
|---|---|---|
| 0.8500 | 0.0998 | 0.1357 |
| 0.9000 | 0.1024 | 0.1382 |
| 0.9500 | 0.1040 | 0.1397 |
| 1 | 0.1048 | 0.1404 |
| 1.0500 | 0.1048 | 0.1405 |
| 1.1000 | 0.1042 | 0.1399 |
| 1.1500 | 0.1031 | 0.1388 |

## Reproducibility
Submission MD5 `dcef4c6c30afe35ad6311dc6bcf9ff4c`. The submitted blend per line is saved in `models/sam_iteration_05/fitted/<line>_blend.rds` (boosters embedded). Prepared data: `data/sam05/` (rebuild with this script).

```r
source("R/0_setup.R"); source("R/model_io.R")
art  <- load_model("models/sam_iteration_05/fitted", "motor_blend")
pred <- pmax(score_model(art, arrow::read_parquet("data/sam05/test_motor.parquet")), 0)
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
| IBNR | frequency-only, from output/3b_ibnr (chain ladder per line x peril; SAM 3 ECDF for motor bodily_injury); effective exposure = exposure x mean reported share over the row's days; severity uses observed capped claims |
| Long-tail perils | buildings.subsidence, motor.bodily_injury (2023 open share > 15%): severity on policy years < 2023, frequency with a 2024 dummy |
| Trend | policy_year term in each per-peril frequency and severity GLM, capped at +/-10% a year; tree models take the GLM level |
| GLM | 6 quantile bins, levels < 0.5% exposure merged to base; frequency on all claim rows + 3e+05 sampled zero rows (reweighted) |
| LightGBM | learning_rate=0.05, num_leaves=15, min_data_in_leaf=500, feature_fraction=0.7, bagging_fraction=0.8, bagging_freq=1, lambda_l2=10, cat_smooth=50, cat_l2=10, min_data_per_group=500, max_cat_threshold=32, verbosity=-1, deterministic=1, force_col_wise=1, num_threads=12 |
| XGBoost line Tweedie | motor: max_depth=3, learning_rate=0.05, min_child_weight=50, subsample=0.7, colsample_bytree=0.8, reg_lambda=5, tweedie_variance_power=1.7; buildings: max_depth=3, learning_rate=0.03, min_child_weight=50, subsample=0.9, colsample_bytree=0.8, reg_lambda=10, tweedie_variance_power=1.3; contents: max_depth=4, learning_rate=0.03, min_child_weight=500, subsample=0.8, colsample_bytree=0.6, reg_lambda=5, tweedie_variance_power=1.3 |
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
Policy-year IBNR factor (reporting only; the models use the row-level share). SAM 3 vs SAM 5:

| line | peril | sam03_factor_2021 | sam03_factor_2022 | sam03_factor_2023 | sam03_factor_2024 | sam05_factor_2021 | sam05_factor_2022 | sam05_factor_2023 | sam05_factor_2024 |
|---|---|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | 1 | 1 | 1.001 | 1.027 | 1 | 1 | 1.001 | 1.031 |
| buildings | escape_of_water | 1 | 1 | 1.002 | 1.061 | 1 | 1 | 1.001 | 1.074 |
| buildings | fire | 1 | 1 | 1.001 | 1.010 | 1 | 1 | 1.001 | 1.022 |
| buildings | flood | 1 | 1 | 1.001 | 1.014 | 1 | 1 | 1.001 | 1.022 |
| buildings | storm | 1 | 1 | 1.002 | 1.044 | 1 | 1 | 1.002 | 1.052 |
| buildings | subsidence | 1 | 1.000 | 1.016 | 1.602 | 1 | 1.000 | 1.019 | 1.607 |
| contents | accidental_damage | 1 | 1 | 1.001 | 1.031 | 1 | 1 | 1.001 | 1.036 |
| contents | escape_of_water | 1 | 1 | 1.002 | 1.047 | 1 | 1 | 1.002 | 1.060 |
| contents | flood | 1 | 1 | 1.003 | 1.030 | 1 | 1 | 1.003 | 1.039 |
| contents | theft | 1 | 1 | 1.001 | 1.012 | 1 | 1 | 1.001 | 1.021 |
| motor | bodily_injury | 1.000 | 1.005 | 1.057 | 1.736 | 1.000 | 1.005 | 1.057 | 1.736 |
| motor | glass_hail | 1 | 1 | 1.002 | 1.017 | 1 | 1 | 1.002 | 1.029 |
| motor | own_damage | 1 | 1 | 1.001 | 1.028 | 1 | 1 | 1.001 | 1.034 |
| motor | theft | 1 | 1 | 1.001 | 1.012 | 1 | 1 | 1.001 | 1.019 |
| motor | third_party_prop | 1 | 1 | 1.002 | 1.049 | 1 | 1 | 1.001 | 1.061 |

Final fit (2021-24): fitted vs used (capped) annual trend, 2024 immaturity relativity for long-tail perils, severity claims and loading:

| line | peril | long_tail | freq_trend_fitted | freq_trend_used | imm_2024_rel | sev_trend_fitted | sev_trend_used | sev_claims | loading |
|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | FALSE | -0.052 | -0.052 |  | 0.082 | 0.082 | 48,258 | 1.010 |
| motor | third_party_prop | FALSE | -0.048 | -0.048 |  | 0.078 | 0.078 | 32,963 | 1.006 |
| motor | bodily_injury | TRUE | -0.060 | -0.060 | 1.025 | 0.045 | 0.045 | 4,285 | 1.036 |
| motor | theft | FALSE | -0.013 | -0.013 |  | 0.064 | 0.064 | 6,119 | 1.007 |
| motor | glass_hail | FALSE | -0.016 | -0.016 |  | 0.080 | 0.080 | 15,643 | 1.006 |
| buildings | storm | FALSE | 0.004 | 0.004 |  | 0.067 | 0.067 | 7,762 | 1.009 |
| buildings | flood | FALSE | -0.019 | -0.019 |  | 0.048 | 0.048 | 2,219 | 1.008 |
| buildings | escape_of_water | FALSE | -0.003 | -0.003 |  | 0.069 | 0.069 | 10,065 | 1.007 |
| buildings | subsidence | TRUE | 0.010 | 0.010 | 1.104 | 0.048 | 0.048 | 617 | 1.001 |
| buildings | fire | FALSE | 0.057 | 0.057 |  | -0.048 | -0.048 | 1,107 | 1.008 |
| buildings | accidental_damage | FALSE | 0.002 | 0.002 |  | 0.016 | 0.016 | 3,825 | 1.006 |
| contents | theft | FALSE | 0.013 | 0.013 |  | 0.031 | 0.031 | 7,626 | 1.008 |
| contents | escape_of_water | FALSE | 0.000 | 0.000 |  | 0.016 | 0.016 | 5,366 | 1.008 |
| contents | accidental_damage | FALSE | -0.008 | -0.008 |  | 0.025 | 0.025 | 9,063 | 1.004 |
| contents | flood | FALSE | -0.026 | -0.026 |  | 0.057 | 0.057 | 1,615 | 1.009 |

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
| motor | 14 | 3 | 0.0500 | 50 | 0.7000 | 0.8000 | 5 | 1.7000 | 0.0557 | 241 | 8 | 1 |
| motor | 33 | 4 | 0.0300 | 200 | 0.7000 | 0.7000 | 5 | 1.3000 | 0.0557 | 335 | 12 | 2 |
| motor | 19 | 3 | 0.0300 | 200 | 0.7000 | 0.7000 | 1 | 1.7000 | 0.0553 | 476 | 13 | 3 |
| motor | 10 | 5 | 0.0300 | 50 | 0.7000 | 0.7000 | 5 | 1.3000 | 0.0550 | 267 | 10 | 4 |
| motor | 35 | 3 | 0.0300 | 200 | 0.7000 | 0.6000 | 1 | 1.5000 | 0.0548 | 448 | 15 | 5 |
| buildings | 37 | 3 | 0.0300 | 50 | 0.9000 | 0.8000 | 10 | 1.3000 | 0.0903 | 258 | 7 | 1 |
| buildings | 10 | 3 | 0.0300 | 200 | 0.7000 | 0.6000 | 10 | 1.3000 | 0.0881 | 268 | 7 | 2 |
| buildings | 18 | 4 | 0.0500 | 200 | 0.9000 | 0.7000 | 1 | 1.3000 | 0.0879 | 112 | 4 | 3 |
| buildings | 7 | 3 | 0.0500 | 200 | 0.9000 | 0.6000 | 1 | 1.5000 | 0.0861 | 129 | 4 | 4 |
| buildings | 12 | 3 | 0.0500 | 200 | 0.7000 | 0.7000 | 5 | 1.3000 | 0.0860 | 126 | 4 | 5 |
| contents | 29 | 4 | 0.0300 | 500 | 0.8000 | 0.6000 | 5 | 1.3000 | 0.0606 | 219 | 17 | 1 |
| contents | 23 | 4 | 0.0300 | 500 | 0.9000 | 0.7000 | 1 | 1.5000 | 0.0591 | 192 | 16 | 2 |
| contents | 27 | 4 | 0.0300 | 50 | 0.9000 | 0.6000 | 5 | 1.5000 | 0.0591 | 192 | 16 | 3 |
| contents | 28 | 4 | 0.0300 | 500 | 0.9000 | 0.7000 | 1 | 1.3000 | 0.0590 | 198 | 15 | 4 |
| contents | 17 | 5 | 0.0500 | 50 | 0.9000 | 0.7000 | 1 | 1.5000 | 0.0590 | 81 | 3 | 5 |

## Validation - local Kaggle metric (Tweedie D2, p = 1.5)
`d2` = raw (exposure-rate baseline, as Kaggle is believed to score), `d2_flat` = flat-mean baseline, `d2_cal` = after rescaling predictions to the actual total (ranking only), `ae_developed` = predicted / IBNR-developed actual (level). 2024 actuals are immature.

### Combined, all lines
| model | d2_2022 | d2_2023 | d2_2024 | d2_flat_2022 | d2_flat_2023 | d2_flat_2024 | ae_developed_2022 | ae_developed_2023 | ae_developed_2024 |
|---|---|---|---|---|---|---|---|---|---|
| legacy_glm | 0.1054 | 0.1059 | 0.0950 | 0.1383 | 0.1416 | 0.1268 | 0.9912 | 0.9480 | 0.9757 |
| blend | 0.1152 | 0.1048 | 0.0983 | 0.1476 | 0.1404 | 0.1300 | 0.9696 | 0.9613 | 1.0320 |
| peril_glm_notrend | 0.1108 | 0.1032 | 0.0957 | 0.1434 | 0.1390 | 0.1274 | 0.9701 | 0.9423 | 0.9804 |
| peril_glm | 0.1108 | 0.1030 | 0.0946 | 0.1434 | 0.1388 | 0.1264 | 0.9701 | 0.9616 | 1.0316 |
| xgb_tweedie | 0.1082 | 0.1024 | 0.0958 | 0.1410 | 0.1382 | 0.1276 | 0.9701 | 0.9616 | 1.0316 |
| legacy_xgb | 0.1035 | 0.1018 | 0.0982 | 0.1364 | 0.1376 | 0.1299 | 0.8694 | 0.8571 | 0.9222 |
| peril_xgb | 0.1150 | 0.1005 | 0.0980 | 0.1475 | 0.1363 | 0.1297 | 0.9690 | 0.9614 | 1.0328 |
| peril_lgb | 0.1092 | 0.0932 | 0.0945 | 0.1419 | 0.1294 | 0.1263 | 0.9688 | 0.9616 | 1.0313 |
| lgb_tweedie | 0.1016 | 0.0924 | 0.0888 | 0.1346 | 0.1286 | 0.1208 | 0.9701 | 0.9616 | 1.0316 |
| burn_trend | 0.0553 | 0.0492 | 0.0352 | 0.0899 | 0.0871 | 0.0691 | 0.9713 | 0.9743 | 1.0431 |
| burn_cost | 0.0553 | 0.0488 | 0.0371 | 0.0899 | 0.0867 | 0.0709 | 0.9712 | 0.9300 | 0.9588 |

### Mean over folds by line
| line | model | d2 | d2_cal | d2_flat | ae_developed |
|---|---|---|---|---|---|
| buildings | blend | 0.0716 | 0.0718 | 0.1081 | 0.9673 |
| buildings | peril_xgb | 0.0710 | 0.0712 | 0.1075 | 0.9667 |
| buildings | xgb_tweedie | 0.0679 | 0.0681 | 0.1045 | 0.9682 |
| buildings | peril_lgb | 0.0676 | 0.0678 | 0.1043 | 0.9654 |
| buildings | legacy_xgb | 0.0664 | 0.0675 | 0.1031 | 0.8748 |
| buildings | peril_glm | 0.0670 | 0.0672 | 0.1036 | 0.9682 |
| buildings | peril_glm_notrend | 0.0670 | 0.0672 | 0.1037 | 0.9294 |
| buildings | lgb_tweedie | 0.0633 | 0.0636 | 0.1001 | 0.9682 |
| buildings | legacy_glm | 0.0597 | 0.0595 | 0.0967 | 0.9819 |
| buildings | burn_trend | -0.0002 | 0 | 0.0392 | 0.9502 |
| buildings | burn_cost | -0.0008 | 0 | 0.0386 | 0.8968 |
| contents | blend | 0.0664 | 0.0668 | 0.0972 | 0.9807 |
| contents | peril_xgb | 0.0648 | 0.0652 | 0.0956 | 0.9816 |
| contents | xgb_tweedie | 0.0631 | 0.0635 | 0.0940 | 0.9803 |
| contents | peril_glm_notrend | 0.0626 | 0.0632 | 0.0935 | 0.9541 |
| contents | peril_glm | 0.0628 | 0.0631 | 0.0936 | 0.9803 |
| contents | peril_lgb | 0.0622 | 0.0624 | 0.0930 | 0.9810 |
| contents | legacy_glm | 0.0598 | 0.0605 | 0.0907 | 0.9494 |
| contents | legacy_xgb | 0.0570 | 0.0590 | 0.0881 | 0.9030 |
| contents | lgb_tweedie | 0.0581 | 0.0586 | 0.0891 | 0.9803 |
| contents | burn_trend | -0.0007 | 0 | 0.0322 | 0.9687 |
| contents | burn_cost | -0.0010 | 0 | 0.0319 | 0.9361 |
| motor | legacy_glm | 0.0519 | 0.0538 | 0.0889 | 0.9726 |
| motor | blend | 0.0495 | 0.0535 | 0.0867 | 1.0038 |
| motor | peril_xgb | 0.0472 | 0.0512 | 0.0845 | 1.0041 |
| motor | peril_glm_notrend | 0.0480 | 0.0505 | 0.0852 | 0.9893 |
| motor | peril_glm | 0.0470 | 0.0505 | 0.0843 | 1.0036 |
| motor | legacy_xgb | 0.0461 | 0.0498 | 0.0834 | 0.8873 |
| motor | xgb_tweedie | 0.0448 | 0.0489 | 0.0821 | 1.0036 |
| motor | peril_lgb | 0.0384 | 0.0424 | 0.0760 | 1.0041 |
| motor | lgb_tweedie | 0.0325 | 0.0367 | 0.0704 | 1.0036 |
| motor | burn_cost | -0.0026 | 0 | 0.0366 | 0.9924 |
| motor | burn_trend | -0.0044 | 0 | 0.0348 | 1.0305 |

### Raw D2 by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.0672 | 0.0728 | 0.0747 |
| buildings | burn_cost | -0.0004 | -0.0009 | -0.0010 |
| buildings | burn_trend | -0.0004 | 0.0000 | -0.0001 |
| buildings | legacy_glm | 0.0483 | 0.0622 | 0.0687 |
| buildings | legacy_xgb | 0.0564 | 0.0699 | 0.0730 |
| buildings | lgb_tweedie | 0.0598 | 0.0641 | 0.0660 |
| buildings | peril_glm | 0.0627 | 0.0685 | 0.0697 |
| buildings | peril_glm_notrend | 0.0627 | 0.0685 | 0.0698 |
| buildings | peril_lgb | 0.0644 | 0.0678 | 0.0706 |
| buildings | peril_xgb | 0.0664 | 0.0726 | 0.0739 |
| buildings | xgb_tweedie | 0.0614 | 0.0694 | 0.0728 |
| contents | blend | 0.0645 | 0.0709 | 0.0639 |
| contents | burn_cost | 0.0000 | -0.0022 | -0.0009 |
| contents | burn_trend | 0.0000 | -0.0021 | -0.0001 |
| contents | legacy_glm | 0.0555 | 0.0631 | 0.0608 |
| contents | legacy_xgb | 0.0511 | 0.0611 | 0.0589 |
| contents | lgb_tweedie | 0.0542 | 0.0621 | 0.0580 |
| contents | peril_glm | 0.0585 | 0.0679 | 0.0620 |
| contents | peril_glm_notrend | 0.0585 | 0.0678 | 0.0616 |
| contents | peril_lgb | 0.0603 | 0.0676 | 0.0586 |
| contents | peril_xgb | 0.0625 | 0.0697 | 0.0623 |
| contents | xgb_tweedie | 0.0622 | 0.0663 | 0.0608 |
| motor | blend | 0.0599 | 0.0427 | 0.0460 |
| motor | burn_cost | -0.0001 | -0.0002 | -0.0075 |
| motor | burn_trend | -0.0001 | -0.0000 | -0.0131 |
| motor | legacy_glm | 0.0553 | 0.0557 | 0.0446 |
| motor | legacy_xgb | 0.0468 | 0.0420 | 0.0494 |
| motor | lgb_tweedie | 0.0391 | 0.0251 | 0.0334 |
| motor | peril_glm | 0.0557 | 0.0431 | 0.0422 |
| motor | peril_glm_notrend | 0.0557 | 0.0436 | 0.0448 |
| motor | peril_lgb | 0.0503 | 0.0222 | 0.0427 |
| motor | peril_xgb | 0.0609 | 0.0340 | 0.0467 |
| motor | xgb_tweedie | 0.0497 | 0.0417 | 0.0430 |

### Calibrated D2 by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.0674 | 0.0729 | 0.0751 |
| buildings | burn_cost | 0 | 0 | 0 |
| buildings | burn_trend | 0 | 0 | 0 |
| buildings | legacy_glm | 0.0474 | 0.0624 | 0.0687 |
| buildings | legacy_xgb | 0.0589 | 0.0702 | 0.0732 |
| buildings | lgb_tweedie | 0.0601 | 0.0642 | 0.0665 |
| buildings | peril_glm | 0.0631 | 0.0685 | 0.0700 |
| buildings | peril_glm_notrend | 0.0631 | 0.0686 | 0.0698 |
| buildings | peril_lgb | 0.0647 | 0.0678 | 0.0709 |
| buildings | peril_xgb | 0.0667 | 0.0726 | 0.0743 |
| buildings | xgb_tweedie | 0.0617 | 0.0694 | 0.0731 |
| contents | blend | 0.0645 | 0.0719 | 0.0640 |
| contents | burn_cost | 0 | 0 | 0 |
| contents | burn_trend | 0 | 0 | 0 |
| contents | legacy_glm | 0.0554 | 0.0647 | 0.0614 |
| contents | legacy_xgb | 0.0533 | 0.0643 | 0.0595 |
| contents | lgb_tweedie | 0.0543 | 0.0632 | 0.0581 |
| contents | peril_glm | 0.0584 | 0.0691 | 0.0619 |
| contents | peril_glm_notrend | 0.0584 | 0.0693 | 0.0620 |
| contents | peril_lgb | 0.0603 | 0.0685 | 0.0585 |
| contents | peril_xgb | 0.0625 | 0.0708 | 0.0621 |
| contents | xgb_tweedie | 0.0622 | 0.0676 | 0.0608 |
| motor | blend | 0.0599 | 0.0430 | 0.0576 |
| motor | burn_cost | 0 | 0 | 0 |
| motor | burn_trend | 0 | 0 | 0 |
| motor | legacy_glm | 0.0556 | 0.0560 | 0.0499 |
| motor | legacy_xgb | 0.0507 | 0.0462 | 0.0525 |
| motor | lgb_tweedie | 0.0392 | 0.0254 | 0.0456 |
| motor | peril_glm | 0.0559 | 0.0435 | 0.0522 |
| motor | peril_glm_notrend | 0.0559 | 0.0439 | 0.0518 |
| motor | peril_lgb | 0.0503 | 0.0225 | 0.0544 |
| motor | peril_xgb | 0.0609 | 0.0344 | 0.0583 |
| motor | xgb_tweedie | 0.0498 | 0.0421 | 0.0548 |

### Level: predicted / developed actual by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.961 | 0.997 | 0.944 |
| buildings | burn_cost | 0.952 | 0.908 | 0.830 |
| buildings | burn_trend | 0.952 | 0.971 | 0.927 |
| buildings | legacy_glm | 1.049 | 0.978 | 0.918 |
| buildings | legacy_xgb | 0.868 | 0.899 | 0.857 |
| buildings | lgb_tweedie | 0.962 | 0.999 | 0.944 |
| buildings | peril_glm | 0.962 | 0.999 | 0.944 |
| buildings | peril_glm_notrend | 0.962 | 0.943 | 0.883 |
| buildings | peril_lgb | 0.958 | 0.996 | 0.942 |
| buildings | peril_xgb | 0.961 | 0.995 | 0.943 |
| buildings | xgb_tweedie | 0.962 | 0.999 | 0.944 |
| contents | blend | 1.009 | 0.923 | 1.010 |
| contents | burn_cost | 1.000 | 0.900 | 0.908 |
| contents | burn_trend | 1.000 | 0.903 | 1.004 |
| contents | legacy_glm | 1.009 | 0.917 | 0.922 |
| contents | legacy_xgb | 0.910 | 0.876 | 0.923 |
| contents | lgb_tweedie | 1.008 | 0.923 | 1.009 |
| contents | peril_glm | 1.008 | 0.923 | 1.009 |
| contents | peril_glm_notrend | 1.008 | 0.919 | 0.934 |
| contents | peril_lgb | 1.011 | 0.923 | 1.009 |
| contents | peril_xgb | 1.011 | 0.924 | 1.010 |
| contents | xgb_tweedie | 1.008 | 0.923 | 1.009 |
| motor | blend | 0.969 | 0.948 | 1.095 |
| motor | burn_cost | 0.977 | 0.946 | 1.054 |
| motor | burn_trend | 0.977 | 0.987 | 1.128 |
| motor | legacy_glm | 0.958 | 0.936 | 1.023 |
| motor | legacy_xgb | 0.864 | 0.832 | 0.966 |
| motor | lgb_tweedie | 0.969 | 0.947 | 1.094 |
| motor | peril_glm | 0.969 | 0.947 | 1.094 |
| motor | peril_glm_notrend | 0.969 | 0.945 | 1.053 |
| motor | peril_lgb | 0.969 | 0.949 | 1.095 |
| motor | peril_xgb | 0.967 | 0.948 | 1.097 |
| motor | xgb_tweedie | 0.969 | 0.947 | 1.094 |

### Trend vs no trend (per-peril GLM)
| line | model | d2_2022 | d2_2023 | d2_2024 | ae_developed_2022 | ae_developed_2023 | ae_developed_2024 |
|---|---|---|---|---|---|---|---|
| buildings | peril_glm | 0.0627 | 0.0685 | 0.0697 | 0.9616 | 0.9989 | 0.9440 |
| buildings | peril_glm_notrend | 0.0627 | 0.0685 | 0.0698 | 0.9616 | 0.9435 | 0.8832 |
| contents | peril_glm | 0.0585 | 0.0679 | 0.0620 | 1.0085 | 0.9231 | 1.0094 |
| contents | peril_glm_notrend | 0.0585 | 0.0678 | 0.0616 | 1.0085 | 0.9194 | 0.9345 |
| motor | peril_glm | 0.0557 | 0.0431 | 0.0422 | 0.9694 | 0.9471 | 1.0942 |
| motor | peril_glm_notrend | 0.0557 | 0.0436 | 0.0448 | 0.9694 | 0.9450 | 1.0534 |

### Overfitting check: calibrated D2 on training rows vs validation year
| valid_year | line | model | d2_cal_train | d2_cal_valid | gap |
|---|---|---|---|---|---|
| 2022 | buildings | lgb_tweedie | 0.1671 | 0.0601 | 0.1070 |
| 2023 | buildings | lgb_tweedie | 0.1092 | 0.0642 | 0.0450 |
| 2024 | buildings | lgb_tweedie | 0.1057 | 0.0665 | 0.0392 |
| 2022 | buildings | peril_glm | 0.0780 | 0.0631 | 0.0149 |
| 2023 | buildings | peril_glm | 0.0767 | 0.0685 | 0.0082 |
| 2024 | buildings | peril_glm | 0.0775 | 0.0700 | 0.0075 |
| 2022 | buildings | peril_lgb | 0.1271 | 0.0647 | 0.0624 |
| 2023 | buildings | peril_lgb | 0.1348 | 0.0678 | 0.0670 |
| 2024 | buildings | peril_lgb | 0.1238 | 0.0709 | 0.0529 |
| 2022 | buildings | peril_xgb | 0.1014 | 0.0667 | 0.0348 |
| 2023 | buildings | peril_xgb | 0.0943 | 0.0726 | 0.0218 |
| 2024 | buildings | peril_xgb | 0.0899 | 0.0743 | 0.0156 |
| 2022 | buildings | xgb_tweedie | 0.1358 | 0.0617 | 0.0741 |
| 2023 | buildings | xgb_tweedie | 0.0902 | 0.0694 | 0.0207 |
| 2024 | buildings | xgb_tweedie | 0.1134 | 0.0731 | 0.0403 |
| 2022 | contents | lgb_tweedie | 0.1143 | 0.0543 | 0.0600 |
| 2023 | contents | lgb_tweedie | 0.1299 | 0.0632 | 0.0666 |
| 2024 | contents | lgb_tweedie | 0.1171 | 0.0581 | 0.0590 |
| 2022 | contents | peril_glm | 0.0877 | 0.0584 | 0.0293 |
| 2023 | contents | peril_glm | 0.0679 | 0.0691 | -0.0013 |
| 2024 | contents | peril_glm | 0.0769 | 0.0619 | 0.0150 |
| 2022 | contents | peril_lgb | 0.1260 | 0.0603 | 0.0657 |
| 2023 | contents | peril_lgb | 0.0960 | 0.0685 | 0.0275 |
| 2024 | contents | peril_lgb | 0.0990 | 0.0585 | 0.0405 |
| 2022 | contents | peril_xgb | 0.1171 | 0.0625 | 0.0545 |
| 2023 | contents | peril_xgb | 0.0986 | 0.0708 | 0.0278 |
| 2024 | contents | peril_xgb | 0.1002 | 0.0621 | 0.0380 |
| 2022 | contents | xgb_tweedie | 0.1515 | 0.0622 | 0.0893 |
| 2023 | contents | xgb_tweedie | 0.1258 | 0.0676 | 0.0582 |
| 2024 | contents | xgb_tweedie | 0.1246 | 0.0608 | 0.0638 |
| 2022 | motor | lgb_tweedie | 0.0988 | 0.0392 | 0.0596 |
| 2023 | motor | lgb_tweedie | 0.0903 | 0.0254 | 0.0650 |
| 2024 | motor | lgb_tweedie | 0.0815 | 0.0456 | 0.0359 |
| 2022 | motor | peril_glm | 0.0533 | 0.0559 | -0.0026 |
| 2023 | motor | peril_glm | 0.0583 | 0.0435 | 0.0148 |
| 2024 | motor | peril_glm | 0.0521 | 0.0522 | -0.0001 |
| 2022 | motor | peril_lgb | 0.0760 | 0.0503 | 0.0257 |
| 2023 | motor | peril_lgb | 0.0720 | 0.0225 | 0.0494 |
| 2024 | motor | peril_lgb | 0.0550 | 0.0544 | 0.0006 |
| 2022 | motor | peril_xgb | 0.0754 | 0.0609 | 0.0145 |
| 2023 | motor | peril_xgb | 0.0740 | 0.0344 | 0.0396 |
| 2024 | motor | peril_xgb | 0.0553 | 0.0583 | -0.0030 |
| 2022 | motor | xgb_tweedie | 0.0805 | 0.0498 | 0.0307 |
| 2023 | motor | xgb_tweedie | 0.0938 | 0.0421 | 0.0517 |
| 2024 | motor | xgb_tweedie | 0.0774 | 0.0548 | 0.0226 |

### Segment A/E of the blend (level removed per line; 1 = right relative price)
| line | segment | level | exposure | ae_2023 | ae_2024 |
|---|---|---|---|---|---|
| buildings | hist_pol_n | 0 | 278,461.014 | 0.969 | 0.967 |
| buildings | hist_pol_n | 1 | 19,745.315 | 1.280 | 1.212 |
| buildings | hist_pol_n | 2 | 1,540.868 | 1.790 | 1.389 |
| buildings | hist_pol_n | 3 | 157.622 | 2.177 | 1.346 |
| buildings | new_business | FALSE | 272,802.258 | 1.007 | 0.991 |
| buildings | new_business | TRUE | 27,102.562 | 0.933 | 1.097 |
| contents | hist_pol_n | 0 | 280,343.293 | 0.967 | 0.990 |
| contents | hist_pol_n | 1 | 18,140.847 | 1.361 | 1.093 |
| contents | hist_pol_n | 2 | 1,350.901 | 1.515 | 0.819 |
| contents | hist_pol_n | 3 | 106.671 | 0.141 | 1.996 |
| contents | new_business | FALSE | 272,872.805 | 0.989 | 1.008 |
| contents | new_business | TRUE | 27,068.907 | 1.107 | 0.919 |
| motor | driver_age | [0,25) | 53,987.041 | 0.818 | 0.918 |
| motor | driver_age | [25,35) | 73,253.537 | 1.532 | 1.026 |
| motor | driver_age | [35,50) | 73,266.926 | 0.904 | 1.015 |
| motor | driver_age | [50,65) | 73,917.564 | 0.907 | 1.011 |
| motor | driver_age | [65,Inf) | 125,042.414 | 0.927 | 1.047 |
| motor | hist_pol_n | 0 | 322,217.088 | 1.028 | 0.967 |
| motor | hist_pol_n | 1 | 59,976.984 | 0.849 | 1.058 |
| motor | hist_pol_n | 2 | 12,763.726 | 1.008 | 0.965 |
| motor | hist_pol_n | 3 | 4,509.685 | 1.364 | 1.388 |
| motor | ncb_years | (-Inf,0] | 17,642.841 | 0.983 | 1.091 |
| motor | ncb_years | (0,3] | 92,279.929 | 0.854 | 0.927 |
| motor | ncb_years | (3,6] | 72,292.312 | 1.540 | 1.024 |
| motor | ncb_years | (6,9] | 60,441.992 | 0.915 | 1.029 |
| motor | ncb_years | (9, Inf] | 156,810.408 | 0.918 | 1.029 |
| motor | new_business | FALSE | 363,280.252 | 1.006 | 1.003 |
| motor | new_business | TRUE | 36,187.230 | 0.954 | 0.976 |
| motor | vehicle_age | (-Inf,3] | 28,076.293 | 0.950 | 1.078 |
| motor | vehicle_age | (12, Inf] | 64,911.699 | 0.821 | 0.857 |
| motor | vehicle_age | (3,7] | 153,642.485 | 1.155 | 1.052 |
| motor | vehicle_age | (7,12] | 142,880.718 | 0.914 | 1.010 |

## Blend weights
| line | lgb_tweedie | peril_glm | peril_lgb | peril_xgb | xgb_tweedie |
|---|---|---|---|---|---|
| buildings | 0 | 0.20 | 0 | 0.60 | 0.20 |
| contents | 0 | 0.30 | 0 | 0.30 | 0.40 |
| motor | 0 | 0.40 | 0 | 0.40 | 0.20 |

## 2025 test predictions (final fit on 2021-24)
| line | model | weight | predicted_total | predicted_burn_cost | p50_row | p90_row | p99_row | max_row |
|---|---|---|---|---|---|---|---|---|
| motor | peril_glm | 0.40 | 121,352,763.49 | 606.81 | 377.13 | 934.11 | 2,072.52 | 6,907.50 |
| motor | peril_lgb | 0 | 121,556,156.18 | 607.83 | 407.14 | 870.05 | 1,936.74 | 12,665.39 |
| motor | peril_xgb | 0.40 | 121,671,208.79 | 608.41 | 393.58 | 896.99 | 2,018.78 | 8,854.39 |
| motor | lgb_tweedie | 0 | 121,352,763.49 | 606.81 | 405.17 | 891.72 | 1,843.11 | 7,596.88 |
| motor | xgb_tweedie | 0.20 | 121,352,763.49 | 606.81 | 387.67 | 918.82 | 2,007.62 | 6,475.97 |
| motor | burn_trend |  | 126,098,666.96 | 630.55 | 630.55 | 630.55 | 630.55 | 630.55 |
| motor | burn_cost |  | 108,930,584.85 | 544.70 | 544.70 | 544.70 | 544.70 | 544.70 |
| motor | blend | 1 | 121,480,141.61 | 607.45 | 389.14 | 914.22 | 1,989.49 | 7,217.70 |
| buildings | peril_glm | 0.20 | 73,594,450.06 | 489.83 | 319.03 | 704.00 | 2,111.42 | 8,664.58 |
| buildings | peril_lgb | 0 | 73,442,367.73 | 488.82 | 320.78 | 676.82 | 2,241.31 | 25,837.54 |
| buildings | peril_xgb | 0.60 | 73,672,063.84 | 490.35 | 308.95 | 719.29 | 2,230.83 | 14,684.54 |
| buildings | lgb_tweedie | 0 | 73,594,450.06 | 489.83 | 323.58 | 681.67 | 2,204.99 | 6,063.41 |
| buildings | xgb_tweedie | 0.20 | 73,594,450.06 | 489.83 | 310.10 | 694.32 | 2,388.56 | 12,947.35 |
| buildings | burn_trend |  | 75,510,607.64 | 502.59 | 502.59 | 502.59 | 502.59 | 502.59 |
| buildings | burn_cost |  | 62,751,650.57 | 417.67 | 417.67 | 417.67 | 417.67 | 417.67 |
| buildings | blend | 1 | 73,641,018.33 | 490.14 | 313.85 | 705.90 | 2,217.10 | 12,249.10 |
| contents | peril_glm | 0.30 | 18,918,347.25 | 126.02 | 77.58 | 188.53 | 522.70 | 3,830.03 |
| contents | peril_lgb | 0 | 18,906,430.16 | 125.94 | 79.17 | 180.60 | 536.21 | 4,823.10 |
| contents | peril_xgb | 0.30 | 18,892,271.51 | 125.84 | 79.15 | 182.23 | 530.71 | 3,140.77 |
| contents | lgb_tweedie | 0 | 18,918,347.25 | 126.02 | 80.37 | 186.84 | 484.33 | 2,800.52 |
| contents | xgb_tweedie | 0.40 | 18,918,347.25 | 126.02 | 80.16 | 182.39 | 494.38 | 6,526.01 |
| contents | burn_trend |  | 18,969,878.59 | 126.36 | 126.36 | 126.36 | 126.36 | 126.36 |
| contents | burn_cost |  | 16,702,409.98 | 111.26 | 111.26 | 111.26 | 111.26 | 111.26 |
| contents | blend | 1 | 18,910,524.53 | 125.97 | 79.54 | 183.42 | 510.71 | 3,923.13 |

### Level vs previous submissions
| submission | motor | buildings | contents | public_d2 |
|---|---|---|---|---|
| #1 iteration_01 | 518.12 | 425.08 | 113.20 | 0.12 |
| #2 iteration_02 | 498.80 | 434.25 | 119.13 | 0.12 |
| #3 sam_iteration_01 | 518.12 | 411.79 | 111.80 | 0.12 |
| this run (sam_iteration_05) | 607.45 | 490.14 | 125.97 |  |

## Variable importance (line Tweedie bags)
![](tree_importance.png)

Rank of the random noise feature:

| line | model | noise_rank |
|---|---|---|
| motor | xgb_tweedie | 33 |
| buildings | lgb_tweedie | 34 |
| buildings | xgb_tweedie | 18 |
| contents | lgb_tweedie | 38 |
| contents | xgb_tweedie | 25 |

| Feature | Gain | rank | line | model |
|---|---|---|---|---|
| premium_index | 0.3334 | 1 | buildings | lgb_tweedie |
| previous_insurer | 0.1668 | 2 | buildings | lgb_tweedie |
| flood_score | 0.0667 | 3 | buildings | lgb_tweedie |
| occupation | 0.0655 | 4 | buildings | lgb_tweedie |
| sum_insured | 0.0560 | 5 | buildings | lgb_tweedie |
| elevation_m | 0.0393 | 6 | buildings | lgb_tweedie |
| energy_rating | 0.0339 | 7 | buildings | lgb_tweedie |
| property_age | 0.0249 | 8 | buildings | lgb_tweedie |
| region | 0.0185 | 9 | buildings | lgb_tweedie |
| log_sum_insured | 0.0179 | 10 | buildings | lgb_tweedie |
| prior_claims_5y | 0.0165 | 11 | buildings | lgb_tweedie |
| year_built | 0.0156 | 12 | buildings | lgb_tweedie |
| construction_type | 0.0119 | 13 | buildings | lgb_tweedie |
| soil_type | 0.0114 | 14 | buildings | lgb_tweedie |
| dry_summer_index | 0.0098 | 15 | buildings | lgb_tweedie |
| premium_index | 0.3577 | 1 | buildings | xgb_tweedie |
| flood_score | 0.0797 | 2 | buildings | xgb_tweedie |
| elevation_m | 0.0668 | 3 | buildings | xgb_tweedie |
| sum_insured | 0.0622 | 4 | buildings | xgb_tweedie |
| energy_rating | 0.0322 | 5 | buildings | xgb_tweedie |
| property_age | 0.0268 | 6 | buildings | xgb_tweedie |
| prior_claims_5y | 0.0261 | 7 | buildings | xgb_tweedie |
| previous_insurer | 0.0183 | 8 | buildings | xgb_tweedie |
| dry_summer_index | 0.0163 | 9 | buildings | xgb_tweedie |
| construction_type | 0.0152 | 10 | buildings | xgb_tweedie |
| soil_type | 0.0149 | 11 | buildings | xgb_tweedie |
| log_sum_insured | 0.0146 | 12 | buildings | xgb_tweedie |
| year_built | 0.0146 | 13 | buildings | xgb_tweedie |
| hist_pol_cost | 0.0145 | 14 | buildings | xgb_tweedie |
| flood_zone | 0.0134 | 15 | buildings | xgb_tweedie |
| flood_score | 0.2079 | 1 | contents | lgb_tweedie |
| previous_insurer | 0.1585 | 2 | contents | lgb_tweedie |
| premium_index | 0.1334 | 3 | contents | lgb_tweedie |
| elevation_m | 0.0775 | 4 | contents | lgb_tweedie |
| occupation | 0.0562 | 5 | contents | lgb_tweedie |
| sum_insured | 0.0416 | 6 | contents | lgb_tweedie |
| flood_zone | 0.0330 | 7 | contents | lgb_tweedie |
| region | 0.0320 | 8 | contents | lgb_tweedie |
| distance_to_river_km | 0.0234 | 9 | contents | lgb_tweedie |
| voluntary_excess | 0.0210 | 10 | contents | lgb_tweedie |
| prior_claims_5y | 0.0198 | 11 | contents | lgb_tweedie |
| customer_age | 0.0185 | 12 | contents | lgb_tweedie |
| log_sum_insured | 0.0141 | 13 | contents | lgb_tweedie |
| accidental_damage_cover | 0.0136 | 14 | contents | lgb_tweedie |
| policyholder_age | 0.0120 | 15 | contents | lgb_tweedie |
| flood_score | 0.2570 | 1 | contents | xgb_tweedie |
| premium_index | 0.1095 | 2 | contents | xgb_tweedie |
| sum_insured | 0.0703 | 3 | contents | xgb_tweedie |
| elevation_m | 0.0687 | 4 | contents | xgb_tweedie |
| flood_zone | 0.0436 | 5 | contents | xgb_tweedie |
| distance_to_river_km | 0.0329 | 6 | contents | xgb_tweedie |
| si_per_person | 0.0257 | 7 | contents | xgb_tweedie |
| customer_age | 0.0229 | 8 | contents | xgb_tweedie |
| prior_claims_5y | 0.0209 | 9 | contents | xgb_tweedie |
| voluntary_excess | 0.0204 | 10 | contents | xgb_tweedie |
| policyholder_age | 0.0191 | 11 | contents | xgb_tweedie |
| log_sum_insured | 0.0174 | 12 | contents | xgb_tweedie |
| region | 0.0159 | 13 | contents | xgb_tweedie |
| hist_pol_cost | 0.0157 | 14 | contents | xgb_tweedie |
| previous_insurer | 0.0132 | 15 | contents | xgb_tweedie |
| make_model | 0.4093 | 1 | motor | lgb_tweedie |
| ncb_years | 0.1101 | 2 | motor | lgb_tweedie |
| premium_index | 0.1007 | 3 | motor | lgb_tweedie |
| previous_insurer | 0.0752 | 4 | motor | lgb_tweedie |
| annual_mileage | 0.0393 | 5 | motor | lgb_tweedie |
| customer_age | 0.0341 | 6 | motor | lgb_tweedie |
| driver_age | 0.0302 | 7 | motor | lgb_tweedie |
| years_licensed | 0.0270 | 8 | motor | lgb_tweedie |
| hist_pol_rel | 0.0243 | 9 | motor | lgb_tweedie |
| prior_claims_5y | 0.0174 | 10 | motor | lgb_tweedie |
| occupation | 0.0152 | 11 | motor | lgb_tweedie |
| cover_type | 0.0150 | 12 | motor | lgb_tweedie |
| voluntary_excess | 0.0136 | 13 | motor | lgb_tweedie |
| vehicle_age | 0.0117 | 14 | motor | lgb_tweedie |
| hist_pol_n | 0.0097 | 15 | motor | lgb_tweedie |
| ncb_years | 0.1663 | 1 | motor | xgb_tweedie |
| premium_index | 0.1593 | 2 | motor | xgb_tweedie |
| years_licensed | 0.0690 | 3 | motor | xgb_tweedie |
| annual_mileage | 0.0682 | 4 | motor | xgb_tweedie |
| make_model | 0.0559 | 5 | motor | xgb_tweedie |
| hist_pol_rel | 0.0417 | 6 | motor | xgb_tweedie |
| prior_claims_5y | 0.0312 | 7 | motor | xgb_tweedie |
| customer_age | 0.0280 | 8 | motor | xgb_tweedie |
| driver_age | 0.0276 | 9 | motor | xgb_tweedie |
| voluntary_excess | 0.0259 | 10 | motor | xgb_tweedie |
| vehicle_age | 0.0247 | 11 | motor | xgb_tweedie |
| cover_type | 0.0231 | 12 | motor | xgb_tweedie |
| hist_pol_cost | 0.0200 | 13 | motor | xgb_tweedie |
| urban_density | 0.0183 | 14 | motor | xgb_tweedie |
| telematics_score | 0.0165 | 15 | motor | xgb_tweedie |

## Boosting rounds (final fit, early-stopping member)
| line | model | rounds |
|---|---|---|
| motor | peril_lgb.own_damage | 414 |
| motor | peril_lgb.third_party_prop | 281 |
| motor | peril_lgb.bodily_injury | 329 |
| motor | peril_lgb.theft | 222 |
| motor | peril_lgb.glass_hail | 279 |
| motor | lgb_tweedie | 133 |
| motor | peril_xgb.own_damage | 1,014 |
| motor | peril_xgb.third_party_prop | 687 |
| motor | peril_xgb.bodily_injury | 388 |
| motor | peril_xgb.theft | 845 |
| motor | peril_xgb.glass_hail | 389 |
| motor | xgb_tweedie | 281 |
| buildings | peril_lgb.storm | 191 |
| buildings | peril_lgb.flood | 254 |
| buildings | peril_lgb.escape_of_water | 622 |
| buildings | peril_lgb.subsidence | 89 |
| buildings | peril_lgb.fire | 25 |
| buildings | peril_lgb.accidental_damage | 150 |
| buildings | lgb_tweedie | 79 |
| buildings | peril_xgb.storm | 1,180 |
| buildings | peril_xgb.flood | 570 |
| buildings | peril_xgb.escape_of_water | 958 |
| buildings | peril_xgb.subsidence | 433 |
| buildings | peril_xgb.fire | 440 |
| buildings | peril_xgb.accidental_damage | 437 |
| buildings | xgb_tweedie | 282 |
| contents | peril_lgb.theft | 170 |
| contents | peril_lgb.escape_of_water | 171 |
| contents | peril_lgb.accidental_damage | 497 |
| contents | peril_lgb.flood | 303 |
| contents | lgb_tweedie | 129 |
| contents | peril_xgb.theft | 308 |
| contents | peril_xgb.escape_of_water | 271 |
| contents | peril_xgb.accidental_damage | 469 |
| contents | peril_xgb.flood | 599 |
| contents | xgb_tweedie | 218 |

## Features used
| line | model | features |
|---|---|---|
| motor | tree models | driver_age, years_licensed, ncb_years, vehicle_value_group, vehicle_age, make_model, engine_size_cc, body_type, transmission, seats, fuel_type, driver_assist, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, telematics_opt_in, telematics_score, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, previous_insurer, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer, noise_probe, young_driver, novice_driver, licence_ratio, telematics_missing, hist_pol_n, hist_pol_cost, hist_pol_exp, hist_cust_other_n, hist_addr_flood, hist_addr_water, hist_addr_subs, hist_addr_storm, hist_pol_rel, premium_index |
| motor | glm_freq.own_damage | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n |
| motor | glm_freq.third_party_prop | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n |
| motor | glm_freq.bodily_injury | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n |
| motor | glm_freq.theft | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n |
| motor | glm_freq.glass_hail | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n |
| motor | glm_sev | vehicle_value_group, cover_type, vehicle_age, region, driver_age, voluntary_excess, urban_density |
| buildings | tree models | policyholder_age, sum_insured, construction_type, occupancy, days_unoccupied, smoke_alarms, accidental_damage_cover, mortgage, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, previous_insurer, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer, noise_probe, log_sum_insured, flood_score, property_age, si_per_bedroom, subsidence_score, hist_pol_n, hist_pol_cost, hist_pol_exp, hist_cust_other_n, hist_addr_flood, hist_addr_water, hist_addr_subs, hist_addr_storm, hist_pol_rel, premium_index |
| buildings | glm_freq.storm | flood_zone, elevation_m, distance_to_river_km, sum_insured, bedrooms, property_age, property_type, construction_type, occupancy, prior_claims_5y, missed_payments_12m, region, urban_density, soil_type, trees_within_5m, roof_type, basement, listed_building, accidental_damage_cover, days_unoccupied, voluntary_excess, wind_exposure_index, hail_days, dry_summer_index, rainfall_mm, freezing_days, hist_pol_n, hist_addr_flood, hist_addr_water, hist_addr_storm |
| buildings | glm_freq.flood | flood_zone, elevation_m, distance_to_river_km, basement, sum_insured, region, rainfall_mm, hist_addr_flood |
| buildings | glm_freq.escape_of_water | flood_zone, elevation_m, distance_to_river_km, sum_insured, bedrooms, property_age, property_type, construction_type, occupancy, prior_claims_5y, missed_payments_12m, region, urban_density, soil_type, trees_within_5m, roof_type, basement, listed_building, accidental_damage_cover, days_unoccupied, voluntary_excess, wind_exposure_index, hail_days, dry_summer_index, rainfall_mm, freezing_days, hist_pol_n, hist_addr_flood, hist_addr_water, hist_addr_storm |
| buildings | glm_freq.subsidence | soil_type, trees_within_5m, dry_summer_index, property_age, sum_insured, region |
| buildings | glm_freq.fire | sum_insured, property_type, construction_type, occupancy, smoke_alarms, region, urban_density, listed_building, prior_claims_5y, hist_pol_n |
| buildings | glm_freq.accidental_damage | flood_zone, elevation_m, distance_to_river_km, sum_insured, bedrooms, property_age, property_type, construction_type, occupancy, prior_claims_5y, missed_payments_12m, region, urban_density, soil_type, trees_within_5m, roof_type, basement, listed_building, accidental_damage_cover, days_unoccupied, voluntary_excess, wind_exposure_index, hail_days, dry_summer_index, rainfall_mm, freezing_days, hist_pol_n, hist_addr_flood, hist_addr_water, hist_addr_storm |
| buildings | glm_sev | sum_insured, property_type, region, flood_zone, property_age, accidental_damage_cover |
| contents | tree models | policyholder_age, sum_insured, tenure, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, previous_insurer, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer, noise_probe, log_sum_insured, flood_score, si_per_person, hvi_per_10k_si, hist_pol_n, hist_pol_cost, hist_pol_exp, hist_cust_other_n, hist_addr_flood, hist_addr_water, hist_addr_subs, hist_addr_storm, hist_pol_rel, premium_index |
| contents | glm_freq.theft | flood_zone, elevation_m, distance_to_river_km, sum_insured, tenure, region, policyholder_age, prior_claims_5y, urban_density, missed_payments_12m, voluntary_excess, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, property_type, household_size, hist_pol_n, hist_cust_other_n, hist_addr_flood, hist_addr_water |
| contents | glm_freq.escape_of_water | flood_zone, elevation_m, distance_to_river_km, sum_insured, tenure, region, policyholder_age, prior_claims_5y, urban_density, missed_payments_12m, voluntary_excess, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, property_type, household_size, hist_pol_n, hist_cust_other_n, hist_addr_flood, hist_addr_water |
| contents | glm_freq.accidental_damage | flood_zone, elevation_m, distance_to_river_km, sum_insured, tenure, region, policyholder_age, prior_claims_5y, urban_density, missed_payments_12m, voluntary_excess, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, property_type, household_size, hist_pol_n, hist_cust_other_n, hist_addr_flood, hist_addr_water |
| contents | glm_freq.flood | flood_zone, elevation_m, distance_to_river_km, property_type, sum_insured, region, rainfall_mm, hist_addr_flood |
| contents | glm_sev | sum_insured, high_value_items, region, tenure, accidental_damage_cover |

