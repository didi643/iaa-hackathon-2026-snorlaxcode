# Model card: week 2 emerging market, Option B

Generated 2026-10-26 07:47:28 SGT by `week_2/R/11_docs_week2.R` from the step outputs.

## Candidate file

`week_2/output/submission/submission_20261025_2240_week2_optionB.csv`, MD5 `62f2e1cbebcda4a1e6f86a666610251c`, 209,063 rows, header `row_id,prediction`, all predictions >= 0. **Not submitted** (waiting for Wendy).

## Structure

Per row and peril, the 2025 expected ultimate cost is:

`exposure x f_dev(x) x L_f x adj_f(x) x (1 + g_f) x s_dev(x) x L_s x adj_s(x) x load_dev x (1 + g_s) x NB`

where:

- `f_dev(x)`, `s_dev(x)`: developed baseline frequency (Poisson XGBoost, ultimate, from IBNR shares) and capped severity (Gamma XGBoost or GLM), WENDY 7 C5 engine refitted on developed 2021-24 with shared features only (step 5). Relativities only.
- `L_f`, `L_s`: emerging level per peril (2023-24), with credibility toward the line's pooled level (K = 100 claims for frequency; 200 for severity; 600 for sparse heavy perils).
- `adj_f`, `adj_s`: ridge-penalised emerging factor adjustments (lambda 100), kept only if they improve the 2023 -> 2024 deviance.
- `g_f`, `g_s`: one year of trend from 2024 to 2025 (developed prior blended with emerging).
- `load_dev`: developed large-loss load.
- `NB`: residual new-business load with credibility, only where `adj` lacks `new_business`.
- IBNR sits inside `f_dev` (developed chain ladder, verified on emerging lags).

The row prediction is the sum over the line's perils. Structural zeros (no cover) give 0.

## Developed baseline (step 5)

| basis | ALL | buildings | contents | motor |
|---|---|---|---|---|
| developed | 0.1030 | 0.0720 | 0.0648 | 0.0471 |
| reported_raw | 0.0976 | 0.0730 | 0.0647 | 0.0372 |

Mean of the 2023 and 2024 folds; week 1 C5 (all fields, 5 bags) scored 0.1026 on reported_raw ALL.

| line | peril | sev_type | claims_freq | rounds_freq | rounds_sev | freq_trend | sev_trend | cap | cap_load |
|---|---|---|---|---|---|---|---|---|---|
| motor | own_damage | gbm | 48,258 | 729 | 162 | 0.005 | 0.037 | 19,895.123 | 1.003 |
| motor | third_party_prop | gbm | 32,963 | 391 | 20 | 0.000 | 0.078 | 30,908.206 | 1.001 |
| motor | bodily_injury | glm | 7,512 | 325 |  | 0 | 0 | 187,505.674 | 1.048 |
| motor | theft | glm | 6,119 | 363 |  | 0 | 0.035 | 55,461.559 | 1.002 |
| motor | glass_hail | gbm | 15,643 | 343 | 45 | 0 | 0.080 | 9,592.568 | 1.001 |
| buildings | storm | gbm | 7,762 | 600 | 117 | 0 | 0.084 | 35,330.142 | 1.002 |
| buildings | flood | glm | 2,219 | 323 |  | 0 | 0.069 | 241,227.874 | 1.007 |
| buildings | escape_of_water | glm | 10,065 | 478 |  | 0 | 0.085 | 57,351.841 | 1.001 |
| buildings | subsidence | glm | 1,288 | 62 |  | 0 | 0.023 | 129,204.618 | 1.005 |
| buildings | fire | glm | 1,107 | 182 |  | 0 | -0.020 | 293,015.565 | 1.019 |
| buildings | accidental_damage | gbm | 3,825 | 192 | 16 | 0 | 0.022 | 9,514.428 | 1.001 |
| contents | theft | glm | 7,626 | 207 |  | 0 | 0.043 | 32,660.961 | 1.003 |
| contents | escape_of_water | gbm | 5,366 | 243 | 184 | 0 | 0.026 | 23,973.187 | 1.002 |
| contents | accidental_damage | gbm | 9,063 | 277 | 45 | 0 | 0.028 | 6,196.545 | 1.002 |
| contents | flood | glm | 1,615 | 245 |  | 0 | 0.056 | 67,334.539 | 1.009 |

