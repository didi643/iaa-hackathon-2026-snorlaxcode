# Week 2 - The New Market (emerging market)

> **Final submission (30 Oct 2026):** #31 `submission_20261030_0905_week2_motorlevel_l_full.csv`, public 0.16840. It is the pre-probing model #12 `line_ensemble` with an actuarial motor level review (`R/29_motor_level.R`, quick rebuild `R/30_final_from_components.R`, full build `run/build_final_motorlevel.ps1`). Leaderboard probing (scripts 25-27, `run/build_final_halfway.ps1`'s last step) was tried and set aside. See `docs/final_model_method_week2.md` sections 8A and 9. The sections below are the earlier development history.

This holds all Part 2 work, kept apart from week 1 (`week1/`, `data/week_1/`).

## Layout

| Path | Content |
|---|---|
| `data/week_2/raw data/emerging/` | Part 2 raw data: training 2023-24, 2025 test, expenses, reference policies |
| `data/week_2/raw data/developed/` | Part 1 raw data for reference (identical to `data/week_1/raw data/`) |
| `data/week_2/clean/` | Cleaned data for both markets (`emerging_*`, `developed_*`), from `2_clean_w2.R` |
| `week2/R/` | Week 2 scripts. Each sources `week2/R/0_setup_w2.R` (series 1-7) or `week2/R/00_setup_week2.R` (Option B series 00-17) |
| `week2/output/` | Generated reports and CSVs, one folder per step (git-ignored, like `week1/output/`) |
| `week2/docs/` | Hand-written decisions and logs; `docs/optionB/` holds the other laptop's step log, decisions, model card and handover |
| `week2/run/`, `week2/inputs/`, `week2/models/` | Option B run logs and `.sh` experiment grids, baseline workbooks and `submissions_week2.csv`, baseline model cards |
| `data/week_2/optionB/` | Option B caches (clean, features, baseline, adjust, final); generated, git-ignored |

## Run order (from the project root)

```
Rscript week2/R/1_checks_w2.R    # read-only raw data checks       -> week2/output/1_checks/checks_report.md
Rscript week2/R/2_clean_w2.R     # cleaning, both markets, targets -> data/week_2/clean/, week2/output/2_clean/cleaning_report.md
```

## Option B pipeline (submissions 3-7, best public 0.16612)

Run from the project root. Authoritative for submissions 3-7; it has its own cleaning (`02`), so its data is kept apart in `data/week_2/optionB/`.

```
Rscript week2/R/01_profile_emerging.R; Rscript week2/R/02_clean_week2.R; Rscript week2/R/03_harmonise_features.R
Rscript week2/R/03b_emerging_extra.R; Rscript week2/R/04_ibnr_trend_week2.R
BAGS=5 RUN_TAG=baseline Rscript week2/R/05_developed_baseline.R     # 1-2 hours
Rscript week2/R/06_score_emerging_baseline.R
zsh week2/run/build_final.sh                                          # steps 07, 14, 08, 09, 15 -> submission #7 (rebuild)
```

Steps 07-17 and the `run/*.sh` grids are the experiments behind submissions 4-7. `00_setup_week2.R` also appends to
`docs/optionB/step_log.md` and `decision_register.csv`; do not run it on its own.

## Documents

- `docs/cleaning_decisions_w2.md`: every data issue, its evidence and the decision, plus a first view of how the emerging market differs from Part 1.
- `docs/workflow_w2.md`: week 2 run log.
