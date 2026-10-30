# BEN 1 - XGBoost variant ladder

**Run id** `20261021_1658` | **Generated** 2026-10-21 17:56 | **Git commit** `af12e5f` | **Submission file** `submission_20261021_1658.csv`

**Change in this iteration:** XGBoost Tweedie on rolling 2-year windows (expanding window as comparison); EDA feature fixes (premium index, weather averages, calendar and duplicate fields removed, renewal_count capped); IBNR by peril; trend to the scored year; tuning on a time fold with monotone constraints; feature-group drop test; model diagnostic plots.

## Reproducibility
Submission file MD5 `34dc2c9da29db5062b2ea2cabe3cf928`. Final models in `models/ben_iteration_01/fitted/`; reload with `load_model()` and score with `score_model()` (`R/model_io.R`). Replication check: **passed**

| line | model | rows | max_abs_diff |
|---|---|---|---|
| motor | xgb_tweedie | 254,986 | 0 |
| buildings | xgb_tweedie | 184,155 | 0 |
| contents | xgb_tweedie | 187,498 | 0 |

## Settings
| setting | value |
|---|---|
| Model | XGBoost reg:tweedie on cost per exposure-year, weight = exposure, hist trees, early stopping on a 10% policy holdout |
| Folds (rolling, main) | 2021-22 -> 2023, 2022-23 -> 2024, 2023-24 -> 2025 |
| Folds (expanding, comparison) | 2021-22 -> 2023, 2021-23 -> 2024, 2021-24 -> 2025 |
| Final fit | motor 2021-2024; buildings 2021-2024; contents 2021-2024 |
| Large-loss cap | row cost capped at p99.9 of the fit years, cap loading on predictions |
| IBNR | v0-v2: line count factor of the policy year; v3 on: per-peril count factors weighted by the row's peril costs (`ibnr_factors_by_peril.csv`) |
| Trend | v4 on: log-linear trend in capped, developed burn cost over all years before the scored year, clamped to +-5%; targets moved to the scored year |
| Features | v2 on: excluded compulsory_excess, years_with_insurer, customer_since_year, campaign_code, written_premium ; added premium_index and 2021-24 address weather averages; renewal_count capped at the training maximum |
| Categorical encoding | levels ordered by cost rate with 200 exposure-years of credibility towards the line mean (v0-v1: raw rate, as iteration 2) |
| Tuning | fit 2021, score 2022 (Kaggle metric), 600-second budget, 216-configuration grid plus iteration 2's parameters; tried motor 32, buildings 51, contents 26 |
| Monotone constraints | ncb_years decreasing; prior_claims_5y increasing; licence_points increasing; missed_payments_12m increasing; flood_zone increasing; voluntary_excess decreasing |
| Group drop test | each group dropped from the best variant; dropped for good if D2 rises by > 0.0005 in both years |
| Seed | 2026 + per-fit offset by line and year (fit_seed()); same seed for every variant |

## Variants: what each change does
Each variant adds one change to the one before; the same seeds are used throughout, so differences come from the change.
For 2023 the rolling and expanding windows are the same (2021-22).

![](variants.png)