## Emerging levels and factors (step 7)

| line | peril | claims_all | freq_level_final | sev_level_final | freq_factors | sev_factors |
|---|---|---|---|---|---|---|
| motor | own_damage | 2,672 | 1.091 | 0.629 | gender + voluntary_excess + occupation | voluntary_excess + hail_days_b |
| motor | third_party_prop | 2,193 | 1.178 | 0.569 | gender + vehicle_value_group_b + self_employed | self_employed |
| motor | bodily_injury | 449 | 1.189 | 0.580 | gender + ncb_years_b + voluntary_excess |  |
| motor | theft | 389 | 1.268 | 0.636 | occupation + self_employed |  |
| motor | glass_hail | 1,345 | 1.310 | 0.606 | hail_days_b + voluntary_excess + vehicle_value_group_b + new_business | years_licensed_b |
| buildings | storm | 464 | 1.283 | 0.643 | self_employed + construction_type |  |
| buildings | flood | 80 | 0.956 | 0.654 | construction_type |  |
| buildings | escape_of_water | 268 | 0.917 | 0.619 | gender |  |
| buildings | subsidence | 52 | 1.060 | 0.651 |  |  |
| buildings | fire | 70 | 1.085 | 0.681 |  |  |
| buildings | accidental_damage | 122 | 0.955 | 0.659 | construction_type |  |
| contents | theft | 406 | 1.017 | 0.794 | gender |  |
| contents | escape_of_water | 171 | 0.888 | 0.781 |  |  |
| contents | accidental_damage | 335 | 0.817 | 0.773 | new_business |  |
| contents | flood | 86 | 0.913 | 0.786 |  |  |

Factors tried: 285; kept: 26 (full log in `week_2/output/07_adjust/factor_log.csv`).

## 2025 loadings (step 8)

| line | peril | freq_trend | sev_trend | nb_ae_rel | z | nb_load | nb_factor |
|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | 0 | 0.028 | 0.834 | 0.204 | 0.966 | FALSE |
| buildings | escape_of_water | 0 | 0.073 | 0.834 | 0.204 | 0.966 | FALSE |
| buildings | fire | 0 | -0.020 | 0.834 | 0.204 | 0.966 | FALSE |
| buildings | flood | 0 | 0.072 | 0.834 | 0.204 | 0.966 | FALSE |
| buildings | storm | 0 | 0.088 | 0.834 | 0.204 | 0.966 | FALSE |
| buildings | subsidence | 0 | 0.015 | 0.834 | 0.204 | 0.966 | FALSE |
| contents | accidental_damage | 0 | 0.015 | 1.179 | 0.254 | 1.045 | TRUE |
| contents | escape_of_water | 0 | 0.016 | 1.179 | 0.254 | 1.045 | FALSE |
| contents | flood | 0 | 0.062 | 1.179 | 0.254 | 1.045 | FALSE |
| contents | theft | 0 | 0.041 | 1.179 | 0.254 | 1.045 | FALSE |
| motor | bodily_injury | 0 | 0 | 1.238 | 0.699 | 1.166 | FALSE |
| motor | glass_hail | 0 | 0.092 | 1.238 | 0.699 | 1.166 | TRUE |
| motor | own_damage | -0.050 | 0.037 | 1.238 | 0.699 | 1.166 | FALSE |
| motor | theft | 0 | 0.060 | 1.238 | 0.699 | 1.166 | FALSE |
| motor | third_party_prop | -0.034 | 0.042 | 1.238 | 0.699 | 1.166 | FALSE |

