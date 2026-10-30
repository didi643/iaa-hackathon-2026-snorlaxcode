# final_week1_R_Script

Rebuilds the final selected Kaggle submission from the raw data, in R:
`submission_20261023_1636_w9_motor2_pre_m0.5.csv` (public 0.12965, private 0.13923).

## Run

```
cd final_week1_R_Script
Rscript run_all.R                    # all stages, about 11 hours; restartable
STAGES=history,ladder Rscript run_all.R   # selected stages; FORCE=1 re-runs finished ones
```

- Needs R 4.6.1 and the parent project's renv library (`.Rprofile` adds it), plus raw data in `../../data/week_1/raw data/` (`RAW_DATA_DIR` overrides).
- Everything is written inside this folder: `data/`, `models/`, `output/`.
- Progress is in `run/status.log`, and each stage's log is in `run/logs/<stage>.log`.

## The model, step by step

| # | Stage | Script | What it builds |
|---|---|---|---|
| 1 | clean | `R/2_clean.R` | Cleaned tables in `data/clean/` |
| 2 | ibnr | `R/3b_ibnr_study.R` | Chain-ladder report shares per peril (used by MOTOR 2) |
| 3 | sam3 | `R/4_models_itersam03.R` | SAM 3: per-peril GLM / LightGBM / XGBoost frequency x severity plus line Tweedie, blended per line |
| 4 | sam4 | `R/4_models_itersam04.R` | SAM 4 (SAM 3 with the step 2 IBNR); only its 2025 motor total is used, to set MOTOR 2's level |
| 5 | c5 | `R/4_models_iterwendy07.R` + `inputs/assumptions_wendy07_final2.xlsx` | WENDY 7 C5: per-peril XGBoost freq x sev or Tweedie, chain-ladder IBNR, 5 bags |
| 6 | motor2 | `R/4_models_itermotor02.R` | MOTOR 2: motor per-peril spline GLMs, with BI pooled with TPP |
| 7 | history | `R/5_history.R` | WENDY 8 credibility inputs per row: N = own earlier reported claims, E = their expected number |
| 8 | ladder | `R/6_ladder.R` | WENDY 9 ladder: LightGBM Poisson frequency x gamma severity for the 8 perils with ladder weight > 0 |
| 9 | blend | `R/9_final_blend.R` | Final file plus a check against the submission |

Final formula, per 2025 row (`R/9_final_blend.R`):

1. Peril blend: `pb = sum_p [w_p x ladder_p + (1 - w_p) x C5_p]`, with w from `inputs/assemble_weights.json`.
2. Line blend: `b = LW x pb + (1 - LW) x SAM 3`, with LW motor 0.9, buildings 0.7, contents 0.9.
3. Motor only: `b = 0.5 x b + 0.5 x MOTOR 2 x sum(b) / sum(MOTOR 2)`.
4. Credibility: `q = b x (A + N) / (A + E)`, rescaled so each line keeps `sum(b)`; A = motor 8, buildings 5, contents 5.

## Exactness

The scripts are the frozen copies used for the submission, with these changes:

- **SAM 3 / SAM 4:** XGBoost tuning stops after the number of configurations the original run tried (`XGB_TUNE_N`) instead of a 900-second time budget, which made the result machine-dependent.
- **WENDY 8 / WENDY 9:** Wendy built these in Python (polars + LightGBM). `R/w89_core.R` ports her code line by line.
  - It reproduces Python's floating-point details: polars divides by a constant as `x * (1/c)`, polars sums are Kahan-compensated, the order of claim rows from polars' join is matched, and the ladder matrix is float32.
  - Checked against her code on 25 Oct 2026: the feature tables are identical; the claim-frequency model behind E matches to 2e-15 with the same early-stopping rounds; N is identical and E matches to 2e-15; ladder frequency and severity for 2025 match the submitted predictions to 1e-14, with the same rounds, trends and caps.
- **`inputs/polars_policy_hash.parquet`:** the only non-R input. It holds the policy folds and the 10% holdout that the Python code drew with polars' string hash, which R cannot compute. It is made by `tools/make_polars_policy_hash.py`.
- **Fixed inputs:**
  - `inputs/assumptions_wendy07_final2.xlsx`: C5 settings.
  - `inputs/motor01_features_used.csv`: MOTOR 1 feature list used by MOTOR 2.
  - `inputs/assemble_*.json`: ladder recipes and blend weights.
  - `inputs/w9_final_details.json`: the submitted ladder run, used as a check.
  - `inputs/target_submission.csv`: the submitted file, used as a check.

`output/final_week1/component_check.csv` compares every rebuilt component with the exact components of the submission (`../docs/handover_final/replicate/inputs/`). `final_check.csv` compares the final file with the submission.

**Result of the full run (25 Oct 2026, about 11 hours on Windows):**

- SAM 3, MOTOR 2, the WENDY 9 ladder and WENDY 8 N/E are identical to the submitted components, to the float32 precision the submission stored (max difference 6e-8; MOTOR 2 byte-identical).
- Only C5 differs: median 1–3% per peril row.
- Final file vs submitted: totals 0.9986 (motor), 0.9999 (buildings), 0.9999 (contents); median row difference 0.5–0.7%; Spearman 0.9999.

**Known limit: C5 (WENDY 7).** The original C5 ran on an Apple M4 Mac. On Windows (x86) it is deterministic, but it can't reproduce the Mac fit:

- Before any model is fitted, the two runs agree to rounding error: claim counts identical, caps equal to 5e-14, trends to 1e-12. The tiny gap comes from R summing in 80-bit precision on x86 but 64-bit on ARM.
- XGBoost's training then diverges: early stopping picks different rounds in 57 of 60 validation fits. ARM fused multiply-adds and Apple's maths library round differently, and boosting amplifies last-bit differences.
- Threads, code, settings and data were all checked and are not the cause.

Running stage `c5` on an Apple Silicon Mac (`STAGES=clean,c5`) is the only way to match it exactly. On Windows, C5 moves the final file by about 0.5% per row (median), with line totals within 0.15%.
