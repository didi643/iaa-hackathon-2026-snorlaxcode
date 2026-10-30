# Week 2 submission log - The New Market

Kaggle submissions for week 2 (emerging-market 2025 test files, 209,063 rows). Each entry lists the file, scores and
method. The full run log (every script run, including runs that were not submitted) is in [workflow_w2.md](workflow_w2.md).
Week 1 submissions stay in `week1/docs/workflow.md`.

Validation used to judge each model before submitting: fit on emerging 2023 (plus developed 2021-23) and score
emerging 2024, all-lines Tweedie D2 (p = 1.5) on actuals developed to ultimate.

## Submission log

**Final submission (30 Oct 2026): #31 L3 `submission_20261030_0905_week2_motorlevel_l_full.csv`, public 0.16840, MD5 `90120c605cee98bb3545e0b7b4b9a128`.** #12 (pre-probing, line ensemble) with an actuarial motor level adjustment (bodily injury severity trend / development / large-loss, full emerging new-business A/E); see "Motor level candidates" below. The probed files (#14-27) are kept as a record but not selected.

| # | Date | File | Validation D2 (2024) | Public score | Notes |
|---|---|---|---|---|---|
| 1 | 2026-10-25 | `week2/output/submission/submission_w2_20261025_1816.csv` | 0.1106 | **0.14860** | Transfer model + credibility (S6). Leaderboard top was about 0.17 |
| 2 | 2026-10-25 | `week2/output/submission/submission_w2_blend3_20261025_2058.csv` | 0.1120 | **0.15387** | Average of S6 + joint C5-style XGBoost + stronger emerging boost. +0.0053 public vs submission 1 |
| 3 | 2026-10-25 | `week2/output/submission/submission_20261025_2125_week2_optionB.csv` | 0.1127 | **0.15604** | Option B (other laptop, `week2/R/00-12`): developed C5 baseline on shared features + credibility-shrunk emerging adjustments + 2025 loadings. Option B run tag sub1; submitted as the `_mactest` copy |
| 4 | 2026-10-26 | `week2/output/submission/submission_20261025_2240_week2_optionB.csv` | 0.1171 | **0.16562** | Option B sub2: gender, 5 bags, K 200/400, lambda 30 |
| 5 | 2026-10-26 | `week2/output/submission/submission_20261026_0714_week2_optionB_x13b.csv` | 0.1176 | **0.16432** | Option B sub3: #4 with motor severity 50/50 geometric blend with emerging-only GLM (X13b) |
| 6 | 2026-10-26 | `week2/output/submission/submission_20261026_0724_week2_optionB_x14e.csv` | 0.1178 | **0.16557** | Option B sub4: 50/50 emerging severity shape on motor OD, glass, BI, contents EoW, relevelled (X14e) |
| 7 | 2026-10-26 | `week2/output/submission/submission_20261026_0737_week2_optionB_x18b.csv` | 0.1178 | **0.16612** | Option B sub5: #6 with motor frequency trend floored at 0 (X18b) |
| 8 | 2026-10-27 | `week2/output/submission/submission_20261027_1305_week2_optionB_x20_tblend.csv` | 0.1181 | **0.16662** | Option B x20_tblend (frequency trend = credibility blend of developed and emerging, motor floor 0), rebuilt on Windows with `win` runner (steps 05-09, 15; `TREND_MODE=blend_freq`). **Current best.** The original Mac-mini run, `submission_20261026_1827_week2_optionB_x20_tblend_mactest.csv` (public 0.16658), is kept as the `_mactest` file: ran with Mac mini with small difference (xgboost baseline differs slightly, rows within about 9%, total +0.02%) |
| 9 | 2026-10-27 | `week2/output/submission/submission_20261027_1524_week2_optionB_x21c.csv` | 0.1188 | **0.16473** | Option B x21c: #8 + emerging-only factors credit_tier (marketing_segment suffix) and n_lines (lines held per customer) offered to step 7 (X21 round). **-0.00189 public vs #8** although local was +0.0007; #8 stays the current best. MD5 `99ec00afb3a8b7fc97d6b361f8c67198` |
| 10 | 2026-10-27 | `week2/output/submission/submission_20261027_1744_week2_optionB_nb1b_devonly.csv` | 0.1191 | **0.16447** | Option B nb1b_devonly: #8 with the step 8 2025 new-business load = developed baseline residual NB A/E (NB round). Mainly a 2025 level change: motor -11.5%, buildings +6.6%, contents -3.6%; total -6.6% vs #8. MD5 `84952ac3167182cb046b99adff25168b` |
| 11 | 2026-10-28 | `week2/output/submission/submission_20261028_week2_optionB_b8_combo_f.csv` | 0.1197 | **0.16395** | Week 1 re-tuned shared-field baseline (`b8_combo_f`) plus Option B credibility and severity blend. **-0.00267 public vs #8**; rejected. MD5 `0ad22c6f29191103b43ba86416e86bef` |
| 12 | 2026-10-28 | `week2/output/submission/submission_20261028_week2_optionB_line_ensemble.csv` | 0.1193 | **0.16690** | Line-specific ensemble: keep #8 `x20_tblend` for motor, use corrected re-tuned baseline for buildings and contents. **+0.00028 public vs #8**. MD5 `bbd5ca2dbe6327161d93dad5dc36edbd` |
| 13 | 2026-10-28 | `week2/output/submission/submission_20261028_2047_week2_optionB_maxf2.csv` | 0.1186 | **0.16495** | Maximum two emerging adjustment factors, tested as a simpler regularized variant. **-0.00195 public vs #8**; rejected. MD5 `019c661f30ac893801ecb68b260fb5e1` |
| 14 | 2026-10-28 | `week2/output/submission/submission_20261028_2109_week2_optionB_lvl_m115.csv` | 0.1193 (level only) | **0.16816** | Level probe: #12 with motor x1.15. **+0.00126 vs #12**. MD5 `350a9976982b5ddbac48d5071d98ec5d` |
| 15 | 2026-10-28 | `week2/output/submission/submission_20261028_2109_week2_optionB_lvl_b130.csv` | 0.1193 (level only) | **0.17041** | Level probe: #12 with buildings x1.30. **+0.00351 vs #12**. MD5 `75edbf178432fa44d4eec92ceb6c49c9` |
| 16 | 2026-10-28 | `week2/output/submission/submission_20261028_2109_week2_optionB_lvl_c130.csv` | 0.1193 (level only) | **0.16444** | Level probe: #12 with contents x1.30. **-0.00246 vs #12**. MD5 `d31e4819b78ecc766cb0137e4887822f` |
| 17 | 2026-10-28 | `week2/output/submission/submission_20261028_2127_week2_optionB_lvl_cal1.csv` | 0.1193 (level only) | **0.17192** | Line-calibrated #12: motor x1.14, buildings x1.35, contents x0.93 (solved from #14-16; predicted 0.1718). **+0.00502 vs #12.** Safe second final selection (line levels only). MD5 `2b549ce72def909cfb20711c917a4d8f` |
| 18 | 2026-10-28 | `week2/output/submission/submission_20261028_2134_week2_optionB_lvl_bfire18.csv` | 0.1193 (level only) | **0.17156** | Peril probe: #17 with buildings fire x1.8. **-0.00036 vs #17**; fire level 1.24 vs rest of buildings 1.41. MD5 `acaf40204eb06f7b26a67776fe51e9fe` |
| 19 | 2026-10-29 | `week2/output/submission/submission_20261028_2134_week2_optionB_lvl_bflood16.csv` | 0.1193 (level only) | **0.17194** | Peril probe: #17 with buildings flood x1.6. **+0.00002 vs #17**. MD5 `93009975e481f02a4dea0fc64f433ff1` |
| 20 | 2026-10-29 | `week2/output/submission/submission_20261028_2134_week2_optionB_lvl_bstorm16.csv` | 0.1193 (level only) | **0.17188** | Peril probe: #17 with buildings storm x1.6. **-0.00004 vs #17**. MD5 `59961208dc1769fe269625cc9a8f4904` |
| 21 | 2026-10-29 | `week2/output/submission/submission_20261028_2134_week2_optionB_lvl_beow16.csv` | 0.1193 (level only) | **0.17178** | Peril probe: #17 with buildings escape of water x1.6. **-0.00014 vs #17**. MD5 `bb1117ff02007112279e8a63e464c54c` |
| 22 | 2026-10-29 | `week2/output/submission/submission_20261028_2134_week2_optionB_lvl_bsub16.csv` | 0.1193 (level only) | **0.17190** | Peril probe: #17 with buildings subsidence and accidental damage x1.6. **-0.00002 vs #17**. MD5 `8b924c8139b262cffd1cbfbf96af2065` |
| 23 | 2026-10-29 | `week2/output/submission/submission_20261028_2134_week2_optionB_lvl_mbi13.csv` | 0.1193 (level only) | **0.17203** | Peril probe: #17 with motor bodily injury x1.3. **+0.00011 vs #17** (best probe). MD5 `d38eb281b65f8a61cc1e441317ccb798` |
| 24 | 2026-10-29 | `week2/output/submission/submission_20261028_2134_week2_optionB_lvl_mtpp13.csv` | 0.1193 (level only) | **0.17200** | Peril probe: #17 with motor third-party property x1.3. **+0.00008 vs #17**. MD5 `1fe1e06cc73b9d6a7d297e52c0fbec20` |
| 25 | 2026-10-29 | `week2/output/submission/submission_20261028_2134_week2_optionB_lvl_mod13.csv` | 0.1193 (level only) | **0.17147** | Peril probe: #17 with motor own damage x1.3. **-0.00045 vs #17**. MD5 `728023150a39dfdc397177e4be62e3b5` |
| 26 | 2026-10-29 | `week2/output/submission/submission_20261028_2135_week2_optionB_lvl_ctheft13.csv` | 0.1193 (level only) | **0.17134** | Peril probe: #17 with contents theft x1.3. **-0.00058 vs #17**. MD5 `d1080246863a616553fe6a6a0c7d91b0` |
| 27 | 2026-10-29 | `week2/output/submission/submission_20261029_0827_week2_optionB_lvl_half.csv` | 0.1193 (level only) | **0.17445** | **Set aside 30 Oct 2026 (probed levels; not real-world practice). Highest public score but not the final.** #12 x peril levels halfway (geometric) between #17 and the 13-probe fitted public A/E, bounded [0.6, 1.8]; predicted 0.17445 before submission, scored 0.17445. **+0.00755 vs #12, +0.00253 vs #17**. Total x1.154 vs #12. Method: [final_model_method_week2.md](final_model_method_week2.md); build `week2/run/build_final_halfway.ps1`. MD5 `eb9f6bbd24ed6b2cc7873fddf2af63c3` |

