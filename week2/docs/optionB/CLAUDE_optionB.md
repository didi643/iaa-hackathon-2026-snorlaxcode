# Week 2 (emerging market): rules for Claude Code

The full brief is in `week_2/HANDOVER_week2_optionB.md`. Read it first, every session.

- Work **only** inside `week_2/`. Everything else in the repo is read-only, apart from appending to `docs/workflow.md` after asking Wendy.
- **R only** for every run (`Rscript week_2/R/<NN>_<name>.R`, run from the repo root). Every week 2 script sources `week_2/R/00_setup_week2.R`. Never edit the week 1 `R/0_setup.R`.
- To reuse week 1 code, copy it into `week_2/R/` under a new name and note the source file in its header.
- Document every step before starting the next:
  - `week_2/docs/step_log.md`
  - `week_2/docs/decision_register.csv`
  - `week_2/docs/assumptions_week2.xlsx`
  - logs in `week_2/run/`
- Data:
  - developed: `data/week_1/`
  - emerging: `data/week_2/emerging/`
  - week 2 caches and clean data: `week_2/data/` (git-ignored)
- Excluded features:
  - always: `compulsory_excess`, `written_premium`, `customer_service_contacts`, `renewal_decision`, marketing/noise fields;
  - `gender` until Wendy approves.
- Don't install packages, don't submit to Kaggle and don't push to git without asking Wendy.
- Branch: `week2_optionB`. Commit after each step.
- Unclear? Write the question in the step log and ask. Never guess.
