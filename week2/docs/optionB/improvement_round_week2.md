# Week 2 improvement round (25 Oct 2026, after submission #1 scored 0.15604 public)

Wendy's brief:
- gender may be used;
- reference_policies is only the 20 policies for the office premium build-up;
- try every idea, keep what improves the score and revert what does not;
- test severity as emerging-only vs a range multiplier;
- aim for 0.20 public.

## Gate

- **One public-board proxy**, `week_2/R/13_compare_runs.R`: Tweedie D2 (p 1.5) against the constant mean, developed
  actuals, emerging 2024 rows reweighted to the 2025 new-business x channel mix.
  - Submission #1 scored 0.1500 locally and 0.15604 public, so the proxy tracks the board.
  - The as-is (unweighted) 2024 score is the second check.
- **Paired policy bootstrap**, 200 draws.
- **Rule:**
  - *adopt* when the gain is above 2 SE on at least one view and below zero on neither;
  - *revert* when worse;
  - *within noise* otherwise. Such a change is not kept unless it is free (no extra complexity).
- The full row log is `week_2/docs/experiment_log.csv`.
- Every run is reproducible with `week_2/run/run_exp.sh <tag> <ENV=VAL...>`.

## Results (gate vs the current best at the time)

| # | Experiment | 2025-mix diff (2 SE) | As-is diff (2 SE) | Decision | Why |
|---|---|---|---|---|---|
| X1 | gender + self_employed offered as emerging factors | +0.0004 (0.0029) | **+0.0020** (0.0020) | **adopted** | Gender is the first factor chosen for motor own damage, TPP and BI. Approved by Wendy. |
| X2 | Fit weights = 2025 new-business x channel mix | -0.0056 | -0.0034 | reverted | NB-heavy weights amplify noise from the few 2023-24 NB claims. |
| X3 | Lighter level credibility (K 30/60) for perils with >= 1,000 claims | 0.0000 | 0.0000 | reverted | No effect: these perils already dominate their prior. |
| X4a | **Severity: emerging-only Gamma GLM** (own factors, no developed shape) | -0.0084 | **-0.0129** | reverted | Worse everywhere (buildings -0.037 as-is). Too few emerging claims to learn a severity shape. |
| X4b | **Severity: range multiplier** (emerging level by quintile of developed severity) | -0.0013 | -0.0007 | reverted | Bands add noise. |
| X4c | **Severity: smooth range multiplier**, level x developed severity^beta | +0.0000 | -0.0001 | reverted | beta 0.85-1.0 (slight compression of the emerging range), no score effect. |
| X5 | Shallow xgboost on the emerging frequency residual | +0.0003 | -0.0002 | reverted | No residual structure the trees can find. |
| X6 | Motor location in the baseline (urban_density + address weather averages for every motor peril) | +0.0012 (0.0012) | -0.0000 | reverted | Developed validation also worse (motor 0.0347 vs 0.0355). |
| X7 | Pooled baseline (developed + emerging rows, market flag + gender) | -0.0099 | -0.0089 | reverted | Trees chase the heavy 2023 buildings year (buildings -0.037). |
| X8 | 5 xgboost bags in the baseline (as week 1 C5) | +0.0009 (0.0015) | **+0.0010** (0.0009) | **adopted** | Lower variance, all lines up. |
| X9a | Level credibility K halved (50 / 100) | -0.0010 | -0.0012 | reverted | |
| X9b | Level credibility K doubled (200 / 400) | +0.0001 | **+0.0005** (0.0004) | adopted, in X10 | |
| X9c | Factor ridge lambda 30 (was 100) | +0.0003 | **+0.0008** (0.0007) | adopted, in X10 | |
| X9d | Factor ridge lambda 300 | -0.0011 | -0.0012 | reverted | |
| X10 | X9b + X9c together | +0.0003 (0.0019) | **+0.0013** (0.0011) | **adopted** | |

**Cumulative effect (X1 + X8 + X10) against submission #1:** 2025-mix proxy 0.14996 -> 0.15160 (+0.0016);
as-is 0.14551 -> 0.14975 (+0.0042). The expected public gain is of the same order, about 0.157-0.158, not 0.20.

## Answer to the severity question

The emerging market's claims are 20-45% cheaper, but this is a **level shift, not a different shape**:

- Modelling emerging severity on its own (X4a) is clearly worse. 2-3k claims per data-rich peril and fewer than 100 for
  fire, flood and subsidence cannot beat a shape learned from 160k developed claims.
- A multiplier that varies with the developed severity, either banded (X4b) or smooth (X4c), finds only a slight
  compression: beta 0.85-1.0, meaning the most expensive developed risks are relatively a little cheaper in emerging.
  It does not change the score.
- **Kept: developed severity shape x one credibility-weighted emerging level per peril.**

## Why 0.20 public is out of reach with this data

- The proxy is now 0.1516, against 0.1500 for the 0.15604 submission. Every idea in the plan has been tried; the
  largest single gain was +0.002.
- The ceiling simulation in step 9 (taking the model as the true risk and simulating claims with the emerging severity
  spread) puts a perfect model at about 0.149 as-is. We are at 0.150 as-is: the remaining error is claim-level noise.
- Week 1 showed the same pattern: real gains of +0.0003 to +0.0011 per change against a ceiling near the achieved score.
- Reaching 0.20 would need information the files do not hold. It is not a modelling choice.

## Public result (26 Oct 2026)

Submission #2 (`submission_20261025_2240_week2_optionB_mactest.csv`, X1 + X8 + X10) scored **0.16562 public**, up
+0.0096 from 0.15604. Locally the same change gained +0.0016 (2025-mix proxy) and +0.0042 (as-is). The direction
agrees and the public gain is larger than the local one, which is within the noise of a single public split (the
local 90% interval is about 0.03 wide). Every peril's cost D2 rose except contents escape of water (flat); the largest
gains were buildings fire, subsidence and accidental damage, where gender and the stronger level credibility moved the
fire A/E from 0.78 to 0.96. Per-peril numbers are in `submission_log_week2.md`.

## X11-X13: developed-only frequency, emerging-only severity (Wendy's idea, 26 Oct 2026)

