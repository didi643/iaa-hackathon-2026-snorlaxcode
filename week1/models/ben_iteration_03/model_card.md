# BEN 3 - frequency x severity per peril, model form chosen per peril

**Run id** `20261022_2141` | **Generated** 2026-10-22 22:25 | **Git commit** `a6fbbf1 + uncommitted changes in R/` | **Submission file** `submission_20261022_2141_ben03.csv` | **MD5** `770be3bd72bb06dd57467466444536f5` | **Replication check** passed

> **Warning:** generated from uncommitted code.

**Change:** Frequency x severity per peril with the model form chosen per peril (GLM or GLM level + XGBoost shape; severity GLM with factors or trend only); per-row chain-ladder IBNR as effective exposure; expected recoveries on open claims; claims history as at 1 January; previous-row and holdings features.

## Local validation vs SAM 3 (same folds, same actuals as reported, same D2)
SAM 3 = its submitted blend (`models/sam_iteration_03/validation_*.csv`). Both choose their components on these folds.

| valid_year | line | ben3_d2 | ben3_d2_cal | ben3_gini | ben3_ae_reported | sam3_d2 | sam3_d2_cal | sam3_gini | sam3_ae_reported | d2_diff |
|---|---|---|---|---|---|---|---|---|---|---|
| 2023 | motor | 0.0492 | 0.0492 | 0.4035 | 1.0174 | 0.0428 | 0.0431 | 0.3831 | 0.9708 | 0.0064 |
| 2023 | buildings | 0.0693 | 0.0693 | 0.4570 | 0.9547 | 0.0714 | 0.0714 | 0.4594 | 0.9984 | -0.0021 |
| 2023 | contents | 0.0703 | 0.0714 | 0.4498 | 0.9226 | 0.0710 | 0.0719 | 0.4490 | 0.9243 | -0.0006 |
| 2023 | ALL | 0.1065 | 0.1065 | 0.5220 | 0.9887 | 0.1043 |  | 0.5149 |  | 0.0021 |
| 2024 | motor | 0.0506 | 0.0568 | 0.3992 | 1.2301 | 0.0465 | 0.0579 | 0.3999 | 1.3181 | 0.0040 |
| 2024 | buildings | 0.0700 | 0.0699 | 0.4580 | 0.9896 | 0.0748 | 0.0752 | 0.4672 | 1.0279 | -0.0048 |
| 2024 | contents | 0.0633 | 0.0632 | 0.4369 | 1.0402 | 0.0642 | 0.0642 | 0.4382 | 1.0405 | -0.0009 |
| 2024 | ALL | 0.0985 | 0.1000 | 0.4972 | 1.1188 | 0.0986 |  | 0.5004 |  | -0.0001 |

A/E against developed actuals (per-row chain ladder, after expected recoveries):

| valid_year | line | ae_reported | ae_developed | d2_cal | gini |
|---|---|---|---|---|---|
| 2023 | motor | 1.017 | 0.985 | 0.049 | 0.403 |
| 2023 | buildings | 0.955 | 0.951 | 0.069 | 0.457 |
| 2023 | contents | 0.923 | 0.921 | 0.071 | 0.450 |
| 2024 | motor | 1.230 | 1.023 | 0.057 | 0.399 |
| 2024 | buildings | 0.990 | 0.904 | 0.070 | 0.458 |
| 2024 | contents | 1.040 | 1.008 | 0.063 | 0.437 |
| 2023 | ALL | 0.989 | 0.969 | 0.106 | 0.522 |
| 2024 | ALL | 1.119 | 0.978 | 0.100 | 0.497 |

## Model form per peril
Candidates: frequency GLM alone or GLM level + XGBoost Poisson shape; severity GLM with factors or trend only. Score = mean
D2 against the peril's developed cost over 2023 and 2024.