| line | variant | label | d2_2023 | d2_2024 | d2_developed_2023 | d2_developed_2024 | pred_vs_reported_2023 | pred_vs_reported_2024 | mean_d2 |
|---|---|---|---|---|---|---|---|---|---|
| buildings | v0 | iteration 2 setup, expanding window | 0.0688 | 0.0724 | 0.0685 | 0.0672 | 0.8967 | 0.9206 | 0.0706 |
| buildings | v1 | + rolling 2-year window | 0.0688 | 0.0696 | 0.0685 | 0.0639 | 0.8967 | 0.9127 | 0.0692 |
| buildings | v2 | + EDA feature fixes | 0.0676 | 0.0680 | 0.0673 | 0.0613 | 0.8532 | 0.8677 | 0.0678 |
| buildings | v3 | + IBNR by peril | 0.0676 | 0.0676 | 0.0673 | 0.0610 | 0.8532 | 0.8685 | 0.0676 |
| buildings | v4 | + trend to the scored year | 0.0695 | 0.0695 | 0.0692 | 0.0645 | 0.9133 | 0.9309 | 0.0695 |
| buildings | v5 | + tuned on a time fold, monotone constraints | 0.0686 | 0.0696 | 0.0684 | 0.0647 | 0.9218 | 0.9454 | 0.0691 |
| buildings | v6 | v5 on the expanding window | 0.0686 | 0.0731 | 0.0684 | 0.0684 | 0.9218 | 0.9586 | 0.0708 |
| contents | v0 | iteration 2 setup, expanding window | 0.0592 | 0.0589 | 0.0592 | 0.0586 | 0.8632 | 0.9466 | 0.0591 |
| contents | v1 | + rolling 2-year window | 0.0592 | 0.0545 | 0.0592 | 0.0539 | 0.8632 | 0.9262 | 0.0569 |
| contents | v2 | + EDA feature fixes | 0.0560 | 0.0567 | 0.0560 | 0.0559 | 0.8177 | 0.8894 | 0.0563 |
| contents | v3 | + IBNR by peril | 0.0560 | 0.0566 | 0.0560 | 0.0559 | 0.8177 | 0.8888 | 0.0563 |
| contents | v4 | + trend to the scored year | 0.0581 | 0.0574 | 0.0581 | 0.0573 | 0.8302 | 0.9601 | 0.0577 |
| contents | v5 | + tuned on a time fold, monotone constraints | 0.0625 | 0.0598 | 0.0624 | 0.0597 | 0.8336 | 0.9649 | 0.0611 |
| contents | v6 | v5 on the expanding window | 0.0625 | 0.0625 | 0.0624 | 0.0626 | 0.8336 | 0.9801 | 0.0625 |
| motor | v0 | iteration 2 setup, expanding window | 0.0385 | 0.0496 | 0.0371 | 0.0534 | 0.8615 | 1.1514 | 0.0441 |
| motor | v1 | + rolling 2-year window | 0.0385 | 0.0479 | 0.0371 | 0.0510 | 0.8615 | 1.1564 | 0.0432 |
| motor | v2 | + EDA feature fixes | 0.0337 | 0.0482 | 0.0319 | 0.0494 | 0.8311 | 1.1253 | 0.0409 |
| motor | v3 | + IBNR by peril | 0.0360 | 0.0475 | 0.0343 | 0.0492 | 0.8223 | 1.1337 | 0.0418 |
| motor | v4 | + trend to the scored year | 0.0353 | 0.0489 | 0.0338 | 0.0492 | 0.8574 | 1.1043 | 0.0421 |
| motor | v5 | + tuned on a time fold, monotone constraints | 0.0384 | 0.0494 | 0.0372 | 0.0525 | 0.8983 | 1.1525 | 0.0439 |
| motor | v6 | v5 on the expanding window | 0.0384 | 0.0514 | 0.0372 | 0.0538 | 0.8983 | 1.1256 | 0.0449 |

Three lines combined (one baseline, as Kaggle scores the file):

| variant | d2_2023 | d2_2024 | d2_developed_2023 | d2_developed_2024 |
|---|---|---|---|---|
| selected per line | 0.1000 | 0.0998 | 0.1003 | 0.1048 |
| v0 | 0.0995 | 0.0981 | 0.0997 | 0.1035 |
| v1 | 0.0995 | 0.0956 | 0.0997 | 0.1005 |
| v2 | 0.0964 | 0.0955 | 0.0964 | 0.0992 |
| v3 | 0.0975 | 0.0951 | 0.0975 | 0.0990 |
| v4 | 0.0981 | 0.0965 | 0.0982 | 0.1005 |
| v5 | 0.1000 | 0.0972 | 0.1003 | 0.1024 |
| v6 | 0.1000 | 0.0998 | 0.1003 | 0.1048 |

## Selected per line
| line | variant | label | scheme |
|---|---|---|---|
| motor | v6 | v5 on the expanding window | expanding |
| buildings | v6 | v5 on the expanding window | expanding |
| contents | v6 | v5 on the expanding window | expanding |

## Feature-group drop test (guardrails)
Change in D2 when the group is removed from the selected variant (positive = the model is better without it).

