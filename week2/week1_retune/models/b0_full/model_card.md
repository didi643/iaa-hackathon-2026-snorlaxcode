# Week 1 re-tune run `b0_full` (week 1 C5 engine on emerging-available fields)

Run 2026-10-28 09:36:18 SGT, 1 bag(s), seed offset 0, workbook `week2/week1_retune/inputs/assumptions_retune_b0_full.xlsx` (MD5 `43d3e08670621b4e7ddd7447acf75ec0`, source copy MD5 `422a8e964874cafe1758ed111be074d9`). Run time 6.3 min.

## Switches

- HP: depth_add=0, eta_mult=1, mcw_mult=1, reg_lambda=NA, colsample=NA, subsample=NA
- FEATURE_ADD: ; FEATURE_OFF_KEEP=all: TRUE; MONO_OFF: FALSE; AGE_BAND_ORD: FALSE; LOC_ALL: FALSE; PROXY: ; TRAIN_FROM: 0; YEAR_WEIGHTS: ; DOMAIN_W: FALSE; LINES: motor,buildings,contents
- SPEC_OVERRIDE rows: 0

## Developed validation (week 1 folds; D2 vs one rate per exposure-year)

| basis | valid_year | ALL | buildings | contents | motor |
|---|---|---|---|---|---|
| developed | 2023 | 0.1072 | 0.0709 | 0.0703 | 0.0548 |
| developed | 2024 | 0.1063 | 0.0713 | 0.0641 | 0.0560 |
| reported_raw | 2023 | 0.1046 | 0.0711 | 0.0702 | 0.0439 |
| reported_raw | 2024 | 0.0983 | 0.0734 | 0.0640 | 0.0471 |

| basis | line | mean_d2 | d2_2023 | d2_2024 |
|---|---|---|---|---|
| reported_raw | motor | 0.0455 | 0.0439 | 0.0471 |
| reported_raw | buildings | 0.0722 | 0.0711 | 0.0734 |
| reported_raw | contents | 0.0671 | 0.0702 | 0.0640 |
| reported_raw | ALL | 0.1015 | 0.1046 | 0.0983 |
| developed | motor | 0.0554 | 0.0548 | 0.0560 |
| developed | buildings | 0.0711 | 0.0709 | 0.0713 |
| developed | contents | 0.0672 | 0.0703 | 0.0641 |
| developed | ALL | 0.1068 | 0.1072 | 0.1063 |

Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.

## Peril scores (mean 2023-24)

| line | peril | developed | reported_raw |
|---|---|---|---|
| buildings | accidental_damage | 0.1386 | 0.1392 |
| buildings | escape_of_water | 0.0408 | 0.0406 |
| buildings | fire | 0.0157 | 0.0159 |
| buildings | flood | 0.4542 | 0.4542 |
| buildings | storm | 0.0578 | 0.0577 |
| buildings | subsidence | 0.0690 | 0.0696 |
| contents | accidental_damage | 0.1416 | 0.1417 |
| contents | escape_of_water | 0.0330 | 0.0328 |
| contents | flood | 0.4364 | 0.4368 |
| contents | theft | 0.0335 | 0.0337 |
| motor | bodily_injury | 0.0519 | 0.0249 |
| motor | glass_hail | 0.1370 | 0.1369 |
| motor | own_damage | 0.1641 | 0.1640 |
| motor | theft | 0.0773 | 0.0774 |
| motor | third_party_prop | 0.0578 | 0.0571 |

## Workbook edits

| sheet | column | edit |
|---|---|---|
| Features_Motor | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Buildings | compulsory_excess | use Y -> N (not shared / excluded) |
| Features_Contents | compulsory_excess | use Y -> N (not shared / excluded) |
| Settings | bags | 5 -> 1 |
| Settings | model_selection | auto -> freq_sev |
| Settings | method_mix | sheet -> auto |

