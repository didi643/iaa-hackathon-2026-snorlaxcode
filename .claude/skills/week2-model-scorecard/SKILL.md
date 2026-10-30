---
name: week2-model-scorecard
description: 'Produce and record the standard week 2 model scorecard: local validation D2 for the frequency model, the severity model and the combined cost, by peril, by line of business and ALL. Use after fitting or changing any week 2 (New Market) model, before offering a submission, or when asked to score, compare or record model results.'
argument-hint: 'Model tag and the script that produced its validation predictions'
---

# Week 2 model scorecard

Follow the full instruction in
[week2/instructions/output_model_instruction.md](../../../week2/instructions/output_model_instruction.md). It is the
single source of truth.

## Procedure

1. Read `week2/instructions/output_model_instruction.md`.
2. Build validation predictions (fit 2023, score emerging 2024) with frequency and severity kept **separately**:
   `row_id, line, peril, exposure, freq, sev` (+ `cost` for blends).
3. In R:

   ```r
   source("week2/R/0_setup_w2.R"); source("week2/R/score_w2.R")
   sc <- score_model_w2(pred, "TAG", "description", "script")
   record_scores_w2(sc)
   cat(scorecard_md_w2(sc), sep = "\n")
   ```

   See `week2/R/7_score_models_w2.R` for a worked example.
4. Record the results:
   - add the comparison row (and, for submitted models, the full scorecard) to `week2/docs/week2_workflow.md`
     under **Model scorecards**;
   - add a run-log row to `week2/docs/workflow_w2.md`.