| line | group | features | d2_change_2023 | d2_change_2024 | dropped |
|---|---|---|---|---|---|
| motor | premium_index | premium_index | -0.0068 | 0.0004 | FALSE |
| motor | marketing | marketing_segment, branch_id, marketing_consent, email_domain, document_preference | 0.0022 | 0.0002 | FALSE |
| motor | distribution | channel, discount_applied, days_quote_to_inception | -0.0018 | -0.0010 | FALSE |
| motor | previous_insurer | previous_insurer | 0.0048 | -0.0005 | FALSE |
| motor | occupation | occupation | -0.0017 | -0.0003 | FALSE |
| motor | weather_yearly | hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c | 0.0025 | -0.0008 | FALSE |
| motor | weather_avg | wx_avg_hail_days, wx_avg_wind_exposure_index, wx_avg_freezing_days, wx_avg_dry_summer_index, wx_avg_wildfire_index, wx_avg_rainfall_mm, wx_avg_mean_temperature_c | 0.0039 | -0.0004 | FALSE |
| motor | vehicle_colour | vehicle_colour | 0.0034 | -0.0003 | FALSE |
| motor | make_model | make_model | 0.0023 | 0.0002 | FALSE |
| buildings | premium_index | premium_index | -0.0002 | -0.0023 | FALSE |
| buildings | marketing | marketing_segment, branch_id, marketing_consent, email_domain, document_preference | 0.0013 | -0.0017 | FALSE |
| buildings | distribution | channel, discount_applied, days_quote_to_inception | 0.0012 | -0.0025 | FALSE |
| buildings | previous_insurer | previous_insurer | 0.0005 | 0.0014 | FALSE |
| buildings | occupation | occupation | -0.0010 | 0.0009 | FALSE |
| buildings | weather_yearly | hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c | 0.0011 | -0.0004 | FALSE |
| buildings | weather_avg | wx_avg_hail_days, wx_avg_wind_exposure_index, wx_avg_freezing_days, wx_avg_dry_summer_index, wx_avg_wildfire_index, wx_avg_rainfall_mm, wx_avg_mean_temperature_c | -0.0001 | -0.0012 | FALSE |
| contents | premium_index | premium_index | -0.0032 | -0.0008 | FALSE |
| contents | marketing | marketing_segment, branch_id, marketing_consent, email_domain, document_preference | -0.0020 | -0.0002 | FALSE |
| contents | distribution | channel, discount_applied, days_quote_to_inception | -0.0042 | 0.0007 | FALSE |
| contents | previous_insurer | previous_insurer | -0.0009 | 0.0006 | FALSE |
| contents | occupation | occupation | -0.0002 | 0.0000 | FALSE |
| contents | weather_yearly | hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c | -0.0004 | 0.0003 | FALSE |
| contents | weather_avg | wx_avg_hail_days, wx_avg_wind_exposure_index, wx_avg_freezing_days, wx_avg_dry_summer_index, wx_avg_wildfire_index, wx_avg_rainfall_mm, wx_avg_mean_temperature_c | -0.0006 | -0.0008 | FALSE |

## Accuracy of the selection - local Kaggle score
`deviance_share` = the line's share of the remaining combined error.

| line | d2_2023 | d2_2024 | deviance_share_2023 | deviance_share_2024 |
|---|---|---|---|---|
| motor | 0.0384 | 0.0514 | 0.4863 | 0.4488 |
| buildings | 0.0686 | 0.0731 | 0.3341 | 0.3613 |
| contents | 0.0625 | 0.0625 | 0.1796 | 0.1899 |
| ALL | 0.1000 | 0.0998 | 1 | 1 |

| line | variant | valid_year | fit_years | d2 | d2_developed | gini | pred_vs_reported | pred_vs_developed | trend | rounds |
|---|---|---|---|---|---|---|---|---|---|---|
| buildings | v6 | 2023 | 2021-2022 | 0.0686 | 0.0684 | 0.4543 | 0.9218 | 0.9188 | 0.0500 | 82 |
| buildings | v6 | 2024 | 2021-2023 | 0.0731 | 0.0684 | 0.4533 | 0.9586 | 0.8809 | 0.0500 | 276 |
| contents | v6 | 2023 | 2021-2022 | 0.0625 | 0.0624 | 0.4362 | 0.8336 | 0.8321 | 0.0039 | 162 |
| contents | v6 | 2024 | 2021-2023 | 0.0625 | 0.0626 | 0.4320 | 0.9801 | 0.9498 | 0.0497 | 142 |
| motor | v6 | 2023 | 2021-2022 | 0.0384 | 0.0372 | 0.3777 | 0.8983 | 0.8772 | 0.0243 | 845 |
| motor | v6 | 2024 | 2021-2023 | 0.0514 | 0.0538 | 0.3872 | 1.1256 | 0.9297 | -0.0200 | 547 |

