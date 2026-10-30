# Week 1 re-tune run `b1_eta_half` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 11:56:41 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b1_eta_half.xlsx` (MD5 `d8d978432448fca531edd989c44859f8`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 8.4 min.

## Switches

- HP: depth_add=0, eta_mult=0.5, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1030 | 0.0710 | 0.0686 | 0.0458 |
| developed | 2024 | 0.1018 | 0.0725 | 0.0596 | 0.0466 |
| reported_raw | 2023 | 0.0988 | 0.0712 | 0.0686 | 0.0316 |
| reported_raw | 2024 | 0.0939 | 0.0743 | 0.0596 | 0.0379 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0348 | 0.0316 | 0.0379 |
| reported_raw | buildings | 0.0727 | 0.0712 | 0.0743 |
| reported_raw | contents | 0.0641 | 0.0686 | 0.0596 |
| reported_raw | ALL | 0.0963 | 0.0988 | 0.0939 |
| developed | motor | 0.0462 | 0.0458 | 0.0466 |
| developed | buildings | 0.0718 | 0.0710 | 0.0725 |
| developed | contents | 0.0641 | 0.0686 | 0.0596 |
| developed | ALL | 0.1024 | 0.1030 | 0.1018 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1375 | 0.1382 |
| buildings | escape_of_water | 0.0375 | 0.0373 |
| buildings | fire | 0.0229 | 0.0230 |
| buildings | flood | 0.4508 | 0.4508 |
| buildings | storm | 0.0607 | 0.0605 |
| buildings | subsidence | 0.0742 | 0.0727 |
| contents | accidental_damage | 0.1396 | 0.1396 |
| contents | escape_of_water | 0.0329 | 0.0327 |
| contents | flood | 0.4263 | 0.4267 |
| contents | theft | 0.0336 | 0.0338 |
| motor | bodily_injury | 0.0402 | 0.0103 |
| motor | glass_hail | 0.1338 | 0.1336 |
| motor | own_damage | 0.1586 | 0.1585 |
| motor | theft | 0.0783 | 0.0783 |
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

