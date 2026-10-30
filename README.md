# SnorlaxCode: AI-assisted claim pricing across two markets

**IAA AI-Assisted Actuarial Hackathon 2026 (Part 1 + Part 2).** Team SnorlaxCode: Samuel Lim, Wendy Low, Benedict Tan.

We predict the 2025 claim cost (the risk premium) of every policy, for car (motor), house (buildings) and house contents.
- **Week 1:** a developed market with 4 years of data.
- **Week 2:** a new emerging market with only 2 years of data.

| | Final file | Public score | Private score |
|---|---|---|---|
| Week 1 | [week1_submission_20261023_1636_w9_motor2_pre_m0.5.csv](final_files/week1_submission_20261023_1636_w9_motor2_pre_m0.5.csv) | 0.12965 | 0.13923 |
| Week 2 | [week2_submission_20261030_0905_week2_motorlevel_l_full.csv](final_files/week2_submission_20261030_0905_week2_motorlevel_l_full.csv) (submission #31) | 0.16840 | not known yet |

Score: Tweedie D² (power 1.5). Higher is better.

**About Week 2.** We also tried setting the Week 2 levels from public-leaderboard probes. Those files scored higher on the public board (up to 0.17445), but we decided that probing is not something a pricing actuary could do in real life, so it is cheating in spirit. We set it aside and did not use it for our final. Instead we went back to the pre-probing model (#12, public 0.16690) and made one actuarial review of the motor level, using only the training data. The probing scripts and outputs stay in this repo as a record. The full story is in [report/writeup.md](report/writeup.md) and section 2B of [final_submission_writeup_week2.md](week2/docs/final_submission_writeup_week2.md).

**Read first:** [report/writeup.md](report/writeup.md) is the write-up (also as [PDF](report/writeup.pdf)). [report/video_script.md](report/video_script.md) is the video script. For actuaries, [dummy_guide/dummy_guide_for_the_final_models.md](dummy_guide/dummy_guide_for_the_final_models.md) is the technical, peril-by-peril guide to both final models, with every setting, every credibility value and the citations for all the methods used.

---

## Quick guide for judges

Pick the level of checking you want. Each level adds to the one before.

| Level | What it proves | Time | Needs |
|---|---|---|---|
| A. Check the final files | The files in `final_files/` are the exact files we submitted | seconds | R + 2 packages |
| B. Quick rebuild | Our code turns our saved model outputs into the exact same files, byte for byte | about 1 minute | A (no Kaggle data needed) |
| C. Full rebuild | Our code rebuilds everything from the raw Kaggle data | Week 1 about 11 hours, Week 2 several hours | B + all packages |

### Step 1. Install R

1. Install R 4.6.1 from [cran.r-project.org](https://cran.r-project.org). Other 4.x versions should work for levels A and B.
2. Open a terminal **in this folder** (the repo root) and start R there. The first time, `renv` sets itself up; it keeps this project's packages separate from your other R work.
3. For levels A and B you only need two packages. In that R session, run:
   ```r
   install.packages(c("data.table", "arrow"))
   ```
4. For level C, restore the exact package versions we used (from `renv.lock`) in the same R session:
   ```r
   options(pkgType = "binary")   # Windows without Rtools: use ready-built packages
   renv::restore()
   ```

### Step 2. Get the data (level C only)

The competition data is not in this repo (the rules do not allow us to share it). Download it from Kaggle and place it like this:

```
data/
  week_1/raw data/            <- all Part 1 parquet files (policies_*, claims, customers, addresses, weather, test_*, sample_submission)
                                 (the Part 2 "developed" folder has the same files)
  week_2/raw data/emerging/   <- all Part 2 "emerging" parquet files (including sample_submission.parquet)
```

### Step 3 (level A). Check the final files

```
Rscript verify_final_files.R
```

For each file in `final_files/`, this checks:
- the fingerprint (MD5);
- the header;
- the row count;
- that no row is duplicated, negative or missing.

Each line should say `OK`.

### Step 4 (level B). Quick rebuild

```
Rscript verify_final_files.R rebuild
```

This runs:
- **Week 1:** [replicate_final_submission.R](week1/docs/handover_final/replicate/replicate_final_submission.R). It blends the frozen model outputs in `week1/docs/handover_final/replicate/inputs/` using the final weights and credibility step.
- **Week 2:** [30_final_from_components.R](week2/R/30_final_from_components.R). It adds up the two saved model outputs in `data/week_2/optionB/final/` (motor and property) to rebuild the pre-probing model #12, then applies the two motor level factors to get the final file #31.

It stops with an error if any rebuilt file is not identical to the final file.

### Step 5 (level C). Full rebuild of Week 1 (Windows, about 11 hours)

```
cd week1/final_week1_R_Script
python tools/make_polars_policy_hash.py "../../data/week_1/raw data" inputs/polars_policy_hash.parquet
Rscript run_all.R
```

- **The Python line:** part of Week 1 was first built in Python, which split policies into folds with a hash that R cannot compute. This one-off line writes those folds; it needs Python with `polars`. We do not ship the file because it lists every competition policy id.
- **Progress:** shown in `run/status.log`. The run can be restarted; finished stages are skipped.
- **Output:** the final file goes to `output/submission/submission_final_week1.csv`, and a comparison with the submitted file goes to `output/final_week1/final_check.csv`.
- **Known limit:** one component (C5) was first fitted on an Apple Silicon Mac. On Windows it lands within about 0.5% per row (median), with line totals within 0.15%. The full explanation is in [week1/final_week1_R_Script/README.md](week1/final_week1_R_Script/README.md).

### Step 6 (level C). Full rebuild of Week 2 (PowerShell, several hours)

```
powershell -File week2\run\build_final_motorlevel.ps1 -Full
```

- **Rscript location:** the scripts use `Rscript` from your PATH. If R is somewhere else, first set `$env:RSCRIPT = "C:\path\to\Rscript.exe"`.
- **On macOS or Linux:** use `pwsh` (PowerShell 7) instead of `powershell`.
- **What it runs:** the model components ([build_final_halfway.ps1](week2/run/build_final_halfway.ps1) `-Full`; its last step also writes the set-aside probing file, kept as a record), then the final step 30, then [29_motor_level.R](week2/R/29_motor_level.R), which derives the motor factors and scores them on 2024.
- **Without `-Full`:** it only runs the last step, which is the same as level B.

---

## How the model works (short version)

**Week 1** ([full method](week1/final_week1_R_Script/MODEL_METHODOLOGY.md))
1. Clean the data, for example sums insured 1,000 times too big, duplicate claims and leaky columns. Excess stays as a feature.
2. Add late-reported claims (IBNR) by peril with chain-ladder.
3. For each peril, model how often claims happen (frequency) × how much each claim costs (severity), using XGBoost, LightGBM and GLMs. Results are averaged over several runs with different random seeds.
4. Blend the models by line, add a motor-only spline GLM, then apply credibility on each policy's own claim history.

**Week 2** ([full method](week2/docs/final_model_method_week2.md))
1. Re-use the Week 1 engine for the **shape** only, meaning who is riskier than whom. It is re-tuned on the fields the new market has.
2. Learn the new market's **level** from its own 2023-24 data, after late claims and trend. Mix the two with Bühlmann credibility, peril by peril.
3. Add the new market's own fields, for example gender, which is allowed in this market.
4. Review the motor level actuarially, using only the training data (no leaderboard probing). Two factors on motor rows only: bodily-injury severity × 1.116 (claims inflation from the mature 2021-23 years, development and large-loss loads) and new-business policies × 1.061 (their full actual-to-expected in the emerging data). Motor total × 1.094; buildings and contents unchanged. See section 8A of the method.

We also tested levels set from public-leaderboard probes and set them aside (see section 9 of the method and the note above).

---

## Folder map

```
final_files/                  the prediction files we submitted (Week 1 final, Week 2 final #31, Week 2 fallback #12)
report/                       write-up (markdown and PDF) and video script
dummy_guide/                  technical guide to both final models (md + source-map workbook), with all citations;
                              sources/ holds copies of the generated outputs it cites
verify_final_files.R          level A and B checks (see above)
kaggle/                       Kaggle R notebook that rebuilds both final files from the saved model outputs (see its README)

week1/
  final_week1_R_Script/       FULL REBUILD of the Week 1 final file (run_all.R, README, MODEL_METHODOLOGY)
  docs/handover_final/        QUICK REBUILD of Week 1 (replicate/), takeaways
  docs/workflow.md            Week 1 diary: every step, decision and submission
  docs/*.xlsx                 assumptions workbooks, iteration summary, model variations register
  R/                          all Week 1 development scripts (one script per model iteration, never overwritten)
  models/*/model_card.md      a model card for every iteration
  tests/                      unit tests and local validation checks
  handover/                   the original Python code of WENDY 9 (later ported line by line to R)

week2/
  R/                          all Week 2 scripts, numbered in run order (01 profile ... 24 office premium, 29 motor level, 30 final from components;
                              25-27 are the probing scripts, set aside and kept as a record)
  run/build_final_motorlevel.ps1  FULL and QUICK REBUILD of the Week 2 final file
  run/build_final_halfway.ps1 model components (called by the full rebuild) and the set-aside probing file
  week1_retune/               the Week 1 engine re-tuned for the new market (buildings and contents)
  docs/final_model_method_week2.md   full Week 2 method, flowchart, motor level review (8A), probing set aside (9)
  docs/final_submission_writeup_week2.md   Week 2 final submission write-up, why probing was set aside (2B)
  docs/week2_workflow.md      Week 2 diary: submission log #1-33 and the method for each
  docs/workflow_w2.md         Week 2 run log
  docs/optionB/               decision register, experiment log, uncertainty, what changed, what we carried over
  output/29_motor_level/      motor level factors, 2024 back-test, burn by peril
  output/25_level/            probing record: probe registry and level tables (set aside)
  output/office_premium_reference_policies.csv   office premium for the 20 reference policies

data/week_2/optionB/final/    our two saved Week 2 model outputs (motor 7 columns, property 5 columns) for the quick rebuild
CLAUDE.md, .claude/skills/    the standing instructions and skills we gave our AI assistant
```

## Where to look for each judging area

| Area | Where |
|---|---|
| Pricing and adaptation | [writeup](report/writeup.md) Parts 2-4; [technical guide with citations](dummy_guide/dummy_guide_for_the_final_models.md); [Week 1 method](week1/final_week1_R_Script/MODEL_METHODOLOGY.md); [Week 2 method](week2/docs/final_model_method_week2.md); [what changed](week2/docs/optionB/what_changed.md); [what we carried over](week2/docs/optionB/what_we_carried_over.md); [uncertainty](week2/docs/optionB/uncertainty.md); data cleaning: [Week 2](week2/docs/cleaning_decisions_w2.md), [Week 1](week1/docs/workflow.md) |
| Use of AI | [writeup](report/writeup.md) Part 5; [CLAUDE.md](CLAUDE.md) and [.claude/skills/](.claude/skills/) (standing instructions); [AI hand-off brief](week1/docs/HANDOFF_claude_code.md); [Week 1 experiment log](week1/docs/wendy07_experiment_log.md) |
| Validation and guardrails | [writeup](report/writeup.md) Parts 6-7; [Week 2 motor level review, section 8A, and why probing was set aside, section 9](week2/docs/final_model_method_week2.md); [tests](week1/tests/); [decision register](week2/docs/optionB/decision_register.csv); `verify_final_files.R` |
| Documentation and version control | this README; the two diaries [week1/docs/workflow.md](week1/docs/workflow.md) and [week2/docs/week2_workflow.md](week2/docs/week2_workflow.md) |

## Tests and checks in the code

- **Unit tests:** `week1/tests/test_model_io_*.R` test the model save, reload and blend helpers. Run them from the repo root, for example `Rscript week1/tests/test_model_io_ensemble.R`.
- **Local validation:** `week1/tests/4_check_reported_*.R` score a model on 2023 and 2024 actual claims, then compare two models with a policy-level bootstrap. A change is only submitted if its gain is bigger than about 2 standard errors.
- **Built-in stops:** the scripts stop with an error if row counts, row ids, totals or the office-premium reconciliation do not match, or if any prediction is negative or missing.
- **Read-only data checks:** `week2/R/1_checks_w2.R` checks keys, joins, dates, impossible values and categories never seen in training.
- **Fingerprints:** every Week 2 submission is written with an `.md5` file next to it.

## About this repository

- **A clean copy of our working repo.** Our working repo sits on a company server that cannot be shared outside, so this public copy holds the code, documents and small inputs only. It has no data, no fitted models and no bulk outputs. The full development record is in the two diaries and the registers above: every iteration, decision and submission, with dates.
- **Data:** the competition data is not included. The only data-like files are our own model outputs needed for the quick rebuild.
- **Licence:** [MIT](LICENSE).

## Troubleshooting

- **`Rscript` not found:** use the full path, for example `"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" verify_final_files.R`.
- **MD5 check fails after cloning:** git may have changed the line endings. Run `git config core.autocrlf false`, delete the folder, and clone again. `.gitattributes` should already prevent this.
- **Missing package:** run `install.packages("<name>")`, or `renv::restore()` for everything.
