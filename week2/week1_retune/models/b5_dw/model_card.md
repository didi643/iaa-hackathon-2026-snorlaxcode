# Week 1 re-tune run `b5_dw` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 15:05:24 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b5_dw.xlsx` (MD5 `664877a2a3edd17beae70216fec288ac`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 3.4 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: TRUE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1002 | 0.0697 | 0.0656 | 0.0417 |
| developed | 2024 | 0.0995 | 0.0684 | 0.0566 | 0.0457 |
| reported_raw | 2023 | 0.0952 | 0.0699 | 0.0656 | 0.0260 |
| reported_raw | 2024 | 0.0916 | 0.0705 | 0.0568 | 0.0368 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0314 | 0.0260 | 0.0368 |
| reported_raw | buildings | 0.0702 | 0.0699 | 0.0705 |
| reported_raw | contents | 0.0612 | 0.0656 | 0.0568 |
| reported_raw | ALL | 0.0934 | 0.0952 | 0.0916 |
| developed | motor | 0.0437 | 0.0417 | 0.0457 |
| developed | buildings | 0.0691 | 0.0697 | 0.0684 |
| developed | contents | 0.0611 | 0.0656 | 0.0566 |
| developed | ALL | 0.0998 | 0.1002 | 0.0995 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1313 | 0.1320 |
| buildings | escape_of_water | 0.0370 | 0.0369 |
| buildings | fire | 0.0118 | 0.0121 |
| buildings | flood | 0.4140 | 0.4134 |
| buildings | storm | 0.0595 | 0.0594 |
| buildings | subsidence | 0.0677 | 0.0669 |
| contents | accidental_damage | 0.1348 | 0.1349 |
| contents | escape_of_water | 0.0288 | 0.0286 |
| contents | flood | 0.3984 | 0.3995 |
| contents | theft | 0.0294 | 0.0298 |
| motor | bodily_injury | 0.0335 | 0.0027 |
| motor | glass_hail | 0.1315 | 0.1313 |
| motor | own_damage | 0.1560 | 0.1561 |
| motor | theft | 0.0758 | 0.0758 |
| motor | third_party_prop | 0.0494 | 0.0484 |

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

