# WENDY 7 (b4) - WENDY 4 engine, IBNR method `report_share`

**Run id** `20261022_1931` | **Workbook** `docs/assumptions_wendy07.xlsx` (MD5 `5abce31f2e80de61169720c5475ab7e2`) | **Method mix** `output/4_check_reported/4_models_iterwendy04/chosen_method.csv` | validation only (FINAL_FIT=0)

## Local protocol: line D2 (Tweedie p = 1.5) on three actual bases
| basis | valid_year | motor | buildings | contents | ALL |
|---|---|---|---|---|---|
| developed | 2023 | 0.0520 | 0.0709 | 0.0711 | 0.1059 |
| developed | 2024 | 0.0573 | 0.0718 | 0.0632 | 0.1056 |
| reported_adj | 2023 | 0.0514 | 0.0710 | 0.0711 | 0.1051 |
| reported_adj | 2024 | 0.0498 | 0.0733 | 0.0631 | 0.0989 |
| reported_raw | 2023 | 0.0423 | 0.0710 | 0.0711 | 0.1040 |
| reported_raw | 2024 | 0.0513 | 0.0733 | 0.0631 | 0.0999 |

Mean of 2023 and 2024 (primary score = reported_raw, ALL):

| basis | line | mean_d2 | d2_2023 | d2_2024 | pred_vs_actual_2024 |
|---|---|---|---|---|---|
| developed | ALL | 0.1058 | 0.1059 | 0.1056 | 1.0373 |
| developed | buildings | 0.0713 | 0.0709 | 0.0718 | 0.9730 |
| developed | contents | 0.0672 | 0.0711 | 0.0632 | 1.0013 |
| developed | motor | 0.0546 | 0.0520 | 0.0573 | 1.0878 |
| reported_adj | ALL | 0.1020 | 0.1051 | 0.0989 | 1.1298 |
| reported_adj | buildings | 0.0722 | 0.0710 | 0.0733 | 1.0148 |
| reported_adj | contents | 0.0671 | 0.0711 | 0.0631 | 1.0072 |
| reported_adj | motor | 0.0506 | 0.0514 | 0.0498 | 1.2407 |
| reported_raw | ALL | 0.1020 | 0.1040 | 0.0999 | 1.1211 |
| reported_raw | buildings | 0.0722 | 0.0710 | 0.0733 | 1.0148 |
| reported_raw | contents | 0.0671 | 0.0711 | 0.0631 | 1.0072 |
| reported_raw | motor | 0.0468 | 0.0423 | 0.0513 | 1.2221 |

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
| buildings | accidental_damage | freq_sev | 0.1388 | 0.1389 | 0.1389 |
| buildings | accidental_damage | tweedie | 0.1262 | 0.1263 | 0.1263 |
| buildings | escape_of_water | freq_sev | 0.0383 | 0.0382 | 0.0382 |
| buildings | escape_of_water | tweedie | 0.0364 | 0.0364 | 0.0364 |
| buildings | fire | freq_sev | 0.0177 | 0.0177 | 0.0177 |
| buildings | fire | tweedie | -0.0179 | -0.0178 | -0.0178 |
| buildings | flood | freq_sev | 0.4558 | 0.4558 | 0.4558 |
| buildings | flood | tweedie | 0.3164 | 0.3168 | 0.3168 |
| buildings | storm | freq_sev | 0.0580 | 0.0578 | 0.0578 |
| buildings | storm | tweedie | 0.0566 | 0.0564 | 0.0564 |
| buildings | subsidence | freq_sev | 0.0713 | 0.0700 | 0.0700 |
| buildings | subsidence | tweedie | 0.0605 | 0.0592 | 0.0592 |
| contents | accidental_damage | freq_sev | 0.1425 | 0.1425 | 0.1425 |
| contents | accidental_damage | tweedie | 0.1412 | 0.1411 | 0.1411 |
| contents | escape_of_water | freq_sev | 0.0334 | 0.0333 | 0.0333 |
| contents | escape_of_water | tweedie | 0.0347 | 0.0345 | 0.0345 |
| contents | flood | freq_sev | 0.4347 | 0.4349 | 0.4349 |
| contents | flood | tweedie | 0.3229 | 0.3235 | 0.3235 |
| contents | theft | freq_sev | 0.0332 | 0.0332 | 0.0332 |
| contents | theft | tweedie | 0.0282 | 0.0282 | 0.0282 |
| motor | bodily_injury | freq_sev | 0.0440 | 0.0087 | 0.0107 |
| motor | bodily_injury | tweedie | 0.0543 | 0.0340 | 0.0410 |
| motor | glass_hail | freq_sev | 0.1375 | 0.1374 | 0.1374 |
| motor | glass_hail | tweedie | 0.1371 | 0.1370 | 0.1370 |
| motor | own_damage | freq_sev | 0.1652 | 0.1651 | 0.1650 |
| motor | own_damage | tweedie | 0.1680 | 0.1679 | 0.1679 |
| motor | theft | freq_sev | 0.0692 | 0.0692 | 0.0693 |
| motor | theft | tweedie | 0.0619 | 0.0619 | 0.0620 |
| motor | third_party_prop | freq_sev | 0.0576 | 0.0575 | 0.0575 |
| motor | third_party_prop | tweedie | 0.0550 | 0.0549 | 0.0549 |

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
- Run time 6.2 minutes.
