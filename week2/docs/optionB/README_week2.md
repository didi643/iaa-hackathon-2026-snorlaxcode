# Week 2 (emerging market, Option B): how to rerun

Everything for week 2 lives in `week_2/`. Run every command from the **repo root**, with R 4.6 and the packages
data.table, arrow, xgboost, readxl and openxlsx (ggplot2 for the step 6 charts). The raw data must be in
`data/week_1/` (developed) and `data/week_2/emerging/`.

| Step | Command | Time (Mac) | Writes |
|---|---|---|---|
| 0 | `Rscript week_2/R/00_setup_week2.R` | seconds | session info, decision register D001-D005 |
| 1 | `Rscript week_2/R/01_profile_emerging.R` | < 1 min | `week_2/output/01_profile/` |
| 2 | `Rscript week_2/R/02_clean_week2.R` | 1 min | `week_2/data/clean/`, `week_2/output/02_clean/` |
| 3 | `Rscript week_2/R/03_harmonise_features.R` | 1 min | `week_2/data/features/`, `week_2/output/03_features/` |
| 4 | `Rscript week_2/R/04_ibnr_trend_week2.R` | < 1 min | `week_2/output/04_ibnr_trend/` (report shares used by every later step) |
| 5 | `Rscript week_2/R/05_developed_baseline.R` | about 10-20 min | `week_2/inputs/assumptions_week2_baseline.xlsx`, `week_2/models/baseline/`, `week_2/data/baseline/`, `week_2/output/05_baseline/` |
| 6 | `Rscript week_2/R/06_score_emerging_baseline.R` | < 1 min | `week_2/output/06_ae/` |
| 7 | `Rscript week_2/R/07_emerging_adjust.R` | < 1 min | `week_2/data/adjust/main/`, `week_2/output/07_adjust/` |
| 8 | `Rscript week_2/R/08_loadings_2025.R` | < 1 min | `week_2/data/final/main/`, `week_2/output/08_loadings/main/` |
| 9 | `Rscript week_2/R/09_validate_compare.R` | < 1 min | `week_2/output/09_validate/main/` |
| 10 | `Rscript week_2/R/10_final_week2.R` | < 1 min | `week_2/output/submission/submission_<runid>_week2_optionB.csv` + `.md5`, `week_2/output/10_final/` |
| 11 | `Rscript week_2/R/11_docs_week2.R` | seconds | `week_2/docs/model_card_week2.md`, `uncertainty.md`, `doc_manifest.csv` |

Options:

- `FAST=1` (step 5): smoke test with fewer rounds and a higher learning rate.
- `RUN_TAG=<tag>` (steps 5, 7-9): writes a separate run.
- `BASE_TAG=<tag>`: makes steps 6-9 read another baseline run.
- `LAMBDA`, `K_FREQ_LEVEL`, `K_SEV_LEVEL`, `MAX_FACTORS` (step 7): sensitivity runs.
- `DT_THREADS=1 OMP_WAIT_POLICY=passive`: use while another heavy fit is running; parallel data.table and xgboost runs
  otherwise slow each other down badly.

Logs:

- every script writes `week_2/run/logs/<script>.log`;
- start and end lines are appended to `week_2/run/status.log`;
- `week_2/run/session_info.txt` holds the session info.

Each step's inputs and outputs with MD5 and run time are in `week_2/docs/step_log.md`.

Read in this order:

1. `step_log.md`
2. `what_changed.md`
3. `what_we_carried_over.md`
4. `model_card_week2.md`
5. `uncertainty.md`
6. `decision_register.csv` and `assumptions_week2.xlsx`

## Final model and lessons (26 Oct 2026)

- `docs/final_model_week2.md`: the final model (submission #5, public 0.16612), with a flowchart and every parameter. Rebuild it with `zsh week_2/run/build_final.sh`.
- `docs/what_works_week2.md`: what works, what does not, and what might still work.
- `docs/submission_log_week2.md`: all five submissions, with per-peril local scores.
