# Week 2 step log (emerging market, Option B)

One section per step. The `auto` blocks are written by the scripts (inputs and outputs with MD5,
run time, key numbers); the decision text around them is written by hand.

## Step rt-b0_ref: Retune run b0_ref

<!-- auto:rt-b0_ref start -->
**Script** `week2/R/r05_retune_baseline_b0_ref.R` · **run** 2026-10-28 09:29:53 SGT · **run time** 4.9 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b0_ref.xlsx | 120,239 | 18047d07fe9d170ea3c5e0fb6432f4a4 |
| week2/week1_retune/output/b0_ref/row_preds.parquet | 85,599,559 | 40047d2f285e97281bc609e5c05cdb00 |
| week2/week1_retune/output/b0_ref/line_scores.csv | 1,019 | 828f741325e142e67c257094c9abb3d7 |
| week2/week1_retune/output/b0_ref/peril_scores.csv | 4,436 | f1fd5a088db15d20b8e0e5886cdcbe28 |
| week2/week1_retune/output/b0_ref/diagnostics_validation.csv | 4,507 | 1e7f16c3460b1ab58f8171dc729a44f6 |
| week2/week1_retune/output/b0_ref/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/week1_retune/output/b0_ref/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b0_ref/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b0_ref/model_card.md | 3,860 | b20f0dd97ee801f8c70fc002885f50d5 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0353, buildings 0.0723, contents 0.0642, ALL 0.0965; developed: motor 0.0464, buildings 0.0713, contents 0.0642, ALL 0.1023 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b0_ref end -->

## Step rt-b0_full: Retune run b0_full

<!-- auto:rt-b0_full start -->
**Script** `week2/R/r05_retune_baseline_b0_full.R` · **run** 2026-10-28 09:36:18 SGT · **run time** 6.4 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/clean/developed_train_motor.parquet | 80,891,702 | 04350e28384215e72754cc7f4d352c53 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/clean/developed_train_buildings.parquet | 52,992,663 | 624a45ddc8a0939fc99024a0a007fcda |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |
| data/week_2/optionB/clean/developed_train_contents.parquet | 53,197,406 | 38581d2a5c35b214e1176c0f332422c6 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b0_full.xlsx | 119,839 | 43d3e08670621b4e7ddd7447acf75ec0 |
| week2/week1_retune/output/b0_full/row_preds.parquet | 85,874,208 | 0b002e3e23d02d20e960be8113b39f0a |
| week2/week1_retune/output/b0_full/line_scores.csv | 1,014 | 89152660b99da1dac6c2c28025e6ccfd |
| week2/week1_retune/output/b0_full/peril_scores.csv | 4,431 | 327903efae73737f2faf93f5f67fdef1 |
| week2/week1_retune/output/b0_full/diagnostics_validation.csv | 4,519 | bfc90705deda96777d8469b919df7499 |
| week2/week1_retune/output/b0_full/features_used.csv | 14,103 | c60f635653422bef1bd07144054b9d01 |
| week2/week1_retune/output/b0_full/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b0_full/workbook_edits.csv | 333 | 45098aab126d40ff4cb3122f32b087f9 |
| week2/week1_retune/models/b0_full/model_card.md | 2,887 | 2679b72700560bd2e2318cf6f0961ace |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0455, buildings 0.0722, contents 0.0671, ALL 0.1015; developed: motor 0.0554, buildings 0.0711, contents 0.0672, ALL 0.1068 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b0_full end -->

## Step rt-b0_tele: Retune run b0_tele

<!-- auto:rt-b0_tele start -->
**Script** `week2/R/r05_retune_baseline_b0_tele.R` · **run** 2026-10-28 09:50:33 SGT · **run time** 4.1 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/clean/developed_train_motor.parquet | 80,891,702 | 04350e28384215e72754cc7f4d352c53 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/clean/developed_train_buildings.parquet | 52,992,663 | 624a45ddc8a0939fc99024a0a007fcda |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |
| data/week_2/optionB/clean/developed_train_contents.parquet | 53,197,406 | 38581d2a5c35b214e1176c0f332422c6 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b0_tele.xlsx | 120,147 | cb116dc802964cbb86f8b6cb6c606c9d |
| week2/week1_retune/output/b0_tele/row_preds.parquet | 85,630,840 | dc7d8502de2862371b4c227f94928714 |
| week2/week1_retune/output/b0_tele/line_scores.csv | 1,016 | 77191e9b83c85849284862ad8049897b |
| week2/week1_retune/output/b0_tele/peril_scores.csv | 4,435 | bb00783a84c8d020a533fcfea2f0caec |
| week2/week1_retune/output/b0_tele/diagnostics_validation.csv | 4,502 | db5f6e027a65c073a4e08d3c43636e43 |
| week2/week1_retune/output/b0_tele/features_used.csv | 13,121 | 8c52081482ff070a1a0c0766d1eaeea1 |
| week2/week1_retune/output/b0_tele/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b0_tele/workbook_edits.csv | 1,080 | 30d106d4a401737d067effe0cca771fc |
| week2/week1_retune/models/b0_tele/model_card.md | 3,743 | 4309f6dbe11aa386db0742b3a90e99ef |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0377, buildings 0.0723, contents 0.0642, ALL 0.0975; developed: motor 0.0477, buildings 0.0713, contents 0.0642, ALL 0.1029 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b0_tele end -->

