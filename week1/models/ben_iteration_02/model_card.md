# BEN 2 - per-peril cost models

**Run id** `20261022_1438` | **Generated** 2026-10-22 16:03 | **Git commit** `e3373d1` | **Submission file** `submission_20261022_1438.csv`

**Change in this iteration:** Per-peril XGBoost Tweedie cost models (no frequency/severity split) on BEN 1's v6 setup; line = sum of perils with per-peril large-loss cap, cap loading and IBNR (v1); v2 adds BEN's own cleaning (type fixes, claims history), cost-weighted IBNR, trend and sensible-direction constraints per peril.

## Reproducibility
Submission file MD5 `34dc2c9da29db5062b2ea2cabe3cf928`. Final models in `models/ben_iteration_02/fitted/`; reload with `load_model()` and score with `score_model()` (`R/model_io.R`; per-peril models load as a `peril_sum`). Replication check: **passed**

| line | model | rows | max_abs_diff |
|---|---|---|---|
| motor | motor_xgb_tweedie | 254,986 | 0 |
| buildings | buildings_xgb_tweedie | 184,155 | 0 |
| contents | contents_xgb_tweedie | 187,498 | 0 |

## Settings
| setting | value |
|---|---|
| Model | XGBoost reg:tweedie on cost per exposure-year, weight = exposure, hist trees, early stopping on a 10% policy holdout |
| Folds | expanding window: 2021-22 -> 2023, 2021-23 -> 2024 |
| Final fit | 2021-24 -> 2025 |
| Per-peril models (v1 on) | one model per peril on that peril's cost (`y_cost_<peril>`); line prediction = sum of the peril predictions; every peril model shares the line's early-stopping holdout |
| Large-loss cap | cost capped at p99.9 of its positive values in the fit years (line total in v0, each peril in v1 on); cap loading on predictions |
| IBNR | per-peril count factors (`ibnr_factors_by_peril.csv`): weighted by the row's peril costs for the line total (v0), the peril's own factor (v1); v2 the peril's cost-weighted factor (`output/ben/ibnr_cost_by_peril.csv`). Validation 'developed' actuals always use the count factors, so variants compare like for like |
| Trend | log-linear trend in capped, developed burn cost over all years before the scored year, clamped to +-5%; v0-v1 the line's trend, v2 each peril's own |
| Features | as BEN 1 v6: excluded compulsory_excess, years_with_insurer, customer_since_year, campaign_code, written_premium ; premium_index and 2021-24 address weather averages; renewal_count capped at the training maximum. v2 reads data/ben/ (R/ben/ben_clean.R): ordered text as natural-order integers ( credit_band, energy_rating, urban_density, security_level, cover_type ), labels stored as numbers as categories ( branch_id, start_month ), plus claims history hist_policy_claims, hist_policy_cost, hist_customer_other_claims, hist_address_property_claims |
| Categorical encoding | levels ordered by the model's own cost rate with 200 exposure-years of credibility towards its mean |
| XGBoost parameters | motor: max_depth=3, learning_rate=0.03, min_child_weight=50, subsample=0.8, colsample_bytree=0.6, reg_lambda=1, tweedie_variance_power=1.4 | buildings: max_depth=3, learning_rate=0.05, min_child_weight=10, subsample=0.8, colsample_bytree=0.6, reg_lambda=10, tweedie_variance_power=1.4 | contents: max_depth=3, learning_rate=0.05, min_child_weight=200, subsample=0.8, colsample_bytree=0.6, reg_lambda=10, tweedie_variance_power=1.4 |
| Monotone constraints | ncb_years decreasing; prior_claims_5y increasing; licence_points increasing; missed_payments_12m increasing; flood_zone increasing; voluntary_excess decreasing. v2: flood_zone only in the flood models; claims history increasing |
| AutoML (v3) | h2o 3.44.0.3, algorithms GBM, GLM, DRF (no XGBoost on Windows, no deep learning or stacked ensembles); per peril up to 8 candidates / 300 s, fit on 2021 (10% policy holdout for early stopping), ranked by Tweedie D2 on 2022; the best candidate's settings are refitted per window with a fixed size; text columns as native h2o categories; balance factor per peril; no monotone constraints (h2o 3.44 GBM fails with them under Tweedie); 16 threads |
| Seed | 2026 + per-fit offset by line and year (fit_seed(), as BEN 1) |

