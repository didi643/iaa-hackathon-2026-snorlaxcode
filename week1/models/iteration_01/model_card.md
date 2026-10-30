# Iteration 1

**Run id** `20261020_1827` | **Generated** 2026-10-20 18:33 | **Git commit** `94755d2` | **Submission file** `submission_20261020_1827.csv`

**Change in this iteration:** Baseline: GLM frequency x severity vs LightGBM Tweedie, burn cost and rescaled premium per line; row cost capped at p99.9 with cap loading; IBNR count factors; no trend. Reproducible re-run: per-fit seeds, deterministic LightGBM, fitted models saved.

Public Kaggle scores for this iteration are in the submission log (`Iteration` column) and on the
Model iterations overview page.

## Reproducibility
Submission file MD5 `956f3aa920945182c5c85cdc9d83031c`. Every candidate's final model is saved in `models/iteration_01/fitted/` (`<line>_<model>.rds`, LightGBM trees in `.txt`). Each fit uses its own seed (`fit_seed()`), and LightGBM runs in deterministic mode.

Reload and score without refitting:

```r
source("R/0_setup.R"); source("R/model_io.R")
art  <- load_model("models/iteration_01/fitted", "motor_glm_freq_sev")
pred <- pmax(score_model(art, read_clean("test_motor")), 0)
```

Replication check (saved models reloaded and re-scored vs the submission): **passed**

| line | model | rows | max_abs_diff |
|---|---|---|---|
| motor | glm_freq_sev | 254,986 | 0 |
| buildings | glm_freq_sev | 184,155 | 0 |
| contents | glm_freq_sev | 187,498 | 0 |

## Settings
| setting | value |
|---|---|
| Training years (final fit) | 2021-2024 |
| Validation folds | fit < 2024, score 2024; fit < 2023, score 2023 |
| Selection rule | highest mean local D2 over the validation folds, per line |
| Large-loss cap | row cost capped at p99.9 per line, cap loading on predictions |
| IBNR | targets x IBNR count factor of their policy year (step 5) |
| Tweedie power | 1.5 |
| GLM frequency sample | 250,000 rows |
| GLM min level share | 0.002 |
| GLM numeric binning | 8 exposure quantile bins for numerics with > 10 values; NA = 'missing' level |
| LightGBM params | objective=tweedie, tweedie_variance_power=1.5, learning_rate=0.05, num_leaves=31, min_data_in_leaf=500, feature_fraction=0.8, bagging_fraction=0.8, bagging_freq=1, lambda_l2=1, verbosity=-1, seed=2026, deterministic=TRUE, force_col_wise=TRUE, num_threads=4 |
| LightGBM rounds (final fit) | motor=60, buildings=55, contents=66 |
| Excluded from features | row_id, policy_id, customer_id, address_id, period_start, period_end, exposure, exposure_raw, renewal_decision, surname, date_of_birth, policy_year, customer_service_contacts |
| Seed | 2026 + per-fit offset by line, model and year (fit_seed()) |

## Accuracy - local Kaggle score (Tweedie D2, p = 1.5, higher = better)
### Submitted combination by line and combined
`deviance_share` = the line's share of the remaining combined error (where improvement moves the score most).

| line | model | d2_2023 | d2_2024 | deviance_share_2023 | deviance_share_2024 |
|---|---|---|---|---|---|
| motor | glm_freq_sev | 0.0558 | 0.0451 | 0.4806 | 0.4493 |
| buildings | glm_freq_sev | 0.0616 | 0.0671 | 0.3388 | 0.3616 |
| contents | glm_freq_sev | 0.0629 | 0.0609 | 0.1806 | 0.1892 |
| ALL | best per line | 0.1057 | 0.0947 | 1 | 1 |

### Every candidate model by line
| line | model | d2_2023 | d2_2024 | gini_2023 | gini_2024 | pred_vs_reported_2023 | pred_vs_reported_2024 |
|---|---|---|---|---|---|---|---|
| buildings | glm_freq_sev | 0.0616 | 0.0671 | 0.4365 | 0.4492 | 0.9821 | 0.9836 |
| buildings | lgb_tweedie | 0.0523 | 0.0580 | 0.4263 | 0.4324 | 0.7826 | 0.8157 |
| buildings | premium_scaled | 0.0521 | 0.0473 | 0.4150 | 0.4008 | 0.9872 | 1.0039 |
| buildings | burn_cost | -0.0009 | -0.0010 | 0.1905 | 0.2074 | 0.9111 | 0.9064 |
| contents | glm_freq_sev | 0.0629 | 0.0609 | 0.4357 | 0.4327 | 0.9119 | 0.9538 |
| contents | lgb_tweedie | 0.0492 | 0.0500 | 0.4083 | 0.4130 | 0.7878 | 0.8445 |
| contents | premium_scaled | 0.0209 | 0.0205 | 0.3054 | 0.3168 | 0.9748 | 1.0388 |
| contents | burn_cost | -0.0022 | -0.0008 | 0.1692 | 0.1796 | 0.9018 | 0.9369 |
| motor | glm_freq_sev | 0.0558 | 0.0451 | 0.4260 | 0.3810 | 0.9571 | 1.2309 |
| motor | lgb_tweedie | 0.0140 | 0.0326 | 0.2983 | 0.3384 | 0.8506 | 1.1241 |
| motor | premium_scaled | 0.0139 | 0.0128 | 0.2795 | 0.3084 | 1.0143 | 1.3448 |
| motor | burn_cost | -0.0002 | -0.0076 | 0.2228 | 0.1515 | 0.9696 | 1.2707 |

### Every candidate model, three lines combined
| model | d2_2023 | d2_2024 | gini_2023 | gini_2024 |
|---|---|---|---|---|
| best per line | 0.1057 | 0.0947 | 0.5214 | 0.4882 |
| glm_freq_sev | 0.1057 | 0.0947 | 0.5214 | 0.4882 |
| lgb_tweedie | 0.0813 | 0.0842 | 0.4728 | 0.4611 |
| premium_scaled | 0.0763 | 0.0666 | 0.4556 | 0.4321 |
| burn_cost | 0.0488 | 0.0371 | 0.3777 | 0.3192 |

## 2025 test predictions (final fit on 2021-24)
`submitted` = the model used for that line in the submission file.

| line | model | submitted | predicted_total | predicted_burn_cost | mean_row | p50_row | p90_row | p99_row | max_row |
|---|---|---|---|---|---|---|---|---|---|
| motor | burn_cost | FALSE | 110,864,356.24 | 554.37 | 434.79 | 554.37 | 554.37 | 554.37 | 554.37 |
| motor | premium_scaled | FALSE | 118,668,849.31 | 593.39 | 465.39 | 445.59 | 775.72 | 1,482.16 | 2,672.82 |
| motor | glm_freq_sev | TRUE | 103,615,296.17 | 518.12 | 406.36 | 334.82 | 781.91 | 1,640.19 | 6,283.38 |
| motor | lgb_tweedie | FALSE | 96,661,888.56 | 483.35 | 379.09 | 347.43 | 670.71 | 1,256.59 | 2,781.35 |
| buildings | burn_cost | FALSE | 63,723,394.31 | 424.13 | 346.03 | 424.13 | 424.13 | 424.13 | 424.13 |
| buildings | premium_scaled | FALSE | 72,481,550.23 | 482.43 | 393.59 | 283.97 | 753.61 | 2,449.03 | 6,396.48 |
| buildings | glm_freq_sev | TRUE | 63,866,256.68 | 425.08 | 346.81 | 261.88 | 649.99 | 1,891.94 | 10,470.95 |
| buildings | lgb_tweedie | FALSE | 58,873,645.36 | 391.85 | 319.70 | 261.80 | 531.19 | 1,756.88 | 3,764.92 |
| contents | burn_cost | FALSE | 16,855,074.03 | 112.27 | 89.89 | 112.27 | 112.27 | 112.27 | 112.27 |
| contents | premium_scaled | FALSE | 19,173,569.93 | 127.72 | 102.26 | 97.99 | 178.42 | 267.44 | 693.17 |
| contents | glm_freq_sev | TRUE | 16,994,444.32 | 113.20 | 90.64 | 71.38 | 169.79 | 431.34 | 3,587.41 |
| contents | lgb_tweedie | FALSE | 15,942,943.18 | 106.20 | 85.03 | 72.50 | 151.98 | 366.21 | 1,360.26 |

| line | model | cap | cap_loading | predicted_burn_cost | train_burn_2021_23 |
|---|---|---|---|---|---|
| motor | glm_freq_sev | 124,533.75 | 1.05 | 518.12 | 575.61 |
| buildings | glm_freq_sev | 280,163.03 | 1.01 | 425.08 | 406.91 |
| contents | glm_freq_sev | 45,596.95 | 1.01 | 113.20 | 109.37 |

## Features used
| line | model | n_features | features |
|---|---|---|---|
| motor | glm_freq_sev | 26 | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, occupation, marital_status, years_at_address, renewal_count, new_business, payment_method, missed_payments_12m |
| motor | lgb_tweedie | 70 | driver_age, years_licensed, ncb_years, vehicle_value_group, vehicle_age, make_model, engine_size_cc, body_type, transmission, seats, vehicle_colour, fuel_type, driver_assist, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, telematics_opt_in, telematics_score, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, written_premium, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, email_domain, marketing_consent, document_preference, previous_insurer, campaign_code, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer |
| buildings | glm_freq_sev | 27 | flood_zone, elevation_m, distance_to_river_km, sum_insured, bedrooms, energy_rating, year_built, property_type, construction_type, occupancy, prior_claims_5y, missed_payments_12m, region, urban_density, soil_type, trees_within_5m, roof_type, basement, listed_building, accidental_damage_cover, days_unoccupied, voluntary_excess, wind_exposure_index, hail_days, dry_summer_index, rainfall_mm, freezing_days |
| buildings | lgb_tweedie | 58 | policyholder_age, sum_insured, construction_type, occupancy, days_unoccupied, smoke_alarms, accidental_damage_cover, mortgage, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, written_premium, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, email_domain, marketing_consent, document_preference, previous_insurer, campaign_code, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer |
| contents | glm_freq_sev | 19 | flood_zone, elevation_m, distance_to_river_km, sum_insured, tenure, region, policyholder_age, prior_claims_5y, urban_density, missed_payments_12m, voluntary_excess, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, property_type, household_size |
| contents | lgb_tweedie | 59 | policyholder_age, sum_insured, tenure, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, voluntary_excess, compulsory_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, written_premium, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, customer_since_year, email_domain, marketing_consent, document_preference, previous_insurer, campaign_code, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, years_with_insurer |

## Variable importance (final fit)
### GLM: exposure-weighted spread of the log relativities
![](glm_importance.png)