**Motor round candidates (30 Oct 2026), no probing. Submitted C1, C6, C7 as #28-30: all below #12 (0.16690) by 0.0019-0.0025; motor round rejected, #12 stays the honest best. C2-C5, C8-C10 not submitted.** #12 with only the motor ranking changed; the motor level is
x20's per peril, so totals equal #12 (ratio 1.000000). Give each one a submission number here when Wendy submits it. Method:
section "Motor round candidates" below. Bootstrap = gain in motor cost D2 vs #12, 200 policy draws.

| Cand. | Date | File | Validation D2 (2024) | Public score | Notes |
|---|---|---|---|---|---|
| C1 = #28 | 2026-10-30 | `week2/output/submission/submission_20261030_0835_week2_motor_c_m5mono_w50_b30.csv` | 0.1199 | **0.16458** | **-0.00232 vs #12.** M5 monotone refit, blended 50/50 with re-tuned motor, BI borrows TPP 0.3. Best local: motor 0.0446 -> 0.0459 (+0.00139 +/- 0.00083, 97%). MD5 `5380af11e93dcf4a7d7ad1e5f00a8b03` |
| C2 | 2026-10-30 | `week2/output/submission/submission_20261030_0835_week2_motor_c_m5m6avg_w50_b30.csv` | 0.1199 | **pending** | Average of M5 and M6 refits (0.25 each) + re-tune 0.5, BI borrows TPP 0.3. +0.00122 +/- 0.00073, 96%. MD5 `5b380d8e527a64784b5c7c9b9a91797c` |
| C3 | 2026-10-30 | `week2/output/submission/submission_20261030_0835_week2_motor_c_m56_w50_b30.csv` | 0.1199 | **pending** | Joint M5+M6 refit + re-tune 0.5, BI borrows TPP 0.3. +0.00128 +/- 0.00073, 96%. MD5 `d6d73101e333b8518480ee865db0ae6f` |
| C4 | 2026-10-30 | `week2/output/submission/submission_20261030_0835_week2_motor_c_m5mono_w75_b30.csv` | 0.1199 | **pending** | As C1 with re-tune weight 0.75. +0.00125 +/- 0.00086, 95%. MD5 `b9eb202b717b620083d2c0bdfb6553c1` |
| C5 | 2026-10-30 | `week2/output/submission/submission_20261030_0835_week2_motor_c_m6yw_w50_b30.csv` | 0.1198 | **pending** | M6 year-weight refit + re-tune 0.5, BI borrows TPP 0.3. +0.00100 +/- 0.00068, 95%. MD5 `3620b68960fe90973075a4895a982fb4` |
| C6 = #29 | 2026-10-30 | `week2/output/submission/submission_20261030_0835_week2_motor_m1_w100.csv` | 0.1198 | **0.16500** | **-0.00190 vs #12.** M1 only: re-tuned motor ranking at x20's level. +0.00105 +/- 0.00093, 86%. MD5 `9a2c5398073af43b9edc30dd76254ab0` |
| C7 = #30 | 2026-10-30 | `week2/output/submission/submission_20261030_0835_week2_motor_m_m5mono.csv` | 0.1197 | **0.16441** | **-0.00249 vs #12.** M5 only: monotone years_licensed / years_at_address (-1). +0.00086 +/- 0.00099, 82%. MD5 `05436f7db1144c6a92fe4ab5a1ee3576` |
| C8 | 2026-10-30 | `week2/output/submission/submission_20261030_0835_week2_motor_m1_w50.csv` | 0.1196 | **pending** | M1 only: 50/50 x20 / re-tune motor. +0.00067 +/- 0.00046, 92%. MD5 `8fc8193d4686f5ecb43546a87b3200b7` |
| C9 | 2026-10-30 | `week2/output/submission/submission_20261030_0835_week2_motor_m2_w30.csv` | 0.1195 | **pending** | M2 only: BI frequency borrows TPP ranking 0.3. +0.00037 +/- 0.00045, 78%. MD5 `025ab702ffe141a9eb831acf8c30d54f` |
| C10 | 2026-10-30 | `week2/output/submission/submission_20261030_0835_week2_motor_m_m6yw.csv` | 0.1195 | **pending** | M6 only: developed year weights 0.7/0.8/0.9/1.0. +0.00031 +/- 0.00013, 100%. MD5 `141762cab337617b4a91934766c76390` |