## Trend
| line | trend_2021_24 | trend_by_fold |
|---|---|---|
| motor | -0.0129 | 2023: 0.024; 2024: -0.020 |
| buildings | 0.0500 | 2023: 0.050; 2024: 0.050 |
| contents | 0.0478 | 2023: 0.004; 2024: 0.050 |

## Diagnostics (validation years 2023-24, selected variant)
Actuals are developed with the per-peril IBNR factors so 2024 is comparable with predictions at ultimate.

### Lift
![](lift.png)

### Double lift vs the iteration 2 setup
![](double_lift.png)

### Actual vs expected by factor
![](ave_motor.png)

![](ave_buildings.png)

![](ave_contents.png)

### Partial dependence
![](pdp.png)

## Tuning (fit 2021, score 2022)
| line | config | max_depth | learning_rate | min_child_weight | subsample | colsample_bytree | reg_lambda | tweedie_variance_power | d2_2022 | rounds | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|
| buildings | 14 | 3 | 0.0500 | 10 | 0.8000 | 0.6000 | 10 | 1.4000 | 0.0560 | 106 | 3 |
| buildings | 4 | 3 | 0.0500 | 200 | 0.8000 | 0.6000 | 1 | 1.4000 | 0.0560 | 106 | 3 |
| buildings | 13 | 3 | 0.0300 | 200 | 0.8000 | 0.6000 | 1 | 1.4000 | 0.0555 | 150 | 3 |
| buildings | 11 | 3 | 0.0300 | 50 | 0.8000 | 0.8000 | 10 | 1.4000 | 0.0551 | 139 | 3 |
| buildings | 22 | 3 | 0.0300 | 10 | 0.8000 | 0.8000 | 10 | 1.4000 | 0.0551 | 139 | 3 |
| contents | 26 | 3 | 0.0500 | 200 | 0.8000 | 0.6000 | 10 | 1.4000 | 0.0600 | 124 | 6 |
| contents | 25 | 3 | 0.0300 | 200 | 0.8000 | 0.6000 | 1 | 1.4000 | 0.0595 | 185 | 8 |
| contents | 1 | 4 | 0.1000 | 10 | 0.9000 | 0.6000 | 10 | 1.3000 | 0.0592 | 45 | 4 |
| contents | 8 | 3 | 0.0300 | 50 | 0.8000 | 0.6000 | 10 | 1.5000 | 0.0585 | 154 | 8 |
| contents | 18 | 3 | 0.0500 | 50 | 0.8000 | 0.6000 | 1 | 1.5000 | 0.0584 | 128 | 7 |
| motor | 30 | 3 | 0.0300 | 50 | 0.8000 | 0.6000 | 1 | 1.4000 | 0.0500 | 299 | 15 |
| motor | 23 | 3 | 0.0300 | 200 | 0.8000 | 0.6000 | 10 | 1.5000 | 0.0494 | 332 | 10 |
| motor | 9 | 3 | 0.0500 | 200 | 0.8000 | 0.6000 | 10 | 1.5000 | 0.0493 | 161 | 6 |
| motor | 18 | 4 | 0.0300 | 200 | 0.8000 | 0.8000 | 10 | 1.4000 | 0.0493 | 177 | 7 |
| motor | 26 | 4 | 0.0300 | 10 | 0.8000 | 0.8000 | 1 | 1.4000 | 0.0493 | 200 | 7 |

## 2025 test predictions
| line | variant | fit_years | cap | cap_loading | trend | test_exposure | predicted_total | predicted_burn_cost | train_burn_2023_24 | p50_row | p90_row | p99_row | max_row |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | v6 | 2021-2024 | 124,533.752 | 1.051 | -0.013 | 199,983.581 | 101,093,244.305 | 505.508 | 520.630 | 333.101 | 748.285 | 1,571.175 | 7,067.129 |
| buildings | v6 | 2021-2024 | 280,163.034 | 1.007 | 0.050 | 150,243.904 | 68,574,012.871 | 456.418 | 440.761 | 283.156 | 670.821 | 2,184.749 | 12,799.617 |
| contents | v6 | 2021-2024 | 45,596.949 | 1.006 | 0.048 | 150,123.770 | 18,369,728.171 | 122.364 | 116.874 | 78.457 | 181.098 | 476.664 | 3,488.350 |

