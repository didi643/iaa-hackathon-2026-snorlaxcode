# Week 2 developed baseline (C5 engine on shared features)

Run 2026-10-25 22:03:34 SGT, 1 bag(s), workbook `week_2/inputs/assumptions_week2_baseline_loc.xlsx` (MD5 `8c5ea90af2560d273cfc11a986cf88d0`). Run time 6.9 min.

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1031 | 0.0709 | 0.0683 | 0.0462 |
| developed | 2024 | 0.1020 | 0.0716 | 0.0597 | 0.0477 |
| reported_raw | 2023 | 0.0982 | 0.0710 | 0.0682 | 0.0305 |
| reported_raw | 2024 | 0.0942 | 0.0737 | 0.0596 | 0.0390 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0347 | 0.0305 | 0.0390 |
| reported_raw | buildings | 0.0724 | 0.0710 | 0.0737 |
| reported_raw | contents | 0.0639 | 0.0682 | 0.0596 |
| reported_raw | ALL | 0.0962 | 0.0982 | 0.0942 |
| developed | motor | 0.0470 | 0.0462 | 0.0477 |
| developed | buildings | 0.0712 | 0.0709 | 0.0716 |
| developed | contents | 0.0640 | 0.0683 | 0.0597 |
| developed | ALL | 0.1025 | 0.1031 | 0.1020 |

Week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW): ALL reported_raw mean 0.1026. Shared features, 1 bag, freq x sev: 0.0962.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1371 | 0.1377 |
| buildings | escape_of_water | 0.0377 | 0.0375 |
| buildings | fire | 0.0197 | 0.0198 |
| buildings | flood | 0.4495 | 0.4495 |
| buildings | storm | 0.0613 | 0.0611 |
| buildings | subsidence | 0.0729 | 0.0715 |
| contents | accidental_damage | 0.1387 | 0.1387 |
| contents | escape_of_water | 0.0324 | 0.0321 |
| contents | flood | 0.4259 | 0.4263 |
| contents | theft | 0.0335 | 0.0337 |
| motor | bodily_injury | 0.0405 | 0.0096 |
| motor | glass_hail | 0.1336 | 0.1334 |
| motor | own_damage | 0.1589 | 0.1589 |
| motor | theft | 0.0769 | 0.0769 |
| motor | third_party_prop | 0.0509 | 0.0500 |

## Final fit diagnostics

| line | peril | rounds_freq | rounds_sev | sev_type | claims_freq | claims_sev | bal_freq | bal_sev | freq_trend | sev_trend | cap | cap_load | sev_years |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | 966 | 162 | gbm | 48,258 | 48,258 | 0.999 | 1.003 | 0.000 | 0.037 | 19,895.123 | 1.003 | 2021-2024 |
| motor | third_party_prop | 404 | 20 | gbm | 32,963 | 32,963 | 0.999 | 0.999 | 0.002 | 0.078 | 30,908.206 | 1.001 | 2021-2024 |
| motor | bodily_injury | 257 |  | glm | 7,512 | 6,334 | 0.996 | 1.000 | 0 | 0 | 187,505.674 | 1.048 | 2021-2023 |
| motor | theft | 537 |  | glm | 6,119 | 6,119 | 1.001 | 1.000 | 0 | 0.035 | 55,461.559 | 1.002 | 2021-2024 |
| motor | glass_hail | 536 | 45 | gbm | 15,643 | 15,643 | 0.998 | 1.009 | 0 | 0.080 | 9,592.568 | 1.001 | 2021-2024 |
| buildings | storm | 600 | 117 | gbm | 7,762 | 7,762 | 0.996 | 1.006 | 0 | 0.084 | 35,330.142 | 1.002 | 2021-2024 |
| buildings | flood | 323 |  | glm | 2,219 | 2,219 | 1.004 | 0.999 | 0 | 0.069 | 241,227.874 | 1.007 | 2021-2024 |
| buildings | escape_of_water | 478 |  | glm | 10,065 | 10,065 | 1.002 | 1.000 | 0 | 0.085 | 57,351.841 | 1.001 | 2021-2024 |
| buildings | subsidence | 62 |  | glm | 1,288 | 997 | 0.994 | 1.000 | 0 | 0.023 | 129,204.618 | 1.005 | 2021-2023 |
| buildings | fire | 182 |  | glm | 1,107 | 1,107 | 1.008 | 1.000 | 0 | -0.020 | 293,015.565 | 1.019 | 2021-2024 |
| buildings | accidental_damage | 192 | 16 | gbm | 3,825 | 3,825 | 0.991 | 0.998 | 0 | 0.022 | 9,514.428 | 1.001 | 2021-2024 |
| contents | theft | 207 |  | glm | 7,626 | 7,626 | 1.001 | 1.000 | 0 | 0.043 | 32,660.961 | 1.003 | 2021-2024 |
| contents | escape_of_water | 243 | 184 | gbm | 5,366 | 5,366 | 1.002 | 1.017 | 0 | 0.026 | 23,973.187 | 1.002 | 2021-2024 |
| contents | accidental_damage | 277 | 45 | gbm | 9,063 | 9,063 | 0.998 | 1.009 | 0 | 0.028 | 6,196.545 | 1.002 | 2021-2024 |
| contents | flood | 245 |  | glm | 1,615 | 1,615 | 1.000 | 0.999 | 0 | 0.056 | 67,334.539 | 1.009 | 2021-2024 |

## Baseline burn (developed level)

| line | peril | developed_test_burn | emerging_train_burn | emerging_test_burn |
|---|---|---|---|---|
| motor | own_damage | 108.83 | 109.83 | 123.91 |
| motor | third_party_prop | 180.48 | 201.39 | 237.46 |
| motor | bodily_injury | 209.35 | 247.26 | 270.26 |
| motor | theft | 49.04 | 47.80 | 49.48 |
| motor | glass_hail | 25.00 | 35.69 | 32.87 |
| buildings | storm | 60.19 | 60.69 | 61.11 |
| buildings | flood | 132.56 | 172.29 | 172.02 |
| buildings | escape_of_water | 124.38 | 99.45 | 118.69 |
| buildings | subsidence | 60.76 | 61.60 | 53.13 |
| buildings | fire | 98.76 | 141.36 | 138.56 |
| buildings | accidental_damage | 8.50 | 8.26 | 8.72 |
| contents | theft | 55.06 | 50.52 | 54.76 |
| contents | escape_of_water | 26.89 | 19.20 | 22.37 |
| contents | accidental_damage | 13.30 | 12.61 | 14.64 |
| contents | flood | 30.84 | 36.61 | 35.41 |

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

