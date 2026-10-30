# Week 1 re-tune run `b1_lambda20` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 12:34:59 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b1_lambda20.xlsx` (MD5 `a868688d6f7e86863adc9b4798be8606`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 5.9 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=20, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1030 | 0.0705 | 0.0686 | 0.0463 |
| developed | 2024 | 0.1018 | 0.0724 | 0.0593 | 0.0468 |
| reported_raw | 2023 | 0.0992 | 0.0707 | 0.0685 | 0.0329 |
| reported_raw | 2024 | 0.0939 | 0.0740 | 0.0593 | 0.0383 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0356 | 0.0329 | 0.0383 |
| reported_raw | buildings | 0.0724 | 0.0707 | 0.0740 |
| reported_raw | contents | 0.0639 | 0.0685 | 0.0593 |
| reported_raw | ALL | 0.0966 | 0.0992 | 0.0939 |
| developed | motor | 0.0466 | 0.0463 | 0.0468 |
| developed | buildings | 0.0715 | 0.0705 | 0.0724 |
| developed | contents | 0.0640 | 0.0686 | 0.0593 |
| developed | ALL | 0.1024 | 0.1030 | 0.1018 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1381 | 0.1387 |
| buildings | escape_of_water | 0.0370 | 0.0368 |
| buildings | fire | 0.0183 | 0.0184 |
| buildings | flood | 0.4482 | 0.4482 |
| buildings | storm | 0.0609 | 0.0607 |
| buildings | subsidence | 0.0736 | 0.0725 |
| contents | accidental_damage | 0.1389 | 0.1390 |
| contents | escape_of_water | 0.0328 | 0.0326 |
| contents | flood | 0.4217 | 0.4223 |
| contents | theft | 0.0338 | 0.0339 |
| motor | bodily_injury | 0.0403 | 0.0111 |
| motor | glass_hail | 0.1335 | 0.1333 |
| motor | own_damage | 0.1584 | 0.1583 |
| motor | theft | 0.0775 | 0.0775 |
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

