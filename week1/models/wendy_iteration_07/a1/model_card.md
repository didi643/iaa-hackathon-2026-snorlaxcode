# WENDY 7 (a1) - WENDY 4 engine, IBNR method `report_share_days`

**Run id** `20261022_1904` | **Workbook** `docs/assumptions_wendy07.xlsx` (MD5 `5abce31f2e80de61169720c5475ab7e2`) | **Method mix** `output/4_check_reported/4_models_iterwendy04/chosen_method.csv` | validation only (FINAL_FIT=0)

## Local protocol: line D2 (Tweedie p = 1.5) on three actual bases
| basis | valid_year | motor | buildings | contents | ALL |
|---|---|---|---|---|---|
| developed | 2023 | 0.0518 | 0.0706 | 0.0709 | 0.1058 |
| developed | 2024 | 0.0552 | 0.0712 | 0.0636 | 0.1045 |
| reported_adj | 2023 | 0.0514 | 0.0708 | 0.0709 | 0.1049 |
| reported_adj | 2024 | 0.0475 | 0.0726 | 0.0634 | 0.0977 |
| reported_raw | 2023 | 0.0426 | 0.0708 | 0.0709 | 0.1041 |
| reported_raw | 2024 | 0.0490 | 0.0726 | 0.0634 | 0.0987 |

Mean of 2023 and 2024 (primary score = reported_raw, ALL):

| basis | line | mean_d2 | d2_2023 | d2_2024 | pred_vs_actual_2024 |
|---|---|---|---|---|---|
| developed | ALL | 0.1052 | 0.1058 | 0.1045 | 1.0437 |
| developed | buildings | 0.0709 | 0.0706 | 0.0712 | 0.9778 |
| developed | contents | 0.0672 | 0.0709 | 0.0636 | 1.0059 |
| developed | motor | 0.0535 | 0.0518 | 0.0552 | 1.0958 |
| reported_adj | ALL | 0.1013 | 0.1049 | 0.0977 | 1.1369 |
| reported_adj | buildings | 0.0717 | 0.0708 | 0.0726 | 1.0198 |
| reported_adj | contents | 0.0672 | 0.0709 | 0.0634 | 1.0119 |
| reported_adj | motor | 0.0494 | 0.0514 | 0.0475 | 1.2498 |
| reported_raw | ALL | 0.1014 | 0.1041 | 0.0987 | 1.1281 |
| reported_raw | buildings | 0.0717 | 0.0708 | 0.0726 | 1.0198 |
| reported_raw | contents | 0.0672 | 0.0709 | 0.0634 | 1.0119 |
| reported_raw | motor | 0.0458 | 0.0426 | 0.0490 | 1.2311 |

## Reported share by policy year (exposure-weighted; A0 = WENDY 4 mid-date ECDF)
| line | peril | 2021 | 2022 | 2023 | 2024 |
|---|---|---|---|---|---|
| buildings | accidental_damage | 1 | 1 | 0.999 | 0.975 |
| buildings | escape_of_water | 1 | 1 | 0.999 | 0.962 |
| buildings | fire | 1 | 1 | 0.999 | 0.988 |
| buildings | flood | 1 | 1 | 0.999 | 0.974 |
| buildings | storm | 1 | 1 | 0.999 | 0.974 |
| buildings | subsidence | 1 | 1.000 | 0.999 | 0.891 |
| contents | accidental_damage | 1 | 1 | 0.999 | 0.974 |
| contents | escape_of_water | 1 | 1 | 0.999 | 0.963 |
| contents | flood | 1 | 1 | 0.998 | 0.975 |
| contents | theft | 1 | 1 | 0.999 | 0.988 |
| motor | bodily_injury | 1.000 | 0.999 | 0.992 | 0.910 |
| motor | glass_hail | 1 | 1 | 0.998 | 0.983 |
| motor | own_damage | 1 | 1 | 0.999 | 0.975 |
| motor | theft | 1 | 1 | 0.999 | 0.988 |
| motor | third_party_prop | 1 | 1 | 0.999 | 0.949 |

