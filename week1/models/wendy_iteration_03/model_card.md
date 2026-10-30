# WENDY 3 - per-peril models

**Run id** `20261021_1650` | **Generated** 2026-10-21 17:12 | **Git commit** `` | **Submission file** `submission_20261021_1650.csv`

**Change in this iteration:** One XGBoost Tweedie model per peril (motor 5, buildings 6, contents 4); the line prediction is the sum of its peril predictions. Each peril has its own p99.9 large-loss cap, IBNR factor (from its own report lags), hyper-parameters (random grid search on a 20% policy holdout of 2021-23) and a balance factor so its training predictions add up to the training target. Validated on 2024 only (fit on 2021-23). Same features as iteration 2.

Public Kaggle scores for this iteration are in the submission log (`Iteration` column `WENDY 3`) and on the Model iterations overview page.

## Reproducibility
Submission file MD5 `5781d7755fa956afa482ad488b7c1796`. The final models are saved in `models/wendy_iteration_03/fitted/`: one `<line>_xgb_peril_sum.rds` per line, which lists its peril models `<line>_<peril>_xgb_tweedie.rds` + `.ubj`. Each fit uses its own seed (`fit_seed()`).

Reload and score without refitting (loads the line model and all its peril models):

```r
source("R/0_setup.R"); source("R/model_io.R"); library(xgboost)
art  <- load_model("models/wendy_iteration_03/fitted", "motor_xgb_peril_sum")
pred <- pmax(score_model(art, read_clean("test_motor")), 0)
bi   <- score_model(art$components$bodily_injury, read_clean("test_motor"))   # one peril on its own
```

Replication check (saved models reloaded and re-scored vs the submission): **passed**

| line | model | rows | max_abs_diff |
|---|---|---|---|
| motor | xgb_peril_sum | 254,986 | 0 |
| buildings | xgb_peril_sum | 184,155 | 0 |
| contents | xgb_peril_sum | 187,498 | 0 |

## Settings
| setting | value |
|---|---|
| Model | Per peril: XGBoost reg:tweedie on peril cost per exposure-year, weight = exposure, hist trees, early stopping on a 10% policy holdout, then a balance factor so predictions on the training rows add up to the training target. Line cost = sum of its peril predictions |
| Perils | motor: own_damage, third_party_prop, bodily_injury, theft, glass_hail; buildings: storm, flood, escape_of_water, subsidence, fire, accidental_damage; contents: theft, escape_of_water, accidental_damage, flood |
| Training years (final fit) | 2021-2024 |
| Validation folds | fit 2021-2023, score 2024 |
| Large-loss cap | peril row cost capped at p99.9 of that peril's positive row costs, cap loading per peril on predictions |
| IBNR | peril targets x the peril's IBNR count factor for their policy year (report lags of 2021-22 losses of that peril) |
| Grid search | 900-second budget split by line (motor 0.4, buildings 0.3, contents 0.3) then equally over perils; random order over 1,296 configurations, tuned on 2021-2023 (20% policy holdout) |
| Excluded from features | row_id, policy_id, customer_id, address_id, period_start, period_end, exposure, exposure_raw, renewal_decision, surname, date_of_birth, policy_year, customer_service_contacts |
| Seed | 2026 + per-fit offset by line, peril and year (fit_seed()) |

## Accuracy - local Kaggle score (Tweedie D2, p = 1.5, higher = better)
Line = sum of its peril models, scored against the line's own baseline; ALL = one baseline over all rows (as Kaggle).
`deviance_share` = the line's share of the remaining combined error (where improvement moves the score most).

| line | d2_2024 | gini_2024 | deviance_share_2024 |
|---|---|---|---|
| motor | 0.0434 | 0.3834 | 0.4504 |
| buildings | 0.0720 | 0.4530 | 0.3599 |
| contents | 0.0591 | 0.4288 | 0.1897 |
| ALL | 0.0954 | 0.4877 | 1 |

### Versus iteration 2 (one XGBoost model per line, same 2024 fold: fit 2021-23)

| line | valid_year | wendy3_d2 | iter2_d2 | change |
|---|---|---|---|---|
| motor | 2024 | 0.0434 | 0.0498 | -0.0064 |
| buildings | 2024 | 0.0720 | 0.0709 | 0.0011 |
| contents | 2024 | 0.0591 | 0.0569 | 0.0022 |
| ALL | 2024 | 0.0954 | 0.0973 | -0.0019 |

| line | valid_year | d2 | gini | pred_vs_reported | pred_vs_developed | total_rounds |
|---|---|---|---|---|---|---|
| buildings | 2024 | 0.0720 | 0.4530 | 0.9584 | 0.8807 | 599 |
| contents | 2024 | 0.0591 | 0.4288 | 0.9648 | 0.9350 | 325 |
| motor | 2024 | 0.0434 | 0.3834 | 1.2409 | 1.0250 | 853 |

