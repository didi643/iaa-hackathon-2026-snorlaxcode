# Iteration SAM 2 (`sam_iteration_02`)

**Run id** `20261021_1528` | **Generated** 2026-10-22 09:22 | **Git commit** `841df76 + uncommitted changes in R/` | **Submission file** `submission_20261021_1528.csv`

**Change in this iteration:** Full rebuild from raw data. Per-peril frequency x severity (GLM, LightGBM, XGBoost) with claim-history features, per-peril report-lag IBNR, claim-level caps and a fitted trend to 2025 (capped at +/-10% a year); line Tweedie bags (LightGBM, XGBoost); greedy blend chosen on calibrated D2 over three rolling folds; written_premium and noise fields excluded.

> **Warning:** generated from uncommitted code.

## Phase 0 - is the old framework off track?
### Predicted 2025 cost per exposure-year of past submissions vs their public D2

| submission | motor | buildings | contents | public_d2 |
|---|---|---|---|---|
| #1 iteration_01 | 518.1190 | 425.0838 | 113.2029 | 0.1190 |
| #2 iteration_02 | 498.8029 | 434.2517 | 119.1349 | 0.1215 |
| #3 sam_iteration_01 | 518.1190 | 411.7918 | 111.8020 | 0.1188 |
| this run (sam_iteration_02) | 604.1321 | 487.3683 | 125.1353 |  |

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
| 0.8500 | 0.0995 | 0.1354 |
| 0.9000 | 0.1021 | 0.1379 |
| 0.9500 | 0.1038 | 0.1395 |
| 1 | 0.1045 | 0.1402 |
| 1.0500 | 0.1046 | 0.1403 |
| 1.1000 | 0.1040 | 0.1397 |
| 1.1500 | 0.1029 | 0.1386 |

## Reproducibility
Submission MD5 `db6f636897fbda72a18bd6be079d8e7f`. The submitted blend per line is saved in `models/sam_iteration_02/fitted/<line>_blend.rds` (boosters embedded). Prepared data: `data/sam02/` (rebuild with this script).

