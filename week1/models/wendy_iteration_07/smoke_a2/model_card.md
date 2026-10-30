# WENDY 7 (smoke_a2) - WENDY 4 engine, IBNR method `chain_ladder`

**Run id** `20261022_1851` | **Workbook** `docs/assumptions_wendy07.xlsx` (MD5 `5abce31f2e80de61169720c5475ab7e2`) | **Method mix** `output/4_check_reported/4_models_iterwendy04/chosen_method.csv` | **FAST mode - not for submission** | validation only (FINAL_FIT=0)

## Local protocol: line D2 (Tweedie p = 1.5) on three actual bases
| basis | valid_year | motor | buildings | contents | ALL |
|---|---|---|---|---|---|
| developed | 2023 | 0.0508 | 0.0711 | 0.0714 | 0.1056 |
| developed | 2024 | 0.0548 | 0.0712 | 0.0642 | 0.1045 |
| reported_adj | 2023 | 0.0503 | 0.0713 | 0.0714 | 0.1047 |
| reported_adj | 2024 | 0.0471 | 0.0726 | 0.0640 | 0.0976 |
| reported_raw | 2023 | 0.0400 | 0.0713 | 0.0714 | 0.1031 |
| reported_raw | 2024 | 0.0485 | 0.0726 | 0.0640 | 0.0987 |

Mean of 2023 and 2024 (primary score = reported_raw, ALL):

| basis | line | mean_d2 | d2_2023 | d2_2024 | pred_vs_actual_2024 |
|---|---|---|---|---|---|
| developed | ALL | 0.1050 | 0.1056 | 0.1045 | 1.0442 |
| developed | buildings | 0.0711 | 0.0711 | 0.0712 | 0.9756 |
| developed | contents | 0.0678 | 0.0714 | 0.0642 | 1.0075 |
| developed | motor | 0.0528 | 0.0508 | 0.0548 | 1.0979 |
| reported_adj | ALL | 0.1012 | 0.1047 | 0.0976 | 1.1375 |
| reported_adj | buildings | 0.0719 | 0.0713 | 0.0726 | 1.0175 |
| reported_adj | contents | 0.0677 | 0.0714 | 0.0640 | 1.0135 |
| reported_adj | motor | 0.0487 | 0.0503 | 0.0471 | 1.2522 |
| reported_raw | ALL | 0.1009 | 0.1031 | 0.0987 | 1.1287 |
| reported_raw | buildings | 0.0719 | 0.0713 | 0.0726 | 1.0175 |
| reported_raw | contents | 0.0677 | 0.0714 | 0.0640 | 1.0135 |
| reported_raw | motor | 0.0443 | 0.0400 | 0.0485 | 1.2335 |

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
| buildings | accidental_damage | freq_sev | 0.1370 | 0.1371 | 0.1371 |
| buildings | accidental_damage | tweedie | 0.1260 | 0.1261 | 0.1261 |
| buildings | escape_of_water | freq_sev | 0.0367 | 0.0367 | 0.0367 |
| buildings | escape_of_water | tweedie | 0.0337 | 0.0339 | 0.0339 |
| buildings | fire | freq_sev | 0.0157 | 0.0157 | 0.0157 |
| buildings | fire | tweedie | -0.0024 | -0.0023 | -0.0023 |
| buildings | flood | freq_sev | 0.4532 | 0.4532 | 0.4532 |
| buildings | flood | tweedie | 0.2854 | 0.2859 | 0.2859 |
| buildings | storm | freq_sev | 0.0575 | 0.0573 | 0.0573 |
| buildings | storm | tweedie | 0.0564 | 0.0562 | 0.0562 |
| buildings | subsidence | freq_sev | 0.0716 | 0.0696 | 0.0696 |
| buildings | subsidence | tweedie | 0.0581 | 0.0578 | 0.0578 |
| contents | accidental_damage | freq_sev | 0.1411 | 0.1411 | 0.1411 |
| contents | accidental_damage | tweedie | 0.1370 | 0.1370 | 0.1370 |
| contents | escape_of_water | freq_sev | 0.0321 | 0.0320 | 0.0320 |
| contents | escape_of_water | tweedie | 0.0330 | 0.0329 | 0.0329 |
| contents | flood | freq_sev | 0.4369 | 0.4370 | 0.4370 |
| contents | flood | tweedie | 0.3259 | 0.3265 | 0.3265 |
| contents | theft | freq_sev | 0.0338 | 0.0338 | 0.0338 |
| contents | theft | tweedie | 0.0248 | 0.0249 | 0.0249 |
| motor | bodily_injury | freq_sev | 0.0431 | 0.0075 | 0.0104 |
| motor | bodily_injury | tweedie | 0.0486 | 0.0268 | 0.0326 |
| motor | glass_hail | freq_sev | 0.1374 | 0.1373 | 0.1373 |
| motor | glass_hail | tweedie | 0.1359 | 0.1358 | 0.1358 |
| motor | own_damage | freq_sev | 0.1643 | 0.1641 | 0.1641 |
| motor | own_damage | tweedie | 0.1670 | 0.1669 | 0.1670 |
| motor | theft | freq_sev | 0.0713 | 0.0713 | 0.0714 |
| motor | theft | tweedie | 0.0627 | 0.0627 | 0.0629 |
| motor | third_party_prop | freq_sev | 0.0572 | 0.0571 | 0.0571 |
| motor | third_party_prop | tweedie | 0.0537 | 0.0537 | 0.0537 |

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
- Run time 3.1 minutes.
