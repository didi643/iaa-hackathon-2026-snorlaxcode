# WENDY 9 handover (23 Oct 2026)

## 1. Status

| Submission | Public D2 | Local D2: 2023 / 2024 / mean (all lines, reported_raw) |
|---|---|---|
| final2 (WENDY 7) | 0.12925 | 0.10619 / 0.09985 / 0.10302 |
| WENDY 8 = final2 + credibility | 0.12945 | +0.00074 vs final2 (mean) |
| **WENDY 9** (current best) | **0.12964** | 0.10682 / 0.10208 / 0.10445 |

**WENDY 9 formula, per line:**
1. Blend each peril: w × ladder + (1 − w) × C5.
2. Sum the perils to a line total, then blend with SAM 3: LW × (peril sum) + (1 − LW) × SAM 3.
3. Multiply by the credibility factor M = (A + N) / (A + E), then rescale so the line total is unchanged.

The weights are in `reference/assemble_weights.json` and at the top of `scripts/w9_blend.py`.

**How to read the scores:**
- Local protocol: fit 2021-22 → score 2023; fit 2021-23 → score 2024. Tweedie D2 (p 1.5) against reported_raw.
- Paired-bootstrap noise is about 0.0011 on all-line D2.
- Public is about 33% of test, with roughly ±0.0013 noise. A local gain below about 0.001 is not reliably visible on public.

## 2. What is in the zip (nothing needs refitting)

| Path | Content |
|---|---|
| `panel/panel_<line>.parquet` | One row per scored row for valid_year 2023 and 2024 (folds) and 2025 (test). See the columns below. |
| `alt_recipes/<line>_<peril>_<year>.parquet` | Fold predictions for the 4 focus perils. Columns: freq_<recipe> and sev_<recipe> (top 3 by peril D2 plus the chosen one), act, exposure. Peril pred = freq × sev. |
| `scripts/w9_blend.py`, `scripts/w9_blend.R` | Rebuild WENDY 9 from the panel only. They print fold D2 by stage and write the submission. Edit W / LW / A, or replace a `lad_<peril>` column, then rerun. |
| `reference/` | Submitted W9 CSV (MD5 733f89991e074ecf6f60954adc9e5a28); assemble_combo/weights JSON; w9_final_details.json; peril_d2.csv; metrics3.csv; burn_by_peril.csv; focus_peril_recipe_ranking.csv; ladder register and model-build workbooks |
| `code/` | Python ladder code (python/wendy09) and the R ports (`4_models_iterwendy08.R`, `4_models_iterwendy09.R`, `wendy_ladder_core.R`). The same files are on Wendy's branch `update_v3`, which was **not pushed yet**. Python paths are hard-coded to the original workspace (`/home/claude/w8`). |

**Panel columns:**
- Identifiers and exposure: `row_id`, `valid_year`, `policy_id`, `exposure`.
- Claim history: `N` (own-policy prior reported claims) and `E` (expected count of those claims).
- `act_<peril>`: reported_raw actual. Null for 2025.
- `c5_<peril>`: WENDY 7 C5 prediction. This uses the method C5 chose for each peril: direct Tweedie for motor BI and contents EoW, freq × sev for the rest.
- `lad_<peril>`: ladder prediction, freq × sev, using the recipe in `assemble_combo.json`. For 2025 it is null where the ladder weight is 0 (motor OD, BI, theft; buildings flood, EoW; contents theft, AD).
- `sam3`: SAM 3 line prediction.
- `final2`: final2 prediction (folds only).
- Predictions are stored as float32.

**Verification:**
- `w9_blend.py` reproduces every stage D2 to 5 decimals: 2023 0.10682 and 2024 0.10208.
- The rebuilt submission matches the submitted file to within float32 rounding (max relative difference 5e-8).
- The R version gives the same D2 and file. It was tested with a CSV stand-in for `arrow`, so it has not been run against the real arrow package.

**If you give a peril with no 2025 ladder prediction a weight above 0:**
- That one peril must be refit on 2021-24. The run times were not recorded.
- Python: `LAD_FINAL=1`, then `run_freq.run(line,[recipe],[peril])` and `run_sev.py line recipe peril`.
- R: `4_models_iterwendy09.R` with STEPS=final. The R LightGBM fit is untested; the R port was checked only against the Python predictions.

## 3. Tried and did NOT work (don't repeat)

**Feature and data tests (WENDY 8, run on top of final2):**
- `customer_service_contacts` is a leakage trap: contacts include claim calls, and the test values look like claim-free rows. Excluded.
- `written_premium` and `discount_applied` gave at most +0.0001 or a negative change.
- Marketing and noise fields were negative in every line: email_domain, branch_id, campaign_code, marketing_segment, vehicle_colour.
- Adding all raw features on top of final2 changed nothing or made it worse.
- Same-year weather anomalies showed no consistent A/E pattern.
- Fraud-repairer flags (RP0733 / RP0901 / RP0417) add nothing after claim counts.
- Cross-line customer or address claim history adds nothing on top of own-policy history.
- Credibility variants were no better than plain count credibility: by peril group, decay-weighted, or severity-based.
- Level and trend changes:
  - Frequency is flat for 2021-24, apart from subsidence and glass_hail.
  - The trends already in final2 are consistent with the data.
  - Test has no lapse effect, so no uplift for that.
- A third independent Python freq × sev GBM as an extra blend member: every weight above 0 lost.