## Step rt-b0_mile: Retune run b0_mile

<!-- auto:rt-b0_mile start -->
**Script** `week2/R/r05_retune_baseline_b0_mile.R` · **run** 2026-10-28 10:07:33 SGT · **run time** 5.5 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/clean/developed_train_motor.parquet | 80,891,702 | 04350e28384215e72754cc7f4d352c53 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/clean/developed_train_buildings.parquet | 52,992,663 | 624a45ddc8a0939fc99024a0a007fcda |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |
| data/week_2/optionB/clean/developed_train_contents.parquet | 53,197,406 | 38581d2a5c35b214e1176c0f332422c6 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b0_mile.xlsx | 120,202 | f6c429db4e18998c8cdb2f5e993aa1ff |
| week2/week1_retune/output/b0_mile/row_preds.parquet | 85,654,434 | fe02f8a50a8cebaca2fb26e803ddd208 |
| week2/week1_retune/output/b0_mile/line_scores.csv | 1,017 | 22e09c65b66d9325f331edf804b4816a |
| week2/week1_retune/output/b0_mile/peril_scores.csv | 4,435 | 68d18d20e14816f520dda606b6690bd7 |
| week2/week1_retune/output/b0_mile/diagnostics_validation.csv | 4,505 | 27879c9580a31c497cbcb2127b30203f |
| week2/week1_retune/output/b0_mile/features_used.csv | 13,019 | 5a221f89bca353a2d47c6e3076ea3fae |
| week2/week1_retune/output/b0_mile/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b0_mile/workbook_edits.csv | 1,151 | 656e2ca5acf1255aac34faf0516040fb |
| week2/week1_retune/models/b0_mile/model_card.md | 3,802 | da5385e6eeecdb3e33f34ae0b244c977 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0437, buildings 0.0723, contents 0.0642, ALL 0.1002; developed: motor 0.0522, buildings 0.0713, contents 0.0642, ALL 0.1049 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b0_mile end -->

## Step rt-b0_region: Retune run b0_region

<!-- auto:rt-b0_region start -->
**Script** `week2/R/r05_retune_baseline_b0_region.R` · **run** 2026-10-28 10:24:38 SGT · **run time** 6.0 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/clean/developed_train_motor.parquet | 80,891,702 | 04350e28384215e72754cc7f4d352c53 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/clean/developed_train_buildings.parquet | 52,992,663 | 624a45ddc8a0939fc99024a0a007fcda |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |
| data/week_2/optionB/clean/developed_train_contents.parquet | 53,197,406 | 38581d2a5c35b214e1176c0f332422c6 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b0_region.xlsx | 120,162 | 43a6eb2a40fed34523ba822218f582d2 |
| week2/week1_retune/output/b0_region/row_preds.parquet | 85,818,396 | b7b9f551f972dcefb71a8cff2c64513d |
| week2/week1_retune/output/b0_region/line_scores.csv | 1,012 | 30d60e06fce02c03ec88dcfef0011f47 |
| week2/week1_retune/output/b0_region/peril_scores.csv | 4,428 | 1aa882923451acf09d8f10f60334b164 |
| week2/week1_retune/output/b0_region/diagnostics_validation.csv | 4,514 | 8e080f27fc7944b0d68456e8b85f063f |
| week2/week1_retune/output/b0_region/features_used.csv | 13,357 | 8ad3428ca83984f76b5a1bbcff853c38 |
| week2/week1_retune/output/b0_region/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b0_region/workbook_edits.csv | 1,036 | aef8d1b36d803e7607ecc49900e7d204 |
| week2/week1_retune/models/b0_region/model_card.md | 3,667 | 97645813c1238146c2a8bab19c5e7e9d |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0375, buildings 0.0722, contents 0.0665, ALL 0.0978; developed: motor 0.0489, buildings 0.0712, contents 0.0665, ALL 0.1038 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b0_region end -->

## Step rt-b0_credit: Retune run b0_credit

<!-- auto:rt-b0_credit start -->
**Script** `week2/R/r05_retune_baseline_b0_credit.R` · **run** 2026-10-28 10:45:56 SGT · **run time** 6.2 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/clean/developed_train_motor.parquet | 80,891,702 | 04350e28384215e72754cc7f4d352c53 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/clean/developed_train_buildings.parquet | 52,992,663 | 624a45ddc8a0939fc99024a0a007fcda |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |
| data/week_2/optionB/clean/developed_train_contents.parquet | 53,197,406 | 38581d2a5c35b214e1176c0f332422c6 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b0_credit.xlsx | 120,169 | 9f20d0c2df1e9c26862cb6e8185606cf |
| week2/week1_retune/output/b0_credit/row_preds.parquet | 85,710,552 | 86724fea2255aaa410e04ca327ef7efe |
| week2/week1_retune/output/b0_credit/line_scores.csv | 1,018 | 517ea85acf0d652d0901b5726970d7e2 |
| week2/week1_retune/output/b0_credit/peril_scores.csv | 4,435 | f8c9d84c32e7bf1f131e5bc0c3fd4868 |
| week2/week1_retune/output/b0_credit/diagnostics_validation.csv | 4,508 | 33d6d21266df829c6ede139bf2c4a61f |
| week2/week1_retune/output/b0_credit/features_used.csv | 13,213 | cbb905f166206e9f950b4305381a45f7 |
| week2/week1_retune/output/b0_credit/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b0_credit/workbook_edits.csv | 1,021 | c0df1659267ef2c7fe66de3e3c2ce913 |
| week2/week1_retune/models/b0_credit/model_card.md | 3,657 | 145cc6fb83c06f56373c3bb10c64a6fd |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0354, buildings 0.0724, contents 0.0645, ALL 0.0966; developed: motor 0.0466, buildings 0.0714, contents 0.0645, ALL 0.1025 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b0_credit end -->

