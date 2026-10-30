# Week 1 re-tune run `b5_recent` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 14:42:55 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b5_recent.xlsx` (MD5 `c4abcb49a6b0fc78a738ac19fcbad870`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 3.6 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: FALSE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 2022; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1000 | 0.0670 | 0.0659 | 0.0431 |
| developed | 2024 | 0.1003 | 0.0700 | 0.0578 | 0.0460 |
| reported_raw | 2023 | 0.0942 | 0.0672 | 0.0659 | 0.0253 |
| reported_raw | 2024 | 0.0922 | 0.0721 | 0.0576 | 0.0366 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0309 | 0.0253 | 0.0366 |
| reported_raw | buildings | 0.0697 | 0.0672 | 0.0721 |
| reported_raw | contents | 0.0618 | 0.0659 | 0.0576 |
| reported_raw | ALL | 0.0932 | 0.0942 | 0.0922 |
| developed | motor | 0.0445 | 0.0431 | 0.0460 |
| developed | buildings | 0.0685 | 0.0670 | 0.0700 |
| developed | contents | 0.0619 | 0.0659 | 0.0578 |
| developed | ALL | 0.1002 | 0.1000 | 0.1003 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1360 | 0.1366 |
| buildings | escape_of_water | 0.0341 | 0.0337 |
| buildings | fire | 0.0160 | 0.0160 |
| buildings | flood | 0.4474 | 0.4477 |
| buildings | storm | 0.0584 | 0.0581 |
| buildings | subsidence | 0.0670 | 0.0706 |
| contents | accidental_damage | 0.1379 | 0.1378 |
| contents | escape_of_water | 0.0298 | 0.0298 |
| contents | flood | 0.4099 | 0.4103 |
| contents | theft | 0.0309 | 0.0310 |
| motor | bodily_injury | 0.0349 | 0.0015 |
| motor | glass_hail | 0.1220 | 0.1219 |
| motor | own_damage | 0.1520 | 0.1519 |
| motor | theft | 0.0695 | 0.0694 |
| motor | third_party_prop | 0.0484 | 0.0475 |

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

