# Week 1 re-tune run `b1_col1` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 12:54:21 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b1_col1.xlsx` (MD5 `572f5234d6618031860799ce3cf17f8c`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 5.4 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=1, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1033 | 0.0711 | 0.0685 | 0.0464 |
| developed | 2024 | 0.1015 | 0.0716 | 0.0600 | 0.0466 |
| reported_raw | 2023 | 0.0994 | 0.0713 | 0.0684 | 0.0330 |
| reported_raw | 2024 | 0.0937 | 0.0734 | 0.0600 | 0.0380 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0355 | 0.0330 | 0.0380 |
| reported_raw | buildings | 0.0724 | 0.0713 | 0.0734 |
| reported_raw | contents | 0.0642 | 0.0684 | 0.0600 |
| reported_raw | ALL | 0.0966 | 0.0994 | 0.0937 |
| developed | motor | 0.0465 | 0.0464 | 0.0466 |
| developed | buildings | 0.0714 | 0.0711 | 0.0716 |
| developed | contents | 0.0642 | 0.0685 | 0.0600 |
| developed | ALL | 0.1024 | 0.1033 | 0.1015 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1364 | 0.1371 |
| buildings | escape_of_water | 0.0365 | 0.0363 |
| buildings | fire | 0.0165 | 0.0167 |
| buildings | flood | 0.4523 | 0.4523 |
| buildings | storm | 0.0609 | 0.0607 |
| buildings | subsidence | 0.0740 | 0.0726 |
| contents | accidental_damage | 0.1394 | 0.1394 |
| contents | escape_of_water | 0.0319 | 0.0317 |
| contents | flood | 0.4270 | 0.4274 |
| contents | theft | 0.0334 | 0.0336 |
| motor | bodily_injury | 0.0408 | 0.0123 |
| motor | glass_hail | 0.1334 | 0.1332 |
| motor | own_damage | 0.1582 | 0.1582 |
| motor | theft | 0.0769 | 0.0769 |
| motor | third_party_prop | 0.0506 | 0.0497 |

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

