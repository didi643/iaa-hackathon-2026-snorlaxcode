# Week 1 re-tune run `b2_band_ord` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 13:33:44 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b2_band_ord.xlsx` (MD5 `50647b2d3411ab8640eb168832b4fe57`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 7.2 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: TRUE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1031 | 0.0707 | 0.0688 | 0.0462 |
| developed | 2024 | 0.1014 | 0.0717 | 0.0598 | 0.0463 |
| reported_raw | 2023 | 0.0986 | 0.0709 | 0.0688 | 0.0314 |
| reported_raw | 2024 | 0.0936 | 0.0736 | 0.0597 | 0.0376 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0345 | 0.0314 | 0.0376 |
| reported_raw | buildings | 0.0722 | 0.0709 | 0.0736 |
| reported_raw | contents | 0.0643 | 0.0688 | 0.0597 |
| reported_raw | ALL | 0.0961 | 0.0986 | 0.0936 |
| developed | motor | 0.0463 | 0.0462 | 0.0463 |
| developed | buildings | 0.0712 | 0.0707 | 0.0717 |
| developed | contents | 0.0643 | 0.0688 | 0.0598 |
| developed | ALL | 0.1022 | 0.1031 | 0.1014 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1384 | 0.1390 |
| buildings | escape_of_water | 0.0379 | 0.0377 |
| buildings | fire | 0.0194 | 0.0195 |
| buildings | flood | 0.4508 | 0.4508 |
| buildings | storm | 0.0610 | 0.0608 |
| buildings | subsidence | 0.0735 | 0.0719 |
| contents | accidental_damage | 0.1397 | 0.1397 |
| contents | escape_of_water | 0.0324 | 0.0323 |
| contents | flood | 0.4243 | 0.4248 |
| contents | theft | 0.0340 | 0.0342 |
| motor | bodily_injury | 0.0404 | 0.0099 |
| motor | glass_hail | 0.1336 | 0.1334 |
| motor | own_damage | 0.1583 | 0.1582 |
| motor | theft | 0.0777 | 0.0777 |
| motor | third_party_prop | 0.0503 | 0.0495 |

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

