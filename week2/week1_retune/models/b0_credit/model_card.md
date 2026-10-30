# Week 1 re-tune run `b0_credit` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 10:45:56 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b0_credit.xlsx` (MD5 `9f20d0c2df1e9c26862cb6e8185606cf`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 6.2 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: credit_band; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1033 | 0.0707 | 0.0692 | 0.0466 |
| developed | 2024 | 0.1017 | 0.0721 | 0.0599 | 0.0466 |
| reported_raw | 2023 | 0.0994 | 0.0709 | 0.0692 | 0.0330 |
| reported_raw | 2024 | 0.0938 | 0.0739 | 0.0599 | 0.0379 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0354 | 0.0330 | 0.0379 |
| reported_raw | buildings | 0.0724 | 0.0709 | 0.0739 |
| reported_raw | contents | 0.0645 | 0.0692 | 0.0599 |
| reported_raw | ALL | 0.0966 | 0.0994 | 0.0938 |
| developed | motor | 0.0466 | 0.0466 | 0.0466 |
| developed | buildings | 0.0714 | 0.0707 | 0.0721 |
| developed | contents | 0.0645 | 0.0692 | 0.0599 |
| developed | ALL | 0.1025 | 0.1033 | 0.1017 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1372 | 0.1379 |
| buildings | escape_of_water | 0.0375 | 0.0373 |
| buildings | fire | 0.0203 | 0.0204 |
| buildings | flood | 0.4508 | 0.4508 |
| buildings | storm | 0.0610 | 0.0608 |
| buildings | subsidence | 0.0735 | 0.0719 |
| contents | accidental_damage | 0.1392 | 0.1393 |
| contents | escape_of_water | 0.0335 | 0.0333 |
| contents | flood | 0.4243 | 0.4248 |
| contents | theft | 0.0338 | 0.0340 |
| motor | bodily_injury | 0.0401 | 0.0106 |
| motor | glass_hail | 0.1336 | 0.1334 |
| motor | own_damage | 0.1585 | 0.1584 |
| motor | theft | 0.0775 | 0.0775 |
| motor | third_party_prop | 0.0513 | 0.0504 |

## Workbook edits

| sheet | column | edit |
|---|---|---|
| Features_Motor | driver_age | renamed to driver_age_band (category, no monotone constraint) |
| Features_Motor | annual_mileage | use Y -> N (not shared / excluded) |
| Features_Motor | telematics_opt_in | use Y -> N (not shared / excluded) |
| Features_Motor | telematics_score | use Y -> N (not shared / excluded) |
| Features_Motor | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Motor | region | use Y -> N (not shared / excluded) |
| Features_Buildings | policyholder_age | renamed to policyholder_age_band (category, no monotone constraint) |
| Features_Buildings | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Buildings | region | use Y -> N (not shared / excluded) |
| Features_Contents | policyholder_age | renamed to policyholder_age_band (category, no monotone constraint) |
| Features_Contents | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Contents | region | use Y -> N (not shared / excluded) |
| Settings | bags | 5 -> 1 |
| Settings | model_selection | auto -> freq_sev |
| Settings | method_mix | sheet -> auto |

