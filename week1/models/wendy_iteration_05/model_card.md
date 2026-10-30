# WENDY 5 - tuned per-peril models, method chosen on grouped CV

**Run id** `20261022_0912` | **Workbook** `docs/assumptions_wendy05.xlsx` (MD5 `edbc4be39d60d8192522c6dff00ffb90`) | **Submission** `submission_20261022_0912_wendy05.csv` (MD5 `33b990116f99a3b93ba90900c8864b25`)

Replication check (saved models in `models/wendy_iteration_05/fitted/` reloaded and re-scored vs the submission): **passed**

| line | rows | max_abs_diff |
|---|---|---|
| motor | 254,986 | 0 |
| buildings | 184,155 | 0 |
| contents | 187,498 | 0 |

Validation mode `both`, 5 policy-grouped folds, 20 configs per component, tuning fold 1.

## Line and portfolio scores (Tweedie D2 vs developed actuals)
| line | group_cv | time_2024 |
|---|---|---|
| ALL | 0.1118 | 0.1025 |
| buildings | 0.0713 | 0.0694 |
| contents | 0.0731 | 0.0628 |
| motor | 0.0579 | 0.0524 |

## Chosen method per peril
| line | peril | method | sev_type | basis |
|---|---|---|---|---|
| motor | own_damage | freq_sev | gbm | group_cv |
| motor | third_party_prop | freq_sev | gbm | group_cv |
| motor | bodily_injury | freq_sev | gbm | group_cv |
| motor | theft | freq_sev | glm | group_cv |
| motor | glass_hail | freq_sev | gbm | group_cv |
| buildings | storm | freq_sev | gbm | group_cv |
| buildings | flood | tweedie | gbm | group_cv |
| buildings | escape_of_water | tweedie | gbm | group_cv |
| buildings | subsidence | freq_sev | gbm | group_cv |
| buildings | fire | freq_sev | gbm | group_cv |
| buildings | accidental_damage | freq_sev | gbm | group_cv |
| contents | theft | freq_sev | glm | group_cv |
| contents | escape_of_water | freq_sev | gbm | group_cv |
| contents | accidental_damage | freq_sev | glm | group_cv |
| contents | flood | freq_sev | glm | group_cv |

## Grouped CV by peril and method
| line | peril | freq_sev | tweedie |
|---|---|---|---|
| buildings | accidental_damage | 0.1507 | 0.1478 |
| buildings | escape_of_water | 0.0449 | 0.0452 |
| buildings | fire | 0.0235 | 0.0159 |
| buildings | flood | 0.4362 | 0.4431 |
| buildings | storm | 0.0709 | 0.0679 |
| buildings | subsidence | 0.0756 | 0.0750 |
| contents | accidental_damage | 0.1499 | 0.1448 |
| contents | escape_of_water | 0.0387 | 0.0373 |
| contents | flood | 0.4470 | 0.4309 |
| contents | theft | 0.0392 | 0.0347 |
| motor | bodily_injury | 0.0597 | 0.0570 |
| motor | glass_hail | 0.1369 | 0.1355 |
| motor | own_damage | 0.1656 | 0.0578 |
| motor | theft | 0.0769 | 0.0678 |
| motor | third_party_prop | 0.0631 | 0.0611 |

## Time check 2024
| line | peril | freq_sev | tweedie |
|---|---|---|---|
| buildings | accidental_damage | 0.1353 | 0.1279 |
| buildings | escape_of_water | 0.0469 | 0.0484 |
| buildings | fire | 0.0054 | -0.0012 |
| buildings | flood | 0.4335 | 0.4221 |
| buildings | storm | 0.0661 | 0.0633 |
| buildings | subsidence | 0.0830 | 0.0895 |
| contents | accidental_damage | 0.1413 | 0.1406 |
| contents | escape_of_water | 0.0402 | 0.0412 |
| contents | flood | 0.3954 | 0.1462 |
| contents | theft | 0.0345 | 0.0326 |
| motor | bodily_injury | 0.0368 | 0.0544 |
| motor | glass_hail | 0.1371 | 0.1355 |
| motor | own_damage | 0.1703 | 0.1373 |
| motor | theft | 0.0823 | 0.0788 |
| motor | third_party_prop | 0.0530 | 0.0513 |