### By peril
Each peril model against its own constant-rate baseline. `cost_share` = the peril's share of the line's reported
cost in that year; `pred_vs_developed` compares predictions with reported cost x the peril IBNR factor.

![](d2_by_peril.png)

| line | peril | d2_2024 | gini_2024 | pred_vs_developed_2024 | cost_share_2024 |
|---|---|---|---|---|---|
| motor | third_party_prop | 0.0490 | 0.4048 | 0.8944 | 0.3473 |
| motor | own_damage | 0.1711 | 0.5274 | 0.8885 | 0.2595 |
| motor | bodily_injury | -0.0222 | 0.3572 | 1.2678 | 0.2316 |
| motor | theft | 0.0723 | 0.4073 | 0.9546 | 0.1087 |
| motor | glass_hail | 0.1312 | 0.4650 | 0.9076 | 0.0528 |
| buildings | flood | 0.4511 | 0.8779 | 0.9494 | 0.2750 |
| buildings | escape_of_water | 0.0421 | 0.3835 | 0.8506 | 0.2464 |
| buildings | fire | 0.0173 | 0.3268 | 0.9035 | 0.2335 |
| buildings | subsidence | 0.0705 | 0.4841 | 0.7413 | 0.1172 |
| buildings | storm | 0.0614 | 0.4336 | 0.9337 | 0.1090 |
| buildings | accidental_damage | 0.1261 | 0.5755 | 0.9483 | 0.0189 |
| contents | theft | 0.0277 | 0.3520 | 0.9168 | 0.4486 |
| contents | flood | 0.0679 | 0.8344 | 0.9417 | 0.2252 |
| contents | escape_of_water | 0.0472 | 0.4064 | 0.9561 | 0.2186 |
| contents | accidental_damage | 0.1370 | 0.5768 | 0.9522 | 0.1076 |

## Peril IBNR count factors
Same method as step 5 (expected share of claims reported by 31 Dec 2024 from 2021-22 lags), per peril.

| line | peril | median_lag_days | 2021 | 2022 | 2023 | 2024 |
|---|---|---|---|---|---|---|
| motor | bodily_injury | 127 | 1.0004 | 1.0047 | 1.0570 | 1.7608 |
| motor | glass_hail | 5 | 1 | 1 | 1.0018 | 1.0270 |
| motor | own_damage | 7 | 1 | 1 | 1.0010 | 1.0330 |
| motor | theft | 4 | 1 | 1 | 1.0011 | 1.0192 |
| motor | third_party_prop | 15 | 1 | 1 | 1.0015 | 1.0644 |
| buildings | accidental_damage | 7 | 1 | 1 | 1.0013 | 1.0332 |
| buildings | escape_of_water | 11 | 1 | 1 | 1.0015 | 1.0486 |
| buildings | fire | 4 | 1 | 1 | 1.0010 | 1.0186 |
| buildings | flood | 8 | 1 | 1 | 1.0011 | 1.0334 |
| buildings | storm | 8 | 1 | 1 | 1.0016 | 1.0352 |
| buildings | subsidence | 94 | 1 | 1.0002 | 1.0160 | 1.4968 |
| contents | accidental_damage | 7 | 1 | 1 | 1.0012 | 1.0342 |
| contents | escape_of_water | 11 | 1 | 1 | 1.0021 | 1.0495 |
| contents | flood | 7 | 1 | 1 | 1.0028 | 1.0401 |
| contents | theft | 4 | 1 | 1 | 1.0009 | 1.0187 |

## 2025 test predictions (final fit on 2021-24)
| line | model | perils | test_rows | test_exposure | predicted_total | predicted_burn_cost | train_burn_2021_23 | p50_row | p90_row | p99_row | max_row |
|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | xgb_peril_sum | 5 | 254,986 | 199,983.58 | 109,120,495.30 | 545.65 | 575.61 | 373.10 | 785.00 | 1,591.67 | 4,732.54 |
| buildings | xgb_peril_sum | 6 | 184,155 | 150,243.90 | 66,960,743.48 | 445.68 | 406.91 | 289.43 | 610.38 | 2,154.38 | 5,836.43 |
| contents | xgb_peril_sum | 4 | 187,498 | 150,123.77 | 17,911,352.21 | 119.31 | 109.37 | 79.78 | 170.34 | 443.75 | 1,025.42 |

