# Week 1 re-tune run `b3_young` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 14:33:27 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b3_young.xlsx` (MD5 `24920a74a2dcfa062315fc2e96ffd03e`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 3.6 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: age; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1033 | 0.0708 | 0.0688 | 0.0466 |
| developed | 2024 | 0.1015 | 0.0717 | 0.0596 | 0.0467 |
| reported_raw | 2023 | 0.0998 | 0.0710 | 0.0688 | 0.0340 |
| reported_raw | 2024 | 0.0938 | 0.0736 | 0.0596 | 0.0381 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0361 | 0.0340 | 0.0381 |
| reported_raw | buildings | 0.0723 | 0.0710 | 0.0736 |
| reported_raw | contents | 0.0642 | 0.0688 | 0.0596 |
| reported_raw | ALL | 0.0968 | 0.0998 | 0.0938 |
| developed | motor | 0.0466 | 0.0466 | 0.0467 |
| developed | buildings | 0.0713 | 0.0708 | 0.0717 |
| developed | contents | 0.0642 | 0.0688 | 0.0596 |
| developed | ALL | 0.1024 | 0.1033 | 0.1015 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1377 | 0.1383 |
| buildings | escape_of_water | 0.0379 | 0.0377 |
| buildings | fire | 0.0193 | 0.0194 |
| buildings | flood | 0.4508 | 0.4508 |
| buildings | storm | 0.0610 | 0.0608 |
| buildings | subsidence | 0.0735 | 0.0719 |
| contents | accidental_damage | 0.1401 | 0.1401 |
| contents | escape_of_water | 0.0324 | 0.0323 |
| contents | flood | 0.4243 | 0.4248 |
| contents | theft | 0.0340 | 0.0342 |
| motor | bodily_injury | 0.0410 | 0.0131 |
| motor | glass_hail | 0.1337 | 0.1335 |
| motor | own_damage | 0.1584 | 0.1584 |
| motor | theft | 0.0776 | 0.0776 |
| motor | third_party_prop | 0.0506 | 0.0498 |

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

