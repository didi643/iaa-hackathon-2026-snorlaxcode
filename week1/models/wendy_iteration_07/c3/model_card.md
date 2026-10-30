# WENDY 7 (c3) - WENDY 4 engine, IBNR method `chain_ladder`

**Run id** `20261022_2004` | **Workbook** `docs/assumptions_wendy07.xlsx` (MD5 `5abce31f2e80de61169720c5475ab7e2`) | **Method mix** `output/4_check_reported/4_models_iterwendy04/chosen_method.csv` | **2025 file** `submission_20261022_2004_wendy07_c3.csv` (MD5 `ece44063891121eeaa1db72df8c1106c`, not submitted)

## Local protocol: line D2 (Tweedie p = 1.5) on three actual bases
| basis | valid_year | motor | buildings | contents | ALL |
|---|---|---|---|---|---|
| developed | 2023 | 0.0522 | 0.0723 | 0.0716 | 0.1066 |
| developed | 2024 | 0.0546 | 0.0721 | 0.0636 | 0.1046 |
| reported_adj | 2023 | 0.0517 | 0.0724 | 0.0716 | 0.1058 |
| reported_adj | 2024 | 0.0468 | 0.0734 | 0.0634 | 0.0977 |
| reported_raw | 2023 | 0.0424 | 0.0724 | 0.0716 | 0.1046 |
| reported_raw | 2024 | 0.0483 | 0.0734 | 0.0634 | 0.0987 |

Mean of 2023 and 2024 (primary score = reported_raw, ALL):

| basis | line | mean_d2 | d2_2023 | d2_2024 | pred_vs_actual_2024 |
|---|---|---|---|---|---|
| developed | ALL | 0.1056 | 0.1066 | 0.1046 | 1.0455 |
| developed | buildings | 0.0722 | 0.0723 | 0.0721 | 0.9813 |
| developed | contents | 0.0676 | 0.0716 | 0.0636 | 1.0035 |
| developed | motor | 0.0534 | 0.0522 | 0.0546 | 1.0971 |
| reported_adj | ALL | 0.1017 | 0.1058 | 0.0977 | 1.1389 |
| reported_adj | buildings | 0.0729 | 0.0724 | 0.0734 | 1.0235 |
| reported_adj | contents | 0.0675 | 0.0716 | 0.0634 | 1.0095 |
| reported_adj | motor | 0.0492 | 0.0517 | 0.0468 | 1.2513 |
| reported_raw | ALL | 0.1017 | 0.1046 | 0.0987 | 1.1301 |
| reported_raw | buildings | 0.0729 | 0.0724 | 0.0734 | 1.0235 |
| reported_raw | contents | 0.0675 | 0.0716 | 0.0634 | 1.0095 |
| reported_raw | motor | 0.0454 | 0.0424 | 0.0483 | 1.2325 |

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
| buildings | accidental_damage | freq_sev | 0.1394 | 0.1395 | 0.1395 |
| buildings | accidental_damage | tweedie | 0.1339 | 0.1339 | 0.1339 |
| buildings | escape_of_water | freq_sev | 0.0399 | 0.0398 | 0.0398 |
| buildings | escape_of_water | tweedie | 0.0376 | 0.0375 | 0.0375 |
| buildings | fire | freq_sev | 0.0233 | 0.0233 | 0.0233 |
| buildings | fire | tweedie | 0.0262 | 0.0262 | 0.0262 |
| buildings | flood | freq_sev | 0.4557 | 0.4557 | 0.4557 |
| buildings | flood | tweedie | 0.4433 | 0.4433 | 0.4433 |
| buildings | storm | freq_sev | 0.0580 | 0.0578 | 0.0578 |
| buildings | storm | tweedie | 0.0584 | 0.0582 | 0.0582 |
| buildings | subsidence | freq_sev | 0.0713 | 0.0698 | 0.0698 |
| buildings | subsidence | tweedie | 0.0691 | 0.0670 | 0.0670 |
| contents | accidental_damage | freq_sev | 0.1434 | 0.1433 | 0.1433 |
| contents | accidental_damage | tweedie | 0.1408 | 0.1408 | 0.1408 |
| contents | escape_of_water | freq_sev | 0.0351 | 0.0350 | 0.0350 |
| contents | escape_of_water | tweedie | 0.0356 | 0.0354 | 0.0354 |
| contents | flood | freq_sev | 0.4355 | 0.4356 | 0.4356 |
| contents | flood | tweedie | 0.3780 | 0.3784 | 0.3784 |
| contents | theft | freq_sev | 0.0339 | 0.0340 | 0.0340 |
| contents | theft | tweedie | 0.0294 | 0.0294 | 0.0294 |
| motor | bodily_injury | freq_sev | 0.0449 | 0.0090 | 0.0150 |
| motor | bodily_injury | tweedie | 0.0505 | 0.0274 | 0.0331 |
| motor | glass_hail | freq_sev | 0.1379 | 0.1378 | 0.1378 |
| motor | glass_hail | tweedie | 0.1366 | 0.1366 | 0.1366 |
| motor | own_damage | freq_sev | 0.1648 | 0.1647 | 0.1647 |
| motor | own_damage | tweedie | 0.1685 | 0.1684 | 0.1685 |
| motor | theft | freq_sev | 0.0712 | 0.0712 | 0.0713 |
| motor | theft | tweedie | 0.0694 | 0.0694 | 0.0695 |
| motor | third_party_prop | freq_sev | 0.0574 | 0.0573 | 0.0573 |
| motor | third_party_prop | tweedie | 0.0552 | 0.0551 | 0.0551 |