Question: model frequency on developed data only and severity on emerging data only? Gate vs main (submission #2,
public 0.16562). z = diff / bootstrap SE; "better in" = share of 200 bootstrap draws where the challenger wins.

| # | Frequency | Severity | 2025-mix diff | As-is diff (z) | Decision |
|---|---|---|---|---|---|
| X11a | developed only (no emerging level) | main | -0.0022 | **-0.0062** (-2.5) | reverted |
| X11b | developed only | one emerging mean per peril | -0.0091 | -0.0184 (-4.9) | reverted |
| X11c | developed only | emerging GLM, greedy factors | -0.0045 | -0.0151 (-4.4) | reverted |
| X11g | developed x emerging level | emerging GLM, greedy factors | -0.0063 | -0.0142 (-4.5) | reverted |
| X11d | main | one emerging mean per peril | -0.0079 | -0.0130 (-4.3) | reverted |
| X11e | main | emerging GLM, greedy factors (all lines) | -0.0033 | -0.0093 (-3.3) | reverted; motor +0.0013, buildings -0.031 |
| X11f | main | emerging GLM for >= 1,000-claim perils, flat others | -0.0063 | -0.0120 (-4.0) | reverted |
| X11h | main | emerging GLM, fixed factors (X4a re-run) | -0.0069 | -0.0104 (-3.9) | reverted |
| X12a | main | emerging GLM greedy, **motor only** | +0.0009 | +0.0006 (1.2), better in 89% | within noise |
| X12b | main | as X12a, 5 factor steps | +0.0009 | +0.0006 (1.2) | within noise |
| X12c | main | motor, emerging GLM rich perils, flat others | -0.0006 | +0.0002 | reverted |
| X12d | main | motor emerging GLM, ridge 100 | -0.0007 | +0.0000 | reverted |
| X13a | main | **blend** sev_dev^0.75 x sev_em^0.25, motor | +0.0003 | +0.0002 (1.8), better in 95% | within noise |
| X13b | main | blend 50 / 50, motor | +0.0006 | +0.0004 (1.6), better in 93% | within noise (best candidate) |
| X13c | main | blend 25 / 75, motor | +0.0008 | +0.0006 (1.4), better in 92% | within noise |
| X13d / X13e | main | blend 50 / 50 and 75 / 25, all lines | +0.0005 / +0.0007 | -0.0026 / -0.0008 | reverted (buildings) |

Findings:
- **Frequency must use emerging data.** Developed-only frequency loses 0.006 as-is (motor -0.013): emerging claim rates
  differ from developed by peril (e.g. motor theft, contents theft), and only the emerging level corrects that.
- **Emerging-only severity fails for property** (buildings -0.03 in every variant): 20-250 claims a peril a year cannot
  learn a severity shape, and the heavy 2023 buildings year dominates.
- **Motor is the exception.** With 180-1,300 claims a peril a year, the emerging GLM ranks claim sizes better (severity
  D2 up for 4 of 5 perils: own damage 0.016 -> 0.026, BI -0.012 -> 0.023, glass 0.005 -> 0.013). Cost D2: BI +0.005,
  own damage +0.004, TPP +0.001, glass -0.002, theft -0.005.
- Blending the two motor severities is consistently positive (better in 92-95% of bootstrap draws) but stays under the
  2 SE adoption bar (+0.0004 to +0.0008). Main is unchanged. X13b (50 / 50 motor blend) is the one to try on the
  public board if a spare submission is available; expected gain is small (about +0.0005).

Switches added (defaults leave main unchanged): `FREQ_MODE` (adjust / developed / level), `SEV_MODE` em_flat /
em_select / em_rich, `SEV_LINES`, `EM_SEV_STEPS` in step 7; `R/14_blend_severity.R` for the geometric blend.

### X13b candidate file (built 26 Oct 2026 at Wendy's request, not yet submitted)

- `output/submission/submission_20261026_0714_week2_optionB_x13b_mactest.csv`, MD5 `899b0ef3f7313b7f8bedd434168210ff`, built
  by `R/15_candidate_from_tag.R` from run x13b (main x 50 / 50 motor severity blend with x12a_msel). All step 10 checks pass.
- Buildings and contents are identical to submission #2. Motor burn 605 -> 592 (-2.2%): bodily injury -7%, theft +11%,
  own damage / glass / TPP -1%. Row ratio vs #2: p1 0.90, median 1.00, p99 1.08.
- Local expectation: +0.0006 (2025 mix) / +0.0004 (as-is) over #2, under 2 SE. When scored, log it in
  `inputs/submissions_week2.csv` with run tag sub3 (freeze `data/adjust/x13b`, `output/09_validate/x13b`, levels_x13b,
  diagnostics) and rerun step 12.

## After submission #3 (public 0.16432): actuarial review and per-peril pick (26 Oct 2026)

**What #3 told us.** #3 = #2 with every motor peril's severity blended 50/50 with the emerging-only GLM. Locally +0.0006
(2025 mix); public -0.0013 vs #2. Both are within the noise of a one-year fold / one public split, but #3 also moved
motor's 2025 level (-2.2%: BI -7%, theft +11%), and level is what this metric rewards most. Decision: treat the
all-motor blend as not proven; keep #2 as the reference.

**Review of every component (`R/16_peril_review.R`, `output/16_review/peril_review.csv`).**
- *Severity barely ranks emerging claims.* Claim-level severity D2 in 2024 is -0.05 to +0.03 for 12 of 15 perils under
  either model (contents EoW / flood / theft 0.07-0.20 are the exceptions). Cost D2 comes from frequency relativities
  and from each peril's level; severity shape choices move the score by +-0.001 at most.
- *Calibration (final model on its own 2023-24 rows, A/E):* stable perils (motor OD, TPP, glass; buildings storm;
  contents AD, theft) within 0.94-1.05 both years. Buildings EoW 0.88 in both years (severity level credibility pulls
  it 12% high toward the buildings average); motor BI 0.84 / 0.96. Fire (3.12 / 0.97), subsidence (1.23 / 0.59) and
  flood swing by year and need the shrinkage. Lighter level credibility overall (X9a) lost on the fold, so EoW / BI
  are left as known judgement items, not changed.