## Tuning gain (holdout deviance, default -> best config)
| line | peril | part | default_dev | best_dev | tuning_gain_pct |
|---|---|---|---|---|---|
| motor | own_damage | freq | 0.2566 | 0.2564 | 0.0579 |
| motor | own_damage | sev | 1.5964 | 1.5964 | 0.0012 |
| motor | own_damage | tweedie | 51.6050 | 51.5359 | 0.1340 |
| motor | third_party_prop | freq | 0.2087 | 0.2085 | 0.0822 |
| motor | third_party_prop | sev | 1.1574 | 1.1557 | 0.1414 |
| motor | third_party_prop | tweedie | 72.3961 | 72.2871 | 0.1505 |
| motor | bodily_injury | freq | 0.0695 | 0.0695 | 0.0916 |
| motor | bodily_injury | sev | 1.2674 | 1.2659 | 0.1219 |
| motor | bodily_injury | tweedie | 78.7145 | 78.5461 | 0.2139 |
| motor | theft | freq | 0.0651 | 0.0650 | 0.2023 |
| motor | theft | sev | 1.2254 | 1.2022 | 1.8943 |
| motor | theft | tweedie | 46.3902 | 46.2118 | 0.3846 |
| motor | glass_hail | freq | 0.1457 | 0.1455 | 0.1223 |
| motor | glass_hail | sev | 1.1512 | 1.1418 | 0.8242 |
| motor | glass_hail | tweedie | 32.1013 | 32.0639 | 0.1163 |
| buildings | storm | freq | 0.0946 | 0.0944 | 0.1728 |
| buildings | storm | sev | 1.1016 | 1.0981 | 0.3163 |
| buildings | storm | tweedie | 43.2501 | 43.1967 | 0.1234 |
| buildings | flood | freq | 0.0241 | 0.0241 | 0.0563 |
| buildings | flood | sev | 1.0816 | 1.0694 | 1.1261 |
| buildings | flood | tweedie | 44.7708 | 43.7032 | 2.3844 |
| buildings | escape_of_water | freq | 0.1125 | 0.1124 | 0.1129 |
| buildings | escape_of_water | sev | 1.1382 | 1.1375 | 0.0620 |
| buildings | escape_of_water | tweedie | 62.5971 | 62.4330 | 0.2621 |
| buildings | subsidence | freq | 0.0207 | 0.0207 | 0.0793 |
| buildings | subsidence | sev | 1.2058 | 1.1592 | 3.8625 |
| buildings | subsidence | tweedie | 46.1716 | 45.7266 | 0.9638 |
| buildings | fire | freq | 0.0208 | 0.0208 | 0.2117 |
| buildings | fire | sev | 1.2615 | 1.2582 | 0.2625 |
| buildings | fire | tweedie | 63.5077 | 62.9976 | 0.8032 |
| buildings | accidental_damage | freq | 0.0503 | 0.0503 | 0 |
| buildings | accidental_damage | sev | 1.1809 | 1.1661 | 1.2459 |
| buildings | accidental_damage | tweedie | 16.2965 | 16.2292 | 0.4131 |
| contents | theft | freq | 0.0939 | 0.0937 | 0.1988 |
| contents | theft | sev | 1.1567 | 1.1554 | 0.1133 |
| contents | theft | tweedie | 44.1767 | 44.0092 | 0.3791 |
| contents | escape_of_water | freq | 0.0679 | 0.0678 | 0.1393 |
| contents | escape_of_water | sev | 1.2128 | 1.2086 | 0.3482 |
| contents | escape_of_water | tweedie | 32.2596 | 32.0373 | 0.6891 |
| contents | accidental_damage | freq | 0.0944 | 0.0944 | 0.0704 |
| contents | accidental_damage | sev | 1.1333 | 1.1304 | 0.2558 |
| contents | accidental_damage | tweedie | 19.0653 | 19.0123 | 0.2782 |
| contents | flood | freq | 0.0193 | 0.0192 | 0.4114 |
| contents | flood | sev | 1.1677 | 1.1596 | 0.6927 |
| contents | flood | tweedie | 20.7139 | 20.1359 | 2.7903 |