| line | peril | share_a0 | share | ibnr_factor |
|---|---|---|---|---|
| motor | own_damage | 0.996 | 0.971 | 1.030 |
| motor | third_party_prop | 0.992 | 0.942 | 1.062 |
| motor | bodily_injury | 0.626 | 0.569 | 1.756 |
| motor | theft | 0.996 | 0.984 | 1.016 |
| motor | glass_hail | 0.994 | 0.976 | 1.024 |
| buildings | storm | 0.995 | 0.969 | 1.032 |
| buildings | flood | 0.996 | 0.970 | 1.031 |
| buildings | escape_of_water | 0.994 | 0.956 | 1.046 |
| buildings | subsidence | 0.751 | 0.670 | 1.493 |
| buildings | fire | 0.996 | 0.984 | 1.016 |
| buildings | accidental_damage | 0.996 | 0.971 | 1.030 |
| contents | theft | 0.997 | 0.984 | 1.016 |
| contents | escape_of_water | 0.992 | 0.955 | 1.047 |
| contents | accidental_damage | 0.995 | 0.970 | 1.031 |
| contents | flood | 0.989 | 0.964 | 1.037 |

## By peril (mean 2023-24 D2, methods fitted)
| line | peril | method | developed | reported_adj | reported_raw |
|---|---|---|---|---|---|
| buildings | accidental_damage | freq_sev | 0.1382 | 0.1383 | 0.1383 |
| buildings | accidental_damage | tweedie | 0.1280 | 0.1281 | 0.1281 |
| buildings | escape_of_water | freq_sev | 0.0381 | 0.0380 | 0.0380 |
| buildings | escape_of_water | tweedie | 0.0337 | 0.0338 | 0.0338 |
| buildings | fire | freq_sev | 0.0127 | 0.0127 | 0.0127 |
| buildings | fire | tweedie | -0.0014 | -0.0013 | -0.0013 |
| buildings | flood | freq_sev | 0.4550 | 0.4550 | 0.4550 |
| buildings | flood | tweedie | 0.2814 | 0.2820 | 0.2820 |
| buildings | storm | freq_sev | 0.0576 | 0.0574 | 0.0574 |
| buildings | storm | tweedie | 0.0566 | 0.0565 | 0.0565 |
| buildings | subsidence | freq_sev | 0.0718 | 0.0704 | 0.0704 |
| buildings | subsidence | tweedie | 0.0596 | 0.0578 | 0.0578 |
| contents | accidental_damage | freq_sev | 0.1420 | 0.1420 | 0.1420 |
| contents | accidental_damage | tweedie | 0.1381 | 0.1380 | 0.1380 |
| contents | escape_of_water | freq_sev | 0.0336 | 0.0335 | 0.0335 |
| contents | escape_of_water | tweedie | 0.0346 | 0.0345 | 0.0345 |
| contents | flood | freq_sev | 0.4366 | 0.4368 | 0.4368 |
| contents | flood | tweedie | 0.2533 | 0.2543 | 0.2543 |
| contents | theft | freq_sev | 0.0337 | 0.0337 | 0.0337 |
| contents | theft | tweedie | 0.0267 | 0.0267 | 0.0267 |
| motor | bodily_injury | freq_sev | 0.0427 | 0.0070 | 0.0101 |
| motor | bodily_injury | tweedie | 0.0526 | 0.0307 | 0.0379 |
| motor | glass_hail | freq_sev | 0.1371 | 0.1370 | 0.1370 |
| motor | glass_hail | tweedie | 0.1361 | 0.1360 | 0.1360 |
| motor | own_damage | freq_sev | 0.1645 | 0.1644 | 0.1644 |
| motor | own_damage | tweedie | 0.1678 | 0.1676 | 0.1676 |
| motor | theft | freq_sev | 0.0700 | 0.0700 | 0.0701 |
| motor | theft | tweedie | 0.0648 | 0.0648 | 0.0649 |
| motor | third_party_prop | freq_sev | 0.0570 | 0.0570 | 0.0570 |
| motor | third_party_prop | tweedie | 0.0543 | 0.0543 | 0.0543 |

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
- Run time 18.6 minutes.