## Variants: what each change does
Each variant adds one change to the one before, with the same seeds; v0 reproduces BEN 1's selected model (v6).

![](variants.png)

| line | variant | label | d2_2023 | d2_2024 | d2_developed_2023 | d2_developed_2024 | pred_vs_reported_2023 | pred_vs_reported_2024 | mean_d2 |
|---|---|---|---|---|---|---|---|---|---|
| buildings | v0 | BEN 1 v6: one XGBoost Tweedie per line | 0.0686 | 0.0731 | 0.0684 | 0.0684 | 0.9218 | 0.9586 | 0.0708 |
| buildings | v1 | + one model per peril, line = sum of perils | 0.0625 | 0.0719 | 0.0622 | 0.0666 | 0.8275 | 0.9032 | 0.0672 |
| buildings | v2 | + BEN cleaning (types, claims history), cost IBNR, trend and constraints per peril | 0.0605 | 0.0707 | 0.0601 | 0.0648 | 0.8047 | 0.8764 | 0.0656 |
| buildings | v3 | + h2o AutoML per peril, plus a log-link GLM candidate (chosen on 2021 -> 2022), balance factor | 0.0587 | 0.0614 | 0.0584 | 0.0564 | 0.9417 | 0.9928 | 0.0601 |
| contents | v0 | BEN 1 v6: one XGBoost Tweedie per line | 0.0625 | 0.0625 | 0.0624 | 0.0626 | 0.8336 | 0.9801 | 0.0625 |
| contents | v1 | + one model per peril, line = sum of perils | 0.0534 | 0.0592 | 0.0534 | 0.0588 | 0.7828 | 0.9336 | 0.0563 |
| contents | v2 | + BEN cleaning (types, claims history), cost IBNR, trend and constraints per peril | 0.0578 | 0.0595 | 0.0578 | 0.0590 | 0.8090 | 0.9238 | 0.0586 |
| contents | v3 | + h2o AutoML per peril, plus a log-link GLM candidate (chosen on 2021 -> 2022), balance factor | 0.0606 | 0.0539 | 0.0606 | 0.0540 | 0.9209 | 1.0247 | 0.0572 |
| motor | v0 | BEN 1 v6: one XGBoost Tweedie per line | 0.0384 | 0.0514 | 0.0372 | 0.0538 | 0.8983 | 1.1256 | 0.0449 |
| motor | v1 | + one model per peril, line = sum of perils | 0.0119 | 0.0510 | 0.0095 | 0.0518 | 0.8849 | 1.0924 | 0.0315 |
| motor | v2 | + BEN cleaning (types, claims history), cost IBNR, trend and constraints per peril | 0.0097 | 0.0512 | 0.0071 | 0.0544 | 0.8692 | 1.1424 | 0.0305 |
| motor | v3 | + h2o AutoML per peril, plus a log-link GLM candidate (chosen on 2021 -> 2022), balance factor | 0.0511 | -1.3238 | 0.0511 | -1.1688 | 1.0005 | 1,018,101.4598 | -0.6363 |

Three lines combined (one baseline, as Kaggle scores the file):

