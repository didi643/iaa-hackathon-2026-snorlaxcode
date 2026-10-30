# IAA Hackathon 2026 - project memory for Claude Code

Start every session by reading `week1/docs/HANDOFF_claude_code.md` (status, rules, local validation protocol, experiment
backlog A/B/C, starter prompt), then `week1/docs/workflow.md` (method notes + submission log).

Key rules (details in the handoff):
- Layout: week 1 lives in `week1/` (R, models, output, docs, tests, handover, final_week1_R_Script) with data in
  `data/week_1/{raw data,clean,sam0N,...}`; week 2 lives in `week2/` with data in `data/week_2/`. `notes/` is personal.
- R first (data.table, arrow, xgboost); run scripts from this folder; every script sources `week1/R/0_setup.R`.
- Raw data is in `data/week_1/raw data/`. Run `week1/R/2_clean.R` then `week1/R/3_incidence.R` before ITER 1 - WENDY 6 scripts.
- Earlier `week1/R/4_models_*.R` scripts are frozen: copy to a new numbered script, never overwrite another
  iteration's `week1/models/<iteration>/` folder or data cache (`data/week_1/sam02`, `data/week_1/sam03`).
- Excess (`voluntary_excess`) is a feature in every model; drop `compulsory_excess`, `noise_probe`,
  `written_premium`, `customer_service_contacts`, `renewal_decision`.
- Judge changes locally first (mean 2023-24 D2 on reported actuals + bootstrap, `week1/R/4_check_reported_*.R`);
  never submit to Kaggle without asking Wendy (public submissions are limited).
- Record every run in `week1/docs/workflow.md` and the workbooks `week1/docs/iteration_summary.xlsx`,
  `week1/docs/model_variations_register.xlsx`.