## Features used
| line | n_features | features |
|---|---|---|
| motor | 73 | driver_age, years_licensed, ncb_years, vehicle_value_group, vehicle_age, make_model, engine_size_cc, body_type, transmission, seats, vehicle_colour, fuel_type, driver_assist, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, telematics_opt_in, telematics_score, voluntary_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, email_domain, marketing_consent, document_preference, previous_insurer, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, premium_index, wx_avg_hail_days, wx_avg_wind_exposure_index, wx_avg_freezing_days, wx_avg_dry_summer_index, wx_avg_wildfire_index, wx_avg_rainfall_mm, wx_avg_mean_temperature_c |
| buildings | 61 | policyholder_age, sum_insured, construction_type, occupancy, days_unoccupied, smoke_alarms, accidental_damage_cover, mortgage, voluntary_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, email_domain, marketing_consent, document_preference, previous_insurer, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, premium_index, wx_avg_hail_days, wx_avg_wind_exposure_index, wx_avg_freezing_days, wx_avg_dry_summer_index, wx_avg_wildfire_index, wx_avg_rainfall_mm, wx_avg_mean_temperature_c |
| contents | 62 | policyholder_age, sum_insured, tenure, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, voluntary_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, email_domain, marketing_consent, document_preference, previous_insurer, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, premium_index, wx_avg_hail_days, wx_avg_wind_exposure_index, wx_avg_freezing_days, wx_avg_dry_summer_index, wx_avg_wildfire_index, wx_avg_rainfall_mm, wx_avg_mean_temperature_c |

## Variable importance (final fit, share of total gain)
![](xgb_importance.png)