| variant | d2_2023 | d2_2024 | d2_developed_2023 | d2_developed_2024 | gini_2023 | gini_2024 |
|---|---|---|---|---|---|---|
| selected per line | 0.1000 | 0.0998 | 0.1003 | 0.1048 | 0.5109 | 0.4938 |
| v0 | 0.1000 | 0.0998 | 0.1003 | 0.1048 | 0.5109 | 0.4938 |
| v1 | 0.0844 | 0.0986 | 0.0841 | 0.1026 | 0.4772 | 0.4911 |
| v2 | 0.0835 | 0.0983 | 0.0830 | 0.1032 | 0.4758 | 0.4904 |
| v3 | 0.1023 | -0.4917 | 0.1031 | -0.4415 | 0.5162 | 0.4844 |

## Selected per line
| line | variant | label | mean_d2 |
|---|---|---|---|
| motor | v0 | BEN 1 v6: one XGBoost Tweedie per line | 0.0449 |
| buildings | v0 | BEN 1 v6: one XGBoost Tweedie per line | 0.0708 |
| contents | v0 | BEN 1 v6: one XGBoost Tweedie per line | 0.0625 |

## Accuracy of the selection - local Kaggle score
`deviance_share` = the line's share of the remaining combined error.

| line | d2_2023 | d2_2024 | deviance_share_2023 | deviance_share_2024 |
|---|---|---|---|---|
| motor | 0.0384 | 0.0514 | 0.4863 | 0.4488 |
| buildings | 0.0686 | 0.0731 | 0.3341 | 0.3613 |
| contents | 0.0625 | 0.0625 | 0.1796 | 0.1899 |
| ALL | 0.1000 | 0.0998 | 1 | 1 |

## Per-peril models
Each peril model's D2 against that peril's own cost (low for rare perils, which are mostly zeros).

![](d2_by_peril.png)