### Method mix
| line | peril | method | own_pick_developed | own_pick_reported_raw |
|---|---|---|---|---|
| buildings | accidental_damage | freq_sev | freq_sev | freq_sev |
| buildings | escape_of_water | freq_sev | freq_sev | freq_sev |
| buildings | fire | freq_sev | tweedie | tweedie |
| buildings | flood | freq_sev | freq_sev | freq_sev |
| buildings | storm | freq_sev | tweedie | tweedie |
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
| motor | 254,986 | 199,983.58 | 109,119,718.91 | 545.64 | 370.61 | 779.69 | 1,650.52 | 7,087.08 |
| buildings | 184,155 | 150,243.90 | 73,365,553.75 | 488.31 | 308.17 | 695.00 | 2,284.30 | 14,890.12 |
| contents | 187,498 | 150,123.77 | 18,933,567.93 | 126.12 | 79.39 | 180.43 | 548.83 | 2,846.58 |

| line | peril | method | predicted_total | predicted_burn |
|---|---|---|---|---|
| motor | own_damage | tweedie | 23,077,077.66 | 115.39 |
| motor | third_party_prop | freq_sev | 35,820,086.60 | 179.12 |
| motor | bodily_injury | tweedie | 35,389,926.54 | 176.96 |
| motor | theft | freq_sev | 9,838,533.42 | 49.20 |
| motor | glass_hail | freq_sev | 4,994,094.68 | 24.97 |
| buildings | storm | freq_sev | 9,033,794.03 | 60.13 |
| buildings | flood | freq_sev | 20,100,684.21 | 133.79 |
| buildings | escape_of_water | freq_sev | 18,809,879.76 | 125.20 |
| buildings | subsidence | freq_sev | 9,155,904.93 | 60.94 |
| buildings | fire | freq_sev | 14,966,846.79 | 99.62 |
| buildings | accidental_damage | freq_sev | 1,298,444.04 | 8.64 |
| contents | theft | freq_sev | 8,224,219.96 | 54.78 |
| contents | escape_of_water | tweedie | 4,089,985.80 | 27.24 |
| contents | accidental_damage | freq_sev | 2,005,420.28 | 13.36 |
| contents | flood | freq_sev | 4,613,941.90 | 30.73 |

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
- Run time 22.5 minutes.
