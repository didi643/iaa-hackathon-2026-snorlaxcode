# Iteration BEN 4 (`ben_iteration_04`)

**Run id** `20261022_2319` | **Generated** 2026-10-22 23:53 | **Git commit** `f3e5f95 + uncommitted changes in R/` | **Submission file** `submission_20261022_2319.csv` | **MD5** `e707849fbf827bda2032fe121a665e3c` | **Quick mode** FALSE

**Change in this iteration:** LightGBM on point-in-time features (claims history at 1 January, previous row, prior declines, row shape, holdings) with claim-capped, chain-ladder-developed, trended targets; line Tweedie vs per-peril Poisson x Gamma, blended per line.

## Variants: D2 against developed actuals (selection basis), by line and year
| variant | label | buildings_2023 | buildings_2024 | combined_2023 | combined_2024 | contents_2023 | contents_2024 | motor_2023 | motor_2024 |
|---|---|---|---|---|---|---|---|---|---|
| v0 | line Tweedie, BEN 1 features | 0.0701 | 0.0681 | 0.1024 | 0.1035 | 0.0658 | 0.0616 | 0.0388 | 0.0515 |
| v1 | + BEN 4 point-in-time features | 0.0689 | 0.0669 | 0.0997 | 0.1059 | 0.0654 | 0.0624 | 0.0337 | 0.0576 |
| v2 | v1 without the row-shape group | 0.0690 | 0.0673 | 0.1039 | 0.1051 | 0.0658 | 0.0624 | 0.0427 | 0.0554 |
| v3 | v1 weighted by sqrt(exposure) | 0.0689 | 0.0684 | 0.1016 | 0.1060 | 0.0655 | 0.0618 | 0.0379 | 0.0569 |
| v4 | per-peril Poisson x Gamma, BEN 4 features | 0.0660 | 0.0716 | 0.0976 | 0.1087 | 0.0655 | 0.0625 | 0.0312 | 0.0602 |
| v5 | blend of the better line model with v4 | 0.0692 | 0.0716 | 0.1018 | 0.1086 | 0.0673 | 0.0639 | 0.0373 | 0.0596 |

## Variants: D2 against reported actuals (as earlier BEN cards)
| variant | label | buildings_2023 | buildings_2024 | combined_2023 | combined_2024 | contents_2023 | contents_2024 | motor_2023 | motor_2024 |
|---|---|---|---|---|---|---|---|---|---|
| v0 | line Tweedie, BEN 1 features | 0.0702 | 0.0708 | 0.1016 | 0.0975 | 0.0659 | 0.0613 | 0.0395 | 0.0486 |
| v1 | + BEN 4 point-in-time features | 0.0692 | 0.0702 | 0.0990 | 0.0994 | 0.0654 | 0.0621 | 0.0348 | 0.0531 |
| v2 | v1 without the row-shape group | 0.0692 | 0.0697 | 0.1030 | 0.0984 | 0.0658 | 0.0622 | 0.0433 | 0.0511 |
| v3 | v1 weighted by sqrt(exposure) | 0.0691 | 0.0711 | 0.1009 | 0.0992 | 0.0656 | 0.0613 | 0.0389 | 0.0523 |
| v4 | per-peril Poisson x Gamma, BEN 4 features | 0.0662 | 0.0734 | 0.0970 | 0.1014 | 0.0655 | 0.0621 | 0.0324 | 0.0551 |
| v5 | blend of the better line model with v4 | 0.0694 | 0.0736 | 0.1010 | 0.1014 | 0.0673 | 0.0635 | 0.0383 | 0.0545 |