| line | peril | variant | cost_share_2023 | cost_share_2024 | d2_2023 | d2_2024 | d2_developed_2023 | d2_developed_2024 | trend_2023 | trend_2024 |
|---|---|---|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | v1 | 0.0174 | 0.0189 | 0.1378 | 0.1200 | 0.1378 | 0.1187 | 0.0500 | 0.0500 |
| buildings | accidental_damage | v2 | 0.0174 | 0.0189 | 0.1339 | 0.1212 | 0.1339 | 0.1195 | 0.0500 | 0.0159 |
| buildings | accidental_damage | v3 | 0.0174 | 0.0189 | 0.1416 | 0.1335 | 0.1416 | 0.1328 | 0.0500 | 0.0159 |
| buildings | escape_of_water | v1 | 0.2309 | 0.2464 | 0.0274 | 0.0414 | 0.0273 | 0.0398 | 0.0500 | 0.0500 |
| buildings | escape_of_water | v2 | 0.2309 | 0.2464 | 0.0238 | 0.0433 | 0.0237 | 0.0416 | -0.0078 | 0.0500 |
| buildings | escape_of_water | v3 | 0.2309 | 0.2464 | 0.0250 | 0.0412 | 0.0249 | 0.0406 | -0.0078 | 0.0500 |
| buildings | fire | v1 | 0.2174 | 0.2335 | 0.0141 | 0.0197 | 0.0141 | 0.0189 | 0.0500 | 0.0500 |
| buildings | fire | v2 | 0.2174 | 0.2335 | 0.0103 | 0.0083 | 0.0103 | 0.0072 | 0.0500 | 0.0156 |
| buildings | fire | v3 | 0.2174 | 0.2335 | -0.0011 | 0.0010 | -0.0010 | 0.0007 | 0.0500 | 0.0156 |
| buildings | flood | v1 | 0.2782 | 0.2750 | 0.4325 | 0.4408 | 0.4326 | 0.4398 | 0.0500 | 0.0500 |
| buildings | flood | v2 | 0.2782 | 0.2750 | 0.4428 | 0.4346 | 0.4428 | 0.4331 | 0.0201 | 0.0338 |
| buildings | flood | v3 | 0.2782 | 0.2750 | 0.4446 | 0.3989 | 0.4445 | 0.3969 | 0.0201 | 0.0338 |
| buildings | storm | v1 | 0.1190 | 0.1090 | 0.0442 | 0.0603 | 0.0441 | 0.0597 | 0.0500 | 0.0500 |
| buildings | storm | v2 | 0.1190 | 0.1090 | 0.0358 | 0.0616 | 0.0356 | 0.0609 | 0.0500 | 0.0500 |
| buildings | storm | v3 | 0.1190 | 0.1090 | 0.0361 | 0.0573 | 0.0360 | 0.0569 | 0.0500 | 0.0500 |
| buildings | subsidence | v1 | 0.1370 | 0.1172 | 0.0552 | 0.0801 | 0.0541 | 0.0727 | 0.0500 | 0.0500 |
| buildings | subsidence | v2 | 0.1370 | 0.1172 | 0.0495 | 0.0777 | 0.0484 | 0.0604 | 0.0500 | 0.0500 |
| buildings | subsidence | v3 | 0.1370 | 0.1172 | -0.0001 | 0.0009 | -0.0006 | -0.0071 | 0.0500 | 0.0500 |
| contents | accidental_damage | v1 | 0.1058 | 0.1076 | 0.1337 | 0.1394 | 0.1337 | 0.1390 | 0.0039 | 0.0497 |
| contents | accidental_damage | v2 | 0.1058 | 0.1076 | 0.1330 | 0.1370 | 0.1330 | 0.1362 | -0.0356 | 0.0288 |
| contents | accidental_damage | v3 | 0.1058 | 0.1076 | 0.1369 | 0.1385 | 0.1369 | 0.1383 | -0.0356 | 0.0288 |
| contents | escape_of_water | v1 | 0.2161 | 0.2186 | 0.0220 | 0.0492 | 0.0219 | 0.0493 | 0.0039 | 0.0497 |
| contents | escape_of_water | v2 | 0.2161 | 0.2186 | 0.0210 | 0.0485 | 0.0209 | 0.0484 | 0.0500 | 0.0422 |
| contents | escape_of_water | v3 | 0.2161 | 0.2186 | 0.0246 | 0.0381 | 0.0246 | 0.0389 | 0.0500 | 0.0422 |
| contents | flood | v1 | 0.2699 | 0.2252 | 0.4508 | 0.3181 | 0.4505 | 0.3135 | 0.0039 | 0.0497 |
| contents | flood | v2 | 0.2699 | 0.2252 | 0.4136 | 0.2986 | 0.4133 | 0.2932 | -0.0500 | 0.0500 |
| contents | flood | v3 | 0.2699 | 0.2252 | 0.4068 | 0.2127 | 0.4066 | 0.2072 | -0.0500 | 0.0500 |
| contents | theft | v1 | 0.4081 | 0.4486 | 0.0087 | 0.0290 | 0.0087 | 0.0285 | 0.0039 | 0.0497 |
| contents | theft | v2 | 0.4081 | 0.4486 | 0.0225 | 0.0284 | 0.0224 | 0.0279 | 0.0379 | 0.0500 |
| contents | theft | v3 | 0.4081 | 0.4486 | 0.0330 | 0.0339 | 0.0330 | 0.0337 | 0.0379 | 0.0500 |
| motor | bodily_injury | v1 | 0.4071 | 0.2316 | -0.0034 | 0.0159 | -0.0073 | 0.0596 | 0.0243 | -0.0200 |
| motor | bodily_injury | v2 | 0.4071 | 0.2316 | -0.0178 | 0.0260 | -0.0235 | 0.0569 | -0.0104 | -0.0500 |
| motor | bodily_injury | v3 | 0.4071 | 0.2316 | 0.0756 | -0.0106 | 0.0761 | 0.0394 | -0.0104 | -0.0500 |
| motor | glass_hail | v1 | 0.0401 | 0.0528 | 0.1325 | 0.1262 | 0.1325 | 0.1245 | 0.0243 | -0.0200 |
| motor | glass_hail | v2 | 0.0401 | 0.0528 | 0.1338 | 0.1336 | 0.1337 | 0.1329 | 0.0500 | 0.0500 |
| motor | glass_hail | v3 | 0.0401 | 0.0528 | 0.1351 | 0.1309 | 0.1350 | 0.1305 | 0.0500 | 0.0500 |
| motor | own_damage | v1 | 0.1896 | 0.2595 | 0.1626 | 0.1658 | 0.1625 | 0.1639 | 0.0243 | -0.0200 |
| motor | own_damage | v2 | 0.1896 | 0.2595 | 0.1639 | 0.1703 | 0.1638 | 0.1689 | 0.0494 | 0.0046 |
| motor | own_damage | v3 | 0.1896 | 0.2595 | 0.1599 | 0.1644 | 0.1599 | 0.1632 | 0.0494 | 0.0046 |
| motor | theft | v1 | 0.0909 | 0.1087 | 0.0507 | 0.0701 | 0.0506 | 0.0691 | 0.0243 | -0.0200 |
| motor | theft | v2 | 0.0909 | 0.1087 | 0.0434 | 0.0751 | 0.0433 | 0.0748 | -0.0497 | 0.0500 |
| motor | theft | v3 | 0.0909 | 0.1087 | 0.0411 | 0.0541 | 0.0411 | 0.0544 | -0.0497 | 0.0500 |
| motor | third_party_prop | v1 | 0.2722 | 0.3473 | 0.0532 | 0.0485 | 0.0532 | 0.0454 | 0.0243 | -0.0200 |
| motor | third_party_prop | v2 | 0.2722 | 0.3473 | 0.0547 | 0.0520 | 0.0547 | 0.0514 | 0.0500 | 0.0500 |
| motor | third_party_prop | v3 | 0.2722 | 0.3473 | 0.0584 | -2.0261 | 0.0584 | -1.9621 | 0.0500 | 0.0500 |

