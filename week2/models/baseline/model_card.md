# Week 2 developed baseline (C5 engine on shared features)

Run 2026-10-27 12:54:43 SGT, 5 bag(s), workbook `week2/inputs/assumptions_week2_baseline.xlsx` (MD5 `563edbb102d821c73bed7727a72eb103`). Run time 41.4 min.

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1041 | 0.0716 | 0.0693 | 0.0475 |
| developed | 2024 | 0.1018 | 0.0722 | 0.0599 | 0.0468 |
| reported_raw | 2023 | 0.1016 | 0.0718 | 0.0693 | 0.0371 |
| reported_raw | 2024 | 0.0939 | 0.0740 | 0.0598 | 0.0381 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0376 | 0.0371 | 0.0381 |
| reported_raw | buildings | 0.0729 | 0.0718 | 0.0740 |
| reported_raw | contents | 0.0645 | 0.0693 | 0.0598 |
| reported_raw | ALL | 0.0978 | 0.1016 | 0.0939 |
| developed | motor | 0.0472 | 0.0475 | 0.0468 |
| developed | buildings | 0.0719 | 0.0716 | 0.0722 |
| developed | contents | 0.0646 | 0.0693 | 0.0599 |
| developed | ALL | 0.1030 | 0.1041 | 0.1018 |

Week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW): ALL reported_raw mean 0.1026. Shared features, 1 bag, freq x sev: 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1377 | 0.1383 |
| buildings | escape_of_water | 0.0387 | 0.0385 |
| buildings | fire | 0.0230 | 0.0231 |
| buildings | flood | 0.4526 | 0.4525 |
| buildings | storm | 0.0612 | 0.0609 |
| buildings | subsidence | 0.0738 | 0.0723 |
| contents | accidental_damage | 0.1408 | 0.1408 |
| contents | escape_of_water | 0.0347 | 0.0343 |
| contents | flood | 0.4248 | 0.4251 |
| contents | theft | 0.0338 | 0.0340 |
| motor | bodily_injury | 0.0418 | 0.0155 |
| motor | glass_hail | 0.1339 | 0.1337 |
| motor | own_damage | 0.1588 | 0.1588 |
| motor | theft | 0.0784 | 0.0784 |
| motor | third_party_prop | 0.0510 | 0.0501 |

## Final fit diagnostics

| line | peril | rounds_freq | rounds_sev | sev_type | claims_freq | claims_sev | bal_freq | bal_sev | freq_trend | sev_trend | cap | cap_load | sev_years |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | 547 | 95 | gbm | 48,258 | 48,258 | 0.999 | 1.008 | 0.005 | 0.037 | 19,895.123 | 1.003 | 2021-2024 |
| motor | third_party_prop | 398 | 16 | gbm | 32,963 | 32,963 | 1.000 | 1.000 | 0.000 | 0.078 | 30,908.206 | 1.001 | 2021-2024 |
| motor | bodily_injury | 307 |  | glm | 7,512 | 6,334 | 1.000 | 1.000 | 0 | 0 | 187,505.674 | 1.048 | 2021-2023 |
| motor | theft | 389 |  | glm | 6,119 | 6,119 | 1.000 | 1.000 | 0 | 0.035 | 55,461.559 | 1.002 | 2021-2024 |
| motor | glass_hail | 259 | 45 | gbm | 15,643 | 15,643 | 0.999 | 1.007 | 0 | 0.080 | 9,592.568 | 1.001 | 2021-2024 |
| buildings | storm | 618 | 83 | gbm | 7,762 | 7,762 | 0.999 | 1.009 | 0 | 0.084 | 35,330.142 | 1.002 | 2021-2024 |
| buildings | flood | 337 |  | glm | 2,219 | 2,219 | 0.997 | 0.999 | 0 | 0.069 | 241,227.874 | 1.007 | 2021-2024 |
| buildings | escape_of_water | 445 |  | glm | 10,065 | 10,065 | 1.004 | 1.000 | 0 | 0.085 | 57,351.841 | 1.001 | 2021-2024 |
| buildings | subsidence | 62 |  | glm | 1,288 | 997 | 1.001 | 1.000 | 0 | 0.023 | 129,204.618 | 1.005 | 2021-2023 |
| buildings | fire | 197 |  | glm | 1,107 | 1,107 | 1.000 | 1.000 | 0 | -0.020 | 293,015.565 | 1.019 | 2021-2024 |
| buildings | accidental_damage | 279 | 8 | gbm | 3,825 | 3,825 | 1.000 | 1.000 | 0 | 0.022 | 9,514.428 | 1.001 | 2021-2024 |
| contents | theft | 204 |  | glm | 7,626 | 7,626 | 1.003 | 1.000 | 0 | 0.043 | 32,660.961 | 1.003 | 2021-2024 |
| contents | escape_of_water | 215 | 156 | gbm | 5,366 | 5,366 | 0.999 | 1.018 | 0 | 0.026 | 23,973.187 | 1.002 | 2021-2024 |
| contents | accidental_damage | 347 | 45 | gbm | 9,063 | 9,063 | 0.999 | 1.006 | 0 | 0.028 | 6,196.545 | 1.002 | 2021-2024 |
| contents | flood | 263 |  | glm | 1,615 | 1,615 | 0.997 | 0.999 | 0 | 0.056 | 67,334.539 | 1.009 | 2021-2024 |

## Baseline burn (developed level)

| line | peril | developed_test_burn | emerging_train_burn | emerging_test_burn |
|---|---|---|---|---|
| motor | own_damage | 110.92 | 111.70 | 129.87 |
| motor | third_party_prop | 179.90 | 214.67 | 254.95 |
| motor | bodily_injury | 208.96 | 267.96 | 296.78 |
| motor | theft | 48.95 | 48.82 | 50.60 |
| motor | glass_hail | 24.76 | 34.19 | 31.14 |
| buildings | storm | 59.55 | 60.15 | 59.67 |
| buildings | flood | 133.62 | 170.31 | 169.56 |
| buildings | escape_of_water | 125.04 | 99.93 | 117.93 |
| buildings | subsidence | 60.69 | 60.52 | 51.90 |
| buildings | fire | 98.79 | 127.56 | 126.51 |
| buildings | accidental_damage | 8.59 | 8.22 | 9.03 |
| contents | theft | 55.00 | 50.57 | 55.37 |
| contents | escape_of_water | 26.58 | 19.11 | 22.31 |
| contents | accidental_damage | 13.34 | 12.53 | 14.66 |
| contents | flood | 30.81 | 35.74 | 34.87 |

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

