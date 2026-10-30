# Week 1 re-tune run `b1_mcw_x2` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 12:14:39 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b1_mcw_x2.xlsx` (MD5 `b4d14c148b8afdf46c52a4d75c554a0c`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 5.2 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=2, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1030 | 0.0702 | 0.0681 | 0.0467 |
| developed | 2024 | 0.1013 | 0.0714 | 0.0591 | 0.0465 |
| reported_raw | 2023 | 0.0994 | 0.0704 | 0.0680 | 0.0337 |
| reported_raw | 2024 | 0.0935 | 0.0735 | 0.0592 | 0.0379 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0358 | 0.0337 | 0.0379 |
| reported_raw | buildings | 0.0719 | 0.0704 | 0.0735 |
| reported_raw | contents | 0.0636 | 0.0680 | 0.0592 |
| reported_raw | ALL | 0.0964 | 0.0994 | 0.0935 |
| developed | motor | 0.0466 | 0.0467 | 0.0465 |
| developed | buildings | 0.0708 | 0.0702 | 0.0714 |
| developed | contents | 0.0636 | 0.0681 | 0.0591 |
| developed | ALL | 0.1021 | 0.1030 | 0.1013 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1354 | 0.1361 |
| buildings | escape_of_water | 0.0373 | 0.0372 |
| buildings | fire | 0.0192 | 0.0194 |
| buildings | flood | 0.4451 | 0.4452 |
| buildings | storm | 0.0613 | 0.0612 |
| buildings | subsidence | 0.0737 | 0.0726 |
| contents | accidental_damage | 0.1395 | 0.1396 |
| contents | escape_of_water | 0.0323 | 0.0322 |
| contents | flood | 0.4207 | 0.4211 |
| contents | theft | 0.0335 | 0.0337 |
| motor | bodily_injury | 0.0402 | 0.0112 |
| motor | glass_hail | 0.1339 | 0.1337 |
| motor | own_damage | 0.1550 | 0.1550 |
| motor | theft | 0.0774 | 0.0774 |
| motor | third_party_prop | 0.0508 | 0.0500 |

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

