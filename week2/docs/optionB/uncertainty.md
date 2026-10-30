# Uncertainty in the week 2 (emerging) prediction

Generated 2026-10-26 07:47:29 SGT by `week_2/R/11_docs_week2.R`. Numbers come from steps 8-10; the reasoning is below each table.

## 1. 2025 burn per exposure-year: low / central / high

| line | low | central | high | sd_down_loadings | sd_up_loadings | level_sd |
|---|---|---|---|---|---|---|
| buildings | 240.822 | 350.627 | 503.581 | 0.115 | 0.056 | 0.358 |
| contents | 96.919 | 104.482 | 117.101 | 0.057 | 0.103 | 0.049 |
| motor | 529.196 | 605.211 | 661.035 | 0.125 | 0.073 | 0.050 |

How the range is built:

- **Loadings:** the step 8 scenarios moved one at a time:
  - trend +/-2-3% a year;
  - new business: no load vs full emerging residual;
  - BI / subsidence IBNR +5%;
  - emerging vs developed large-loss load.
  Downward and upward moves are each combined in quadrature.
- **Level:** the one-year A/E miss of the model in 2024, combined with the 2023 -> 2024 swing of the emerging burn and the Poisson noise 1/claims. This is the dominant term for buildings, where 2023 (fire 284 per exposure-year) and 2024 (95) differ by a factor of three.
- **Low / high:** central x exp(-/+ sqrt(loadings^2 + level^2)). Roughly a 1-sigma band, not a hard bound.

## 2. 2025 vs history (developed actuals, reweighted to the 2025 new-business x channel mix)

| line | exposure_2025 | burn_2025 | burn_2023 | burn_2024 | burn_mix_2023 | burn_mix_2024 |
|---|---|---|---|---|---|---|
| buildings | 47,376.4 | 350.6 | 515.7 | 324.9 | 495.5 | 285.8 |
| contents | 59,016.5 | 104.5 | 91.3 | 89.3 | 97.3 | 117.5 |
| motor | 79,007.0 | 605.2 | 443.4 | 467.8 | 820.6 | 519.1 |

- Motor 2025 (595) sits between 2024 (519) and 2023 (821) at the 2025 mix. The 2023 figure is inflated by few, heavy 2023 new-business claims (1.2k vehicle-years).
- Buildings 2025 (366) sits between the two years.
- Contents is stable.
- By peril, buildings EoW (66 vs 45-46 history) is the largest upward lean: the level credibility pulls it toward the buildings average, plus a 7.3% severity trend. It is a known judgement to revisit if Wendy prefers less shrinkage.

## 3. Sensitivity grid (2025 burn per line, each loading alone)

| line | scenario | burn | vs_central |
|---|---|---|---|
| buildings | developed_level_D | 534.689 | 0.525 |
| buildings | emerging_only_E | 432.464 | 0.233 |
| buildings | ibnr_plus5 | 352.393 | 0.005 |
| buildings | large_loss_emerging_load | 348.750 | -0.005 |
| buildings | level_only_L | 363.034 | 0.035 |
| buildings | nb_full_emerging | 314.036 | -0.104 |
| buildings | nb_none | 360.018 | 0.027 |
| buildings | trend_high | 367.924 | 0.049 |
| buildings | trend_low | 333.733 | -0.048 |
| contents | developed_level_D | 127.236 | 0.218 |
| contents | emerging_only_E | 108.737 | 0.041 |
| contents | ibnr_plus5 | 104.482 | 0 |
| contents | large_loss_emerging_load | 104.126 | -0.003 |
| contents | level_only_L | 101.434 | -0.029 |
| contents | nb_full_emerging | 113.945 | 0.091 |
| contents | nb_none | 101.265 | -0.031 |
| contents | trend_high | 109.646 | 0.049 |
| contents | trend_low | 99.439 | -0.048 |
| motor | developed_level_D | 763.152 | 0.261 |
| motor | emerging_only_E | 528.438 | -0.127 |
| motor | ibnr_plus5 | 616.853 | 0.019 |
| motor | large_loss_emerging_load | 600.152 | -0.008 |
| motor | level_only_L | 603.948 | -0.002 |
| motor | nb_full_emerging | 634.991 | 0.049 |
| motor | nb_none | 536.022 | -0.114 |
| motor | trend_high | 635.575 | 0.050 |
| motor | trend_low | 575.567 | -0.049 |

## 4. Validation noise

Bootstrap of the 2024 D2 of B (200 paired policy draws):

| weighting | basis | d2_B | p5 | p95 |
|---|---|---|---|---|
| as_is | reported_raw | 0.1085 | 0.0939 | 0.1243 |
| as_is | developed | 0.1171 | 0.1029 | 0.1325 |
| mix_2025 | reported_raw | 0.0525 | 0.0216 | 0.0792 |
| mix_2025 | developed | 0.0668 | 0.0372 | 0.0925 |

One fold of about 4k claims: the 90% interval of B's D2 is about 0.03 wide, ten times week 1's noise. Differences under about 0.001-0.002 (2 SE of B - L) cannot be called.

## 5. How good can D2 get? (the 0.25 goal)

Ceiling simulation: B taken as the TRUE risk, claims simulated (Poisson counts, Gamma sizes with the emerging per-peril CV), then the perfect model scored:

| metric | mean | p5 | p95 |
|---|---|---|---|
| d2_w1_as_is | 0.1162 | 0.1052 | 0.1269 |
| d2_const_as_is | 0.1514 | 0.1353 | 0.1650 |
| d2_w1_mix | 0.1111 | 0.0855 | 0.1472 |
| d2_const_mix | 0.1767 | 0.1441 | 0.2160 |

B scores 0.1171 (d2_w1) / 0.1497 (d2_const) on the as-is 2024 developed actuals, close to that ceiling. Even with every line x peril level set to the actual (Bor, uses the answers), D2 is 0.1188 / 0.1513. A local D2 of 0.25 would need the true risk spread to be far wider than any model of this data finds; week 1 reached the same conclusion (R/4_check_ceiling.R).

## 6. Main uncertainties, in order

1. **Emerging level per peril.** Only two years exist, and buildings swings by a factor of 1.8 between them.
2. **New-business loading.** 77% of 2025 is new business. Motor moves -11% to +5% between no residual NB load and the full emerging residual.
3. **Trend:** +/-5% per line for +/-2-3% a year.
4. **Dropped developed fields.** About 0.006 of developed D2 (0.0965 vs 0.1026), mostly motor (region, mileage). Unknown how much of that signal exists in emerging.
5. **IBNR and large losses:** small (< 2%), because emerging reporting matches developed.
6. **Takeover selection.** The broker portfolio may differ from the 2023-24 new business in ways the fields do not show. Not measurable from the data.