- Frequency must stay emerging-calibrated (X11a); trend, IBNR, new-business load and large-loss load were reviewed with
  no change indicated by the data.

**Per-peril choice of severity, X14.** A 5-fold policy-level CV of claim-level severity on all 2023-24 emerging claims
(`output/07_adjust/sev_cv_x14_cv.csv`, step 7 with `SEV_CV=1`) compares, per peril, developed shape x level vs the
emerging-only GLM vs a 50/50 blend; "relevelled" variants rescale the emerging shape to the same mean, so they test
shape only. z = gain of the blend in SE:

| Peril | z blend | z blend relevelled | Reading |
|---|---|---|---|
| motor own damage | 2.9 | 2.8 | emerging shape helps |
| motor glass / hail | 2.6 | 2.5 | emerging shape helps |
| motor bodily injury | 1.7 | 1.9 | borderline, shape |
| contents escape of water | 1.8 | 1.8 | borderline, shape |
| buildings subsidence | 1.5 | 1.4 | borderline, 52 claims |
| buildings fire | 2.3 | 1.1 | level effect from the 2023 fire year, not shape: not used |
| motor theft, TPP, buildings storm / flood / EoW / AD, contents theft | -0.9 to 0.9 | | no gain |
| contents flood, contents AD | -1.6, -1.5 | | developed shape better |

Gated on the 2023 -> 2024 fold vs #2:

| # | Severity blended 50/50 on | Level | 2025-mix diff (2 SE) | As-is diff (2 SE) | Verdict |
|---|---|---|---|---|---|
| X14a | motor OD, glass | moves | -0.0001 | +0.0002 | revert |
| X14f | motor OD, glass | #2's | -0.0000 | +0.0002 | revert |
| X14b | + motor BI, contents EoW | moves | +0.0007 (0.0011) | **+0.0005** (0.0005) | adopt (just) |
| X14c | + buildings subsidence | moves | +0.0011 (0.0012) | +0.0003 | within noise |
| X14d | X14a, weight 0.75 | moves | -0.0002 | +0.0002 | revert |
| **X14e** | **motor OD, glass, BI, contents EoW** | **#2's per peril** | **+0.0006** (0.0011) | **+0.0006** (0.0005) | **adopt (just)** |
| X13r | #3 (all motor), relevelled | #2's | +0.0004 | +0.0005 (0.0005) | within noise |

Selection caveat: the CV uses 2023-24 claims, so the 2024 fold is not fully independent of the pick (severity only;
cost and frequency are untouched).

**Candidate #4 (not submitted):** `output/submission/submission_20261026_0724_week2_optionB_x14e_mactest.csv`, MD5
`1396622b27748b75a371fdaba893501b`. Every peril's 2025 total is the same as #2 (total 1.0006); only the motor OD / glass
/ BI and contents EoW severity shape changes (row ratio p1 0.93, median 1.00, p99 1.09). It is a clean public test of
"emerging severity shape for the perils with enough emerging claims": if it scores at or above #2 the shape transfers;
if it drops like #3, keep #2.

## Submission #4 (public 0.16557) and the weakest peril (26 Oct 2026)

**#4 vs #2.** #4 (X14e) scored 0.16557 public vs 0.16562 for #2 (-0.00005); public board 2nd (leader 0.17182).
Locally #4 is +0.0006 on both views (better in 89% / 99% of bootstrap draws). Public / private split simulation on the
2024 fold (500 random 33% / 67% policy splits, 2025-mix weights):

| Difference vs #2 | Mean | SD on a 33% split | SD on a 67% split | P(worse), 67% |
|---|---|---|---|---|
| #3 (all-motor blend, level moved) | +0.0006 | 0.0007 | 0.0003 | 0.03 |
| #4 (X14e, #2's levels) | +0.0006 | 0.0008 | 0.0004 | 0.09 |

- #3's public -0.0013 had a 0.2% chance if 2025 behaved like 2024: the motor level change in #3 (BI -7%, theft +11%)
  was genuinely wrong for 2025. Levels, not shape, decide this metric.
- #4's public -0.00005 had a 22% chance: consistent with noise.
- #4 keeps #2's per-peril levels, so on the private 67% it carries the same level risk as #2 plus a small, CV-backed
  shape gain (+0.0006 +- 0.0004 if 2025 ranks like 2024). Recommended final selection: #4 and #2.

**Weakest peril (`R/17_peril_headroom.R`, `output/17_headroom/peril_headroom_sub4.csv`).** Achieved 2024 cost D2 vs a
per-peril ceiling (model as truth, simulated claims). Below the ceiling: motor TPP 0.087 vs 0.105 (at the ceiling's
5th percentile; 32% of motor burn), buildings EoW 0.049 vs 0.066 (A/E 0.82), buildings AD (1% of burn). Perils above
their "ceiling" (contents EoW / theft / AD, buildings fire / flood, motor theft) have more true spread than the model
predicts; the simulation cannot measure their headroom.

| # | Fix tried | 2025-mix diff | As-is diff | Verdict |
|---|---|---|---|---|
| X15a | frequency range multiplier, level x baseline^beta, all perils (beta 0.83-1.21; TPP 0.94) | +0.0001 | -0.0007 | revert |
| X15b | same, offered to the greedy factor step | +0.0007 | -0.0004 | revert |
| X15c | same, motor TPP only | -0.0002 | -0.0001 | revert |
| X16a / b | buildings EoW severity level credibility K 100 / 25 (was 400) | 0.0000 | +0.0000 | no effect |
| X17a / b | motor TPP severity flat / half-flat (CV showed no severity signal), relevelled | +0.0000 | +0.0000 | no effect |
| X17c | half-flat severity for TPP, buildings AD, contents AD | +0.0001 | +0.0001 | within noise |

Conclusion: TPP's relativities transfer from developed almost 1:1 and its severity carries no signal either way; its
gap sits at the low edge of the ceiling's range (one-year noise). No peril has a fixable weakness that the 2024 fold can
confirm. Main stays #2 + X14e (= #4).