| line | peril | glm_x_sevfactors | glm_x_sevtrend | tree_x_sevfactors | tree_x_sevtrend | chosen |
|---|---|---|---|---|---|---|
| buildings | accidental_damage | 0.1324 | 0.1336 | 0.1346 | 0.1349 | tree_x_sevtrend |
| buildings | escape_of_water | 0.0335 | 0.0271 | 0.0395 | 0.0323 | tree_x_sevfactors |
| buildings | fire | 0.0172 | 0.0074 | 0.0138 | 0.0032 | glm_x_sevfactors |
| buildings | flood | 0.4471 | 0.4461 | 0.4395 | 0.4380 | glm_x_sevfactors |
| buildings | storm | 0.0532 | 0.0477 | 0.0552 | 0.0486 | tree_x_sevfactors |
| buildings | subsidence | 0.0423 | 0.0435 | 0.0721 | 0.0752 | tree_x_sevtrend |
| contents | accidental_damage | 0.1411 | 0.1392 | 0.1411 | 0.1395 | tree_x_sevfactors |
| contents | escape_of_water | 0.0353 | 0.0226 | 0.0382 | 0.0239 | tree_x_sevfactors |
| contents | flood | 0.4268 | 0.4166 | 0.4286 | 0.4183 | tree_x_sevfactors |
| contents | theft | 0.0316 | 0.0128 | 0.0286 | 0.0093 | glm_x_sevfactors |
| motor | bodily_injury | 0.0563 | 0.0599 | 0.0446 | 0.0492 | glm_x_sevtrend |
| motor | glass_hail | 0.1431 | 0.1417 | 0.1349 | 0.1332 | glm_x_sevfactors |
| motor | own_damage | 0.1680 | 0.1577 | 0.1687 | 0.1594 | tree_x_sevfactors |
| motor | theft | 0.0783 | 0.0728 | 0.0704 | 0.0643 | glm_x_sevfactors |
| motor | third_party_prop | 0.0562 | 0.0565 | 0.0592 | 0.0599 | tree_x_sevtrend |

## Final models (fit 2021-24)
| line | peril | form | claims | cap | loading | freq_trend | sev_trend | tree_rounds |
|---|---|---|---|---|---|---|---|---|
| motor | own_damage | tree_x_sevfactors | 48,258 | 12,953.445 | 1.010 | -0.019 | 0.064 | 944 |
| motor | third_party_prop | tree_x_sevtrend | 32,963 | 19,749.538 | 1.006 | -0.030 | 0.076 | 749 |
| motor | bodily_injury | glm_x_sevtrend | 7,512 | 187,516.024 | 1.115 | 0.005 | -0.078 |  |
| motor | theft | glm_x_sevfactors | 6,119 | 38,269.990 | 1.006 | 0.009 | 0.062 |  |
| motor | glass_hail | glm_x_sevfactors | 15,643 | 5,873.072 | 1.006 | 0.020 | 0.080 |  |
| buildings | storm | tree_x_sevfactors | 7,762 | 19,764.172 | 1.009 | 0.002 | 0.067 | 688 |
| buildings | flood | glm_x_sevfactors | 2,219 | 208,045.474 | 1.008 | -0.008 | 0.048 |  |
| buildings | escape_of_water | tree_x_sevfactors | 10,065 | 34,856.354 | 1.007 | 0.020 | 0.069 | 969 |
| buildings | subsidence | tree_x_sevtrend | 1,288 | 138,263.216 | 1.005 | 0.035 | 0.061 | 369 |
| buildings | fire | glm_x_sevfactors | 1,107 | 369,276.900 | 1.008 | 0.059 | -0.051 |  |
| buildings | accidental_damage | tree_x_sevtrend | 3,825 | 6,560.715 | 1.006 | 0.011 | 0.023 | 534 |
| contents | theft | glm_x_sevfactors | 7,626 | 23,478.005 | 1.008 | 0.015 | 0.031 |  |
| contents | escape_of_water | tree_x_sevfactors | 5,366 | 16,952.690 | 1.008 | 0.017 | 0.016 | 284 |
| contents | accidental_damage | tree_x_sevfactors | 9,063 | 4,821.239 | 1.004 | 0.020 | 0.025 | 487 |
| contents | flood | tree_x_sevfactors | 1,615 | 60,320.197 | 1.009 | 0.010 | 0.057 | 422 |

Factors in each GLM:

