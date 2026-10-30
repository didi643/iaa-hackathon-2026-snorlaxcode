# Week 2 developed baseline (C5 engine on shared features)

Run 2026-10-25 22:11:39 SGT, 5 bag(s), workbook `week_2/inputs/assumptions_week2_baseline_b5.xlsx` (MD5 `1ddf03779fbed49be6b46a645362bd55`). Run time 8.1 min.

Validation skipped.
## Final fit diagnostics

| line | peril | rounds_freq | rounds_sev | sev_type | claims_freq | claims_sev | bal_freq | bal_sev | freq_trend | sev_trend | cap | cap_load | sev_years |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | 729 | 162 | gbm | 48,258 | 48,258 | 0.999 | 1.007 | 0.005 | 0.037 | 19,895.123 | 1.003 | 2021-2024 |
| motor | third_party_prop | 391 | 20 | gbm | 32,963 | 32,963 | 1.000 | 1.000 | 0.000 | 0.078 | 30,908.206 | 1.001 | 2021-2024 |
| motor | bodily_injury | 325 |  | glm | 7,512 | 6,334 | 1.000 | 1.000 | 0 | 0 | 187,505.674 | 1.048 | 2021-2023 |
| motor | theft | 363 |  | glm | 6,119 | 6,119 | 1.000 | 1.000 | 0 | 0.035 | 55,461.559 | 1.002 | 2021-2024 |
| motor | glass_hail | 343 | 45 | gbm | 15,643 | 15,643 | 0.999 | 1.006 | 0 | 0.080 | 9,592.568 | 1.001 | 2021-2024 |
| buildings | storm | 600 | 117 | gbm | 7,762 | 7,762 | 0.999 | 1.010 | 0 | 0.084 | 35,330.142 | 1.002 | 2021-2024 |
| buildings | flood | 323 |  | glm | 2,219 | 2,219 | 0.996 | 0.999 | 0 | 0.069 | 241,227.874 | 1.007 | 2021-2024 |
| buildings | escape_of_water | 478 |  | glm | 10,065 | 10,065 | 1.004 | 1.000 | 0 | 0.085 | 57,351.841 | 1.001 | 2021-2024 |
| buildings | subsidence | 62 |  | glm | 1,288 | 997 | 1.001 | 1.000 | 0 | 0.023 | 129,204.618 | 1.005 | 2021-2023 |
| buildings | fire | 182 |  | glm | 1,107 | 1,107 | 1.002 | 1.000 | 0 | -0.020 | 293,015.565 | 1.019 | 2021-2024 |
| buildings | accidental_damage | 192 | 16 | gbm | 3,825 | 3,825 | 0.999 | 1.000 | 0 | 0.022 | 9,514.428 | 1.001 | 2021-2024 |
| contents | theft | 207 |  | glm | 7,626 | 7,626 | 1.003 | 1.000 | 0 | 0.043 | 32,660.961 | 1.003 | 2021-2024 |
| contents | escape_of_water | 243 | 184 | gbm | 5,366 | 5,366 | 0.999 | 1.018 | 0 | 0.026 | 23,973.187 | 1.002 | 2021-2024 |
| contents | accidental_damage | 277 | 45 | gbm | 9,063 | 9,063 | 0.999 | 1.006 | 0 | 0.028 | 6,196.545 | 1.002 | 2021-2024 |
| contents | flood | 245 |  | glm | 1,615 | 1,615 | 0.998 | 0.999 | 0 | 0.056 | 67,334.539 | 1.009 | 2021-2024 |

## Baseline burn (developed level)

| line | peril | developed_test_burn | emerging_train_burn | emerging_test_burn |
|---|---|---|---|---|
| motor | own_damage | 110.75 | 111.80 | 129.84 |
| motor | third_party_prop | 180.00 | 214.79 | 254.74 |
| motor | bodily_injury | 208.89 | 267.75 | 296.82 |
| motor | theft | 48.96 | 48.81 | 50.47 |
| motor | glass_hail | 24.73 | 34.49 | 31.27 |
| buildings | storm | 59.71 | 60.26 | 59.88 |
| buildings | flood | 133.45 | 170.47 | 169.79 |
| buildings | escape_of_water | 125.07 | 99.81 | 118.43 |
| buildings | subsidence | 60.56 | 60.94 | 51.82 |
| buildings | fire | 98.72 | 126.79 | 125.76 |
| buildings | accidental_damage | 8.59 | 8.23 | 9.01 |
| contents | theft | 55.04 | 50.58 | 55.47 |
| contents | escape_of_water | 26.59 | 19.11 | 22.32 |
| contents | accidental_damage | 13.34 | 12.54 | 14.63 |
| contents | flood | 30.83 | 35.58 | 34.81 |

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
| Settings | bags | 5 -> 5 |
| Settings | model_selection | auto -> freq_sev |
| Settings | method_mix | sheet -> auto |

