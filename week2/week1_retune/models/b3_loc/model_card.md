# Week 1 re-tune run `b3_loc` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 13:55:49 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b3_loc.xlsx` (MD5 `77f8bc7b289e7f18cd246483cdfc4e24`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 4.9 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: TRUE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1033 | 0.0706 | 0.0683 | 0.0468 |
| developed | 2024 | 0.1022 | 0.0716 | 0.0607 | 0.0477 |
| reported_raw | 2023 | 0.0990 | 0.0708 | 0.0683 | 0.0325 |
| reported_raw | 2024 | 0.0944 | 0.0735 | 0.0607 | 0.0392 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0358 | 0.0325 | 0.0392 |
| reported_raw | buildings | 0.0721 | 0.0708 | 0.0735 |
| reported_raw | contents | 0.0645 | 0.0683 | 0.0607 |
| reported_raw | ALL | 0.0967 | 0.0990 | 0.0944 |
| developed | motor | 0.0473 | 0.0468 | 0.0477 |
| developed | buildings | 0.0711 | 0.0706 | 0.0716 |
| developed | contents | 0.0645 | 0.0683 | 0.0607 |
| developed | ALL | 0.1027 | 0.1033 | 0.1022 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1371 | 0.1378 |
| buildings | escape_of_water | 0.0387 | 0.0385 |
| buildings | fire | 0.0193 | 0.0195 |
| buildings | flood | 0.4518 | 0.4517 |
| buildings | storm | 0.0550 | 0.0549 |
| buildings | subsidence | 0.0711 | 0.0700 |
| contents | accidental_damage | 0.1404 | 0.1405 |
| contents | escape_of_water | 0.0315 | 0.0313 |
| contents | flood | 0.4301 | 0.4304 |
| contents | theft | 0.0332 | 0.0334 |
| motor | bodily_injury | 0.0413 | 0.0111 |
| motor | glass_hail | 0.1337 | 0.1335 |
| motor | own_damage | 0.1590 | 0.1590 |
| motor | theft | 0.0763 | 0.0763 |
| motor | third_party_prop | 0.0514 | 0.0505 |

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