## Step rt-b0_age: Retune run b0_age

<!-- auto:rt-b0_age start -->
**Script** `week2/R/r05_retune_baseline_b0_age.R` · **run** 2026-10-28 11:05:44 SGT · **run time** 6.8 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/clean/developed_train_motor.parquet | 80,891,702 | 04350e28384215e72754cc7f4d352c53 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/clean/developed_train_buildings.parquet | 52,992,663 | 624a45ddc8a0939fc99024a0a007fcda |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |
| data/week_2/optionB/clean/developed_train_contents.parquet | 53,197,406 | 38581d2a5c35b214e1176c0f332422c6 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b0_age.xlsx | 120,134 | d1badedcd47099da8b5cd0c030a23ed5 |
| week2/week1_retune/output/b0_age/row_preds.parquet | 85,648,019 | 4c4b92be371bb3f59ec503e0b6009453 |
| week2/week1_retune/output/b0_age/line_scores.csv | 1,014 | 18f084514acbe9341c4968244a2bd834 |
| week2/week1_retune/output/b0_age/peril_scores.csv | 4,432 | 3a846eb6ae5c9dd15a52625ad14291cc |
| week2/week1_retune/output/b0_age/diagnostics_validation.csv | 4,515 | bfb2516bb9c7c5bdcb079ee83f4c3dec |
| week2/week1_retune/output/b0_age/features_used.csv | 12,809 | dcec4a69363e0d335b3494b2f4dce791 |
| week2/week1_retune/output/b0_age/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b0_age/workbook_edits.csv | 913 | 8ca363a55b82658f83d5ac46713e65ac |
| week2/week1_retune/models/b0_age/model_card.md | 3,565 | b3b070379f1dd6e9bb19c456450dd476 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0350, buildings 0.0723, contents 0.0646, ALL 0.0964; developed: motor 0.0470, buildings 0.0712, contents 0.0646, ALL 0.1027 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b0_age end -->

## Step rt-b1_depth_m1: Retune run b1_depth_m1

<!-- auto:rt-b1_depth_m1 start -->
**Script** `week2/R/r05_retune_baseline_b1_depth_m1.R` · **run** 2026-10-28 11:21:01 SGT · **run time** 4.0 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b1_depth_m1.xlsx | 120,239 | 688ef061090b7ec143a61f37774e28d1 |
| week2/week1_retune/output/b1_depth_m1/row_preds.parquet | 85,746,170 | 280e284b36ee50495e0a294bd854a6b0 |
| week2/week1_retune/output/b1_depth_m1/line_scores.csv | 1,017 | 58b9994b8c6d2b87a95edb449f4a6ca3 |
| week2/week1_retune/output/b1_depth_m1/peril_scores.csv | 4,426 | 86bbdabed2fc553969fb68aa4fcebc07 |
| week2/week1_retune/output/b1_depth_m1/diagnostics_validation.csv | 4,508 | 7b74ebdf1b5fff1007e5f06c874f1b2c |
| week2/week1_retune/output/b1_depth_m1/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/week1_retune/output/b1_depth_m1/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b1_depth_m1/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b1_depth_m1/model_card.md | 3,871 | ff254d8f972cd99ed41ed5310a199c17 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0351, buildings 0.0723, contents 0.0645, ALL 0.0964; developed: motor 0.0464, buildings 0.0714, contents 0.0645, ALL 0.1024 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b1_depth_m1 end -->

## Step rt-b1_depth_p1: Retune run b1_depth_p1

<!-- auto:rt-b1_depth_p1 start -->
**Script** `week2/R/r05_retune_baseline_b1_depth_p1.R` · **run** 2026-10-28 11:33:41 SGT · **run time** 5.1 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b1_depth_p1.xlsx | 120,239 | 07bb9c9852b0a19da5c7e47121bb1683 |
| week2/week1_retune/output/b1_depth_p1/row_preds.parquet | 85,627,789 | 119a3d691798e40e54cc4fa6c8205e07 |
| week2/week1_retune/output/b1_depth_p1/line_scores.csv | 1,014 | 925bd384fd3505fde6d7d9b7ff100250 |
| week2/week1_retune/output/b1_depth_p1/peril_scores.csv | 4,427 | 1e525e4fae7b42a4bfc6ed747e76e3dd |
| week2/week1_retune/output/b1_depth_p1/diagnostics_validation.csv | 4,502 | 41d22c92f72892e50e6a806af129838e |
| week2/week1_retune/output/b1_depth_p1/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/week1_retune/output/b1_depth_p1/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b1_depth_p1/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b1_depth_p1/model_card.md | 3,870 | 3166a7f89d146d1d52dbb6985b8db6af |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0361, buildings 0.0720, contents 0.0636, ALL 0.0966; developed: motor 0.0468, buildings 0.0709, contents 0.0636, ALL 0.1023 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b1_depth_p1 end -->