## X18: motor frequency trend floored at 0, on the #4 basis (26 Oct 2026, Wendy's request)

Why: #3 showed that lowering motor's 2025 level hurt on the public board (a 0.2% chance under 2024 noise). Two motor
perils carry a negative chosen frequency trend: own damage -5%/yr (developed -2.8%, emerging 2023->24 -8.9%, capped
at -5%) and TPP -3.4%/yr (developed -2.5%, emerging -4.2%). Switch `TREND_FLOOR_FREQ=motor` in steps 7 and 8.

| # | Floor applied in | Gate vs #4: 2025 mix / as-is | 2025 motor burn (#4 605.7) |
|---|---|---|---|
| X18a | 2024 -> 2025 projection only (step 8) | 0 / 0 (fold unchanged by construction) | 617.8 (+2.0%) |
| X18b | step 7 fit (2023 -> 2024) and step 8 projection | -0.00003 / +0.00009 (2 SE 0.0007 / 0.0004) | 623.7 (+3.0%): own damage 99.4 -> 107.2, TPP 194.9 -> 205.0 |

The 2024 fold cannot tell a 0% motor frequency trend from -3% to -5%: it is a level judgement only the 2025 data can
judge. X18b keeps one consistent assumption in fit and projection.

**Candidate #5 (not submitted):** `output/submission/submission_20261026_0737_week2_optionB_x18b_mactest.csv`, MD5
`6a5011cc9752fc1204c0056f0f4ec985`. Identical to #4 outside motor (contents +0.0%); motor +3.0%; 43% of rows change,
row ratio vs #4 up to 1.04 (p99). Reading the public result: above #4 supports a flat motor frequency for 2025;
below #4 supports keeping the negative trends (#4). Either way it is one public split; the level read is noisy.

## X21: new emerging-only rating fields, one at a time on the x20_tblend chain (27 Oct 2026, Wendy's request)

Why: competitors reach 0.173 public vs our 0.16662 (x20_tblend). Turn-1 review of the 2024 A/E of x20_tblend found
unused signal in fields the pipeline never offered to step 7 (see the review notes in the chat of 27 Oct 2026):
credit tier hidden in `marketing_segment` (suffix affluent / mainstream / budget = developed `credit_band` A-B / C / D-E;
budget A/E motor 1.16, buildings 1.11, contents 1.20), `region` (motor A/E 0.89-1.15), multi-line holding (buildings A/E
1.24 / 0.81 / 0.70 for 1 / 2 / 3 lines), motor value-for-age, property age, and the 12% missing-field rate.

How: `week2/R/03c_emerging_extra2.R` builds the fields (emerging only; developed baseline untouched) into
`data/week_2/optionB/features/emerging_extra2_{train,test}_<line>.parquet`. Step 7 offers them as candidate factors
through `X_NEW` (after the step 6 slope filter; same greedy selection, ridge lambda 30, 2024 deviance gain > 1).
`X_NEW_SEV=0` (added at X21h) keeps them out of the severity selection. Chain = x20_tblend exactly:
`week2/run/run_x21_win.ps1` (07 core -> 14 blend with fin_sevem -> 08 -> 09 -> 13 gate -> 21 scorecard).
`week2/R/21_x21_scorecard.R` writes the standard scorecard (`score_w2.R`) and per-peril deltas to
`week2/output/scores/x21/<tag>_vs_<ref>.csv/.md`.

Acceptance rule (cumulative, one field at a time): keep a step only if BOTH the 2025-mix and the as-is constant-mean D2
proxies of `13_compare_runs.R` improve vs the current best; the reference moves to the accepted run. Reproduction
check X21_0 (no new fields, Windows runner): identical to x20_tblend (diff 0, every per-peril delta 0).
Caveat: factor selection uses the 2024 fold, so gains of ~1 SE are optimistic; none of the steps clears 2 SE.

| # | Fields offered (new in bold) | Ref | 2025 mix diff (SE) | As-is diff (SE) | Picked by step 7 | Decision |
|---|---|---|---|---|---|---|
| X21_0 | none (reproduction) | x20_tblend | 0 | 0 | as x20_tblend | exact |
| X21a | **credit_tier** | x20_tblend | +0.00155 (0.00123), 89% better | +0.00051 (0.00039), 91% | freq: motor TPP, motor theft, contents theft, contents AD | **accept** |
| X21b | credit_tier + **region** | x21a | -0.00161 (0.00108) | -0.00042 (0.00036) | freq: bldg EoW, contents theft (replaces gender), contents EoW; sev: motor glass_hail | reject |
| X21c | credit_tier + **n_lines** | x21a | +0.00067 (0.00052), 89% | +0.00015 (0.00024), 79% | freq: motor BI, motor theft, bldg EoW | **accept** |
| X21d | + **val_age_b** (motor value / (age+1) quartiles) | x21c | -0.00025 (0.00016) | -0.00006 (0.00009) | sev: motor OD only | reject |
| X21e | + **bldg_age_b** (property age bands) | x21c | 0 | 0 | never (best gain +1.95 bldg storm, lost to self_employed) | neutral, not adopted |
| X21f | + **miss_n** (missing-field count 0/1/2/3+) | x21c | -0.00015 (0.00063) | +0.00009 (0.00023) | freq: contents theft / EoW / AD; sev: motor OD | reject (mixed) |
| X21g | + **va_missing** (motor vehicle_age missing) | x21c | -0.00002 (0.00004) | -0.00008 (0.00003) | sev: motor OD, TPP | reject |
| X21h | + miss_n, new fields frequency-only (`X_NEW_SEV=0`) | x21c | -0.00003 (0.00062) | +0.00010 (0.00023) | freq: contents theft / EoW / AD | reject (mixed) |
| X21i | + region, frequency-only | x21c | -0.00134 (0.00106) | -0.00035 (0.00033) | freq: contents theft (replaces gender), contents EoW | reject |
| **X21 final** | **x21c = credit_tier + n_lines** | x20_tblend | **+0.00222 (0.00131), 96.5% better**; motor +0.0009, bldg +0.0017, contents +0.0068 | **+0.00066 (0.00045), 92.5%** | | **new best locally** |