## Validation (step 9): emerging 2023 -> 2024, ALL lines

| weighting | basis | candidate | d2_w1 | d2_const | pred_vs_actual |
|---|---|---|---|---|---|
| as_is | reported_raw | B | 0.1085 | 0.1380 | 1.1825 |
| as_is | reported_raw | L | 0.1052 | 0.1348 | 1.1839 |
| as_is | reported_raw | E | 0.0557 | 0.0869 | 1.3147 |
| as_is | reported_raw | BE | 0.0880 | 0.1182 | 1.2486 |
| as_is | reported_raw | D | 0.0708 | 0.1016 | 1.7135 |
| as_is | reported_raw | Bor | 0.1101 | 0.1395 | 1.1551 |
| as_is | developed | B | 0.1171 | 0.1497 | 1.0237 |
| as_is | developed | L | 0.1131 | 0.1458 | 1.0250 |
| as_is | developed | E | 0.0670 | 0.1015 | 1.1382 |
| as_is | developed | BE | 0.0985 | 0.1318 | 1.0810 |
| as_is | developed | D | 0.0930 | 0.1265 | 1.4834 |
| as_is | developed | Bor | 0.1188 | 0.1513 | 1 |
| mix_2025 | reported_raw | B | 0.0525 | 0.1344 | 1.2704 |
| mix_2025 | reported_raw | L | 0.0509 | 0.1329 | 1.2721 |
| mix_2025 | reported_raw | E | 0.0265 | 0.1106 | 1.4160 |
| mix_2025 | reported_raw | BE | 0.0444 | 0.1270 | 1.3432 |
| mix_2025 | reported_raw | D | 0.0121 | 0.0975 | 1.8469 |
| mix_2025 | reported_raw | Bor | 0.0559 | 0.1375 | 1.2460 |
| mix_2025 | developed | B | 0.0668 | 0.1516 | 1.0746 |
| mix_2025 | developed | L | 0.0648 | 0.1497 | 1.0761 |
| mix_2025 | developed | E | 0.0492 | 0.1356 | 1.1977 |
| mix_2025 | developed | BE | 0.0634 | 0.1485 | 1.1362 |
| mix_2025 | developed | D | 0.0423 | 0.1293 | 1.5623 |
| mix_2025 | developed | Bor | 0.0694 | 0.1540 | 1.0539 |

d2_w1 is the week 1 protocol (baseline: one cost rate per exposure-year); d2_const is Tweedie D2 against the constant mean (sklearn formula). Bor is a diagnostic that uses the answers.