## Step rt-b1_eta_half: Retune run b1_eta_half

<!-- auto:rt-b1_eta_half start -->
**Script** `week2/R/r05_retune_baseline_b1_eta_half.R` · **run** 2026-10-28 11:56:42 SGT · **run time** 8.4 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b1_eta_half.xlsx | 120,239 | d8d978432448fca531edd989c44859f8 |
| week2/week1_retune/output/b1_eta_half/row_preds.parquet | 85,886,393 | 8d14bc37065be3e755a78e7c5c9c1354 |
| week2/week1_retune/output/b1_eta_half/line_scores.csv | 1,015 | cefd728383fc5c36c40d139cb5d720be |
| week2/week1_retune/output/b1_eta_half/peril_scores.csv | 4,426 | 2e042bbc0bde0af25f3c4d6813761c2e |
| week2/week1_retune/output/b1_eta_half/diagnostics_validation.csv | 4,530 | 8f24ba47bd116c9262ab2615fa20db40 |
| week2/week1_retune/output/b1_eta_half/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/week1_retune/output/b1_eta_half/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b1_eta_half/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b1_eta_half/model_card.md | 3,872 | 9b4f318bbaedaa3cdc6db74e33d7aff2 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0348, buildings 0.0727, contents 0.0641, ALL 0.0963; developed: motor 0.0462, buildings 0.0718, contents 0.0641, ALL 0.1024 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b1_eta_half end -->

## Step rt-b1_mcw_x2: Retune run b1_mcw_x2

<!-- auto:rt-b1_mcw_x2 start -->
**Script** `week2/R/r05_retune_baseline_b1_mcw_x2.R` · **run** 2026-10-28 12:14:39 SGT · **run time** 5.2 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b1_mcw_x2.xlsx | 120,239 | b4d14c148b8afdf46c52a4d75c554a0c |
| week2/week1_retune/output/b1_mcw_x2/row_preds.parquet | 85,594,639 | 4a98234c4bcf310daeec669cd1b9e082 |
| week2/week1_retune/output/b1_mcw_x2/line_scores.csv | 1,015 | ef14291144da3518294f8b9135f0c042 |
| week2/week1_retune/output/b1_mcw_x2/peril_scores.csv | 4,437 | 93bfce48241a5cdc1dbef72d9caaff23 |
| week2/week1_retune/output/b1_mcw_x2/diagnostics_validation.csv | 4,513 | 40138dd67186543d7a8ac8e05962075f |
| week2/week1_retune/output/b1_mcw_x2/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/week1_retune/output/b1_mcw_x2/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b1_mcw_x2/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b1_mcw_x2/model_card.md | 3,866 | 40c6b11f1e2d1fdea50115724585090a |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0358, buildings 0.0719, contents 0.0636, ALL 0.0964; developed: motor 0.0466, buildings 0.0708, contents 0.0636, ALL 0.1021 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b1_mcw_x2 end -->

## Step rt-b1_lambda20: Retune run b1_lambda20

<!-- auto:rt-b1_lambda20 start -->
**Script** `week2/R/r05_retune_baseline_b1_lambda20.R` · **run** 2026-10-28 12:34:59 SGT · **run time** 5.9 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b1_lambda20.xlsx | 120,239 | a868688d6f7e86863adc9b4798be8606 |
| week2/week1_retune/output/b1_lambda20/row_preds.parquet | 85,595,225 | 0cfdffdd3d01b66caff99cbf5f1c8f52 |
| week2/week1_retune/output/b1_lambda20/line_scores.csv | 1,016 | 99285125cfa85e2eaa95679b62d9f58e |
| week2/week1_retune/output/b1_lambda20/peril_scores.csv | 4,428 | c2d8fb98599817d7ad59e982df00ab7f |
| week2/week1_retune/output/b1_lambda20/diagnostics_validation.csv | 4,516 | 0895fa3aef12d83c03d34ffedc5b0454 |
| week2/week1_retune/output/b1_lambda20/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/week1_retune/output/b1_lambda20/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b1_lambda20/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b1_lambda20/model_card.md | 3,870 | 511b33666c25b8a258a8d98d0165f54f |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0356, buildings 0.0724, contents 0.0639, ALL 0.0966; developed: motor 0.0466, buildings 0.0715, contents 0.0640, ALL 0.1024 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b1_lambda20 end -->

## Step rt-b1_col1: Retune run b1_col1

<!-- auto:rt-b1_col1 start -->
**Script** `week2/R/r05_retune_baseline_b1_col1.R` · **run** 2026-10-28 12:54:21 SGT · **run time** 5.4 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b1_col1.xlsx | 120,239 | 572f5234d6618031860799ce3cf17f8c |
| week2/week1_retune/output/b1_col1/row_preds.parquet | 85,792,718 | 23337997ff2b0a6541ded22a99755e4c |
| week2/week1_retune/output/b1_col1/line_scores.csv | 1,014 | 1e37f57361e76c1c6c2caf7946f6f5e4 |
| week2/week1_retune/output/b1_col1/peril_scores.csv | 4,436 | 4ee13305a7f69931c31a79a271a9ef1d |
| week2/week1_retune/output/b1_col1/diagnostics_validation.csv | 4,507 | cecfec2d67fc2e79836c588408247ac0 |
| week2/week1_retune/output/b1_col1/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/week1_retune/output/b1_col1/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b1_col1/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b1_col1/model_card.md | 3,861 | fd03c74a7ee602fe815fad2dddcde5b2 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0355, buildings 0.0724, contents 0.0642, ALL 0.0966; developed: motor 0.0465, buildings 0.0714, contents 0.0642, ALL 0.1024 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b1_col1 end -->

