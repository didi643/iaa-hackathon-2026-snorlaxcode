# Week 2 developed baseline (C5 engine on shared features)

Run 2026-10-25 22:21:11 SGT, 1 bag(s), workbook `week_2/inputs/assumptions_week2_baseline_pool24.xlsx` (MD5 `2eef4133dc40f0f978aed2add3fca245`). Run time 4.6 min.

Validation skipped.
## Final fit diagnostics

| line | peril | rounds_freq | rounds_sev | sev_type | claims_freq | claims_sev | bal_freq | bal_sev | freq_trend | sev_trend | cap | cap_load | sev_years |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | 692 | 150 | gbm | 50,930 | 50,930 | 0.999 | 1.003 | 0.006 | 0.019 | 19,231.482 | 1.002 | 2021-2024 |
| motor | third_party_prop | 433 | 33 | gbm | 35,156 | 35,156 | 0.999 | 1.003 | 0.004 | 0.057 | 29,555.987 | 1.001 | 2021-2024 |
| motor | bodily_injury | 271 |  | glm | 7,961 | 6,600 | 0.998 | 1.000 | 0 | 0 | 186,221.863 | 1.047 | 2021-2023 |
| motor | theft | 367 |  | glm | 6,508 | 6,508 | 1.001 | 1.000 | 0 | 0.019 | 52,243.939 | 1.002 | 2021-2024 |
| motor | glass_hail | 366 | 34 | gbm | 16,988 | 16,988 | 1.003 | 1.012 | 0 | 0.057 | 8,843.507 | 1.001 | 2021-2024 |
| buildings | storm | 620 | 84 | gbm | 8,226 | 8,226 | 0.995 | 1.009 | 0 | 0.070 | 34,170.579 | 1.002 | 2021-2024 |
| buildings | flood | 420 |  | glm | 2,299 | 2,299 | 1.003 | 0.999 | 0 | 0.063 | 234,613.691 | 1.007 | 2021-2024 |
| buildings | escape_of_water | 404 |  | glm | 10,333 | 10,333 | 1.001 | 1.000 | 0 | 0.077 | 56,274.725 | 1.001 | 2021-2024 |
| buildings | subsidence | 174 |  | glm | 1,340 | 1,029 | 0.997 | 1.000 | 0 | 0.010 | 123,681.854 | 1.005 | 2021-2023 |
| buildings | fire | 168 |  | glm | 1,177 | 1,177 | 1.013 | 1.001 | 0 | -0.020 | 327,388.970 | 1.012 | 2021-2024 |
| buildings | accidental_damage | 211 | 13 | gbm | 3,947 | 3,947 | 0.994 | 0.997 | 0 | 0.015 | 9,329.032 | 1.001 | 2021-2024 |
| contents | theft | 189 |  | glm | 8,032 | 8,032 | 1.002 | 1.001 | 0 | 0.035 | 32,228.111 | 1.003 | 2021-2024 |
| contents | escape_of_water | 247 | 148 | gbm | 5,537 | 5,537 | 1.003 | 1.015 | 0 | 0.019 | 23,285.664 | 1.002 | 2021-2024 |
| contents | accidental_damage | 347 | 25 | gbm | 9,398 | 9,398 | 0.999 | 1.009 | 0 | 0.021 | 6,144.762 | 1.002 | 2021-2024 |
| contents | flood | 285 |  | glm | 1,701 | 1,701 | 0.994 | 0.999 | 0 | 0.053 | 65,569.351 | 1.009 | 2021-2024 |

## Baseline burn (developed level)

| line | peril | developed_test_burn | emerging_train_burn | emerging_test_burn |
|---|---|---|---|---|
| motor | own_damage | 105.99 | 80.87 | 96.47 |
| motor | third_party_prop | 171.87 | 173.32 | 208.03 |
| motor | bodily_injury | 208.94 | 167.36 | 183.02 |
| motor | theft | 47.20 | 40.80 | 41.51 |
| motor | glass_hail | 23.32 | 30.84 | 25.69 |
| buildings | storm | 57.75 | 59.62 | 52.62 |
| buildings | flood | 130.26 | 108.01 | 112.92 |
| buildings | escape_of_water | 121.78 | 55.98 | 65.75 |
| buildings | subsidence | 58.88 | 48.51 | 41.19 |
| buildings | fire | 97.38 | 179.80 | 184.12 |
| buildings | accidental_damage | 8.27 | 7.14 | 7.48 |
| contents | theft | 53.80 | 43.59 | 47.66 |
| contents | escape_of_water | 26.39 | 14.81 | 17.52 |
| contents | accidental_damage | 13.03 | 9.26 | 11.27 |
| contents | flood | 30.49 | 29.96 | 29.42 |

## Workbook edits

| sheet | column | edit |
|---|---|---|
| Features_Motor | driver_age | renamed to driver_age_band (category, no monotone constraint) |
| Features_Motor | annual_mileage | use Y -> N (not shared / excluded) |
| Features_Motor | telematics_opt_in | use Y -> N (not shared / excluded) |
| Features_Motor | telematics_score | use Y -> N (not shared / excluded) |
| Features_Motor | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Motor | credit_band | use Y -> N (not shared / excluded) |
| Features_Motor | region | use Y -> N (not shared / excluded) |
| Features_Buildings | policyholder_age | renamed to policyholder_age_band (category, no monotone constraint) |
| Features_Buildings | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Buildings | credit_band | use Y -> N (not shared / excluded) |
| Features_Buildings | region | use Y -> N (not shared / excluded) |
| Features_Contents | policyholder_age | renamed to policyholder_age_band (category, no monotone constraint) |
| Features_Contents | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Contents | credit_band | use Y -> N (not shared / excluded) |
| Features_Contents | region | use Y -> N (not shared / excluded) |
| Settings | bags | 5 -> 1 |
| Settings | model_selection | auto -> freq_sev |
| Settings | method_mix | sheet -> auto |