## BEN cleaning used by v2 (`R/ben/ben_clean.R`)
Details and how to import it into the shared pipeline: `R/ben/README.md`. Copies of its outputs: `ben_clean/`.

| line | feature | type_before | type_after | encoding |
|---|---|---|---|---|
| motor | credit_band | character | integer | A < B < C < D < E |
| motor | energy_rating | character | integer | A < B < C < D < E < F < G |
| motor | urban_density | character | integer | rural < suburban < urban < dense_urban |
| motor | cover_type | character | integer | third_party_only < third_party_fire_theft < comprehensive |
| motor | branch_id | integer | character | category (levels ordered by credibility-weighted cost rate in the model) |
| motor | start_month | integer | character | category (levels ordered by credibility-weighted cost rate in the model) |
| buildings | credit_band | character | integer | A < B < C < D < E |
| buildings | energy_rating | character | integer | A < B < C < D < E < F < G |
| buildings | urban_density | character | integer | rural < suburban < urban < dense_urban |
| buildings | branch_id | integer | character | category (levels ordered by credibility-weighted cost rate in the model) |
| buildings | start_month | integer | character | category (levels ordered by credibility-weighted cost rate in the model) |
| contents | credit_band | character | integer | A < B < C < D < E |
| contents | energy_rating | character | integer | A < B < C < D < E < F < G |
| contents | urban_density | character | integer | rural < suburban < urban < dense_urban |
| contents | security_level | character | integer | standard < locks < alarm_and_locks |
| contents | branch_id | integer | character | category (levels ordered by credibility-weighted cost rate in the model) |
| contents | start_month | integer | character | category (levels ordered by credibility-weighted cost rate in the model) |

Claim frequency of the row by its own claims in the previous 365 days (2022-24):

| line | level | exposure | frequency |
|---|---|---|---|
| motor | 0 | 539,644.7562 | 0.1264 |
| motor | 1 | 52,984.4110 | 0.2274 |
| motor | 2+ | 6,536.8164 | 0.4398 |
| buildings | 0 | 434,698.7589 | 0.0436 |
| buildings | 1 | 14,580.4000 | 0.0724 |
| buildings | 2+ | 498.0932 | 0.1084 |
| contents | 0 | 435,875.7178 | 0.0394 |
| contents | 1 | 13,609.9041 | 0.0639 |
| contents | 2+ | 442.2822 | 0.1017 |