## Combined, all three lines (one exposure baseline; `d2_flat` = flat-mean baseline)
| variant | year | d2 | d2_dev | d2_flat | pred_over_dev |
|---|---|---|---|---|---|
| v0 | 2023 | 0.1016 | 0.1024 | 0.1374 | 0.9460 |
| v0 | 2024 | 0.0975 | 0.1035 | 0.1292 | 0.9497 |
| v1 | 2023 | 0.0990 | 0.0997 | 0.1350 | 0.9487 |
| v1 | 2024 | 0.0994 | 0.1059 | 0.1311 | 0.9614 |
| v2 | 2023 | 0.1030 | 0.1039 | 0.1387 | 0.9524 |
| v2 | 2024 | 0.0984 | 0.1051 | 0.1301 | 0.9580 |
| v3 | 2023 | 0.1009 | 0.1016 | 0.1367 | 0.9482 |
| v3 | 2024 | 0.0992 | 0.1060 | 0.1308 | 0.9608 |
| v4 | 2023 | 0.0970 | 0.0976 | 0.1330 | 0.9633 |
| v4 | 2024 | 0.1014 | 0.1087 | 0.1329 | 0.9661 |
| v5 | 2023 | 0.1010 | 0.1018 | 0.1368 | 0.9542 |
| v5 | 2024 | 0.1014 | 0.1086 | 0.1330 | 0.9628 |

## Selection (per line, mean developed D2 over 2023 and 2024)
| line | variant | d2_dev | d2 |
|---|---|---|---|
| motor | v2 | 0.0491 | 0.0472 |
| buildings | v5 | 0.0704 | 0.0715 |
| contents | v5 | 0.0656 | 0.0654 |

Selected combined D2:

| year | d2 | d2_dev | d2_flat |
|---|---|---|---|
| 2023 | 0.1033 | 0.1042 | 0.1390 |
| 2024 | 0.1000 | 0.1068 | 0.1316 |

## Blend weight of the line model (v5)
| line | line_model | w_line | d2 | d2_dev |
|---|---|---|---|---|
| buildings | v3 | 0.5000 | 0.0715 | 0.0704 |
| contents | v1 | 0.5000 | 0.0654 | 0.0656 |
| motor | v3 | 0.6000 | 0.0464 | 0.0484 |

## Trend used (line burn, fitted on the fit years, clamped)
| line | year | trend |
|---|---|---|
| motor | 2023 | 0.0310 |
| motor | 2024 | -0.0160 |
| motor | 2025 | -0.0124 |
| buildings | 2023 | 0.0505 |
| buildings | 2024 | 0.0600 |
| buildings | 2025 | 0.0600 |
| contents | 2023 | -0.0016 |
| contents | 2024 | 0.0540 |
| contents | 2025 | 0.0513 |

## Ceiling

If v4's 2024 per-peril frequency and severity were the true means, the same predictions would score a combined D2 of 0.097 / 0.1008 / 0.1041 on the 2024 rows (3 simulations; claim sizes resampled from each peril's 2021-23 claims). Real D2 can only exceed this if the true risk varies more than the model believes.

## 2025 predictions, cost per exposure-year
| line | v0 | v1 | v2 | v3 | v4 | v5 | selected |
|---|---|---|---|---|---|---|---|
| motor | 510.5 | 529.2 | 529.7 | 531.5 | 532.0 | 531.7 | 529.7 |
| buildings | 499.2 | 501.7 | 501.2 | 502.1 | 502.2 | 502.2 | 502.2 |
| contents | 126.9 | 128.4 | 127.9 | 128.4 | 128.7 | 128.6 | 128.6 |

Anchor from `R/ben/ben3_study.R`: motor ~548 (~560 with a large-loss load), buildings ~489, contents ~128.

