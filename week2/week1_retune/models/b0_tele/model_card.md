# Week 1 re-tune run `b0_tele` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 09:50:33 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b0_tele.xlsx` (MD5 `cb116dc802964cbb86f8b6cb6c606c9d`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 4.1 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: telematics_opt_in,telematics_score; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1039 | 0.0708 | 0.0688 | 0.0479 |
| developed | 2024 | 0.1019 | 0.0717 | 0.0596 | 0.0476 |
| reported_raw | 2023 | 0.1008 | 0.0710 | 0.0688 | 0.0362 |
| reported_raw | 2024 | 0.0942 | 0.0736 | 0.0596 | 0.0392 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0377 | 0.0362 | 0.0392 |
| reported_raw | buildings | 0.0723 | 0.0710 | 0.0736 |
| reported_raw | contents | 0.0642 | 0.0688 | 0.0596 |
| reported_raw | ALL | 0.0975 | 0.1008 | 0.0942 |
| developed | motor | 0.0477 | 0.0479 | 0.0476 |
| developed | buildings | 0.0713 | 0.0708 | 0.0717 |
| developed | contents | 0.0642 | 0.0688 | 0.0596 |
| developed | ALL | 0.1029 | 0.1039 | 0.1019 |

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
| motor | bodily_injury | 0.0424 | 0.0154 |
| motor | glass_hail | 0.1336 | 0.1334 |
| motor | own_damage | 0.1594 | 0.1593 |
| motor | theft | 0.0771 | 0.0771 |
| motor | third_party_prop | 0.0514 | 0.0506 |

## Workbook edits

| sheet | column | edit |
|---|---|---|
| Features_Motor | driver_age | renamed to driver_age_band (category, no monotone constraint) |
| Features_Motor | annual_mileage | use Y -> N (not shared / excluded) |
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