### By peril
| line | peril | cap | cap_loading | balance | rounds | predicted_total | predicted_burn_cost | train_burn_2021_23 | share_of_line |
|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | 19,755.845 | 1.003 | 1.020 | 777 | 22,683,172.143 | 113.425 | 112.496 | 0.208 |
| motor | third_party_prop | 27,979.348 | 1.001 | 1.046 | 109 | 30,726,486.654 | 153.645 | 153.052 | 0.282 |
| motor | bodily_injury | 420,236.306 | 1.084 | 1.182 | 102 | 42,020,794.616 | 210.121 | 240.393 | 0.385 |
| motor | theft | 52,421.927 | 1.001 | 1.113 | 102 | 9,342,177.220 | 46.715 | 48.859 | 0.086 |
| motor | glass_hail | 7,964.975 | 1.001 | 1.049 | 72 | 4,347,864.673 | 21.741 | 20.807 | 0.040 |
| buildings | storm | 30,484.982 | 1.002 | 1.064 | 52 | 7,620,141.490 | 50.718 | 44.202 | 0.114 |
| buildings | flood | 299,310.611 | 1.001 | 1.276 | 30 | 18,837,489.321 | 125.379 | 115.660 | 0.281 |
| buildings | escape_of_water | 47,292.581 | 1.001 | 1.057 | 76 | 15,634,884.577 | 104.063 | 93.261 | 0.233 |
| buildings | subsidence | 163,287.601 | 1.002 | 1.293 | 101 | 9,076,904.122 | 60.414 | 51.735 | 0.136 |
| buildings | fire | 462,047.216 | 1.003 | 1.157 | 27 | 14,559,037.515 | 96.903 | 94.377 | 0.217 |
| buildings | accidental_damage | 8,943.536 | 1.001 | 1.093 | 165 | 1,232,286.450 | 8.202 | 7.676 | 0.018 |
| contents | theft | 30,736.154 | 1.003 | 1.021 | 73 | 7,902,638.896 | 52.641 | 45.322 | 0.441 |
| contents | escape_of_water | 21,874.843 | 1.002 | 1.105 | 166 | 3,980,925.781 | 26.518 | 24.645 | 0.222 |
| contents | accidental_damage | 5,935.202 | 1.001 | 1.096 | 24 | 1,919,443.940 | 12.786 | 11.801 | 0.107 |
| contents | flood | 92,208.129 | 1.002 | 1.483 | 22 | 4,108,343.588 | 27.366 | 27.604 | 0.229 |

## Grid search
Each configuration is trained on 80% of 2021-23 policies and scored on the other 20% with the Kaggle metric (peril cost only); the best per peril is used for every later fit of that peril (with its own early stopping).

![](xgb_tuning.png)

| line | peril | rounds_final_fit | params |
|---|---|---|---|
| motor | own_damage | 777 | max_depth=3, learning_rate=0.03, min_child_weight=50, subsample=0.9, colsample_bytree=0.8, reg_lambda=1, tweedie_variance_power=1.3 |
| motor | third_party_prop | 109 | max_depth=4, learning_rate=0.1, min_child_weight=10, subsample=0.9, colsample_bytree=0.8, reg_lambda=1, tweedie_variance_power=1.5 |
| motor | bodily_injury | 102 | max_depth=6, learning_rate=0.03, min_child_weight=1, subsample=0.9, colsample_bytree=0.6, reg_lambda=10, tweedie_variance_power=1.3 |
| motor | theft | 102 | max_depth=4, learning_rate=0.1, min_child_weight=1, subsample=0.7, colsample_bytree=0.6, reg_lambda=10, tweedie_variance_power=1.5 |
| motor | glass_hail | 72 | max_depth=4, learning_rate=0.1, min_child_weight=10, subsample=0.9, colsample_bytree=0.8, reg_lambda=1, tweedie_variance_power=1.5 |
| buildings | storm | 52 | max_depth=4, learning_rate=0.1, min_child_weight=50, subsample=0.9, colsample_bytree=0.6, reg_lambda=1, tweedie_variance_power=1.3 |
| buildings | flood | 30 | max_depth=4, learning_rate=0.1, min_child_weight=10, subsample=0.9, colsample_bytree=0.8, reg_lambda=10, tweedie_variance_power=1.5 |
| buildings | escape_of_water | 76 | max_depth=3, learning_rate=0.1, min_child_weight=1, subsample=0.9, colsample_bytree=0.8, reg_lambda=1, tweedie_variance_power=1.5 |
| buildings | subsidence | 101 | max_depth=4, learning_rate=0.03, min_child_weight=50, subsample=0.9, colsample_bytree=1, reg_lambda=1, tweedie_variance_power=1.5 |
| buildings | fire | 27 | max_depth=3, learning_rate=0.03, min_child_weight=50, subsample=0.7, colsample_bytree=1, reg_lambda=10, tweedie_variance_power=1.7 |
| buildings | accidental_damage | 165 | max_depth=4, learning_rate=0.03, min_child_weight=1, subsample=0.7, colsample_bytree=0.8, reg_lambda=1, tweedie_variance_power=1.3 |
| contents | theft | 73 | max_depth=3, learning_rate=0.05, min_child_weight=1, subsample=0.7, colsample_bytree=0.6, reg_lambda=10, tweedie_variance_power=1.3 |
| contents | escape_of_water | 166 | max_depth=3, learning_rate=0.03, min_child_weight=50, subsample=0.9, colsample_bytree=0.6, reg_lambda=1, tweedie_variance_power=1.7 |
| contents | accidental_damage | 24 | max_depth=4, learning_rate=0.1, min_child_weight=50, subsample=0.7, colsample_bytree=1, reg_lambda=10, tweedie_variance_power=1.5 |
| contents | flood | 22 | max_depth=4, learning_rate=0.1, min_child_weight=10, subsample=0.9, colsample_bytree=0.8, reg_lambda=1, tweedie_variance_power=1.5 |

