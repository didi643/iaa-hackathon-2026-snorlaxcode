# WENDY 7 (b6) - WENDY 4 engine, IBNR method `report_share`

**Run id** `20261022_1927` | **Workbook** `docs/assumptions_wendy07.xlsx` (MD5 `5abce31f2e80de61169720c5475ab7e2`) | **Method mix** `output/4_check_reported/4_models_iterwendy04/chosen_method.csv` | validation only (FINAL_FIT=0)

## Local protocol: line D2 (Tweedie p = 1.5) on three actual bases
| basis | valid_year | motor | buildings | contents | ALL |
|---|---|---|---|---|---|
| developed | 2023 | 0.0528 | 0.0712 | 0.0707 | 0.1064 |
| developed | 2024 | 0.0556 | 0.0717 | 0.0638 | 0.1049 |
| reported_adj | 2023 | 0.0523 | 0.0714 | 0.0707 | 0.1055 |
| reported_adj | 2024 | 0.0482 | 0.0731 | 0.0636 | 0.0982 |
| reported_raw | 2023 | 0.0454 | 0.0714 | 0.0707 | 0.1055 |
| reported_raw | 2024 | 0.0497 | 0.0731 | 0.0636 | 0.0993 |

Mean of 2023 and 2024 (primary score = reported_raw, ALL):

| basis | line | mean_d2 | d2_2023 | d2_2024 | pred_vs_actual_2024 |
|---|---|---|---|---|---|
| developed | ALL | 0.1056 | 0.1064 | 0.1049 | 1.0415 |
| developed | buildings | 0.0715 | 0.0712 | 0.0717 | 0.9800 |
| developed | contents | 0.0672 | 0.0707 | 0.0638 | 1.0027 |
| developed | motor | 0.0542 | 0.0528 | 0.0556 | 1.0907 |
| reported_adj | ALL | 0.1019 | 0.1055 | 0.0982 | 1.1345 |
| reported_adj | buildings | 0.0723 | 0.0714 | 0.0731 | 1.0221 |
| reported_adj | contents | 0.0672 | 0.0707 | 0.0636 | 1.0087 |
| reported_adj | motor | 0.0503 | 0.0523 | 0.0482 | 1.2439 |
| reported_raw | ALL | 0.1024 | 0.1055 | 0.0993 | 1.1257 |
| reported_raw | buildings | 0.0723 | 0.0714 | 0.0731 | 1.0221 |
| reported_raw | contents | 0.0672 | 0.0707 | 0.0636 | 1.0087 |
| reported_raw | motor | 0.0476 | 0.0454 | 0.0497 | 1.2253 |

## Reported share by policy year (exposure-weighted; A0 = WENDY 4 mid-date ECDF)
| line | peril | 2021 | 2022 | 2023 | 2024 |
|---|---|---|---|---|---|
| buildings | accidental_damage | 1 | 1 | 1 | 1 |
| buildings | escape_of_water | 1 | 1 | 1 | 1 |
| buildings | fire | 1 | 1 | 1 | 1 |
| buildings | flood | 1 | 1 | 1 | 1 |
| buildings | storm | 1 | 1 | 1 | 1 |
| buildings | subsidence | 1 | 1 | 1 | 1 |
| contents | accidental_damage | 1 | 1 | 1 | 1 |
| contents | escape_of_water | 1 | 1 | 1 | 1 |
| contents | flood | 1 | 1 | 1 | 1 |
| contents | theft | 1 | 1 | 1 | 1 |
| motor | bodily_injury | 1 | 1 | 1 | 1 |
| motor | glass_hail | 1 | 1 | 1 | 1 |
| motor | own_damage | 1 | 1 | 1 | 1 |
| motor | theft | 1 | 1 | 1 | 1 |
| motor | third_party_prop | 1 | 1 | 1 | 1 |

| line | peril | share_a0 | share | ibnr_factor |
|---|---|---|---|---|
| motor | own_damage | 0.996 | 0.996 | 1.004 |
| motor | third_party_prop | 0.992 | 0.992 | 1.008 |
| motor | bodily_injury | 0.626 | 0.626 | 1.599 |
| motor | theft | 0.996 | 0.996 | 1.004 |
| motor | glass_hail | 0.994 | 0.994 | 1.006 |
| buildings | storm | 0.995 | 0.995 | 1.005 |
| buildings | flood | 0.996 | 0.996 | 1.004 |
| buildings | escape_of_water | 0.994 | 0.994 | 1.006 |
| buildings | subsidence | 0.751 | 0.751 | 1.331 |
| buildings | fire | 0.996 | 0.996 | 1.004 |
| buildings | accidental_damage | 0.996 | 0.996 | 1.004 |
| contents | theft | 0.997 | 0.997 | 1.003 |
| contents | escape_of_water | 0.992 | 0.992 | 1.008 |
| contents | accidental_damage | 0.995 | 0.995 | 1.005 |
| contents | flood | 0.989 | 0.989 | 1.011 |