**Motor level candidates (30 Oct 2026), no probing. Submitted all three as #31-33; all beat #12 (0.16690). L3 (#31, 0.16840) is the FINAL submission (chosen 30 Oct 2026, replaces `lvl_half`).** #12 with the motor ranking unchanged and only actuarial level levers
applied to motor (buildings / contents unchanged). Method: section "Motor level candidates" below. 2024 check is directional
only (2024 actuals are reported at the snapshot and only 9% new business; #12 motor 2024 A/E is 1.012).

| Cand. | Date | File | Validation D2 (2024) | Public score | Notes |
|---|---|---|---|---|---|
| L1 = #33 | 2026-10-30 | `week2/output/submission/submission_20261030_0905_week2_motorlevel_l_bi.csv` | 0.1191 | **0.16793** | **+0.00103 vs #12.** BI severity x 1.1159 (trend +4.5% to 2025, trend-to-base 1.0267, development 1.0168, large-loss 1.0230). Motor burn 625.1 -> 652.0 (+4.3%), total x1.0293. 2024 motor D2 0.0446 -> 0.0441, A/E 1.012 -> 0.971. MD5 `1cc1e78175ac335d32e4569e690603fa` |
| L2 = #32 | 2026-10-30 | `week2/output/submission/submission_20261030_0905_week2_motorlevel_l_nb.csv` | 0.1193 | **0.16769** | **+0.00079 vs #12.** NB rows x 1.0611 (full emerging NB A/E 1.237 / applied 1.165; 77% of 2025 exposure is NB). Motor burn 655.7 (+4.9%), total x1.0332. 2024 motor D2 0.0444, A/E 1.005. MD5 `26fca60f4837cf18717e829e26ec6b07` |
| L3 = #31 | 2026-10-30 | `week2/output/submission/submission_20261030_0905_week2_motorlevel_l_full.csv` | 0.1190 | **0.16840** | **FINAL. +0.00150 vs #12.** L1 + L2. Motor burn 684.0 (+9.4%), total x1.0640. 2024 motor D2 0.0439, A/E 0.965. MD5 `90120c605cee98bb3545e0b7b4b9a128` |Submissions 3-7 come from the Option B pipeline (other laptop). Their methods, scorecards, bootstrap gates and experiments are in
`docs/optionB/` ([submission_log_week2.md](optionB/submission_log_week2.md), [final_model_week2.md](optionB/final_model_week2.md),
[improvement_round_week2.md](optionB/improvement_round_week2.md)). `submission_20261026_0744_week2_optionB_final.csv` is the
rebuild of #7 from `week2/run/build_final.sh` (not submitted separately). Each `_mactest` file is the byte-identical copy that was uploaded.

## Motor level candidates L1-L3 - #12 with actuarial motor level levers (30 Oct 2026)

After the motor round, Wendy judged the motor level too low and asked for actuarially sound, non-probing ways to raise it.
Diagnostics (details in [improvement_round_week2.md](optionB/improvement_round_week2.md), "Motor level"): the spread of #12
motor is already calibrated in both markets (best power k on pred^k is about 1.0), so the shape is kept and only the level moves.
Script `week2/R/29_motor_level.R` (outputs `week2/output/29_motor_level/{factors,results,burn_by_peril}.csv`, MLV_* scores).

- Data and model: #12 exactly (x20_tblend motor, rt_var_b8 buildings / contents); motor rows of the 2025 file multiplied by:
- **BI severity x 1.1159** (L1, L3):
  - trend: the chosen BI severity trend was 0 because the developed estimate (-8.8%) uses capped / closed severities of
    immature 2023-24 loss years. On mature developed loss years 2021-23 uncapped BI severity rises about +4% a year
    (21.4k, 22.2k, 23.3k); emerging +4.9%. Selected +4.5%: x1.045 to 2025, plus x1.0267 because the 2023 emerging BI
    claims (266 of 449) were brought to the 2024 base at 0 trend;
  - development: late-reported BI claims are larger (developed: reported within 30 days 19.6k, after 2 years 28.0k);
    mature-year severity development factors at the emerging claim ages: 2023 1.007, 2024 1.031, claim-weighted 1.0168;
  - large-loss: developed capped-excess load 1.048 / emerging 1.024 = 1.0230 (benchmark large-loss load as the
    complement of credibility for a thin new book).
- **New-business rows x 1.0611** (L2, L3): 77% of 2025 motor exposure is new business (2023-24: 6-9%); the applied NB load
  is the credibility-weighted 1.165 (z 0.70); this uses the full emerging NB relative A/E 1.237.
- Not applied: spread stretch (not supported), IBNER / case-reserve adequacy (not measurable from one snapshot; 58% of
  emerging BI claims open, paid / incurred 0.49 vs 0.69 developed), BI frequency trend (+7.8% emerging, floored at 0).
- 2025 motor burn by peril (`burn_by_peril.csv`): BI 232.5 -> 259.4 (L1) / 272.7 (L3); TPP 205.2 -> 215.8 (L2, L3);
  OD 107.6 -> 113.1; theft 50.1 -> 52.7; glass 29.7 unchanged.
- Risk: if the 2025 actuals are reported at a snapshot rather than ultimate, the development part (and the trend-to-base
  part) overshoots; the 2024 fold (reported actuals) prefers the #12 level (A/E 1.012).

## Motor round candidates C1-C10 - #12 with an improved motor ranking (30 Oct 2026), submitted #28-30, rejected

Wendy chose the pre-probing model with the Week 1 re-tune (#12 `line_ensemble`, public 0.16690) and asked to improve motor
(42% of exposure) without probing. Full experiment table: [improvement_round_week2.md](optionB/improvement_round_week2.md)
("Motor round"); results `week2/output/28_motor_round/results.csv`.

Scripts, in run order:
1. `week2/run/run_motor_round.ps1 -Tag <t> -Env @{...}`: `05_developed_baseline.R` (motor only: `LINES_ONLY=motor`,
   `SKIP_VALID=1`, plus the variant switch) -> property rows copied from the main baseline -> x20_tblend chain
   `07` (`TREND_FLOOR_FREQ=motor`, `TREND_MODE=blend_freq`, `BASE_TAG=<t>`) -> `14` (fin_sevem blend 0.5 on OD / glass / BI /
   contents EoW) -> `08` -> `09` -> `13`. Chain tag `mr_<t>`. Control `m0ctl` reproduced x20_tblend exactly (max difference 0).
2. `week2/R/28_motor_round.R` (`VARIANTS=...`, `BUILD=...`): combines the motor predictions, relevels each motor peril to
   x20's 2024 (validation) and 2025 totals, scores with `score_w2.R` (buildings / contents = `rt_var_b8_chosen`, as #12),
   runs the policy bootstrap and writes the files (#12 with motor rows replaced).

- Data and everything outside motor: as #12 (emerging 2023-24, developed 2021-24; buildings and contents unchanged).
- Motor ideas: M1 geometric blend with the re-tuned (b8) motor; M2 BI frequency x (TPP frequency / BI frequency)^w;
  M5 frequency monotone -1 on years_licensed and years_at_address (every motor peril using them); M6 developed training
  weights 2021-24 = 0.7 / 0.8 / 0.9 / 1.0 (frequency and severity).
- Level: motor 2025 burn 625.06 per exposure-year in every candidate (as #12); per-peril totals equal x20's.
- 2025 checks: 209,063 rows, ids = sample submission, no NA / negative / duplicates; total vs #12 = 1.000000. Motor row
  ratio vs #12, p1-p99: C1 0.87-1.14, C6 0.87-1.18, C8 0.93-1.09, C9 0.92-1.06, C10 0.98-1.02.
- Validation: ALL cost D2 0.1193 (#12) -> 0.1199 (C1), reported basis 0.1147 -> 0.1150; buildings / contents unchanged.
- Tested and not used: M3 lower large-loss cap (BI 0.99, theft 0.995): -0.00003; M4 15 bags: -0.00002; stronger year weights
  (0.5 / 0.65 / 0.8 / 1) weaker than M6; joint M5+M6 refit alone (+0.00040) weaker than M5 alone.
- Caveat: the gains (+0.0003 to +0.0014 motor, +0.0002 to +0.0006 ALL) are of the order of public-board noise; the weights
  were chosen on the same 2024 fold, so expect part of the local gain to shrink.

## Submissions 14-27 - 2025 level calibration from public probes, best public 0.17445 (#27 `lvl_half`)

Scripts:
- `TAG=<tag> MULT="<line>=<x>,<line>/<peril>=<x>" week2/R/25_level_calibration.R` writes each file.
- `SEGS=... week2/R/26_probe_solver.R` estimates the levels.
- The probe registry is `week2/output/25_level/probes.csv`; burn tables are in `week2/output/25_level/<tag>_burn.csv`.

Base model and data:
- Model: unchanged #12 (`line_ensemble`): `x20_tblend` motor rows plus `rt_var_b8_floor_corrected` buildings/contents rows, with every peril prediction multiplied by a level factor.
- Data: emerging 2023-24, developed 2021-24, as #12.

Why levels:
- Past public scores show shape changes sit within noise (about ±0.002) and do not transfer from the 2024 fold.
- Public and private are random parts of the same 2025 book, so the 2025 cost level carries over.
- The 2024 fold cannot judge the 2025 level, so the 2024-fold validation D2 is unchanged at 0.1193.

How the levels are solved:
- Tweedie p = 1.5. If the expected row cost is the sum over segments of θ_s times the base μ_s, then each probe's public change is linear in θ given one scale constant K (= public share / public null deviance).
- `26_probe_solver.R` fits θ and K across all level probes and recommends multipliers equal to θ.
- With #14-17 it reproduces every probe exactly: K = 3.69e-8.
- Line levels: motor 1.136, buildings 1.361, contents 0.915. Best line-level public is 0.17193; #17 gets 0.17192.

Fire probe (#18):
- Fire level 1.24 vs 1.41 for the rest of buildings. The buildings uplift is not a fire effect.

Local checks that support uniform line factors:
- Peril-level and NB/renewal splits fitted in-sample flip sign between 2023 and 2024 (motor NB 1.91 vs 0.77).
- Region levels fitted on 2023 lose on the 2024 fold at every credibility weight: buildings -0.0006 to -0.022.
- Spread test μ' = c·μ^β gives β within 1 SD of 1.00.

Overfitting check: calibrate on a random 69k-row sample (public size) and score on an independent 139k sample, using emerging in-sample years.
- Line levels:
  - Year with a real level shift (2023): private gain +0.009 (10-90%: +0.004 / +0.014).
  - Year without a shift (2024): -0.0006 (-0.0024 / +0.0009).
  - Shrinking levels 25% toward 1 (θ^0.75) keeps the shift gain (+0.009) and cuts the no-shift cost to -0.0002.
- Peril levels: same mean as line levels (2023 +0.0089, 2024 0.0000), wider spread.

2025 burn per unit of exposure (#17):
- Motor: 712.6 (#12: 625.1)
- Buildings: 482.1 (357.1)
- Contents: 101.7 (109.4)

Peril probes (#19-26, 29 Oct):
- Each probe is #17 with one peril moved: buildings flood, storm, EoW, subsidence+AD x1.6; motor BI, TPP, OD x1.3; contents theft x1.3.
- Public scores: 0.17194 / 0.17188 / 0.17178 / 0.17190 / **0.17203** / 0.17200 / 0.17147 / 0.17134.
- Joint solve with all 13 probes (`SEGS` = 11 segments): K 3.70e-8, every probe fitted exactly.

| Segment | θ (public A/E vs #12) | SD from 5-decimal rounding |
|---|---|---|
| motor BI | 1.741 | 0.029 |
| motor TPP | 1.261 | 0.033 |
| motor OD | -0.040 | 0.038 |
| motor rest (glass/hail, theft) | 0.658 | 0.053 |
| buildings fire | 1.829 | 0.030 |
| buildings flood | 1.497 | 0.003 |
| buildings storm | 1.583 | 0.035 |
| buildings EoW | 0.222 | 0.042 |
| buildings subsidence+AD | 1.628 | 0.043 |
| contents theft | 1.254 | 0.003 |
| contents rest | 0.527 | 0.004 |

How to read the peril θ:
- Rounding does not explain the extreme values.
- Perils share rows (every motor row carries BI, TPP, OD, ...). The solver therefore separates them through the differences in public actuals across rows, which are driven by a few large claims.
- The θ are an exact description of the public 33% but not plausible true 2025 levels (OD cannot be negative). Using them in full is fitting public noise.

Expected public for candidate files under the fitted θ (`EVAL` in `26_probe_solver.R`):

| Candidate | Expected public | Total vs #12 |
|---|---|---|
| #17 `lvl_cal1` | 0.17192 | 1.170 |
| full θ (OD floored at 0.01) | 0.17539 | 1.176 |
| half-way geometric between #17 and θ, bounded [0.6, 1.8] | 0.17445 | 1.154 |
| conservative (direction only, bounded 0.8-1.6) | 0.17368 | 1.178 |

Submission 27 (`lvl_half`, final candidate, 29 Oct):
- Halfway row above: `C = clamp(sqrt(C_cal1 x θ), 0.6, 1.8)`. Built with `week2/run/build_final_halfway.ps1`. Full method: [final_model_method_week2.md](final_model_method_week2.md).
- Public **0.17445**, exactly as predicted before submission (an out-of-sample check of the probe model).
- Added to `probes.csv` as the 14th probe. Re-solve: K 3.698e-8, all 14 fitted exactly, θ unchanged to the 3rd decimal.
- How close can the guardrails get to 0.175? Expected public, with C = C_cal1^(1-a) θ^a bounded [0.6, 1.8]:

  | a | 0.5 (final) | 0.6 | 0.7 | 0.8 |
  |---|---|---|---|---|
  | Expected public | 0.17445 | 0.17462 | 0.17469 | 0.17463 |

  - Full θ with OD and EoW kept at the 0.6 bound: 0.17420. Bounding at 0.3 instead: 0.17507.
  - Only near-raw θ (OD 0, EoW 0.22) reaches 0.17539.
  - So 0.175 is reachable only by cutting motor own damage and buildings EoW by 70% or more on public evidence alone, which the guardrails rule out.
- Guardrails: section 9.6 of [final_model_method_week2.md](final_model_method_week2.md).

## Submission 10 - Option B nb1b_devonly (x20_tblend + developed new-business load), public 0.16447

Scripts: `week2/run/run_nb_win.ps1 -Tag nb1b_devonly -Env @{NB_K="Inf"; NB_PRIOR="dev"}` (= `22_nb_backtest.R` on 2024 ->
`08_loadings_2025.R` with ADJ_TAG=x20nb -> `09_validate_compare.R` -> `13_compare_runs.R` -> `21_x21_scorecard.R`), where
x20nb = exact x20_tblend reproduction of steps 7 + 14 (max difference 0) -> `SOURCE_TAG=nb1b_devonly week2/R/15_candidate_from_tag.R`.

- Data and model: identical to #8 (same baseline, step 7 fits, severity blend, trend), except the step 8 new-business load.
- Change: the 2025 load on new-business rows was the emerging residual NB A/E credibility-weighted to 1 (D020: motor 1.165,
  buildings 0.966, contents 1.046). It is now the developed baseline's own out-of-fold residual NB A/E on developed actuals
  (2023-24 folds, `nb_load_fns.R`): motor 0.998, buildings 1.051, contents 0.993. Reason: a backtest of the D020 load
  (fitted on 2023, applied to 2024) lost -0.0078 on the 2025-mix proxy; the emerging NB A/E is unstable year to year.
- Validation (2024 fold, load fitted on 2023 only): ALL cost D2 0.1191 vs 0.1189 (#8 scorecard); 2025-mix proxy +0.00103
  (2 SE 0.0018), as-is +0.00016. Within noise. Scorecard OPTB_NB1B_DEVONLY; per-peril deltas in
  `week2/output/scores/x21/nb1b_devonly_vs_x20_tblend.md`.
- 2025 checks: 209,063 rows, ids match the sample, no NA / negative / duplicates. Burn per unit exposure: motor 553.3
  (#8 625.1), buildings 379.1 (355.5), contents 102.3 (106.1). Total vs #8 file -6.6%; row ratio vs #8 p1 / p50 / p99 =
  0.857 / 0.959 / 1.088.
- Tested but not used (NB round): credibility to developed, January-start load, per-peril loads, seasonal shape,
  domain-classifier weights, pooled NB model. See `docs/optionB/improvement_round_week2.md` (NB round).
- What the public score tells us: this is a level test on the 77% new-business 2025 book, not a shape test. A gain says the
  emerging NB uplift (motor +16%) was overstated; a loss says motor new business really is worse than renewals in 2025.

## Submission 11 - Week 1 re-tuned shared-field baseline, public 0.16395

Scripts: `week2/week1_retune/R/r05_retune_baseline.R` (`b8_combo_f`, 5 bags; depth -1, location proxy and credit proxy) ->
`week2/R/06_score_emerging_baseline.R` -> `07_emerging_adjust.R` -> `14_blend_severity.R` -> `08_loadings_2025.R` ->
`09_validate_compare.R` -> `21_x21_scorecard.R` -> `week2/R/15_candidate_from_tag.R`.

- Model: developed 2021-24 baseline re-tuned only within `week2/week1_retune/` on fields available in emerging; emerging
  2023-24 credibility adjustments used the existing Option B settings (peril level credibility, ridge factor shrinkage,
  selected emerging severity blend and new-business loads). No files in `week1/` were changed.
- Validation: ALL cost D2 0.1197; motor 0.0454, buildings 0.1038, contents 0.0616. The standard component/peril
  comparison is `week2/output/scores/x21/rt_var_b8_chosen_vs_rt_b8_combo_f.csv` and the recorded model is in
  `week2/output/scores/model_scores.csv`.
- 2025 checks: 209,063 rows, no missing or negative predictions. Burn per exposure: motor 601.4, buildings 354.3,
  contents 108.7. Compared with #8, the candidate was motor 0.962x, buildings 0.997x and contents 1.025x.
- Public result: **0.16395**, down 0.00267 from #8 (0.16662). Decision: reject and keep `x20_tblend`.
- Diagnosis: the candidate's step 8 report shows motor frequency trends of -5.0% for own damage and -3.4% for
  third-party property. #8 explicitly floors motor frequency trend at 0%. That reduced the largest line by 3.8% overall;
  it was a pipeline-setting error in the candidate build, not evidence against the re-tuned shared-field baseline.
- Tested but not used: default selected trend and line-level severity trend produced byte-identical predictions to the
  current-trend variant. A corrected re-run with `TREND_FLOOR_FREQ=motor` is required before judging the re-tuned baseline.

## Submission 12 - Line-specific ensemble, public 0.16690

Scripts: `week2/run/score_line_ensemble.R` assembled the validated 2024 frequency/severity parts and
`week2/run/make_line_ensembles.R` built the 2025 file. The motor component is `x20_tblend`; buildings and contents use the
corrected re-tuned shared-field model with the motor frequency floor restored.

- Validation: ALL cost D2 0.1193; motor 0.0456, buildings 0.1038, contents 0.0616. Full frequency / severity / cost
  scorecard is recorded as `OPTB_LINE_ENSEMBLE` in `week2/output/scores/model_scores.csv`.
- 2025 checks: 209,063 rows, no missing or negative predictions. MD5 `bbd5ca2dbe6327161d93dad5dc36edbd`.
- Public result: **0.16690**, +0.00028 versus #8 `x20_tblend`.
- Two alternatives were also written for local testing: buildings-only re-tune and contents-only re-tune. The selected
  version keeps both property-line changes because the public score supports the combined line-specific choice.

## Submission 13 - Maximum two-factor variant, public 0.16495

Scripts: `week2/run/run_l1_variants.ps1 -Tag maxf2 -L1 0 -MaxFactors 2` -> steps 07 / 14 / 08 / 09 / 13 / 21 / 15.

- Change: limited the emerging greedy factor selection to two factors per peril as a simpler regularization method.
- Validation: ALL cost D2 0.1186, below `x20_tblend` at 0.1189. Scorecard: `OPTB_MAXF2` in
  `week2/output/scores/model_scores.csv`.
- Public result: **0.16495**, −0.00195 versus #8. Decision: reject.
- Related failed tests: lasso-like soft threshold `l1f02` (local 0.1183) and `l1f05` (0.1174), plus the shared-field
  re-tune candidates. Full record: `docs/optionB/improvement_round_week2.md`, section "Regularization and re-tune failures".

## Submission 9 - Option B x21c (x20_tblend + credit_tier + n_lines), public 0.16473

Scripts: `week2/R/03c_emerging_extra2.R` -> `week2/run/run_x21_win.ps1 -Tag x21c -Env @{X_NEW="credit_tier,n_lines"}`
(= `07_emerging_adjust.R` RUN_TAG=x21c_core -> `14_blend_severity.R` (with fin_sevem, BLEND_W 0.5, relevelled, motor OD /
glass / BI, contents EoW) -> `08_loadings_2025.R` -> `09_validate_compare.R`; env `TREND_FLOOR_FREQ=motor TREND_MODE=blend_freq
DT_THREADS=1`) -> `SOURCE_TAG=x21c week2/R/15_candidate_from_tag.R`.

- Data: emerging 2023-24 (fit), developed 2021-24 (step 5 baseline `baseline`, unchanged from #8); same cleaning as #8.
- Model: identical to #8 except step 7, where two new emerging-only fields (built by `03c`, never seen by the developed
  baseline) are offered to the greedy per-peril factor selection (ridge lambda 30, kept if 2024 deviance gain > 1):
  - `credit_tier` = suffix of `marketing_segment` (affluent / mainstream / budget; matches developed credit_band A-B / C / D-E).
    Picked for frequency on motor TPP, motor theft, contents theft, contents accidental damage.
  - `n_lines` = number of lines (1-3) the customer holds in the policy year. Picked for frequency on motor BI, motor theft,
    buildings escape of water. No severity factor changed; credibility, trend, cap, loadings, blend all as #8.
- Validation (2024 fold, developed basis): ALL cost D2 0.1188 vs 0.1181 (#8); motor 0.0449 vs 0.0440, buildings 0.1023 vs
  0.1022, contents 0.0636 vs 0.0623. Constant-mean proxy vs #8: 2025 mix +0.00222 (SE 0.00131, better in 96.5% of bootstrap
  draws), as-is +0.00066 (SE 0.00045, 92.5%). Within 2 SE; factor selection uses the 2024 fold, so slightly optimistic.
  Scorecard OPTB_X21C in `week2/output/scores/model_scores.csv`; per-peril deltas in `week2/output/scores/x21/x21c_vs_x20_tblend.csv`.
- 2025 checks: 209,063 rows, no NA / negative / duplicates (`week2/output/15_candidate/x21c_checks.csv`). Burn per unit
  exposure: motor 625.6 (#8 625.1), buildings 356.5 (355.5), contents 106.0 (106.1). Total vs #8 file +0.12%; row ratio
  vs #8 p1-p99: motor 0.90-1.13, buildings 0.94-1.05, contents 0.90-1.20; correlation with #8 0.995-0.9997.
- Tested but not used (X21 round): region, motor value/(age+1) bands, property age bands, missing-field count, vehicle_age
  missing flag, and frequency-only variants. See `docs/optionB/improvement_round_week2.md` (X21).
- **Public result: 0.16473, -0.00189 vs #8 (0.16662).** Expected from the 2024 fold: +0.0007 with SD 0.0004-0.0006 on a
  public split of 20-50% of the test rows (bootstrap of the 2024 rows at public size, 300 draws; none of them reached -0.0019).
  Row sampling noise alone does not explain the drop: the credit_tier / n_lines relativities learned on 2023-24 (mostly
  renewals, factors picked on the 2024 fold) do not hold on the 2025 book (76% broker take-on new business). Public and
  private are random splits of the same 2025 rows, so private is expected to be worse than #8 as well. Decision: x21c
  reverted; #8 (x20_tblend) stays the current best and the preferred final selection.

## Shared pipeline (submissions 1 and 2)

1. **Cleaning** - `week2/R/1_checks_w2.R`, `week2/R/2_clean_w2.R`. The emerging and developed raw files are cleaned with the
   same rules (R1-R9, [cleaning_decisions_w2.md](cleaning_decisions_w2.md)). The developed folder is the Part 1 (week 1)
   data, byte-identical to `data/week_1/raw data`, read from `data/week_2/raw data/developed`.
2. **IBNR** - `week2/R/3_ibnr_w2.R`. Reporting-lag curves per line x peril; the backtest preferred the developed-market
   curve (k = Inf), so the Part 1 reporting pattern is used. Labels are ultimate claim counts = reported / reported share.
3. **What changed vs Part 1** - `week2/R/4_drift_w2.R` (analysis only). The shape of most rating factors transfers; the
   level does not (motor frequency x1.12-1.41, severity x0.51-0.65; storm frequency x1.42; severity lower for every peril).
   See [findings_w2.md](findings_w2.md).
4. **Frequency x severity per peril**, summed to the row. Severity is capped at the developed p99.5 x the emerging/developed
   severity ratio, and the cap loading comes from developed claims. Features exclude written_premium, discount,
   premium index, customer service contacts, compulsory excess and noise fields; voluntary excess is kept.

## Submission 1 - transfer model with credibility (S6), public 0.14860

Scripts: `week2/R/5_models_w2.R` -> `week2/R/6_blend_w2.R` (config `W2_CFG = "200,100,avg,none"`).

- **Developed model:** LightGBM per peril (Poisson frequency, gamma severity), fitted on developed 2021-24 using only the
  features both markets share (no weather, region or make_model).
- **Emerging level:** each peril's developed prediction x one emerging level factor (frequency and severity), fitted on
  emerging 2023-24.
- **Model average:** 50/50 of "level only" (F2/S2) and "level + small emerging LightGBM boost" (F3/S3). The boost uses
  all emerging features.
- **Credibility:** each peril's emerging level shrunk towards its line's pooled level, z = n / (n + k), with k_freq 200 and
  k_sev 100. This damps one-year spikes such as buildings fire in 2023.
- **No trend.** The new-business relativity is carried over from the developed model.
- **2025 burn per unit of exposure:** motor 532, buildings 396, contents 89.

## Submission 2 - three-model blend, public 0.15387

Scripts: `week2/R/5b_joint_w2.R` (`W2_FOLDS=valid`, then `final`) -> `week2/R/6b_blend_joint_w2.R`.
Validation evidence: `week2/output/5b_joint/validation_report.md`.

prediction = (S6 + J3c + B4c) / 3, where:
- **S6** is submission 1's prediction, unchanged.
- **J3c** is a joint XGBoost per peril.
  - Trained on developed (2021-24) and emerging (2023-24) rows stacked, with a `market_e` flag and all features
    (weather, weather averages, region, make_model, gender), so the trees learn which developed patterns carry over.
  - Emerging rows are weighted x5.
  - Settings copied from week 1's C5: per-peril max_depth and min_child_weight from
    `week1/final_week1_R_Script/inputs/assumptions_wendy07_final2.xlsx`, eta 0.05, subsample / colsample 0.8, lambda 5,
    early stopping 50, 3 bags.
  - Balanced to the emerging training total, then given S6's credibility adjustment.
- **B4c** is the S6 transfer model with a stronger emerging LightGBM boost (15 leaves, minimum leaf size 150,
  learning rate 0.05), plus the same credibility adjustment.
- **Validation:** ALL D2 0.1120 vs 0.1106 for S6 (paired policy bootstrap gain +0.0014 +/- 0.0011, better in 91% of
  draws). Each component alone scores below S6; the gain comes from averaging.
- **2025 burn per unit of exposure:** motor 530, buildings 394, contents 91. The change from S6 is mostly in the ranking
  of policies (Spearman correlation with S6: J3c 0.84-0.96, B4c 0.96-1.00).

Tested but not used (same validation): joint LightGBM 0.099; joint with emerging x5 weight 0.091; new-business uplift
x0.8-1.2 (flat, best at x1.0).

## Model scorecards (local validation: fit 2023, score emerging 2024)

Every model is scored with `week2/R/score_w2.R`, following [output_model_instruction.md](../instructions/output_model_instruction.md):
D2 for frequency (Poisson), severity (gamma) and cost (Tweedie 1.5) separately, by peril, by line and for ALL.
Full scorecards, including the by-peril tables and A/E: `week2/output/scores/scorecards.md`. Machine-readable version:
`week2/output/scores/model_scores.csv`. Produced by `week2/R/7_score_models_w2.R`.

**Comparison: D2 by component and line**

| model | freq ALL | freq motor | freq bldg | freq cont | sev ALL | sev motor | sev bldg | sev cont | cost ALL | cost motor | cost bldg | cost cont |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| BURN (reference) | 0.0972 | -0.0001 | -0.0000 | -0.0000 | 0.3818 | 0.2884 | 0.5082 | 0.3529 | 0.0499 | -0.0000 | -0.0251 | -0.0003 |
| S6 (submission 1) | 0.1534 | 0.0760 | 0.0377 | 0.0285 | 0.3900 | 0.2940 | 0.5199 | 0.3816 | 0.1106 | 0.0351 | 0.0955 | 0.0514 |
| J3c | 0.1582 | 0.0818 | 0.0468 | 0.0285 | 0.3882 | 0.2917 | 0.5178 | 0.3819 | 0.1087 | 0.0374 | 0.0853 | 0.0509 |
| B4c | 0.1531 | 0.0756 | 0.0386 | 0.0270 | 0.3873 | 0.2901 | 0.5199 | 0.3816 | 0.1104 | 0.0356 | 0.0938 | 0.0519 |
| BLEND3 (submission 2) | 0.1569 | 0.0798 | 0.0440 | 0.0306 | 0.3908 | 0.2940 | 0.5216 | 0.3870 | 0.1120 | 0.0373 | 0.0942 | 0.0553 |
| OPTB_X20_TBLEND (submission 8, public 0.16662) | 0.1599 | 0.0839 | 0.0468 | 0.0308 | 0.3968 | 0.3018 | 0.5191 | 0.3971 | 0.1189 | 0.0446 | 0.1021 | 0.0622 |
| OPTB_X21C (submission 9, public 0.16473) | 0.1605 | 0.0845 | 0.0469 | 0.0323 | 0.3968 | 0.3018 | 0.5191 | 0.3971 | 0.1196 | 0.0455 | 0.1021 | 0.0635 |
| OPTB_NB1B_DEVONLY (submission 10, public pending) | 0.1600 | 0.0839 | 0.0472 | 0.0312 | 0.3968 | 0.3018 | 0.5191 | 0.3971 | 0.1191 | 0.0445 | 0.1024 | 0.0627 |
| OPTB_VAR_B8_CHOSEN (submission 11, public 0.16395) | 0.1608 | 0.0850 | 0.0468 | 0.0318 | 0.3968 | 0.3018 | 0.5191 | 0.3971 | 0.1197 | 0.0454 | 0.1038 | 0.0616 |
| OPTB_LINE_ENSEMBLE (submission 12, public 0.16690) | 0.1600 | 0.0839 | 0.0477 | 0.0305 | 0.3968 | 0.3018 | 0.5198 | 0.3969 | 0.1193 | 0.0446 | 0.1038 | 0.0616 |
| MR_C_M5MONO_W50_B30 (C1, pending) | 0.1601 | 0.0840 | 0.0477 | 0.0305 | 0.3968 | 0.3017 | 0.5198 | 0.3969 | 0.1199 | 0.0459 | 0.1038 | 0.0616 |
| MR_C_M5M6AVG_W50_B30 (C2, pending) | 0.1601 | 0.0841 | 0.0477 | 0.0305 | 0.3968 | 0.3017 | 0.5198 | 0.3969 | 0.1199 | 0.0457 | 0.1038 | 0.0616 |
| MR_C_M56_W50_B30 (C3, pending) | 0.1600 | 0.0840 | 0.0477 | 0.0305 | 0.3968 | 0.3017 | 0.5198 | 0.3969 | 0.1199 | 0.0458 | 0.1038 | 0.0616 |
| MR_C_M5MONO_W75_B30 (C4, pending) | 0.1601 | 0.0840 | 0.0477 | 0.0305 | 0.3968 | 0.3016 | 0.5198 | 0.3969 | 0.1199 | 0.0457 | 0.1038 | 0.0616 |
| MR_C_M6YW_W50_B30 (C5, pending) | 0.1601 | 0.0841 | 0.0477 | 0.0305 | 0.3968 | 0.3017 | 0.5198 | 0.3969 | 0.1198 | 0.0455 | 0.1038 | 0.0616 |
| MR_M1_W100 (C6, pending) | 0.1600 | 0.0840 | 0.0477 | 0.0305 | 0.3967 | 0.3016 | 0.5198 | 0.3969 | 0.1198 | 0.0456 | 0.1038 | 0.0616 |
| MR_M_M5MONO (C7, pending) | 0.1598 | 0.0837 | 0.0477 | 0.0305 | 0.3968 | 0.3018 | 0.5198 | 0.3969 | 0.1197 | 0.0453 | 0.1038 | 0.0616 |
| MR_M1_W50 (C8, pending) | 0.1601 | 0.0842 | 0.0477 | 0.0305 | 0.3968 | 0.3017 | 0.5198 | 0.3969 | 0.1196 | 0.0452 | 0.1038 | 0.0616 |
| MR_M2_W30 (C9, pending) | 0.1599 | 0.0838 | 0.0477 | 0.0305 | 0.3968 | 0.3018 | 0.5198 | 0.3969 | 0.1195 | 0.0449 | 0.1038 | 0.0616 |
| MR_M_M6YW (C10, pending) | 0.1600 | 0.0840 | 0.0477 | 0.0305 | 0.3969 | 0.3018 | 0.5198 | 0.3969 | 0.1195 | 0.0449 | 0.1038 | 0.0616 |
| MLV_L_BI (L1 = #33, public 0.16793) | 0.1600 | 0.0839 | 0.0477 | 0.0305 | 0.3964 | 0.3012 | 0.5198 | 0.3969 | 0.1191 | 0.0441 | 0.1038 | 0.0616 |
| MLV_L_NB (L2 = #32, public 0.16769) | 0.1600 | 0.0839 | 0.0477 | 0.0305 | 0.3969 | 0.3018 | 0.5198 | 0.3969 | 0.1193 | 0.0444 | 0.1038 | 0.0616 |
| MLV_L_FULL (L3 = #31, FINAL, public 0.16840) | 0.1600 | 0.0839 | 0.0477 | 0.0305 | 0.3965 | 0.3012 | 0.5198 | 0.3969 | 0.1190 | 0.0439 | 0.1038 | 0.0616 |

Motor round (30 Oct 2026): per-peril tables for every MR_* model are in `week2/output/scores/model_scores.csv`; the summary with
bootstrap is `week2/output/28_motor_round/results.csv`.

X21 round (27 Oct 2026): every new field was scored with the same scorecard; per-peril frequency / severity / cost deltas
for each step are in `docs/optionB/improvement_round_week2.md` (X21) and `week2/output/scores/x21/`.

How to read it:
- The ALL and line-level severity D2 values are high mainly because they reward getting the differences *between perils* right
  (fire claims cost far more than glass claims). Compare models on the peril-level severity D2 to judge the within-peril ranking.
- ALL frequency and cost D2 are likewise helped by the line/peril mix. BURN (one flat rate per peril) gets 0.097 / 0.050 from
  that alone.
- J3c has the best frequency D2 but the weakest buildings cost D2 (0.085). The blend keeps J3c's frequency gain and S6's buildings level.
- BLEND3 severity is defined as blended cost / blended frequency.

**Submission 1 - S6, D2 by peril**

| line | peril | D2 freq | D2 sev | D2 cost | A/E freq | A/E sev | A/E cost |
|---|---|---|---|---|---|---|---|
| motor | bodily_injury | 0.0284 | -0.0030 | 0.0146 | 1.089 | 0.910 | 0.993 |
| motor | glass_hail | 0.0869 | -0.0071 | 0.1484 | 1.212 | 1.124 | 1.364 |
| motor | own_damage | 0.1445 | 0.0081 | 0.1808 | 0.937 | 1.139 | 1.081 |
| motor | theft | 0.0392 | -0.0007 | 0.0920 | 1.026 | 1.202 | 1.247 |
| motor | third_party_prop | 0.0581 | 0.0008 | 0.0417 | 0.989 | 1.025 | 1.010 |
| buildings | accidental_damage | 0.0501 | -0.0094 | 0.0833 | 0.900 | 0.911 | 0.819 |
| buildings | escape_of_water | 0.0058 | 0.0212 | 0.0090 | 0.781 | 0.857 | 0.679 |
| buildings | fire | 0.0006 | 0.1783 | 0.0486 | 0.764 | 1.020 | 0.796 |
| buildings | flood | 0.3211 | -0.0176 | 0.4901 | 0.786 | 1.075 | 0.832 |
| buildings | storm | 0.0277 | 0.0235 | 0.0422 | 1.337 | 1.019 | 1.370 |
| buildings | subsidence | 0.0381 | -0.3478 | 0.0191 | 1.064 | 0.517 | 0.578 |
| contents | accidental_damage | 0.1118 | -0.0128 | 0.1617 | 0.925 | 0.948 | 0.885 |
| contents | escape_of_water | 0.0014 | 0.1390 | 0.0223 | 0.815 | 0.909 | 0.722 |
| contents | flood | 0.2128 | 0.0508 | 0.3294 | 0.925 | 1.258 | 1.142 |
| contents | theft | 0.0221 | 0.0507 | 0.0316 | 1.200 | 1.044 | 1.248 |

**Submission 2 - BLEND3, D2 by peril**

| line | peril | D2 freq | D2 sev | D2 cost | A/E freq | A/E sev | A/E cost |
|---|---|---|---|---|---|---|---|
| motor | bodily_injury | 0.0321 | -0.0007 | 0.0166 | 1.080 | 0.915 | 0.987 |
| motor | glass_hail | 0.0945 | -0.0034 | 0.1547 | 1.175 | 1.125 | 1.325 |
| motor | own_damage | 0.1474 | 0.0059 | 0.1832 | 0.934 | 1.140 | 1.075 |
| motor | theft | 0.0411 | -0.0020 | 0.0934 | 1.041 | 1.189 | 1.259 |
| motor | third_party_prop | 0.0604 | 0.0021 | 0.0443 | 0.983 | 1.026 | 1.004 |
| buildings | accidental_damage | 0.0544 | -0.0087 | 0.0839 | 0.929 | 0.914 | 0.847 |
| buildings | escape_of_water | 0.0052 | 0.0283 | 0.0094 | 0.800 | 0.886 | 0.711 |
| buildings | fire | -0.0046 | 0.1497 | 0.0413 | 0.750 | 0.980 | 0.753 |
| buildings | flood | 0.3203 | 0.0026 | 0.4886 | 0.802 | 1.076 | 0.849 |
| buildings | storm | 0.0448 | 0.0277 | 0.0532 | 1.309 | 1.045 | 1.352 |
| buildings | subsidence | 0.0556 | -0.3856 | 0.0383 | 1.013 | 0.508 | 0.546 |
| contents | accidental_damage | 0.1090 | -0.0109 | 0.1592 | 0.977 | 0.947 | 0.934 |
| contents | escape_of_water | 0.0111 | 0.1502 | 0.0332 | 0.818 | 0.905 | 0.722 |
| contents | flood | 0.2171 | 0.0758 | 0.3331 | 0.978 | 1.272 | 1.226 |
| contents | theft | 0.0244 | 0.0604 | 0.0368 | 1.212 | 1.046 | 1.258 |

What the scorecards point to: the A/E columns show the 2024 *level* is off by more than the ranking for several perils.
- Over-predicted (A/E well below 1): buildings subsidence severity (A/E 0.51-0.52) and escape of water (cost A/E about 0.7).
- Under-predicted (A/E above 1): storm frequency (A/E 1.31-1.34) and motor glass_hail (cost A/E about 1.33-1.36).
2024 is a single year, so some of this is noise; it is a lead for the "overall level" open question below.

## Using the instructions as skills

The two instruction files can be called as skills by anyone working in this repo (Claude Code or GitHub Copilot):

| Skill | Call it with | Canonical instructions | What it does |
|---|---|---|---|
| week2-submission-log | `/week2-submission-log` | [submission_log.md](../instructions/submission_log.md) | Lists every place a week 2 submission must be recorded and what to include |
| week2-model-scorecard | `/week2-model-scorecard` | [output_model_instruction.md](../instructions/output_model_instruction.md) | Scores a model (frequency / severity / cost D2 by peril, line and ALL) with `week2/R/score_w2.R` and records it here |

The skill wrappers are in `.claude/skills/<name>/SKILL.md` and only point to the files in `week2/instructions/`, so
edit the instruction files, not the wrappers. Every new model must have a scorecard row in the comparison table above
before it is considered for submission.

## Open questions

- **Broker take-on:** 76% of 2025 rows are new business, mostly January full-year policies. The developed market shows
  the same new-business uplift for January and mid-year starts, but no data shows how a transferred broker book behaves.
- **Leaderboard gap:** the top is about 0.17. The model-shape experiments gained little on validation, so the gap is
  more likely in the overall level or in large-claim handling.