```r
source("R/0_setup.R"); source("R/model_io.R")
art  <- load_model("models/sam_iteration_02/fitted", "motor_blend")
pred <- pmax(score_model(art, arrow::read_parquet("data/sam02/test_motor.parquet")), 0)
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
| IBNR | per line x peril x policy year from the 2021-22 report-lag distribution (inverse reporting probability) |
| Long-tail perils | buildings.subsidence, motor.bodily_injury (2023 open share > 15%): severity on policy years < 2023, frequency with a 2024 dummy |
| Trend | policy_year term in each per-peril frequency and severity GLM, capped at +/-10% a year; tree models take the GLM level |
| GLM | 6 quantile bins, levels < 0.5% exposure merged to base; frequency on all claim rows + 3e+05 sampled zero rows (reweighted) |
| LightGBM | learning_rate=0.05, num_leaves=15, min_data_in_leaf=500, feature_fraction=0.7, bagging_fraction=0.8, bagging_freq=1, lambda_l2=10, cat_smooth=50, cat_l2=10, min_data_per_group=500, max_cat_threshold=32, verbosity=-1, deterministic=1, force_col_wise=1, num_threads=12 |
| XGBoost line Tweedie | motor: max_depth=3, learning_rate=0.03, min_child_weight=50, subsample=0.9, colsample_bytree=0.6, reg_lambda=5, tweedie_variance_power=1.3; buildings: max_depth=4, learning_rate=0.03, min_child_weight=500, subsample=0.8, colsample_bytree=0.6, reg_lambda=1, tweedie_variance_power=1.3; contents: max_depth=3, learning_rate=0.05, min_child_weight=500, subsample=0.7, colsample_bytree=0.7, reg_lambda=1, tweedie_variance_power=1.5 |
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
| motor | bodily_injury | TRUE | -0.060 | -0.060 | 1.007 | 0.045 | 0.045 | 4,285 | 1.036 |
| motor | theft | FALSE | -0.015 | -0.015 |  | 0.064 | 0.064 | 6,119 | 1.007 |
| motor | glass_hail | FALSE | -0.019 | -0.019 |  | 0.080 | 0.080 | 15,643 | 1.006 |
| buildings | storm | FALSE | 0.006 | 0.006 |  | 0.067 | 0.067 | 7,762 | 1.009 |
| buildings | flood | FALSE | -0.025 | -0.025 |  | 0.048 | 0.048 | 2,219 | 1.008 |
| buildings | escape_of_water | FALSE | 0.001 | 0.001 |  | 0.069 | 0.069 | 10,065 | 1.007 |
| buildings | subsidence | TRUE | 0.008 | 0.008 | 1.177 | 0.048 | 0.048 | 617 | 1.001 |
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
| motor | 12 | 3 | 0.0300 | 50 | 0.9000 | 0.6000 | 5 | 1.3000 | 0.0551 | 492 | 42 | 1 |
| motor | 6 | 4 | 0.0300 | 500 | 0.8000 | 0.7000 | 1 | 1.7000 | 0.0545 | 308 | 31 | 2 |
| motor | 9 | 3 | 0.0500 | 500 | 0.8000 | 0.6000 | 1 | 1.3000 | 0.0544 | 265 | 25 | 3 |
| motor | 10 | 5 | 0.0300 | 50 | 0.7000 | 0.7000 | 5 | 1.3000 | 0.0544 | 262 | 30 | 4 |
| motor | 11 | 4 | 0.0500 | 50 | 0.7000 | 0.7000 | 1 | 1.3000 | 0.0544 | 184 | 20 | 5 |
| buildings | 15 | 4 | 0.0300 | 500 | 0.8000 | 0.6000 | 1 | 1.3000 | 0.0843 | 239 | 18 | 1 |
| buildings | 12 | 3 | 0.0500 | 200 | 0.7000 | 0.7000 | 5 | 1.3000 | 0.0840 | 185 | 14 | 2 |
| buildings | 10 | 3 | 0.0300 | 200 | 0.7000 | 0.6000 | 10 | 1.3000 | 0.0837 | 260 | 18 | 3 |
| buildings | 16 | 3 | 0.0300 | 200 | 0.8000 | 0.8000 | 1 | 1.5000 | 0.0832 | 240 | 16 | 4 |
| buildings | 7 | 3 | 0.0500 | 200 | 0.9000 | 0.6000 | 1 | 1.5000 | 0.0826 | 103 | 9 | 5 |
| contents | 3 | 3 | 0.0500 | 500 | 0.7000 | 0.7000 | 1 | 1.5000 | 0.0593 | 181 | 13 | 1 |
| contents | 11 | 3 | 0.0300 | 500 | 0.8000 | 0.6000 | 5 | 1.5000 | 0.0583 | 277 | 18 | 2 |
| contents | 12 | 5 | 0.0500 | 50 | 0.9000 | 0.8000 | 1 | 1.3000 | 0.0582 | 101 | 10 | 3 |
| contents | 21 | 3 | 0.0500 | 50 | 0.7000 | 0.8000 | 1 | 1.3000 | 0.0580 | 192 | 5 | 4 |
| contents | 19 | 3 | 0.0300 | 500 | 0.8000 | 0.7000 | 5 | 1.3000 | 0.0580 | 320 | 15 | 5 |

## Validation - local Kaggle metric (Tweedie D2, p = 1.5)
`d2` = raw (exposure-rate baseline, as Kaggle is believed to score), `d2_flat` = flat-mean baseline, `d2_cal` = after rescaling predictions to the actual total (ranking only), `ae_developed` = predicted / IBNR-developed actual (level). 2024 actuals are immature.

### Combined, all lines
| model | d2_2022 | d2_2023 | d2_2024 | d2_flat_2022 | d2_flat_2023 | d2_flat_2024 | ae_developed_2022 | ae_developed_2023 | ae_developed_2024 |
|---|---|---|---|---|---|---|---|---|---|
| legacy_glm | 0.1054 | 0.1059 | 0.0950 | 0.1383 | 0.1416 | 0.1268 | 0.9911 | 0.9482 | 0.9772 |
| blend | 0.1143 | 0.1045 | 0.0982 | 0.1468 | 0.1402 | 0.1298 | 0.9689 | 0.9611 | 1.0329 |
| peril_glm_notrend | 0.1108 | 0.1032 | 0.0957 | 0.1434 | 0.1390 | 0.1274 | 0.9701 | 0.9425 | 0.9816 |
| peril_glm | 0.1108 | 0.1030 | 0.0946 | 0.1434 | 0.1388 | 0.1264 | 0.9701 | 0.9619 | 1.0331 |
| legacy_xgb | 0.1035 | 0.1017 | 0.0983 | 0.1364 | 0.1375 | 0.1299 | 0.8694 | 0.8593 | 0.9249 |
| xgb_tweedie | 0.1074 | 0.1016 | 0.0960 | 0.1402 | 0.1375 | 0.1278 | 0.9701 | 0.9619 | 1.0331 |
| peril_xgb | 0.1144 | 0.0993 | 0.0980 | 0.1469 | 0.1352 | 0.1297 | 0.9675 | 0.9609 | 1.0332 |
| peril_lgb | 0.1086 | 0.0927 | 0.0945 | 0.1413 | 0.1289 | 0.1263 | 0.9677 | 0.9603 | 1.0321 |
| lgb_tweedie | 0.0992 | 0.0899 | 0.0910 | 0.1323 | 0.1262 | 0.1229 | 0.9701 | 0.9619 | 1.0331 |
| burn_trend | 0.0553 | 0.0492 | 0.0352 | 0.0899 | 0.0871 | 0.0691 | 0.9713 | 0.9746 | 1.0450 |
| burn_cost | 0.0553 | 0.0488 | 0.0371 | 0.0899 | 0.0867 | 0.0709 | 0.9712 | 0.9302 | 0.9602 |

### Mean over folds by line
| line | model | d2 | d2_cal | d2_flat | ae_developed |
|---|---|---|---|---|---|
| buildings | blend | 0.0707 | 0.0708 | 0.1072 | 0.9639 |
| buildings | peril_xgb | 0.0699 | 0.0701 | 0.1065 | 0.9624 |
| buildings | legacy_xgb | 0.0664 | 0.0675 | 0.1031 | 0.8736 |
| buildings | xgb_tweedie | 0.0672 | 0.0674 | 0.1039 | 0.9663 |
| buildings | peril_glm | 0.0670 | 0.0672 | 0.1036 | 0.9663 |
| buildings | peril_glm_notrend | 0.0670 | 0.0672 | 0.1037 | 0.9278 |
| buildings | peril_lgb | 0.0670 | 0.0671 | 0.1037 | 0.9610 |
| buildings | lgb_tweedie | 0.0621 | 0.0623 | 0.0989 | 0.9663 |
| buildings | legacy_glm | 0.0597 | 0.0595 | 0.0967 | 0.9802 |
| buildings | burn_cost | -0.0008 | 0 | 0.0386 | 0.8953 |
| buildings | burn_trend | -0.0002 | 0 | 0.0392 | 0.9485 |
| contents | blend | 0.0663 | 0.0667 | 0.0971 | 0.9818 |
| contents | peril_xgb | 0.0648 | 0.0652 | 0.0956 | 0.9816 |
| contents | xgb_tweedie | 0.0628 | 0.0633 | 0.0937 | 0.9820 |
| contents | peril_glm_notrend | 0.0626 | 0.0632 | 0.0935 | 0.9556 |
| contents | peril_glm | 0.0628 | 0.0631 | 0.0936 | 0.9820 |
| contents | peril_lgb | 0.0622 | 0.0625 | 0.0930 | 0.9813 |
| contents | legacy_glm | 0.0598 | 0.0605 | 0.0907 | 0.9509 |
| contents | legacy_xgb | 0.0570 | 0.0590 | 0.0881 | 0.9061 |
| contents | lgb_tweedie | 0.0569 | 0.0573 | 0.0879 | 0.9820 |
| contents | burn_trend | -0.0007 | 0 | 0.0322 | 0.9705 |
| contents | burn_cost | -0.0010 | 0 | 0.0319 | 0.9375 |
| motor | legacy_glm | 0.0519 | 0.0538 | 0.0889 | 0.9747 |
| motor | blend | 0.0493 | 0.0532 | 0.0865 | 1.0060 |
| motor | peril_xgb | 0.0466 | 0.0506 | 0.0839 | 1.0062 |
| motor | peril_glm_notrend | 0.0481 | 0.0505 | 0.0853 | 0.9913 |
| motor | peril_glm | 0.0470 | 0.0505 | 0.0843 | 1.0059 |
| motor | legacy_xgb | 0.0460 | 0.0496 | 0.0833 | 0.8907 |
| motor | xgb_tweedie | 0.0444 | 0.0483 | 0.0818 | 1.0059 |
| motor | peril_lgb | 0.0380 | 0.0421 | 0.0757 | 1.0061 |
| motor | lgb_tweedie | 0.0320 | 0.0359 | 0.0699 | 1.0059 |
| motor | burn_cost | -0.0026 | 0 | 0.0366 | 0.9945 |
| motor | burn_trend | -0.0044 | 0 | 0.0348 | 1.0330 |

### Raw D2 by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.0661 | 0.0716 | 0.0743 |
| buildings | burn_cost | -0.0004 | -0.0009 | -0.0010 |
| buildings | burn_trend | -0.0004 | 0.0000 | -0.0001 |
| buildings | legacy_glm | 0.0483 | 0.0622 | 0.0687 |
| buildings | legacy_xgb | 0.0564 | 0.0699 | 0.0730 |
| buildings | lgb_tweedie | 0.0582 | 0.0613 | 0.0666 |
| buildings | peril_glm | 0.0627 | 0.0685 | 0.0697 |
| buildings | peril_glm_notrend | 0.0627 | 0.0685 | 0.0698 |
| buildings | peril_lgb | 0.0634 | 0.0660 | 0.0715 |
| buildings | peril_xgb | 0.0653 | 0.0705 | 0.0741 |
| buildings | xgb_tweedie | 0.0604 | 0.0694 | 0.0719 |
| contents | blend | 0.0638 | 0.0710 | 0.0643 |
| contents | burn_cost | 0.0000 | -0.0022 | -0.0009 |
| contents | burn_trend | 0.0000 | -0.0021 | -0.0001 |
| contents | legacy_glm | 0.0555 | 0.0631 | 0.0608 |
| contents | legacy_xgb | 0.0511 | 0.0611 | 0.0589 |
| contents | lgb_tweedie | 0.0519 | 0.0613 | 0.0574 |
| contents | peril_glm | 0.0585 | 0.0679 | 0.0620 |
| contents | peril_glm_notrend | 0.0585 | 0.0678 | 0.0616 |
| contents | peril_lgb | 0.0609 | 0.0671 | 0.0586 |
| contents | peril_xgb | 0.0627 | 0.0697 | 0.0621 |
| contents | xgb_tweedie | 0.0609 | 0.0659 | 0.0618 |
| motor | blend | 0.0591 | 0.0431 | 0.0458 |
| motor | burn_cost | -0.0001 | -0.0002 | -0.0075 |
| motor | burn_trend | -0.0001 | -0.0000 | -0.0131 |
| motor | legacy_glm | 0.0553 | 0.0557 | 0.0446 |
| motor | legacy_xgb | 0.0468 | 0.0417 | 0.0495 |
| motor | lgb_tweedie | 0.0359 | 0.0219 | 0.0383 |
| motor | peril_glm | 0.0557 | 0.0431 | 0.0422 |
| motor | peril_glm_notrend | 0.0557 | 0.0436 | 0.0448 |
| motor | peril_lgb | 0.0496 | 0.0225 | 0.0420 |
| motor | peril_xgb | 0.0603 | 0.0330 | 0.0466 |
| motor | xgb_tweedie | 0.0491 | 0.0402 | 0.0439 |

### Calibrated D2 by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.0662 | 0.0716 | 0.0747 |
| buildings | burn_cost | 0 | 0 | 0 |
| buildings | burn_trend | 0 | 0 | 0 |
| buildings | legacy_glm | 0.0474 | 0.0624 | 0.0687 |
| buildings | legacy_xgb | 0.0589 | 0.0702 | 0.0732 |
| buildings | lgb_tweedie | 0.0583 | 0.0614 | 0.0671 |
| buildings | peril_glm | 0.0631 | 0.0685 | 0.0700 |
| buildings | peril_glm_notrend | 0.0631 | 0.0686 | 0.0698 |
| buildings | peril_lgb | 0.0636 | 0.0660 | 0.0718 |
| buildings | peril_xgb | 0.0655 | 0.0705 | 0.0744 |
| buildings | xgb_tweedie | 0.0604 | 0.0694 | 0.0722 |
| contents | blend | 0.0638 | 0.0719 | 0.0643 |
| contents | burn_cost | 0 | 0 | 0 |
| contents | burn_trend | 0 | 0 | 0 |
| contents | legacy_glm | 0.0554 | 0.0647 | 0.0614 |
| contents | legacy_xgb | 0.0533 | 0.0643 | 0.0594 |
| contents | lgb_tweedie | 0.0520 | 0.0623 | 0.0575 |
| contents | peril_glm | 0.0584 | 0.0691 | 0.0619 |
| contents | peril_glm_notrend | 0.0584 | 0.0693 | 0.0620 |
| contents | peril_lgb | 0.0609 | 0.0680 | 0.0585 |
| contents | peril_xgb | 0.0627 | 0.0708 | 0.0620 |
| contents | xgb_tweedie | 0.0609 | 0.0671 | 0.0617 |
| motor | blend | 0.0591 | 0.0434 | 0.0572 |
| motor | burn_cost | 0 | 0 | 0 |
| motor | burn_trend | 0 | 0 | 0 |
| motor | legacy_glm | 0.0556 | 0.0560 | 0.0499 |
| motor | legacy_xgb | 0.0507 | 0.0457 | 0.0525 |
| motor | lgb_tweedie | 0.0359 | 0.0223 | 0.0496 |
| motor | peril_glm | 0.0559 | 0.0435 | 0.0522 |
| motor | peril_glm_notrend | 0.0559 | 0.0439 | 0.0518 |
| motor | peril_lgb | 0.0496 | 0.0228 | 0.0538 |
| motor | peril_xgb | 0.0602 | 0.0334 | 0.0581 |
| motor | xgb_tweedie | 0.0492 | 0.0407 | 0.0551 |

### Level: predicted / developed actual by fold
| line | model | 2022 | 2023 | 2024 |
|---|---|---|---|---|
| buildings | blend | 0.959 | 0.996 | 0.937 |
| buildings | burn_cost | 0.952 | 0.908 | 0.825 |
| buildings | burn_trend | 0.952 | 0.971 | 0.922 |
| buildings | legacy_glm | 1.049 | 0.978 | 0.913 |
| buildings | legacy_xgb | 0.868 | 0.899 | 0.853 |
| buildings | lgb_tweedie | 0.962 | 0.999 | 0.938 |
| buildings | peril_glm | 0.962 | 0.999 | 0.938 |
| buildings | peril_glm_notrend | 0.962 | 0.944 | 0.878 |
| buildings | peril_lgb | 0.956 | 0.993 | 0.934 |
| buildings | peril_xgb | 0.957 | 0.994 | 0.936 |
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
| motor | blend | 0.969 | 0.948 | 1.102 |
| motor | burn_cost | 0.977 | 0.947 | 1.060 |
| motor | burn_trend | 0.977 | 0.987 | 1.135 |
| motor | legacy_glm | 0.958 | 0.936 | 1.029 |
| motor | legacy_xgb | 0.864 | 0.835 | 0.972 |
| motor | lgb_tweedie | 0.969 | 0.947 | 1.101 |
| motor | peril_glm | 0.969 | 0.947 | 1.101 |
| motor | peril_glm_notrend | 0.969 | 0.945 | 1.059 |
| motor | peril_lgb | 0.968 | 0.948 | 1.102 |
| motor | peril_xgb | 0.967 | 0.948 | 1.103 |
| motor | xgb_tweedie | 0.969 | 0.947 | 1.101 |

### Trend vs no trend (per-peril GLM)
| line | model | d2_2022 | d2_2023 | d2_2024 | ae_developed_2022 | ae_developed_2023 | ae_developed_2024 |
|---|---|---|---|---|---|---|---|
| buildings | peril_glm | 0.0627 | 0.0685 | 0.0697 | 0.9616 | 0.9992 | 0.9380 |
| buildings | peril_glm_notrend | 0.0627 | 0.0685 | 0.0698 | 0.9616 | 0.9438 | 0.8779 |
| contents | peril_glm | 0.0585 | 0.0679 | 0.0620 | 1.0085 | 0.9229 | 1.0147 |
| contents | peril_glm_notrend | 0.0585 | 0.0678 | 0.0616 | 1.0085 | 0.9193 | 0.9392 |
| motor | peril_glm | 0.0557 | 0.0431 | 0.0422 | 0.9693 | 0.9474 | 1.1010 |
| motor | peril_glm_notrend | 0.0557 | 0.0436 | 0.0448 | 0.9693 | 0.9452 | 1.0592 |

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
| 2024 | buildings | peril_lgb | 0.1026 | 0.0718 | 0.0308 |
| 2022 | buildings | peril_xgb | 0.1167 | 0.0655 | 0.0512 |
| 2023 | buildings | peril_xgb | 0.1047 | 0.0705 | 0.0342 |
| 2024 | buildings | peril_xgb | 0.0949 | 0.0744 | 0.0204 |
| 2022 | buildings | xgb_tweedie | 0.1367 | 0.0604 | 0.0762 |
| 2023 | buildings | xgb_tweedie | 0.1161 | 0.0694 | 0.0466 |
| 2024 | buildings | xgb_tweedie | 0.1255 | 0.0722 | 0.0533 |
| 2022 | contents | lgb_tweedie | 0.1083 | 0.0520 | 0.0562 |
| 2023 | contents | lgb_tweedie | 0.1206 | 0.0623 | 0.0584 |
| 2024 | contents | lgb_tweedie | 0.1280 | 0.0575 | 0.0705 |
| 2022 | contents | peril_glm | 0.0877 | 0.0584 | 0.0293 |
| 2023 | contents | peril_glm | 0.0679 | 0.0691 | -0.0013 |
| 2024 | contents | peril_glm | 0.0769 | 0.0619 | 0.0150 |
| 2022 | contents | peril_lgb | 0.1520 | 0.0609 | 0.0911 |
| 2023 | contents | peril_lgb | 0.0971 | 0.0680 | 0.0290 |
| 2024 | contents | peril_lgb | 0.0981 | 0.0585 | 0.0395 |
| 2022 | contents | peril_xgb | 0.1047 | 0.0627 | 0.0419 |
| 2023 | contents | peril_xgb | 0.0894 | 0.0708 | 0.0186 |
| 2024 | contents | peril_xgb | 0.0929 | 0.0620 | 0.0309 |
| 2022 | contents | xgb_tweedie | 0.1145 | 0.0609 | 0.0536 |
| 2023 | contents | xgb_tweedie | 0.1038 | 0.0671 | 0.0368 |
| 2024 | contents | xgb_tweedie | 0.1129 | 0.0617 | 0.0512 |
| 2022 | motor | lgb_tweedie | 0.0753 | 0.0359 | 0.0394 |
| 2023 | motor | lgb_tweedie | 0.1099 | 0.0223 | 0.0876 |
| 2024 | motor | lgb_tweedie | 0.1203 | 0.0496 | 0.0707 |
| 2022 | motor | peril_glm | 0.0533 | 0.0559 | -0.0026 |
| 2023 | motor | peril_glm | 0.0583 | 0.0435 | 0.0148 |
| 2024 | motor | peril_glm | 0.0522 | 0.0522 | 0.0000 |
| 2022 | motor | peril_lgb | 0.0827 | 0.0496 | 0.0332 |
| 2023 | motor | peril_lgb | 0.0708 | 0.0228 | 0.0480 |
| 2024 | motor | peril_lgb | 0.0527 | 0.0538 | -0.0011 |
| 2022 | motor | peril_xgb | 0.0719 | 0.0602 | 0.0116 |
| 2023 | motor | peril_xgb | 0.0768 | 0.0334 | 0.0434 |
| 2024 | motor | peril_xgb | 0.0592 | 0.0581 | 0.0011 |
| 2022 | motor | xgb_tweedie | 0.0887 | 0.0492 | 0.0395 |
| 2023 | motor | xgb_tweedie | 0.0999 | 0.0407 | 0.0593 |
| 2024 | motor | xgb_tweedie | 0.1020 | 0.0551 | 0.0469 |

### Segment A/E of the blend (level removed per line; 1 = right relative price)
| line | segment | level | exposure | ae_2023 | ae_2024 |
|---|---|---|---|---|---|
| buildings | hist_pol_n | 0 | 278,461.014 | 0.972 | 0.969 |
| buildings | hist_pol_n | 1 | 19,745.315 | 1.241 | 1.206 |
| buildings | hist_pol_n | 2 | 1,540.868 | 1.638 | 1.350 |
| buildings | hist_pol_n | 3 | 157.622 | 1.837 | 1.298 |
| buildings | new_business | FALSE | 272,802.258 | 1.008 | 0.991 |
| buildings | new_business | TRUE | 27,102.562 | 0.917 | 1.087 |
| contents | hist_pol_n | 0 | 280,343.293 | 0.967 | 0.989 |
| contents | hist_pol_n | 1 | 18,140.847 | 1.367 | 1.088 |
| contents | hist_pol_n | 2 | 1,350.901 | 1.593 | 0.858 |
| contents | hist_pol_n | 3 | 106.671 | 0.149 | 2.189 |
| contents | new_business | FALSE | 272,872.805 | 0.990 | 1.009 |
| contents | new_business | TRUE | 27,068.907 | 1.101 | 0.913 |
| motor | driver_age | [0,25) | 53,987.041 | 0.825 | 0.922 |
| motor | driver_age | [25,35) | 73,253.537 | 1.500 | 1.007 |
| motor | driver_age | [35,50) | 73,266.926 | 0.905 | 1.018 |
| motor | driver_age | [50,65) | 73,917.564 | 0.915 | 1.024 |
| motor | driver_age | [65,Inf) | 125,042.414 | 0.926 | 1.049 |
| motor | hist_pol_n | 0 | 322,217.088 | 1.027 | 0.969 |
| motor | hist_pol_n | 1 | 59,976.984 | 0.842 | 1.051 |
| motor | hist_pol_n | 2 | 12,763.726 | 1.041 | 0.956 |
| motor | hist_pol_n | 3 | 4,509.685 | 1.398 | 1.414 |
| motor | ncb_years | (-Inf,0] | 17,642.841 | 0.992 | 1.100 |
| motor | ncb_years | (0,3] | 92,279.929 | 0.849 | 0.923 |
| motor | ncb_years | (3,6] | 72,292.312 | 1.545 | 1.021 |
| motor | ncb_years | (6,9] | 60,441.992 | 0.917 | 1.030 |
| motor | ncb_years | (9, Inf] | 156,810.408 | 0.919 | 1.033 |
| motor | new_business | FALSE | 363,280.252 | 1.007 | 1.004 |
| motor | new_business | TRUE | 36,187.230 | 0.951 | 0.973 |
| motor | vehicle_age | (-Inf,3] | 28,076.293 | 0.954 | 1.080 |
| motor | vehicle_age | (12, Inf] | 64,911.699 | 0.818 | 0.860 |
| motor | vehicle_age | (3,7] | 153,642.485 | 1.155 | 1.050 |
| motor | vehicle_age | (7,12] | 142,880.718 | 0.915 | 1.011 |

## Blend weights
| line | lgb_tweedie | peril_glm | peril_lgb | peril_xgb | xgb_tweedie |
|---|---|---|---|---|---|
| buildings | 0 | 0.20 | 0 | 0.60 | 0.20 |
| contents | 0 | 0.30 | 0 | 0.40 | 0.30 |
| motor | 0 | 0.50 | 0 | 0.30 | 0.20 |

## 2025 test predictions (final fit on 2021-24)
| line | model | weight | predicted_total | predicted_burn_cost | p50_row | p90_row | p99_row | max_row |
|---|---|---|---|---|---|---|---|---|
| motor | peril_glm | 0.50 | 120,734,511.67 | 603.72 | 375.93 | 927.51 | 2,062.43 | 6,763.02 |
| motor | peril_lgb | 0 | 120,975,880.51 | 604.93 | 398.36 | 873.26 | 1,995.93 | 13,824.24 |
| motor | peril_xgb | 0.30 | 121,007,808.23 | 605.09 | 394.97 | 888.78 | 1,977.35 | 7,785.09 |
| motor | lgb_tweedie | 0 | 120,734,511.67 | 603.72 | 396.43 | 897.08 | 1,903.22 | 10,950.66 |
| motor | xgb_tweedie | 0.20 | 120,734,511.67 | 603.72 | 381.84 | 904.29 | 2,086.67 | 9,197.24 |
| motor | burn_trend |  | 125,472,062.29 | 627.41 | 627.41 | 627.41 | 627.41 | 627.41 |
| motor | burn_cost |  | 108,930,584.85 | 544.70 | 544.70 | 544.70 | 544.70 | 544.70 |
| motor | blend | 1 | 120,816,500.63 | 604.13 | 386.16 | 909.60 | 1,992.34 | 7,086.74 |
| buildings | peril_glm | 0.20 | 73,316,884.37 | 487.99 | 319.00 | 701.92 | 2,080.45 | 8,540.58 |
| buildings | peril_lgb | 0 | 73,047,273.61 | 486.19 | 317.65 | 689.39 | 2,165.30 | 17,786.32 |
| buildings | peril_xgb | 0.60 | 73,162,272.33 | 486.96 | 312.59 | 711.26 | 2,138.85 | 13,752.18 |
| buildings | lgb_tweedie | 0 | 73,316,884.37 | 487.99 | 315.07 | 712.29 | 2,131.90 | 7,371.19 |
| buildings | xgb_tweedie | 0.20 | 73,316,884.37 | 487.99 | 308.51 | 709.44 | 2,246.40 | 18,555.22 |
| buildings | burn_trend |  | 75,302,597.37 | 501.20 | 501.20 | 501.20 | 501.20 | 501.20 |
| buildings | burn_cost |  | 62,751,650.57 | 417.67 | 417.67 | 417.67 | 417.67 | 417.67 |
| buildings | blend | 1 | 73,224,117.15 | 487.37 | 315.03 | 704.10 | 2,127.34 | 12,798.59 |
| contents | peril_glm | 0.30 | 18,813,263.45 | 125.32 | 77.18 | 187.53 | 518.56 | 3,803.82 |
| contents | peril_lgb | 0 | 18,750,838.14 | 124.90 | 78.37 | 179.78 | 531.82 | 5,502.59 |
| contents | peril_xgb | 0.40 | 18,744,559.56 | 124.86 | 77.66 | 182.84 | 529.34 | 3,467.08 |
| contents | lgb_tweedie | 0 | 18,813,263.45 | 125.32 | 79.59 | 185.93 | 491.94 | 3,215.17 |
| contents | xgb_tweedie | 0.30 | 18,813,263.45 | 125.32 | 78.76 | 184.85 | 500.19 | 3,945.31 |
| contents | burn_trend |  | 18,862,611.97 | 125.65 | 125.65 | 125.65 | 125.65 | 125.65 |
| contents | burn_cost |  | 16,702,409.98 | 111.26 | 111.26 | 111.26 | 111.26 | 111.26 |
| contents | blend | 1 | 18,785,781.89 | 125.14 | 78.28 | 184.43 | 512.45 | 2,954.99 |

### Level vs previous submissions
| submission | motor | buildings | contents | public_d2 |
|---|---|---|---|---|
| #1 iteration_01 | 518.12 | 425.08 | 113.20 | 0.12 |
| #2 iteration_02 | 498.80 | 434.25 | 119.13 | 0.12 |
| #3 sam_iteration_01 | 518.12 | 411.79 | 111.80 | 0.12 |
| this run (sam_iteration_02) | 604.13 | 487.37 | 125.14 |  |

## Variable importance (line Tweedie bags)
![](tree_importance.png)

Rank of the random noise feature:

| line | model | noise_rank |
|---|---|---|
| motor | lgb_tweedie | 50 |
| motor | xgb_tweedie | 37 |
| buildings | lgb_tweedie | 32 |
| buildings | xgb_tweedie | 16 |
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
| flood_score | 0.1956 | 1 | buildings | xgb_tweedie |
| flood_zone | 0.0862 | 2 | buildings | xgb_tweedie |
| sum_insured | 0.0817 | 3 | buildings | xgb_tweedie |
| elevation_m | 0.0704 | 4 | buildings | xgb_tweedie |
| log_sum_insured | 0.0327 | 5 | buildings | xgb_tweedie |
| distance_to_river_km | 0.0299 | 6 | buildings | xgb_tweedie |
| energy_rating | 0.0276 | 7 | buildings | xgb_tweedie |
| property_age | 0.0248 | 8 | buildings | xgb_tweedie |
| year_built | 0.0217 | 9 | buildings | xgb_tweedie |
| dry_summer_index | 0.0217 | 10 | buildings | xgb_tweedie |
| prior_claims_5y | 0.0213 | 11 | buildings | xgb_tweedie |
| si_per_bedroom | 0.0207 | 12 | buildings | xgb_tweedie |
| wind_exposure_index | 0.0196 | 13 | buildings | xgb_tweedie |
| previous_insurer | 0.0193 | 14 | buildings | xgb_tweedie |
| rainfall_mm | 0.0187 | 15 | buildings | xgb_tweedie |
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
| ncb_years | 0.2258 | 1 | motor | xgb_tweedie |
| customer_age | 0.0762 | 2 | motor | xgb_tweedie |
| annual_mileage | 0.0653 | 3 | motor | xgb_tweedie |
| years_licensed | 0.0600 | 4 | motor | xgb_tweedie |
| make_model | 0.0593 | 5 | motor | xgb_tweedie |
| driver_age | 0.0504 | 6 | motor | xgb_tweedie |
| hist_pol_rel | 0.0427 | 7 | motor | xgb_tweedie |
| prior_claims_5y | 0.0325 | 8 | motor | xgb_tweedie |
| cover_type | 0.0261 | 9 | motor | xgb_tweedie |
| region | 0.0239 | 10 | motor | xgb_tweedie |
| vehicle_age | 0.0221 | 11 | motor | xgb_tweedie |
| voluntary_excess | 0.0217 | 12 | motor | xgb_tweedie |
| urban_density | 0.0169 | 13 | motor | xgb_tweedie |
| telematics_score | 0.0163 | 14 | motor | xgb_tweedie |
| hist_pol_cost | 0.0155 | 15 | motor | xgb_tweedie |

## Boosting rounds (final fit, early-stopping member)
| line | model | rounds |
|---|---|---|
| motor | peril_lgb.own_damage | 784 |
| motor | peril_lgb.third_party_prop | 269 |
| motor | peril_lgb.bodily_injury | 543 |
| motor | peril_lgb.theft | 264 |
| motor | peril_lgb.glass_hail | 220 |
| motor | lgb_tweedie | 173 |
| motor | peril_xgb.own_damage | 1,686 |
| motor | peril_xgb.third_party_prop | 1,165 |
| motor | peril_xgb.bodily_injury | 617 |
| motor | peril_xgb.theft | 778 |
| motor | peril_xgb.glass_hail | 811 |
| motor | xgb_tweedie | 655 |
| buildings | peril_lgb.storm | 310 |
| buildings | peril_lgb.flood | 199 |
| buildings | peril_lgb.escape_of_water | 227 |
| buildings | peril_lgb.subsidence | 198 |
| buildings | peril_lgb.fire | 59 |
| buildings | peril_lgb.accidental_damage | 148 |
| buildings | lgb_tweedie | 108 |
| buildings | peril_xgb.storm | 795 |
| buildings | peril_xgb.flood | 348 |
| buildings | peril_xgb.escape_of_water | 465 |
| buildings | peril_xgb.subsidence | 247 |
| buildings | peril_xgb.fire | 226 |
| buildings | peril_xgb.accidental_damage | 368 |
| buildings | xgb_tweedie | 238 |
| contents | peril_lgb.theft | 245 |
| contents | peril_lgb.escape_of_water | 176 |
| contents | peril_lgb.accidental_damage | 253 |
| contents | peril_lgb.flood | 296 |
| contents | lgb_tweedie | 162 |
| contents | peril_xgb.theft | 422 |
| contents | peril_xgb.escape_of_water | 232 |
| contents | peril_xgb.accidental_damage | 504 |
| contents | peril_xgb.flood | 377 |
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