## Step rt-b2_mono_off: Retune run b2_mono_off

<!-- auto:rt-b2_mono_off start -->
**Script** `week2/R/r05_retune_baseline_b2_mono_off.R` · **run** 2026-10-28 13:12:11 SGT · **run time** 5.2 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b2_mono_off.xlsx | 120,239 | ca51e7877e1657fe1537c061af293585 |
| week2/week1_retune/output/b2_mono_off/row_preds.parquet | 85,619,350 | 4ec602a1721406d09a825acbd0cfb5b9 |
| week2/week1_retune/output/b2_mono_off/line_scores.csv | 1,014 | e5690f2d833d2e6e1da1eb557c84be1e |
| week2/week1_retune/output/b2_mono_off/peril_scores.csv | 4,430 | b164db5f9ff0a4d8a0e41226e3246d6b |
| week2/week1_retune/output/b2_mono_off/diagnostics_validation.csv | 4,513 | aa6ad17480ed8b874ba7f8b4144849b2 |
| week2/week1_retune/output/b2_mono_off/features_used.csv | 12,832 | c77c9d4f924716f1dc8c93d1492b18de |
| week2/week1_retune/output/b2_mono_off/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b2_mono_off/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b2_mono_off/model_card.md | 3,869 | ca128655ab6552c379000f18e775eb43 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0358, buildings 0.0728, contents 0.0639, ALL 0.0968; developed: motor 0.0464, buildings 0.0717, contents 0.0640, ALL 0.1024 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b2_mono_off end -->

## Step rt-b2_band_ord: Retune run b2_band_ord

<!-- auto:rt-b2_band_ord start -->
**Script** `week2/R/r05_retune_baseline_b2_band_ord.R` · **run** 2026-10-28 13:33:44 SGT · **run time** 7.2 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b2_band_ord.xlsx | 120,239 | 50647b2d3411ab8640eb168832b4fe57 |
| week2/week1_retune/output/b2_band_ord/row_preds.parquet | 85,599,723 | efeff2fe0576edfa69969a7015f57855 |
| week2/week1_retune/output/b2_band_ord/line_scores.csv | 1,020 | 1a14211be2d360b12367ea6ba4c04405 |
| week2/week1_retune/output/b2_band_ord/peril_scores.csv | 4,436 | 9c6e3a300f1aa1dcbf1534ed0ad65465 |
| week2/week1_retune/output/b2_band_ord/diagnostics_validation.csv | 4,517 | 8a30729f244227ff44982753b1351912 |
| week2/week1_retune/output/b2_band_ord/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/week1_retune/output/b2_band_ord/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b2_band_ord/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b2_band_ord/model_card.md | 3,869 | 716825e256be4d36f221f1d539005279 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0345, buildings 0.0722, contents 0.0643, ALL 0.0961; developed: motor 0.0463, buildings 0.0712, contents 0.0643, ALL 0.1022 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b2_band_ord end -->

## Step rt-b3_loc: Retune run b3_loc

<!-- auto:rt-b3_loc start -->
**Script** `week2/R/r05_retune_baseline_b3_loc.R` · **run** 2026-10-28 13:55:49 SGT · **run time** 4.9 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b3_loc.xlsx | 120,239 | 77f8bc7b289e7f18cd246483cdfc4e24 |
| week2/week1_retune/output/b3_loc/row_preds.parquet | 85,882,271 | 375b8e22fa3c12fd241c1bf2ced87e82 |
| week2/week1_retune/output/b3_loc/line_scores.csv | 1,018 | 4f3596408e330a5b88c98ce4adae7d87 |
| week2/week1_retune/output/b3_loc/peril_scores.csv | 4,428 | 2fe9785b4b01bb94de5b4bacb090dbd3 |
| week2/week1_retune/output/b3_loc/diagnostics_validation.csv | 4,508 | c47e5600bdd7ca4dd310f946c8f0f6e6 |
| week2/week1_retune/output/b3_loc/features_used.csv | 16,363 | 12d37e7421c9daba58bbafd5ab730e4a |
| week2/week1_retune/output/b3_loc/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b3_loc/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b3_loc/model_card.md | 3,859 | 8cdd236cb3b2d7d9d1c36c54e7546aad |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0358, buildings 0.0721, contents 0.0645, ALL 0.0967; developed: motor 0.0473, buildings 0.0711, contents 0.0645, ALL 0.1027 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b3_loc end -->

## Step rt-b3_use: Retune run b3_use