## Component out-of-fold deviance (compare with WENDY 6)
| line | peril | part | metric | value | n |
|---|---|---|---|---|---|
| motor | own_damage | freq | poisson_deviance | 0.25597 | 979,968 |
| motor | own_damage | sev | gamma_deviance | 1.58577 | 48,258 |
| motor | third_party_prop | freq | poisson_deviance | 0.21011 | 979,968 |
| motor | third_party_prop | sev | gamma_deviance | 1.15744 | 32,963 |
| motor | bodily_injury | freq | poisson_deviance | 0.06944 | 979,968 |
| motor | bodily_injury | sev | gamma_deviance | 1.39419 | 7,512 |
| motor | theft | freq | poisson_deviance | 0.06600 | 891,764 |
| motor | theft | sev | gamma_deviance | 1.15498 | 6,119 |
| motor | glass_hail | freq | poisson_deviance | 0.14621 | 802,694 |
| motor | glass_hail | sev | gamma_deviance | 1.17607 | 15,643 |
| buildings | storm | freq | poisson_deviance | 0.09314 | 707,726 |
| buildings | storm | sev | gamma_deviance | 1.13573 | 7,762 |
| buildings | flood | freq | poisson_deviance | 0.02490 | 707,726 |
| buildings | flood | sev | gamma_deviance | 1.14796 | 2,219 |
| buildings | escape_of_water | freq | poisson_deviance | 0.11566 | 707,726 |
| buildings | escape_of_water | sev | gamma_deviance | 1.18548 | 10,065 |
| buildings | subsidence | freq | poisson_deviance | 0.02142 | 707,726 |
| buildings | subsidence | sev | gamma_deviance | 1.25167 | 1,288 |
| buildings | fire | freq | poisson_deviance | 0.01980 | 707,726 |
| buildings | fire | sev | gamma_deviance | 1.36067 | 1,107 |
| buildings | accidental_damage | freq | poisson_deviance | 0.04987 | 707,726 |
| buildings | accidental_damage | sev | gamma_deviance | 1.17265 | 3,825 |
| contents | theft | freq | poisson_deviance | 0.09291 | 721,617 |
| contents | theft | sev | gamma_deviance | 1.15824 | 7,626 |
| contents | escape_of_water | freq | poisson_deviance | 0.07084 | 721,617 |
| contents | escape_of_water | sev | gamma_deviance | 1.18294 | 5,366 |
| contents | accidental_damage | freq | poisson_deviance | 0.09571 | 721,617 |
| contents | accidental_damage | sev | gamma_deviance | 1.18853 | 9,063 |
| contents | flood | freq | poisson_deviance | 0.01901 | 721,617 |
| contents | flood | sev | gamma_deviance | 1.13832 | 1,615 |

## Final fit
| line | peril | method | sev_type | rounds_freq | rounds_sev | claims | sev_claims | freq_trend | sev_trend | cap | cap_load | predicted_burn |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | freq_sev | gbm | 1,717 | 215 | 48,258 | 48,258 | -0.002 | 0.037 | 19,187.494 | 1.003 | 108.201 |
| motor | third_party_prop | freq_sev | gbm | 1,625 | 93 | 32,963 | 32,963 | -0.010 | 0.078 | 28,661.613 | 1.001 | 171.292 |
| motor | bodily_injury | freq_sev | gbm | 624 | 0 | 7,512 | 6,334 | 0.005 | -0.020 | 182,287.065 | 1.048 | 191.964 |
| motor | theft | freq_sev | glm | 704 |  | 6,119 | 6,119 | 0 | 0.035 | 53,594.467 | 1.002 | 48.859 |
| motor | glass_hail | freq_sev | gbm | 1,142 | 56 | 15,643 | 15,643 | 0 | 0.080 | 8,880.490 | 1.001 | 24.761 |
| buildings | storm | freq_sev | gbm | 1,891 | 65 | 7,762 | 7,762 | 0 | 0.084 | 32,578.808 | 1.002 | 58.926 |
| buildings | flood | tweedie | gbm | 96 |  | 2,219 | 2,219 | 0 | 0.069 | 225,734.500 | 1.007 | 130.162 |
| buildings | escape_of_water | tweedie | gbm | 347 |  | 10,065 | 10,065 | 0 | 0.085 | 52,848.332 | 1.001 | 122.457 |
| buildings | subsidence | freq_sev | gbm | 405 | 20 | 1,288 | 997 | 0 | 0.023 | 126,323.343 | 1.005 | 58.414 |
| buildings | fire | freq_sev | gbm | 773 | 13 | 1,107 | 1,107 | 0 | -0.020 | 298,995.475 | 1.019 | 96.864 |
| buildings | accidental_damage | freq_sev | gbm | 356 | 115 | 3,825 | 3,825 | 0 | 0.022 | 9,309.180 | 1.001 | 8.567 |
| contents | theft | freq_sev | glm | 627 |  | 7,626 | 7,626 | 0 | 0.043 | 31,316.440 | 1.003 | 54.772 |
| contents | escape_of_water | freq_sev | gbm | 747 | 273 | 5,366 | 5,366 | 0 | 0.026 | 23,374.462 | 1.002 | 26.626 |
| contents | accidental_damage | freq_sev | glm | 595 |  | 9,063 | 9,063 | 0 | 0.028 | 6,030.573 | 1.002 | 13.281 |
| contents | flood | freq_sev | glm | 500 |  | 1,615 | 1,615 | 0 | 0.056 | 63,741.816 | 1.009 | 30.742 |

| line | rows | predicted_total | predicted_burn |
|---|---|---|---|
| motor | 254,986 | 109,006,444.59 | 545.08 |
| buildings | 184,155 | 71,424,432.14 | 475.39 |
| contents | 187,498 | 18,828,754.48 | 125.42 |

Run time 3.87 hours.