| line | rank | feature | levels | cost_spread | freq_spread | sev_spread | min_cost_rel | max_cost_rel |
|---|---|---|---|---|---|---|---|---|
| buildings | 1 | sum_insured | 8 | 0.281 | 0.063 | 0.219 | 0.828 | 2.057 |
| buildings | 2 | flood_zone | 6 | 0.255 | 0.107 | 0.154 | 1 | 4.182 |
| buildings | 3 | elevation_m | 8 | 0.197 | 0.090 | 0.112 | 0.770 | 1.482 |
| buildings | 4 | energy_rating | 8 | 0.128 | 0.095 | 0.071 | 0.895 | 1.356 |
| buildings | 5 | year_built | 8 | 0.122 | 0.217 | 0.103 | 0.729 | 1.016 |
| buildings | 6 | prior_claims_5y | 4 | 0.117 | 0.133 | 0.026 | 1 | 1.759 |
| buildings | 7 | soil_type | 6 | 0.099 | 0.043 | 0.062 | 0.801 | 1 |
| buildings | 8 | region | 12 | 0.099 | 0.107 | 0.087 | 0.760 | 1.206 |
| buildings | 9 | construction_type | 4 | 0.093 | 0.101 | 0.010 | 1 | 1.368 |
| buildings | 10 | voluntary_excess | 4 | 0.084 | 0.123 | 0.056 | 0.715 | 1.003 |
| buildings | 11 | dry_summer_index | 8 | 0.083 | 0.030 | 0.062 | 0.921 | 1.200 |
| buildings | 12 | wind_exposure_index | 8 | 0.082 | 0.057 | 0.133 | 0.949 | 1.179 |
| buildings | 13 | missed_payments_12m | 4 | 0.077 | 0.075 | 0.005 | 1 | 1.523 |
| buildings | 14 | occupancy | 2 | 0.074 | 0.057 | 0.018 | 1 | 1.282 |
| buildings | 15 | bedrooms | 6 | 0.074 | 0.029 | 0.057 | 0.761 | 1 |
| buildings | 16 | freezing_days | 8 | 0.068 | 0.064 | 0.047 | 0.906 | 1.126 |
| buildings | 17 | distance_to_river_km | 9 | 0.065 | 0.032 | 0.043 | 0.839 | 1.096 |
| buildings | 18 | days_unoccupied | 9 | 0.061 | 0.063 | 0.060 | 0.855 | 1.075 |
| buildings | 19 | rainfall_mm | 8 | 0.052 | 0.031 | 0.035 | 0.960 | 1.104 |
| buildings | 20 | hail_days | 8 | 0.049 | 0.053 | 0.047 | 0.891 | 1.039 |
| buildings | 21 | basement | 2 | 0.048 | 0.013 | 0.035 | 1 | 1.144 |
| buildings | 22 | accidental_damage_cover | 2 | 0.047 | 0.153 | 0.107 | 1 | 1.100 |
| buildings | 23 | listed_building | 2 | 0.033 | 0.010 | 0.043 | 1 | 1.214 |
| buildings | 24 | property_type | 4 | 0.032 | 0.045 | 0.041 | 1 | 1.088 |
| buildings | 25 | urban_density | 4 | 0.027 | 0.013 | 0.016 | 1 | 1.068 |
| buildings | 26 | trees_within_5m | 2 | 0.019 | 0.014 | 0.005 | 1 | 1.059 |
| buildings | 27 | roof_type | 3 | 0.016 | 0.017 | 0.023 | 0.910 | 1 |
| contents | 1 | sum_insured | 8 | 0.375 | 0.084 | 0.295 | 1 | 3.362 |
| contents | 2 | flood_zone | 6 | 0.260 | 0.120 | 0.149 | 1 | 5.325 |
| contents | 3 | region | 12 | 0.155 | 0.159 | 0.042 | 0.859 | 1.514 |
| contents | 4 | policyholder_age | 8 | 0.149 | 0.174 | 0.030 | 0.632 | 1 |
| contents | 5 | voluntary_excess | 4 | 0.125 | 0.193 | 0.085 | 0.705 | 1 |
| contents | 6 | elevation_m | 8 | 0.123 | 0.041 | 0.087 | 0.820 | 1.243 |
| contents | 7 | prior_claims_5y | 4 | 0.120 | 0.114 | 0.007 | 1 | 2.254 |
| contents | 8 | missed_payments_12m | 4 | 0.114 | 0.102 | 0.014 | 1 | 1.839 |
| contents | 9 | urban_density | 4 | 0.105 | 0.064 | 0.043 | 0.972 | 1.371 |
| contents | 10 | accidental_damage_cover | 2 | 0.095 | 0.323 | 0.228 | 1 | 1.211 |
| contents | 11 | high_value_items | 7 | 0.069 | 0.014 | 0.069 | 0.969 | 1.316 |
| contents | 12 | distance_to_river_km | 9 | 0.068 | 0.048 | 0.032 | 0.864 | 1.176 |
| contents | 13 | property_type | 4 | 0.063 | 0.035 | 0.030 | 0.841 | 1 |
| contents | 14 | security_level | 4 | 0.051 | 0.031 | 0.022 | 0.894 | 1 |
| contents | 15 | lodgers | 2 | 0.037 | 0.034 | 0.003 | 1 | 1.185 |
| contents | 16 | tenure | 2 | 0.031 | 0.032 | 0.001 | 1 | 1.070 |
| contents | 17 | household_size | 8 | 0.031 | 0.016 | 0.023 | 0.942 | 1.107 |
| contents | 18 | bicycle_cover | 2 | 0.011 | 0.016 | 0.005 | 1 | 1.032 |
| contents | 19 | works_from_home | 2 | 0.008 | 0.006 | 0.003 | 0.981 | 1 |
| motor | 1 | ncb_years | 8 | 0.253 | 0.234 | 0.028 | 0.635 | 1.303 |
| motor | 2 | years_licensed | 8 | 0.203 | 0.158 | 0.058 | 0.735 | 1.362 |
| motor | 3 | driver_age | 8 | 0.198 | 0.179 | 0.048 | 0.575 | 1.016 |
| motor | 4 | annual_mileage | 7 | 0.168 | 0.164 | 0.015 | 0.797 | 1.372 |
| motor | 5 | prior_claims_5y | 4 | 0.123 | 0.123 | 0.006 | 1 | 2.057 |
| motor | 6 | cover_type | 3 | 0.121 | 0.384 | 0.263 | 0.697 | 1 |
| motor | 7 | region | 12 | 0.118 | 0.126 | 0.022 | 0.788 | 1.179 |
| motor | 8 | voluntary_excess | 4 | 0.109 | 0.161 | 0.052 | 0.726 | 1 |
| motor | 9 | vehicle_age | 9 | 0.095 | 0.034 | 0.065 | 0.764 | 1 |
| motor | 10 | vehicle_value_group | 8 | 0.086 | 0.040 | 0.048 | 0.928 | 1.206 |
| motor | 11 | vehicle_use | 3 | 0.071 | 0.064 | 0.008 | 1 | 1.248 |
| motor | 12 | urban_density | 4 | 0.070 | 0.075 | 0.015 | 0.897 | 1.138 |
| motor | 13 | telematics_opt_in | 2 | 0.067 | 0.061 | 0.006 | 0.816 | 1 |
| motor | 14 | occupation | 21 | 0.067 | 0.063 | 0.025 | 0.871 | 1.126 |
| motor | 15 | credit_band | 5 | 0.061 | 0.057 | 0.005 | 1 | 1.260 |
| motor | 16 | licence_points | 4 | 0.056 | 0.052 | 0.006 | 1 | 1.245 |
| motor | 17 | payment_method | 2 | 0.047 | 0.045 | 0.002 | 1 | 1.098 |
| motor | 18 | missed_payments_12m | 4 | 0.043 | 0.048 | 0.011 | 1 | 1.179 |
| motor | 19 | years_at_address | 9 | 0.039 | 0.030 | 0.023 | 0.999 | 1.108 |
| motor | 20 | renewal_count | 7 | 0.037 | 0.025 | 0.016 | 0.890 | 1 |
| motor | 21 | named_young_driver | 2 | 0.036 | 0.038 | 0.002 | 1 | 1.173 |
| motor | 22 | overnight_parking | 4 | 0.020 | 0.017 | 0.010 | 0.952 | 1.010 |
| motor | 23 | new_business | 2 | 0.017 | 0.029 | 0.012 | 1 | 1.063 |
| motor | 24 | marital_status | 5 | 0.013 | 0.005 | 0.010 | 0.977 | 1.045 |
| motor | 25 | fuel_type | 4 | 0.013 | 0.011 | 0.010 | 1 | 1.049 |
| motor | 26 | body_type | 5 | 0.012 | 0.012 | 0.007 | 0.960 | 1.004 |

### LightGBM: share of total gain
![](lgb_importance.png)