Constant-mean proxies, x20_tblend -> x21c: 2025 mix 0.15322 -> 0.15545; as-is 0.15064 -> 0.15130. Standard scorecard
(week 1 protocol, developed basis) ALL cost D2 0.1189 -> 0.1196, frequency 0.1599 -> 0.1605, severity unchanged 0.3968.

Per-peril findings (frequency / severity / cost):
- credit_tier (kept): frequency up on motor TPP (+0.0010), motor theft (+0.0013), contents theft (+0.0007) and contents
  accidental damage (+0.0020; cost +0.0034). Buildings never picked it (baseline sum insured / property fields already carry
  the wealth signal). No severity effect.
- n_lines (kept): frequency up on motor BI (+0.0011; cost +0.0022), motor theft (+0.0008) and buildings escape of water
  (+0.0014). Multi-line customers are better risks (selection / loyalty), strongest on buildings.
- region: real but small gains (contents EoW freq +0.0016, motor glass_hail severity +0.0069, hail region effect), cancelled
  by contents theft, where region displaces gender and cost D2 falls 0.0056. Rejected with and without severity.
- miss_n: consistent contents frequency gain (+0.0013 to +0.0015 on theft, EoW, AD) on the as-is basis, but not once 2024
  is reweighted to the 2025 new-business x channel mix. Rejected (fails the both-positive rule); first candidate to revisit.
- val_age_b, va_missing: only ever picked for motor severity (own damage, TPP), where they lower motor cost D2. Pattern:
  new fields entering the motor severity selection (about 1,000-2,000 claims, 2 steps, 50/50 blend) do not transfer.
- bldg_age_b: no signal beyond the baseline (developed model already uses year_built).
- Cleaning suggestion "open claims with zero recoveries": already in `claim_basis()` (closed-claim recovery ratio applied
  to open claims, `00_setup_week2.R`), so not rerun.

**frequency D2 change vs the step's reference (+ = improvement)**

| line | peril | X21a | X21b | X21c | X21d | X21e | X21f | X21g | X21h | X21i |
|---|---|---|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | escape_of_water | 0 | +0.0006 | +0.0014 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | fire | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | flood | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | storm | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | subsidence | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| contents | accidental_damage | +0.0020 | 0 | 0 | 0 | 0 | +0.0014 | 0 | +0.0014 | 0 |
| contents | escape_of_water | 0 | +0.0016 | 0 | 0 | 0 | +0.0013 | 0 | +0.0013 | +0.0016 |
| contents | flood | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| contents | theft | +0.0007 | +0.0004 | 0 | 0 | 0 | +0.0015 | 0 | +0.0015 | +0.0004 |
| motor | bodily_injury | 0 | 0 | +0.0011 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | glass_hail | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | own_damage | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | theft | +0.0013 | 0 | +0.0008 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | third_party_prop | +0.0010 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | **(all)** | 0 | +0.0001 | +0.0001 | 0 | 0 | 0 | 0 | 0 | 0 |
| contents | **(all)** | +0.0015 | +0.0005 | 0 | 0 | 0 | +0.0010 | 0 | +0.0010 | +0.0005 |
| motor | **(all)** | +0.0005 | 0 | +0.0001 | 0 | 0 | 0 | 0 | 0 | 0 |
| ALL | **(all)** | +0.0005 | +0.0001 | 0 | 0 | 0 | +0.0001 | 0 | +0.0001 | +0.0001 |

**severity D2 change vs the step's reference (+ = improvement)**

| line | peril | X21a | X21b | X21c | X21d | X21e | X21f | X21g | X21h | X21i |
|---|---|---|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | escape_of_water | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | fire | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | flood | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | storm | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | subsidence | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| contents | accidental_damage | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| contents | escape_of_water | 0 | -0.0001 | 0 | 0 | 0 | 0 | 0 | 0 | -0.0001 |
| contents | flood | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| contents | theft | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | bodily_injury | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | glass_hail | 0 | +0.0069 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | own_damage | 0 | 0 | 0 | +0.0002 | 0 | +0.0019 | -0.0001 | 0 | 0 |
| motor | theft | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | third_party_prop | 0 | 0 | 0 | 0 | 0 | 0 | +0.0012 | 0 | 0 |
| buildings | **(all)** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| contents | **(all)** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | **(all)** | 0 | +0.0009 | 0 | +0.0001 | 0 | +0.0006 | +0.0002 | 0 | 0 |
| ALL | **(all)** | 0 | +0.0006 | 0 | 0 | 0 | +0.0004 | +0.0001 | 0 | 0 |

**cost D2 change vs the step's reference (+ = improvement)**

| line | peril | X21a | X21b | X21c | X21d | X21e | X21f | X21g | X21h | X21i |
|---|---|---|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | escape_of_water | 0 | +0.0001 | +0.0004 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | fire | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | flood | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | storm | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| buildings | subsidence | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| contents | accidental_damage | +0.0034 | 0 | 0 | 0 | 0 | +0.0017 | 0 | +0.0017 | 0 |
| contents | escape_of_water | 0 | +0.0025 | 0 | 0 | 0 | +0.0018 | 0 | +0.0018 | +0.0025 |
| contents | flood | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| contents | theft | -0.0003 | -0.0056 | 0 | 0 | 0 | +0.0003 | 0 | +0.0003 | -0.0056 |
| motor | bodily_injury | 0 | 0 | +0.0022 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | glass_hail | 0 | -0.0003 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | own_damage | 0 | 0 | 0 | +0.0002 | 0 | +0.0006 | -0.0001 | 0 | 0 |
| motor | theft | +0.0020 | 0 | +0.0003 | 0 | 0 | 0 | 0 | 0 | 0 |
| motor | third_party_prop | +0.0004 | 0 | 0 | 0 | 0 | 0 | -0.0001 | 0 | 0 |
| buildings | **(all)** | 0 | -0.0001 | +0.0001 | 0 | 0 | 0 | 0 | 0 | 0 |
| contents | **(all)** | +0.0013 | -0.0020 | 0 | 0 | 0 | +0.0005 | 0 | +0.0005 | -0.0020 |
| motor | **(all)** | +0.0006 | -0.0001 | +0.0003 | -0.0001 | 0 | 0 | -0.0002 | 0 | 0 |
| ALL | **(all)** | +0.0005 | -0.0004 | +0.0001 | -0.0001 | 0 | +0.0001 | -0.0001 | +0.0001 | -0.0004 |

