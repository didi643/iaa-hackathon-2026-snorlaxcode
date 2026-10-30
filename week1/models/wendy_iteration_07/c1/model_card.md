# WENDY 7 (c1) - WENDY 4 engine, IBNR method `chain_ladder`

**Run id** `20261022_1937` | **Workbook** `docs/assumptions_wendy07.xlsx` (MD5 `5abce31f2e80de61169720c5475ab7e2`) | **Method mix** `output/4_check_reported/4_models_iterwendy04/chosen_method.csv` | **2025 file** `submission_20261022_1937_wendy07_c1.csv` (MD5 `774a00ba5d63995a850fac35c3a10705`, not submitted)

## Local protocol: line D2 (Tweedie p = 1.5) on three actual bases
| basis | valid_year | motor | buildings | contents | ALL |
|---|---|---|---|---|---|
| developed | 2023 | 0.0520 | 0.0709 | 0.0709 | 0.1060 |
| developed | 2024 | 0.0576 | 0.0711 | 0.0634 | 0.1055 |
| reported_adj | 2023 | 0.0515 | 0.0710 | 0.0709 | 0.1051 |
| reported_adj | 2024 | 0.0500 | 0.0726 | 0.0633 | 0.0987 |
| reported_raw | 2023 | 0.0428 | 0.0710 | 0.0709 | 0.1042 |
| reported_raw | 2024 | 0.0515 | 0.0726 | 0.0633 | 0.0998 |

Mean of 2023 and 2024 (primary score = reported_raw, ALL):

| basis | line | mean_d2 | d2_2023 | d2_2024 | pred_vs_actual_2024 |
|---|---|---|---|---|---|
| developed | ALL | 0.1057 | 0.1060 | 0.1055 | 1.0405 |
| developed | buildings | 0.0710 | 0.0709 | 0.0711 | 0.9716 |
| developed | contents | 0.0671 | 0.0709 | 0.0634 | 1.0032 |
| developed | motor | 0.0548 | 0.0520 | 0.0576 | 1.0945 |
| reported_adj | ALL | 0.1019 | 0.1051 | 0.0987 | 1.1334 |
| reported_adj | buildings | 0.0718 | 0.0710 | 0.0726 | 1.0134 |
| reported_adj | contents | 0.0671 | 0.0709 | 0.0633 | 1.0092 |
| reported_adj | motor | 0.0507 | 0.0515 | 0.0500 | 1.2483 |
| reported_raw | ALL | 0.1020 | 0.1042 | 0.0998 | 1.1247 |
| reported_raw | buildings | 0.0718 | 0.0710 | 0.0726 | 1.0134 |
| reported_raw | contents | 0.0671 | 0.0709 | 0.0633 | 1.0092 |
| reported_raw | motor | 0.0471 | 0.0428 | 0.0515 | 1.2296 |

## Reported share by policy year (exposure-weighted; A0 = WENDY 4 mid-date ECDF)
| line | peril | 2021 | 2022 | 2023 | 2024 |
|---|---|---|---|---|---|
| buildings | accidental_damage | 1 | 1 | 0.999 | 0.973 |
| buildings | escape_of_water | 1 | 1 | 0.999 | 0.960 |
| buildings | fire | 1 | 1 | 0.999 | 0.985 |
| buildings | flood | 1 | 1 | 0.999 | 0.969 |
| buildings | storm | 1 | 1 | 0.999 | 0.969 |
| buildings | subsidence | 1 | 1.000 | 0.999 | 0.891 |
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
| buildings | subsidence | 0.751 | 0.670 | 1.493 |
| buildings | fire | 0.996 | 0.981 | 1.019 |
| buildings | accidental_damage | 0.996 | 0.969 | 1.032 |
| contents | theft | 0.997 | 0.982 | 1.018 |
| contents | escape_of_water | 0.992 | 0.950 | 1.053 |
| contents | accidental_damage | 0.995 | 0.966 | 1.035 |
| contents | flood | 0.989 | 0.964 | 1.038 |

