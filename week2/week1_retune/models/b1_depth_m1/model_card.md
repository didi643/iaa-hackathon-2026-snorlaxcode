# Week 1 re-tune run `b1_depth_m1` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 11:21:01 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b1_depth_m1.xlsx` (MD5 `688ef061090b7ec143a61f37774e28d1`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 4.0 min.

## Switches

- HP: depth_add=-1, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1031 | 0.0705 | 0.0694 | 0.0461 |
| developed | 2024 | 0.1017 | 0.0722 | 0.0596 | 0.0467 |
| reported_raw | 2023 | 0.0990 | 0.0707 | 0.0694 | 0.0321 |
| reported_raw | 2024 | 0.0939 | 0.0740 | 0.0596 | 0.0381 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0351 | 0.0321 | 0.0381 |
| reported_raw | buildings | 0.0723 | 0.0707 | 0.0740 |
| reported_raw | contents | 0.0645 | 0.0694 | 0.0596 |
| reported_raw | ALL | 0.0964 | 0.0990 | 0.0939 |
| developed | motor | 0.0464 | 0.0461 | 0.0467 |
| developed | buildings | 0.0714 | 0.0705 | 0.0722 |
| developed | contents | 0.0645 | 0.0694 | 0.0596 |
| developed | ALL | 0.1024 | 0.1031 | 0.1017 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1381 | 0.1387 |
| buildings | escape_of_water | 0.0371 | 0.0369 |
| buildings | fire | 0.0214 | 0.0215 |
| buildings | flood | 0.4516 | 0.4516 |
| buildings | storm | 0.0616 | 0.0615 |
| buildings | subsidence | 0.0737 | 0.0721 |
| contents | accidental_damage | 0.1393 | 0.1393 |
| contents | escape_of_water | 0.0334 | 0.0332 |
| contents | flood | 0.4282 | 0.4287 |
| contents | theft | 0.0339 | 0.0341 |
| motor | bodily_injury | 0.0411 | 0.0119 |
| motor | glass_hail | 0.1334 | 0.1332 |
| motor | own_damage | 0.1587 | 0.1586 |
| motor | theft | 0.0776 | 0.0776 |
| motor | third_party_prop | 0.0507 | 0.0498 |

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