**Cumulative: x21c vs x20_tblend, D2 (A/E) by peril**

| line | peril | freq x20 | freq x21c | sev x20 | sev x21c | cost x20 | cost x21c | cost A/E x20 -> x21c |
|---|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | 0.0579 | 0.0579 | -0.0048 | -0.0048 | 0.1054 | 0.1054 | 1.081 -> 1.081 |
| buildings | escape_of_water | 0.0068 | 0.0082 | 0.0237 | 0.0237 | 0.0068 | 0.0071 | 0.809 -> 0.791 |
| buildings | fire | -0.0163 | -0.0163 | -0.0458 | -0.0458 | 0.0389 | 0.0389 | 0.908 -> 0.908 |
| buildings | flood | 0.3204 | 0.3204 | -0.0010 | -0.0010 | 0.5142 | 0.5142 | 0.875 -> 0.875 |
| buildings | storm | 0.0591 | 0.0591 | 0.0348 | 0.0348 | 0.0718 | 0.0718 | 0.963 -> 0.963 |
| buildings | subsidence | 0.0718 | 0.0718 | -0.2953 | -0.2953 | 0.0716 | 0.0716 | 0.570 -> 0.570 |
| contents | accidental_damage | 0.1137 | 0.1158 | -0.0057 | -0.0057 | 0.1755 | 0.1789 | 0.930 -> 0.941 |
| contents | escape_of_water | 0.0174 | 0.0174 | 0.1887 | 0.1887 | 0.0524 | 0.0524 | 0.854 -> 0.854 |
| contents | flood | 0.2190 | 0.2190 | 0.1253 | 0.1253 | 0.3672 | 0.3672 | 0.920 -> 0.920 |
| contents | theft | 0.0312 | 0.0320 | 0.0705 | 0.0705 | 0.0579 | 0.0576 | 1.053 -> 1.051 |
| motor | bodily_injury | 0.0410 | 0.0421 | 0.0070 | 0.0070 | 0.0311 | 0.0333 | 1.038 -> 1.035 |
| motor | glass_hail | 0.1008 | 0.1008 | 0.0132 | 0.0132 | 0.1756 | 0.1756 | 1.026 -> 1.026 |
| motor | own_damage | 0.1518 | 0.1518 | 0.0201 | 0.0201 | 0.1915 | 0.1915 | 1.001 -> 1.001 |
| motor | theft | 0.0533 | 0.0554 | 0.0280 | 0.0280 | 0.1385 | 0.1408 | 1.206 -> 1.191 |
| motor | third_party_prop | 0.0603 | 0.0613 | 0.0003 | 0.0003 | 0.0415 | 0.0419 | 0.939 -> 0.938 |
| buildings | **(all)** | 0.0468 | 0.0469 | 0.5191 | 0.5191 | 0.1021 | 0.1021 | 0.852 -> 0.849 |
| contents | **(all)** | 0.0308 | 0.0323 | 0.3971 | 0.3971 | 0.0622 | 0.0635 | 0.973 -> 0.973 |
| motor | **(all)** | 0.0839 | 0.0845 | 0.3018 | 0.3018 | 0.0446 | 0.0455 | 1.012 -> 1.010 |
| ALL | **(all)** | 0.1599 | 0.1605 | 0.3968 | 0.3968 | 0.1189 | 0.1196 | 0.961 -> 0.959 |

Not run in X21 (need Wendy's go-ahead, larger changes): credit_tier in the developed baseline (step 5 retrain, about
41 min, separate BASE_TAG); case-reserve development (IBNER) on open claims (changes the validation actuals, so it
needs its own like-for-like protocol).

**Submission 9 (public 0.16473, -0.00189 vs x20_tblend 0.16662):** `week2/output/submission/submission_20261027_1524_week2_optionB_x21c.csv`,
MD5 `99ec00afb3a8b7fc97d6b361f8c67198`. Total vs x20_tblend file +0.12%; row ratio p1-p99 0.90-1.20.