<!-- auto:rt-b3_use start -->
**Script** `week2/R/r05_retune_baseline_b3_use.R` · **run** 2026-10-28 14:12:02 SGT · **run time** 5.5 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b3_use.xlsx | 120,239 | 1f4734c3de4ad58754b76dbaeb63867c |
| week2/week1_retune/output/b3_use/row_preds.parquet | 85,647,573 | 35de21fe553c64b88c53df46a9e0b77b |
| week2/week1_retune/output/b3_use/line_scores.csv | 1,016 | bd660776617c1b6e9d72adf8589756d3 |
| week2/week1_retune/output/b3_use/peril_scores.csv | 4,432 | 02f5526af58ec64f0d179eb7d7790b82 |
| week2/week1_retune/output/b3_use/diagnostics_validation.csv | 4,506 | 4c98fa0654f6a301e0e932011fefc312 |
| week2/week1_retune/output/b3_use/features_used.csv | 13,192 | 1b386a4b7b8d84942166b2d8d23d32c3 |
| week2/week1_retune/output/b3_use/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b3_use/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b3_use/model_card.md | 3,867 | 0f133556dfe34d9765964552d958b4a3 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0371, buildings 0.0723, contents 0.0642, ALL 0.0973; developed: motor 0.0470, buildings 0.0713, contents 0.0642, ALL 0.1026 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b3_use end -->

## Step rt-b3_credit: Retune run b3_credit

<!-- auto:rt-b3_credit start -->
**Script** `week2/R/r05_retune_baseline_b3_credit.R` · **run** 2026-10-28 14:23:58 SGT · **run time** 4.0 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b3_credit.xlsx | 120,239 | 381b3f9c411c12617adf9c98695bb4b9 |
| week2/week1_retune/output/b3_credit/row_preds.parquet | 85,772,272 | ff7243c9b0b304ee1a8a548866940c9d |
| week2/week1_retune/output/b3_credit/line_scores.csv | 1,018 | 1cf959084e37dedc8ff16e33b3b4fc4f |
| week2/week1_retune/output/b3_credit/peril_scores.csv | 4,434 | 56b57886e1cbf6aaeabcd29e2d033879 |
| week2/week1_retune/output/b3_credit/diagnostics_validation.csv | 4,502 | 87503ceeb0cff5036b8aaeceec4280f2 |
| week2/week1_retune/output/b3_credit/features_used.csv | 13,965 | 7b4ba201d1cee891e902180076e69d48 |
| week2/week1_retune/output/b3_credit/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b3_credit/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b3_credit/model_card.md | 3,872 | 19dabe95a026ccc5bc195d453bddeec3 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0357, buildings 0.0728, contents 0.0647, ALL 0.0969; developed: motor 0.0471, buildings 0.0718, contents 0.0647, ALL 0.1029 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b3_credit end -->

## Step rt-b3_young: Retune run b3_young

<!-- auto:rt-b3_young start -->
**Script** `week2/R/r05_retune_baseline_b3_young.R` · **run** 2026-10-28 14:33:27 SGT · **run time** 3.6 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b3_young.xlsx | 120,239 | 24920a74a2dcfa062315fc2e96ffd03e |
| week2/week1_retune/output/b3_young/row_preds.parquet | 85,610,946 | d8b6a8d67d6e9d90f6898c8541903336 |
| week2/week1_retune/output/b3_young/line_scores.csv | 1,019 | ba589317c14573d977ef567ffaa261db |
| week2/week1_retune/output/b3_young/peril_scores.csv | 4,423 | cd322c94f8d1aa2f5342a51eea2ed223 |
| week2/week1_retune/output/b3_young/diagnostics_validation.csv | 4,501 | 4bc33ee64db8c7a27375b646fcea9ecb |
| week2/week1_retune/output/b3_young/features_used.csv | 13,038 | c73127aee783a8ecf715091b48fda4b4 |
| week2/week1_retune/output/b3_young/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b3_young/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b3_young/model_card.md | 3,867 | e8e074a70bee3745676504d38aa80096 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0361, buildings 0.0723, contents 0.0642, ALL 0.0968; developed: motor 0.0466, buildings 0.0713, contents 0.0642, ALL 0.1024 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b3_young end -->

## Step rt-b5_recent: Retune run b5_recent

<!-- auto:rt-b5_recent start -->
**Script** `week2/R/r05_retune_baseline_b5_recent.R` · **run** 2026-10-28 14:42:55 SGT · **run time** 3.6 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b5_recent.xlsx | 120,239 | c4abcb49a6b0fc78a738ac19fcbad870 |
| week2/week1_retune/output/b5_recent/row_preds.parquet | 85,714,007 | feb9784f2ccab5e7cb16d4d2c21dc676 |
| week2/week1_retune/output/b5_recent/line_scores.csv | 1,022 | 7d82ca4fe2ef4c7575d222edeef7e427 |
| week2/week1_retune/output/b5_recent/peril_scores.csv | 4,426 | 90eb172498dbf2a2deb9ecde7a5c473d |
| week2/week1_retune/output/b5_recent/diagnostics_validation.csv | 4,144 | 80563e9ad9ed0ce6e14ed0a0c2773925 |
| week2/week1_retune/output/b5_recent/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/week1_retune/output/b5_recent/structural_zero_check.csv | 421 | de74af859092bb0aba48372548369e82 |
| week2/week1_retune/output/b5_recent/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b5_recent/model_card.md | 3,869 | 494cf6f7385f147bb1ea5e4587d042bc |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0309, buildings 0.0697, contents 0.0618, ALL 0.0932; developed: motor 0.0445, buildings 0.0685, contents 0.0619, ALL 0.1002 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b5_recent end -->