**Ladder steps (WENDY 9) with no gain:**
- Top-K feature pruning (F3k*).
- Seasonality features: row start/end, quarter mix (F9, F10, F12).
- History counts inside the frequency model (F5, F6). On average they are still worse than the credibility multiplier, though F6 is best for buildings EoW; see below.
- Severity trend variants (S1, S5, S6, S7).
- Severity cap at 0.99 or 0.999 instead of 0.995 (S8, S9).
- Rate-encoded severity (SB, SC), apart from some single-peril noise.
- Deeper frequency trees (G1, G9).
- The ladder alone plateaus at 0.099-0.101 (all lines), the same plateau as WENDY 4/7 and SAM 3.

**Overfitting warning:** the per-peril weights are unstable.
- Weights picked on 2023 and scored on 2024: peril blend −0.00014.
- Weights picked on 2024 and scored on 2023: −0.00067.
- Do not tune weights finer than the 0 / 0.25 / 0.5 / 0.75 / 1 grid.

## 4. Focus perils: diagnostics

**Peril D2 alone by fold, and actual/expected ratio (A/E):**

| Peril | Claim rows 2023 / 2024 | C5 D2 2023 / 2024 | Ladder D2 2023 / 2024 | A/E C5 2023 / 2024 | Weight on ladder now |
|---|---|---|---|---|---|
| Motor BI | 2,029 / 1,173 | 0.0588 / 0.0023 | 0.0440 / −0.0106 | 1.06 / 0.51 | 0 |
| Motor TPP | 8,012 / 7,354 | 0.0627 / 0.0523 | 0.0607 / 0.0543 | 1.00 / 0.93 | 1 |
| Buildings fire | 278 / 308 | 0.0156 / 0.0311 | 0.0103 / 0.0397 | 1.00 / 1.09 | 0.25 |
| Buildings EoW | 2,485 / 2,523 | 0.0349 / 0.0468 | 0.0325 / 0.0467 | 1.05 / 0.96 | 0 |

**Line D2 change from moving one peril's weight from C5 toward the ladder (2023 / 2024):**

| Peril | w = 0.25 | w = 0.5 | w = 1 |
|---|---|---|---|
| Motor BI | −0.00053 / −0.00015 | | −0.00466 / −0.00187 |
| Motor TPP | −0.00003 / +0.00037 | | −0.00035 / +0.00128 |
| Buildings fire | −0.00004 / +0.00032 | −0.00029 / +0.00052 | −0.00138 / +0.00059 |
| Buildings EoW | +0.00002 / −0.00014 | | −0.00022 / −0.00080 |

The TPP and fire weights are driven by 2024 only, so treat them as fragile.

## 5. High-priority ideas (untested; my best judgement, verify locally first)

**Motor BI** has the biggest money at stake: about 36% of motor cost, and both models are near 0 D2 on 2024.
1. **Flat severity × frequency GBM.**
   - In `alt_recipes`, flat severity with trend (S1) beats GBM severity (SA) on peril D2: mean 0.0201 vs 0.0167. Rate-encoded SB gives 0.0214.
   - So BI severity features look like noise.
   - Note that C5 BI is a direct Tweedie model, so there is no C5 BI frequency to reuse.
   - Instead, blend C5 with ladder F11 × S1 (or × SB) at w 0.25 and check the line D2. Both are in `alt_recipes`.
2. **Large-loss treatment.**
   - The 2023 fold is dominated by one 11.9m claim.
   - Cap BI severity lower (for example p99) and spread the excess as a flat per-exposure load. Re-score with and without that claim to see how sensitive the result is.
3. **Level.**
   - 2025 BI burn in C5 is about 200 per exposure-year, against 240-245 in 2021-22.
   - BI severity is down 17% from 2023 in open and closed claims alike, so the fall looks real.
   - The 2024 fold A/E of 0.51 is reporting immaturity in the reported_raw target. Local folds cannot settle the level.
   - A BI +10-20% level probe on public is a bet that uses up a submission, not a validated gain.
4. **Borrow strength from TPP frequency.**
   - TPP has about 4-6 times more claim rows than BI, and BI follows at-fault collisions.
   - Use the TPP frequency prediction as an offset or feature for BI frequency.

**Motor TPP** is already near its plateau: recipes span only 0.0574-0.0575.
1. **Keep w = 1 or drop to 0.5.** 0.5 hedges the 2023/2024 disagreement and gives up about 0.0003 on 2024.
2. **Joint collision frequency.** Model OD and TPP frequency together (more claims per leaf) with a peril-share model, then compare with G4.
3. **Severity.** Trend is +5-8% a year. S5, S6 and S2 tie, so there is no gain left in trend variants.

**Buildings fire** is very sparse (about 300 claim rows a year), and the D2 is mostly noise.
1. **Simpler is better.** Single-split stumps (G5) are the best ladder recipe. Try a GLM or GAM with a few property factors, or monotone constraints, rather than more trees.
2. **Pool frequency signal.** Use the all-peril buildings claim propensity, or the history multiplier, as an offset for fire.
3. **Heavy-tailed severity.** Try flat severity with trend plus a large-loss load (as for BI). The severity recipes tie (0.0250-0.0252).
4. **Keep w at or below 0.25.** Higher weights win in 2024 and lose in 2023.

**Buildings EoW**: C5 and the ladder are about equal.
1. **History matters.** F6 (adds history counts including own-peril claims) is the best EoW frequency: 0.0400 vs 0.0396 for G5.
   - Try an EoW-specific credibility multiplier on top of the line multiplier.
   - I am not certain EoW alone was isolated in the WENDY 8 peril-group credibility test.
2. **Blend 50/50 with F6 × SA instead of G5 × SA.** The F6 fold predictions are in `alt_recipes`, so this needs no refit to test. A 2025 refit is needed only if it wins.
3. **Interactions.** Test property age (year_built) × freezing_days. Not tested explicitly.

**Rule of thumb:** only submit a change that is at least +0.001 on the mean of both folds and positive in each fold, with weights on the coarse grid. Anything smaller is invisible on public.