| line | peril | config | max_depth | learning_rate | min_child_weight | subsample | colsample_bytree | reg_lambda | tweedie_variance_power | holdout_d2 | rounds | seconds | rank |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | bodily_injury | 2 | 6 | 0.0300 | 1 | 0.9000 | 0.6000 | 10 | 1.3000 | 0.0681 | 126 | 21.6000 | 1 |
| motor | bodily_injury | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0679 | 46 | 11.8000 | 2 |
| motor | bodily_injury | 4 | 6 | 0.1000 | 1 | 0.7000 | 1 | 10 | 1.3000 | 0.0592 | 18 | 9.2000 | 3 |
| motor | glass_hail | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.1430 | 81 | 16 | 1 |
| motor | glass_hail | 5 | 3 | 0.0500 | 50 | 0.9000 | 0.6000 | 1 | 1.3000 | 0.1428 | 230 | 27.5000 | 2 |
| motor | glass_hail | 3 | 4 | 0.1000 | 1 | 0.9000 | 0.8000 | 1 | 1.3000 | 0.1428 | 95 | 15.5000 | 3 |
| motor | own_damage | 4 | 3 | 0.0300 | 50 | 0.9000 | 0.8000 | 1 | 1.3000 | 0.1683 | 690 | 67.8000 | 1 |
| motor | own_damage | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.1635 | 65 | 12 | 2 |
| motor | own_damage | 3 | 8 | 0.0300 | 50 | 0.9000 | 1 | 1 | 1.7000 | 0.1581 | 83 | 19.1000 | 3 |
| motor | theft | 3 | 4 | 0.1000 | 1 | 0.7000 | 0.6000 | 10 | 1.5000 | 0.0901 | 49 | 12.5000 | 1 |
| motor | theft | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0887 | 53 | 11.7000 | 2 |
| motor | theft | 4 | 6 | 0.0500 | 1 | 0.9000 | 1 | 1 | 1.3000 | 0.0879 | 84 | 14.5000 | 3 |
| motor | third_party_prop | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0681 | 92 | 15.7000 | 1 |
| motor | third_party_prop | 2 | 8 | 0.0300 | 50 | 0.9000 | 0.8000 | 1 | 1.3000 | 0.0650 | 93 | 22.5000 | 2 |
| motor | third_party_prop | 3 | 8 | 0.0300 | 1 | 0.9000 | 1 | 10 | 1.5000 | 0.0640 | 74 | 18.4000 | 3 |
| buildings | accidental_damage | 4 | 4 | 0.0300 | 1 | 0.7000 | 0.8000 | 1 | 1.3000 | 0.1542 | 117 | 19.2000 | 1 |
| buildings | accidental_damage | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.1517 | 31 | 9.7000 | 2 |
| buildings | accidental_damage | 3 | 6 | 0.0300 | 50 | 0.7000 | 0.6000 | 10 | 1.7000 | 0.1366 | 48 | 12.7000 | 3 |
| buildings | escape_of_water | 3 | 3 | 0.1000 | 1 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0450 | 89 | 13.2000 | 1 |
| buildings | escape_of_water | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0414 | 63 | 9.7000 | 2 |
| buildings | escape_of_water | 4 | 4 | 0.0500 | 1 | 0.7000 | 0.6000 | 10 | 1.7000 | 0.0397 | 82 | 12.2000 | 3 |
| buildings | fire | 4 | 3 | 0.0300 | 50 | 0.7000 | 1 | 10 | 1.7000 | 0.0209 | 37 | 10.7000 | 1 |
| buildings | fire | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0120 | 11 | 6.5000 | 2 |
| buildings | fire | 3 | 6 | 0.0500 | 1 | 0.7000 | 0.8000 | 1 | 1.5000 | 0.0072 | 7 | 7.2000 | 3 |
| buildings | flood | 3 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 10 | 1.5000 | 0.4617 | 34 | 3.6000 | 1 |
| buildings | flood | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.4617 | 34 | 3.6000 | 2 |
| buildings | flood | 4 | 3 | 0.0300 | 1 | 0.7000 | 0.8000 | 10 | 1.5000 | 0.4595 | 120 | 6.2000 | 3 |
| buildings | storm | 2 | 4 | 0.1000 | 50 | 0.9000 | 0.6000 | 1 | 1.3000 | 0.0752 | 78 | 9.3000 | 1 |
| buildings | storm | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0735 | 48 | 8.7000 | 2 |
| buildings | storm | 4 | 6 | 0.0300 | 10 | 0.9000 | 0.8000 | 1 | 1.3000 | 0.0718 | 105 | 13.9000 | 3 |
| buildings | subsidence | 2 | 4 | 0.0300 | 50 | 0.9000 | 1 | 1 | 1.5000 | 0.0561 | 37 | 9.3000 | 1 |
| buildings | subsidence | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0543 | 13 | 8.2000 | 2 |
| buildings | subsidence | 5 | 4 | 0.1000 | 1 | 0.7000 | 0.8000 | 1 | 1.7000 | 0.0388 | 6 | 7.1000 | 3 |
| contents | accidental_damage | 4 | 4 | 0.1000 | 50 | 0.7000 | 1 | 10 | 1.5000 | 0.1341 | 29 | 9.6000 | 1 |
| contents | accidental_damage | 3 | 4 | 0.0500 | 10 | 0.7000 | 1 | 10 | 1.3000 | 0.1309 | 80 | 16.1000 | 2 |
| contents | accidental_damage | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.1290 | 26 | 8.9000 | 3 |
| contents | escape_of_water | 6 | 3 | 0.0300 | 50 | 0.9000 | 0.6000 | 1 | 1.7000 | 0.0385 | 139 | 21.1000 | 1 |
| contents | escape_of_water | 2 | 4 | 0.0300 | 1 | 0.9000 | 0.8000 | 1 | 1.3000 | 0.0371 | 113 | 16.5000 | 2 |
| contents | escape_of_water | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0345 | 23 | 10.1000 | 3 |
| contents | flood | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.5320 | 51 | 12.2000 | 1 |
| contents | flood | 3 | 4 | 0.0500 | 50 | 0.9000 | 0.6000 | 10 | 1.7000 | 0.5039 | 66 | 13.1000 | 2 |
| contents | flood | 2 | 8 | 0.1000 | 50 | 0.7000 | 0.8000 | 1 | 1.3000 | 0.4663 | 28 | 11.7000 | 3 |
| contents | theft | 5 | 3 | 0.0500 | 1 | 0.7000 | 0.6000 | 10 | 1.3000 | 0.0369 | 134 | 17.7000 | 1 |
| contents | theft | 3 | 3 | 0.0300 | 50 | 0.9000 | 0.8000 | 1 | 1.7000 | 0.0369 | 207 | 27.8000 | 2 |
| contents | theft | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0341 | 47 | 8.1000 | 3 |

