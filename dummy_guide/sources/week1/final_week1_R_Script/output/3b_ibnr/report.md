# Step 3b - IBNR method study

Generated 2026-10-25 10:58 from `R/3b_ibnr_study.R`. Standalone; not used by any model yet.

## Backtest design
Each method is fitted on claims reported by a pseudo-valuation date and predicts, per claim, the late-reported count
(F(cut + h - t) - F(cut - t)) / max(F(cut - t), 0.05). Actual = claims reported in (cut, cut + h], fully observed at 2024-12-31.
Windows: 2022-12-31+12m, 2022-12-31+24m, 2023-06-30+12m, 2023-12-31+12m
Primary metric: mean over windows of the cost-weighted (2021-22 capped cost share) |log((A + 0.5) / (E + 0.5))| over line x peril,
for losses in the 12 months before the cut. SE: Poisson bootstrap on the actual counts (process noise only, paired across methods).

## Ranking
| rank | method | primary | se | diff_vs_M0 | diff_vs_M0_se | count_weighted | bias_cost_w | cost_ae | poisson_dev_vs_M0 | selected |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | M2_chain_ladder | 0.0996 | 0.0161 | -0.0796 | 0.0189 | 0.0680 | 0.0465 | 0.9151 | 0.9144 | TRUE |
| 2 | M0_current | 0.1792 | 0.0196 | 0 | 0 | 0.1405 | -0.0692 | 1.0056 | 1 | FALSE |
| 3 | M1_truncation_km | 0.1809 | 0.0202 | 0.0018 | 0.0076 | 0.1264 | -0.0333 | 0.9661 | 0.9436 | FALSE |
| 4 | M5_recent | 0.1832 | 0.0203 | 0.0040 | 0.0074 | 0.1313 | -0.0409 | 0.9702 | 1.0375 | FALSE |
| 5 | M4_credibility | 0.1890 | 0.0206 | 0.0098 | 0.0114 | 0.1251 | -0.0268 | 1.0053 | 0.9252 | FALSE |
| 6 | M3_parametric | 0.1922 | 0.0201 | 0.0130 | 0.0104 | 0.1159 | 0.0203 | 0.9528 | 1.3958 | FALSE |

Selected: **M2_chain_ladder** (simplest method within 1 SE of the best, M2_chain_ladder).
Credibility k (all windows): M4_k30. M6 stratifier: none.

## Per-peril selection
Override only when another method beats the winner by more than 2 bootstrap SEs.

| lp | winner_abs_log | best_method | best_abs_log | gain | gain_se | use_method |
|---|---|---|---|---|---|---|
| motor.own_damage | 0.0238 | M2_chain_ladder | 0.0238 | 0 | 0 | M2_chain_ladder |
| motor.third_party_prop | 0.0472 | M0_current | 0.0147 | 0.0326 | 0.0191 | M2_chain_ladder |
| motor.bodily_injury | 0.1073 | M0_current | 0.0489 | 0.0584 | 0.0134 | M0_current |
| motor.theft | 0.0730 | M2_chain_ladder | 0.0730 | 0 | 0 | M2_chain_ladder |
| motor.glass_hail | 0.0983 | M3_parametric | 0.0776 | 0.0207 | 0.0290 | M2_chain_ladder |
| buildings.storm | 0.1662 | M2_chain_ladder | 0.1662 | 0 | 0 | M2_chain_ladder |
| buildings.flood | 0.0690 | M2_chain_ladder | 0.0690 | 0 | 0 | M2_chain_ladder |
| buildings.escape_of_water | 0.0447 | M2_chain_ladder | 0.0447 | 0 | 0 | M2_chain_ladder |
| buildings.subsidence | 0.1235 | M2_chain_ladder | 0.1235 | 0 | 0 | M2_chain_ladder |
| buildings.fire | 0.2627 | M2_chain_ladder | 0.2627 | 0 | 0 | M2_chain_ladder |
| buildings.accidental_damage | 0.1909 | M5_recent | 0.0794 | 0.1115 | 0.0998 | M2_chain_ladder |
| contents.theft | 0.1004 | M2_chain_ladder | 0.1004 | 0 | 0 | M2_chain_ladder |
| contents.escape_of_water | 0.0754 | M2_chain_ladder | 0.0754 | 0 | 0 | M2_chain_ladder |
| contents.accidental_damage | 0.0516 | M2_chain_ladder | 0.0516 | 0 | 0 | M2_chain_ladder |
| contents.flood | 0.5145 | M0_current | 0.3592 | 0.1553 | 0.0793 | M2_chain_ladder |

## Replication of SAM 3
M0 at 2024-12-31 vs `data/sam03/ibnr.csv`: max |factor difference| = NA.

## Policy-year 2024 factors: SAM 3 vs recommended
| line | peril | policy_year | claims | method | recommended_factor |
|---|---|---|---|---|---|
| buildings | accidental_damage | 2024 | 989 | M2_chain_ladder | 1.0312 |
| buildings | escape_of_water | 2024 | 2,558 | M2_chain_ladder | 1.0738 |
| buildings | fire | 2024 | 309 | M2_chain_ladder | 1.0223 |
| buildings | flood | 2024 | 530 | M2_chain_ladder | 1.0220 |
| buildings | storm | 2024 | 1,894 | M2_chain_ladder | 1.0524 |
| buildings | subsidence | 2024 | 291 | M2_chain_ladder | 1.6072 |
| contents | accidental_damage | 2024 | 2,289 | M2_chain_ladder | 1.0363 |
| contents | escape_of_water | 2024 | 1,362 | M2_chain_ladder | 1.0596 |
| contents | flood | 2024 | 361 | M2_chain_ladder | 1.0393 |
| contents | theft | 2024 | 1,976 | M2_chain_ladder | 1.0208 |
| motor | bodily_injury | 2024 | 1,178 | M0_current | 1.7360 |
| motor | glass_hail | 2024 | 4,020 | M2_chain_ladder | 1.0285 |
| motor | own_damage | 2024 | 11,537 | M2_chain_ladder | 1.0343 |
| motor | theft | 2024 | 1,503 | M2_chain_ladder | 1.0193 |
| motor | third_party_prop | 2024 | 7,626 | M2_chain_ladder | 1.0614 |

## Diagnostics
- `cost_vs_count_factors.csv`: cost-weighted / count-weighted factor = implied severity adjustment for late claims (diagnostic only).
- `severity_by_lag.csv`: mean capped severity of closed 2021-22 claims by report lag.
- `open_claims_check.csv`: open vs closed severity; open-claim case development is not estimable from one valuation.
- `row_level_calibration.csv` / `row_level_factors.csv`: claim-level vs policy-year factors by policy start quarter.
- `lag_covariates.csv`: covariate effects on P(lag > 30 days) for losses at least a year old.

## Caveats
- Only counts are backtested; incurred values as at an earlier date cannot be rebuilt from one snapshot.
- Tails beyond the observed lag range (about 4 years) are untested; M3 extrapolates, the others assume none.
- Covariate choice for M6 and the credibility k for the final factors use all data (mild look-ahead).