| line | rank | Feature | Gain | Cover | Frequency |
|---|---|---|---|---|---|
| motor | 1 | make_model | 0.4515 | 0.4092 | 0.5289 |
| motor | 2 | ncb_years | 0.1479 | 0.0941 | 0.0311 |
| motor | 3 | written_premium | 0.1010 | 0.0633 | 0.0300 |
| motor | 4 | previous_insurer | 0.0854 | 0.0393 | 0.1683 |
| motor | 5 | annual_mileage | 0.0368 | 0.0706 | 0.0411 |
| motor | 6 | years_licensed | 0.0348 | 0.0336 | 0.0189 |
| motor | 7 | marketing_segment | 0.0203 | 0.0372 | 0.0161 |
| motor | 8 | cover_type | 0.0201 | 0.0360 | 0.0233 |
| motor | 9 | prior_claims_5y | 0.0195 | 0.0433 | 0.0211 |
| motor | 10 | driver_age | 0.0161 | 0.0165 | 0.0089 |
| motor | 11 | voluntary_excess | 0.0109 | 0.0296 | 0.0156 |
| motor | 12 | customer_age | 0.0100 | 0.0134 | 0.0061 |
| motor | 13 | vehicle_age | 0.0090 | 0.0242 | 0.0156 |
| motor | 14 | region | 0.0083 | 0.0178 | 0.0156 |
| motor | 15 | occupation | 0.0064 | 0.0063 | 0.0189 |
| motor | 16 | telematics_score | 0.0038 | 0.0118 | 0.0072 |
| motor | 17 | payment_method | 0.0037 | 0.0109 | 0.0056 |
| motor | 18 | missed_payments_12m | 0.0025 | 0.0099 | 0.0028 |
| motor | 19 | urban_density | 0.0023 | 0.0092 | 0.0039 |
| motor | 20 | channel | 0.0021 | 0.0075 | 0.0033 |
| motor | 21 | credit_band | 0.0017 | 0.0039 | 0.0033 |
| motor | 22 | vehicle_use | 0.0014 | 0.0049 | 0.0028 |
| motor | 23 | licence_points | 0.0010 | 0.0036 | 0.0022 |
| motor | 24 | campaign_code | 0.0007 | 0.0007 | 0.0022 |
| motor | 25 | discount_applied | 0.0004 | 0.0014 | 0.0006 |
| motor | 26 | energy_rating | 0.0003 | 0.0001 | 0.0011 |
| motor | 27 | wildfire_index | 0.0003 | 0.0000 | 0.0006 |
| motor | 28 | new_business | 0.0003 | 0.0011 | 0.0006 |
| motor | 29 | days_quote_to_inception | 0.0002 | 0.0000 | 0.0006 |
| motor | 30 | vehicle_colour | 0.0002 | 0.0000 | 0.0006 |
| motor | 31 | elevation_m | 0.0002 | 0.0000 | 0.0006 |
| motor | 32 | soil_type | 0.0002 | 0.0000 | 0.0006 |
| motor | 33 | year_built | 0.0002 | 0.0001 | 0.0006 |
| motor | 34 | flood_zone | 0.0002 | 0.0000 | 0.0006 |
| motor | 35 | dry_summer_index | 0.0002 | 0.0001 | 0.0006 |
| motor | 36 | household_size | 0.0002 | 0.0001 | 0.0006 |
| buildings | 1 | written_premium | 0.3414 | 0.1916 | 0.0618 |
| buildings | 2 | previous_insurer | 0.1970 | 0.1718 | 0.2873 |
| buildings | 3 | occupation | 0.0849 | 0.0617 | 0.1394 |
| buildings | 4 | elevation_m | 0.0490 | 0.0734 | 0.0424 |
| buildings | 5 | sum_insured | 0.0389 | 0.0830 | 0.0382 |
| buildings | 6 | energy_rating | 0.0313 | 0.0438 | 0.0303 |
| buildings | 7 | year_built | 0.0310 | 0.0614 | 0.0279 |
| buildings | 8 | campaign_code | 0.0267 | 0.0194 | 0.0485 |
| buildings | 9 | marketing_segment | 0.0264 | 0.0185 | 0.0491 |
| buildings | 10 | region | 0.0241 | 0.0215 | 0.0430 |
| buildings | 11 | flood_zone | 0.0180 | 0.0172 | 0.0097 |
| buildings | 12 | prior_claims_5y | 0.0166 | 0.0538 | 0.0218 |
| buildings | 13 | dry_summer_index | 0.0143 | 0.0182 | 0.0218 |
| buildings | 14 | soil_type | 0.0119 | 0.0225 | 0.0176 |
| buildings | 15 | construction_type | 0.0085 | 0.0224 | 0.0139 |
| buildings | 16 | missed_payments_12m | 0.0079 | 0.0259 | 0.0109 |
| buildings | 17 | distance_to_river_km | 0.0075 | 0.0044 | 0.0133 |
| buildings | 18 | rainfall_mm | 0.0059 | 0.0060 | 0.0109 |
| buildings | 19 | wind_exposure_index | 0.0048 | 0.0033 | 0.0091 |
| buildings | 20 | voluntary_excess | 0.0044 | 0.0131 | 0.0073 |
| buildings | 21 | credit_band | 0.0035 | 0.0079 | 0.0067 |
| buildings | 22 | days_quote_to_inception | 0.0032 | 0.0035 | 0.0061 |
| buildings | 23 | channel | 0.0030 | 0.0035 | 0.0061 |
| buildings | 24 | branch_id | 0.0030 | 0.0017 | 0.0055 |
| buildings | 25 | email_domain | 0.0028 | 0.0009 | 0.0048 |
| buildings | 26 | occupancy | 0.0028 | 0.0122 | 0.0042 |
| buildings | 27 | years_at_address | 0.0027 | 0.0030 | 0.0061 |
| buildings | 28 | payment_method | 0.0026 | 0.0075 | 0.0055 |
| buildings | 29 | wildfire_index | 0.0024 | 0.0021 | 0.0042 |
| buildings | 30 | policyholder_age | 0.0024 | 0.0034 | 0.0042 |
| buildings | 31 | customer_since_year | 0.0022 | 0.0032 | 0.0042 |
| buildings | 32 | mean_temperature_c | 0.0022 | 0.0023 | 0.0042 |
| buildings | 33 | freezing_days | 0.0019 | 0.0019 | 0.0042 |
| buildings | 34 | household_size | 0.0015 | 0.0005 | 0.0030 |
| buildings | 35 | property_type | 0.0014 | 0.0014 | 0.0024 |
| buildings | 36 | hail_days | 0.0013 | 0.0011 | 0.0030 |
| buildings | 37 | customer_age | 0.0012 | 0.0004 | 0.0018 |
| buildings | 38 | days_unoccupied | 0.0011 | 0.0005 | 0.0024 |
| buildings | 39 | bedrooms | 0.0011 | 0.0030 | 0.0018 |
| buildings | 40 | marketing_consent | 0.0011 | 0.0008 | 0.0024 |
| buildings | 41 | accidental_damage_cover | 0.0011 | 0.0020 | 0.0024 |
| buildings | 42 | smoke_alarms | 0.0009 | 0.0005 | 0.0018 |
| buildings | 43 | renewal_count | 0.0008 | 0.0008 | 0.0018 |
| buildings | 44 | basement | 0.0008 | 0.0006 | 0.0018 |
| buildings | 45 | urban_density | 0.0006 | 0.0007 | 0.0012 |
| buildings | 46 | marital_status | 0.0006 | 0.0008 | 0.0012 |
| buildings | 47 | roof_type | 0.0005 | 0.0002 | 0.0006 |
| buildings | 48 | solar_panels | 0.0004 | 0.0001 | 0.0006 |
| buildings | 49 | discount_applied | 0.0003 | 0.0001 | 0.0006 |
| buildings | 50 | listed_building | 0.0002 | 0.0004 | 0.0006 |
| contents | 1 | flood_zone | 0.1972 | 0.1175 | 0.0379 |
| contents | 2 | previous_insurer | 0.1926 | 0.1393 | 0.2727 |
| contents | 3 | written_premium | 0.1408 | 0.1411 | 0.0646 |
| contents | 4 | elevation_m | 0.0874 | 0.0725 | 0.0444 |
| contents | 5 | occupation | 0.0848 | 0.0546 | 0.1495 |
| contents | 6 | sum_insured | 0.0432 | 0.0528 | 0.0394 |
| contents | 7 | marketing_segment | 0.0339 | 0.0437 | 0.0490 |
| contents | 8 | region | 0.0279 | 0.0320 | 0.0460 |
| contents | 9 | campaign_code | 0.0242 | 0.0187 | 0.0470 |
| contents | 10 | prior_claims_5y | 0.0183 | 0.0471 | 0.0202 |
| contents | 11 | distance_to_river_km | 0.0176 | 0.0145 | 0.0167 |
| contents | 12 | voluntary_excess | 0.0175 | 0.0454 | 0.0197 |
| contents | 13 | accidental_damage_cover | 0.0120 | 0.0334 | 0.0152 |
| contents | 14 | missed_payments_12m | 0.0096 | 0.0275 | 0.0131 |
| contents | 15 | customer_age | 0.0074 | 0.0218 | 0.0101 |
| contents | 16 | property_type | 0.0073 | 0.0045 | 0.0111 |
| contents | 17 | urban_density | 0.0067 | 0.0165 | 0.0101 |
| contents | 18 | high_value_items | 0.0064 | 0.0153 | 0.0111 |
| contents | 19 | wildfire_index | 0.0054 | 0.0103 | 0.0091 |
| contents | 20 | security_level | 0.0053 | 0.0100 | 0.0091 |
| contents | 21 | policyholder_age | 0.0044 | 0.0081 | 0.0071 |
| contents | 22 | year_built | 0.0041 | 0.0037 | 0.0081 |
| contents | 23 | payment_method | 0.0038 | 0.0135 | 0.0051 |
| contents | 24 | credit_band | 0.0038 | 0.0075 | 0.0071 |
| contents | 25 | channel | 0.0038 | 0.0130 | 0.0076 |
| contents | 26 | energy_rating | 0.0035 | 0.0035 | 0.0071 |
| contents | 27 | rainfall_mm | 0.0033 | 0.0053 | 0.0061 |
| contents | 28 | mean_temperature_c | 0.0033 | 0.0030 | 0.0066 |
| contents | 29 | years_at_address | 0.0033 | 0.0019 | 0.0066 |
| contents | 30 | days_quote_to_inception | 0.0031 | 0.0053 | 0.0061 |
| contents | 31 | dry_summer_index | 0.0027 | 0.0022 | 0.0056 |
| contents | 32 | freezing_days | 0.0025 | 0.0030 | 0.0045 |
| contents | 33 | email_domain | 0.0022 | 0.0018 | 0.0045 |
| contents | 34 | wind_exposure_index | 0.0019 | 0.0015 | 0.0040 |
| contents | 35 | works_from_home | 0.0015 | 0.0023 | 0.0030 |
| contents | 36 | bedrooms | 0.0012 | 0.0008 | 0.0025 |
| contents | 37 | soil_type | 0.0012 | 0.0008 | 0.0025 |
| contents | 38 | branch_id | 0.0009 | 0.0009 | 0.0020 |
| contents | 39 | hail_days | 0.0009 | 0.0009 | 0.0015 |
| contents | 40 | renewal_count | 0.0005 | 0.0003 | 0.0010 |
| contents | 41 | marital_status | 0.0004 | 0.0002 | 0.0010 |
| contents | 42 | household_size | 0.0004 | 0.0005 | 0.0010 |
| contents | 43 | roof_type | 0.0003 | 0.0001 | 0.0005 |
| contents | 44 | discount_applied | 0.0002 | 0.0005 | 0.0005 |
| contents | 45 | basement | 0.0002 | 0.0001 | 0.0005 |
| contents | 46 | document_preference | 0.0002 | 0.0000 | 0.0005 |
| contents | 47 | start_month | 0.0002 | 0.0001 | 0.0005 |
| contents | 48 | licence_points | 0.0002 | 0.0002 | 0.0005 |
| contents | 49 | marketing_consent | 0.0002 | 0.0002 | 0.0005 |

## GLM relativities (final fit)
Relativity to the base level (`1` = base, the level with most exposure). `cost_rel` = frequency x severity. Small p-values = level differs clearly from the base. Blank = level aliased or absent from the fitted sample.
Full detail: `glm_relativities.csv`.

### motor
Base frequency 0.2346 claims per exposure-year, base severity 3232 CU.