| line | peril | freq_factors | sev_factors |
|---|---|---|---|
| motor | own_damage | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n, n_lines, hist_pol_n_own_damage | vehicle_value_group, vehicle_age, region, driver_age, voluntary_excess, urban_density |
| motor | third_party_prop | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n, n_lines, hist_pol_n_third_party_prop |  |
| motor | bodily_injury | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n, n_lines, hist_pol_n_bodily_injury |  |
| motor | theft | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n, n_lines, hist_pol_n_theft | vehicle_value_group, cover_type, vehicle_age, region, driver_age, voluntary_excess, urban_density |
| motor | glass_hail | driver_age, ncb_years, years_licensed, vehicle_value_group, vehicle_age, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, fuel_type, body_type, telematics_opt_in, prior_claims_5y, licence_points, credit_band, region, urban_density, voluntary_excess, new_business, payment_method, missed_payments_12m, hail_days, hist_pol_n, hist_cust_other_n, n_lines, hist_pol_n_glass_hail | vehicle_value_group, vehicle_age, region, driver_age, voluntary_excess, urban_density |
| buildings | storm | flood_zone, elevation_m, distance_to_river_km, sum_insured, bedrooms, property_age, property_type, construction_type, occupancy, prior_claims_5y, missed_payments_12m, region, urban_density, soil_type, trees_within_5m, roof_type, basement, listed_building, accidental_damage_cover, days_unoccupied, voluntary_excess, wind_exposure_index, hail_days, dry_summer_index, rainfall_mm, freezing_days, hist_pol_n, hist_addr_flood, hist_addr_water, hist_addr_subs, hist_addr_storm, n_lines, hist_pol_n_storm | sum_insured, property_type, region, flood_zone, property_age, accidental_damage_cover |
| buildings | flood | flood_zone, elevation_m, distance_to_river_km, basement, sum_insured, region, rainfall_mm, hist_addr_flood, hist_pol_n_flood | sum_insured, property_type, region, flood_zone, property_age, accidental_damage_cover |
| buildings | escape_of_water | flood_zone, elevation_m, distance_to_river_km, sum_insured, bedrooms, property_age, property_type, construction_type, occupancy, prior_claims_5y, missed_payments_12m, region, urban_density, soil_type, trees_within_5m, roof_type, basement, listed_building, accidental_damage_cover, days_unoccupied, voluntary_excess, wind_exposure_index, hail_days, dry_summer_index, rainfall_mm, freezing_days, hist_pol_n, hist_addr_flood, hist_addr_water, hist_addr_subs, hist_addr_storm, n_lines, hist_pol_n_escape_of_water | sum_insured, property_type, region, flood_zone, property_age, accidental_damage_cover |
| buildings | subsidence | soil_type, trees_within_5m, dry_summer_index, property_age, sum_insured, region, hist_addr_subs, hist_pol_n_subsidence |  |
| buildings | fire | sum_insured, property_type, construction_type, occupancy, smoke_alarms, region, urban_density, listed_building, prior_claims_5y, hist_pol_n, hist_pol_n_fire | sum_insured, property_type, region, flood_zone, property_age, accidental_damage_cover |
| buildings | accidental_damage | flood_zone, elevation_m, distance_to_river_km, sum_insured, bedrooms, property_age, property_type, construction_type, occupancy, prior_claims_5y, missed_payments_12m, region, urban_density, soil_type, trees_within_5m, roof_type, basement, listed_building, accidental_damage_cover, days_unoccupied, voluntary_excess, wind_exposure_index, hail_days, dry_summer_index, rainfall_mm, freezing_days, hist_pol_n, hist_addr_flood, hist_addr_water, hist_addr_subs, hist_addr_storm, n_lines, hist_pol_n_accidental_damage |  |
| contents | theft | flood_zone, elevation_m, distance_to_river_km, sum_insured, tenure, region, policyholder_age, prior_claims_5y, urban_density, missed_payments_12m, voluntary_excess, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, property_type, household_size, hist_pol_n, hist_cust_other_n, hist_addr_flood, hist_addr_water, n_lines, hist_pol_n_theft | sum_insured, high_value_items, region, tenure, accidental_damage_cover |
| contents | escape_of_water | flood_zone, elevation_m, distance_to_river_km, sum_insured, tenure, region, policyholder_age, prior_claims_5y, urban_density, missed_payments_12m, voluntary_excess, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, property_type, household_size, hist_pol_n, hist_cust_other_n, hist_addr_flood, hist_addr_water, n_lines, hist_pol_n_escape_of_water | sum_insured, high_value_items, region, tenure, accidental_damage_cover |
| contents | accidental_damage | flood_zone, elevation_m, distance_to_river_km, sum_insured, tenure, region, policyholder_age, prior_claims_5y, urban_density, missed_payments_12m, voluntary_excess, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, property_type, household_size, hist_pol_n, hist_cust_other_n, hist_addr_flood, hist_addr_water, n_lines, hist_pol_n_accidental_damage | sum_insured, high_value_items, region, tenure, accidental_damage_cover |
| contents | flood | flood_zone, elevation_m, distance_to_river_km, property_type, sum_insured, region, rainfall_mm, hist_addr_flood, hist_pol_n_flood | sum_insured, high_value_items, region, tenure, accidental_damage_cover |

## 2025 predictions
| line | test_exposure | predicted_total | predicted_burn_cost | p50_row | p90_row | p99_row | max_row |
|---|---|---|---|---|---|---|---|
| motor | 199,983.58 | 109,833,681.10 | 549.21 | 359.56 | 813.34 | 1,725.33 | 6,735.43 |
| buildings | 150,243.90 | 74,799,774.87 | 497.86 | 323.97 | 703.54 | 2,140.44 | 8,842.81 |
| contents | 150,123.77 | 19,256,897.37 | 128.27 | 79.25 | 188.69 | 556.50 | 3,414.29 |

Cost per exposure-year against earlier submissions and the level anchor from `R/ben/ben3_study.R`:

| source | public | motor | buildings | contents |
|---|---|---|---|---|
| BEN 1/2 | 0.1 | 505.5 | 456.4 | 122.4 |
| WENDY 4 | 0.1 | 521.2 | 482.4 | 125 |
| WENDY 5 | 0.1 | 545.1 | 475.4 | 125.4 |
| SAM 3 | 0.1 | 603.3 | 487.4 | 125.2 |
| Level anchor (ben3_study) |  | 548 | 489 | 128 |
| BEN 3 |  | 549.2 | 497.9 | 128.3 |

By peril:

| peril | buildings | contents | motor |
|---|---|---|---|
| accidental_damage | 8.87 | 13.85 |  |
| bodily_injury |  |  | 183.07 |
| escape_of_water | 123.67 | 28.41 |  |
| fire | 102.69 |  |  |
| flood | 129.21 | 30.90 |  |
| glass_hail |  |  | 26.50 |
| own_damage |  |  | 114.86 |
| storm | 59.93 |  |  |
| subsidence | 73.48 |  |  |
| theft |  | 55.11 | 53.48 |
| third_party_prop |  |  | 171.30 |

Motor rates by cover type (glass and theft should be near zero where not covered):

| cover_type | rows | glass_hail_rate | theft_rate |
|---|---|---|---|
| 1 | 23,728 | 0.000 | 0.000 |
| 2 | 23,729 | 0.000 | 54.260 |
| 3 | 207,529 | 32.908 | 61.377 |

## Tree importance (top 5 per peril with a tree)
| line | peril | rank | Feature | Gain |
|---|---|---|---|---|
| motor | own_damage | 1 | cover_type | 0.418 |
| motor | own_damage | 2 | ncb_years | 0.141 |
| motor | own_damage | 3 | driver_age | 0.103 |
| motor | own_damage | 4 | customer_age | 0.046 |
| motor | own_damage | 5 | years_licensed | 0.042 |
| motor | third_party_prop | 1 | ncb_years | 0.204 |
| motor | third_party_prop | 2 | driver_age | 0.167 |
| motor | third_party_prop | 3 | customer_age | 0.154 |
| motor | third_party_prop | 4 | annual_mileage | 0.071 |
| motor | third_party_prop | 5 | years_licensed | 0.055 |
| buildings | storm | 1 | property_age | 0.210 |
| buildings | storm | 2 | property_type | 0.174 |
| buildings | storm | 3 | wind_exposure_index | 0.075 |
| buildings | storm | 4 | year_built | 0.054 |
| buildings | storm | 5 | wx_avg_wind_exposure_index | 0.038 |
| buildings | escape_of_water | 1 | property_age | 0.147 |
| buildings | escape_of_water | 2 | freezing_days | 0.084 |
| buildings | escape_of_water | 3 | days_unoccupied | 0.079 |
| buildings | escape_of_water | 4 | year_built | 0.079 |
| buildings | escape_of_water | 5 | region | 0.061 |
| buildings | subsidence | 1 | soil_type | 0.232 |
| buildings | subsidence | 2 | dry_summer_index | 0.170 |
| buildings | subsidence | 3 | mean_temperature_c | 0.091 |
| buildings | subsidence | 4 | subsidence_score | 0.088 |
| buildings | subsidence | 5 | wx_avg_mean_temperature_c | 0.030 |
| buildings | accidental_damage | 1 | accidental_damage_cover | 0.704 |
| buildings | accidental_damage | 2 | voluntary_excess | 0.040 |
| buildings | accidental_damage | 3 | year_built | 0.023 |
| buildings | accidental_damage | 4 | prior_claims_5y | 0.023 |
| buildings | accidental_damage | 5 | property_age | 0.019 |
| contents | escape_of_water | 1 | freezing_days | 0.085 |
| contents | escape_of_water | 2 | customer_age | 0.067 |
| contents | escape_of_water | 3 | prior_claims_5y | 0.056 |
| contents | escape_of_water | 4 | wx_avg_mean_temperature_c | 0.049 |
| contents | escape_of_water | 5 | policyholder_age | 0.046 |
| contents | accidental_damage | 1 | accidental_damage_cover | 0.650 |
| contents | accidental_damage | 2 | voluntary_excess | 0.081 |
| contents | accidental_damage | 3 | customer_age | 0.024 |
| contents | accidental_damage | 4 | policyholder_age | 0.021 |
| contents | accidental_damage | 5 | region | 0.018 |
| contents | flood | 1 | flood_score | 0.470 |
| contents | flood | 2 | flood_zone | 0.189 |
| contents | flood | 3 | elevation_m | 0.155 |
| contents | flood | 4 | distance_to_river_km | 0.041 |
| contents | flood | 5 | property_type | 0.014 |

## Replication
| line | rows | max_abs_diff |
|---|---|---|
| motor | 254,986 | 0 |
| buildings | 184,155 | 0 |
| contents | 187,498 | 0 |

