# Week 2 developed baseline (C5 engine on shared features)

Run 2026-10-25 22:16:35 SGT, 1 bag(s), workbook `week_2/inputs/assumptions_week2_baseline_pool23.xlsx` (MD5 `0f452b3e539a63860aaa2b0a66c37f9e`). Run time 4.8 min.

Validation skipped.
## Final fit diagnostics

| line | peril | rounds_freq | rounds_sev | sev_type | claims_freq | claims_sev | bal_freq | bal_sev | freq_trend | sev_trend | cap | cap_load | sev_years |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | 651 | 137 | gbm | 49,635 | 49,635 | 0.999 | 1.005 | 0.006 | 0.032 | 19,667.898 | 1.002 | 2021-2024 |
| motor | third_party_prop | 426 | 85 | gbm | 34,082 | 34,082 | 1.000 | 1.000 | 0.004 | 0.073 | 30,448.728 | 1.001 | 2021-2024 |
| motor | bodily_injury | 331 |  | glm | 7,778 | 6,600 | 0.998 | 1.000 | 0 | 0 | 186,221.863 | 1.047 | 2021-2023 |
| motor | theft | 434 |  | glm | 6,313 | 6,313 | 1.002 | 1.000 | 0 | 0.030 | 54,216.591 | 1.002 | 2021-2024 |
| motor | glass_hail | 438 | 50 | gbm | 16,244 | 16,244 | 1.003 | 1.010 | 0 | 0.075 | 9,408.159 | 1.001 | 2021-2024 |
| buildings | storm | 657 | 85 | gbm | 7,972 | 7,972 | 0.996 | 1.007 | 0 | 0.081 | 34,952.943 | 1.002 | 2021-2024 |
| buildings | flood | 378 |  | glm | 2,261 | 2,261 | 0.999 | 0.999 | 0 | 0.067 | 237,992.968 | 1.007 | 2021-2024 |
| buildings | escape_of_water | 558 |  | glm | 10,196 | 10,196 | 1.000 | 1.000 | 0 | 0.083 | 57,149.771 | 1.001 | 2021-2024 |
| buildings | subsidence | 226 |  | glm | 1,320 | 1,029 | 0.992 | 1.000 | 0 | 0.010 | 123,681.854 | 1.005 | 2021-2023 |
| buildings | fire | 203 |  | glm | 1,156 | 1,156 | 1.007 | 1.000 | 0 | -0.020 | 308,110.946 | 1.016 | 2021-2024 |
| buildings | accidental_damage | 183 | 16 | gbm | 3,880 | 3,880 | 0.993 | 0.995 | 0 | 0.020 | 9,463.851 | 1.001 | 2021-2024 |
| contents | theft | 180 |  | glm | 7,814 | 7,814 | 1.002 | 1.000 | 0 | 0.041 | 32,510.059 | 1.003 | 2021-2024 |
| contents | escape_of_water | 203 | 194 | gbm | 5,452 | 5,452 | 1.003 | 1.014 | 0 | 0.024 | 23,797.534 | 1.002 | 2021-2024 |
| contents | accidental_damage | 356 | 44 | gbm | 9,229 | 9,229 | 0.998 | 1.009 | 0 | 0.026 | 6,164.094 | 1.002 | 2021-2024 |
| contents | flood | 221 |  | glm | 1,666 | 1,666 | 0.994 | 0.999 | 0 | 0.054 | 66,230.631 | 1.009 | 2021-2024 |

## Baseline burn (developed level)

| line | peril | developed_test_burn | emerging_train_burn | emerging_test_burn |
|---|---|---|---|---|
| motor | own_damage | 108.94 | 83.66 | 101.96 |
| motor | third_party_prop | 178.96 | 162.60 | 191.41 |
| motor | bodily_injury | 208.32 | 160.74 | 177.35 |
| motor | theft | 48.48 | 37.91 | 39.64 |
| motor | glass_hail | 24.32 | 29.94 | 24.40 |
| buildings | storm | 59.42 | 62.23 | 55.76 |
| buildings | flood | 131.80 | 112.20 | 111.68 |
| buildings | escape_of_water | 123.14 | 60.92 | 72.09 |
| buildings | subsidence | 58.77 | 53.67 | 42.64 |
| buildings | fire | 98.88 | 297.28 | 294.04 |
| buildings | accidental_damage | 8.42 | 7.29 | 7.76 |
| contents | theft | 54.61 | 43.14 | 46.22 |
| contents | escape_of_water | 26.73 | 18.56 | 21.86 |
| contents | accidental_damage | 13.28 | 10.50 | 12.44 |
| contents | flood | 30.69 | 30.35 | 29.54 |

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