| line | rank | Feature | Gain | Cover | Frequency |
|---|---|---|---|---|---|
| motor | 1 | ncb_years | 0.1728 | 0.0443 | 0.0303 |
| motor | 2 | premium_index | 0.1526 | 0.0424 | 0.0460 |
| motor | 3 | annual_mileage | 0.0696 | 0.0589 | 0.0521 |
| motor | 4 | make_model | 0.0533 | 0.0504 | 0.0519 |
| motor | 5 | customer_age | 0.0471 | 0.0229 | 0.0230 |
| motor | 6 | marketing_segment | 0.0465 | 0.0200 | 0.0162 |
| motor | 7 | years_licensed | 0.0413 | 0.0231 | 0.0238 |
| motor | 8 | prior_claims_5y | 0.0324 | 0.0367 | 0.0250 |
| motor | 9 | driver_age | 0.0309 | 0.0241 | 0.0244 |
| motor | 10 | cover_type | 0.0264 | 0.0280 | 0.0210 |
| motor | 11 | voluntary_excess | 0.0261 | 0.0370 | 0.0271 |
| motor | 12 | vehicle_age | 0.0203 | 0.0377 | 0.0345 |
| motor | 13 | telematics_score | 0.0175 | 0.0346 | 0.0269 |
| motor | 14 | urban_density | 0.0174 | 0.0338 | 0.0240 |
| motor | 15 | region | 0.0169 | 0.0295 | 0.0252 |
| motor | 16 | vehicle_use | 0.0128 | 0.0301 | 0.0192 |
| motor | 17 | previous_insurer | 0.0125 | 0.0216 | 0.0256 |
| motor | 18 | channel | 0.0112 | 0.0218 | 0.0155 |
| motor | 19 | year_built | 0.0099 | 0.0211 | 0.0269 |
| motor | 20 | payment_method | 0.0096 | 0.0164 | 0.0113 |
| motor | 21 | distance_to_river_km | 0.0094 | 0.0180 | 0.0283 |
| motor | 22 | occupation | 0.0093 | 0.0239 | 0.0188 |
| motor | 23 | missed_payments_12m | 0.0082 | 0.0122 | 0.0079 |
| motor | 24 | rainfall_mm | 0.0077 | 0.0221 | 0.0232 |
| motor | 25 | mean_temperature_c | 0.0073 | 0.0145 | 0.0200 |
| buildings | 1 | premium_index | 0.2080 | 0.0569 | 0.0482 |
| buildings | 2 | flood_zone | 0.1014 | 0.0146 | 0.0126 |
| buildings | 3 | elevation_m | 0.0870 | 0.0606 | 0.0568 |
| buildings | 4 | sum_insured | 0.0652 | 0.0573 | 0.0445 |
| buildings | 5 | distance_to_river_km | 0.0481 | 0.0360 | 0.0386 |
| buildings | 6 | year_built | 0.0395 | 0.0370 | 0.0393 |
| buildings | 7 | energy_rating | 0.0277 | 0.0248 | 0.0200 |
| buildings | 8 | prior_claims_5y | 0.0229 | 0.0358 | 0.0234 |
| buildings | 9 | dry_summer_index | 0.0190 | 0.0233 | 0.0278 |
| buildings | 10 | previous_insurer | 0.0182 | 0.0267 | 0.0297 |
| buildings | 11 | wx_avg_wind_exposure_index | 0.0182 | 0.0317 | 0.0345 |
| buildings | 12 | years_at_address | 0.0177 | 0.0303 | 0.0345 |
| buildings | 13 | days_quote_to_inception | 0.0155 | 0.0218 | 0.0286 |
| buildings | 14 | wx_avg_rainfall_mm | 0.0146 | 0.0305 | 0.0282 |
| buildings | 15 | wx_avg_dry_summer_index | 0.0132 | 0.0212 | 0.0234 |
| buildings | 16 | soil_type | 0.0130 | 0.0220 | 0.0171 |
| buildings | 17 | construction_type | 0.0127 | 0.0222 | 0.0141 |
| buildings | 18 | wind_exposure_index | 0.0124 | 0.0169 | 0.0245 |
| buildings | 19 | occupancy | 0.0118 | 0.0209 | 0.0137 |
| buildings | 20 | occupation | 0.0118 | 0.0200 | 0.0223 |
| buildings | 21 | marketing_segment | 0.0116 | 0.0137 | 0.0189 |
| buildings | 22 | mean_temperature_c | 0.0116 | 0.0237 | 0.0219 |
| buildings | 23 | wx_avg_freezing_days | 0.0113 | 0.0231 | 0.0237 |
| buildings | 24 | wx_avg_wildfire_index | 0.0108 | 0.0180 | 0.0237 |
| buildings | 25 | rainfall_mm | 0.0102 | 0.0196 | 0.0208 |
| contents | 1 | flood_zone | 0.2396 | 0.0533 | 0.0423 |
| contents | 2 | premium_index | 0.1810 | 0.0870 | 0.0791 |
| contents | 3 | elevation_m | 0.1182 | 0.0658 | 0.0648 |
| contents | 4 | sum_insured | 0.0661 | 0.0598 | 0.0588 |
| contents | 5 | distance_to_river_km | 0.0415 | 0.0255 | 0.0357 |
| contents | 6 | prior_claims_5y | 0.0281 | 0.0470 | 0.0313 |
| contents | 7 | marketing_segment | 0.0247 | 0.0237 | 0.0247 |
| contents | 8 | voluntary_excess | 0.0196 | 0.0391 | 0.0231 |
| contents | 9 | accidental_damage_cover | 0.0152 | 0.0305 | 0.0209 |
| contents | 10 | region | 0.0147 | 0.0294 | 0.0247 |
| contents | 11 | customer_age | 0.0132 | 0.0211 | 0.0247 |
| contents | 12 | rainfall_mm | 0.0126 | 0.0301 | 0.0346 |
| contents | 13 | high_value_items | 0.0126 | 0.0334 | 0.0236 |
| contents | 14 | policyholder_age | 0.0124 | 0.0189 | 0.0247 |
| contents | 15 | property_type | 0.0109 | 0.0169 | 0.0203 |
| contents | 16 | missed_payments_12m | 0.0099 | 0.0183 | 0.0115 |
| contents | 17 | urban_density | 0.0099 | 0.0219 | 0.0154 |
| contents | 18 | channel | 0.0096 | 0.0266 | 0.0181 |
| contents | 19 | security_level | 0.0092 | 0.0253 | 0.0176 |
| contents | 20 | previous_insurer | 0.0092 | 0.0263 | 0.0236 |
| contents | 21 | wildfire_index | 0.0092 | 0.0211 | 0.0187 |
| contents | 22 | years_at_address | 0.0084 | 0.0140 | 0.0214 |
| contents | 23 | wx_avg_rainfall_mm | 0.0081 | 0.0174 | 0.0225 |
| contents | 24 | days_quote_to_inception | 0.0079 | 0.0230 | 0.0214 |
| contents | 25 | dry_summer_index | 0.0072 | 0.0133 | 0.0192 |