## v3: AutoML per peril
Best candidate per peril (fit 2021, ranked by Tweedie D2 on 2022); every candidate is in `automl_ranking.csv`.
h2o 3.44 limits seen in testing: AutoML's Tweedie GLMs use an identity link (near-flat predictions), hence the extra log-link GLM candidate (`*_GLM_log_link`); its Tweedie GBMs under-predict by about half with near-zero predictions on some rows, and fail outright with monotone constraints; no XGBoost on Windows.

| line | peril | algo | model_id | d2_2022 | pred_vs_actual |
|---|---|---|---|---|---|
| motor | own_damage | glm | ben02_motor_own_damage_20261022_1438_GLM_log_link | 0.1528 | 0.8734 |
| motor | third_party_prop | glm | ben02_motor_third_party_prop_20261022_1438_GLM_log_link | 0.0608 | 0.9017 |
| motor | bodily_injury | glm | ben02_motor_bodily_injury_20261022_1438_GLM_log_link | 0.0519 | 0.9898 |
| motor | theft | glm | ben02_motor_theft_20261022_1438_GLM_log_link | 0.0360 | 0.9746 |
| motor | glass_hail | glm | ben02_motor_glass_hail_20261022_1438_GLM_log_link | 0.1176 | 0.9136 |
| buildings | storm | glm | ben02_buildings_storm_20261022_1438_GLM_log_link | 0.0510 | 1.0230 |
| buildings | flood | glm | ben02_buildings_flood_20261022_1438_GLM_log_link | 0.3847 | 1.1108 |
| buildings | escape_of_water | glm | ben02_buildings_escape_of_water_20261022_1438_GLM_log_link | 0.0301 | 0.9516 |
| buildings | subsidence | glm | GLM_1_AutoML_9_20261022_152702 | -0.0010 | 0.8633 |
| buildings | fire | glm | GLM_1_AutoML_10_20261022_153010 | -0.0009 | 0.9046 |
| buildings | accidental_damage | glm | ben02_buildings_accidental_damage_20261022_1438_GLM_log_link | 0.1462 | 0.7806 |
| contents | theft | glm | ben02_contents_theft_20261022_1438_GLM_log_link | 0.0243 | 0.9203 |
| contents | escape_of_water | glm | ben02_contents_escape_of_water_20261022_1438_GLM_log_link | 0.0258 | 0.8968 |
| contents | accidental_damage | glm | ben02_contents_accidental_damage_20261022_1438_GLM_log_link | 0.1348 | 0.9800 |
| contents | flood | glm | ben02_contents_flood_20261022_1438_GLM_log_link | 0.3970 | 1.0108 |

| line | algo | candidates | best_d2_2022 |
|---|---|---|---|
| motor | glm | 10 | 0.1528 |
| motor | gbm | 25 | 0.0489 |
| motor | drf | 10 | 0.0387 |
| buildings | glm | 12 | 0.3847 |
| buildings | drf | 12 | 0.2328 |
| buildings | gbm | 30 | -0.1838 |
| contents | glm | 8 | 0.3970 |
| contents | drf | 8 | 0.1084 |
| contents | gbm | 20 | -0.2231 |

## Final models (fit 2021-24)
| line | model | trend | cap | cap_loading | rounds |
|---|---|---|---|---|---|
| motor | all | -0.0129 | 124,533.7516 | 1.0507 | 670 |
| buildings | all | 0.0500 | 280,163.0336 | 1.0067 | 334 |
| contents | all | 0.0478 | 45,596.9493 | 1.0063 | 209 |

