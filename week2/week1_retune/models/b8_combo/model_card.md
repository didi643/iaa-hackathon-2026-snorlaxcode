# Week 1 re-tune run `b8_combo` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 15:20:30 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b8_combo.xlsx` (MD5 `e9af6bdd3e91c607223eb31b02d39589`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 5.0 min.

## Switches

- HP: depth_add=-1, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: TRUE; PROXY: credit; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1034 | 0.0711 | 0.0699 | 0.0462 |
| developed | 2024 | 0.1027 | 0.0724 | 0.0617 | 0.0480 |
| reported_raw | 2023 | 0.0977 | 0.0713 | 0.0699 | 0.0288 |
| reported_raw | 2024 | 0.0949 | 0.0744 | 0.0616 | 0.0393 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0340 | 0.0288 | 0.0393 |
| reported_raw | buildings | 0.0728 | 0.0713 | 0.0744 |
| reported_raw | contents | 0.0657 | 0.0699 | 0.0616 |
| reported_raw | ALL | 0.0963 | 0.0977 | 0.0949 |
| developed | motor | 0.0471 | 0.0462 | 0.0480 |
| developed | buildings | 0.0718 | 0.0711 | 0.0724 |
| developed | contents | 0.0658 | 0.0699 | 0.0617 |
| developed | ALL | 0.1031 | 0.1034 | 0.1027 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1387 | 0.1394 |
| buildings | escape_of_water | 0.0391 | 0.0389 |
| buildings | fire | 0.0176 | 0.0178 |
| buildings | flood | 0.4538 | 0.4537 |
| buildings | storm | 0.0564 | 0.0563 |
| buildings | subsidence | 0.0739 | 0.0716 |
| contents | accidental_damage | 0.1403 | 0.1404 |
| contents | escape_of_water | 0.0360 | 0.0358 |
| contents | flood | 0.4347 | 0.4349 |
| contents | theft | 0.0339 | 0.0341 |
| motor | bodily_injury | 0.0417 | 0.0084 |
| motor | glass_hail | 0.1346 | 0.1344 |
| motor | own_damage | 0.1591 | 0.1590 |
| motor | theft | 0.0772 | 0.0773 |
| motor | third_party_prop | 0.0513 | 0.0505 |

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

