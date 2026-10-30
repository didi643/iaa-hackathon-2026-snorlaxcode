# Iteration 2

**Run id** `20261021_0951` | **Generated** 2026-10-21 10:08 | **Git commit** `` | **Submission file** `submission_20261021_0951.csv`

**Change in this iteration:** XGBoost Tweedie for motor, buildings and contents (same features as iteration 1's tree model; categoricals coded by their training cost rate). Hyper-parameters per line from a random grid search with a 10-minute budget on a 20% policy holdout of 2021-22.

Public Kaggle scores for this iteration are in the submission log (`Iteration` column) and on the
Model iterations overview page.

## Reproducibility
Submission file MD5 `64b6ce2085ed4df632435d508a9a8b9c`. The final models are saved in `models/iteration_02/fitted/` (`<line>_xgb_tweedie.rds` + `.ubj`). Each fit uses its own seed (`fit_seed()`).

Reload and score without refitting:

```r
source("R/0_setup.R"); source("R/model_io.R"); library(xgboost)
art  <- load_model("models/iteration_02/fitted", "motor_xgb_tweedie")
pred <- pmax(score_model(art, read_clean("test_motor")), 0)
```

Replication check (saved models reloaded and re-scored vs the submission): **passed**

| line | model | rows | max_abs_diff |
|---|---|---|---|
| motor | xgb_tweedie | 254,986 | 0 |
| buildings | xgb_tweedie | 184,155 | 0 |
| contents | xgb_tweedie | 187,498 | 0 |

## Settings
| setting | value |
|---|---|
| Model | XGBoost reg:tweedie on cost per exposure-year, weight = exposure, hist trees, early stopping on a 10% policy holdout |
| Training years (final fit) | 2021-2024 |
| Validation folds | fit < 2024, score 2024; fit < 2023, score 2023 |
| Large-loss cap | row cost capped at p99.9 per line, cap loading on predictions |
| IBNR | targets x IBNR count factor of their policy year (step 5) |
| Grid search | 600-second budget, random order over 1,296 configurations, tuned on 2021-2022 (20% policy holdout); tried motor 28, buildings 47, contents 39 |
| Selected params | motor: max_depth=4, learning_rate=0.03, min_child_weight=50, subsample=0.9, colsample_bytree=0.6, reg_lambda=1, tweedie_variance_power=1.7; buildings: max_depth=3, learning_rate=0.03, min_child_weight=1, subsample=0.9, colsample_bytree=0.8, reg_lambda=1, tweedie_variance_power=1.5; contents: max_depth=4, learning_rate=0.1, min_child_weight=10, subsample=0.9, colsample_bytree=0.6, reg_lambda=10, tweedie_variance_power=1.3 |
| Boosting rounds (final fit) | motor=335, buildings=294, contents=65 |
| Excluded from features | row_id, policy_id, customer_id, address_id, period_start, period_end, exposure, exposure_raw, renewal_decision, surname, date_of_birth, policy_year, customer_service_contacts |
| Seed | 2026 + per-fit offset by line and year (fit_seed()) |

## Grid search
Each configuration is trained on 80% of 2021-22 policies and scored on the other 20% with the Kaggle metric; the best per line is used for every later fit (with its own early stopping).

![](xgb_tuning.png)

| line | config | max_depth | learning_rate | min_child_weight | subsample | colsample_bytree | reg_lambda | tweedie_variance_power | holdout_d2 | rounds | seconds | rank |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| buildings | 40 | 3 | 0.0300 | 1 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0823 | 370 | 9 | 1 |
| buildings | 3 | 3 | 0.1000 | 1 | 0.7000 | 0.6000 | 10 | 1.5000 | 0.0816 | 70 | 3 | 2 |
| buildings | 8 | 3 | 0.0300 | 50 | 0.7000 | 1 | 10 | 1.3000 | 0.0814 | 238 | 6 | 3 |
| buildings | 14 | 3 | 0.0500 | 1 | 0.9000 | 0.6000 | 1 | 1.5000 | 0.0812 | 144 | 5 | 4 |
| buildings | 30 | 3 | 0.0300 | 50 | 0.7000 | 0.8000 | 1 | 1.3000 | 0.0811 | 205 | 6 | 5 |
| buildings | 29 | 3 | 0.0300 | 1 | 0.7000 | 0.8000 | 10 | 1.5000 | 0.0807 | 316 | 9 | 6 |
| buildings | 45 | 3 | 0.0500 | 10 | 0.7000 | 0.6000 | 10 | 1.7000 | 0.0806 | 155 | 5 | 7 |
| buildings | 11 | 3 | 0.0300 | 10 | 0.9000 | 0.6000 | 10 | 1.5000 | 0.0805 | 230 | 6 | 8 |
| buildings | 26 | 3 | 0.0500 | 50 | 0.7000 | 0.6000 | 1 | 1.7000 | 0.0803 | 153 | 5 | 9 |
| buildings | 33 | 3 | 0.0500 | 10 | 0.7000 | 0.6000 | 10 | 1.5000 | 0.0803 | 133 | 4 | 10 |
| contents | 33 | 4 | 0.1000 | 10 | 0.9000 | 0.6000 | 10 | 1.3000 | 0.0722 | 62 | 3 | 1 |
| contents | 22 | 3 | 0.0500 | 50 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0716 | 178 | 5 | 2 |
| contents | 18 | 3 | 0.0500 | 50 | 0.9000 | 0.6000 | 10 | 1.3000 | 0.0714 | 185 | 5 | 3 |
| contents | 3 | 4 | 0.0300 | 50 | 0.9000 | 0.6000 | 1 | 1.5000 | 0.0713 | 169 | 6 | 4 |
| contents | 28 | 3 | 0.1000 | 10 | 0.9000 | 0.6000 | 10 | 1.3000 | 0.0709 | 84 | 3 | 5 |
| contents | 20 | 3 | 0.1000 | 10 | 0.7000 | 0.8000 | 10 | 1.3000 | 0.0708 | 82 | 3 | 6 |
| contents | 11 | 3 | 0.0500 | 50 | 0.7000 | 1 | 1 | 1.5000 | 0.0705 | 122 | 4 | 7 |
| contents | 29 | 4 | 0.0300 | 1 | 0.7000 | 0.8000 | 10 | 1.5000 | 0.0704 | 186 | 6 | 8 |
| contents | 19 | 4 | 0.0300 | 50 | 0.7000 | 0.8000 | 1 | 1.3000 | 0.0703 | 280 | 8 | 9 |
| contents | 31 | 3 | 0.1000 | 50 | 0.7000 | 0.8000 | 1 | 1.5000 | 0.0701 | 90 | 3 | 10 |
| motor | 23 | 4 | 0.0300 | 50 | 0.9000 | 0.6000 | 1 | 1.7000 | 0.0597 | 318 | 15 | 1 |
| motor | 11 | 3 | 0.0300 | 10 | 0.9000 | 0.6000 | 10 | 1.3000 | 0.0597 | 514 | 22 | 2 |
| motor | 16 | 3 | 0.0300 | 50 | 0.9000 | 0.6000 | 1 | 1.7000 | 0.0596 | 458 | 16 | 3 |
| motor | 17 | 3 | 0.0300 | 1 | 0.9000 | 0.8000 | 1 | 1.3000 | 0.0596 | 544 | 19 | 4 |
| motor | 12 | 3 | 0.1000 | 10 | 0.7000 | 1 | 1 | 1.7000 | 0.0593 | 93 | 5 | 5 |
| motor | 25 | 4 | 0.0500 | 10 | 0.9000 | 0.8000 | 10 | 1.7000 | 0.0592 | 157 | 9 | 6 |
| motor | 8 | 4 | 0.0500 | 1 | 0.7000 | 0.6000 | 1 | 1.3000 | 0.0591 | 245 | 12 | 7 |
| motor | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.8000 | 1 | 1.5000 | 0.0591 | 93 | 5 | 8 |
| motor | 2 | 4 | 0.1000 | 1 | 0.7000 | 0.6000 | 10 | 1.3000 | 0.0588 | 86 | 6 | 9 |
| motor | 20 | 4 | 0.1000 | 50 | 0.7000 | 0.8000 | 10 | 1.5000 | 0.0588 | 85 | 6 | 10 |

## Accuracy - local Kaggle score (Tweedie D2, p = 1.5, higher = better)
`deviance_share` = the line's share of the remaining combined error (where improvement moves the score most).

| line | d2_2023 | d2_2024 | gini_2023 | gini_2024 | deviance_share_2023 | deviance_share_2024 |
|---|---|---|---|---|---|---|
| motor | 0.0376 | 0.0498 | 0.3787 | 0.3861 | 0.4866 | 0.4484 |
| buildings | 0.0703 | 0.0709 | 0.4578 | 0.4518 | 0.3334 | 0.3611 |
| contents | 0.0599 | 0.0569 | 0.4312 | 0.4222 | 0.1800 | 0.1905 |
| ALL | 0.0997 | 0.0973 | 0.5122 | 0.4907 | 1 | 1 |

| line | valid_year | d2 | gini | pred_vs_reported | pred_vs_developed | rounds |
|---|---|---|---|---|---|---|
| buildings | 2023 | 0.0703 | 0.4578 | 0.8997 | 0.8978 | 195 |
| buildings | 2024 | 0.0709 | 0.4518 | 0.9194 | 0.8715 | 202 |
| contents | 2023 | 0.0599 | 0.4312 | 0.8746 | 0.8733 | 61 |
| contents | 2024 | 0.0569 | 0.4222 | 0.9303 | 0.9006 | 114 |
| motor | 2023 | 0.0376 | 0.3787 | 0.8675 | 0.8630 | 273 |
| motor | 2024 | 0.0498 | 0.3861 | 1.1524 | 1.0725 | 330 |

## 2025 test predictions (final fit on 2021-24)
| line | model | cap | cap_loading | test_rows | test_exposure | predicted_total | predicted_burn_cost | train_burn_2021_23 | p50_row | p90_row | p99_row | max_row |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | xgb_tweedie | 124,533.75 | 1.05 | 254,986 | 199,983.58 | 99,752,386.14 | 498.80 | 575.61 | 336.93 | 729.43 | 1,486.11 | 4,783.87 |
| buildings | xgb_tweedie | 280,163.03 | 1.01 | 184,155 | 150,243.90 | 65,243,666.50 | 434.25 | 406.91 | 280.32 | 607.91 | 2,063.99 | 7,882.64 |
| contents | xgb_tweedie | 45,596.95 | 1.01 | 187,498 | 150,123.77 | 17,884,986.31 | 119.13 | 109.37 | 76.58 | 176.79 | 442.59 | 2,891.57 |

## Features used
| line | n_features | features |
|---|---|---|
| motor | 70 | driver_age, years_licensed, ncb_years, vehicle_value_group, vehicle_age, make_model, engine_size_cc, body_type, transmission, seats, vehicle_colour, fuel_type, driver_assist, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, telematics_opt_in, telematics_score, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, written_premium, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, email_domain, marketing_consent, document_preference, previous_insurer, campaign_code, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer |
| buildings | 58 | policyholder_age, sum_insured, construction_type, occupancy, days_unoccupied, smoke_alarms, accidental_damage_cover, mortgage, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, written_premium, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, email_domain, marketing_consent, document_preference, previous_insurer, campaign_code, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer |
| contents | 59 | policyholder_age, sum_insured, tenure, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, written_premium, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, email_domain, marketing_consent, document_preference, previous_insurer, campaign_code, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer |

## Variable importance (final fit, share of total gain)
![](xgb_importance.png)

| line | rank | Feature | Gain | Cover | Frequency |
|---|---|---|---|---|---|
| motor | 1 | ncb_years | 0.2290 | 0.0609 | 0.0367 |
| motor | 2 | written_premium | 0.1245 | 0.0461 | 0.0557 |
| motor | 3 | annual_mileage | 0.0653 | 0.0740 | 0.0512 |
| motor | 4 | make_model | 0.0489 | 0.0569 | 0.0574 |
| motor | 5 | years_licensed | 0.0482 | 0.0394 | 0.0316 |
| motor | 6 | cover_type | 0.0370 | 0.0387 | 0.0301 |
| motor | 7 | customer_age | 0.0366 | 0.0218 | 0.0194 |
| motor | 8 | prior_claims_5y | 0.0341 | 0.0512 | 0.0304 |
| motor | 9 | driver_age | 0.0315 | 0.0226 | 0.0239 |
| motor | 10 | vehicle_age | 0.0299 | 0.0449 | 0.0424 |
| motor | 11 | marketing_segment | 0.0295 | 0.0217 | 0.0265 |
| motor | 12 | voluntary_excess | 0.0292 | 0.0485 | 0.0304 |
| motor | 13 | telematics_score | 0.0191 | 0.0351 | 0.0306 |
| motor | 14 | urban_density | 0.0188 | 0.0412 | 0.0256 |
| motor | 15 | region | 0.0182 | 0.0351 | 0.0299 |
| motor | 16 | vehicle_use | 0.0140 | 0.0359 | 0.0194 |
| motor | 17 | channel | 0.0131 | 0.0292 | 0.0169 |
| motor | 18 | previous_insurer | 0.0127 | 0.0205 | 0.0282 |
| motor | 19 | payment_method | 0.0101 | 0.0203 | 0.0114 |
| motor | 20 | rainfall_mm | 0.0099 | 0.0170 | 0.0280 |
| motor | 21 | distance_to_river_km | 0.0094 | 0.0095 | 0.0294 |
| motor | 22 | missed_payments_12m | 0.0080 | 0.0184 | 0.0090 |
| motor | 23 | credit_band | 0.0080 | 0.0164 | 0.0121 |
| motor | 24 | occupation | 0.0078 | 0.0166 | 0.0175 |
| motor | 25 | year_built | 0.0077 | 0.0102 | 0.0232 |
| motor | 26 | wind_exposure_index | 0.0064 | 0.0075 | 0.0190 |
| motor | 27 | dry_summer_index | 0.0063 | 0.0050 | 0.0185 |
| motor | 28 | elevation_m | 0.0056 | 0.0045 | 0.0178 |
| motor | 29 | wildfire_index | 0.0051 | 0.0073 | 0.0137 |
| motor | 30 | mean_temperature_c | 0.0051 | 0.0062 | 0.0149 |
| motor | 31 | days_quote_to_inception | 0.0049 | 0.0150 | 0.0140 |
| motor | 32 | licence_points | 0.0046 | 0.0203 | 0.0093 |
| motor | 33 | household_size | 0.0042 | 0.0076 | 0.0125 |
| motor | 34 | hail_days | 0.0042 | 0.0071 | 0.0137 |
| motor | 35 | overnight_parking | 0.0040 | 0.0112 | 0.0100 |
| motor | 36 | years_at_address | 0.0037 | 0.0034 | 0.0109 |
| motor | 37 | engine_size_cc | 0.0037 | 0.0031 | 0.0119 |
| motor | 38 | freezing_days | 0.0036 | 0.0030 | 0.0114 |
| motor | 39 | renewal_count | 0.0034 | 0.0053 | 0.0088 |
| motor | 40 | named_young_driver | 0.0032 | 0.0165 | 0.0069 |
| motor | 41 | branch_id | 0.0030 | 0.0016 | 0.0088 |
| motor | 42 | flood_zone | 0.0029 | 0.0038 | 0.0073 |
| motor | 43 | property_type | 0.0028 | 0.0058 | 0.0069 |
| motor | 44 | vehicle_value_group | 0.0027 | 0.0053 | 0.0083 |
| motor | 45 | new_business | 0.0024 | 0.0073 | 0.0045 |
| motor | 46 | years_with_insurer | 0.0019 | 0.0022 | 0.0042 |
| motor | 47 | vehicle_colour | 0.0016 | 0.0009 | 0.0047 |
| motor | 48 | customer_since_year | 0.0013 | 0.0010 | 0.0042 |
| motor | 49 | email_domain | 0.0012 | 0.0010 | 0.0038 |
| motor | 50 | energy_rating | 0.0012 | 0.0010 | 0.0040 |
| motor | 51 | soil_type | 0.0010 | 0.0015 | 0.0033 |
| motor | 52 | campaign_code | 0.0010 | 0.0021 | 0.0035 |
| motor | 53 | discount_applied | 0.0010 | 0.0044 | 0.0026 |
| motor | 54 | seats | 0.0009 | 0.0006 | 0.0028 |
| motor | 55 | bedrooms | 0.0008 | 0.0003 | 0.0028 |
| motor | 56 | telematics_opt_in | 0.0008 | 0.0016 | 0.0016 |
| motor | 57 | marital_status | 0.0007 | 0.0011 | 0.0024 |
| motor | 58 | fuel_type | 0.0007 | 0.0012 | 0.0024 |
| motor | 59 | body_type | 0.0007 | 0.0006 | 0.0017 |
| motor | 60 | start_month | 0.0005 | 0.0006 | 0.0017 |
| motor | 61 | trees_within_5m | 0.0004 | 0.0001 | 0.0012 |
| motor | 62 | marketing_consent | 0.0004 | 0.0001 | 0.0010 |
| motor | 63 | document_preference | 0.0003 | 0.0001 | 0.0016 |
| motor | 64 | roof_type | 0.0002 | 0.0002 | 0.0009 |
| motor | 65 | solar_panels | 0.0002 | 0.0001 | 0.0009 |
| motor | 66 | transmission | 0.0002 | 0.0001 | 0.0009 |
| motor | 67 | driver_assist | 0.0002 | 0.0001 | 0.0007 |
| motor | 68 | basement | 0.0002 | 0.0000 | 0.0007 |
| motor | 69 | listed_building | 0.0001 | 0.0000 | 0.0007 |
| buildings | 1 | written_premium | 0.4518 | 0.1104 | 0.0915 |
| buildings | 2 | elevation_m | 0.0822 | 0.0939 | 0.0766 |
| buildings | 3 | sum_insured | 0.0668 | 0.0787 | 0.0609 |
| buildings | 4 | year_built | 0.0453 | 0.0497 | 0.0464 |
| buildings | 5 | flood_zone | 0.0301 | 0.0091 | 0.0128 |
| buildings | 6 | energy_rating | 0.0291 | 0.0422 | 0.0352 |
| buildings | 7 | prior_claims_5y | 0.0286 | 0.0568 | 0.0402 |
| buildings | 8 | dry_summer_index | 0.0202 | 0.0301 | 0.0381 |
| buildings | 9 | previous_insurer | 0.0148 | 0.0328 | 0.0348 |
| buildings | 10 | construction_type | 0.0134 | 0.0341 | 0.0211 |
| buildings | 11 | soil_type | 0.0121 | 0.0275 | 0.0207 |
| buildings | 12 | missed_payments_12m | 0.0120 | 0.0260 | 0.0149 |
| buildings | 13 | wind_exposure_index | 0.0119 | 0.0132 | 0.0311 |
| buildings | 14 | rainfall_mm | 0.0109 | 0.0225 | 0.0302 |
| buildings | 15 | occupancy | 0.0105 | 0.0310 | 0.0178 |
| buildings | 16 | distance_to_river_km | 0.0092 | 0.0145 | 0.0257 |
| buildings | 17 | days_quote_to_inception | 0.0091 | 0.0190 | 0.0261 |
| buildings | 18 | voluntary_excess | 0.0090 | 0.0269 | 0.0203 |
| buildings | 19 | occupation | 0.0083 | 0.0212 | 0.0203 |
| buildings | 20 | channel | 0.0082 | 0.0221 | 0.0203 |
| buildings | 21 | mean_temperature_c | 0.0080 | 0.0211 | 0.0211 |
| buildings | 22 | credit_band | 0.0080 | 0.0282 | 0.0191 |
| buildings | 23 | marketing_segment | 0.0077 | 0.0109 | 0.0182 |
| buildings | 24 | policyholder_age | 0.0074 | 0.0068 | 0.0211 |
| buildings | 25 | campaign_code | 0.0070 | 0.0155 | 0.0174 |
| buildings | 26 | wildfire_index | 0.0069 | 0.0147 | 0.0203 |
| buildings | 27 | years_at_address | 0.0061 | 0.0188 | 0.0178 |
| buildings | 28 | basement | 0.0059 | 0.0081 | 0.0133 |
| buildings | 29 | days_unoccupied | 0.0056 | 0.0049 | 0.0162 |
| buildings | 30 | payment_method | 0.0052 | 0.0174 | 0.0116 |
| buildings | 31 | freezing_days | 0.0051 | 0.0073 | 0.0153 |
| buildings | 32 | listed_building | 0.0041 | 0.0160 | 0.0095 |
| buildings | 33 | hail_days | 0.0040 | 0.0032 | 0.0133 |
| buildings | 34 | bedrooms | 0.0037 | 0.0035 | 0.0066 |
| buildings | 35 | household_size | 0.0035 | 0.0055 | 0.0120 |
| buildings | 36 | customer_since_year | 0.0030 | 0.0067 | 0.0075 |
| buildings | 37 | customer_age | 0.0029 | 0.0040 | 0.0083 |
| buildings | 38 | accidental_damage_cover | 0.0028 | 0.0125 | 0.0066 |
| buildings | 39 | urban_density | 0.0025 | 0.0065 | 0.0066 |
| buildings | 40 | renewal_count | 0.0024 | 0.0052 | 0.0075 |
| buildings | 41 | property_type | 0.0022 | 0.0024 | 0.0062 |
| buildings | 42 | email_domain | 0.0019 | 0.0014 | 0.0054 |
| buildings | 43 | region | 0.0019 | 0.0043 | 0.0054 |
| buildings | 44 | branch_id | 0.0017 | 0.0009 | 0.0058 |
| buildings | 45 | marital_status | 0.0014 | 0.0049 | 0.0041 |
| buildings | 46 | marketing_consent | 0.0010 | 0.0011 | 0.0029 |
| buildings | 47 | smoke_alarms | 0.0008 | 0.0002 | 0.0021 |
| buildings | 48 | mortgage | 0.0007 | 0.0006 | 0.0021 |
| buildings | 49 | start_month | 0.0007 | 0.0021 | 0.0021 |
| buildings | 50 | licence_points | 0.0005 | 0.0007 | 0.0025 |
| buildings | 51 | new_business | 0.0004 | 0.0011 | 0.0021 |
| buildings | 52 | discount_applied | 0.0004 | 0.0006 | 0.0021 |
| buildings | 53 | roof_type | 0.0004 | 0.0002 | 0.0017 |
| buildings | 54 | document_preference | 0.0003 | 0.0010 | 0.0012 |
| contents | 1 | flood_zone | 0.2497 | 0.0515 | 0.0329 |
| contents | 2 | written_premium | 0.1576 | 0.0838 | 0.0744 |
| contents | 3 | elevation_m | 0.0899 | 0.0543 | 0.0588 |
| contents | 4 | sum_insured | 0.0551 | 0.0536 | 0.0496 |
| contents | 5 | distance_to_river_km | 0.0296 | 0.0434 | 0.0490 |
| contents | 6 | prior_claims_5y | 0.0261 | 0.0469 | 0.0265 |
| contents | 7 | marketing_segment | 0.0226 | 0.0221 | 0.0225 |
| contents | 8 | voluntary_excess | 0.0210 | 0.0441 | 0.0231 |
| contents | 9 | previous_insurer | 0.0176 | 0.0237 | 0.0300 |
| contents | 10 | policyholder_age | 0.0174 | 0.0195 | 0.0352 |
| contents | 11 | years_at_address | 0.0174 | 0.0271 | 0.0323 |
| contents | 12 | rainfall_mm | 0.0170 | 0.0294 | 0.0346 |
| contents | 13 | year_built | 0.0148 | 0.0170 | 0.0317 |
| contents | 14 | region | 0.0145 | 0.0287 | 0.0190 |
| contents | 15 | high_value_items | 0.0139 | 0.0316 | 0.0242 |
| contents | 16 | customer_age | 0.0134 | 0.0204 | 0.0179 |
| contents | 17 | wind_exposure_index | 0.0128 | 0.0365 | 0.0311 |
| contents | 18 | accidental_damage_cover | 0.0126 | 0.0294 | 0.0144 |
| contents | 19 | freezing_days | 0.0125 | 0.0175 | 0.0288 |
| contents | 20 | dry_summer_index | 0.0124 | 0.0183 | 0.0277 |
| contents | 21 | wildfire_index | 0.0114 | 0.0178 | 0.0225 |
| contents | 22 | missed_payments_12m | 0.0112 | 0.0199 | 0.0115 |
| contents | 23 | property_type | 0.0106 | 0.0153 | 0.0156 |
| contents | 24 | mean_temperature_c | 0.0099 | 0.0128 | 0.0265 |
| contents | 25 | occupation | 0.0094 | 0.0126 | 0.0185 |
| contents | 26 | urban_density | 0.0093 | 0.0247 | 0.0127 |
| contents | 27 | days_quote_to_inception | 0.0083 | 0.0172 | 0.0167 |
| contents | 28 | security_level | 0.0080 | 0.0163 | 0.0127 |
| contents | 29 | campaign_code | 0.0077 | 0.0155 | 0.0156 |
| contents | 30 | channel | 0.0071 | 0.0216 | 0.0115 |
| contents | 31 | credit_band | 0.0068 | 0.0096 | 0.0098 |
| contents | 32 | hail_days | 0.0059 | 0.0078 | 0.0150 |
| contents | 33 | customer_since_year | 0.0058 | 0.0063 | 0.0138 |
| contents | 34 | payment_method | 0.0057 | 0.0165 | 0.0092 |
| contents | 35 | email_domain | 0.0054 | 0.0091 | 0.0115 |
| contents | 36 | household_size | 0.0053 | 0.0052 | 0.0115 |
| contents | 37 | bedrooms | 0.0053 | 0.0127 | 0.0121 |
| contents | 38 | branch_id | 0.0049 | 0.0035 | 0.0127 |
| contents | 39 | soil_type | 0.0036 | 0.0038 | 0.0087 |
| contents | 40 | roof_type | 0.0033 | 0.0113 | 0.0063 |
| contents | 41 | renewal_count | 0.0032 | 0.0031 | 0.0081 |
| contents | 42 | energy_rating | 0.0031 | 0.0037 | 0.0069 |
| contents | 43 | document_preference | 0.0030 | 0.0032 | 0.0058 |
| contents | 44 | marital_status | 0.0026 | 0.0035 | 0.0058 |
| contents | 45 | discount_applied | 0.0024 | 0.0015 | 0.0035 |
| contents | 46 | lodgers | 0.0020 | 0.0034 | 0.0052 |
| contents | 47 | years_with_insurer | 0.0018 | 0.0004 | 0.0035 |
| contents | 48 | trees_within_5m | 0.0016 | 0.0071 | 0.0046 |
| contents | 49 | works_from_home | 0.0016 | 0.0102 | 0.0046 |
| contents | 50 | licence_points | 0.0013 | 0.0012 | 0.0035 |
| contents | 51 | start_month | 0.0010 | 0.0008 | 0.0029 |
| contents | 52 | bicycle_cover | 0.0009 | 0.0003 | 0.0012 |
| contents | 53 | marketing_consent | 0.0008 | 0.0016 | 0.0017 |
| contents | 54 | basement | 0.0006 | 0.0005 | 0.0012 |
| contents | 55 | tenure | 0.0005 | 0.0007 | 0.0012 |
| contents | 56 | listed_building | 0.0005 | 0.0003 | 0.0012 |
| contents | 57 | new_business | 0.0002 | 0.0000 | 0.0006 |
| contents | 58 | solar_panels | 0.0002 | 0.0001 | 0.0006 |

