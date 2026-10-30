# Week 1 re-tune run `b0_age` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 11:05:44 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b0_age.xlsx` (MD5 `d1badedcd47099da8b5cd0c030a23ed5`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 6.8 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: driver_age,policyholder_age; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1033 | 0.0706 | 0.0690 | 0.0467 |
| developed | 2024 | 0.1020 | 0.0719 | 0.0603 | 0.0473 |
| reported_raw | 2023 | 0.0987 | 0.0708 | 0.0690 | 0.0315 |
| reported_raw | 2024 | 0.0941 | 0.0738 | 0.0602 | 0.0386 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0350 | 0.0315 | 0.0386 |
| reported_raw | buildings | 0.0723 | 0.0708 | 0.0738 |
| reported_raw | contents | 0.0646 | 0.0690 | 0.0602 |
| reported_raw | ALL | 0.0964 | 0.0987 | 0.0941 |
| developed | motor | 0.0470 | 0.0467 | 0.0473 |
| developed | buildings | 0.0712 | 0.0706 | 0.0719 |
| developed | contents | 0.0646 | 0.0690 | 0.0603 |
| developed | ALL | 0.1027 | 0.1033 | 0.1020 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1378 | 0.1385 |
| buildings | escape_of_water | 0.0380 | 0.0378 |
| buildings | fire | 0.0207 | 0.0208 |
| buildings | flood | 0.4508 | 0.4508 |
| buildings | storm | 0.0610 | 0.0608 |
| buildings | subsidence | 0.0735 | 0.0719 |
| contents | accidental_damage | 0.1403 | 0.1404 |
| contents | escape_of_water | 0.0324 | 0.0323 |
| contents | flood | 0.4243 | 0.4248 |
| contents | theft | 0.0341 | 0.0343 |
| motor | bodily_injury | 0.0416 | 0.0110 |
| motor | glass_hail | 0.1336 | 0.1334 |
| motor | own_damage | 0.1587 | 0.1586 |
| motor | theft | 0.0772 | 0.0772 |
| motor | third_party_prop | 0.0509 | 0.0501 |

## Workbook edits

| sheet | column | edit |
|---|---|---|
| Features_Motor | annual_mileage | use Y -> N (not shared / excluded) |
| Features_Motor | telematics_opt_in | use Y -> N (not shared / excluded) |
| Features_Motor | telematics_score | use Y -> N (not shared / excluded) |
| Features_Motor | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Motor | credit_band | use Y -> N (not shared / excluded) |
| Features_Motor | region | use Y -> N (not shared / excluded) |
| Features_Buildings | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Buildings | credit_band | use Y -> N (not shared / excluded) |
| Features_Buildings | region | use Y -> N (not shared / excluded) |
| Features_Contents | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Contents | credit_band | use Y -> N (not shared / excluded) |
| Features_Contents | region | use Y -> N (not shared / excluded) |
| Settings | bags | 5 -> 1 |
| Settings | model_selection | auto -> freq_sev |
| Settings | method_mix | sheet -> auto |

