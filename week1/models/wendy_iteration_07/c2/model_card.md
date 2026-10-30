# WENDY 7 (c2) - WENDY 4 engine, IBNR method `chain_ladder`

**Run id** `20261022_1946` | **Workbook** `docs/assumptions_wendy07.xlsx` (MD5 `5abce31f2e80de61169720c5475ab7e2`) | **Method mix** `output/4_check_reported/4_models_iterwendy04/chosen_method.csv` | **2025 file** `submission_20261022_1946_wendy07_c2.csv` (MD5 `e7aaf8b0e9862700789602808f7c48ec`, not submitted)

## Local protocol: line D2 (Tweedie p = 1.5) on three actual bases
| basis | valid_year | motor | buildings | contents | ALL |
|---|---|---|---|---|---|
| developed | 2023 | 0.0525 | 0.0712 | 0.0707 | 0.1063 |
| developed | 2024 | 0.0551 | 0.0716 | 0.0636 | 0.1046 |
| reported_adj | 2023 | 0.0520 | 0.0714 | 0.0707 | 0.1054 |
| reported_adj | 2024 | 0.0472 | 0.0730 | 0.0635 | 0.0977 |
| reported_raw | 2023 | 0.0439 | 0.0714 | 0.0707 | 0.1048 |
| reported_raw | 2024 | 0.0487 | 0.0730 | 0.0635 | 0.0988 |

Mean of 2023 and 2024 (primary score = reported_raw, ALL):

| basis | line | mean_d2 | d2_2023 | d2_2024 | pred_vs_actual_2024 |
|---|---|---|---|---|---|
| developed | ALL | 0.1055 | 0.1063 | 0.1046 | 1.0465 |
| developed | buildings | 0.0714 | 0.0712 | 0.0716 | 0.9808 |
| developed | contents | 0.0672 | 0.0707 | 0.0636 | 1.0023 |
| developed | motor | 0.0538 | 0.0525 | 0.0551 | 1.0994 |
| reported_adj | ALL | 0.1016 | 0.1054 | 0.0977 | 1.1399 |
| reported_adj | buildings | 0.0722 | 0.0714 | 0.0730 | 1.0229 |
| reported_adj | contents | 0.0671 | 0.0707 | 0.0635 | 1.0083 |
| reported_adj | motor | 0.0496 | 0.0520 | 0.0472 | 1.2540 |
| reported_raw | ALL | 0.1018 | 0.1048 | 0.0988 | 1.1311 |
| reported_raw | buildings | 0.0722 | 0.0714 | 0.0730 | 1.0229 |
| reported_raw | contents | 0.0671 | 0.0707 | 0.0635 | 1.0083 |
| reported_raw | motor | 0.0463 | 0.0439 | 0.0487 | 1.2352 |

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
| buildings | accidental_damage | freq_sev | 0.1383 | 0.1384 | 0.1384 |
| buildings | accidental_damage | tweedie | 0.1286 | 0.1287 | 0.1287 |
| buildings | escape_of_water | freq_sev | 0.0376 | 0.0375 | 0.0375 |
| buildings | escape_of_water | tweedie | 0.0352 | 0.0351 | 0.0351 |
| buildings | fire | freq_sev | 0.0180 | 0.0181 | 0.0181 |
| buildings | fire | tweedie | -0.0029 | -0.0028 | -0.0028 |
| buildings | flood | freq_sev | 0.4567 | 0.4566 | 0.4566 |
| buildings | flood | tweedie | 0.2905 | 0.2909 | 0.2909 |
| buildings | storm | freq_sev | 0.0575 | 0.0574 | 0.0574 |
| buildings | storm | tweedie | 0.0574 | 0.0572 | 0.0572 |
| buildings | subsidence | freq_sev | 0.0715 | 0.0697 | 0.0697 |
| buildings | subsidence | tweedie | 0.0589 | 0.0573 | 0.0573 |
| contents | accidental_damage | freq_sev | 0.1416 | 0.1416 | 0.1416 |
| contents | accidental_damage | tweedie | 0.1388 | 0.1388 | 0.1388 |
| contents | escape_of_water | freq_sev | 0.0330 | 0.0329 | 0.0329 |
| contents | escape_of_water | tweedie | 0.0324 | 0.0323 | 0.0323 |
| contents | flood | freq_sev | 0.4384 | 0.4385 | 0.4385 |
| contents | flood | tweedie | 0.3489 | 0.3494 | 0.3494 |
| contents | theft | freq_sev | 0.0335 | 0.0335 | 0.0335 |
| contents | theft | tweedie | 0.0267 | 0.0268 | 0.0268 |
| motor | bodily_injury | freq_sev | 0.0429 | 0.0069 | 0.0107 |
| motor | bodily_injury | tweedie | 0.0519 | 0.0295 | 0.0372 |
| motor | glass_hail | freq_sev | 0.1374 | 0.1373 | 0.1373 |
| motor | glass_hail | tweedie | 0.1361 | 0.1361 | 0.1361 |
| motor | own_damage | freq_sev | 0.1645 | 0.1643 | 0.1643 |
| motor | own_damage | tweedie | 0.1676 | 0.1675 | 0.1675 |
| motor | theft | freq_sev | 0.0691 | 0.0691 | 0.0692 |
| motor | theft | tweedie | 0.0633 | 0.0633 | 0.0634 |
| motor | third_party_prop | freq_sev | 0.0572 | 0.0570 | 0.0570 |
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
| contents | escape_of_water | tweedie | freq_sev | freq_sev |
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
| motor | 254,986 | 199,983.58 | 109,079,618.37 | 545.44 | 375.52 | 775.98 | 1,601.03 | 6,480.35 |
| buildings | 184,155 | 150,243.90 | 73,412,908.44 | 488.62 | 306.39 | 697.70 | 2,318.11 | 15,957.27 |
| contents | 187,498 | 150,123.77 | 18,963,299.65 | 126.32 | 80.21 | 177.80 | 550.89 | 2,919.58 |

| line | peril | method | predicted_total | predicted_burn |
|---|---|---|---|---|
| motor | own_damage | tweedie | 23,416,449.34 | 117.09 |
| motor | third_party_prop | freq_sev | 36,012,465.59 | 180.08 |
| motor | bodily_injury | tweedie | 34,843,346.88 | 174.23 |
| motor | theft | freq_sev | 9,808,550.16 | 49.05 |
| motor | glass_hail | freq_sev | 4,998,806.40 | 25.00 |
| buildings | storm | freq_sev | 9,102,840.54 | 60.59 |
| buildings | flood | freq_sev | 20,091,363.96 | 133.72 |
| buildings | escape_of_water | freq_sev | 18,742,890.56 | 124.75 |
| buildings | subsidence | freq_sev | 9,240,832.57 | 61.51 |
| buildings | fire | freq_sev | 14,942,529.33 | 99.46 |
| buildings | accidental_damage | freq_sev | 1,292,451.48 | 8.60 |
| contents | theft | freq_sev | 8,177,692.30 | 54.47 |
| contents | escape_of_water | tweedie | 4,153,749.61 | 27.67 |
| contents | accidental_damage | freq_sev | 2,002,745.19 | 13.34 |
| contents | flood | freq_sev | 4,629,112.55 | 30.84 |

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
- Run time 7.2 minutes.