## By peril (mean 2023-24 D2, methods fitted)
| line | peril | method | developed | reported_adj | reported_raw |
|---|---|---|---|---|---|
| buildings | accidental_damage | freq_sev | 0.1375 | 0.1376 | 0.1376 |
| buildings | accidental_damage | tweedie | 0.1264 | 0.1265 | 0.1265 |
| buildings | escape_of_water | freq_sev | 0.0389 | 0.0389 | 0.0389 |
| buildings | escape_of_water | tweedie | 0.0324 | 0.0324 | 0.0324 |
| buildings | fire | freq_sev | 0.0125 | 0.0126 | 0.0126 |
| buildings | fire | tweedie | 0.0055 | 0.0056 | 0.0056 |
| buildings | flood | freq_sev | 0.4561 | 0.4561 | 0.4561 |
| buildings | flood | tweedie | -0.0283 | -0.0268 | -0.0268 |
| buildings | storm | freq_sev | 0.0572 | 0.0570 | 0.0570 |
| buildings | storm | tweedie | 0.0557 | 0.0555 | 0.0555 |
| buildings | subsidence | freq_sev | 0.0707 | 0.0695 | 0.0695 |
| buildings | subsidence | tweedie | 0.0600 | 0.0583 | 0.0583 |
| contents | accidental_damage | freq_sev | 0.1417 | 0.1417 | 0.1417 |
| contents | accidental_damage | tweedie | 0.1397 | 0.1397 | 0.1397 |
| contents | escape_of_water | freq_sev | 0.0331 | 0.0331 | 0.0331 |
| contents | escape_of_water | tweedie | 0.0338 | 0.0337 | 0.0337 |
| contents | flood | freq_sev | 0.4372 | 0.4373 | 0.4373 |
| contents | flood | tweedie | 0.3157 | 0.3164 | 0.3164 |
| contents | theft | freq_sev | 0.0330 | 0.0330 | 0.0330 |
| contents | theft | tweedie | 0.0270 | 0.0270 | 0.0270 |
| motor | bodily_injury | freq_sev | 0.0463 | 0.0101 | 0.0155 |
| motor | bodily_injury | tweedie | 0.0557 | 0.0348 | 0.0419 |
| motor | glass_hail | freq_sev | 0.1379 | 0.1378 | 0.1378 |
| motor | glass_hail | tweedie | 0.1367 | 0.1366 | 0.1366 |
| motor | own_damage | freq_sev | 0.1651 | 0.1650 | 0.1650 |
| motor | own_damage | tweedie | 0.1681 | 0.1679 | 0.1680 |
| motor | theft | freq_sev | 0.0689 | 0.0689 | 0.0690 |
| motor | theft | tweedie | 0.0630 | 0.0630 | 0.0631 |
| motor | third_party_prop | freq_sev | 0.0576 | 0.0575 | 0.0575 |
| motor | third_party_prop | tweedie | 0.0554 | 0.0553 | 0.0553 |

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

## 2025 predictions
| line | rows | exposure | predicted_total | predicted_burn | p50 | p90 | p99 | max |
|---|---|---|---|---|---|---|---|---|
| motor | 254,986 | 199,983.58 | 110,593,697.51 | 553.01 | 368.84 | 801.72 | 1,737.86 | 6,325.84 |
| buildings | 184,155 | 150,243.90 | 73,237,058.18 | 487.45 | 305.63 | 692.56 | 2,320.96 | 17,460.46 |
| contents | 187,498 | 150,123.77 | 18,772,118.00 | 125.04 | 80.02 | 175.70 | 538.39 | 2,857.35 |

| line | peril | method | predicted_total | predicted_burn |
|---|---|---|---|---|
| motor | own_damage | tweedie | 23,575,351.72 | 117.89 |
| motor | third_party_prop | freq_sev | 36,262,142.93 | 181.33 |
| motor | bodily_injury | tweedie | 35,962,681.41 | 179.83 |
| motor | theft | freq_sev | 9,816,345.60 | 49.09 |
| motor | glass_hail | freq_sev | 4,977,175.85 | 24.89 |
| buildings | storm | freq_sev | 8,872,665.37 | 59.06 |
| buildings | flood | freq_sev | 20,273,385.69 | 134.94 |
| buildings | escape_of_water | freq_sev | 18,859,828.23 | 125.53 |
| buildings | subsidence | freq_sev | 9,130,804.40 | 60.77 |
| buildings | fire | freq_sev | 14,811,672.36 | 98.58 |
| buildings | accidental_damage | freq_sev | 1,288,702.13 | 8.58 |
| contents | theft | freq_sev | 8,127,531.81 | 54.14 |
| contents | escape_of_water | tweedie | 4,003,435.63 | 26.67 |
| contents | accidental_damage | freq_sev | 1,997,823.15 | 13.31 |
| contents | flood | freq_sev | 4,643,327.41 | 30.93 |

## Replication check (saved models reloaded)
| line | rows | max_abs_diff |
|---|---|---|
| motor | 254,986 | 0 |
| buildings | 184,155 | 0 |
| contents | 187,498 | 0 |

## Notes
- Developed actuals use the A0 report share for every variant, so the three bases are identical across WENDY 7 runs.
- In the 2023 fold the training rows (2021-22) are almost fully reported under every method, so IBNR variants move
  mostly the 2024 fold and the final 2025 fit.
- Run time 7.7 minutes.
