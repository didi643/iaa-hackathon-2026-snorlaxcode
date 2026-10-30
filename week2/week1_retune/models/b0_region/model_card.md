# Week 1 re-tune run `b0_region` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 10:24:38 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b0_region.xlsx` (MD5 `43a6eb2a40fed34523ba822218f582d2`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 6.0 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: region; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1043 | 0.0708 | 0.0700 | 0.0483 |
| developed | 2024 | 0.1033 | 0.0715 | 0.0629 | 0.0496 |
| reported_raw | 2023 | 0.1000 | 0.0710 | 0.0700 | 0.0339 |
| reported_raw | 2024 | 0.0956 | 0.0735 | 0.0629 | 0.0410 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0375 | 0.0339 | 0.0410 |
| reported_raw | buildings | 0.0722 | 0.0710 | 0.0735 |
| reported_raw | contents | 0.0665 | 0.0700 | 0.0629 |
| reported_raw | ALL | 0.0978 | 0.1000 | 0.0956 |
| developed | motor | 0.0489 | 0.0483 | 0.0496 |
| developed | buildings | 0.0712 | 0.0708 | 0.0715 |
| developed | contents | 0.0665 | 0.0700 | 0.0629 |
| developed | ALL | 0.1038 | 0.1043 | 0.1033 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1372 | 0.1378 |
| buildings | escape_of_water | 0.0401 | 0.0399 |
| buildings | fire | 0.0163 | 0.0165 |
| buildings | flood | 0.4542 | 0.4542 |
| buildings | storm | 0.0578 | 0.0577 |
| buildings | subsidence | 0.0690 | 0.0696 |
| contents | accidental_damage | 0.1410 | 0.1411 |
| contents | escape_of_water | 0.0325 | 0.0323 |
| contents | flood | 0.4364 | 0.4368 |
| contents | theft | 0.0331 | 0.0333 |
| motor | bodily_injury | 0.0425 | 0.0136 |
| motor | glass_hail | 0.1351 | 0.1349 |
| motor | own_damage | 0.1591 | 0.1591 |
| motor | theft | 0.0775 | 0.0775 |
| motor | third_party_prop | 0.0522 | 0.0514 |

## Workbook edits

| sheet | column | edit |
|---|---|---|
| Features_Motor | driver_age | renamed to driver_age_band (category, no monotone constraint) |
| Features_Motor | annual_mileage | use Y -> N (not shared / excluded) |
| Features_Motor | telematics_opt_in | use Y -> N (not shared / excluded) |
| Features_Motor | telematics_score | use Y -> N (not shared / excluded) |
| Features_Motor | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Motor | credit_band | use Y -> N (not shared / excluded) |
| Features_Buildings | policyholder_age | renamed to policyholder_age_band (category, no monotone constraint) |
| Features_Buildings | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Buildings | credit_band | use Y -> N (not shared / excluded) |
| Features_Contents | policyholder_age | renamed to policyholder_age_band (category, no monotone constraint) |
| Features_Contents | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Contents | credit_band | use Y -> N (not shared / excluded) |
| Settings | bags | 5 -> 1 |
| Settings | model_selection | auto -> freq_sev |
| Settings | method_mix | sheet -> auto |

