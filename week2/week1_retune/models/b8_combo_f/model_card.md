# Week 1 re-tune run `b8_combo_f` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 19:44:53 SGT, 5 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b8_combo_f.xlsx` (MD5 `260f73c44a9af4747750bb5168f35060`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 39.2 min.

## Switches

- HP: depth_add=-1, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: TRUE; PROXY: credit; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1042 | 0.0716 | 0.0707 | 0.0473 |
| developed | 2024 | 0.1029 | 0.0728 | 0.0620 | 0.0481 |
| reported_raw | 2023 | 0.1000 | 0.0717 | 0.0707 | 0.0332 |
| reported_raw | 2024 | 0.0951 | 0.0746 | 0.0619 | 0.0395 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0364 | 0.0332 | 0.0395 |
| reported_raw | buildings | 0.0732 | 0.0717 | 0.0746 |
| reported_raw | contents | 0.0663 | 0.0707 | 0.0619 |
| reported_raw | ALL | 0.0976 | 0.1000 | 0.0951 |
| developed | motor | 0.0477 | 0.0473 | 0.0481 |
| developed | buildings | 0.0722 | 0.0716 | 0.0728 |
| developed | contents | 0.0664 | 0.0707 | 0.0620 |
| developed | ALL | 0.1036 | 0.1042 | 0.1029 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1394 | 0.1399 |
| buildings | escape_of_water | 0.0405 | 0.0403 |
| buildings | fire | 0.0215 | 0.0216 |
| buildings | flood | 0.4551 | 0.4550 |
| buildings | storm | 0.0581 | 0.0579 |
| buildings | subsidence | 0.0727 | 0.0706 |
| contents | accidental_damage | 0.1420 | 0.1421 |
| contents | escape_of_water | 0.0378 | 0.0375 |
| contents | flood | 0.4347 | 0.4349 |
| contents | theft | 0.0341 | 0.0343 |
| motor | bodily_injury | 0.0425 | 0.0126 |
| motor | glass_hail | 0.1352 | 0.1350 |
| motor | own_damage | 0.1594 | 0.1593 |
| motor | theft | 0.0779 | 0.0779 |
| motor | third_party_prop | 0.0517 | 0.0508 |

## Final fit diagnostics

| line | peril | rounds_freq | rounds_sev | sev_type | claims_freq | claims_sev | bal_freq | bal_sev | freq_trend | sev_trend | cap | cap_load | sev_years |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | 919 | 249 | gbm | 48,258 | 48,258 | 0.999 | 1.004 | 0.003 | 0.037 | 19,895.123 | 1.003 | 2021-2024 |
| motor | third_party_prop | 626 | 18 | gbm | 32,963 | 32,963 | 1.000 | 1.000 | 0.001 | 0.078 | 30,908.206 | 1.001 | 2021-2024 |
| motor | bodily_injury | 462 |  | glm | 7,512 | 6,334 | 1.001 | 1.000 | 0 | 0 | 187,505.674 | 1.048 | 2021-2023 |
| motor | theft | 983 |  | glm | 6,119 | 6,119 | 0.999 | 1.000 | 0 | 0.035 | 55,461.559 | 1.002 | 2021-2024 |
| motor | glass_hail | 689 | 55 | gbm | 15,643 | 15,643 | 0.999 | 1.004 | 0 | 0.080 | 9,592.568 | 1.001 | 2021-2024 |
| buildings | storm | 672 | 151 | gbm | 7,762 | 7,762 | 0.999 | 1.007 | 0 | 0.084 | 35,330.142 | 1.002 | 2021-2024 |
| buildings | flood | 383 |  | glm | 2,219 | 2,219 | 0.996 | 0.999 | 0 | 0.069 | 241,227.874 | 1.007 | 2021-2024 |
| buildings | escape_of_water | 681 |  | glm | 10,065 | 10,065 | 1.004 | 1.000 | 0 | 0.085 | 57,351.841 | 1.001 | 2021-2024 |
| buildings | subsidence | 332 |  | glm | 1,288 | 997 | 1.002 | 1.000 | 0 | 0.023 | 129,204.618 | 1.005 | 2021-2023 |
| buildings | fire | 355 |  | glm | 1,107 | 1,107 | 0.999 | 1.000 | 0 | -0.020 | 293,015.565 | 1.019 | 2021-2024 |
| buildings | accidental_damage | 312 | 19 | gbm | 3,825 | 3,825 | 0.999 | 1.000 | 0 | 0.022 | 9,514.428 | 1.001 | 2021-2024 |
| contents | theft | 316 |  | glm | 7,626 | 7,626 | 1.003 | 1.000 | 0 | 0.043 | 32,660.961 | 1.003 | 2021-2024 |
| contents | escape_of_water | 380 | 152 | gbm | 5,366 | 5,366 | 0.999 | 1.012 | 0 | 0.026 | 23,973.187 | 1.002 | 2021-2024 |
| contents | accidental_damage | 834 | 34 | gbm | 9,063 | 9,063 | 0.999 | 1.002 | 0 | 0.028 | 6,196.545 | 1.002 | 2021-2024 |
| contents | flood | 304 |  | glm | 1,615 | 1,615 | 0.996 | 0.999 | 0 | 0.056 | 67,334.539 | 1.009 | 2021-2024 |

## Baseline burn (developed level)

| line | peril | developed_test_burn | emerging_train_burn | emerging_test_burn |
|---|---|---|---|---|
| motor | own_damage | 110.00 | 110.61 | 124.95 |
| motor | third_party_prop | 180.02 | 201.87 | 237.29 |
| motor | bodily_injury | 208.25 | 260.20 | 284.75 |
| motor | theft | 48.95 | 47.15 | 48.81 |
| motor | glass_hail | 24.93 | 36.42 | 33.03 |
| buildings | storm | 58.23 | 60.93 | 60.74 |
| buildings | flood | 133.41 | 176.07 | 180.75 |
| buildings | escape_of_water | 126.43 | 91.74 | 104.67 |
| buildings | subsidence | 60.21 | 64.36 | 54.60 |
| buildings | fire | 98.33 | 127.04 | 127.04 |
| buildings | accidental_damage | 8.57 | 8.41 | 8.98 |
| contents | theft | 54.88 | 49.70 | 54.15 |
| contents | escape_of_water | 27.00 | 19.13 | 21.52 |
| contents | accidental_damage | 13.33 | 11.47 | 13.37 |
| contents | flood | 30.69 | 39.64 | 41.12 |

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