| feature | level | exposure_share | freq_rel | sev_rel | cost_rel | freq_p | sev_p |
|---|---|---|---|---|---|---|---|
| driver_age | (-Inf,24] | 0.1329 | 1 | 1 | 1 |  |  |
| driver_age | (24,30] | 0.1143 | 0.7446 | 1.0046 | 0.7480 | 0 | 0.8880 |
| driver_age | (30,40] | 0.1297 | 0.6299 | 1.0277 | 0.6473 | 0 | 0.5745 |
| driver_age | (40,50] | 0.1284 | 0.5952 | 0.9668 | 0.5754 | 0 | 0.6032 |
| driver_age | (50,59] | 0.1159 | 0.6157 | 1.0161 | 0.6256 | 0 | 0.8413 |
| driver_age | (59,69] | 0.1287 | 0.6755 | 1.0791 | 0.7290 | 0.0000 | 0.4034 |
| driver_age | (69,79] | 0.1288 | 0.7469 | 1.1141 | 0.8321 | 0.0028 | 0.2874 |
| driver_age | (79, Inf] | 0.1213 | 0.9186 | 1.1061 | 1.0160 | 0.4196 | 0.3560 |
| ncb_years | (-Inf,1] | 0.1381 | 1.2874 | 1.0121 | 1.3030 | 0 | 0.5202 |
| ncb_years | (1,3] | 0.1672 | 1 | 1 | 1 |  |  |
| ncb_years | (3,4] | 0.0636 | 0.8697 | 0.9454 | 0.8222 | 0.0000 | 0.0568 |
| ncb_years | (4,7] | 0.1584 | 0.7968 | 0.9766 | 0.7781 | 0 | 0.3074 |
| ncb_years | (7,9] | 0.1041 | 0.6813 | 0.9674 | 0.6591 | 0 | 0.2317 |
| ncb_years | (9,12] | 0.1574 | 0.6728 | 0.9515 | 0.6401 | 0 | 0.0418 |
| ncb_years | (12,14] | 0.1051 | 0.6823 | 0.9304 | 0.6348 | 0 | 0.0093 |
| ncb_years | (14, Inf] | 0.1061 | 0.6388 | 1.0017 | 0.6399 | 0 | 0.9533 |
| years_licensed | (-Inf,3] | 0.1329 | 1.2826 | 1.0616 | 1.3615 | 0.0000 | 0.1938 |
| years_licensed | (3,9] | 0.1099 | 1.0522 | 1.0505 | 1.1053 | 0.1711 | 0.1917 |
| years_licensed | (9,19] | 0.1347 | 1 | 1 | 1 |  |  |
| years_licensed | (19,28] | 0.1149 | 0.9298 | 1.0929 | 1.0161 | 0.1012 | 0.0534 |
| years_licensed | (28,38] | 0.1288 | 0.8551 | 1.0276 | 0.8787 | 0.0109 | 0.6639 |
| years_licensed | (38,48] | 0.1288 | 0.7910 | 0.9298 | 0.7355 | 0.0021 | 0.3554 |
| years_licensed | (48,58] | 0.1291 | 0.8273 | 0.9309 | 0.7701 | 0.0294 | 0.4284 |
| years_licensed | (58, Inf] | 0.1209 | 0.7980 | 0.9554 | 0.7624 | 0.0182 | 0.6447 |
| vehicle_value_group | (-Inf,7] | 0.1779 | 0.9704 | 0.9561 | 0.9278 | 0.1322 | 0.0302 |
| vehicle_value_group | (7,8] | 0.0772 | 0.9918 | 0.9524 | 0.9445 | 0.7484 | 0.0680 |
| vehicle_value_group | (8,10] | 0.1878 | 1 | 1 | 1 |  |  |
| vehicle_value_group | (10,11] | 0.1013 | 1.0381 | 1.0221 | 1.0611 | 0.1141 | 0.3720 |
| vehicle_value_group | (11,12] | 0.0974 | 1.0498 | 0.9971 | 1.0468 | 0.0449 | 0.9072 |
| vehicle_value_group | (12,14] | 0.1714 | 1.0723 | 1.0562 | 1.1326 | 0.0007 | 0.0103 |
| vehicle_value_group | (14,15] | 0.0651 | 1.0338 | 1.0399 | 1.0750 | 0.2472 | 0.1876 |
| vehicle_value_group | (15, Inf] | 0.1219 | 1.0872 | 1.1090 | 1.2057 | 0.0003 | 0.0000 |
| vehicle_age | (-Inf,3] | 0.1355 | 0.9787 | 1.0186 | 0.9969 | 0.3312 | 0.4206 |
| vehicle_age | (3,5] | 0.1942 | 1 | 1 | 1 |  |  |
| vehicle_age | (5,6] | 0.1028 | 1.0074 | 0.9638 | 0.9710 | 0.7495 | 0.1255 |
| vehicle_age | (6,7] | 0.0966 | 1.0174 | 0.9644 | 0.9812 | 0.4615 | 0.1388 |
| vehicle_age | (7,8] | 0.0863 | 0.9768 | 0.9250 | 0.9036 | 0.3415 | 0.0021 |
| vehicle_age | (8,10] | 0.1354 | 0.9432 | 0.9021 | 0.8509 | 0.0068 | 0.0000 |
| vehicle_age | (10,13] | 0.1213 | 0.9332 | 0.8754 | 0.8169 | 0.0020 | 0.0000 |
| vehicle_age | (13, Inf] | 0.1029 | 0.9229 | 0.8281 | 0.7643 | 0.0009 | 0 |
| vehicle_age | missing | 0.0250 | 1.0221 | 0.9437 | 0.9646 | 0.5847 | 0.1699 |
| cover_type | comprehensive | 0.8206 | 1 | 1 | 1 |  |  |
| cover_type | third_party_fire_theft | 0.0902 | 0.3916 | 1.9610 | 0.7679 | 0 | 0 |
| cover_type | third_party_only | 0.0892 | 0.3467 | 2.0119 | 0.6974 | 0 | 0 |
| annual_mileage | (-Inf,5e+03] | 0.1705 | 0.7756 | 1.0274 | 0.7968 | 0 | 0.1780 |
| annual_mileage | (5e+03,9.5e+03] | 0.0745 | 0.8896 | 1.0053 | 0.8943 | 0.0000 | 0.8444 |
| annual_mileage | (9.5e+03,1e+04] | 0.4012 | 1 | 1 | 1 |  |  |
| annual_mileage | (1e+04,1.5e+04] | 0.1841 | 1.1589 | 1.0250 | 1.1879 | 0 | 0.1503 |
| annual_mileage | (1.5e+04,1.93e+04] | 0.0227 | 1.2432 | 1.0250 | 1.2742 | 0.0000 | 0.5245 |
| annual_mileage | (1.93e+04, Inf] | 0.1218 | 1.3283 | 1.0329 | 1.3721 | 0 | 0.0817 |
| annual_mileage | missing | 0.0252 | 0.9442 | 0.9721 | 0.9179 | 0.1600 | 0.4942 |
| overnight_parking | driveway | 0.4883 | 1 | 1 | 1 |  |  |
| overnight_parking | garage | 0.1942 | 0.9593 | 0.9923 | 0.9520 | 0.0115 | 0.6496 |
| overnight_parking | missing | 0.0248 | 1.0283 | 0.9824 | 1.0102 | 0.4706 | 0.6630 |
| overnight_parking | street | 0.2927 | 0.9872 | 1.0178 | 1.0048 | 0.3599 | 0.2260 |
| vehicle_use | business | 0.0988 | 1.2256 | 1.0184 | 1.2481 | 0 | 0.3836 |
| vehicle_use | commuting | 0.4492 | 1.0945 | 1.0162 | 1.1122 | 0 | 0.2293 |
| vehicle_use | social | 0.4520 | 1 | 1 | 1 |  |  |
| named_young_driver | FALSE | 0.9460 | 1 | 1 | 1 |  |  |
| named_young_driver | TRUE | 0.0540 | 1.1830 | 0.9920 | 1.1735 | 0 | 0.7752 |
| fuel_type | diesel | 0.2760 | 0.9818 | 1.0209 | 1.0024 | 0.2013 | 0.1633 |
| fuel_type | electric | 0.0806 | 1.0206 | 1.0276 | 1.0487 | 0.3693 | 0.2485 |
| fuel_type | hybrid | 0.1376 | 0.9887 | 1.0139 | 1.0025 | 0.5391 | 0.4677 |
| fuel_type | petrol | 0.5058 | 1 | 1 | 1 |  |  |
| body_type | coupe | 0.0751 | 0.9641 | 0.9960 | 0.9602 | 0.1130 | 0.8653 |
| body_type | estate | 0.1241 | 1.0077 | 0.9963 | 1.0039 | 0.7109 | 0.8613 |
| body_type | hatchback | 0.3757 | 1 | 1 | 1 |  |  |
| body_type | saloon | 0.2127 | 0.9813 | 1.0007 | 0.9820 | 0.2720 | 0.9703 |
| body_type | suv | 0.2123 | 0.9835 | 1.0161 | 0.9994 | 0.3310 | 0.3699 |
| telematics_opt_in | FALSE | 0.8775 | 1 | 1 | 1 |  |  |
| telematics_opt_in | TRUE | 0.1225 | 0.8294 | 0.9833 | 0.8156 | 0 | 0.3841 |
| prior_claims_5y | 0 | 0.7382 | 1 | 1 | 1 |  |  |
| prior_claims_5y | 1 | 0.2215 | 1.2526 | 0.9952 | 1.2466 | 0 | 0.7412 |
| prior_claims_5y | 2 | 0.0362 | 1.5501 | 0.9938 | 1.5405 | 0 | 0.8285 |
| prior_claims_5y | 3 | 0.0041 | 1.8824 | 1.0927 | 2.0569 | 0 | 0.2412 |
| licence_points | 0 | 0.8015 | 1 | 1 | 1 |  |  |
| licence_points | 3 | 0.1191 | 1.0777 | 0.9937 | 1.0709 | 0.0000 | 0.7383 |
| licence_points | 6 | 0.0594 | 1.1823 | 1.0248 | 1.2116 | 0 | 0.3311 |
| licence_points | 9 | 0.0200 | 1.2440 | 1.0004 | 1.2445 | 0.0000 | 0.9917 |
| credit_band | A | 0.2513 | 1.0151 | 1.0095 | 1.0247 | 0.3698 | 0.5851 |
| credit_band | B | 0.2980 | 1 | 1 | 1 |  |  |
| credit_band | C | 0.2496 | 1.0039 | 1.0021 | 1.0060 | 0.8177 | 0.9059 |
| credit_band | D | 0.1200 | 1.0206 | 1.0047 | 1.0254 | 0.3411 | 0.8314 |
| credit_band | E | 0.0811 | 1.2395 | 1.0169 | 1.2605 | 0 | 0.5112 |
| region | R01 | 0.1619 | 1 | 1 | 1 |  |  |
| region | R02 | 0.0635 | 0.9507 | 1.0019 | 0.9525 | 0.0845 | 0.9493 |
| region | R03 | 0.0970 | 1.1788 | 0.9952 | 1.1731 | 0 | 0.8430 |
| region | R04 | 0.0590 | 1.0781 | 0.9543 | 1.0288 | 0.0086 | 0.1152 |
| region | R05 | 0.0788 | 0.7618 | 1.0338 | 0.7876 | 0 | 0.2680 |
| region | R06 | 0.0425 | 0.8007 | 1.0083 | 0.8074 | 0 | 0.8238 |
| region | R07 | 0.0726 | 1.2178 | 0.9677 | 1.1785 | 0 | 0.2159 |
| region | R08 | 0.0711 | 1.0913 | 1.0333 | 1.1277 | 0.0011 | 0.2406 |
| region | R09 | 0.0751 | 0.9141 | 0.9736 | 0.8900 | 0.0013 | 0.3542 |
| region | R10 | 0.0940 | 0.9885 | 0.9951 | 0.9836 | 0.6457 | 0.8499 |
| region | R11 | 0.0849 | 1.1149 | 0.9796 | 1.0921 | 0.0000 | 0.4313 |
| region | R12 | 0.0998 | 1.0309 | 1.0100 | 1.0412 | 0.2105 | 0.6930 |
| urban_density | dense_urban | 0.1006 | 1.1832 | 0.9618 | 1.1380 | 0 | 0.0568 |
| urban_density | rural | 0.1990 | 0.9218 | 0.9736 | 0.8974 | 0.0000 | 0.1307 |
| urban_density | suburban | 0.4495 | 1 | 1 | 1 |  |  |
| urban_density | urban | 0.2509 | 1.0940 | 0.9706 | 1.0618 | 0.0000 | 0.0529 |
| voluntary_excess | 0 | 0.4000 | 1 | 1 | 1 |  |  |
| voluntary_excess | 250 | 0.3001 | 0.8872 | 1.0524 | 0.9336 | 0 | 0.0005 |
| voluntary_excess | 500 | 0.2008 | 0.7262 | 1.1060 | 0.8032 | 0 | 0.0000 |
| voluntary_excess | 1000 | 0.0991 | 0.6190 | 1.1735 | 0.7264 | 0 | 0 |
| occupation | Accountant | 0.0402 | 0.9301 | 0.9521 | 0.8855 | 0.0605 | 0.2062 |
| occupation | Administrator | 0.0415 | 0.9804 | 1.0177 | 0.9977 | 0.5959 | 0.6505 |
| occupation | Builder | 0.0372 | 1.0665 | 1.0110 | 1.0782 | 0.0831 | 0.7771 |
| occupation | Care worker | 0.0427 | 0.9494 | 1.0276 | 0.9756 | 0.1664 | 0.4838 |
| occupation | Chef | 0.0388 | 1.0133 | 0.9450 | 0.9576 | 0.7220 | 0.1427 |
| occupation | Doctor | 0.0406 | 1.1401 | 0.9873 | 1.1256 | 0.0003 | 0.7380 |
| occupation | Driver | 0.0380 | 0.9848 | 0.9474 | 0.9331 | 0.6891 | 0.1681 |
| occupation | Electrician | 0.0370 | 1.0823 | 1.0111 | 1.0943 | 0.0343 | 0.7773 |
| occupation | Engineer | 0.0378 | 1.0885 | 0.9876 | 1.0750 | 0.0204 | 0.7424 |
| occupation | Hairdresser | 0.0440 | 0.8907 | 0.9784 | 0.8715 | 0.0023 | 0.5721 |
| occupation | Manager | 0.0395 | 0.9991 | 1.0137 | 1.0128 | 0.9800 | 0.7277 |
| occupation | Mechanic | 0.0375 | 1.0787 | 0.9993 | 1.0779 | 0.0394 | 0.9846 |
| occupation | missing | 0.0246 | 0.9466 | 1.0255 | 0.9707 | 0.2126 | 0.5759 |
| occupation | Nurse | 0.0428 | 0.9175 | 0.9588 | 0.8797 | 0.0233 | 0.2769 |
| occupation | Retail assistant | 0.0418 | 0.9703 | 0.9807 | 0.9516 | 0.4204 | 0.6156 |
| occupation | Retired | 0.1900 | 1 | 1 | 1 |  |  |
| occupation | Sales representative | 0.0400 | 1.0734 | 0.9613 | 1.0319 | 0.0523 | 0.3033 |
| occupation | Software developer | 0.0393 | 1.0194 | 0.9936 | 1.0129 | 0.6063 | 0.8678 |
| occupation | Student | 0.0642 | 0.9272 | 1.0187 | 0.9445 | 0.0179 | 0.5732 |
| occupation | Teacher | 0.0426 | 0.9343 | 0.9883 | 0.9234 | 0.0710 | 0.7619 |
| occupation | Unemployed | 0.0398 | 1.0812 | 0.9553 | 1.0329 | 0.0316 | 0.2318 |
| marital_status | divorced | 0.0830 | 0.9829 | 0.9942 | 0.9772 | 0.4869 | 0.8209 |
| marital_status | married | 0.4647 | 1 | 1 | 1 |  |  |
| marital_status | missing | 0.0254 | 0.9978 | 1.0074 | 1.0052 | 0.9545 | 0.8540 |
| marital_status | single | 0.3861 | 1.0015 | 1.0136 | 1.0151 | 0.9183 | 0.3802 |
| marital_status | widowed | 0.0408 | 1.0039 | 1.0409 | 1.0450 | 0.9084 | 0.2465 |
| years_at_address | (-Inf,2] | 0.1502 | 1.0505 | 1.0526 | 1.1057 | 0.0129 | 0.0126 |
| years_at_address | (2,3] | 0.0991 | 1.0749 | 1.0305 | 1.1077 | 0.0011 | 0.1971 |
| years_at_address | (3,5] | 0.1908 | 1 | 1 | 1 |  |  |
| years_at_address | (5,6] | 0.0843 | 0.9959 | 1.0760 | 1.0716 | 0.8697 | 0.0048 |
| years_at_address | (6,8] | 0.1396 | 0.9782 | 1.0589 | 1.0358 | 0.3112 | 0.0112 |
| years_at_address | (8,10] | 0.1028 | 0.9792 | 1.0205 | 0.9993 | 0.3996 | 0.4274 |
| years_at_address | (10,13] | 0.0972 | 1.0263 | 1.0304 | 1.0575 | 0.3083 | 0.2562 |
| years_at_address | (13, Inf] | 0.1107 | 1.0241 | 1.0304 | 1.0553 | 0.3364 | 0.2449 |
| years_at_address | missing | 0.0253 | 0.9985 | 1.0038 | 1.0023 | 0.9709 | 0.9278 |
| renewal_count | (-Inf,1] | 0.2095 | 1 | 1 | 1 |  |  |
| renewal_count | (1,3] | 0.1426 | 0.9462 | 0.9668 | 0.9148 | 0.0160 | 0.1575 |
| renewal_count | (3,6] | 0.1457 | 0.9513 | 0.9732 | 0.9259 | 0.0312 | 0.2599 |
| renewal_count | (6,9] | 0.1460 | 0.9419 | 0.9876 | 0.9302 | 0.0098 | 0.6057 |
| renewal_count | (9,11] | 0.0978 | 0.9610 | 0.9747 | 0.9367 | 0.1229 | 0.3392 |
| renewal_count | (11,14] | 0.1464 | 0.9269 | 0.9601 | 0.8899 | 0.0012 | 0.0914 |
| renewal_count | (14, Inf] | 0.1120 | 0.9698 | 0.9565 | 0.9276 | 0.2206 | 0.0877 |
| new_business | FALSE | 0.9161 | 1 | 1 | 1 |  |  |
| new_business | TRUE | 0.0839 | 1.1114 | 0.9569 | 1.0635 | 0.0000 | 0.0805 |
| payment_method | annual | 0.5491 | 1 | 1 | 1 |  |  |
| payment_method | monthly | 0.4509 | 1.0944 | 1.0036 | 1.0984 | 0 | 0.7880 |
| missed_payments_12m | 0 | 0.9186 | 1 | 1 | 1 |  |  |
| missed_payments_12m | 1 | 0.0646 | 1.1939 | 0.9797 | 1.1696 | 0 | 0.4179 |
| missed_payments_12m | 2 | 0.0139 | 1.1615 | 1.0150 | 1.1789 | 0.0015 | 0.7589 |
| missed_payments_12m | 3 | 0.0029 | 1.2658 | 0.8318 | 1.0529 | 0.0106 | 0.0560 |