## By peril (mean 2023-24 D2, methods fitted)
| line | peril | method | developed | reported_adj | reported_raw |
|---|---|---|---|---|---|
| buildings | accidental_damage | freq_sev | 0.1377 | 0.1377 | 0.1377 |
| buildings | accidental_damage | tweedie | 0.1283 | 0.1283 | 0.1283 |
| buildings | escape_of_water | freq_sev | 0.0375 | 0.0375 | 0.0375 |
| buildings | escape_of_water | tweedie | 0.0352 | 0.0351 | 0.0351 |
| buildings | fire | freq_sev | 0.0180 | 0.0180 | 0.0180 |
| buildings | fire | tweedie | -0.0029 | -0.0028 | -0.0028 |
| buildings | flood | freq_sev | 0.4566 | 0.4566 | 0.4566 |
| buildings | flood | tweedie | 0.2905 | 0.2909 | 0.2909 |
| buildings | storm | freq_sev | 0.0576 | 0.0574 | 0.0574 |
| buildings | storm | tweedie | 0.0571 | 0.0570 | 0.0570 |
| buildings | subsidence | freq_sev | 0.0713 | 0.0696 | 0.0696 |
| buildings | subsidence | tweedie | 0.0591 | 0.0574 | 0.0574 |
| contents | accidental_damage | freq_sev | 0.1416 | 0.1416 | 0.1416 |
| contents | accidental_damage | tweedie | 0.1388 | 0.1388 | 0.1388 |
| contents | escape_of_water | freq_sev | 0.0330 | 0.0329 | 0.0329 |
| contents | escape_of_water | tweedie | 0.0324 | 0.0323 | 0.0323 |
| contents | flood | freq_sev | 0.4387 | 0.4388 | 0.4388 |
| contents | flood | tweedie | 0.3489 | 0.3493 | 0.3493 |
| contents | theft | freq_sev | 0.0335 | 0.0335 | 0.0335 |
| contents | theft | tweedie | 0.0268 | 0.0268 | 0.0268 |
| motor | bodily_injury | freq_sev | 0.0438 | 0.0087 | 0.0126 |
| motor | bodily_injury | tweedie | 0.0528 | 0.0334 | 0.0424 |
| motor | glass_hail | freq_sev | 0.1373 | 0.1372 | 0.1372 |
| motor | glass_hail | tweedie | 0.1361 | 0.1360 | 0.1360 |
| motor | own_damage | freq_sev | 0.1645 | 0.1644 | 0.1644 |
| motor | own_damage | tweedie | 0.1676 | 0.1674 | 0.1674 |
| motor | theft | freq_sev | 0.0693 | 0.0693 | 0.0694 |
| motor | theft | tweedie | 0.0633 | 0.0633 | 0.0634 |
| motor | third_party_prop | freq_sev | 0.0572 | 0.0570 | 0.0570 |
| motor | third_party_prop | tweedie | 0.0544 | 0.0544 | 0.0544 |

### Method mix
| line | peril | method | own_pick_developed | own_pick_reported_raw |
|---|---|---|---|---|
| buildings | accidental_damage | freq_sev | freq_sev | freq_sev |
| buildings | escape_of_water | freq_sev | freq_sev | freq_sev |
| buildings | fire | freq_sev | freq_sev | freq_sev |
| buildings | flood | freq_sev | freq_sev | freq_sev |
| buildings | storm | freq_sev | freq_sev | freq_sev |
| buildings | subsidence | freq_sev | freq_sev | freq_sev |
| contents | accidental_damage | freq_sev | freq_sev | freq_sev |
| contents | escape_of_water | tweedie | freq_sev | freq_sev |
| contents | flood | freq_sev | freq_sev | freq_sev |
| contents | theft | freq_sev | freq_sev | freq_sev |
| motor | bodily_injury | tweedie | tweedie | tweedie |
| motor | glass_hail | freq_sev | freq_sev | freq_sev |
| motor | own_damage | tweedie | tweedie | tweedie |
| motor | theft | freq_sev | freq_sev | freq_sev |
| motor | third_party_prop | freq_sev | freq_sev | freq_sev |

## Notes
- Developed actuals use the A0 report share for every variant, so the three bases are identical across WENDY 7 runs.
- In the 2023 fold the training rows (2021-22) are almost fully reported under every method, so IBNR variants move
  mostly the 2024 fold and the final 2025 fit.
- Run time 3.3 minutes.