## Step rt-b5_yw: Retune run b5_yw

<!-- auto:rt-b5_yw start -->
**Script** `week2/R/r05_retune_baseline_b5_yw.R` · **run** 2026-10-28 14:56:15 SGT · **run time** 3.7 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b5_yw.xlsx | 120,239 | a5009ea70b25236bf47f28d2ab213b61 |
| week2/week1_retune/output/b5_yw/row_preds.parquet | 85,849,303 | 20bc23bc160628b810fc6094bb79233f |
| week2/week1_retune/output/b5_yw/line_scores.csv | 1,010 | d09b64ff38e307e8c1db1cbbbe174aa6 |
| week2/week1_retune/output/b5_yw/peril_scores.csv | 4,438 | 6bc1f91f4c99e5338155e2a9617ee360 |
| week2/week1_retune/output/b5_yw/diagnostics_validation.csv | 4,510 | e4435645766aa5517b2d98f239b284a2 |
| week2/week1_retune/output/b5_yw/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/week1_retune/output/b5_yw/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b5_yw/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b5_yw/model_card.md | 3,871 | 1f981d5ac0bf6d1c466222b022346837 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0356, buildings 0.0721, contents 0.0641, ALL 0.0965; developed: motor 0.0466, buildings 0.0710, contents 0.0641, ALL 0.1023 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b5_yw end -->

## Step rt-b5_dw: Retune run b5_dw

<!-- auto:rt-b5_dw start -->
**Script** `week2/R/r05_retune_baseline_b5_dw.R` · **run** 2026-10-28 15:05:24 SGT · **run time** 3.4 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/emerging_train_buildings.parquet | 1,700,814 | e4b352330c75e3c79f9e0df09e6a697d |
| data/week_2/optionB/features/emerging_test_buildings.parquet | 3,678,330 | 9c6bf403e45023a050908c1fb940baac |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |
| data/week_2/optionB/features/emerging_train_contents.parquet | 2,109,480 | 19008e4596d174d35c5190636c6e4555 |
| data/week_2/optionB/features/emerging_test_contents.parquet | 4,591,647 | 667f79b9d3a2f08cdbeedf7bed2790f2 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b5_dw.xlsx | 120,239 | 664877a2a3edd17beae70216fec288ac |
| week2/week1_retune/output/b5_dw/row_preds.parquet | 85,172,121 | 4d40da028aa8b6dc765c37cb0b0e7ad7 |
| week2/week1_retune/output/b5_dw/line_scores.csv | 1,015 | ffc9fba24e523330a69247bbb6d35ae0 |
| week2/week1_retune/output/b5_dw/peril_scores.csv | 4,425 | 703870d5c19cef6f85d689d209e9a0db |
| week2/week1_retune/output/b5_dw/diagnostics_validation.csv | 4,484 | 93a3d784d9043f786bd34123df04eb70 |
| week2/week1_retune/output/b5_dw/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/week1_retune/output/b5_dw/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b5_dw/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b5_dw/model_card.md | 3,857 | c818b2893394b0baf4acb61243dedf0d |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0314, buildings 0.0702, contents 0.0612, ALL 0.0934; developed: motor 0.0437, buildings 0.0691, contents 0.0611, ALL 0.0998 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b5_dw end -->

## Step rt-b8_combo: Retune run b8_combo

<!-- auto:rt-b8_combo start -->
**Script** `week2/R/r05_retune_baseline_b8_combo.R` · **run** 2026-10-28 15:20:30 SGT · **run time** 5.0 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b8_combo.xlsx | 120,239 | e9af6bdd3e91c607223eb31b02d39589 |
| week2/week1_retune/output/b8_combo/row_preds.parquet | 85,716,969 | 4a459907ff88182e8d21e883b2da578a |
| week2/week1_retune/output/b8_combo/line_scores.csv | 1,017 | 6091e1bf0cbdc918b2495c6fd29500f1 |
| week2/week1_retune/output/b8_combo/peril_scores.csv | 4,423 | b0aff05aaf661f76549a5eee318677af |
| week2/week1_retune/output/b8_combo/diagnostics_validation.csv | 4,512 | 98ebd1f9a07e222e490bd1dd0d542fd7 |
| week2/week1_retune/output/b8_combo/features_used.csv | 17,474 | 1c26cb42336c9a689fb98459587679b8 |
| week2/week1_retune/output/b8_combo/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b8_combo/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b8_combo/model_card.md | 3,870 | b10d93458d0e0226d53dd2290af143f7 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0340, buildings 0.0728, contents 0.0657, ALL 0.0963; developed: motor 0.0471, buildings 0.0718, contents 0.0658, ALL 0.1031 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b8_combo end -->

## Step rt-b9_tune: Retune tuning b9_tune

<!-- auto:rt-b9_tune start -->
**Script** `week2/R/r05_retune_baseline_b9_tune.R` · **run** 2026-10-28 16:56:59 SGT · **run time** 87.4 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b9_tune.xlsx | 120,239 | ca1b2e4d4e01622097164773a12a6699 |

**Key numbers (from the script)**

- Tuned perils: 1 of 15.

<!-- auto:rt-b9_tune end -->

