# Iteration SAM 4 (`sam_iteration_04`)

**Run id** `20261022_1734` | **Generated** 2026-10-22 21:26 | **Git commit** `e41be93 + uncommitted changes in R/` | **Submission file** `submission_20261022_1734.csv`

**Change in this iteration:** SAM 3 with the IBNR study's recommended reporting pattern (chain ladder per line x peril; SAM 3 ECDF for motor bodily_injury) applied per row: effective exposure = exposure x mean reported share over the row's days (was exposure / policy-year factor); IBNR-adjusted counts, line Tweedie targets and developed validation actuals use the same row share. Models, features, tuning and blend unchanged from SAM 3; open-claim case estimates used as final.

> **Warning:** generated from uncommitted code.

## Phase 0 - is the old framework off track?
### Predicted 2025 cost per exposure-year of past submissions vs their public D2

| submission | motor | buildings | contents | public_d2 |
|---|---|---|---|---|
| #1 iteration_01 | 518.1190 | 425.0838 | 113.2029 | 0.1190 |
| #2 iteration_02 | 498.8029 | 434.2517 | 119.1349 | 0.1215 |
| #3 sam_iteration_01 | 518.1190 | 411.7918 | 111.8020 | 0.1188 |
| this run (sam_iteration_04) | 607.4120 | 489.2413 | 125.8341 |  |

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
| 0.8500 | 0.0997 | 0.1356 |
| 0.9000 | 0.1023 | 0.1381 |
| 0.9500 | 0.1039 | 0.1396 |
| 1 | 0.1047 | 0.1404 |
| 1.0500 | 0.1047 | 0.1404 |
| 1.1000 | 0.1041 | 0.1398 |
| 1.1500 | 0.1030 | 0.1388 |

## Reproducibility
Submission MD5 `b928f7887f9e97c403de6d9d3da858a1`. The submitted blend per line is saved in `models/sam_iteration_04/fitted/<line>_blend.rds` (boosters embedded). Prepared data: `data/sam04/` (rebuild with this script).

