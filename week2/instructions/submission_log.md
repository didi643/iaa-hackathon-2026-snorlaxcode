# Instruction: recording a week 2 submission

Use this every time a week 2 file is created for Kaggle, and again when Wendy reports its public score.
Week 2 = "The New Market" (emerging-market 2025 test files, 209,063 rows). Week 1 records stay in `week1/docs/workflow.md`
and must not be mixed with week 2.

Callable as a skill: `/week2-submission-log` (wrapper in `.claude/skills/week2-submission-log/SKILL.md`).

## Rules

1. **Never submit to Kaggle yourself.** Write the file locally, then ask Wendy; she submits and reports the public score.
   Public submissions are limited.
2. **Validate locally first.** Every submitted model must have a scorecard (see
   [output_model_instruction.md](output_model_instruction.md)) before it is offered for submission.
3. **One file = one entry.** Never overwrite an earlier submission file. File names follow
   `week2/output/submission/submission_w2_<tag>_<YYYYMMDD_HHMM>.csv`.
4. Record the entry when the file is written ("public score: pending"), then fill in the score when Wendy reports it.

## Where to record (all four places)

| # | Place | What to write |
|---|---|---|
| 1 | `week2/docs/week2_workflow.md` - **Submission log** table | One row: `#`, date, file path, validation D2 (ALL cost, developed basis), public score (bold), one-line notes (model name, change vs previous public score) |
| 2 | `week2/docs/week2_workflow.md` - **Submission N** section | Method: scripts in run order with env settings (e.g. `W2_CFG`, `W2_FOLDS`), what each model component does, blend weights, credibility / level settings, 2025 burn by line, what was tested and rejected |
| 3 | `week2/docs/week2_workflow.md` - **Model scorecards** section | The scorecard tables for the submitted model, from `week2/output/scores/scorecards.md` (see the output instruction) |
| 4 | `week2/docs/workflow_w2.md` (run log) | One row when the file is written (date, step, script, result, file path) and one row when the public score arrives ("Kaggle submission N (Wendy): public X") |

Validation output files stay where the scripts write them (`week2/output/<step>/`); link them, don't copy them.

## What every submission entry must include

- **File:** full relative path of the csv, and the scripts that produced it, in run order
- **Data:** training years per market (emerging 2023-24, developed 2021-24), any data excluded
- **Method:**
  - model type per peril (frequency and severity)
  - features (and any excluded)
  - how the emerging level is set
  - credibility settings
  - trend
  - large-claim cap and loading
  - blend weights
- **Validation:** cost D2 ALL and by line (developed and reported basis), plus a pointer to the full scorecard
  (frequency / severity / cost by peril and line)
- **Uncertainty:** paired policy bootstrap of the gain vs the previous submitted model (gain +/- SE, share of draws better)
- **2025 checks:**
  - row count 209,063
  - no NA or negative predictions
  - burn per unit of exposure by line (new business / renewal) vs history
- **Public score** (when known), and the change vs the previous public score
- **Decision notes:** why this model was chosen, what was tested and not used

## Template (copy into week2_workflow.md)

```markdown
| N | YYYY-MM-DD | `week2/output/submission/submission_w2_<tag>_<run>.csv` | 0.xxxx | **pending** | <model>; <change> |

## Submission N - <short name>, public <score or pending>

Scripts: `week2/R/<a>.R` -> `week2/R/<b>.R` (settings: ...).

- Model: ...
- Validation: ALL D2 0.xxxx vs 0.xxxx for submission N-1 (bootstrap gain +0.xxxx +/- 0.xxxx, better in xx% of draws)
- 2025 burn per unit of exposure: motor ..., buildings ..., contents ...
- Tested but not used: ...
```
