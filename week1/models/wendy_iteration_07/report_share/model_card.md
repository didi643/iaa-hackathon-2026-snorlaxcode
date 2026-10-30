# WENDY 7 (report_share) - WENDY 4 engine, IBNR method `report_share`

**Run id** `20261022_1854` | **Workbook** `docs/assumptions_wendy07.xlsx` (MD5 `5abce31f2e80de61169720c5475ab7e2`) | **Method mix** `output/4_check_reported/4_models_iterwendy04/chosen_method.csv` | validation only (FINAL_FIT=0)

## Local protocol: line D2 (Tweedie p = 1.5) on three actual bases
| basis | valid_year | motor | buildings | contents | ALL |
|---|---|---|---|---|---|
| developed | 2023 | 0.0518 | 0.0706 | 0.0709 | 0.1058 |
| developed | 2024 | 0.0551 | 0.0710 | 0.0636 | 0.1044 |
| reported_adj | 2023 | 0.0514 | 0.0708 | 0.0709 | 0.1050 |
| reported_adj | 2024 | 0.0474 | 0.0724 | 0.0635 | 0.0976 |
| reported_raw | 2023 | 0.0426 | 0.0708 | 0.0709 | 0.1041 |
| reported_raw | 2024 | 0.0489 | 0.0724 | 0.0635 | 0.0987 |

Mean of 2023 and 2024 (primary score = reported_raw, ALL):

| basis | line | mean_d2 | d2_2023 | d2_2024 | pred_vs_actual_2024 |
|---|---|---|---|---|---|
| developed | ALL | 0.1051 | 0.1058 | 0.1044 | 1.0424 |
| developed | buildings | 0.0708 | 0.0706 | 0.0710 | 0.9766 |
| developed | contents | 0.0673 | 0.0709 | 0.0636 | 1.0055 |
| developed | motor | 0.0534 | 0.0518 | 0.0551 | 1.0941 |
| reported_adj | ALL | 0.1013 | 0.1050 | 0.0976 | 1.1354 |
| reported_adj | buildings | 0.0716 | 0.0708 | 0.0724 | 1.0185 |
| reported_adj | contents | 0.0672 | 0.0709 | 0.0635 | 1.0114 |
| reported_adj | motor | 0.0494 | 0.0514 | 0.0474 | 1.2479 |
| reported_raw | ALL | 0.1014 | 0.1041 | 0.0987 | 1.1266 |
| reported_raw | buildings | 0.0716 | 0.0708 | 0.0724 | 1.0185 |
| reported_raw | contents | 0.0672 | 0.0709 | 0.0635 | 1.0114 |
| reported_raw | motor | 0.0458 | 0.0426 | 0.0489 | 1.2292 |

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
| buildings | accidental_damage | freq_sev | 0.1381 | 0.1382 | 0.1382 |
| buildings | accidental_damage | tweedie | 0.1280 | 0.1281 | 0.1281 |
| buildings | escape_of_water | freq_sev | 0.0379 | 0.0379 | 0.0379 |
| buildings | escape_of_water | tweedie | 0.0335 | 0.0336 | 0.0336 |
| buildings | fire | freq_sev | 0.0127 | 0.0127 | 0.0127 |
| buildings | fire | tweedie | 0.0115 | 0.0116 | 0.0116 |
| buildings | flood | freq_sev | 0.4548 | 0.4548 | 0.4548 |
| buildings | flood | tweedie | 0.2814 | 0.2820 | 0.2820 |
| buildings | storm | freq_sev | 0.0576 | 0.0574 | 0.0574 |
| buildings | storm | tweedie | 0.0561 | 0.0559 | 0.0559 |
| buildings | subsidence | freq_sev | 0.0718 | 0.0704 | 0.0704 |
| buildings | subsidence | tweedie | 0.0572 | 0.0558 | 0.0558 |
| contents | accidental_damage | freq_sev | 0.1420 | 0.1420 | 0.1420 |
| contents | accidental_damage | tweedie | 0.1379 | 0.1379 | 0.1379 |
| contents | escape_of_water | freq_sev | 0.0336 | 0.0335 | 0.0335 |
| contents | escape_of_water | tweedie | 0.0346 | 0.0345 | 0.0345 |
| contents | flood | freq_sev | 0.4370 | 0.4371 | 0.4371 |
| contents | flood | tweedie | 0.2533 | 0.2542 | 0.2542 |
| contents | theft | freq_sev | 0.0337 | 0.0337 | 0.0337 |
| contents | theft | tweedie | 0.0276 | 0.0277 | 0.0277 |
| motor | bodily_injury | freq_sev | 0.0432 | 0.0080 | 0.0103 |
| motor | bodily_injury | tweedie | 0.0517 | 0.0299 | 0.0370 |
| motor | glass_hail | freq_sev | 0.1372 | 0.1371 | 0.1371 |
| motor | glass_hail | tweedie | 0.1362 | 0.1361 | 0.1361 |
| motor | own_damage | freq_sev | 0.1646 | 0.1644 | 0.1644 |
| motor | own_damage | tweedie | 0.1677 | 0.1675 | 0.1675 |
| motor | theft | freq_sev | 0.0701 | 0.0701 | 0.0702 |
| motor | theft | tweedie | 0.0648 | 0.0648 | 0.0649 |
| motor | third_party_prop | freq_sev | 0.0570 | 0.0570 | 0.0570 |
| motor | third_party_prop | tweedie | 0.0542 | 0.0542 | 0.0542 |

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
| contents | escape_of_water | tweedie | tweedie | tweedie |
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
- Run time 3.4 minutes.