```r
source("R/0_setup.R"); source("R/model_io.R")
art  <- load_model("models/sam_iteration_04/fitted", "motor_blend")
pred <- pmax(score_model(art, arrow::read_parquet("data/sam04/test_motor.parquet")), 0)
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
| XGBoost line Tweedie | motor: max_depth=3, learning_rate=0.05, min_child_weight=50, subsample=0.7, colsample_bytree=0.8, reg_lambda=5, tweedie_variance_power=1.7; buildings: max_depth=3, learning_rate=0.03, min_child_weight=200, subsample=0.8, colsample_bytree=0.7, reg_lambda=10, tweedie_variance_power=1.5; contents: max_depth=3, learning_rate=0.05, min_child_weight=500, subsample=0.7, colsample_bytree=0.7, reg_lambda=1, tweedie_variance_power=1.5 |
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
Policy-year IBNR factor (reporting only; the models use the row-level share). SAM 3 vs SAM 4:

| line | peril | sam03_factor_2021 | sam03_factor_2022 | sam03_factor_2023 | sam03_factor_2024 | sam04_factor_2021 | sam04_factor_2022 | sam04_factor_2023 | sam04_factor_2024 |
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
| motor | 14 | 3 | 0.0500 | 50 | 0.7000 | 0.8000 | 5 | 1.7000 | 0.0564 | 262 | 21 | 1 |
| motor | 6 | 4 | 0.0300 | 500 | 0.8000 | 0.7000 | 1 | 1.7000 | 0.0551 | 301 | 25 | 2 |
| motor | 11 | 4 | 0.0500 | 50 | 0.7000 | 0.7000 | 1 | 1.3000 | 0.0549 | 231 | 20 | 3 |
| motor | 12 | 3 | 0.0300 | 50 | 0.9000 | 0.6000 | 5 | 1.3000 | 0.0547 | 492 | 35 | 4 |
| motor | 15 | 4 | 0.0300 | 50 | 0.9000 | 0.7000 | 1 | 1.3000 | 0.0545 | 410 | 32 | 5 |
| buildings | 25 | 3 | 0.0300 | 200 | 0.8000 | 0.7000 | 10 | 1.5000 | 0.0844 | 239 | 14 | 1 |
| buildings | 15 | 4 | 0.0300 | 500 | 0.8000 | 0.6000 | 1 | 1.3000 | 0.0843 | 239 | 15 | 2 |
| buildings | 12 | 3 | 0.0500 | 200 | 0.7000 | 0.7000 | 5 | 1.3000 | 0.0840 | 185 | 13 | 3 |
| buildings | 10 | 3 | 0.0300 | 200 | 0.7000 | 0.6000 | 10 | 1.3000 | 0.0837 | 260 | 16 | 4 |
| buildings | 16 | 3 | 0.0300 | 200 | 0.8000 | 0.8000 | 1 | 1.5000 | 0.0832 | 240 | 14 | 5 |
| contents | 3 | 3 | 0.0500 | 500 | 0.7000 | 0.7000 | 1 | 1.5000 | 0.0593 | 181 | 12 | 1 |
| contents | 11 | 3 | 0.0300 | 500 | 0.8000 | 0.6000 | 5 | 1.5000 | 0.0583 | 277 | 16 | 2 |
| contents | 12 | 5 | 0.0500 | 50 | 0.9000 | 0.8000 | 1 | 1.3000 | 0.0582 | 101 | 9 | 3 |
| contents | 21 | 3 | 0.0500 | 50 | 0.7000 | 0.8000 | 1 | 1.3000 | 0.0580 | 192 | 12 | 4 |
| contents | 19 | 3 | 0.0300 | 500 | 0.8000 | 0.7000 | 5 | 1.3000 | 0.0580 | 320 | 19 | 5 |

## Validation - local Kaggle metric (Tweedie D2, p = 1.5)
`d2` = raw (exposure-rate baseline, as Kaggle is believed to score), `d2_flat` = flat-mean baseline, `d2_cal` = after rescaling predictions to the actual total (ranking only), `ae_developed` = predicted / IBNR-developed actual (level). 2024 actuals are immature.

### Combined, all lines
| model | d2_2022 | d2_2023 | d2_2024 | d2_flat_2022 | d2_flat_2023 | d2_flat_2024 | ae_developed_2022 | ae_developed_2023 | ae_developed_2024 |
|---|---|---|---|---|---|---|---|---|---|
| legacy_glm | 0.1054 | 0.1059 | 0.0950 | 0.1383 | 0.1416 | 0.1268 | 0.9912 | 0.9480 | 0.9757 |
| blend | 0.1145 | 0.1047 | 0.0984 | 0.1470 | 0.1404 | 0.1301 | 0.9686 | 0.9606 | 1.0317 |
| peril_glm_notrend | 0.1108 | 0.1032 | 0.0957 | 0.1434 | 0.1390 | 0.1274 | 0.9701 | 0.9423 | 0.9804 |
| peril_glm | 0.1108 | 0.1030 | 0.0946 | 0.1434 | 0.1388 | 0.1264 | 0.9701 | 0.9616 | 1.0316 |
| legacy_xgb | 0.1035 | 0.1018 | 0.0982 | 0.1364 | 0.1376 | 0.1299 | 0.8694 | 0.8571 | 0.9222 |
| peril_xgb | 0.1145 | 0.1016 | 0.0982 | 0.1470 | 0.1374 | 0.1298 | 0.9675 | 0.9604 | 1.0323 |
| xgb_tweedie | 0.1075 | 0.1009 | 0.0967 | 0.1403 | 0.1367 | 0.1284 | 0.9701 | 0.9616 | 1.0316 |
| peril_lgb | 0.1086 | 0.0928 | 0.0944 | 0.1413 | 0.1290 | 0.1262 | 0.9677 | 0.9599 | 1.0306 |
| lgb_tweedie | 0.1011 | 0.0908 | 0.0906 | 0.1341 | 0.1271 | 0.1225 | 0.9701 | 0.9616 | 1.0316 |
| burn_trend | 0.0553 | 0.0492 | 0.0352 | 0.0899 | 0.0871 | 0.0691 | 0.9713 | 0.9743 | 1.0431 |
| burn_cost | 0.0553 | 0.0488 | 0.0371 | 0.0899 | 0.0867 | 0.0709 | 0.9712 | 0.9300 | 0.9588 |

### Mean over folds by line
| line | model | d2 | d2_cal | d2_flat | ae_developed |
|---|---|---|---|---|---|
| buildings | blend | 0.0708 | 0.0710 | 0.1073 | 0.9653 |
| buildings | peril_xgb | 0.0703 | 0.0705 | 0.1068 | 0.9641 |
| buildings | legacy_xgb | 0.0664 | 0.0675 | 0.1031 | 0.8748 |
| buildings | peril_glm | 0.0670 | 0.0672 | 0.1036 | 0.9682 |
| buildings | peril_glm_notrend | 0.0670 | 0.0672 | 0.1037 | 0.9294 |
| buildings | peril_lgb | 0.0670 | 0.0671 | 0.1036 | 0.9631 |
| buildings | xgb_tweedie | 0.0664 | 0.0665 | 0.1031 | 0.9682 |
| buildings | lgb_tweedie | 0.0620 | 0.0622 | 0.0988 | 0.9682 |
| buildings | legacy_glm | 0.0597 | 0.0595 | 0.0967 | 0.9819 |
| buildings | burn_trend | -0.0002 | 0 | 0.0392 | 0.9502 |
| buildings | burn_cost | -0.0008 | 0 | 0.0386 | 0.8968 |
| contents | blend | 0.0663 | 0.0666 | 0.0970 | 0.9802 |
| contents | peril_xgb | 0.0648 | 0.0651 | 0.0956 | 0.9800 |
| contents | xgb_tweedie | 0.0630 | 0.0634 | 0.0938 | 0.9803 |
| contents | peril_glm_notrend | 0.0626 | 0.0632 | 0.0935 | 0.9541 |
| contents | peril_glm | 0.0628 | 0.0631 | 0.0936 | 0.9803 |
| contents | peril_lgb | 0.0622 | 0.0625 | 0.0930 | 0.9796 |
| contents | legacy_glm | 0.0598 | 0.0605 | 0.0907 | 0.9494 |
| contents | legacy_xgb | 0.0570 | 0.0590 | 0.0881 | 0.9030 |
| contents | lgb_tweedie | 0.0569 | 0.0574 | 0.0880 | 0.9803 |
| contents | burn_trend | -0.0007 | 0 | 0.0322 | 0.9687 |
| contents | burn_cost | -0.0010 | 0 | 0.0319 | 0.9361 |
| motor | legacy_glm | 0.0519 | 0.0538 | 0.0889 | 0.9726 |
| motor | blend | 0.0498 | 0.0537 | 0.0869 | 1.0038 |
| motor | peril_xgb | 0.0482 | 0.0522 | 0.0854 | 1.0042 |
| motor | peril_glm_notrend | 0.0480 | 0.0505 | 0.0852 | 0.9893 |
| motor | peril_glm | 0.0470 | 0.0505 | 0.0843 | 1.0036 |
| motor | legacy_xgb | 0.0461 | 0.0498 | 0.0834 | 0.8873 |
| motor | xgb_tweedie | 0.0450 | 0.0488 | 0.0823 | 1.0036 |
| motor | peril_lgb | 0.0381 | 0.0421 | 0.0757 | 1.0036 |
| motor | lgb_tweedie | 0.0338 | 0.0377 | 0.0716 | 1.0036 |
| motor | burn_cost | -0.0026 | 0 | 0.0366 | 0.9924 |
| motor | burn_trend | -0.0044 | 0 | 0.0348 | 1.0305 |

### Raw D2 by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.0662 | 0.0714 | 0.0747 |
| buildings | burn_cost | -0.0004 | -0.0009 | -0.0010 |
| buildings | burn_trend | -0.0004 | 0.0000 | -0.0001 |
| buildings | legacy_glm | 0.0483 | 0.0622 | 0.0687 |
| buildings | legacy_xgb | 0.0564 | 0.0699 | 0.0730 |
| buildings | lgb_tweedie | 0.0582 | 0.0613 | 0.0663 |
| buildings | peril_glm | 0.0627 | 0.0685 | 0.0697 |
| buildings | peril_glm_notrend | 0.0627 | 0.0685 | 0.0698 |
| buildings | peril_lgb | 0.0634 | 0.0660 | 0.0714 |
| buildings | peril_xgb | 0.0653 | 0.0709 | 0.0747 |
| buildings | xgb_tweedie | 0.0602 | 0.0663 | 0.0726 |
| contents | blend | 0.0638 | 0.0710 | 0.0641 |
| contents | burn_cost | 0.0000 | -0.0022 | -0.0009 |
| contents | burn_trend | 0.0000 | -0.0021 | -0.0001 |
| contents | legacy_glm | 0.0555 | 0.0631 | 0.0608 |
| contents | legacy_xgb | 0.0511 | 0.0611 | 0.0589 |
| contents | lgb_tweedie | 0.0519 | 0.0613 | 0.0576 |
| contents | peril_glm | 0.0585 | 0.0679 | 0.0620 |
| contents | peril_glm_notrend | 0.0585 | 0.0678 | 0.0616 |
| contents | peril_lgb | 0.0609 | 0.0671 | 0.0585 |
| contents | peril_xgb | 0.0627 | 0.0697 | 0.0619 |
| contents | xgb_tweedie | 0.0609 | 0.0659 | 0.0621 |
| motor | blend | 0.0596 | 0.0435 | 0.0463 |
| motor | burn_cost | -0.0001 | -0.0002 | -0.0075 |
| motor | burn_trend | -0.0001 | -0.0000 | -0.0131 |
| motor | legacy_glm | 0.0553 | 0.0557 | 0.0446 |
| motor | legacy_xgb | 0.0468 | 0.0420 | 0.0494 |
| motor | lgb_tweedie | 0.0401 | 0.0239 | 0.0375 |
| motor | peril_glm | 0.0557 | 0.0431 | 0.0422 |
| motor | peril_glm_notrend | 0.0557 | 0.0436 | 0.0448 |
| motor | peril_lgb | 0.0496 | 0.0227 | 0.0419 |
| motor | peril_xgb | 0.0605 | 0.0376 | 0.0465 |
| motor | xgb_tweedie | 0.0495 | 0.0408 | 0.0447 |

### Calibrated D2 by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.0664 | 0.0714 | 0.0751 |
| buildings | burn_cost | 0 | 0 | 0 |
| buildings | burn_trend | 0 | 0 | 0 |
| buildings | legacy_glm | 0.0474 | 0.0624 | 0.0687 |
| buildings | legacy_xgb | 0.0589 | 0.0702 | 0.0732 |
| buildings | lgb_tweedie | 0.0583 | 0.0614 | 0.0669 |
| buildings | peril_glm | 0.0631 | 0.0685 | 0.0700 |
| buildings | peril_glm_notrend | 0.0631 | 0.0686 | 0.0698 |
| buildings | peril_lgb | 0.0636 | 0.0660 | 0.0717 |
| buildings | peril_xgb | 0.0655 | 0.0709 | 0.0751 |
| buildings | xgb_tweedie | 0.0603 | 0.0663 | 0.0730 |
| contents | blend | 0.0638 | 0.0719 | 0.0641 |
| contents | burn_cost | 0 | 0 | 0 |
| contents | burn_trend | 0 | 0 | 0 |
| contents | legacy_glm | 0.0554 | 0.0647 | 0.0614 |
| contents | legacy_xgb | 0.0533 | 0.0643 | 0.0595 |
| contents | lgb_tweedie | 0.0520 | 0.0623 | 0.0578 |
| contents | peril_glm | 0.0584 | 0.0691 | 0.0619 |
| contents | peril_glm_notrend | 0.0584 | 0.0693 | 0.0620 |
| contents | peril_lgb | 0.0609 | 0.0680 | 0.0585 |
| contents | peril_xgb | 0.0627 | 0.0708 | 0.0618 |
| contents | xgb_tweedie | 0.0609 | 0.0671 | 0.0622 |
| motor | blend | 0.0595 | 0.0438 | 0.0577 |
| motor | burn_cost | 0 | 0 | 0 |
| motor | burn_trend | 0 | 0 | 0 |
| motor | legacy_glm | 0.0556 | 0.0560 | 0.0499 |
| motor | legacy_xgb | 0.0507 | 0.0462 | 0.0525 |
| motor | lgb_tweedie | 0.0402 | 0.0240 | 0.0487 |
| motor | peril_glm | 0.0559 | 0.0435 | 0.0522 |
| motor | peril_glm_notrend | 0.0559 | 0.0439 | 0.0518 |
| motor | peril_lgb | 0.0496 | 0.0231 | 0.0536 |
| motor | peril_xgb | 0.0604 | 0.0380 | 0.0580 |
| motor | xgb_tweedie | 0.0496 | 0.0412 | 0.0557 |

### Level: predicted / developed actual by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.958 | 0.995 | 0.943 |
| buildings | burn_cost | 0.952 | 0.908 | 0.830 |
| buildings | burn_trend | 0.952 | 0.971 | 0.927 |
| buildings | legacy_glm | 1.049 | 0.978 | 0.918 |
| buildings | legacy_xgb | 0.868 | 0.899 | 0.857 |
| buildings | lgb_tweedie | 0.962 | 0.999 | 0.944 |
| buildings | peril_glm | 0.962 | 0.999 | 0.944 |
| buildings | peril_glm_notrend | 0.962 | 0.943 | 0.883 |
| buildings | peril_lgb | 0.956 | 0.992 | 0.941 |
| buildings | peril_xgb | 0.956 | 0.993 | 0.943 |
| buildings | xgb_tweedie | 0.962 | 0.999 | 0.944 |
| contents | blend | 1.009 | 0.923 | 1.009 |
| contents | burn_cost | 1.000 | 0.900 | 0.908 |
| contents | burn_trend | 1.000 | 0.903 | 1.004 |
| contents | legacy_glm | 1.009 | 0.917 | 0.922 |
| contents | legacy_xgb | 0.910 | 0.876 | 0.923 |
| contents | lgb_tweedie | 1.008 | 0.923 | 1.009 |
| contents | peril_glm | 1.008 | 0.923 | 1.009 |
| contents | peril_glm_notrend | 1.008 | 0.919 | 0.934 |
| contents | peril_lgb | 1.008 | 0.923 | 1.008 |
| contents | peril_xgb | 1.009 | 0.922 | 1.009 |
| contents | xgb_tweedie | 1.008 | 0.923 | 1.009 |
| motor | blend | 0.969 | 0.948 | 1.095 |
| motor | burn_cost | 0.977 | 0.946 | 1.054 |
| motor | burn_trend | 0.977 | 0.987 | 1.128 |
| motor | legacy_glm | 0.958 | 0.936 | 1.023 |
| motor | legacy_xgb | 0.864 | 0.832 | 0.966 |
| motor | lgb_tweedie | 0.969 | 0.947 | 1.094 |
| motor | peril_glm | 0.969 | 0.947 | 1.094 |
| motor | peril_glm_notrend | 0.969 | 0.945 | 1.053 |
| motor | peril_lgb | 0.968 | 0.948 | 1.095 |
| motor | peril_xgb | 0.968 | 0.948 | 1.096 |
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
| 2022 | buildings | lgb_tweedie | 0.1537 | 0.0583 | 0.0954 |
| 2023 | buildings | lgb_tweedie | 0.1075 | 0.0614 | 0.0461 |
| 2024 | buildings | lgb_tweedie | 0.1107 | 0.0669 | 0.0438 |
| 2022 | buildings | peril_glm | 0.0780 | 0.0631 | 0.0149 |
| 2023 | buildings | peril_glm | 0.0767 | 0.0685 | 0.0082 |
| 2024 | buildings | peril_glm | 0.0775 | 0.0700 | 0.0075 |
| 2022 | buildings | peril_lgb | 0.1239 | 0.0636 | 0.0603 |
| 2023 | buildings | peril_lgb | 0.1202 | 0.0660 | 0.0542 |
| 2024 | buildings | peril_lgb | 0.1061 | 0.0717 | 0.0343 |
| 2022 | buildings | peril_xgb | 0.1020 | 0.0655 | 0.0365 |
| 2023 | buildings | peril_xgb | 0.0939 | 0.0709 | 0.0231 |
| 2024 | buildings | peril_xgb | 0.0902 | 0.0751 | 0.0151 |
| 2022 | buildings | xgb_tweedie | 0.1130 | 0.0603 | 0.0527 |
| 2023 | buildings | xgb_tweedie | 0.0838 | 0.0663 | 0.0174 |
| 2024 | buildings | xgb_tweedie | 0.1072 | 0.0730 | 0.0342 |
| 2022 | contents | lgb_tweedie | 0.1083 | 0.0520 | 0.0562 |
| 2023 | contents | lgb_tweedie | 0.1206 | 0.0623 | 0.0584 |
| 2024 | contents | lgb_tweedie | 0.1190 | 0.0578 | 0.0612 |
| 2022 | contents | peril_glm | 0.0877 | 0.0584 | 0.0293 |
| 2023 | contents | peril_glm | 0.0679 | 0.0691 | -0.0013 |
| 2024 | contents | peril_glm | 0.0769 | 0.0619 | 0.0150 |
| 2022 | contents | peril_lgb | 0.1520 | 0.0609 | 0.0911 |
| 2023 | contents | peril_lgb | 0.0971 | 0.0680 | 0.0290 |
| 2024 | contents | peril_lgb | 0.0968 | 0.0585 | 0.0383 |
| 2022 | contents | peril_xgb | 0.1047 | 0.0627 | 0.0419 |
| 2023 | contents | peril_xgb | 0.0894 | 0.0708 | 0.0186 |
| 2024 | contents | peril_xgb | 0.0922 | 0.0618 | 0.0304 |
| 2022 | contents | xgb_tweedie | 0.1145 | 0.0609 | 0.0536 |
| 2023 | contents | xgb_tweedie | 0.1038 | 0.0671 | 0.0368 |
| 2024 | contents | xgb_tweedie | 0.1047 | 0.0622 | 0.0425 |
| 2022 | motor | lgb_tweedie | 0.1073 | 0.0402 | 0.0671 |
| 2023 | motor | lgb_tweedie | 0.0717 | 0.0240 | 0.0477 |
| 2024 | motor | lgb_tweedie | 0.1187 | 0.0487 | 0.0700 |
| 2022 | motor | peril_glm | 0.0533 | 0.0559 | -0.0026 |
| 2023 | motor | peril_glm | 0.0583 | 0.0435 | 0.0148 |
| 2024 | motor | peril_glm | 0.0521 | 0.0522 | -0.0001 |
| 2022 | motor | peril_lgb | 0.0827 | 0.0496 | 0.0331 |
| 2023 | motor | peril_lgb | 0.0718 | 0.0231 | 0.0487 |
| 2024 | motor | peril_lgb | 0.0520 | 0.0536 | -0.0017 |
| 2022 | motor | peril_xgb | 0.0743 | 0.0604 | 0.0139 |
| 2023 | motor | peril_xgb | 0.0759 | 0.0380 | 0.0378 |
| 2024 | motor | peril_xgb | 0.0575 | 0.0580 | -0.0005 |
| 2022 | motor | xgb_tweedie | 0.0861 | 0.0496 | 0.0365 |
| 2023 | motor | xgb_tweedie | 0.0911 | 0.0412 | 0.0499 |
| 2024 | motor | xgb_tweedie | 0.0906 | 0.0557 | 0.0349 |

### Segment A/E of the blend (level removed per line; 1 = right relative price)
| line | segment | level | exposure | ae_2023 | ae_2024 |
|---|---|---|---|---|---|
| buildings | hist_pol_n | 0 | 278,461.014 | 0.969 | 0.967 |
| buildings | hist_pol_n | 1 | 19,745.315 | 1.277 | 1.216 |
| buildings | hist_pol_n | 2 | 1,540.868 | 1.761 | 1.390 |
| buildings | hist_pol_n | 3 | 157.622 | 2.088 | 1.394 |
| buildings | new_business | FALSE | 272,802.258 | 1.008 | 0.992 |
| buildings | new_business | TRUE | 27,102.562 | 0.919 | 1.082 |
| contents | hist_pol_n | 0 | 280,343.293 | 0.967 | 0.988 |
| contents | hist_pol_n | 1 | 18,140.847 | 1.367 | 1.099 |
| contents | hist_pol_n | 2 | 1,350.901 | 1.593 | 0.883 |
| contents | hist_pol_n | 3 | 106.671 | 0.149 | 2.266 |
| contents | new_business | FALSE | 272,872.805 | 0.990 | 1.008 |
| contents | new_business | TRUE | 27,068.907 | 1.101 | 0.917 |
| motor | driver_age | [0,25) | 53,987.041 | 0.828 | 0.923 |
| motor | driver_age | [25,35) | 73,253.537 | 1.512 | 1.013 |
| motor | driver_age | [35,50) | 73,266.926 | 0.902 | 1.017 |
| motor | driver_age | [50,65) | 73,917.564 | 0.907 | 1.017 |
| motor | driver_age | [65,Inf) | 125,042.414 | 0.924 | 1.047 |
| motor | hist_pol_n | 0 | 322,217.088 | 1.030 | 0.969 |
| motor | hist_pol_n | 1 | 59,976.984 | 0.843 | 1.056 |
| motor | hist_pol_n | 2 | 12,763.726 | 1.013 | 0.955 |
| motor | hist_pol_n | 3 | 4,509.685 | 1.366 | 1.370 |
| motor | ncb_years | (-Inf,0] | 17,642.841 | 0.983 | 1.084 |
| motor | ncb_years | (0,3] | 92,279.929 | 0.853 | 0.924 |
| motor | ncb_years | (3,6] | 72,292.312 | 1.548 | 1.028 |
| motor | ncb_years | (6,9] | 60,441.992 | 0.914 | 1.030 |
| motor | ncb_years | (9, Inf] | 156,810.408 | 0.917 | 1.033 |
| motor | new_business | FALSE | 363,280.252 | 1.007 | 1.004 |
| motor | new_business | TRUE | 36,187.230 | 0.951 | 0.970 |
| motor | vehicle_age | (-Inf,3] | 28,076.293 | 0.949 | 1.071 |
| motor | vehicle_age | (12, Inf] | 64,911.699 | 0.822 | 0.863 |
| motor | vehicle_age | (3,7] | 153,642.485 | 1.153 | 1.050 |
| motor | vehicle_age | (7,12] | 142,880.718 | 0.916 | 1.010 |

## Blend weights
| line | lgb_tweedie | peril_glm | peril_lgb | peril_xgb | xgb_tweedie |
|---|---|---|---|---|---|
| buildings | 0 | 0.20 | 0 | 0.70 | 0.10 |
| contents | 0 | 0.30 | 0 | 0.40 | 0.30 |
| motor | 0 | 0.40 | 0 | 0.40 | 0.20 |

## 2025 test predictions (final fit on 2021-24)
| line | model | weight | predicted_total | predicted_burn_cost | p50_row | p90_row | p99_row | max_row |
|---|---|---|---|---|---|---|---|---|
| motor | peril_glm | 0.40 | 121,352,763.49 | 606.81 | 377.13 | 934.11 | 2,072.52 | 6,907.50 |
| motor | peril_lgb | 0 | 121,558,586.40 | 607.84 | 401.92 | 876.39 | 1,977.17 | 13,575.64 |
| motor | peril_xgb | 0.40 | 121,651,942.50 | 608.31 | 394.46 | 895.40 | 2,009.82 | 8,554.24 |
| motor | lgb_tweedie | 0 | 121,352,763.49 | 606.81 | 415.54 | 872.82 | 1,756.19 | 6,142.18 |
| motor | xgb_tweedie | 0.20 | 121,352,763.49 | 606.81 | 388.04 | 915.22 | 2,006.32 | 6,799.64 |
| motor | burn_trend |  | 126,098,666.96 | 630.55 | 630.55 | 630.55 | 630.55 | 630.55 |
| motor | burn_cost |  | 108,930,584.85 | 544.70 | 544.70 | 544.70 | 544.70 | 544.70 |
| motor | blend | 1 | 121,472,435.09 | 607.41 | 389.59 | 912.89 | 1,985.85 | 7,162.38 |
| buildings | peril_glm | 0.20 | 73,594,450.06 | 489.83 | 319.03 | 704.00 | 2,111.42 | 8,664.58 |
| buildings | peril_lgb | 0 | 73,299,682.91 | 487.87 | 318.40 | 686.33 | 2,200.05 | 23,827.68 |
| buildings | peril_xgb | 0.70 | 73,467,415.36 | 488.99 | 310.98 | 716.41 | 2,165.11 | 13,482.44 |
| buildings | lgb_tweedie | 0 | 73,594,450.06 | 489.83 | 317.13 | 711.05 | 2,130.95 | 6,998.74 |
| buildings | xgb_tweedie | 0.10 | 73,594,450.06 | 489.83 | 307.24 | 726.87 | 2,210.92 | 12,960.88 |
| buildings | burn_trend |  | 75,510,607.64 | 502.59 | 502.59 | 502.59 | 502.59 | 502.59 |
| buildings | burn_cost |  | 62,751,650.57 | 417.67 | 417.67 | 417.67 | 417.67 | 417.67 |
| buildings | blend | 1 | 73,505,525.77 | 489.24 | 314.06 | 711.35 | 2,149.24 | 11,582.71 |
| contents | peril_glm | 0.30 | 18,918,347.25 | 126.02 | 77.58 | 188.53 | 522.70 | 3,830.03 |
| contents | peril_lgb | 0 | 18,857,466.32 | 125.61 | 78.61 | 180.59 | 538.93 | 6,345.41 |
| contents | peril_xgb | 0.40 | 18,849,191.35 | 125.56 | 78.58 | 182.19 | 531.41 | 3,539.59 |
| contents | lgb_tweedie | 0 | 18,918,347.25 | 126.02 | 80.00 | 187.35 | 493.05 | 3,322.52 |
| contents | xgb_tweedie | 0.30 | 18,918,347.25 | 126.02 | 79.02 | 185.39 | 506.14 | 4,002.78 |
| contents | burn_trend |  | 18,969,878.59 | 126.36 | 126.36 | 126.36 | 126.36 | 126.36 |
| contents | burn_cost |  | 16,702,409.98 | 111.26 | 111.26 | 111.26 | 111.26 | 111.26 |
| contents | blend | 1 | 18,890,684.89 | 125.83 | 78.82 | 184.55 | 515.88 | 3,005.26 |

### Level vs previous submissions
| submission | motor | buildings | contents | public_d2 |
|---|---|---|---|---|
| #1 iteration_01 | 518.12 | 425.08 | 113.20 | 0.12 |
| #2 iteration_02 | 498.80 | 434.25 | 119.13 | 0.12 |
| #3 sam_iteration_01 | 518.12 | 411.79 | 111.80 | 0.12 |
| this run (sam_iteration_04) | 607.41 | 489.24 | 125.83 |  |

## Variable importance (line Tweedie bags)
![](tree_importance.png)

Rank of the random noise feature:

| line | model | noise_rank |
|---|---|---|
| motor | xgb_tweedie | 31 |
| buildings | lgb_tweedie | 27 |
| buildings | xgb_tweedie | 24 |
| contents | lgb_tweedie | 31 |
| contents | xgb_tweedie | 30 |

| Feature | Gain | rank | line | model |
|---|---|---|---|---|
| flood_score | 0.2073 | 1 | buildings | lgb_tweedie |
| previous_insurer | 0.1764 | 2 | buildings | lgb_tweedie |
| sum_insured | 0.0796 | 3 | buildings | lgb_tweedie |
| occupation | 0.0688 | 4 | buildings | lgb_tweedie |
| elevation_m | 0.0657 | 5 | buildings | lgb_tweedie |
| flood_zone | 0.0631 | 6 | buildings | lgb_tweedie |
| energy_rating | 0.0355 | 7 | buildings | lgb_tweedie |
| log_sum_insured | 0.0347 | 8 | buildings | lgb_tweedie |
| region | 0.0266 | 9 | buildings | lgb_tweedie |
| property_age | 0.0246 | 10 | buildings | lgb_tweedie |
| year_built | 0.0185 | 11 | buildings | lgb_tweedie |
| distance_to_river_km | 0.0179 | 12 | buildings | lgb_tweedie |
| prior_claims_5y | 0.0177 | 13 | buildings | lgb_tweedie |
| soil_type | 0.0132 | 14 | buildings | lgb_tweedie |
| dry_summer_index | 0.0128 | 15 | buildings | lgb_tweedie |
| flood_score | 0.2376 | 1 | buildings | xgb_tweedie |
| sum_insured | 0.1038 | 2 | buildings | xgb_tweedie |
| flood_zone | 0.0806 | 3 | buildings | xgb_tweedie |
| elevation_m | 0.0765 | 4 | buildings | xgb_tweedie |
| log_sum_insured | 0.0373 | 5 | buildings | xgb_tweedie |
| energy_rating | 0.0327 | 6 | buildings | xgb_tweedie |
| property_age | 0.0277 | 7 | buildings | xgb_tweedie |
| prior_claims_5y | 0.0267 | 8 | buildings | xgb_tweedie |
| distance_to_river_km | 0.0244 | 9 | buildings | xgb_tweedie |
| dry_summer_index | 0.0221 | 10 | buildings | xgb_tweedie |
| year_built | 0.0192 | 11 | buildings | xgb_tweedie |
| previous_insurer | 0.0159 | 12 | buildings | xgb_tweedie |
| soil_type | 0.0147 | 13 | buildings | xgb_tweedie |
| construction_type | 0.0138 | 14 | buildings | xgb_tweedie |
| rainfall_mm | 0.0128 | 15 | buildings | xgb_tweedie |
| flood_score | 0.1812 | 1 | contents | lgb_tweedie |
| previous_insurer | 0.1809 | 2 | contents | lgb_tweedie |
| sum_insured | 0.1298 | 3 | contents | lgb_tweedie |
| occupation | 0.0748 | 4 | contents | lgb_tweedie |
| flood_zone | 0.0676 | 5 | contents | lgb_tweedie |
| elevation_m | 0.0490 | 6 | contents | lgb_tweedie |
| region | 0.0476 | 7 | contents | lgb_tweedie |
| log_sum_insured | 0.0216 | 8 | contents | lgb_tweedie |
| prior_claims_5y | 0.0194 | 9 | contents | lgb_tweedie |
| voluntary_excess | 0.0193 | 10 | contents | lgb_tweedie |
| urban_density | 0.0174 | 11 | contents | lgb_tweedie |
| customer_age | 0.0171 | 12 | contents | lgb_tweedie |
| accidental_damage_cover | 0.0127 | 13 | contents | lgb_tweedie |
| distance_to_river_km | 0.0122 | 14 | contents | lgb_tweedie |
| policyholder_age | 0.0108 | 15 | contents | lgb_tweedie |
| flood_score | 0.1979 | 1 | contents | xgb_tweedie |
| sum_insured | 0.1503 | 2 | contents | xgb_tweedie |
| flood_zone | 0.1020 | 3 | contents | xgb_tweedie |
| elevation_m | 0.0755 | 4 | contents | xgb_tweedie |
| log_sum_insured | 0.0404 | 5 | contents | xgb_tweedie |
| region | 0.0284 | 6 | contents | xgb_tweedie |
| customer_age | 0.0257 | 7 | contents | xgb_tweedie |
| urban_density | 0.0243 | 8 | contents | xgb_tweedie |
| si_per_person | 0.0241 | 9 | contents | xgb_tweedie |
| voluntary_excess | 0.0236 | 10 | contents | xgb_tweedie |
| prior_claims_5y | 0.0232 | 11 | contents | xgb_tweedie |
| distance_to_river_km | 0.0196 | 12 | contents | xgb_tweedie |
| policyholder_age | 0.0177 | 13 | contents | xgb_tweedie |
| accidental_damage_cover | 0.0145 | 14 | contents | xgb_tweedie |
| previous_insurer | 0.0139 | 15 | contents | xgb_tweedie |
| make_model | 0.4061 | 1 | motor | lgb_tweedie |
| ncb_years | 0.1720 | 2 | motor | lgb_tweedie |
| customer_age | 0.0673 | 3 | motor | lgb_tweedie |
| previous_insurer | 0.0531 | 4 | motor | lgb_tweedie |
| annual_mileage | 0.0452 | 5 | motor | lgb_tweedie |
| years_licensed | 0.0377 | 6 | motor | lgb_tweedie |
| driver_age | 0.0375 | 7 | motor | lgb_tweedie |
| hist_pol_rel | 0.0338 | 8 | motor | lgb_tweedie |
| prior_claims_5y | 0.0193 | 9 | motor | lgb_tweedie |
| cover_type | 0.0182 | 10 | motor | lgb_tweedie |
| region | 0.0155 | 11 | motor | lgb_tweedie |
| hist_pol_cost | 0.0131 | 12 | motor | lgb_tweedie |
| voluntary_excess | 0.0131 | 13 | motor | lgb_tweedie |
| occupation | 0.0122 | 14 | motor | lgb_tweedie |
| vehicle_age | 0.0112 | 15 | motor | lgb_tweedie |
| ncb_years | 0.2475 | 1 | motor | xgb_tweedie |
| annual_mileage | 0.0666 | 2 | motor | xgb_tweedie |
| years_licensed | 0.0603 | 3 | motor | xgb_tweedie |
| make_model | 0.0597 | 4 | motor | xgb_tweedie |
| driver_age | 0.0536 | 5 | motor | xgb_tweedie |
| customer_age | 0.0486 | 6 | motor | xgb_tweedie |
| hist_pol_rel | 0.0437 | 7 | motor | xgb_tweedie |
| cover_type | 0.0325 | 8 | motor | xgb_tweedie |
| prior_claims_5y | 0.0307 | 9 | motor | xgb_tweedie |
| vehicle_age | 0.0264 | 10 | motor | xgb_tweedie |
| voluntary_excess | 0.0254 | 11 | motor | xgb_tweedie |
| region | 0.0232 | 12 | motor | xgb_tweedie |
| urban_density | 0.0194 | 13 | motor | xgb_tweedie |
| hist_pol_cost | 0.0179 | 14 | motor | xgb_tweedie |
| telematics_score | 0.0176 | 15 | motor | xgb_tweedie |

## Boosting rounds (final fit, early-stopping member)
| line | model | rounds |
|---|---|---|
| motor | peril_lgb.own_damage | 698 |
| motor | peril_lgb.third_party_prop | 354 |
| motor | peril_lgb.bodily_injury | 416 |
| motor | peril_lgb.theft | 236 |
| motor | peril_lgb.glass_hail | 280 |
| motor | lgb_tweedie | 105 |
| motor | peril_xgb.own_damage | 1,053 |
| motor | peril_xgb.third_party_prop | 631 |
| motor | peril_xgb.bodily_injury | 366 |
| motor | peril_xgb.theft | 534 |
| motor | peril_xgb.glass_hail | 615 |
| motor | xgb_tweedie | 291 |
| buildings | peril_lgb.storm | 234 |
| buildings | peril_lgb.flood | 248 |
| buildings | peril_lgb.escape_of_water | 423 |
| buildings | peril_lgb.subsidence | 117 |
| buildings | peril_lgb.fire | 56 |
| buildings | peril_lgb.accidental_damage | 134 |
| buildings | lgb_tweedie | 102 |
| buildings | peril_xgb.storm | 1,221 |
| buildings | peril_xgb.flood | 484 |
| buildings | peril_xgb.escape_of_water | 713 |
| buildings | peril_xgb.subsidence | 455 |
| buildings | peril_xgb.fire | 311 |
| buildings | peril_xgb.accidental_damage | 497 |
| buildings | xgb_tweedie | 350 |
| contents | peril_lgb.theft | 232 |
| contents | peril_lgb.escape_of_water | 177 |
| contents | peril_lgb.accidental_damage | 327 |
| contents | peril_lgb.flood | 348 |
| contents | lgb_tweedie | 167 |
| contents | peril_xgb.theft | 291 |
| contents | peril_xgb.escape_of_water | 232 |
| contents | peril_xgb.accidental_damage | 504 |
| contents | peril_xgb.flood | 403 |
| contents | xgb_tweedie | 226 |

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

