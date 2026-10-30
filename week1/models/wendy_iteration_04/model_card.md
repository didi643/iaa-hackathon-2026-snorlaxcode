# WENDY 4 - per-peril frequency x severity from the assumption workbook

**Run id** `20261022_0715` | **Workbook** `docs/assumptions_wendy04.xlsx` (MD5 `6de5733ba03b8f4f02dfceef5c43211d`) | **Submission** `submission_20261022_0715_wendy04.csv` (MD5 `e1a2b96e02f795c46f96ece3694abb5d`)

Target, data and feature decisions are documented in the workbook (sheets Target_Assumptions, Features_*, Model_Spec).

## Validation (developed actuals, Tweedie D2 p = 1.5)
| mix | line | 2023 | 2024 |
|---|---|---|---|
| all freq_sev | ALL | 0.1061 | 0.1030 |
| all freq_sev | buildings | 0.0704 | 0.0712 |
| all freq_sev | contents | 0.0698 | 0.0639 |
| all freq_sev | motor | 0.0531 | 0.0517 |
| chosen | ALL | 0.1053 | 0.1045 |
| chosen | buildings | 0.0704 | 0.0712 |
| chosen | contents | 0.0703 | 0.0639 |
| chosen | motor | 0.0511 | 0.0551 |

WENDY 3 (scored vs REPORTED actuals, so not like-for-like):

| line | valid_year | d2 |
|---|---|---|
| motor | 2024 | 0.0434 |
| buildings | 2024 | 0.0720 |
| contents | 2024 | 0.0591 |
| ALL | 2024 | 0.0954 |

### By peril and method
![](d2_by_peril.png)

| line | peril | freq_sev_2023 | freq_sev_2024 | tweedie_2023 | tweedie_2024 |
|---|---|---|---|---|---|
| buildings | accidental_damage | 0.1443 | 0.1336 | 0.1335 | 0.1223 |
| buildings | escape_of_water | 0.0313 | 0.0451 | 0.0283 | 0.0415 |
| buildings | fire | 0.0096 | 0.0233 | 0.0196 | -0.0804 |
| buildings | flood | 0.4719 | 0.4402 | 0.1524 | 0.4430 |
| buildings | storm | 0.0518 | 0.0635 | 0.0503 | 0.0616 |
| buildings | subsidence | 0.0669 | 0.0757 | 0.0517 | 0.0762 |
| contents | accidental_damage | 0.1427 | 0.1412 | 0.1413 | 0.1361 |
| contents | escape_of_water | 0.0237 | 0.0419 | 0.0262 | 0.0419 |
| contents | flood | 0.4789 | 0.3940 | 0.4281 | 0.1770 |
| contents | theft | 0.0322 | 0.0340 | 0.0249 | 0.0260 |
| motor | bodily_injury | 0.0524 | 0.0326 | 0.0494 | 0.0494 |
| motor | glass_hail | 0.1391 | 0.1354 | 0.1370 | 0.1345 |
| motor | own_damage | 0.1612 | 0.1677 | 0.1594 | 0.1730 |
| motor | theft | 0.0592 | 0.0796 | 0.0481 | 0.0768 |
| motor | third_party_prop | 0.0616 | 0.0522 | 0.0591 | 0.0501 |

### Chosen method per peril
| line | peril | method | mean_d2 |
|---|---|---|---|
| buildings | accidental_damage | freq_sev | 0.1390 |
| buildings | escape_of_water | freq_sev | 0.0382 |
| buildings | fire | freq_sev | 0.0164 |
| buildings | flood | freq_sev | 0.4561 |
| buildings | storm | freq_sev | 0.0577 |
| buildings | subsidence | freq_sev | 0.0713 |
| contents | accidental_damage | freq_sev | 0.1420 |
| contents | escape_of_water | tweedie | 0.0341 |
| contents | flood | freq_sev | 0.4364 |
| contents | theft | freq_sev | 0.0331 |
| motor | bodily_injury | tweedie | 0.0494 |
| motor | glass_hail | freq_sev | 0.1372 |
| motor | own_damage | tweedie | 0.1662 |
| motor | theft | freq_sev | 0.0694 |
| motor | third_party_prop | freq_sev | 0.0569 |