| weighting | basis | comparison | d2_B | d2_other | diff | boot_se | share_B_better | verdict |
|---|---|---|---|---|---|---|---|---|
| as_is | reported_raw | B - L | 0.1085 | 0.1052 | 0.0033 | 0.0009 | 1 | B better |
| as_is | reported_raw | B - E | 0.1085 | 0.0557 | 0.0528 | 0.0063 | 1 | B better |
| as_is | reported_raw | B - BE | 0.1085 | 0.0880 | 0.0205 | 0.0029 | 1 | B better |
| as_is | reported_raw | B - D | 0.1085 | 0.0708 | 0.0377 | 0.0048 | 1 | B better |
| as_is | reported_raw | B (level, 90% interval) | 0.1085 | 0.0939 | 0.1243 | 0.0091 |  | d2_other = p5, diff = p95 |
| as_is | developed | B - L | 0.1171 | 0.1131 | 0.0041 | 0.0012 | 1 | B better |
| as_is | developed | B - E | 0.1171 | 0.0670 | 0.0501 | 0.0063 | 1 | B better |
| as_is | developed | B - BE | 0.1171 | 0.0985 | 0.0187 | 0.0029 | 1 | B better |
| as_is | developed | B - D | 0.1171 | 0.0930 | 0.0241 | 0.0047 | 1 | B better |
| as_is | developed | B (level, 90% interval) | 0.1171 | 0.1029 | 0.1325 | 0.0087 |  | d2_other = p5, diff = p95 |
| mix_2025 | reported_raw | B - L | 0.0525 | 0.0509 | 0.0016 | 0.0019 | 0.8000 | within noise |
| mix_2025 | reported_raw | B - E | 0.0525 | 0.0265 | 0.0261 | 0.0121 | 0.9800 | B better |
| mix_2025 | reported_raw | B - BE | 0.0525 | 0.0444 | 0.0081 | 0.0074 | 0.8800 | within noise |
| mix_2025 | reported_raw | B - D | 0.0525 | 0.0121 | 0.0405 | 0.0097 | 1 | B better |
| mix_2025 | reported_raw | B (level, 90% interval) | 0.0525 | 0.0216 | 0.0792 | 0.0179 |  | d2_other = p5, diff = p95 |
| mix_2025 | developed | B - L | 0.0668 | 0.0648 | 0.0020 | 0.0026 | 0.7800 | within noise |
| mix_2025 | developed | B - E | 0.0668 | 0.0492 | 0.0177 | 0.0128 | 0.9100 | within noise |
| mix_2025 | developed | B - BE | 0.0668 | 0.0634 | 0.0034 | 0.0077 | 0.7050 | within noise |
| mix_2025 | developed | B - D | 0.0668 | 0.0423 | 0.0246 | 0.0106 | 0.9900 | B better |
| mix_2025 | developed | B (level, 90% interval) | 0.0668 | 0.0372 | 0.0925 | 0.0183 |  | d2_other = p5, diff = p95 |

## 2025 burn per exposure-year (step 10)

| line | exposure_2025 | burn_2025 | burn_2023 | burn_2024 | burn_mix_2023 | burn_mix_2024 |
|---|---|---|---|---|---|---|
| buildings | 47,376.4 | 350.6 | 515.7 | 324.9 | 495.5 | 285.8 |
| contents | 59,016.5 | 104.5 | 91.3 | 89.3 | 97.3 | 117.5 |
| motor | 79,007.0 | 605.2 | 443.4 | 467.8 | 820.6 | 519.1 |

| line | peril | burn_2025 | burn_2023 | burn_2024 | burn_mix_2023 | burn_mix_2024 |
|---|---|---|---|---|---|---|
| buildings | accidental_damage | 5.21 | 4.10 | 5.37 | 4.84 | 4.97 |
| buildings | escape_of_water | 66.04 | 44.55 | 46.07 | 38.01 | 28.28 |
| buildings | fire | 88.66 | 283.73 | 94.85 | 70.40 | 83.75 |
| buildings | flood | 98.81 | 91.70 | 91.98 | 185.29 | 63.12 |
| buildings | storm | 56.58 | 45.47 | 59.41 | 64.45 | 50.34 |
| buildings | subsidence | 35.33 | 46.11 | 27.23 | 132.55 | 55.30 |
| contents | accidental_damage | 10.42 | 7.68 | 7.27 | 13.82 | 10.08 |
| contents | escape_of_water | 16.28 | 13.72 | 11.93 | 11.09 | 8.65 |
| contents | flood | 27.47 | 30.72 | 24.71 | 18.76 | 24.03 |
| contents | theft | 50.31 | 39.17 | 45.43 | 53.59 | 74.76 |
| motor | bodily_injury | 232.84 | 158.25 | 177.24 | 430.53 | 171.27 |
| motor | glass_hail | 28.44 | 22.87 | 30.32 | 24.40 | 36.41 |
| motor | own_damage | 99.27 | 79.26 | 75.10 | 111.54 | 94.57 |
| motor | theft | 49.98 | 38.69 | 44.22 | 67.78 | 53.22 |
| motor | third_party_prop | 194.68 | 144.33 | 140.92 | 186.30 | 163.66 |