## 2025 test predictions
| line | variant | models | test_exposure | predicted_total | predicted_burn_cost | train_burn_2023_24 | p50_row | p90_row | p99_row | max_row |
|---|---|---|---|---|---|---|---|---|---|---|
| motor | v0 | 1 | 199,983.581 | 101,093,244.305 | 505.508 | 520.630 | 333.101 | 748.285 | 1,571.175 | 7,067.129 |
| buildings | v0 | 1 | 150,243.904 | 68,574,012.871 | 456.418 | 440.761 | 283.156 | 670.821 | 2,184.749 | 12,799.617 |
| contents | v0 | 1 | 150,123.770 | 18,369,728.171 | 122.364 | 116.874 | 78.457 | 181.098 | 476.664 | 3,488.350 |

## Features used
| line | n_features | features |
|---|---|---|
| motor | 73 | driver_age, years_licensed, ncb_years, vehicle_value_group, vehicle_age, make_model, engine_size_cc, body_type, transmission, seats, vehicle_colour, fuel_type, driver_assist, cover_type, annual_mileage, overnight_parking, vehicle_use, named_young_driver, telematics_opt_in, telematics_score, voluntary_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, email_domain, marketing_consent, document_preference, previous_insurer, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, premium_index, wx_avg_hail_days, wx_avg_wind_exposure_index, wx_avg_freezing_days, wx_avg_dry_summer_index, wx_avg_wildfire_index, wx_avg_rainfall_mm, wx_avg_mean_temperature_c |
| buildings | 61 | policyholder_age, sum_insured, construction_type, occupancy, days_unoccupied, smoke_alarms, accidental_damage_cover, mortgage, voluntary_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, email_domain, marketing_consent, document_preference, previous_insurer, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, premium_index, wx_avg_hail_days, wx_avg_wind_exposure_index, wx_avg_freezing_days, wx_avg_dry_summer_index, wx_avg_wildfire_index, wx_avg_rainfall_mm, wx_avg_mean_temperature_c |
| contents | 62 | policyholder_age, sum_insured, tenure, security_level, high_value_items, accidental_damage_cover, works_from_home, lodgers, bicycle_cover, voluntary_excess, channel, payment_method, missed_payments_12m, new_business, renewal_count, days_quote_to_inception, discount_applied, occupation, marital_status, household_size, credit_band, prior_claims_5y, licence_points, years_at_address, email_domain, marketing_consent, document_preference, previous_insurer, branch_id, marketing_segment, region, urban_density, flood_zone, distance_to_river_km, elevation_m, soil_type, year_built, property_type, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels, hail_days, wind_exposure_index, freezing_days, dry_summer_index, wildfire_index, rainfall_mm, mean_temperature_c, customer_age, start_month, premium_index, wx_avg_hail_days, wx_avg_wind_exposure_index, wx_avg_freezing_days, wx_avg_dry_summer_index, wx_avg_wildfire_index, wx_avg_rainfall_mm, wx_avg_mean_temperature_c |

## Variable importance (final fit, share of total gain, top 5 per model)
| line | model | rank | Feature | Gain |
|---|---|---|---|---|
| motor | all | 1 | ncb_years | 0.1728 |
| motor | all | 2 | premium_index | 0.1526 |
| motor | all | 3 | annual_mileage | 0.0696 |
| motor | all | 4 | make_model | 0.0533 |
| motor | all | 5 | customer_age | 0.0471 |
| buildings | all | 1 | premium_index | 0.2080 |
| buildings | all | 2 | flood_zone | 0.1014 |
| buildings | all | 3 | elevation_m | 0.0870 |
| buildings | all | 4 | sum_insured | 0.0652 |
| buildings | all | 5 | distance_to_river_km | 0.0481 |
| contents | all | 1 | flood_zone | 0.2396 |
| contents | all | 2 | premium_index | 0.1810 |
| contents | all | 3 | elevation_m | 0.1182 |
| contents | all | 4 | sum_insured | 0.0661 |
| contents | all | 5 | distance_to_river_km | 0.0415 |