Public result and reading (27 Oct 2026): local said +0.0007 (as-is) / +0.0022 (2025 mix); public said -0.0019. A bootstrap
of the 2024 rows at public-split size (20 / 30 / 50% of the 209,063 test rows) gives a diff SD of 0.0006 / 0.0005 / 0.0004
around +0.0007, and none of 300 draws reached -0.0019. So the drop is not row-sampling noise: the credit_tier / n_lines
relativities (fitted on 2023-24, mostly renewals, picked on the 2024 fold) do not carry over to the 2025 book (76% broker
take-on new business). Same pattern as X13b (#3): a step 7 shape gain on the 2024 fold that the 2025 public split rejects.
Since public and private are random splits of the same 2025 rows, private is expected to be worse than x20_tblend too.
Decision: x21c reverted (D031); x20_tblend stays the best model and preferred final selection.
Lesson for further rounds: new emerging-only *shape* factors chosen on the 2024 fold are not reliable for 2025; changes that
are judged on 2025-like structure (new-business / broker behaviour, levels) are the better remaining lever.

## NB round: 2025 broker take-on treatment (27 Oct 2026)

Goal: better treatment of the 2025 new business (77% of 2025 test exposure; 88-91% January starts, 70% broker), keeping
x20_tblend as the primary final selection. Probe: x20_tblend 2024 D2 is 0.126 on renewals but 0.056 on new-business rows.
Web research could not be done (no internet access in this session); directions are from standard practice for transferred
books and were tested on the data.

New code (defaults reproduce x20_tblend exactly; x20nb = reproduction, max |diff| 0 on valid / final / insample / 2025 pred):
- `week2/R/nb_load_fns.R`: shared NB load (NB_K, NB_PRIOR one/dev/dev_jan, NB_LEVEL line/peril, NB_KP, NB_PPRIOR line/dev/dev_jan).
- `week2/R/07_emerging_adjust.R`: writes `insample23_peril.parquet` (2023 fit on 2023 rows); `MIXW_MODE=clf` (domain-classifier weights).
- `week2/R/14_blend_severity.R`: passes insample23 through.
- `week2/R/08_loadings_2025.R`: ADJ_TAG input; NB load from nb_load_fns.R (per peril).
- `week2/R/22_nb_backtest.R`: NEW - fits the NB load as step 8 does but on 2023 only and applies it to the 2024 fold. Before this, the 2024 gate never saw the step 8 load.
- `week2/R/23_nb_pooled_model.R`: NEW - pooled developed + emerging NB residual xgboost (Tweedie 1.5), shape only.
- `week2/run/run_nb_win.ps1`: 22 -> 08 -> 09 -> 13 gate -> 21 scorecard.

| Run | Direction | Ref | 2025-mix diff | As-is diff | Decision |
|---|---|---|---|---|---|
| NB0 | Current D020 load backtested (K300, prior 1; 2023 fit gives motor 1.374, bldg 0.989, cont 0.996) | x20_tblend | -0.00781 (2SE 0.0102) | -0.00121 | The current emerging NB load hurts out of year |
| NB0b | No step 8 load (K=Inf) | x20_tblend | 0 | 0 | = x20_tblend on 2024 (load was not in the gate) |
| NB1 | (1) Load credibility-weighted towards developed residual NB A/E (K300) | x20_tblend | -0.00701 | -0.00109 | Rejected |
| **NB1b** | **(1) Load = developed baseline residual NB A/E only (out of fold, developed actuals)** | x20_tblend | **+0.00103** (2SE 0.0018) | **+0.00016** | **Accepted (within noise, simpler, much larger data)** |
| NB2 | (2) January-start developed NB residual | NB1b | -0.00157 | -0.00025 | Rejected |
| NB3a | (3) Per-peril load, developed peril residuals | NB1b | -0.00113 | -0.00018 | Rejected |
| NB3b | (3) Per-peril, emerging peril A/E credibility KP300 towards developed | NB1b | -0.00228 | -0.00035 | Rejected |
| NB4 | (4) Seasonal full-year shape per peril (developed Jan-start NB peril/line) | NB1b | -0.00749 | -0.00116 | Rejected |
| NB6 | (6) Step 7 fit weights = domain-classifier odds (ESS 7-15%) | NB1b | -0.01386 | -0.00963 | Rejected |
| NB7 | (7) Pooled developed + emerging NB residual model, w 0.5 | NB1b | -0.00200 | -0.00031 | Rejected |

Direction 5 (NB-focused validation) is the 22_nb_backtest.R backtest itself: step 8 changes are now gated on 2024.

NB1b loads (2025, developed 2023-24 folds): motor 0.998, buildings 1.051, contents 0.993 (x20_tblend: 1.165 / 0.966 / 1.046).
2025 burn: motor 625.1 -> 553.3 (-11.5%), buildings 355.5 -> 379.1 (+6.6%), contents 106.1 -> 102.3 (-3.6%).

NB1b vs x20_tblend per peril (D2 change on the 2024 fold, scorecard; severity unchanged by design):

| line | peril | frequency | severity | cost |
|---|---|---|---|---|
| ALL | (all) | +0.0001 | 0 | +0.0002 |
| buildings | (all) | +0.0003 | 0 | +0.0003 |
| buildings | accidental_damage | +0.0003 | 0 | +0.0006 |
| buildings | escape_of_water | +0.0003 | 0 | +0.0008 |
| buildings | fire | -0.0002 | 0 | -0.0000 |
| buildings | flood | +0.0002 | 0 | +0.0006 |
| buildings | storm | +0.0003 | 0 | +0.0001 |
| buildings | subsidence | -0.0001 | 0 | +0.0004 |
| contents | (all) | +0.0003 | 0 | +0.0005 |
| contents | accidental_damage | 0 | 0 | 0 |
| contents | escape_of_water | -0.0001 | 0 | -0.0016 |
| contents | flood | -0.0005 | 0 | +0.0013 |
| contents | theft | +0.0009 | 0 | +0.0010 |
| motor | (all) | -0.0000 | 0 | -0.0000 |
| motor | bodily_injury | -0.0001 | 0 | -0.0001 |
| motor | own_damage | -0.0000 | 0 | +0.0001 |
| motor | theft | -0.0000 | 0 | +0.0002 |
| motor | third_party_prop | -0.0000 | 0 | -0.0001 |

Per-run scorecards: `week2/output/scores/x21/<tag>_vs_<ref>.md`; loads: `week2/output/22_nb_backtest/<tag>_loads.csv`.

Reading: the emerging NB A/E is unstable year to year (2023-only fit: motor 1.73 relative; 2023-24 fit: 1.24) and NB is only
~10% of the 2024 fold, so the 2024 gate is weak for NB (2 SE 0.002 on mix). NB1b is mainly a 2025 level change (motor NB -14%),
driven by the developed market's own out-of-fold NB residual (about 1.0). It is the most material untested lever for the public
score; not submitted. x20_tblend stays the primary final selection until Wendy decides.

## Regularization and re-tune failures (28 Oct 2026)

These experiments are recorded here so they are not repeated without a new reason:

| Method | Local ALL cost D2 | Public | Result | Lesson |
|---|---:|---:|---|---|
| Week 1 shared-field re-tune `b8_combo_f` | 0.1197 | 0.16395 | rejected | The build also lost the motor frequency floor; motor 2025 burn fell to 601.4. The re-tuned baseline was not judged independently. |
| Corrected re-tune with motor floor | not separately scored | 0.16471 | rejected | Motor burn remained 1.7% below x20; re-tuning shared fields changed the public level in the wrong direction. |
| Lasso-like factor soft threshold `l1f02` | 0.1183 | pending | rejected locally | Shrinking every factor coefficient after the ridge fit removed useful emerging signal. |
| Lasso-like factor soft threshold `l1f05` | 0.1174 | pending | rejected locally | Stronger soft threshold was materially worse. |
| Maximum two emerging factors `maxf2` | 0.1186 | 0.16495 | rejected | Simpler greedy factor selection did not transfer to the 2025 book; it also lowered the local score versus x20. |

The successful adjustment was **line-specific**, not global regularization: keep x20 motor and use the corrected re-tuned
model only for buildings and contents. That file scored 0.16690 publicly and remains the selected candidate.
## Motor round: improving #12's motor ranking without probing (30 Oct 2026, Wendy's request)

Basis #12 `line_ensemble` (public 0.16690): x20_tblend motor + re-tuned b8 buildings / contents. Every variant keeps x20's motor
level per peril (validation and 2025), so only the ranking within motor perils changes. Score: motor cost D2 on the 2024
fold (#12 = 0.04456) and a policy bootstrap of the gain (200 draws). Scripts: `week2/run/run_motor_round.ps1` (refits),
`week2/R/28_motor_round.R` (blends, scoring, files). Control refit `m0ctl` reproduced x20 exactly.

| Idea | Variant | Motor cost D2 | Gain vs #12 (SE, % draws better) | Result |
|---|---|---:|---|---|
| M1 blend with re-tuned motor | w = 0.25 / 0.5 / 0.75 / 1 | 0.04492 / 0.04521 / 0.04542 / 0.04555 | +0.00037 (96%) ... +0.00105 (+/- 0.00093, 86%) | kept |
| M2 BI frequency borrows TPP ranking | w = 0.1 / 0.3 / 0.5 / 0.7 / 1 | 0.04470 / 0.04492 / 0.04503 / 0.04506 / 0.04490 | +0.00015 ... +0.00052 (69-81%) | kept at 0.3 (BI D2 0.031 -> 0.036) |
| M3 lower large-loss cap | BI 0.99, theft 0.995 | 0.04454 | -0.00003 (24%) | rejected |
| M4 more bags | 15 instead of 5 | 0.04454 | -0.00002 (45%) | rejected |
| M5 monotone constraints | years_licensed, years_at_address -1 | 0.04532 | +0.00086 (+/- 0.00099, 82%) | kept |
| M6 recency weights | 0.7 / 0.8 / 0.9 / 1.0 | 0.04488 | +0.00031 (+/- 0.00013, 100%) | kept |
| M6b stronger recency | 0.5 / 0.65 / 0.8 / 1.0 | 0.04477 | +0.00020 (86%) | weaker than M6 |
| M5 + M6 in one refit | both switches | 0.04490 | +0.00040 (72%) | not additive |
| Combination | M5 refit + M1 0.5 + M2 0.3 | **0.04587** | **+0.00139 (+/- 0.00083, 97%)** | best (C1) |
| Combination | M5/M6 average + M1 0.5 + M2 0.3 | 0.04573 | +0.00122 (96%) | C2 |
| Combination | M5+M6 refit + M1 0.5 + M2 0.3 | 0.04577 | +0.00128 (96%) | C3 |
| Combination | M6 refit + M1 0.5 + M2 0.3 | 0.04553 | +0.00100 (95%) | C5 |

Lessons: the motor ranking gains come from shape regularisation (monotone ages / tenure, averaging two baselines, borrowing the
TPP frequency ranking for thin BI), not from capacity (bags) or caps. All gains are small (ALL cost D2 +0.0002 to +0.0006) and
the weights were chosen on the same fold, so the public score may not move. Ten candidate files C1-C10 (week2_workflow.md).

**Public result (30 Oct 2026):** C1 0.16458 (#28), C6 0.16500 (#29), C7 0.16441 (#30) vs #12 0.16690. All lost 0.0019-0.0025, with identical levels, so the 2024-fold motor ranking gains did not transfer to 2025. Lesson: at this size the 2024 fold cannot rank motor-shape changes; every one tried (x21c, b8 re-tune, maxf2, motor round) lost about 0.002 public. Stop motor-shape work; #12 stays.

## Motor level: actuarial level levers on #12 (30 Oct 2026, Wendy's request, no probing)

Question: is #12's motor level too low, and which non-probing, actuarially sound adjustments would raise it?

| Check / lever | Finding | Used |
|---|---|---|
| Spread (Week 1 spread as proxy) | Best power k on pred^k (total kept) about 1.0 on emerging 2024 (perils 0.95-1.05) and 0.95-1.0 on developed folds | No |
| Reporting pattern | Emerging and developed lags match (KS p 0.16-0.99); IBNR counts fine | No |
| BI severity trend | Chosen 0; developed -8.8% is an immature-year artefact. Mature loss years 2021-23: +4%/yr; emerging +4.9% | +4.5%: x1.045 to 2025, x1.0267 trend-to-base |
| BI severity development | Late reports larger; mature-year factors at emerging ages 1.007 (2023), 1.031 (2024) | x1.0168 |
| BI large-loss load | Emerging 1.024 vs developed 1.048 (benchmark complement) | x1.0230 |
| New-business load | 77% of 2025 exposure NB; applied 1.165 (z 0.70) vs full emerging A/E 1.237 | x1.0611 on NB rows |
| IBNER (case reserves) | 58% of emerging BI open, paid/incurred 0.49 vs 0.69; not measurable from one snapshot | No (judgement) |
| BI frequency trend | Emerging +7.8%, floored at 0 | No |

Candidates (week2/R/29_motor_level.R, motor rows only, ranking unchanged): L1 BI (motor +4.3%), L2 NB (+4.9%), L3 both
(+9.4%). 2024 fold (reported actuals, 9% NB) prefers #12's level (motor A/E 1.012; D2 0.0446 vs 0.0441 / 0.0444 / 0.0439), so
the 2024 fold cannot judge these 2025 ultimate-cost levers; the public score is the only test.

**Public result (30 Oct 2026):** L3 0.16840 (#31), L2 0.16769 (#32), L1 0.16793 (#33) vs #12 0.16690. All three gained; the two levers
add +0.00079 (NB) and +0.00103 (BI) alone and +0.00150 together (slightly less than additive, as expected for a level move under
Tweedie). Unlike the motor-shape changes, the level levers transferred to the public board. Each lever was set from data and
actuarial reasoning before submission (no factor was tuned on the board); three scores were used only to confirm direction.
**L3 chosen as the final submission** (replaces `lvl_half`, which used probed levels).
