# WENDY 7 (a2) - WENDY 4 engine, IBNR method `chain_ladder`

**Run id** `20261022_1923` | **Workbook** `docs/assumptions_wendy07.xlsx` (MD5 `5abce31f2e80de61169720c5475ab7e2`) | **Method mix** `output/4_check_reported/4_models_iterwendy04/chosen_method.csv` | validation only (FINAL_FIT=0)

## Local protocol: line D2 (Tweedie p = 1.5) on three actual bases
| basis | valid_year | motor | buildings | contents | ALL |
|---|---|---|---|---|---|
| developed | 2023 | 0.0518 | 0.0706 | 0.0709 | 0.1058 |
| developed | 2024 | 0.0550 | 0.0712 | 0.0636 | 0.1045 |
| reported_adj | 2023 | 0.0513 | 0.0708 | 0.0709 | 0.1049 |
| reported_adj | 2024 | 0.0473 | 0.0726 | 0.0634 | 0.0976 |
| reported_raw | 2023 | 0.0433 | 0.0708 | 0.0709 | 0.1044 |
| reported_raw | 2024 | 0.0488 | 0.0726 | 0.0634 | 0.0986 |

Mean of 2023 and 2024 (primary score = reported_raw, ALL):

| basis | line | mean_d2 | d2_2023 | d2_2024 | pred_vs_actual_2024 |
|---|---|---|---|---|---|
| developed | ALL | 0.1051 | 0.1058 | 0.1045 | 1.0448 |
| developed | buildings | 0.0709 | 0.0706 | 0.0712 | 0.9781 |
| developed | contents | 0.0672 | 0.0709 | 0.0636 | 1.0059 |
| developed | motor | 0.0534 | 0.0518 | 0.0550 | 1.0975 |
| reported_adj | ALL | 0.1013 | 0.1049 | 0.0976 | 1.1380 |
| reported_adj | buildings | 0.0717 | 0.0708 | 0.0726 | 1.0201 |
| reported_adj | contents | 0.0672 | 0.0709 | 0.0634 | 1.0119 |
| reported_adj | motor | 0.0493 | 0.0513 | 0.0473 | 1.2517 |
| reported_raw | ALL | 0.1015 | 0.1044 | 0.0986 | 1.1292 |
| reported_raw | buildings | 0.0717 | 0.0708 | 0.0726 | 1.0201 |
| reported_raw | contents | 0.0672 | 0.0709 | 0.0634 | 1.0119 |
| reported_raw | motor | 0.0460 | 0.0433 | 0.0488 | 1.2330 |

## Reported share by policy year (exposure-weighted; A0 = WENDY 4 mid-date ECDF)
| line | peril | 2021 | 2022 | 2023 | 2024 |
|---|---|---|---|---|---|
| buildings | accidental_damage | 1 | 1 | 0.999 | 0.973 |
| buildings | escape_of_water | 1 | 1 | 0.999 | 0.960 |
| buildings | fire | 1 | 1 | 0.999 | 0.985 |
| buildings | flood | 1 | 1 | 0.999 | 0.969 |
| buildings | storm | 1 | 1 | 0.999 | 0.969 |
| buildings | subsidence | 1 | 1.000 | 0.994 | 0.884 |
| contents | accidental_damage | 1 | 1 | 0.999 | 0.971 |
| contents | escape_of_water | 1 | 1 | 0.999 | 0.957 |
| contents | flood | 1 | 1 | 0.998 | 0.974 |
| contents | theft | 1 | 1 | 0.999 | 0.985 |
| motor | bodily_injury | 0.998 | 0.995 | 0.986 | 0.899 |
| motor | glass_hail | 1 | 1 | 0.999 | 0.980 |
| motor | own_damage | 1 | 1 | 0.999 | 0.972 |
| motor | theft | 1 | 1 | 0.999 | 0.985 |
| motor | third_party_prop | 1 | 1 | 0.999 | 0.946 |

| line | peril | share_a0 | share | ibnr_factor |
|---|---|---|---|---|
| motor | own_damage | 0.996 | 0.968 | 1.033 |
| motor | third_party_prop | 0.992 | 0.939 | 1.065 |
| motor | bodily_injury | 0.626 | 0.562 | 1.778 |
| motor | theft | 0.996 | 0.981 | 1.019 |
| motor | glass_hail | 0.994 | 0.974 | 1.027 |
| buildings | storm | 0.995 | 0.964 | 1.037 |
| buildings | flood | 0.996 | 0.965 | 1.036 |
| buildings | escape_of_water | 0.994 | 0.954 | 1.048 |
| buildings | subsidence | 0.751 | 0.665 | 1.505 |
| buildings | fire | 0.996 | 0.981 | 1.019 |
| buildings | accidental_damage | 0.996 | 0.969 | 1.032 |
| contents | theft | 0.997 | 0.982 | 1.018 |
| contents | escape_of_water | 0.992 | 0.950 | 1.053 |
| contents | accidental_damage | 0.995 | 0.966 | 1.035 |
| contents | flood | 0.989 | 0.964 | 1.038 |

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
| buildings | storm | freq_sev | 0.0576 | 0.0575 | 0.0575 |
| buildings | storm | tweedie | 0.0564 | 0.0563 | 0.0563 |
| buildings | subsidence | freq_sev | 0.0717 | 0.0702 | 0.0702 |
| buildings | subsidence | tweedie | 0.0594 | 0.0573 | 0.0573 |
| contents | accidental_damage | freq_sev | 0.1420 | 0.1420 | 0.1420 |
| contents | accidental_damage | tweedie | 0.1390 | 0.1390 | 0.1390 |
| contents | escape_of_water | freq_sev | 0.0336 | 0.0335 | 0.0335 |
| contents | escape_of_water | tweedie | 0.0346 | 0.0345 | 0.0345 |
| contents | flood | freq_sev | 0.4366 | 0.4368 | 0.4368 |
| contents | flood | tweedie | 0.2533 | 0.2543 | 0.2543 |
| contents | theft | freq_sev | 0.0337 | 0.0337 | 0.0337 |
| contents | theft | tweedie | 0.0267 | 0.0267 | 0.0267 |
| motor | bodily_injury | freq_sev | 0.0422 | 0.0062 | 0.0087 |
| motor | bodily_injury | tweedie | 0.0519 | 0.0296 | 0.0375 |
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
- Run time 3.5 minutes.
