# Instruction: what every week 2 model must output

Every week 2 candidate model (submitted or not) must produce the **standard local scorecard**: validation D2
**separately for the frequency model and the severity model, and for the combined cost**, each at **peril**,
**line of business** and **ALL** level. The scorecard is recorded so that all models can be compared like for like.

Callable as a skill: `/week2-model-scorecard` (wrapper in `.claude/skills/week2-model-scorecard/SKILL.md`).

## Validation fold (fixed for every model)

- **Fit:** emerging 2023 (+ developed 2021-23 if the model uses Part 1 data).
- **Score:** emerging 2024 (25,603 motor / 14,867 buildings / 18,732 contents rows).
- **Actuals** are developed to ultimate with the step 3 reporting shares: actual = reported / reported share.

## The three components

| Component | Metric | Actual | Predicted | Null model |
|---|---|---|---|---|
| frequency | Poisson deviance D2 | ultimate claim count per row | expected ultimate claims (rate x exposure) | cell's claims per exposure x exposure |
| severity | Gamma deviance D2 | net cost of each 2024 claim (uncapped, `counts` and > 0) | the row's expected severity for that peril, including the large-claim loading | cell's mean claim cost |
| cost | Tweedie (p = 1.5) D2, the competition metric | ultimate cost per row (`d2_rep`: reported cost vs prediction x share) | expected cost | cell's cost per exposure x exposure |

D2 = 1 - deviance(model) / deviance(null). A/E = actual / predicted is reported in every cell as well.

## Levels

- **peril**: each line x peril (15 cells).
- **line**: motor, buildings, contents. For frequency and cost, perils are summed per row; for severity, the line's
  claims are pooled.
- **ALL**: all rows of all lines (frequency, cost) or all claims (severity). Cost ALL is the headline number.

Reading note: line and ALL severity D2 are high mostly because they pool perils with very different claim sizes, and
the single-mean null cannot separate them. Judge severity by the **peril** rows. Blends are not frequency x severity
models: their frequency = blended frequency, cost = blended cost, severity = cost / frequency (implied).

## How to produce it (in R)

```r
source("week2/R/0_setup_w2.R")
source("week2/R/score_w2.R")
# one row per emerging 2024 row x peril, on the validation fold:
pred <- data.table(row_id, line, peril, exposure,
                   freq = expected_ultimate_claims,   # per row (rate x exposure)
                   sev  = expected_cost_per_claim)    # incl. large-claim loading; add `cost` for blends
sc <- score_model_w2(pred, model = "MODEL_TAG", desc = "one-line method", script = "week2/R/<script>.R")
record_scores_w2(sc)                       # appends / replaces in week2/output/scores/model_scores.csv
cat(scorecard_md_w2(sc), sep = "\n")       # markdown tables for week2_workflow.md
```

Every modelling script should therefore **save frequency and severity predictions separately**, not only their product
(e.g. `5b_joint_w2.R` saves `<model>`, `<model>_f`, `<model>_s`). Worked example covering five models:
`week2/R/7_score_models_w2.R` (writes `week2/output/scores/scorecards.md`).

## Where to record

1. `week2/output/scores/model_scores.csv`: every scored model in long format (written by `record_scores_w2`). This
   is the master file for comparing models.
2. `week2/docs/week2_workflow.md`, section **Model scorecards**:
   - add the model's row to the comparison table (frequency / severity / cost D2 for ALL and each line);
   - for models that are submitted, also add the full scorecard (line table, A/E table, peril table).
3. `week2/docs/workflow_w2.md` (run log): one row per run, with the headline cost ALL D2 and the scorecard location.

## Checklist before calling a model done

- [ ] Frequency and severity predictions saved separately
- [ ] `score_model_w2` run on the validation fold (fails loudly if any 2024 row x peril is missing)
- [ ] `record_scores_w2` called (model tag is unique; reusing a tag replaces that model's rows)
- [ ] Comparison row added to `week2_workflow.md`; full scorecard too if submitted
- [ ] Run log row in `workflow_w2.md`