## Features used (same for every peril of a line)
| line | n_features | features |
|---|---|---|
| motor | 70 | driver_age, years_licensed, ncb_years, vehicle_value_group, vehicle_age, make_model, engine_size_cc, body_type, transmission, seats, vehicle_colour, fuel_type, driver_assist, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, telematics_opt_in, telematics_score, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, written_premium, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, email_domain, marketing_consent, document_preference, previous_insurer, campaign_code, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer |
| buildings | 58 | policyholder_age, sum_insured, construction_type, occupancy, days_unoccupied, smoke_alarms, accidental_damage_cover, mortgage, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, written_premium, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, email_domain, marketing_consent, document_preference, previous_insurer, campaign_code, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer |
| contents | 59 | policyholder_age, sum_insured, tenure, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, written_premium, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, email_domain, marketing_consent, document_preference, previous_insurer, campaign_code, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer |

## Variable importance (final fit, share of total gain)
![](xgb_importance_motor.png)

![](xgb_importance_buildings.png)

![](xgb_importance_contents.png)

| line | peril | rank | Feature | Gain | Cover | Frequency |
|---|---|---|---|---|---|---|
| motor | own_damage | 1 | cover_type | 0.4905 | 0.0890 | 0.0386 |
| motor | own_damage | 2 | written_premium | 0.1194 | 0.0332 | 0.0412 |
| motor | own_damage | 3 | ncb_years | 0.0568 | 0.0344 | 0.0297 |
| motor | own_damage | 4 | vehicle_age | 0.0511 | 0.0679 | 0.0545 |
| motor | own_damage | 5 | annual_mileage | 0.0299 | 0.0548 | 0.0402 |
| motor | own_damage | 6 | make_model | 0.0228 | 0.0349 | 0.0435 |
| motor | own_damage | 7 | voluntary_excess | 0.0209 | 0.0414 | 0.0278 |
| motor | own_damage | 8 | driver_age | 0.0195 | 0.0223 | 0.0239 |
| motor | own_damage | 9 | prior_claims_5y | 0.0165 | 0.0374 | 0.0224 |
| motor | own_damage | 10 | marketing_segment | 0.0150 | 0.0129 | 0.0135 |
| motor | third_party_prop | 1 | ncb_years | 0.2171 | 0.0548 | 0.0366 |
| motor | third_party_prop | 2 | written_premium | 0.0878 | 0.0228 | 0.0312 |
| motor | third_party_prop | 3 | driver_age | 0.0624 | 0.0217 | 0.0295 |
| motor | third_party_prop | 4 | annual_mileage | 0.0594 | 0.0667 | 0.0501 |
| motor | third_party_prop | 5 | years_licensed | 0.0494 | 0.0280 | 0.0232 |
| motor | third_party_prop | 6 | customer_age | 0.0470 | 0.0184 | 0.0147 |
| motor | third_party_prop | 7 | make_model | 0.0423 | 0.0446 | 0.0514 |
| motor | third_party_prop | 8 | marketing_segment | 0.0409 | 0.0194 | 0.0173 |
| motor | third_party_prop | 9 | region | 0.0261 | 0.0374 | 0.0282 |
| motor | third_party_prop | 10 | voluntary_excess | 0.0253 | 0.0391 | 0.0265 |
| motor | bodily_injury | 1 | ncb_years | 0.0994 | 0.0904 | 0.0250 |
| motor | bodily_injury | 2 | make_model | 0.0933 | 0.1245 | 0.0551 |
| motor | bodily_injury | 3 | driver_age | 0.0662 | 0.0333 | 0.0277 |
| motor | bodily_injury | 4 | written_premium | 0.0463 | 0.0381 | 0.0431 |
| motor | bodily_injury | 5 | customer_age | 0.0425 | 0.0225 | 0.0152 |
| motor | bodily_injury | 6 | annual_mileage | 0.0376 | 0.0720 | 0.0311 |
| motor | bodily_injury | 7 | previous_insurer | 0.0367 | 0.0433 | 0.0342 |
| motor | bodily_injury | 8 | years_licensed | 0.0308 | 0.0301 | 0.0258 |
| motor | bodily_injury | 9 | distance_to_river_km | 0.0294 | 0.0201 | 0.0371 |
| motor | bodily_injury | 10 | rainfall_mm | 0.0264 | 0.0174 | 0.0338 |
| motor | theft | 1 | cover_type | 0.1987 | 0.0783 | 0.0246 |
| motor | theft | 2 | make_model | 0.1100 | 0.0802 | 0.0575 |
| motor | theft | 3 | vehicle_age | 0.0555 | 0.0647 | 0.0470 |
| motor | theft | 4 | overnight_parking | 0.0426 | 0.0423 | 0.0204 |
| motor | theft | 5 | written_premium | 0.0374 | 0.0331 | 0.0376 |
| motor | theft | 6 | urban_density | 0.0363 | 0.0424 | 0.0261 |
| motor | theft | 7 | vehicle_value_group | 0.0278 | 0.0312 | 0.0246 |
| motor | theft | 8 | previous_insurer | 0.0228 | 0.0270 | 0.0350 |
| motor | theft | 9 | rainfall_mm | 0.0213 | 0.0242 | 0.0324 |
| motor | theft | 10 | mean_temperature_c | 0.0200 | 0.0332 | 0.0308 |
| motor | glass_hail | 1 | cover_type | 0.5683 | 0.1341 | 0.0477 |
| motor | glass_hail | 2 | hail_days | 0.0780 | 0.0938 | 0.0661 |
| motor | glass_hail | 3 | voluntary_excess | 0.0703 | 0.0765 | 0.0382 |
| motor | glass_hail | 4 | make_model | 0.0453 | 0.0635 | 0.0720 |
| motor | glass_hail | 5 | region | 0.0209 | 0.0287 | 0.0308 |
| motor | glass_hail | 6 | annual_mileage | 0.0188 | 0.0527 | 0.0441 |
| motor | glass_hail | 7 | written_premium | 0.0155 | 0.0282 | 0.0338 |
| motor | glass_hail | 8 | prior_claims_5y | 0.0119 | 0.0364 | 0.0184 |
| motor | glass_hail | 9 | vehicle_value_group | 0.0106 | 0.0187 | 0.0250 |
| motor | glass_hail | 10 | previous_insurer | 0.0099 | 0.0259 | 0.0338 |
| buildings | storm | 1 | property_type | 0.1472 | 0.0628 | 0.0223 |
| buildings | storm | 2 | year_built | 0.1383 | 0.0870 | 0.0564 |
| buildings | storm | 3 | sum_insured | 0.0934 | 0.0626 | 0.0584 |
| buildings | storm | 4 | wind_exposure_index | 0.0659 | 0.0659 | 0.0564 |
| buildings | storm | 5 | energy_rating | 0.0427 | 0.0270 | 0.0262 |
| buildings | storm | 6 | distance_to_river_km | 0.0309 | 0.0380 | 0.0505 |
| buildings | storm | 7 | written_premium | 0.0299 | 0.0240 | 0.0282 |
| buildings | storm | 8 | rainfall_mm | 0.0288 | 0.0465 | 0.0459 |
| buildings | storm | 9 | region | 0.0220 | 0.0270 | 0.0230 |
| buildings | storm | 10 | years_at_address | 0.0218 | 0.0113 | 0.0334 |
| buildings | flood | 1 | written_premium | 0.4554 | 0.1568 | 0.0993 |
| buildings | flood | 2 | elevation_m | 0.3105 | 0.2334 | 0.1178 |
| buildings | flood | 3 | distance_to_river_km | 0.0357 | 0.0872 | 0.0905 |
| buildings | flood | 4 | flood_zone | 0.0354 | 0.0404 | 0.0316 |
| buildings | flood | 5 | rainfall_mm | 0.0123 | 0.0381 | 0.0466 |
| buildings | flood | 6 | previous_insurer | 0.0108 | 0.0351 | 0.0457 |
| buildings | flood | 7 | dry_summer_index | 0.0090 | 0.0196 | 0.0264 |
| buildings | flood | 8 | policyholder_age | 0.0087 | 0.0177 | 0.0281 |
| buildings | flood | 9 | days_unoccupied | 0.0078 | 0.0222 | 0.0360 |
| buildings | flood | 10 | freezing_days | 0.0069 | 0.0188 | 0.0228 |
| buildings | escape_of_water | 1 | year_built | 0.1718 | 0.0668 | 0.0596 |
| buildings | escape_of_water | 2 | sum_insured | 0.1477 | 0.1035 | 0.0911 |
| buildings | escape_of_water | 3 | freezing_days | 0.0701 | 0.0640 | 0.0540 |
| buildings | escape_of_water | 4 | days_unoccupied | 0.0658 | 0.0523 | 0.0472 |
| buildings | escape_of_water | 5 | region | 0.0538 | 0.0329 | 0.0236 |
| buildings | escape_of_water | 6 | prior_claims_5y | 0.0439 | 0.0581 | 0.0326 |
| buildings | escape_of_water | 7 | previous_insurer | 0.0434 | 0.0369 | 0.0529 |
| buildings | escape_of_water | 8 | written_premium | 0.0355 | 0.0359 | 0.0439 |
| buildings | escape_of_water | 9 | construction_type | 0.0235 | 0.0375 | 0.0236 |
| buildings | escape_of_water | 10 | energy_rating | 0.0218 | 0.0294 | 0.0247 |
| buildings | subsidence | 1 | soil_type | 0.1504 | 0.1089 | 0.0434 |
| buildings | subsidence | 2 | dry_summer_index | 0.1429 | 0.0584 | 0.0515 |
| buildings | subsidence | 3 | sum_insured | 0.0909 | 0.1068 | 0.0787 |
| buildings | subsidence | 4 | previous_insurer | 0.0532 | 0.0730 | 0.0577 |
| buildings | subsidence | 5 | mean_temperature_c | 0.0459 | 0.0418 | 0.0389 |
| buildings | subsidence | 6 | years_at_address | 0.0375 | 0.0514 | 0.0497 |
| buildings | subsidence | 7 | occupation | 0.0297 | 0.0419 | 0.0367 |
| buildings | subsidence | 8 | campaign_code | 0.0272 | 0.0413 | 0.0327 |
| buildings | subsidence | 9 | elevation_m | 0.0246 | 0.0297 | 0.0389 |
| buildings | subsidence | 10 | days_unoccupied | 0.0246 | 0.0468 | 0.0322 |
| buildings | fire | 1 | energy_rating | 0.1213 | 0.1462 | 0.0775 |
| buildings | fire | 2 | sum_insured | 0.1163 | 0.1216 | 0.0886 |
| buildings | fire | 3 | dry_summer_index | 0.0654 | 0.0588 | 0.0609 |
| buildings | fire | 4 | written_premium | 0.0649 | 0.0529 | 0.0683 |
| buildings | fire | 5 | previous_insurer | 0.0595 | 0.0736 | 0.0627 |
| buildings | fire | 6 | wildfire_index | 0.0584 | 0.0717 | 0.0517 |
| buildings | fire | 7 | year_built | 0.0420 | 0.0368 | 0.0480 |
| buildings | fire | 8 | region | 0.0379 | 0.0215 | 0.0369 |
| buildings | fire | 9 | days_unoccupied | 0.0374 | 0.0424 | 0.0443 |
| buildings | fire | 10 | occupation | 0.0313 | 0.0344 | 0.0351 |
| buildings | accidental_damage | 1 | accidental_damage_cover | 0.4707 | 0.1241 | 0.0355 |
| buildings | accidental_damage | 2 | year_built | 0.0378 | 0.0558 | 0.0507 |
| buildings | accidental_damage | 3 | sum_insured | 0.0328 | 0.0533 | 0.0542 |
| buildings | accidental_damage | 4 | distance_to_river_km | 0.0270 | 0.0325 | 0.0542 |
| buildings | accidental_damage | 5 | voluntary_excess | 0.0260 | 0.0627 | 0.0321 |
| buildings | accidental_damage | 6 | previous_insurer | 0.0245 | 0.0491 | 0.0417 |
| buildings | accidental_damage | 7 | written_premium | 0.0240 | 0.0304 | 0.0420 |
| buildings | accidental_damage | 8 | days_unoccupied | 0.0182 | 0.0248 | 0.0377 |
| buildings | accidental_damage | 9 | wind_exposure_index | 0.0169 | 0.0210 | 0.0364 |
| buildings | accidental_damage | 10 | mean_temperature_c | 0.0169 | 0.0327 | 0.0349 |
| contents | theft | 1 | written_premium | 0.2460 | 0.1426 | 0.0945 |
| contents | theft | 2 | urban_density | 0.0906 | 0.0835 | 0.0518 |
| contents | theft | 3 | sum_insured | 0.0720 | 0.0537 | 0.0541 |
| contents | theft | 4 | high_value_items | 0.0633 | 0.0743 | 0.0553 |
| contents | theft | 5 | security_level | 0.0449 | 0.0533 | 0.0438 |
| contents | theft | 6 | prior_claims_5y | 0.0431 | 0.0603 | 0.0403 |
| contents | theft | 7 | marketing_segment | 0.0404 | 0.0423 | 0.0369 |
| contents | theft | 8 | previous_insurer | 0.0296 | 0.0231 | 0.0346 |
| contents | theft | 9 | rainfall_mm | 0.0280 | 0.0420 | 0.0461 |
| contents | theft | 10 | customer_age | 0.0270 | 0.0332 | 0.0346 |
| contents | escape_of_water | 1 | written_premium | 0.1712 | 0.0800 | 0.0640 |
| contents | escape_of_water | 2 | sum_insured | 0.1693 | 0.1401 | 0.1027 |
| contents | escape_of_water | 3 | freezing_days | 0.0834 | 0.0689 | 0.0680 |
| contents | escape_of_water | 4 | mean_temperature_c | 0.0603 | 0.0412 | 0.0453 |
| contents | escape_of_water | 5 | marketing_segment | 0.0555 | 0.0569 | 0.0480 |
| contents | escape_of_water | 6 | voluntary_excess | 0.0448 | 0.0697 | 0.0460 |
| contents | escape_of_water | 7 | wildfire_index | 0.0396 | 0.0295 | 0.0333 |
| contents | escape_of_water | 8 | prior_claims_5y | 0.0326 | 0.0689 | 0.0413 |
| contents | escape_of_water | 9 | year_built | 0.0303 | 0.0452 | 0.0433 |
| contents | escape_of_water | 10 | distance_to_river_km | 0.0240 | 0.0336 | 0.0367 |
| contents | accidental_damage | 1 | accidental_damage_cover | 0.5100 | 0.1097 | 0.0448 |
| contents | accidental_damage | 2 | voluntary_excess | 0.0556 | 0.0966 | 0.0529 |
| contents | accidental_damage | 3 | written_premium | 0.0385 | 0.0599 | 0.0511 |
| contents | accidental_damage | 4 | sum_insured | 0.0359 | 0.0551 | 0.0511 |
| contents | accidental_damage | 5 | marketing_segment | 0.0295 | 0.0512 | 0.0404 |
| contents | accidental_damage | 6 | distance_to_river_km | 0.0218 | 0.0435 | 0.0556 |
| contents | accidental_damage | 7 | year_built | 0.0182 | 0.0277 | 0.0413 |
| contents | accidental_damage | 8 | previous_insurer | 0.0173 | 0.0276 | 0.0332 |
| contents | accidental_damage | 9 | wind_exposure_index | 0.0171 | 0.0259 | 0.0404 |
| contents | accidental_damage | 10 | region | 0.0169 | 0.0307 | 0.0269 |
| contents | flood | 1 | flood_zone | 0.4679 | 0.1401 | 0.0747 |
| contents | flood | 2 | elevation_m | 0.2659 | 0.2510 | 0.1298 |
| contents | flood | 3 | distance_to_river_km | 0.0370 | 0.0672 | 0.0836 |
| contents | flood | 4 | sum_insured | 0.0233 | 0.0472 | 0.0501 |
| contents | flood | 5 | rainfall_mm | 0.0204 | 0.0284 | 0.0531 |
| contents | flood | 6 | previous_insurer | 0.0198 | 0.0381 | 0.0551 |
| contents | flood | 7 | written_premium | 0.0164 | 0.0419 | 0.0531 |
| contents | flood | 8 | occupation | 0.0113 | 0.0292 | 0.0246 |
| contents | flood | 9 | region | 0.0112 | 0.0289 | 0.0256 |
| contents | flood | 10 | campaign_code | 0.0093 | 0.0371 | 0.0256 |