### buildings
Base frequency 0.0432 claims per exposure-year, base severity 5815 CU.

| feature | level | exposure_share | freq_rel | sev_rel | cost_rel | freq_p | sev_p |
|---|---|---|---|---|---|---|---|
| flood_zone | 1 | 0.6851 | 1 | 1 | 1 |  |  |
| flood_zone | 2 | 0.1482 | 0.9730 | 1.0477 | 1.0195 | 0.4339 | 0.2905 |
| flood_zone | 3 | 0.0788 | 1.0088 | 1.1280 | 1.1379 | 0.8541 | 0.0461 |
| flood_zone | 4 | 0.0433 | 1.3250 | 1.6734 | 2.2172 | 0.0000 | 0 |
| flood_zone | 5 | 0.0154 | 2.0268 | 2.0632 | 4.1818 | 0 | 0 |
| flood_zone | missing | 0.0293 | 1.1888 | 1.6248 | 1.9315 | 0.0044 | 0 |
| elevation_m | (-Inf,2.1] | 0.1266 | 1.2149 | 1.2195 | 1.4816 | 0.0000 | 0.0001 |
| elevation_m | (2.1,3.9] | 0.1287 | 1 | 1 | 1 |  |  |
| elevation_m | (3.9,5.8] | 0.1205 | 1.0108 | 0.8755 | 0.8850 | 0.7984 | 0.0138 |
| elevation_m | (5.8,8.1] | 0.1264 | 0.9315 | 0.9202 | 0.8572 | 0.1011 | 0.1276 |
| elevation_m | (8.1,10.9] | 0.1229 | 0.9935 | 0.8989 | 0.8931 | 0.8818 | 0.0548 |
| elevation_m | (10.9,14.9] | 0.1253 | 0.9402 | 0.8707 | 0.8187 | 0.1635 | 0.0135 |
| elevation_m | (14.9,21.8] | 0.1247 | 0.8988 | 0.8565 | 0.7699 | 0.0186 | 0.0068 |
| elevation_m | (21.8, Inf] | 0.1249 | 0.9169 | 0.8650 | 0.7932 | 0.0720 | 0.0172 |
| distance_to_river_km | (-Inf,0.52] | 0.1238 | 1 | 1 | 1 |  |  |
| distance_to_river_km | (0.52,1.04] | 0.1203 | 0.9493 | 0.9336 | 0.8863 | 0.2340 | 0.2155 |
| distance_to_river_km | (1.04,1.65] | 0.1223 | 0.9787 | 0.9563 | 0.9359 | 0.6452 | 0.4570 |
| distance_to_river_km | (1.65,2.36] | 0.1218 | 0.9361 | 0.8962 | 0.8389 | 0.1786 | 0.0791 |
| distance_to_river_km | (2.36,3.25] | 0.1222 | 0.9547 | 0.9937 | 0.9486 | 0.3530 | 0.9201 |
| distance_to_river_km | (3.25,4.43] | 0.1212 | 0.9713 | 0.9805 | 0.9523 | 0.5638 | 0.7601 |
| distance_to_river_km | (4.43,6.29] | 0.1223 | 0.9196 | 0.9424 | 0.8666 | 0.1019 | 0.3600 |
| distance_to_river_km | (6.29, Inf] | 0.1213 | 0.8985 | 0.9490 | 0.8527 | 0.0384 | 0.4228 |
| distance_to_river_km | missing | 0.0247 | 0.9602 | 1.1419 | 1.0965 | 0.5855 | 0.1672 |
| sum_insured | (-Inf,1.3e+05] | 0.1257 | 0.9746 | 0.8497 | 0.8281 | 0.6466 | 0.0214 |
| sum_insured | (1.3e+05,1.67e+05] | 0.1283 | 1 | 1 | 1 |  |  |
| sum_insured | (1.67e+05,1.96e+05] | 0.1270 | 1.0354 | 1.0192 | 1.0553 | 0.4321 | 0.7307 |
| sum_insured | (1.96e+05,2.23e+05] | 0.1226 | 1.0979 | 1.2357 | 1.3567 | 0.0399 | 0.0002 |
| sum_insured | (2.23e+05,2.52e+05] | 0.1249 | 1.0997 | 1.2884 | 1.4168 | 0.0420 | 0.0000 |
| sum_insured | (2.52e+05,2.88e+05] | 0.1251 | 1.1232 | 1.4258 | 1.6015 | 0.0151 | 0.0000 |
| sum_insured | (2.88e+05,3.39e+05] | 0.1223 | 1.1335 | 1.4463 | 1.6393 | 0.0111 | 0.0000 |
| sum_insured | (3.39e+05, Inf] | 0.1241 | 1.1864 | 1.7338 | 2.0571 | 0.0009 | 0 |
| bedrooms | 1 | 0.0878 | 0.9218 | 0.8293 | 0.7644 | 0.2423 | 0.0326 |
| bedrooms | 2 | 0.2270 | 0.9595 | 0.9999 | 0.9594 | 0.2406 | 0.9981 |
| bedrooms | 3 | 0.3521 | 1 | 1 | 1 |  |  |
| bedrooms | 4 | 0.2497 | 0.9417 | 0.9997 | 0.9414 | 0.0486 | 0.9933 |
| bedrooms | 5 | 0.0757 | 0.9855 | 0.9598 | 0.9458 | 0.7588 | 0.4931 |
| bedrooms | 6 | 0.0077 | 0.9716 | 0.7828 | 0.7606 | 0.8072 | 0.1029 |
| energy_rating | A | 0.1556 | 1.0656 | 0.9344 | 0.9957 | 0.2028 | 0.2829 |
| energy_rating | B | 0.1923 | 1.0247 | 0.8731 | 0.8947 | 0.5574 | 0.0089 |
| energy_rating | C | 0.1962 | 1 | 1 | 1 |  |  |
| energy_rating | D | 0.1666 | 1.1258 | 0.8711 | 0.9807 | 0.0026 | 0.0056 |
| energy_rating | E | 0.1141 | 1.1934 | 0.9971 | 1.1899 | 0.0001 | 0.9593 |
| energy_rating | F | 0.0786 | 1.2962 | 1.0462 | 1.3562 | 0.0000 | 0.4983 |
| energy_rating | G | 0.0720 | 1.3534 | 0.8889 | 1.2030 | 0.0000 | 0.1129 |
| energy_rating | missing | 0.0247 | 1.1990 | 1.1218 | 1.3450 | 0.0116 | 0.2080 |
| year_built | (-Inf,1.9e+03] | 0.1492 | 1 | 1 | 1 |  |  |
| year_built | (1.9e+03,1.93e+03] | 0.1031 | 1.1483 | 0.8845 | 1.0157 | 0.0006 | 0.0187 |
| year_built | (1.93e+03,1.95e+03] | 0.1246 | 1.0105 | 0.9642 | 0.9743 | 0.8188 | 0.5345 |
| year_built | (1.95e+03,1.96e+03] | 0.1303 | 0.7090 | 1.1447 | 0.8116 | 0 | 0.0399 |
| year_built | (1.96e+03,1.98e+03] | 0.1252 | 0.7377 | 1.1614 | 0.8568 | 0.0000 | 0.0317 |
| year_built | (1.98e+03,1.99e+03] | 0.1199 | 0.6239 | 1.2347 | 0.7703 | 0 | 0.0050 |
| year_built | (1.99e+03,2.01e+03] | 0.1272 | 0.6223 | 1.1718 | 0.7292 | 0 | 0.0419 |
| year_built | (2.01e+03, Inf] | 0.1206 | 0.7273 | 1.0682 | 0.7769 | 0.0000 | 0.4139 |
| property_type | detached | 0.2510 | 1.0822 | 1.0055 | 1.0881 | 0.0111 | 0.8893 |
| property_type | flat | 0.1989 | 0.9490 | 1.1157 | 1.0588 | 0.1576 | 0.0199 |
| property_type | semi_detached | 0.2990 | 1 | 1 | 1 |  |  |
| property_type | terraced | 0.2511 | 1.0097 | 1.0209 | 1.0309 | 0.7339 | 0.5637 |
| construction_type | brick | 0.7003 | 1 | 1 | 1 |  |  |
| construction_type | non_standard | 0.0992 | 1.4043 | 0.9740 | 1.3678 | 0 | 0.5107 |
| construction_type | stone | 0.0796 | 1.0541 | 1.0026 | 1.0569 | 0.1820 | 0.9585 |
| construction_type | timber | 0.1210 | 1.0785 | 0.9785 | 1.0553 | 0.0204 | 0.5983 |
| occupancy | let | 0.0993 | 1.2086 | 1.0606 | 1.2818 | 0.0000 | 0.1519 |
| occupancy | owner_occupied | 0.9007 | 1 | 1 | 1 |  |  |
| prior_claims_5y | 0 | 0.7391 | 1 | 1 | 1 |  |  |
| prior_claims_5y | 1 | 0.2213 | 1.3055 | 0.9412 | 1.2287 | 0 | 0.0483 |
| prior_claims_5y | 2 | 0.0355 | 1.5288 | 1.0257 | 1.5680 | 0 | 0.6716 |
| prior_claims_5y | 3 | 0.0041 | 1.7596 | 0.9998 | 1.7592 | 0.0000 | 0.9989 |
| missed_payments_12m | 0 | 0.9191 | 1 | 1 | 1 |  |  |
| missed_payments_12m | 1 | 0.0640 | 1.3021 | 0.9983 | 1.2999 | 0 | 0.9721 |
| missed_payments_12m | 2 | 0.0139 | 1.3496 | 1.0339 | 1.3953 | 0.0001 | 0.7298 |
| missed_payments_12m | 3 | 0.0030 | 1.4311 | 1.0644 | 1.5232 | 0.0233 | 0.7687 |
| region | R01 | 0.1624 | 1 | 1 | 1 |  |  |
| region | R02 | 0.0626 | 0.9264 | 1.3015 | 1.2057 | 0.3530 | 0.0104 |
| region | R03 | 0.0973 | 0.9821 | 1.1517 | 1.1310 | 0.8219 | 0.1626 |
| region | R04 | 0.0589 | 0.9434 | 1.1447 | 1.0799 | 0.4139 | 0.1332 |
| region | R05 | 0.0798 | 1.0262 | 1.1736 | 1.2043 | 0.6992 | 0.0573 |
| region | R06 | 0.0418 | 0.6797 | 1.1186 | 0.7603 | 0.0005 | 0.4188 |
| region | R07 | 0.0715 | 1.0454 | 0.9307 | 0.9730 | 0.6343 | 0.5450 |
| region | R08 | 0.0711 | 0.8207 | 1.1530 | 0.9462 | 0.0034 | 0.0919 |
| region | R09 | 0.0752 | 0.8261 | 1.1647 | 0.9622 | 0.0315 | 0.1733 |
| region | R10 | 0.0935 | 0.9423 | 1.1184 | 1.0539 | 0.3862 | 0.1935 |
| region | R11 | 0.0850 | 0.8487 | 1.1586 | 0.9833 | 0.0183 | 0.0918 |
| region | R12 | 0.1009 | 1.0547 | 0.9942 | 1.0486 | 0.4604 | 0.9491 |
| urban_density | dense_urban | 0.1012 | 1.0253 | 1.0035 | 1.0289 | 0.4955 | 0.9393 |
| urban_density | rural | 0.1977 | 1.0203 | 0.9985 | 1.0188 | 0.4791 | 0.9668 |
| urban_density | suburban | 0.4494 | 1 | 1 | 1 |  |  |
| urban_density | urban | 0.2517 | 1.0302 | 1.0370 | 1.0683 | 0.2557 | 0.2731 |
| soil_type | chalk | 0.1434 | 0.8913 | 0.8984 | 0.8007 | 0.0006 | 0.0108 |
| soil_type | clay | 0.4046 | 1 | 1 | 1 |  |  |
| soil_type | loam | 0.1428 | 0.9150 | 0.8916 | 0.8159 | 0.0078 | 0.0062 |
| soil_type | missing | 0.0245 | 0.9530 | 0.8487 | 0.8088 | 0.4892 | 0.0572 |
| soil_type | rock | 0.1433 | 0.9517 | 0.8600 | 0.8185 | 0.1309 | 0.0003 |
| soil_type | sand | 0.1415 | 0.9366 | 0.8981 | 0.8411 | 0.0490 | 0.0101 |
| trees_within_5m | FALSE | 0.8784 | 1 | 1 | 1 |  |  |
| trees_within_5m | TRUE | 0.1216 | 1.0433 | 1.0152 | 1.0591 | 0.1828 | 0.7126 |
| roof_type | flat | 0.0992 | 1.0541 | 0.9293 | 0.9796 | 0.1266 | 0.0882 |
| roof_type | missing | 0.0248 | 0.9603 | 0.9476 | 0.9100 | 0.5590 | 0.5317 |
| roof_type | pitched | 0.8759 | 1 | 1 | 1 |  |  |
| basement | FALSE | 0.8510 | 1 | 1 | 1 |  |  |
| basement | TRUE | 0.1490 | 1.0374 | 1.1030 | 1.1443 | 0.2089 | 0.0084 |
| listed_building | FALSE | 0.9702 | 1 | 1 | 1 |  |  |
| listed_building | TRUE | 0.0298 | 0.9412 | 1.2895 | 1.2137 | 0.3425 | 0.0013 |
| accidental_damage_cover | FALSE | 0.6008 | 1 | 1 | 1 |  |  |
| accidental_damage_cover | TRUE | 0.3992 | 1.3679 | 0.8042 | 1.1001 | 0 | 0 |
| days_unoccupied | (-Inf,1] | 0.1237 | 0.9674 | 0.9457 | 0.9148 | 0.4392 | 0.3010 |
| days_unoccupied | (1,3] | 0.1240 | 1 | 1 | 1 |  |  |
| days_unoccupied | (3,5] | 0.1235 | 1.0201 | 0.9386 | 0.9574 | 0.6398 | 0.2358 |
| days_unoccupied | (5,7] | 0.1230 | 0.9707 | 1.0084 | 0.9789 | 0.4892 | 0.8774 |
| days_unoccupied | (7,9] | 0.1237 | 0.9660 | 0.9523 | 0.9199 | 0.4215 | 0.3622 |
| days_unoccupied | (9,11] | 0.1230 | 1.0171 | 1.0570 | 1.0751 | 0.6894 | 0.3032 |
| days_unoccupied | (11,13] | 0.1232 | 0.9967 | 0.8983 | 0.8953 | 0.9381 | 0.0460 |
| days_unoccupied | (13, Inf] | 0.1111 | 1.1925 | 0.8621 | 1.0281 | 0.0000 | 0.0053 |
| days_unoccupied | missing | 0.0248 | 0.9305 | 0.9183 | 0.8545 | 0.3477 | 0.3625 |
| voluntary_excess | 0 | 0.5007 | 1 | 1 | 1 |  |  |
| voluntary_excess | 250 | 0.2997 | 0.9315 | 1.0767 | 1.0029 | 0.0031 | 0.0149 |
| voluntary_excess | 500 | 0.1502 | 0.7493 | 1.1670 | 0.8744 | 0 | 0.0002 |
| voluntary_excess | 1000 | 0.0494 | 0.6618 | 1.0800 | 0.7147 | 0 | 0.2852 |
| wind_exposure_index | (-Inf,1.8] | 0.1275 | 0.8766 | 1.3450 | 1.1790 | 0.0275 | 0.0001 |
| wind_exposure_index | (1.8,2.7] | 0.1226 | 0.9117 | 1.2242 | 1.1162 | 0.1083 | 0.0052 |
| wind_exposure_index | (2.7,3.6] | 0.1291 | 0.9737 | 1.1499 | 1.1197 | 0.6218 | 0.0401 |
| wind_exposure_index | (3.6,4.6] | 0.1268 | 0.9620 | 1.1649 | 1.1207 | 0.4095 | 0.0093 |
| wind_exposure_index | (4.6,5.5] | 0.1354 | 1 | 1 | 1 |  |  |
| wind_exposure_index | (5.5,6.2] | 0.1253 | 0.9715 | 0.9766 | 0.9488 | 0.4977 | 0.6573 |
| wind_exposure_index | (6.2,6.9] | 0.1124 | 1.0430 | 0.9315 | 0.9716 | 0.3346 | 0.1969 |
| wind_exposure_index | (6.9, Inf] | 0.1210 | 1.0502 | 0.9042 | 0.9496 | 0.2654 | 0.0698 |
| hail_days | (-Inf,2] | 0.1697 | 0.8835 | 1.0623 | 0.9386 | 0.0010 | 0.2006 |
| hail_days | (2,3] | 0.1049 | 0.9284 | 0.9599 | 0.8912 | 0.0734 | 0.4380 |
| hail_days | (3,4] | 0.1094 | 0.9457 | 1.0361 | 0.9798 | 0.1680 | 0.4878 |
| hail_days | (4,6] | 0.1992 | 1 | 1 | 1 |  |  |
| hail_days | (6,7] | 0.0829 | 0.9922 | 1.0467 | 1.0386 | 0.8589 | 0.4089 |
| hail_days | (7,9] | 0.1304 | 0.9710 | 0.9263 | 0.8995 | 0.4469 | 0.1172 |
| hail_days | (9,11] | 0.0879 | 1.0628 | 0.9596 | 1.0199 | 0.1588 | 0.4589 |
| hail_days | (11, Inf] | 0.1156 | 0.9997 | 0.9628 | 0.9625 | 0.9939 | 0.4777 |
| dry_summer_index | (-Inf,0.183] | 0.1246 | 0.9445 | 1.0658 | 1.0067 | 0.3578 | 0.4216 |
| dry_summer_index | (0.183,0.366] | 0.1252 | 0.9341 | 0.9856 | 0.9207 | 0.1298 | 0.7981 |
| dry_summer_index | (0.366,0.457] | 0.1276 | 1 | 1 | 1 |  |  |
| dry_summer_index | (0.457,0.536] | 0.1259 | 0.9614 | 1.0250 | 0.9854 | 0.3539 | 0.6455 |
| dry_summer_index | (0.536,0.635] | 0.1260 | 0.9720 | 0.9997 | 0.9717 | 0.5257 | 0.9961 |
| dry_summer_index | (0.635,0.729] | 0.1251 | 0.9672 | 1.0688 | 1.0337 | 0.4776 | 0.2680 |
| dry_summer_index | (0.729,0.827] | 0.1216 | 0.9954 | 1.1617 | 1.1564 | 0.9259 | 0.0186 |
| dry_summer_index | (0.827, Inf] | 0.1240 | 1.0292 | 1.1661 | 1.2001 | 0.5870 | 0.0221 |
| rainfall_mm | (-Inf,740] | 0.1235 | 0.9735 | 0.9862 | 0.9601 | 0.6317 | 0.8439 |
| rainfall_mm | (740,854] | 0.1242 | 1.0333 | 0.9966 | 1.0297 | 0.5319 | 0.9585 |
| rainfall_mm | (854,938] | 0.1250 | 1.0454 | 1.0440 | 1.0913 | 0.3604 | 0.4858 |
| rainfall_mm | (938,1.01e+03] | 0.1251 | 1.0159 | 1.0623 | 1.0792 | 0.7366 | 0.3028 |
| rainfall_mm | (1.01e+03,1.1e+03] | 0.1241 | 1.0150 | 1.0544 | 1.0702 | 0.7412 | 0.3562 |
| rainfall_mm | (1.1e+03,1.2e+03] | 0.1252 | 1.0048 | 1.0985 | 1.1038 | 0.9130 | 0.0870 |
| rainfall_mm | (1.2e+03,1.36e+03] | 0.1267 | 1 | 1 | 1 |  |  |
| rainfall_mm | (1.36e+03, Inf] | 0.1263 | 0.9419 | 1.0247 | 0.9651 | 0.2246 | 0.6922 |
| freezing_days | (-Inf,13] | 0.1323 | 0.8542 | 1.0603 | 0.9057 | 0.0392 | 0.5420 |
| freezing_days | (13,20] | 0.1166 | 0.9692 | 1.1556 | 1.1200 | 0.6504 | 0.0970 |
| freezing_days | (20,27] | 0.1302 | 1.0086 | 1.0952 | 1.1046 | 0.8968 | 0.2736 |
| freezing_days | (27,35] | 0.1204 | 0.9762 | 1.1086 | 1.0822 | 0.7023 | 0.1951 |
| freezing_days | (35,47] | 0.1308 | 1.0068 | 1.0366 | 1.0437 | 0.8973 | 0.5853 |
| freezing_days | (47,58] | 0.1338 | 1 | 1 | 1 |  |  |
| freezing_days | (58,66] | 0.1248 | 1.0541 | 0.9993 | 1.0533 | 0.2177 | 0.9891 |
| freezing_days | (66, Inf] | 0.1109 | 1.0633 | 1.0590 | 1.1261 | 0.1814 | 0.3235 |

