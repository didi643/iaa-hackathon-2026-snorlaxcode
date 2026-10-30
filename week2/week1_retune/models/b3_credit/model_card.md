# Week 1 re-tune run `b3_credit` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 14:23:58 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b3_credit.xlsx` (MD5 `381b3f9c411c12617adf9c98695bb4b9`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 3.9 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: credit; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1036 | 0.0710 | 0.0693 | 0.0470 |
| developed | 2024 | 0.1021 | 0.0727 | 0.0601 | 0.0471 |
| reported_raw | 2023 | 0.0994 | 0.0712 | 0.0692 | 0.0327 |
| reported_raw | 2024 | 0.0944 | 0.0745 | 0.0601 | 0.0387 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0357 | 0.0327 | 0.0387 |
| reported_raw | buildings | 0.0728 | 0.0712 | 0.0745 |
| reported_raw | contents | 0.0647 | 0.0692 | 0.0601 |
| reported_raw | ALL | 0.0969 | 0.0994 | 0.0944 |
| developed | motor | 0.0471 | 0.0470 | 0.0471 |
| developed | buildings | 0.0718 | 0.0710 | 0.0727 |
| developed | contents | 0.0647 | 0.0693 | 0.0601 |
| developed | ALL | 0.1029 | 0.1036 | 0.1021 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1372 | 0.1379 |
| buildings | escape_of_water | 0.0375 | 0.0373 |
| buildings | fire | 0.0208 | 0.0210 |
| buildings | flood | 0.4512 | 0.4513 |
| buildings | storm | 0.0617 | 0.0616 |
| buildings | subsidence | 0.0743 | 0.0735 |
| contents | accidental_damage | 0.1390 | 0.1390 |
| contents | escape_of_water | 0.0350 | 0.0348 |
| contents | flood | 0.4272 | 0.4276 |
| contents | theft | 0.0333 | 0.0335 |
| motor | bodily_injury | 0.0426 | 0.0127 |
| motor | glass_hail | 0.1345 | 0.1343 |
| motor | own_damage | 0.1583 | 0.1582 |
| motor | theft | 0.0779 | 0.0779 |
| motor | third_party_prop | 0.0507 | 0.0499 |

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