## Step rt-b9_applied: Retune run b9_applied

<!-- auto:rt-b9_applied start -->
**Script** `week2/R/r05_retune_baseline_b9_applied.R` · **run** 2026-10-28 17:03:43 SGT · **run time** 6.7 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b9_applied.xlsx | 120,239 | 7bf704d33850806bff1e1f98ef16c647 |
| week2/week1_retune/output/b9_applied/row_preds.parquet | 85,716,969 | 062d8c316251d48035363d49c310526d |
| week2/week1_retune/output/b9_applied/line_scores.csv | 1,016 | 47ca83761d7316f1e9f79590ae2962ca |
| week2/week1_retune/output/b9_applied/peril_scores.csv | 4,421 | 249573621c56c9a59559b23793960cf3 |
| week2/week1_retune/output/b9_applied/diagnostics_validation.csv | 4,516 | 1dba27bac460af5558e571a877ff14ac |
| week2/week1_retune/output/b9_applied/features_used.csv | 17,474 | 1c26cb42336c9a689fb98459587679b8 |
| week2/week1_retune/output/b9_applied/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b9_applied/workbook_edits.csv | 1,217 | 41a4e2e486d0e09bb7b40244b38b5f7f |
| week2/week1_retune/models/b9_applied/model_card.md | 3,874 | 99d10d9fe28f0104abf70d59d02c4cb1 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0340, buildings 0.0728, contents 0.0658, ALL 0.0963; developed: motor 0.0471, buildings 0.0718, contents 0.0659, ALL 0.1031 (week 1 C5 ALL reported_raw 0.1026).

<!-- auto:rt-b9_applied end -->

## Step rt-b8_combo_f: Retune run b8_combo_f

<!-- auto:rt-b8_combo_f start -->
**Script** `week2/R/r05_retune_baseline_b8_combo_f.R` · **run** 2026-10-28 19:44:53 SGT · **run time** 39.2 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_wendy07_final2_week1_copy.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/developed_test_motor.parquet | 17,652,719 | 03fb8840d762c392715da9f7e703f895 |
| data/week_2/optionB/features/emerging_train_buildings.parquet | 1,700,814 | e4b352330c75e3c79f9e0df09e6a697d |
| data/week_2/optionB/features/emerging_test_buildings.parquet | 3,678,330 | 9c6bf403e45023a050908c1fb940baac |
| data/week_2/optionB/features/developed_test_buildings.parquet | 12,304,955 | b9ab4f991c833c545e0e6c89fc791e62 |
| data/week_2/optionB/features/emerging_train_contents.parquet | 2,109,480 | 19008e4596d174d35c5190636c6e4555 |
| data/week_2/optionB/features/emerging_test_contents.parquet | 4,591,647 | 667f79b9d3a2f08cdbeedf7bed2790f2 |
| data/week_2/optionB/features/developed_test_contents.parquet | 12,454,975 | 5b3c7f31383a585435e3fe7c18793ec0 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/week1_retune/inputs/assumptions_retune_b8_combo_f.xlsx | 120,238 | 260f73c44a9af4747750bb5168f35060 |
| week2/week1_retune/output/b8_combo_f/row_preds.parquet | 85,931,457 | a32f33a74b189513ea6221569d6732ef |
| week2/week1_retune/output/b8_combo_f/line_scores.csv | 1,013 | f49737a47d41d26fd38192ffd16f7b3a |
| week2/week1_retune/output/b8_combo_f/peril_scores.csv | 4,429 | 6e30f87c7bfebaa6e1ef83d160cfbff7 |
| week2/week1_retune/output/b8_combo_f/diagnostics_validation.csv | 4,541 | 39cffa09c876874595ac5a0397769d68 |
| data/week_2/week1_retune/b8_combo_f/baseline_emerging_train.parquet | 9,722,050 | c25ebe70871fa1bda44e66a431d370e4 |
| data/week_2/week1_retune/b8_combo_f/baseline_emerging_test.parquet | 18,400,479 | 2596a830ae5ccbe7b524636fd0006593 |
| week2/week1_retune/output/b8_combo_f/diagnostics_final.csv | 2,238 | 7e84b9cb0bc9b46254045a1ceac581ab |
| week2/week1_retune/output/b8_combo_f/baseline_burn.csv | 1,140 | 23f06c6a5996b0dca9952560402b2dec |
| week2/week1_retune/output/b8_combo_f/replication_check.csv | 363 | c569eae5fe4fed9c8a77d93c298a9065 |
| week2/week1_retune/output/b8_combo_f/features_used.csv | 17,474 | 1c26cb42336c9a689fb98459587679b8 |
| week2/week1_retune/output/b8_combo_f/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/week1_retune/output/b8_combo_f/workbook_edits.csv | 1,217 | d47e853741f25fa33f98e10888f7fc11 |
| week2/week1_retune/models/b8_combo_f/model_card.md | 6,846 | 42b41ebc51249f2bc411f7eae53e36fd |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0364, buildings 0.0732, contents 0.0663, ALL 0.0976; developed: motor 0.0477, buildings 0.0722, contents 0.0664, ALL 0.1036 (week 1 C5 ALL reported_raw 0.1026).
- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 728.8, buildings 536.8, contents 130.2.

<!-- auto:rt-b8_combo_f end -->