### contents
Base frequency 0.0283 claims per exposure-year, base severity 1756 CU.

| feature | level | exposure_share | freq_rel | sev_rel | cost_rel | freq_p | sev_p |
|---|---|---|---|---|---|---|---|
| flood_zone | 1 | 0.6859 | 1 | 1 | 1 |  |  |
| flood_zone | 2 | 0.1472 | 0.9836 | 1.0282 | 1.0113 | 0.6530 | 0.3454 |
| flood_zone | 3 | 0.0784 | 1.0341 | 1.2470 | 1.2895 | 0.5061 | 0.0000 |
| flood_zone | 4 | 0.0438 | 1.3150 | 1.5358 | 2.0196 | 0.0000 | 0 |
| flood_zone | 5 | 0.0155 | 2.3803 | 2.2370 | 5.3247 | 0 | 0 |
| flood_zone | missing | 0.0292 | 1.0642 | 1.4564 | 1.5499 | 0.3605 | 0 |
| elevation_m | (-Inf,2.1] | 0.1258 | 1.0598 | 1.1727 | 1.2428 | 0.1896 | 0.0000 |
| elevation_m | (2.1,3.9] | 0.1283 | 1 | 1 | 1 |  |  |
| elevation_m | (3.9,5.9] | 0.1264 | 0.9635 | 0.9282 | 0.8944 | 0.4067 | 0.0362 |
| elevation_m | (5.9,8.1] | 0.1198 | 0.9666 | 0.9413 | 0.9099 | 0.4618 | 0.1002 |
| elevation_m | (8.1,11] | 0.1275 | 0.9567 | 0.8762 | 0.8382 | 0.3377 | 0.0003 |
| elevation_m | (11,15] | 0.1240 | 0.9147 | 0.8965 | 0.8201 | 0.0601 | 0.0037 |
| elevation_m | (15,21.9] | 0.1234 | 1.0032 | 0.9080 | 0.9109 | 0.9462 | 0.0103 |
| elevation_m | (21.9, Inf] | 0.1247 | 0.9534 | 0.9328 | 0.8893 | 0.3441 | 0.0840 |
| distance_to_river_km | (-Inf,0.52] | 0.1241 | 1 | 1 | 1 |  |  |
| distance_to_river_km | (0.52,1.04] | 0.1213 | 1.0153 | 0.9715 | 0.9864 | 0.7469 | 0.4379 |
| distance_to_river_km | (1.04,1.65] | 0.1213 | 0.9726 | 0.9372 | 0.9115 | 0.5878 | 0.1119 |
| distance_to_river_km | (1.65,2.37] | 0.1224 | 1.0904 | 0.9432 | 1.0285 | 0.0947 | 0.1596 |
| distance_to_river_km | (2.37,3.25] | 0.1208 | 1.0167 | 1.0062 | 1.0230 | 0.7570 | 0.8859 |
| distance_to_river_km | (3.25,4.43] | 0.1223 | 0.9976 | 0.9498 | 0.9475 | 0.9651 | 0.2345 |
| distance_to_river_km | (4.43,6.29] | 0.1216 | 0.9611 | 0.9378 | 0.9013 | 0.4717 | 0.1422 |
| distance_to_river_km | (6.29, Inf] | 0.1214 | 0.9200 | 0.9393 | 0.8641 | 0.1346 | 0.1579 |
| distance_to_river_km | missing | 0.0247 | 1.1036 | 1.0660 | 1.1764 | 0.2048 | 0.3083 |
| sum_insured | (-Inf,2.01e+04] | 0.1277 | 1 | 1 | 1 |  |  |
| sum_insured | (2.01e+04,2.65e+04] | 0.1242 | 1.0780 | 1.2207 | 1.3160 | 0.1121 | 0.0000 |
| sum_insured | (2.65e+04,3.27e+04] | 0.1264 | 1.1775 | 1.3571 | 1.5980 | 0.0007 | 0 |
| sum_insured | (3.27e+04,3.89e+04] | 0.1247 | 1.2200 | 1.5634 | 1.9074 | 0.0001 | 0 |
| sum_insured | (3.89e+04,4.58e+04] | 0.1244 | 1.2121 | 1.7040 | 2.0655 | 0.0002 | 0 |
| sum_insured | (4.58e+04,5.45e+04] | 0.1261 | 1.2333 | 2.0354 | 2.5103 | 0.0001 | 0 |
| sum_insured | (5.45e+04,6.77e+04] | 0.1237 | 1.2725 | 2.1587 | 2.7469 | 0.0000 | 0 |
| sum_insured | (6.77e+04, Inf] | 0.1227 | 1.3110 | 2.5646 | 3.3623 | 0.0000 | 0 |
| tenure | owner | 0.6999 | 1 | 1 | 1 |  |  |
| tenure | renter | 0.3001 | 1.0718 | 0.9985 | 1.0703 | 0.0342 | 0.9555 |
| region | R01 | 0.1632 | 1 | 1 | 1 |  |  |
| region | R02 | 0.0629 | 1.1058 | 0.9883 | 1.0928 | 0.0620 | 0.7808 |
| region | R03 | 0.0973 | 1.4033 | 0.9551 | 1.3402 | 0 | 0.1878 |
| region | R04 | 0.0583 | 1.1265 | 0.9354 | 1.0538 | 0.0304 | 0.1265 |
| region | R05 | 0.0797 | 0.9054 | 1.0122 | 0.9165 | 0.0621 | 0.7708 |
| region | R06 | 0.0423 | 0.9822 | 0.8872 | 0.8714 | 0.7840 | 0.0227 |
| region | R07 | 0.0718 | 1.5874 | 0.9536 | 1.5137 | 0 | 0.1943 |
| region | R08 | 0.0710 | 0.9496 | 0.9042 | 0.8586 | 0.3461 | 0.0203 |
| region | R09 | 0.0747 | 1.0876 | 0.9613 | 1.0455 | 0.0998 | 0.3397 |
| region | R10 | 0.0940 | 1.0586 | 0.9354 | 0.9902 | 0.2349 | 0.0805 |
| region | R11 | 0.0851 | 1.1061 | 1.0260 | 1.1348 | 0.0542 | 0.5359 |
| region | R12 | 0.0997 | 1.3210 | 0.9192 | 1.2142 | 0 | 0.0165 |
| policyholder_age | (-Inf,24] | 0.1321 | 1 | 1 | 1 |  |  |
| policyholder_age | (24,30] | 0.1147 | 0.8261 | 1.0617 | 0.8771 | 0.0000 | 0.0692 |
| policyholder_age | (30,40] | 0.1298 | 0.6761 | 1.0546 | 0.7131 | 0 | 0.1169 |
| policyholder_age | (40,49] | 0.1164 | 0.5847 | 1.0863 | 0.6351 | 0 | 0.0238 |
| policyholder_age | (49,59] | 0.1285 | 0.5866 | 1.0771 | 0.6319 | 0 | 0.0353 |
| policyholder_age | (59,69] | 0.1279 | 0.6538 | 1.0754 | 0.7030 | 0 | 0.0348 |
| policyholder_age | (69,79] | 0.1290 | 0.7904 | 1.0022 | 0.7922 | 0.0000 | 0.9461 |
| policyholder_age | (79, Inf] | 0.1215 | 0.7669 | 1.0415 | 0.7987 | 0 | 0.2210 |
| prior_claims_5y | 0 | 0.7390 | 1 | 1 | 1 |  |  |
| prior_claims_5y | 1 | 0.2207 | 1.2158 | 1.0103 | 1.2283 | 0 | 0.6206 |
| prior_claims_5y | 2 | 0.0362 | 1.5158 | 1.0070 | 1.5264 | 0 | 0.8652 |
| prior_claims_5y | 3 | 0.0041 | 2.0499 | 1.0997 | 2.2543 | 0.0000 | 0.3462 |
| urban_density | dense_urban | 0.1007 | 1.2082 | 1.1348 | 1.3711 | 0.0000 | 0.0000 |
| urban_density | rural | 0.1990 | 0.9607 | 1.0117 | 0.9719 | 0.1948 | 0.6397 |
| urban_density | suburban | 0.4493 | 1 | 1 | 1 |  |  |
| urban_density | urban | 0.2510 | 1.0619 | 1.0729 | 1.1394 | 0.0305 | 0.0015 |
| missed_payments_12m | 0 | 0.9190 | 1 | 1 | 1 |  |  |
| missed_payments_12m | 1 | 0.0643 | 1.4236 | 1.0556 | 1.5027 | 0 | 0.0918 |
| missed_payments_12m | 2 | 0.0138 | 1.5296 | 1.0007 | 1.5307 | 0.0000 | 0.9912 |
| missed_payments_12m | 3 | 0.0029 | 1.7027 | 1.0802 | 1.8393 | 0.0013 | 0.5681 |
| voluntary_excess | 0 | 0.4995 | 1 | 1 | 1 |  |  |
| voluntary_excess | 250 | 0.2997 | 0.8489 | 1.0994 | 0.9333 | 0 | 0.0000 |
| voluntary_excess | 500 | 0.1508 | 0.6285 | 1.1224 | 0.7054 | 0 | 0.0001 |
| voluntary_excess | 1000 | 0.0500 | 0.5392 | 1.4414 | 0.7772 | 0 | 0 |
| security_level | alarm_and_locks | 0.3401 | 0.9413 | 0.9496 | 0.8939 | 0.0264 | 0.0177 |
| security_level | locks | 0.2926 | 1.0097 | 0.9828 | 0.9923 | 0.7282 | 0.4331 |
| security_level | missing | 0.0251 | 1.0054 | 0.9489 | 0.9540 | 0.9405 | 0.3711 |
| security_level | standard | 0.3422 | 1 | 1 | 1 |  |  |
| high_value_items | 0 | 0.4865 | 1 | 1 | 1 |  |  |
| high_value_items | 1 | 0.1959 | 1.0347 | 1.0204 | 1.0559 | 0.2508 | 0.3935 |
| high_value_items | 2 | 0.1172 | 0.9989 | 1.0922 | 1.0911 | 0.9766 | 0.0024 |
| high_value_items | 3 | 0.0779 | 0.9976 | 1.1323 | 1.1297 | 0.9564 | 0.0003 |
| high_value_items | 4 | 0.0483 | 1.0139 | 1.1238 | 1.1394 | 0.7958 | 0.0051 |
| high_value_items | 5 | 0.0491 | 1.0051 | 1.3092 | 1.3158 | 0.9241 | 0 |
| high_value_items | missing | 0.0250 | 1.0175 | 0.9520 | 0.9686 | 0.8115 | 0.4067 |
| accidental_damage_cover | FALSE | 0.5510 | 1 | 1 | 1 |  |  |
| accidental_damage_cover | TRUE | 0.4490 | 1.9133 | 0.6328 | 1.2107 | 0 | 0 |
| works_from_home | FALSE | 0.7497 | 1 | 1 | 1 |  |  |
| works_from_home | TRUE | 0.2503 | 0.9874 | 0.9940 | 0.9815 | 0.6230 | 0.7754 |
| lodgers | FALSE | 0.9501 | 1 | 1 | 1 |  |  |
| lodgers | TRUE | 0.0499 | 1.1679 | 1.0144 | 1.1847 | 0.0012 | 0.7141 |
| bicycle_cover | FALSE | 0.8508 | 1 | 1 | 1 |  |  |
| bicycle_cover | TRUE | 0.1492 | 1.0449 | 0.9874 | 1.0317 | 0.1545 | 0.6097 |
| property_type | detached | 0.2501 | 0.9747 | 0.9481 | 0.9240 | 0.3940 | 0.0266 |
| property_type | flat | 0.2002 | 0.9098 | 0.9248 | 0.8414 | 0.0040 | 0.0029 |
| property_type | semi_detached | 0.2999 | 1 | 1 | 1 |  |  |
| property_type | terraced | 0.2499 | 0.9909 | 0.9798 | 0.9710 | 0.7608 | 0.3975 |
| household_size | 1 | 0.3589 | 1 | 1 | 1 |  |  |
| household_size | 2 | 0.2698 | 1.0125 | 1.0258 | 1.0387 | 0.6590 | 0.2585 |
| household_size | 3 | 0.1624 | 0.9820 | 0.9977 | 0.9798 | 0.5971 | 0.9321 |
| household_size | 4 | 0.0987 | 0.9749 | 1.0207 | 0.9951 | 0.5406 | 0.5372 |
| household_size | 5 | 0.0515 | 1.0014 | 0.9405 | 0.9418 | 0.9788 | 0.1580 |
| household_size | 6 | 0.0225 | 1.0630 | 1.0411 | 1.1067 | 0.4168 | 0.5216 |
| household_size | 7 | 0.0115 | 0.9603 | 1.0263 | 0.9856 | 0.7140 | 0.7639 |
| household_size | missing | 0.0246 | 0.9967 | 1.0754 | 1.0719 | 0.9637 | 0.2152 |

