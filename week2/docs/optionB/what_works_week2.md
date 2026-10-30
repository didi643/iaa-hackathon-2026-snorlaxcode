# Week 2: what works and what does not (emerging market, Option B)

Written 26 Oct 2026 after five public submissions (best 0.16612, submission #5). The final model and all its parameters are in `final_model_week2.md`.

- **Detail:**
  - `improvement_round_week2.md`: every experiment with its numbers;
  - `experiment_log.csv`: one row per gate comparison;
  - `submission_log_week2.md`: per-peril scores for each submission.
- **How we judged changes:**
  - Fit emerging 2023, score 2024.
  - Metric: Tweedie D2 (p 1.5) against the constant mean, on developed actuals.
  - Two views: rows as-is, and rows reweighted to the 2025 new-business x channel mix (the public-board proxy).
  - Paired policy bootstrap, 200 draws.
  - **Adopt** only if the gain is above 2 bootstrap SE on one view and negative on neither.
  - Bad changes were reverted.

## 1. The big picture

1. **The score is mostly frequency plus getting each peril's level right.**
   - Severity barely ranks emerging claims: claim-level severity D2 is between -0.05 and +0.03 for 12 of the 15 perils, under any model.
   - So severity-shape ideas can move the total by about +-0.001.
   - A level error of a few percent on a large peril moves it more.
2. **One year of emerging data is the hard limit.**
   - The 2024 fold has about 4k claims.
   - The 90% interval of the local D2 is about 0.03 wide.
   - The ceiling simulation (model taken as the truth) is close to what we achieve.
   - Most real improvements were +0.0005 to +0.002.
3. **Public vs local.**
   - The public board uses 33% of the 2025 test rows.
   - On our 2024 fold, a random 33% split moves a model difference by about +-0.0008 (1 SD).
   - So treat public differences under about 0.0015 as noise, unless they point the same way as local.
   - The exception is a level change: #3 showed a public drop that had a 0.2% chance under 2024-type noise.

## 2. What works (kept in the final model)

| Idea | Evidence | Gain |
|---|---|---|
| **Option B structure:** developed relativities (WENDY 7 C5 per-peril XGBoost, shared fields only) x emerging levels | Beats the emerging-only GLM benchmark E by 0.05 D2 and the raw developed model D by 0.025 | Foundation |
| **Level credibility** toward the line's pooled level (K 200 freq / 400 sev, x3 sparse heavy perils) | Without it, peril levels fitted on one year over-predicted 2024 by 20% | Largest single fix |
| **Claim-weighted severity prior** (not cost-weighted) | A cost-weighted prior let buildings fire set every buildings severity | Fix (D025) |
| **Gender + self_employed** as emerging factors (X1) | Gender is the first factor picked for motor own damage, TPP and BI | +0.0020 as-is |
| **5 xgboost bags** in the baseline (X8) | Lower variance, all lines up | +0.0010 as-is |
| **Credibility constants:** K 200/400 + ridge lambda 30 (X10) | | +0.0013 as-is |
| Public jump #1 -> #2 (X1 + X8 + X10) | 0.15604 -> 0.16562 | **+0.0096 public** |
| **Developed severity shape x one emerging level per peril** | Every emerging-only severity model lost for property (X4a, X11) | Kept as the default |
| **Emerging severity shape on the 4 data-rich perils** (motor own damage, glass, BI; contents EoW): 50/50 blend, picked by a 5-fold claim CV, relevelled so levels do not move (X14e) | Local +0.0006 on both views (better in 89% / 99% of draws); public 0.16557 vs 0.16562 (tie, a 22% chance under noise) | Small, CV-backed |
| **Motor frequency trend floored at 0** (X18b; own damage was -5%/yr, TPP -3.4%/yr) | Locally neutral; public 0.16557 -> **0.16612** | +0.0006 public |

## 3. What does not work (tested and reverted)

### Structure

| Idea | Result | Why it fails |
|---|---|---|
| **Frequency from developed data only** (no emerging level) (X11a) | -0.006 as-is (motor -0.013) | Emerging claim rates differ from developed by peril (motor glass +31%, contents AD -18%) |
| **Pooled baseline:** developed + emerging rows with a market flag (X7) | -0.009 | Trees chase the heavy 2023 buildings year |
| **Boosted residual** on emerging frequency (X5) | Noise | No residual structure the trees can find |
| **Motor location** fields in the baseline (X6) | Noise; developed validation worse | |
| **2025-mix fit weights** (X2) | -0.0056 | Amplifies noise from the few 2023-24 NB claims |
| Developed-only frequency + emerging-only severity, all combinations (X11b, c, g) | -0.014 to -0.018 as-is | Both halves lose |

### Severity

| Idea | Result | Why |
|---|---|---|
| **Emerging-only severity** on every peril: fixed factors, greedy factors, flat mean, rich perils only (X4a, X11d-h) | -0.009 to -0.013 as-is; buildings -0.03 every time | 20-250 claims per property peril per year cannot learn a shape; 2023 fire dominates |
| Range multiplier on severity, banded (X4b) or smooth power (X4c, beta 0.85-1.0) | 0 to -0.001 | Emerging is a level shift, not a different shape |
| **All motor perils** severity blended (X13b, submitted as #3) | Local +0.0006, **public -0.0013** | It also moved motor levels (BI -7%, theft +11%). Level moves are what the metric punishes. |
| Emerging severity on CV-clear perils only, motor OD + glass (X14a, X14f) | 0 | Too small to matter |
| Flat TPP severity (no severity signal in CV) (X17) | 0 | TPP severity carries no signal either way |

### Credibility and levels

| Idea | Result |
|---|---|
| K halved (X9a) | -0.001 |
| Lighter K for rich perils (X3) | 0 |
| Ridge lambda 300 (X9d) | -0.001 |
| Buildings EoW severity level K 100 / 25 (X16), although the in-sample A/E is 0.88 both years | 0 |

### Frequency relativities

| Idea | Result |
|---|---|
| Frequency range multiplier: level x developed frequency^beta (X15), all perils, greedy, TPP only | -0.0004 to -0.0007 as-is. Beta 0.83-1.21 (TPP 0.94): developed relativities transfer almost 1:1. |

## 4. What might still work (untested or unresolved)

1. **2025 levels per peril.**
   - Evidence: #3 (motor lower: worse) and #5 (motor higher: better).
   - The public board is sensitive to motor's 2025 level, and our trend and level assumptions are the remaining lever.
   - The 2024 fold cannot judge them.
   - Candidates:
     - motor bodily injury trend (0 now; developed -8.8%/yr, emerging +4.9%);
     - the motor NB load (1.166 on 697 claims);
     - buildings EoW (12% high in-sample in both years).
   - **Risk:** tuning levels to the public 33% can overfit it. A level move needs an actuarial reason, not just a public score.
2. **Reverse fold** (fit 2024, score 2023) to get a second local check of the per-peril choices. The 2023 buildings year is extreme, so read it with care.
3. **Dropped developed fields** (region, mileage, credit, telematics). They cost about 0.005 of developed D2 (0.0976 vs 0.1026). Proxies built from the shared fields have not been tried.
4. **TPP** is the peril furthest below its simulated ceiling (0.087 vs 0.105, `output/17_headroom/`). Frequency compression and flat severity did not help, so the gap is probably one-year noise. It remains the place to look first.

## 5. Practical lessons

- **Judge on the 2025-mix proxy and as-is together.** A change that wins on only one view was usually noise.
- **Separate shape from level in every severity test.** Relevel to the reference totals first: that is what made X14e safe after #3.
- **Keep a reproducible run tag per experiment.**
  - `run/run_exp.sh <tag> ENV=VAL` covers steps 7, 8, 9 and the gate.
  - `R/14_blend_severity.R` blends two runs.
  - `R/15_candidate_from_tag.R` builds a file without touching main.
  - `run/build_final.sh` rebuilds #5.
- **Freeze each submission's run** (`data/adjust/subN`, `output/09_validate/subN`) before rebuilding main, so the submission log keeps its numbers.
- **Machine:** run parallel jobs with `DT_THREADS=1 OMP_WAIT_POLICY=passive`, and never edit a script while it is running.