## Top features (gain, final v1 line model)
| line | feature | gain |
|---|---|---|
| motor | ncb_years | 0.1682 |
| motor | premium_index | 0.1638 |
| motor | make_model | 0.0746 |
| motor | annual_mileage | 0.0645 |
| motor | years_licensed | 0.0567 |
| motor | customer_age | 0.0491 |
| motor | prior_claims_5y | 0.0309 |
| motor | driver_age | 0.0270 |
| motor | voluntary_excess | 0.0235 |
| motor | vehicle_age | 0.0218 |
| motor | cover_type | 0.0204 |
| motor | urban_density | 0.0173 |
| buildings | premium_index | 0.4552 |
| buildings | elevation_m | 0.1054 |
| buildings | flood_zone | 0.0881 |
| buildings | sum_insured | 0.0633 |
| buildings | year_built | 0.0472 |
| buildings | energy_rating | 0.0306 |
| buildings | prior_claims_5y | 0.0252 |
| buildings | bedrooms | 0.0241 |
| buildings | missed_payments_12m | 0.0148 |
| buildings | construction_type | 0.0112 |
| buildings | previous_insurer | 0.0109 |
| buildings | b4_last_peril | 0.0107 |
| contents | flood_zone | 0.2244 |
| contents | premium_index | 0.1621 |
| contents | elevation_m | 0.1337 |
| contents | sum_insured | 0.0719 |
| contents | distance_to_river_km | 0.0369 |
| contents | prior_claims_5y | 0.0281 |
| contents | voluntary_excess | 0.0235 |
| contents | customer_age | 0.0208 |
| contents | policyholder_age | 0.0188 |
| contents | region | 0.0173 |
| contents | accidental_damage_cover | 0.0154 |
| contents | missed_payments_12m | 0.0134 |

## Replication (saved models reloaded and rescored)
| line | rows | max_abs_diff |
|---|---|---|
| motor | 254,986 | 0 |
| buildings | 184,155 | 0 |
| contents | 187,498 | 0 |

Replication check: **passed**

## Settings

- Line Tweedie: objective=tweedie, tweedie_variance_power=1.5, learning_rate=0.05, num_leaves=8, max_depth=3, min_data_in_leaf=1000, feature_fraction=0.6, bagging_fraction=0.8, bagging_freq=1, lambda_l2=20, verbosity=-1, num_threads=20, deterministic=TRUE, force_col_wise=TRUE
- Frequency: objective=poisson, tweedie_variance_power=1.5, learning_rate=0.05, num_leaves=15, max_depth=4, min_data_in_leaf=1000, feature_fraction=0.6, bagging_fraction=0.8, bagging_freq=1, lambda_l2=20, verbosity=-1, num_threads=20, deterministic=TRUE, force_col_wise=TRUE
- Severity: objective=gamma, tweedie_variance_power=1.5, learning_rate=0.03, num_leaves=7, max_depth=3, min_data_in_leaf=200, feature_fraction=0.6, bagging_fraction=0.8, bagging_freq=1, lambda_l2=50, verbosity=-1, num_threads=20, deterministic=TRUE, force_col_wise=TRUE
- Rounds: early stopping (100) on a 15% policy holdout of the fit years, then refit on all at 1.1x the best round; max 3000
- Excluded: row_id, policy_id, customer_id, address_id, period_start, period_end, exposure, exposure_raw, renewal_decision, surname, date_of_birth, policy_year, customer_service_contacts, compulsory_excess, years_with_insurer, customer_since_year, campaign_code, written_premium, discount_applied, email_domain, vehicle_colour, document_preference, marketing_consent, branch_id, marketing_segment
- Trend clamp -0.03 to 0.06; claim cap p99.9 per peril (2021-23); loading = 2m-limited / capped cost

## Public score and follow-ups (added after the run, 2026-10-23)
- Public D² **0.12656** (submission #16), against SAM 3 0.12818 and BEN 3 0.12698.
- `R/ben/ben4_blend.R`: blending all five variants per line gives 0.1032 / 0.1010 (2023 / 2024) against 0.1033 / 0.1000
  for the selection; it does not win both folds, so it is not used.
- `R/ben/ben4_level.R`: motor predicts 0.94 / 0.95 of developed actuals; combined developed D² is best with motor x1.05-1.10.
  Candidate `submission_20261022_2319_ben04_motor603.csv` scales motor x1.139 to SAM 3's 2025 level (603), MD5
  `28cf3c80eaae9543fa0bf83353483ea0`, as a public test of level against ranking.
- Row-level test predictions of every variant: `output/ben/ben4/test_predictions_by_variant.csv.gz` (git-ignored).