## Final fit diagnostics (2021-2024 -> 2025)
| line | peril | method | sev_type | rounds_freq | rounds_sev | claims_freq | claims_sev | freq_trend | sev_trend | cap | cap_load | bal_freq | bal_sev | sev_years |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | tweedie | - | 107 |  | 48,258 |  | 0.010 | 0.037 | 19,895.123 | 1.003 | 1.048 |  | 2021-2024 |
| motor | third_party_prop | freq_sev | gbm | 423 | 7 | 32,963 | 32,963 | -0.009 | 0.078 | 30,908.206 | 1.001 | 0.999 | 0.999 | 2021-2024 |
| motor | bodily_injury | tweedie | - | 123 |  | 7,512 |  | -0.049 | -0.020 | 178,641.324 | 1.048 | 1.039 |  | 2021-2023 |
| motor | theft | freq_sev | gbm | 440 | 109 | 6,119 | 6,119 | 0 | 0.035 | 55,461.559 | 1.002 | 1.000 | 1.008 | 2021-2024 |
| motor | glass_hail | freq_sev | gbm | 419 | 45 | 15,643 | 15,643 | 0 | 0.080 | 9,592.568 | 1.001 | 0.998 | 1.010 | 2021-2024 |
| buildings | storm | freq_sev | gbm | 595 | 88 | 7,762 | 7,762 | 0 | 0.084 | 35,330.142 | 1.002 | 0.996 | 1.007 | 2021-2024 |
| buildings | flood | freq_sev | glm | 373 |  | 2,219 | 2,219 | 0 | 0.069 | 241,227.874 | 1.007 | 1.002 | 0.999 | 2021-2024 |
| buildings | escape_of_water | freq_sev | gbm | 571 | 54 | 10,065 | 10,065 | 0 | 0.085 | 57,351.841 | 1.001 | 1.001 | 1.013 | 2021-2024 |
| buildings | subsidence | freq_sev | glm | 71 |  | 1,288 | 997 | 0 | 0.023 | 129,204.618 | 1.005 | 0.995 | 0.999 | 2021-2023 |
| buildings | fire | freq_sev | glm | 208 |  | 1,107 | 1,107 | 0 | -0.020 | 293,015.565 | 1.019 | 1.012 | 1.000 | 2021-2024 |
| buildings | accidental_damage | freq_sev | gbm | 307 | 15 | 3,825 | 3,825 | 0 | 0.022 | 9,514.428 | 1.001 | 0.995 | 1.000 | 2021-2024 |
| contents | theft | freq_sev | gbm | 207 | 44 | 7,626 | 7,626 | 0 | 0.043 | 32,660.961 | 1.003 | 1.002 | 1.022 | 2021-2024 |
| contents | escape_of_water | tweedie | - | 245 |  | 5,366 |  | 0 | 0.026 | 23,973.187 | 1.002 | 1.064 |  | 2021-2024 |
| contents | accidental_damage | freq_sev | gbm | 344 | 50 | 9,063 | 9,063 | 0 | 0.028 | 6,196.545 | 1.002 | 0.997 | 1.011 | 2021-2024 |
| contents | flood | freq_sev | glm | 281 |  | 1,615 | 1,615 | 0 | 0.056 | 67,334.539 | 1.009 | 0.997 | 1.000 | 2021-2024 |

## Structural zeros (applied only if training has no claims in those rows)
| line | peril | column | values | rows | claims | active |
|---|---|---|---|---|---|---|
| motor | own_damage | cover_type | third_party_only,third_party_fire_theft | 177,274 | 4 | FALSE |
| motor | glass_hail | cover_type | third_party_only,third_party_fire_theft | 177,274 | 0 | TRUE |
| motor | theft | cover_type | third_party_only | 88,204 | 0 | TRUE |
| buildings | accidental_damage | accidental_damage_cover | FALSE | 425,155 | 502 | FALSE |
| contents | accidental_damage | accidental_damage_cover | FALSE | 397,233 | 1,087 | FALSE |

## Expected recoveries deducted from open claims
| line | peril | closed_claims | recovery_ratio |
|---|---|---|---|
| motor | own_damage | 46,269 | 0.2359 |
| motor | theft | 5,875 | 0.0400 |

Claims limited at 2,000,000: 1

## 2025 predictions
| line | rows | exposure | predicted_total | predicted_burn | p50 | p90 | p99 | max |
|---|---|---|---|---|---|---|---|---|
| motor | 254,986 | 199,983.58 | 104,228,676.74 | 521.19 | 358.86 | 738.79 | 1,543.80 | 6,320.90 |
| buildings | 184,155 | 150,243.90 | 72,474,364.54 | 482.38 | 300.70 | 695.04 | 2,296.41 | 15,595.32 |
| contents | 187,498 | 150,123.77 | 18,763,566.70 | 124.99 | 79.09 | 177.77 | 548.62 | 2,909.13 |

| line | peril | method | predicted_total | predicted_burn | reported_burn_train_ex_latest |
|---|---|---|---|---|---|
| motor | own_damage | tweedie | 22,758,685.48 | 113.80 | 112.48 |
| motor | third_party_prop | freq_sev | 34,424,923.91 | 172.14 | 153.05 |
| motor | bodily_injury | tweedie | 32,336,686.82 | 161.70 | 223.55 |
| motor | theft | freq_sev | 9,753,380.71 | 48.77 | 48.86 |
| motor | glass_hail | freq_sev | 4,954,999.81 | 24.78 | 20.81 |
| buildings | storm | freq_sev | 8,982,789.39 | 59.79 | 44.20 |
| buildings | flood | freq_sev | 19,799,932.36 | 131.79 | 115.66 |
| buildings | escape_of_water | freq_sev | 18,400,778.57 | 122.47 | 93.26 |
| buildings | subsidence | freq_sev | 9,011,846.26 | 59.98 | 51.73 |
| buildings | fire | freq_sev | 14,997,949.65 | 99.82 | 94.38 |
| buildings | accidental_damage | freq_sev | 1,281,068.30 | 8.53 | 7.68 |
| contents | theft | freq_sev | 8,150,487.84 | 54.29 | 45.32 |
| contents | escape_of_water | tweedie | 4,024,509.15 | 26.81 | 24.64 |
| contents | accidental_damage | freq_sev | 1,982,539.08 | 13.21 | 11.80 |
| contents | flood | freq_sev | 4,606,030.63 | 30.68 | 27.60 |

## Known limitations
- Case reserves assumed adequate (no IBNER); long-tail perils exclude the latest year from severity only.
- Severity trend is a raw log-linear fit on capped claims, so mix change is partly counted as trend (clamped).
- Weather features use the realised weather of the row's year (supplied for 2025 in the test data).
- Prior-year history for 2025 test rows uses 2024 claims reported by 31 Dec 2024 - same basis as training.
- Run time 28.9 minutes.
