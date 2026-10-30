# Week 1 re-tune run `b1_depth_p1` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 11:33:41 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b1_depth_p1.xlsx` (MD5 `07bb9c9852b0a19da5c7e47121bb1683`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 5.1 min.

## Switches

- HP: depth_add=1, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1032 | 0.0708 | 0.0680 | 0.0468 |
| developed | 2024 | 0.1013 | 0.0710 | 0.0591 | 0.0468 |
| reported_raw | 2023 | 0.0997 | 0.0710 | 0.0680 | 0.0340 |
| reported_raw | 2024 | 0.0935 | 0.0731 | 0.0591 | 0.0382 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0361 | 0.0340 | 0.0382 |
| reported_raw | buildings | 0.0720 | 0.0710 | 0.0731 |
| reported_raw | contents | 0.0636 | 0.0680 | 0.0591 |
| reported_raw | ALL | 0.0966 | 0.0997 | 0.0935 |
| developed | motor | 0.0468 | 0.0468 | 0.0468 |
| developed | buildings | 0.0709 | 0.0708 | 0.0710 |
| developed | contents | 0.0636 | 0.0680 | 0.0591 |
| developed | ALL | 0.1023 | 0.1032 | 0.1013 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1354 | 0.1361 |
| buildings | escape_of_water | 0.0372 | 0.0370 |
| buildings | fire | 0.0179 | 0.0181 |
| buildings | flood | 0.4515 | 0.4515 |
| buildings | storm | 0.0599 | 0.0597 |
| buildings | subsidence | 0.0717 | 0.0708 |
| contents | accidental_damage | 0.1375 | 0.1376 |
| contents | escape_of_water | 0.0319 | 0.0316 |
| contents | flood | 0.4237 | 0.4241 |
| contents | theft | 0.0327 | 0.0329 |
| motor | bodily_injury | 0.0407 | 0.0126 |
| motor | glass_hail | 0.1340 | 0.1338 |
| motor | own_damage | 0.1580 | 0.1579 |
| motor | theft | 0.0783 | 0.0783 |
| motor | third_party_prop | 0.0504 | 0.0496 |

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

