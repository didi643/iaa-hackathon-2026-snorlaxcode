# Week 2 step log (emerging market, Option B)

One section per step. The `auto` blocks are written by the scripts (inputs and outputs with MD5,
run time, key numbers); the decision text around them is written by hand.

## Step 0: Setup (paths, logging, seeds, MD5, session info)

<!-- auto:0 start -->
**Script** `week_2/R/00_setup_week2.R` · **run** 2026-10-25 20:42:24 SGT · **run time** 0.0 min

**Inputs**

(none)
**Outputs**

(none)
**Key numbers (from the script)**

- R 4.6.1; data.table 1.18.6.1, arrow 25.0.1, xgboost 3.2.1.1, lightgbm 4.7.0, readxl 1.6.0, openxlsx 4.2.9, mgcv 1.9.4; glmnet and writexl not installed.
- Seed 2026; valuation date 2024-12-31 (latest emerging report date is 2024-12-30).

<!-- auto:0 end -->

## Step 1: Profile both markets

<!-- auto:1 start -->
**Script** `week2/R/01_profile_emerging.R` · **run** 2026-10-27 11:12:05 SGT · **run time** 0.6 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| data/week_1/raw data/policies_motor.parquet | 44,218,528 | 1f041d00a0dd0291ad4e08b2ac3da431 |
| data/week_1/raw data/policies_buildings.parquet | 28,411,001 | 3a8f5315126ff7efae046e20a885e2c6 |
| data/week_1/raw data/policies_contents.parquet | 28,203,870 | 48584ba424dd46bbd55a1197f9668473 |
| data/week_1/raw data/test_motor.parquet | 12,035,693 | 3f858a996b0668fcfe48377c04495f47 |
| data/week_1/raw data/test_buildings.parquet | 7,917,305 | b192c00f2470ad54b6c43231bbd8a06d |
| data/week_1/raw data/test_contents.parquet | 7,795,903 | 7a0ff387bddf087fa5c16429b6593555 |
| data/week_1/raw data/claims.parquet | 6,393,494 | 52f29187d9e06fe8bf2ee26663b5e1f5 |
| data/week_1/raw data/customers.parquet | 9,840,123 | 4935ed63f4ae04643625e210f0c011a9 |
| data/week_1/raw data/addresses.parquet | 8,209,304 | 5f21db73de4b18196fe957a319e225b7 |
| data/week_1/raw data/weather.parquet | 41,863,008 | 324bf930fe5b66bacfdc1863f95c7944 |
| data/week_2/raw data/emerging/policies_motor.parquet | 1,988,978 | d1ee538b69fac149ba0a167ea42b02b6 |
| data/week_2/raw data/emerging/policies_buildings.parquet | 1,049,236 | b485efa7f62c5eaa8b259e2ce4b300f5 |
| data/week_2/raw data/emerging/policies_contents.parquet | 1,272,728 | cd86fbf03087a5921d95084423701be5 |
| data/week_2/raw data/emerging/test_motor.parquet | 4,626,510 | fbed8ecced3bc7eba78dadb09099f804 |
| data/week_2/raw data/emerging/test_buildings.parquet | 2,507,817 | cd5dd9164d3c6690c20a3ee1b77b4c70 |
| data/week_2/raw data/emerging/test_contents.parquet | 3,038,763 | 00503445baaa28ac422f79024e5bef51 |
| data/week_2/raw data/emerging/claims.parquet | 373,376 | 5ebd52402ed7c81c16de9ee54babd707 |
| data/week_2/raw data/emerging/customers.parquet | 2,319,251 | cc5e71468d171919920d88501c826c20 |
| data/week_2/raw data/emerging/addresses.parquet | 2,094,327 | aad04b143389215e099a3414d7926162 |
| data/week_2/raw data/emerging/weather.parquet | 6,060,339 | d86d473ef1f478ebf146a2c1e6074a1a |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/output/01_profile/row_counts.csv | 296 | 59a243b47db134a4e6984fd45f3d788f |
| week2/output/01_profile/column_differences.csv | 583 | dd51cc8af2752d2b021c561efd66828b |
| week2/output/01_profile/key_integrity.csv | 3,814 | 4ac7866a781829554aa1e26037c6b6d4 |
| week2/output/01_profile/emerging_exposure_fixes.csv | 38,633 | 70f98596221f96a7544fb647e50d2174 |
| week2/output/01_profile/data_traps.csv | 4,816 | f41a3a16f3e3f4a822e144a8de325bc6 |
| week2/output/01_profile/emerging_unmatched_claims.csv | 2,839 | 06900f6e7ce83ed946fa6032ce4f897a |
| week2/output/01_profile/customer_service_contacts_check.csv | 513 | 45d3dc68140b2a06d791b39b8a894c79 |
| week2/output/01_profile/renewal_decision_levels.csv | 1,196 | f394c33f420da9b3db9a92dfdf3828ab |
| week2/output/01_profile/experience_line_year_nb.csv | 4,402 | d3ac1fc430100e6abfd8197db30e80a7 |
| week2/output/01_profile/experience_peril_year.csv | 11,025 | 292ed2010924523e4e3a3612216ebdfa |
| week2/output/01_profile/experience_peril_year_nb.csv | 13,361 | 0af63cf15327930c9a7bb6cc37860294 |
| week2/output/01_profile/new_business_frequency_ratio.csv | 2,037 | 75f25d720aff1cc26b20b887a301c975 |
| week2/output/01_profile/report_lags.csv | 3,418 | c13673a38f33ddce958c962017551f1d |
| week2/output/01_profile/test_mix.csv | 5,850 | eb6c399461688c565ac4903d53c04641 |
| week2/output/01_profile/test_exposure_vs_training.csv | 281 | e9c585211c686e8595b1150bbaf759be |
| week2/output/01_profile/categorical_levels.csv | 2,730 | dcf1c1e624429142d80f44232645d276 |
| week2/output/01_profile/numeric_ranges.csv | 5,402 | e0fb68bf141bf8ae7908c3c8813b6f97 |
| week2/output/01_profile/peril_2023_24_market_comparison.csv | 2,172 | 766b23774f22d4c645a209a463e950be |
| week2/output/01_profile/profile_report.md | 31,635 | 3fe04dae5edffb40b6c6bf20b16fa964 |

**Key numbers (from the script)**

- Emerging claims 9,258 (handover 9,258); unmatched 36, of which loss date before 2023: 34.
- Emerging exposure fixes: policies_motor 254, policies_buildings 155, policies_contents 200, test_motor 0, test_buildings 0, test_contents 0.
- Test exposure vs 2024: buildings 3.92x, contents 3.95x, motor 3.93x.
- Test new-business share of exposure: motor 76.9%, buildings 76.8%, contents 77.0%.

<!-- auto:1 end -->

### Step 1 findings and decisions (written by hand after reading `week_2/output/01_profile/profile_report.md`)

Handover section 2 numbers, checked in R:

| Handover claim | R result | Verdict |
|---|---|---|
| 9,258 emerging claims | 9,258 | confirmed |
| Exposure >1 rows: motor 189, buildings 117, contents 146 | same (189 / 117 / 146); rows inconsistent with dates in any way: 254 / 155 / 200 (includes days/360-type errors < 1) | confirmed, wider fix needed |
| 34 claims in 2021-22 | 34 with loss date before 2023, all unmatched; 2 more unmatched claims in 2023-24 (36 unmatched in all) | confirmed + 2 |
| Test 76% new business | 76.8-77.0% of exposure | confirmed |
| Test exposure ~1.5x 2024 | **3.9x** 2024 exposure on every line (motor 79.0k vs 20.1k vehicle-years) | **corrected** |
| Motor renewal frequency 0.123-0.13 | all-peril reported frequency 0.184 (2023) / 0.170 (2024) renewals, 0.260 / 0.209 new business | **corrected** (handover figure looks like a subset of perils) |
| NB/renewal motor 0.209 vs 0.130 (2023), 0.143 vs 0.123 (2024) | ratio 1.42 (2023), 1.23 (2024); developed 1.36-1.43 | ratio pattern confirmed, levels differ |
| Fire severity 51.7k dev / 62.1k em | 50.7k / 62.1k | confirmed (dev slightly different window) |
| Flood severity 31.4k / 26.3k | 33.9k / 26.5k | close |
| Motor report lag median/p90 9/42 vs 9/41 | per peril, emerging lags match developed 2023-24 within a few days (e.g. TPP 14/45 vs 14/46; BI 99/318 vs 94/293) | confirmed |
| customer_service_contacts leakage | emerging claim rows 3.0-3.4 contacts vs 0.42 without, test 0.40: same leakage as Part 1 | confirmed, keep excluded |

New findings:
- **construction_type** uses different codes in emerging: BRK / STN / WOD / MIX (no lower-case words). Proposed map BRK->brick, STN->stone, WOD->timber, MIX->non_standard (shares 70/7/12/10% vs developed 72/8/12/10%). MIX->non_standard is a judgement; checked by A/E in step 6 (D006).
- **occupation** in emerging has 81 levels: mixed case, trailing spaces and a "Self-employed " prefix. Normalised to the 20 developed levels; the prefix becomes an emerging-only flag `self_employed` (D007).
- **Missing values** are about 12% in emerging vs 2.5% in developed for occupation, household_size, years_at_address, vehicle_age, engine_size_cc, days_unoccupied, high_value_items, distance_to_river_km.
- **Climate** differs: emerging hail_days mean 14.2 vs 6.3, wildfire_index 0.53 vs 0.16 (only 34% of emerging values inside developed p1-p99), rainfall 1,336 vs 1,045 mm, freezing days 22 vs 38. Tree models cannot extrapolate beyond the developed range, so weather relativities need an emerging check (step 6).
- **Severity is lower in emerging** for almost every peril (motor 0.55-0.65x developed; buildings EoW 0.62x; subsidence 0.56x) except buildings fire (1.22x). **Frequency is higher** for motor (glass/hail 1.7x, TPP 1.4x, BI 1.4x) and buildings storm (1.5x), lower for EoW and AD.
- **Test mix**: test age bands shift to younger (17-24 and 25-34 each 25% vs 19-20% in 2024), consistent with the new-business mix; channel and cover mix unchanged.
- sum_insured has the 1000x unit error in emerging too (mean 680k vs p99 525k) - same fix as week 1.
- renewal_decision is NA on all test rows; not a feature (future information).
- No emerging duplicate claim ids, no 9-digit duplicate trap, no paid > incurred, no repudiated with incurred > 0.

## Step 2: Clean both markets

<!-- auto:2 start -->
**Script** `week2/R/02_clean_week2.R` · **run** 2026-10-27 11:15:45 SGT · **run time** 1.6 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| data/week_1/raw data/customers.parquet | 9,840,123 | 4935ed63f4ae04643625e210f0c011a9 |
| data/week_1/raw data/addresses.parquet | 8,209,304 | 5f21db73de4b18196fe957a319e225b7 |
| data/week_1/raw data/weather.parquet | 41,863,008 | 324bf930fe5b66bacfdc1863f95c7944 |
| data/week_1/raw data/claims.parquet | 6,393,494 | 52f29187d9e06fe8bf2ee26663b5e1f5 |
| data/week_1/raw data/policies_motor.parquet | 44,218,528 | 1f041d00a0dd0291ad4e08b2ac3da431 |
| data/week_1/raw data/test_motor.parquet | 12,035,693 | 3f858a996b0668fcfe48377c04495f47 |
| data/week_1/raw data/policies_buildings.parquet | 28,411,001 | 3a8f5315126ff7efae046e20a885e2c6 |
| data/week_1/raw data/test_buildings.parquet | 7,917,305 | b192c00f2470ad54b6c43231bbd8a06d |
| data/week_1/raw data/policies_contents.parquet | 28,203,870 | 48584ba424dd46bbd55a1197f9668473 |
| data/week_1/raw data/test_contents.parquet | 7,795,903 | 7a0ff387bddf087fa5c16429b6593555 |
| data/week_2/raw data/emerging/customers.parquet | 2,319,251 | cc5e71468d171919920d88501c826c20 |
| data/week_2/raw data/emerging/addresses.parquet | 2,094,327 | aad04b143389215e099a3414d7926162 |
| data/week_2/raw data/emerging/weather.parquet | 6,060,339 | d86d473ef1f478ebf146a2c1e6074a1a |
| data/week_2/raw data/emerging/claims.parquet | 373,376 | 5ebd52402ed7c81c16de9ee54babd707 |
| data/week_2/raw data/emerging/policies_motor.parquet | 1,988,978 | d1ee538b69fac149ba0a167ea42b02b6 |
| data/week_2/raw data/emerging/test_motor.parquet | 4,626,510 | fbed8ecced3bc7eba78dadb09099f804 |
| data/week_2/raw data/emerging/policies_buildings.parquet | 1,049,236 | b485efa7f62c5eaa8b259e2ce4b300f5 |
| data/week_2/raw data/emerging/test_buildings.parquet | 2,507,817 | cd5dd9164d3c6690c20a3ee1b77b4c70 |
| data/week_2/raw data/emerging/policies_contents.parquet | 1,272,728 | cd86fbf03087a5921d95084423701be5 |
| data/week_2/raw data/emerging/test_contents.parquet | 3,038,763 | 00503445baaa28ac422f79024e5bef51 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| data/week_2/optionB/clean/developed_train_motor.parquet | 80,891,702 | 04350e28384215e72754cc7f4d352c53 |
| data/week_2/optionB/clean/developed_test_motor.parquet | 20,554,332 | ec1000f82185286c5da9f80edb181db3 |
| data/week_2/optionB/clean/developed_train_buildings.parquet | 52,992,663 | 624a45ddc8a0939fc99024a0a007fcda |
| data/week_2/optionB/clean/developed_test_buildings.parquet | 14,069,371 | 0baaae9f8f9046ae185b8844f7bebaab |
| data/week_2/optionB/clean/developed_train_contents.parquet | 53,197,406 | 38581d2a5c35b214e1176c0f332422c6 |
| data/week_2/optionB/clean/developed_test_contents.parquet | 14,086,244 | 88e0e5c2f97162d0e89fe26932c65bb5 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/02_clean/unmatched_claims_developed.csv | 32,252 | 9ae8774d2ade6325e558f91563bde102 |
| data/week_2/optionB/clean/emerging_train_motor.parquet | 3,714,162 | bb9bde44c10725ec350d4abc7def5513 |
| data/week_2/optionB/clean/emerging_test_motor.parquet | 7,436,217 | 2093fc9d31e42536d5149f209cc1ab94 |
| data/week_2/optionB/clean/emerging_train_buildings.parquet | 1,972,856 | c844ffa6fc65cf0b173466ef8beccbd1 |
| data/week_2/optionB/clean/emerging_test_buildings.parquet | 4,161,366 | b8539e055821e002969e76a65d67e555 |
| data/week_2/optionB/clean/emerging_train_contents.parquet | 2,416,238 | 9c151fb976c0e16674efdcc5a07f1928 |
| data/week_2/optionB/clean/emerging_test_contents.parquet | 5,115,375 | 7254a55f5765a1b2dca63273fc82f290 |
| data/week_2/optionB/clean/emerging_claims_matched.parquet | 512,923 | 1588dcfe42835f5c380b2d623e421775 |
| week2/output/02_clean/unmatched_claims_emerging.csv | 2,844 | 12ee7f373c3596b563fc1e1dff36fa23 |
| week2/output/02_clean/data_checks.csv | 13,790 | e83f1b3b298f239efcdd2acc58c17e40 |
| week2/output/02_clean/experience_by_year.csv | 2,208 | 0e8cebd0d91289877dfc3f5be77f9703 |
| week2/output/02_clean/emerging_exposure_fixes.csv | 38,624 | 5c8903add87b240408df66677ede0915 |
| week2/output/02_clean/cleaning_report.md | 17,932 | c4a92d8ad87ae1b832bcd1187320f50e |

**Key numbers (from the script)**

- customers: occupation changed by normalisation (case / spaces / prefix) = 59899
- policies_motor: exposure inconsistent with period dates = 254
- claims_motor: claims matching no policy row = 28
- claims_motor: unmatched with loss_date before first training year = 26
- policies_buildings: exposure inconsistent with period dates = 155
- policies_buildings: sum_insured > 5e+06 and divisible by 1000 = 53
- policies_buildings: construction_type recoded = 27447
- test_buildings: sum_insured > 5e+06 and divisible by 1000 = 104
- test_buildings: construction_type recoded = 52295
- claims_buildings: claims matching no policy row = 3
- claims_buildings: unmatched with loss_date before first training year = 3
- policies_contents: exposure inconsistent with period dates = 200
- policies_contents: sum_insured > 2e+06 and divisible by 1000 = 57
- test_contents: sum_insured > 2e+06 and divisible by 1000 = 135
- claims_contents: claims matching no policy row = 5
- claims_contents: unmatched with loss_date before first training year = 5
- Emerging experience: motor 2023 freq 0.1886 burn 432.7; motor 2024 freq 0.1736 burn 382.7; buildings 2023 freq 0.0456 burn 514.3; buildings 2024 freq 0.0444 burn 306.7; contents 2023 freq 0.0348 burn 91.1; contents 2024 freq 0.0339 burn 86.8

<!-- auto:2 end -->

## Step 3: Harmonise features

<!-- auto:3 start -->
**Script** `week2/R/03_harmonise_features.R` · **run** 2026-10-27 11:17:44 SGT · **run time** 1.9 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| data/week_2/optionB/clean/developed_train_motor.parquet | 80,891,702 | 04350e28384215e72754cc7f4d352c53 |
| data/week_2/optionB/clean/developed_test_motor.parquet | 20,554,332 | ec1000f82185286c5da9f80edb181db3 |
| data/week_2/optionB/clean/emerging_train_motor.parquet | 3,714,162 | bb9bde44c10725ec350d4abc7def5513 |
| data/week_2/optionB/clean/emerging_test_motor.parquet | 7,436,217 | 2093fc9d31e42536d5149f209cc1ab94 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| data/week_2/optionB/clean/developed_train_buildings.parquet | 52,992,663 | 624a45ddc8a0939fc99024a0a007fcda |
| data/week_2/optionB/clean/developed_train_contents.parquet | 53,197,406 | 38581d2a5c35b214e1176c0f332422c6 |
| data/week_2/optionB/clean/emerging_claims_matched.parquet | 512,923 | 1588dcfe42835f5c380b2d623e421775 |
| data/week_2/optionB/clean/emerging_train_buildings.parquet | 1,972,856 | c844ffa6fc65cf0b173466ef8beccbd1 |
| data/week_2/optionB/clean/emerging_train_contents.parquet | 2,416,238 | 9c151fb976c0e16674efdcc5a07f1928 |
| data/week_2/optionB/clean/developed_test_buildings.parquet | 14,069,371 | 0baaae9f8f9046ae185b8844f7bebaab |
| data/week_2/optionB/clean/emerging_test_buildings.parquet | 4,161,366 | b8539e055821e002969e76a65d67e555 |
| data/week_2/optionB/clean/developed_test_contents.parquet | 14,086,244 | 88e0e5c2f97162d0e89fe26932c65bb5 |
| data/week_2/optionB/clean/emerging_test_contents.parquet | 5,115,375 | 7254a55f5765a1b2dca63273fc82f290 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/developed_test_motor.parquet | 17,652,719 | 03fb8840d762c392715da9f7e703f895 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/developed_train_buildings.parquet | 46,432,040 | cb614d1f7f6e052ae3de1fe961dfacdf |
| data/week_2/optionB/features/developed_test_buildings.parquet | 12,304,955 | b9ab4f991c833c545e0e6c89fc791e62 |
| data/week_2/optionB/features/emerging_train_buildings.parquet | 1,700,814 | e4b352330c75e3c79f9e0df09e6a697d |
| data/week_2/optionB/features/emerging_test_buildings.parquet | 3,678,330 | 9c6bf403e45023a050908c1fb940baac |
| data/week_2/optionB/features/developed_train_contents.parquet | 46,982,094 | f23b46a7878e187d160112189ea04c15 |
| data/week_2/optionB/features/developed_test_contents.parquet | 12,454,975 | 5b3c7f31383a585435e3fe7c18793ec0 |
| data/week_2/optionB/features/emerging_train_contents.parquet | 2,109,480 | 19008e4596d174d35c5190636c6e4555 |
| data/week_2/optionB/features/emerging_test_contents.parquet | 4,591,647 | 667f79b9d3a2f08cdbeedf7bed2790f2 |
| week2/output/03_features/feature_map.csv | 28,667 | 6acb129a13052d9c4913d4934ed35c84 |
| week2/output/03_features/level_map.csv | 39 | a49cd19f5faf824b31a0274a461263e7 |
| week2/output/03_features/history_summary.csv | 1,974 | 33d1ea83975f9093b5de692aaa862a84 |
| week2/output/03_features/features_report.md | 34,359 | a37d381d58a3e77fc83c71a41265a733 |

**Key numbers (from the script)**

- Features kept per line: motor 62, buildings 54, contents 55.
- Emerging-only levels sent to 'other': 0 level(s), 0 rows.
- History NA share: emerging test motor 0.76, buildings 0.76, contents 0.76; developed test motor 0.15, buildings 0.15, contents 0.15.

<!-- auto:3 end -->

## Step 4: IBNR and trend

<!-- auto:4 start -->
**Script** `week2/R/04_ibnr_trend_week2.R` · **run** 2026-10-27 11:18:25 SGT · **run time** 0.6 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| data/week_2/optionB/clean/emerging_claims_matched.parquet | 512,923 | 1588dcfe42835f5c380b2d623e421775 |
| data/week_2/optionB/clean/developed_train_motor.parquet | 80,891,702 | 04350e28384215e72754cc7f4d352c53 |
| data/week_2/optionB/clean/developed_train_buildings.parquet | 52,992,663 | 624a45ddc8a0939fc99024a0a007fcda |
| data/week_2/optionB/clean/developed_train_contents.parquet | 53,197,406 | 38581d2a5c35b214e1176c0f332422c6 |
| data/week_2/optionB/clean/emerging_train_motor.parquet | 3,714,162 | bb9bde44c10725ec350d4abc7def5513 |
| data/week_2/optionB/clean/emerging_train_buildings.parquet | 1,972,856 | c844ffa6fc65cf0b173466ef8beccbd1 |
| data/week_2/optionB/clean/emerging_train_contents.parquet | 2,416,238 | 9c151fb976c0e16674efdcc5a07f1928 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| week2/output/04_ibnr_trend/emerging_chain_ladder_check.csv | 6,864 | 8e6d8e59ecae5de7160dccfaea1bd93e |
| week2/output/04_ibnr_trend/lag_comparison.csv | 2,582 | 380d580b6249c49785cfde449d9db4c0 |
| week2/output/04_ibnr_trend/ibnr_by_year.csv | 1,896 | ccdc5c3b6cf8acea831fe5b80c7e4b45 |
| week2/output/04_ibnr_trend/experience_by_year_ultimate.csv | 11,412 | 07ba2e6db98aedfc05472e1eceedd7ee |
| week2/output/04_ibnr_trend/trend_table.csv | 3,429 | d89cd42f595510cdb2aaacb5145853fc |
| week2/output/04_ibnr_trend/ibnr_trend_report.md | 15,788 | 21babab535842f8e90868ec833d0e7c9 |

**Key numbers (from the script)**

- Lags (same loss years, KS p < 0.01): none.
- 2024 IBNR factor (developed CL): b/accidental_damage 1.033, b/escape_of_water 1.048, b/fire 1.019, b/flood 1.036, b/storm 1.038, b/subsidence 1.494, c/accidental_damage 1.035, c/escape_of_water 1.053, c/flood 1.038, c/theft 1.018, m/bodily_injury 1.778, m/glass_hail 1.027, m/own_damage 1.033, m/theft 1.019, m/third_party_prop 1.066.
- Chosen severity trend: b/accidental_damage +2.8%, b/escape_of_water +7.3%, b/fire -2.0%, b/flood +7.2%, b/storm +8.8%, b/subsidence +1.5%, c/accidental_damage +1.5%, c/escape_of_water +1.6%, c/flood +6.2%, c/theft +4.1%, m/bodily_injury +0.0%, m/glass_hail +9.2%, m/own_damage +3.7%, m/theft +6.0%, m/third_party_prop +4.2%.
- Chosen frequency trend: motor/own_damage -5.0%, motor/third_party_prop -3.4%.

<!-- auto:4 end -->

### Step 4 decisions (by hand)

- **Reporting is the same in both markets.** For the same loss years (identical censoring at 31 Dec 2024), no peril shows a significant lag difference (KS p >= 0.01 everywhere). An emerging-only chain ladder gives 2024 shares within about 0.02 of the developed ones (BI 0.557 vs 0.563, TPP 0.945 vs 0.939, subsidence 0.748 vs 0.669 on 52 claims). Decision D014: use the developed chain ladder (thick) for emerging rows; subsidence keeps the C5 lag-ECDF override.
- **Trends.** Developed log-linear trends 2021-24 are the prior. The emerging one-year change is noisy (fire frequency -59%, subsidence severity -33%) and gets credibility Z = n/(n+2000), so 3-57% weight. Frequency trend only where week 1 used one (motor OD, TPP); motor BI no trend (week 1 C5 choice: IBNER vs real decline unresolved). Severity trends 1.5-9% a year, fire -2% (clamp). D015. These apply from the emerging data period to 2025 in step 8.
## Step 5: Developed baseline

<!-- auto:5 start -->
**Script** `week2/R/05_developed_baseline.R` · **run** 2026-10-27 12:54:43 SGT · **run time** 41.4 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week1/docs/assumptions_wendy07_final2.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
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
| week2/inputs/assumptions_week2_baseline.xlsx | 120,238 | 563edbb102d821c73bed7727a72eb103 |
| week2/output/05_baseline/row_preds.parquet | 85,921,055 | 9bde2289cef28d7b484df2428e83ef36 |
| week2/output/05_baseline/line_scores.csv | 1,017 | d154c3116bfd7b5eb426a15b593d3113 |
| week2/output/05_baseline/peril_scores.csv | 4,423 | a330df949151f382ce45d66f438ec699 |
| week2/output/05_baseline/diagnostics_validation.csv | 4,531 | b8e8faf3123960d93a6b0ad27a4a9022 |
| data/week_2/optionB/baseline/baseline_emerging_train.parquet | 9,727,477 | cf56acd7bc6a49416da9b8b78d8d58f8 |
| data/week_2/optionB/baseline/baseline_emerging_test.parquet | 18,377,519 | df1d1668d906c6c8866a9663083fcbb7 |
| week2/output/05_baseline/diagnostics_final.csv | 2,234 | dc79eb0ba665bb806e695a55134df87d |
| week2/output/05_baseline/baseline_burn.csv | 1,131 | e1daa12f4a0ec01f2f6a8f51c75b4615 |
| week2/output/05_baseline/replication_check.csv | 363 | c569eae5fe4fed9c8a77d93c298a9065 |
| week2/output/05_baseline/features_used.csv | 12,854 | c1bd8834efdb8feac7c0ddabccf0d8b4 |
| week2/output/05_baseline/structural_zero_check.csv | 422 | f3d6b71f3280be56b740bce41d3a9d79 |
| week2/output/05_baseline/workbook_edits.csv | 1,217 | d47e853741f25fa33f98e10888f7fc11 |
| week2/models/baseline/model_card.md | 6,396 | ccd618a0afb9fe5be401e683c58883de |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0376, buildings 0.0729, contents 0.0645, ALL 0.0978; developed: motor 0.0472, buildings 0.0719, contents 0.0646, ALL 0.1030 (week 1 C5 ALL reported_raw 0.1026).
- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 763.3, buildings 534.6, contents 127.2.

<!-- auto:5 end -->

### Step 5 decisions (by hand)

- Shared features cost little on developed data: mean 2023-24 ALL D2 is 0.0965 on reported_raw (0.1024 on developed actuals), against week 1 C5's 0.1026 with all fields, 5 bags and Tweedie for BI / contents EoW. The loss of about 0.006 is the price of dropping region, credit_band, annual_mileage and telematics (plus 1 bag). Motor loses most (0.0355 vs about 0.054 in week 1): region and mileage mattered for motor.
- The 22.7-minute run included a contention slowdown (step 6 was debugged in parallel). The FAST smoke test gave ALL 0.0963, so early stopping, not rounds, sets the result.
- Saved models reproduce the emerging predictions exactly (replication diff 0).
- At the developed level the emerging 2025 burn would be motor 765, buildings 552, contents 127. Step 7 re-estimates the level.


## Step 6: Score emerging with the baseline (A/E)

<!-- auto:6 start -->
**Script** `week2/R/06_score_emerging_baseline.R` · **run** 2026-10-27 12:54:55 SGT · **run time** 0.2 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/clean/emerging_claims_matched.parquet | 512,923 | 1588dcfe42835f5c380b2d623e421775 |
| data/week_2/optionB/baseline/baseline_emerging_train.parquet | 9,727,477 | cf56acd7bc6a49416da9b8b78d8d58f8 |
| week2/output/05_baseline/diagnostics_final.csv | 2,234 | dc79eb0ba665bb806e695a55134df87d |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_train_buildings.parquet | 1,700,814 | e4b352330c75e3c79f9e0df09e6a697d |
| data/week_2/optionB/features/emerging_train_contents.parquet | 2,109,480 | 19008e4596d174d35c5190636c6e4555 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/output/06_ae/ae_line_peril.csv | 9,401 | 4345d5bf6f3eaff895a32dd7b13de172 |
| week2/output/06_ae/ae_factor.csv | 48,152 | e6c34cbee2854a9eee91ec41c74f5aae |
| week2/output/06_ae/ae_slopes.csv | 7,092 | fff6bd57a5a09328f8d8a1d22d7e5196 |
| week2/output/06_ae/ae_motor_factors.png | 17,957 | adc1273526a66dfb3784c42585fcca87 |
| week2/output/06_ae/ae_buildings_factors.png | 12,314 | f322d9e08da1d43753175308194f5ea7 |
| week2/output/06_ae/ae_report.md | 37,419 | 34333217b1bf16650ac653712e75b18d |

**Key numbers (from the script)**

- Frequency A/E (2023-24, reported basis) by peril: b/accidental_damage 0.83, b/escape_of_water 0.83, b/fire 1.20, b/flood 0.78, b/storm 1.41, b/subsidence 1.11, c/accidental_damage 0.77, c/escape_of_water 0.87, c/flood 0.92, c/theft 1.08, m/bodily_injury 1.19, m/glass_hail 1.34, m/own_damage 1.12, m/theft 1.32, m/third_party_prop 1.20.
- Capped severity A/E by peril: b/accidental_damage 0.70, b/escape_of_water 0.55, b/fire 1.21, b/flood 0.70, b/storm 0.62, b/subsidence 0.58, c/accidental_damage 0.78, c/escape_of_water 0.77, c/flood 0.85, c/theft 0.78, m/bodily_injury 0.54, m/glass_hail 0.58, m/own_damage 0.62, m/theft 0.64, m/third_party_prop 0.55.
- Factors with a significant A/E slope (p < 0.01): buildings:construction_type, motor:occupation, motor:voluntary_excess, motor:driver_age_band, motor:hail_days_b, motor:years_licensed_b.

<!-- auto:6 end -->

### Step 6 findings (by hand) - what changed

- **Levels differ a lot, shapes mostly do not.** Frequency A/E vs the developed baseline is 1.1-1.3 for motor perils and buildings storm (1.39), and 0.77-0.87 for EoW and AD. Capped severity A/E is 0.54-0.80 everywhere except buildings fire (1.21). Emerging claims are cheaper but more frequent.
- Factor slopes significant at p < 0.01 exist only in motor: occupation, voluntary_excess, driver_age_band, hail_days, years_licensed, ncb_years. The motor hail slope is expected: emerging hail days are far outside the developed range. Buildings construction_type and sum_insured are weak (p 0.01-0.05); all contents factors are flat or weak.
- construction_type MIX -> non_standard (D006): the A/E for non_standard is within the noise of the other levels (see ae_factor.csv), so the map is kept; the weak construction_type slope is picked up in step 7 for storm / flood.


## Step 7: Emerging adjustments

<!-- auto:7 start -->
**Script** `week2/R/07_emerging_adjust.R` · **run** 2026-10-27 12:55:40 SGT · **run time** 0.7 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| week2/output/04_ibnr_trend/trend_table.csv | 3,429 | d89cd42f595510cdb2aaacb5145853fc |
| week2/output/05_baseline/diagnostics_final.csv | 2,234 | dc79eb0ba665bb806e695a55134df87d |
| week2/output/06_ae/ae_slopes.csv | 7,092 | fff6bd57a5a09328f8d8a1d22d7e5196 |
| data/week_2/optionB/clean/emerging_claims_matched.parquet | 512,923 | 1588dcfe42835f5c380b2d623e421775 |
| data/week_2/optionB/baseline/baseline_emerging_train.parquet | 9,727,477 | cf56acd7bc6a49416da9b8b78d8d58f8 |
| data/week_2/optionB/baseline/baseline_emerging_test.parquet | 18,377,519 | df1d1668d906c6c8866a9663083fcbb7 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/emerging_extra_train_motor.parquet | 335,942 | 359b9b588ff0c49c3cc8a65cc51ed22a |
| data/week_2/optionB/features/emerging_extra_test_motor.parquet | 630,845 | 37ba43ea3bc50440fb47bd73f6cb36b9 |
| data/week_2/optionB/features/emerging_train_buildings.parquet | 1,700,814 | e4b352330c75e3c79f9e0df09e6a697d |
| data/week_2/optionB/features/emerging_test_buildings.parquet | 3,678,330 | 9c6bf403e45023a050908c1fb940baac |
| data/week_2/optionB/features/emerging_extra_train_buildings.parquet | 191,543 | c707e6ae4c7b5f80afc8342a1fc079ba |
| data/week_2/optionB/features/emerging_extra_test_buildings.parquet | 374,698 | 49963fafd5406b86763b5b1846aaf248 |
| data/week_2/optionB/features/emerging_train_contents.parquet | 2,109,480 | 19008e4596d174d35c5190636c6e4555 |
| data/week_2/optionB/features/emerging_test_contents.parquet | 4,591,647 | 667f79b9d3a2f08cdbeedf7bed2790f2 |
| data/week_2/optionB/features/emerging_extra_train_contents.parquet | 246,002 | 3988fbb3291451760c450f3795eb9179 |
| data/week_2/optionB/features/emerging_extra_test_contents.parquet | 470,690 | 596dfe2d577f2f7c06f4ed153513750a |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/output/07_adjust/cred_main.csv | 4,386 | 8235a49035432ad6d8dcb00088bd7240 |
| data/week_2/optionB/adjust/main/valid_2024_peril.parquet | 12,993,269 | 0feca0e282242e72e8b49cfd3b434fab |
| data/week_2/optionB/adjust/main/final_2025_peril.parquet | 58,652,112 | 52a3c7b08f3fe352dd52b0dab49e96a7 |
| data/week_2/optionB/adjust/main/insample_peril.parquet | 14,840,414 | 6d4165aaedce0cdfd68caa2787e6a1b0 |
| week2/output/07_adjust/factor_log.csv | 27,404 | eaa4105d43266e06b9bbb80d9bd84170 |
| week2/output/07_adjust/coefficients.csv | 11,830 | 8c7d8f97063075c1afab00c187e25f17 |
| week2/output/07_adjust/levels.csv | 3,232 | 2535175e535db848190aea3590c5c959 |
| week2/output/07_adjust/adjust_report.md | 42,761 | 92e7ad5200d921ee4bc4f228aa09cd3d |

**Key numbers (from the script)**

- Frequency level (emerging / developed baseline), final fit: m/own_damage 1.10, m/third_party_prop 1.18, m/bodily_injury 1.19, m/theft 1.27, m/glass_hail 1.32, b/storm 1.29, b/flood 0.96, b/escape_of_water 0.92, b/subsidence 1.06, b/fire 1.08, b/accidental_damage 0.96, c/theft 1.02, c/escape_of_water 0.89, c/accidental_damage 0.82, c/flood 0.91.
- Severity level, final fit: m/own_damage 0.63, m/third_party_prop 0.57, m/bodily_injury 0.58, m/theft 0.64, m/glass_hail 0.61, b/storm 0.64, b/flood 0.65, b/escape_of_water 0.62, b/subsidence 0.65, b/fire 0.68, b/accidental_damage 0.66, c/theft 0.79, c/escape_of_water 0.78, c/accidental_damage 0.77, c/flood 0.79.
- Factors kept (frequency): motor/own_damage: gender + voluntary_excess + occupation; motor/third_party_prop: gender + vehicle_value_group_b + self_employed; motor/bodily_injury: gender + ncb_years_b + voluntary_excess; motor/theft: occupation + self_employed; motor/glass_hail: hail_days_b + voluntary_excess + vehicle_value_group_b + new_business; buildings/storm: self_employed + construction_type; buildings/flood: construction_type; buildings/escape_of_water: gender; buildings/accidental_damage: construction_type; contents/theft: gender; contents/accidental_damage: new_business.
- Factors kept (severity): motor/own_damage: voluntary_excess; motor/third_party_prop: self_employed; motor/glass_hail: years_licensed_b.

<!-- auto:7 end -->

### Step 7 decisions (by hand)

- First run (no level credibility): peril levels fitted on 2023 alone over-predicted 2024 by 20% (buildings fire 4.0m predicted vs 1.1m actual; subsidence 0.83m vs 0.33m). **Added credibility on the level** (handover step 8 principle applied to the level): the intercept is pulled to the line's pooled emerging/developed level with K = 100 claims (frequency) and K = 200 claims (severity, x3 for fire / flood / subsidence / BI / contents flood). 2024 D2 (developed, ALL) rose from 0.095 to 0.107 and the 2024 A/E from 1.20 to 1.13. One change, round constants, not tuned on the fold (D022).
- Second fix after the calibration check (step 9 / 10): the severity prior was first a cost-weighted pool, so buildings fire (level 1.2, largest claims) set the prior for every buildings peril and lifted EoW from its credible 0.56 to 0.66 (2024 A/E 0.66; 2025 EoW burn 73 vs 45 in history). Prior changed to the claim-weighted mean of the peril log levels (D025). 2024 D2 0.107 -> 0.113; buildings EoW A/E 0.66 -> 0.80, storm 1.00. This was prompted by the fold's calibration, so it carries some selection risk, but the old construction was wrong in principle (one peril's claim size should not set another's level).
- Factors are kept only where they improve 2024 deviance, so the 2024 D2 of B is slightly optimistic (the selection used the 2024 deviance); B - L is only +0.0013 so the effect is small.


## Step 8: 2025 loadings

<!-- auto:8 start -->
**Script** `week2/R/08_loadings_2025.R` · **run** 2026-10-27 12:55:48 SGT · **run time** 0.1 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| week2/output/04_ibnr_trend/trend_table.csv | 3,429 | d89cd42f595510cdb2aaacb5145853fc |
| week2/output/07_adjust/levels.csv | 3,232 | 2535175e535db848190aea3590c5c959 |
| data/week_2/optionB/adjust/main/final_2025_peril.parquet | 58,652,112 | 52a3c7b08f3fe352dd52b0dab49e96a7 |
| data/week_2/optionB/adjust/main/insample_peril.parquet | 14,840,414 | 6d4165aaedce0cdfd68caa2787e6a1b0 |
| data/week_2/optionB/clean/emerging_claims_matched.parquet | 512,923 | 1588dcfe42835f5c380b2d623e421775 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_train_buildings.parquet | 1,700,814 | e4b352330c75e3c79f9e0df09e6a697d |
| data/week_2/optionB/features/emerging_train_contents.parquet | 2,109,480 | 19008e4596d174d35c5190636c6e4555 |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/emerging_test_buildings.parquet | 3,678,330 | 9c6bf403e45023a050908c1fb940baac |
| data/week_2/optionB/features/emerging_test_contents.parquet | 4,591,647 | 667f79b9d3a2f08cdbeedf7bed2790f2 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| data/week_2/optionB/final/main/pred_2025_peril.parquet | 101,761,992 | d3c2a69edf574c84003b6d82a74e7ab9 |
| week2/output/08_loadings/main/loadings.csv | 2,981 | e8cd5dbf62ec22252b974de3cf13d1aa |
| week2/output/08_loadings/main/sensitivity.csv | 3,027 | afe8f13dffc3098a30be478fb3d2ee0b |
| week2/output/08_loadings/main/loadings_report.md | 5,901 | 7469aa1828837ce9992e768b06a377c2 |

**Key numbers (from the script)**

- NB residual A/E (relative) by line: buildings 0.834 (n 77), contents 1.182 (n 102), motor 1.237 (n 697); loads applied buildings 0.966, contents 1.046, motor 1.165.
- 2025 central burn (B): buildings 350.8, contents 104.4, motor 605.2.

<!-- auto:8 end -->

### Step 8 decisions (by hand)

- New business: the baseline already includes the developed NB relativity, so only the residual emerging NB A/E is loaded, with credibility: motor 1.164 (n 697 NB claims, residual 1.235), contents 1.051, buildings 0.965. Not applied where step 7 kept new_business (motor glass, contents AD).
- 2025 central burn (B): motor 589.5, buildings 422.5, contents 104.0 per exposure-year. The largest single sensitivities are NB (motor -11% with no NB load), trend (+/- 5%) and the emerging level itself (the developed level would be +22-31%).


## Step 9: Validation and comparison

<!-- auto:9 start -->
**Script** `week_2/R/09_validate_compare.R` · **run** 2026-10-25 22:40:13 SGT · **run time** 0.3 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week_2/output/04_ibnr_trend/report_share_quarter.csv | 22,478 | 686c60b027e806c65310d1b6b3b7ed76 |
| week_2/data/clean/emerging_claims_matched.parquet | 509,742 | e94de1fc19deccd5cc2624d050fd7dba |
| week_2/data/adjust/main/valid_2024_peril.parquet | 12,999,552 | a5f8ce88718992ec70424e06916b9e13 |
| week_2/data/features/emerging_train_motor.parquet | 3,194,789 | 05b67be9ec72b27383fc40d710396800 |
| week_2/data/features/emerging_train_buildings.parquet | 1,691,768 | 082f934eb9d8b5fe9eaa47afb3546ac6 |
| week_2/data/features/emerging_train_contents.parquet | 2,101,171 | 8891ac66c12252fb97c63e0055a8b17e |
| week_2/data/baseline/baseline_emerging_train.parquet | 9,731,924 | d390f36ac9be5cabb08f67b638301be9 |
| week_2/data/features/emerging_test_motor.parquet | 6,508,749 | 572cccb2d8a43f809a877203ee5cf342 |
| week_2/data/features/emerging_test_buildings.parquet | 3,652,456 | 5c7e3102d2970cafdda423fa1dfb5ee4 |
| week_2/data/features/emerging_test_contents.parquet | 4,553,937 | d31e5f39d4cc63815ff4f00433576086 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week_2/output/09_validate/main/reweighting_cells.csv | 1,755 | 74be96b8c4db6b2ce524da378851bb59 |
| week_2/data/valid_rows/main.parquet | 4,588,858 | 4f84e0be9757a73e1b07a4c8233ffebc |
| week_2/output/09_validate/main/scorecard.csv | 8,027 | 49eed6284d85821df50f3e41dab4987d |
| week_2/output/09_validate/main/bootstrap.csv | 2,513 | 4462aa28bc00dd6fc03d473283d13cb6 |
| week_2/output/09_validate/main/ceiling_simulation.csv | 1,540 | d7b944656af8955f5234f548aa3e6b9f |
| week_2/output/09_validate/main/calibration.csv | 3,869 | a09890331661a4b48e3717991bc2f83b |
| week_2/output/09_validate/main/validate_report.md | 14,733 | ee48aa71f7f3b1f3ddb0ce637fb521b2 |

**Key numbers (from the script)**

- As-is 2024 ALL D2 (week 1 protocol / constant-mean), developed actuals: B 0.1171/0.1497, L 0.1131/0.1458, E 0.0670/0.1015, BE 0.0985/0.1318, D 0.0930/0.1265, Bor 0.1188/0.1513.
- 2024 reweighted to the 2025 mix ALL D2 (week 1 protocol / constant-mean), developed actuals: B 0.0668/0.1516, L 0.0648/0.1497, E 0.0492/0.1356, BE 0.0634/0.1485, D 0.0423/0.1293, Bor 0.0694/0.1540.
- Ceiling (perfect model, B as truth, simulated claims): W1 D2 as-is 0.1162 (p5 0.1052, p95 0.1269); constant-mean as-is 0.1514 (p5 0.1353, p95 0.1650).
- Bootstrap (developed, as-is): B - L +0.0041 (2se 0.0025) B better; B - E +0.0501 (2se 0.0125) B better; B - BE +0.0187 (2se 0.0058) B better; B - D +0.0241 (2se 0.0094) B better.

<!-- auto:9 end -->

### Step 9 verdict (by hand)

- **B (full Option B) is the best candidate on every view and the pick**, on the reweighted 2024 D2 with judgement. It significantly beats L, E, BE and D as-is (bootstrap, 200 draws); on the 2025-mix reweighting the differences vs L / E / BE are within noise, but B is never worse. The fixed 50/50 BE does not help as-is (-0.013).
- **Goal check: local D2 >= 0.25 on a developed basis is not reachable honestly.** Final B scores 0.113 (week 1 protocol) or 0.146 against the constant mean (2025-mix weighting 0.065 / 0.150). Numbers in this paragraph's diagnostics are from the run before D025; after D025 the oracle level is 0.116 / 0.148 and the ceiling 0.117 (p5-p95 0.104-0.130) / 0.149 (0.138-0.159), so B is at about 97% of the ceiling. Two diagnostics show this is a ceiling, not a modelling gap:
  1. Oracle level (B rescaled to the 2024 actual of every line x peril, using the answers): 0.116 / 0.148.
  2. Ceiling simulation (B taken as the true risk, claims simulated with the observed emerging severity spread): a perfect model scores 0.123 (p5-p95 0.111-0.138) / 0.156 (0.144-0.166).
   The week 1 ceiling study (R/4_check_ceiling.R) found the same about 0.10 limit for the developed market.


## Step 10: 2025 candidate file

<!-- auto:10 start -->
**Script** `week_2/R/10_final_week2.R` · **run** 2026-10-25 22:40:16 SGT · **run time** 0.0 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week_2/output/04_ibnr_trend/report_share_quarter.csv | 22,478 | 686c60b027e806c65310d1b6b3b7ed76 |
| week_2/data/final/main/pred_2025_peril.parquet | 101,680,145 | 14c6ada1bac356aab50d5de607af4f2d |
| data/week_2/emerging/sample_submission.parquet | 1,197,460 | fde7fa93b9907e72f581a2ae7e513aba |
| week_2/data/clean/emerging_claims_matched.parquet | 509,742 | e94de1fc19deccd5cc2624d050fd7dba |
| week_2/data/features/emerging_train_motor.parquet | 3,194,789 | 05b67be9ec72b27383fc40d710396800 |
| week_2/data/features/emerging_test_motor.parquet | 6,508,749 | 572cccb2d8a43f809a877203ee5cf342 |
| week_2/data/features/emerging_train_buildings.parquet | 1,691,768 | 082f934eb9d8b5fe9eaa47afb3546ac6 |
| week_2/data/features/emerging_test_buildings.parquet | 3,652,456 | 5c7e3102d2970cafdda423fa1dfb5ee4 |
| week_2/data/features/emerging_train_contents.parquet | 2,101,171 | 8891ac66c12252fb97c63e0055a8b17e |
| week_2/data/features/emerging_test_contents.parquet | 4,553,937 | d31e5f39d4cc63815ff4f00433576086 |
| week_2/output/08_loadings/main/sensitivity.csv | 2,983 | 4021924c138b290a6e8c4005f8207cd0 |
| week_2/output/09_validate/main/calibration.csv | 3,869 | a09890331661a4b48e3717991bc2f83b |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week_2/output/10_final/checks.csv | 126 | 2c9d53b3b98dddd6138977206b5635d9 |
| week_2/output/submission/submission_20261025_2240_week2_optionB.csv | 5,621,647 | 62f2e1cbebcda4a1e6f86a666610251c |
| week_2/output/submission/submission_20261025_2240_week2_optionB.csv.md5 | 76 | e9dd94112fbadb8348e9ef5b7da33238 |
| week_2/output/10_final/burn_by_peril.csv | 1,630 | 9d1bc5360130bbd2df58433424ac9e54 |
| week_2/output/10_final/burn_by_line.csv | 405 | b0877d8ebc90efabefcf65d5017c47f2 |
| week_2/output/10_final/uncertainty_by_line.csv | 384 | b59c5b828ad0649942891f270801d797 |
| week_2/output/10_final/final_report.md | 2,455 | d76fc3a03d2b9b9b1a270aad15444898 |

**Key numbers (from the script)**

- Candidate B file `week_2/output/submission/submission_20261025_2240_week2_optionB.csv` (MD5 `62f2e1cbebcda4a1e6f86a666610251c`), 209,063 rows, all checks passed. NOT submitted.
- 2025 burn per exposure-year (central, low-high): buildings 351 (241-504); contents 104 (97-117); motor 605 (529-661).
- 2023 / 2024 developed burn at the 2025 mix: buildings 496 / 286; contents 97 / 118; motor 821 / 519.

<!-- auto:10 end -->

## Step 11: Documentation pack

<!-- auto:11 start -->
**Script** `week_2/R/11_docs_week2.R` · **run** 2026-10-26 07:47:29 SGT · **run time** 0.0 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week_2/output/05_baseline/line_scores.csv | 1,000 | 7312b521e4c5935aab36c33bc338d750 |
| week_2/output/05_baseline/diagnostics_final.csv | 2,221 | b984db5b7056624864ff0d056c3c308a |
| week_2/output/07_adjust/levels.csv | 3,225 | 775d365830d7de92d6296a3ba7838e04 |
| week_2/output/07_adjust/factor_log.csv | 27,108 | d6a8f59d738456a4dcd97e4fc54847bc |
| week_2/output/08_loadings/main/loadings.csv | 2,989 | e123c170438ccd7755a9d83ba5e5f97a |
| week_2/output/08_loadings/main/sensitivity.csv | 2,983 | 4021924c138b290a6e8c4005f8207cd0 |
| week_2/output/09_validate/main/scorecard.csv | 8,027 | 49eed6284d85821df50f3e41dab4987d |
| week_2/output/09_validate/main/bootstrap.csv | 2,513 | 4462aa28bc00dd6fc03d473283d13cb6 |
| week_2/output/09_validate/main/ceiling_simulation.csv | 1,540 | d7b944656af8955f5234f548aa3e6b9f |
| week_2/output/09_validate/main/calibration.csv | 3,869 | a09890331661a4b48e3717991bc2f83b |
| week_2/output/10_final/burn_by_line.csv | 405 | b0877d8ebc90efabefcf65d5017c47f2 |
| week_2/output/10_final/burn_by_peril.csv | 1,630 | 9d1bc5360130bbd2df58433424ac9e54 |
| week_2/output/10_final/uncertainty_by_line.csv | 384 | b59c5b828ad0649942891f270801d797 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week_2/docs/model_card_week2.md | 10,998 | 1784f737947e6d5d04b318dd5d92d5b2 |
| week_2/docs/uncertainty.md | 5,546 | 5f96affd9f64036e7831c22df1e82acd |
| week_2/docs/doc_manifest.csv | 1,111 | 6af8e9c42bd69fbda36bfd05901f5bbf |

**Key numbers (from the script)**

- Docs: assumptions_week2.csv, assumptions_week2.xlsx, decision_register.csv, experiment_log.csv, final_model_week2.md, improvement_round_week2.md, model_card_week2.md, README_week2.md, step_log.md, submission_log_week2.md, uncertainty.md, what_changed.md, what_we_carried_over.md, what_works_week2.md, submission_20261025_2240_week2_optionB.csv.

<!-- auto:11 end -->

## Step 12: Submission log

<!-- auto:12 start -->
**Script** `week_2/R/12_submission_log.R` · **run** 2026-10-26 07:43:36 SGT · **run time** 0.0 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week_2/inputs/submissions_week2.csv | 1,384 | 2d50d2ee0d31d68edc4e316494488f4c |
| week_2/data/clean/emerging_claims_matched.parquet | 509,742 | e94de1fc19deccd5cc2624d050fd7dba |
| week_2/data/features/emerging_train_motor.parquet | 3,194,789 | 05b67be9ec72b27383fc40d710396800 |
| week_2/data/features/emerging_train_buildings.parquet | 1,691,768 | 082f934eb9d8b5fe9eaa47afb3546ac6 |
| week_2/data/features/emerging_train_contents.parquet | 2,101,171 | 8891ac66c12252fb97c63e0055a8b17e |
| week_2/data/adjust/sub1/valid_2024_peril.parquet | 12,795,935 | f660563e6fcc882e96272d60406747af |
| week_2/output/07_adjust/levels_sub1.csv | 3,180 | 9617e3500b6dc4b8eb0b7044d8eca473 |
| week_2/output/05_baseline/diagnostics_final_sub1.csv | 2,223 | 3d567936fac85a53e7beea1fb1781526 |
| week_2/output/09_validate/sub1/scorecard.csv | 8,025 | 873f8ccf46ce392fe2cf15f29bbcaba7 |
| week_2/data/adjust/sub2/valid_2024_peril.parquet | 12,999,552 | a5f8ce88718992ec70424e06916b9e13 |
| week_2/output/07_adjust/levels_sub2.csv | 3,225 | 775d365830d7de92d6296a3ba7838e04 |
| week_2/output/05_baseline/diagnostics_final_sub2.csv | 2,221 | b984db5b7056624864ff0d056c3c308a |
| week_2/output/09_validate/sub2/scorecard.csv | 8,027 | 49eed6284d85821df50f3e41dab4987d |
| week_2/data/adjust/sub3/valid_2024_peril.parquet | 17,405,485 | 93068e19ceff01097ff1174c94c3ca53 |
| week_2/output/07_adjust/levels_sub3.csv | 3,225 | 775d365830d7de92d6296a3ba7838e04 |
| week_2/output/05_baseline/diagnostics_final_sub3.csv | 2,221 | b984db5b7056624864ff0d056c3c308a |
| week_2/output/09_validate/sub3/scorecard.csv | 8,024 | 636ac869150a8b44ac8f4179c25556ed |
| week_2/data/adjust/sub4/valid_2024_peril.parquet | 13,056,834 | b8332fc84086b5e873b870a704cf0115 |
| week_2/output/07_adjust/levels_sub4.csv | 3,225 | 775d365830d7de92d6296a3ba7838e04 |
| week_2/output/05_baseline/diagnostics_final_sub4.csv | 2,221 | b984db5b7056624864ff0d056c3c308a |
| week_2/output/09_validate/sub4/scorecard.csv | 8,039 | f0892481b3bc2c257c8b5be09c427cc9 |
| week_2/data/adjust/sub5/valid_2024_peril.parquet | 13,056,834 | b74130176cb781fa559b2d5ba5b9c6a4 |
| week_2/output/07_adjust/levels_sub5.csv | 3,224 | e4e1709058ccaa54f88002844009acd8 |
| week_2/output/05_baseline/diagnostics_final_sub5.csv | 2,221 | b984db5b7056624864ff0d056c3c308a |
| week_2/output/09_validate/sub5/scorecard.csv | 8,037 | 98ba76d749fa197ab38f4a80dad0a8c8 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week_2/output/12_submission_log/peril_scores_sub1_B.csv | 3,227 | 8e6d3d4600e92d0d491b8f78d2b8728f |
| week_2/output/12_submission_log/peril_scores_sub2_B.csv | 3,212 | 3b586210572f20ad3bd04ebceb5650c8 |
| week_2/output/12_submission_log/peril_scores_sub3_B.csv | 3,211 | 29d1c8a3789b7083526594193bce6469 |
| week_2/output/12_submission_log/peril_scores_sub4_B.csv | 3,211 | 550cba010baf1b3645b78d6746f61e73 |
| week_2/output/12_submission_log/peril_scores_sub5_B.csv | 3,212 | 21f45c6b26f86008bb8df15ecabacf63 |
| week_2/docs/submission_log_week2.md | 27,151 | 935425896d3636c5830f9bbb05df16a2 |

**Key numbers (from the script)**

- #1 submission_20261025_2125_week2_optionB.csv: public 0.15604 (candidate B).
- #2 submission_20261025_2240_week2_optionB.csv: public 0.16562 (candidate B).
- #3 submission_20261026_0714_week2_optionB_x13b.csv: public 0.16432 (candidate B).
- #4 submission_20261026_0724_week2_optionB_x14e.csv: public 0.16557 (candidate B).
- #5 submission_20261026_0737_week2_optionB_x18b.csv: public 0.16612 (candidate B).

<!-- auto:12 end -->

## Step 3b: Emerging-only fields (gender, self_employed)

<!-- auto:3b start -->
**Script** `week2/R/03b_emerging_extra.R` · **run** 2026-10-27 11:17:49 SGT · **run time** 0.0 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| data/week_2/optionB/clean/emerging_train_motor.parquet | 3,714,162 | bb9bde44c10725ec350d4abc7def5513 |
| data/week_2/optionB/clean/emerging_test_motor.parquet | 7,436,217 | 2093fc9d31e42536d5149f209cc1ab94 |
| data/week_2/optionB/clean/emerging_train_buildings.parquet | 1,972,856 | c844ffa6fc65cf0b173466ef8beccbd1 |
| data/week_2/optionB/clean/emerging_test_buildings.parquet | 4,161,366 | b8539e055821e002969e76a65d67e555 |
| data/week_2/optionB/clean/emerging_train_contents.parquet | 2,416,238 | 9c151fb976c0e16674efdcc5a07f1928 |
| data/week_2/optionB/clean/emerging_test_contents.parquet | 5,115,375 | 7254a55f5765a1b2dca63273fc82f290 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| data/week_2/optionB/features/emerging_extra_train_motor.parquet | 335,942 | 359b9b588ff0c49c3cc8a65cc51ed22a |
| data/week_2/optionB/features/emerging_extra_test_motor.parquet | 630,845 | 37ba43ea3bc50440fb47bd73f6cb36b9 |
| data/week_2/optionB/features/emerging_extra_train_buildings.parquet | 191,543 | c707e6ae4c7b5f80afc8342a1fc079ba |
| data/week_2/optionB/features/emerging_extra_test_buildings.parquet | 374,698 | 49963fafd5406b86763b5b1846aaf248 |
| data/week_2/optionB/features/emerging_extra_train_contents.parquet | 246,002 | 3988fbb3291451760c450f3795eb9179 |
| data/week_2/optionB/features/emerging_extra_test_contents.parquet | 470,690 | 596dfe2d577f2f7c06f4ed153513750a |

**Key numbers (from the script)**

- gender approved by Wendy; kept out of the developed baseline, offered to step 7 only.

<!-- auto:3b end -->

## Step 5-baseline_loc: Baseline variant baseline_loc

<!-- auto:5-baseline_loc start -->
**Script** `week_2/R/05_developed_baseline.R` · **run** 2026-10-25 22:03:34 SGT · **run time** 6.9 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| docs/assumptions_wendy07_final2.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| week_2/data/clean/developed_claims_matched.parquet | 8,295,706 | 80cf63199cbc3ad375ecbbda37cb4db8 |
| week_2/output/04_ibnr_trend/report_share_quarter.csv | 22,478 | 686c60b027e806c65310d1b6b3b7ed76 |
| week_2/data/features/developed_train_motor.parquet | 69,448,809 | 8189cc5cea6958f03b71ea9e2e896f1d |
| week_2/data/features/developed_train_buildings.parquet | 46,038,165 | 6b55c4b6f058a7ba0f1f3c5ca002154a |
| week_2/data/features/developed_train_contents.parquet | 46,577,493 | 3558cf2127c468bef972ce849a867a80 |
| week_2/data/features/emerging_train_motor.parquet | 3,194,789 | 05b67be9ec72b27383fc40d710396800 |
| week_2/data/features/emerging_test_motor.parquet | 6,508,749 | 572cccb2d8a43f809a877203ee5cf342 |
| week_2/data/features/developed_test_motor.parquet | 17,516,894 | d1616ad05a75f6c0f60c5244981e29c7 |
| week_2/data/features/emerging_train_buildings.parquet | 1,691,768 | 082f934eb9d8b5fe9eaa47afb3546ac6 |
| week_2/data/features/emerging_test_buildings.parquet | 3,652,456 | 5c7e3102d2970cafdda423fa1dfb5ee4 |
| week_2/data/features/developed_test_buildings.parquet | 12,204,941 | 836a4adbebcc225d61cd16bff2b6dc2e |
| week_2/data/features/emerging_train_contents.parquet | 2,101,171 | 8891ac66c12252fb97c63e0055a8b17e |
| week_2/data/features/emerging_test_contents.parquet | 4,553,937 | d31e5f39d4cc63815ff4f00433576086 |
| week_2/data/features/developed_test_contents.parquet | 12,344,921 | 47ad96a1623e414dc48aa2f5fa05f0fc |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week_2/inputs/assumptions_week2_baseline_loc.xlsx | 120,215 | 8c5ea90af2560d273cfc11a986cf88d0 |
| week_2/output/05_baseline_loc/row_preds.parquet | 85,489,315 | b4a61b8a85a215d3072e2043001c7e9e |
| week_2/output/05_baseline_loc/line_scores.csv | 1,002 | b3c73c34c92c8f35b7872765af8b9fb7 |
| week_2/output/05_baseline_loc/peril_scores.csv | 4,369 | 7e9958bd36f0676bb6e085a4481b2051 |
| week_2/output/05_baseline_loc/diagnostics_validation.csv | 4,470 | b5b1d4a204d5eb79a1692d3fd80ab928 |
| week_2/data/baseline_loc/baseline_emerging_train.parquet | 9,364,429 | 46d9154774d0afae8552a15b9db9b60b |
| week_2/data/baseline_loc/baseline_emerging_test.parquet | 17,607,724 | 7f34cf4fa442a33dce70bbe6b46755a3 |
| week_2/output/05_baseline_loc/diagnostics_final.csv | 2,222 | 2a3e17d4293981eeeaa28bb116d35640 |
| week_2/output/05_baseline_loc/baseline_burn.csv | 1,123 | c57bfc23f8547262c9d7223625fd05b7 |
| week_2/output/05_baseline_loc/replication_check.csv | 347 | dfc17141d82aea698f9bb54e5cac84ad |
| week_2/output/05_baseline_loc/features_used.csv | 13,448 | e0df920cfa8aefa1f5780f4722144982 |
| week_2/output/05_baseline_loc/structural_zero_check.csv | 416 | 07103f13da39808be6505f18248e8e17 |
| week_2/output/05_baseline_loc/workbook_edits.csv | 1,198 | 8c516542f64b72e087d55dfee657481c |
| week_2/models/baseline_loc/model_card.md | 6,294 | 4496bc018a9f6d83bee628dff941b4c2 |

**Key numbers (from the script)**

- Developed validation mean 2023-24 D2, reported_raw: motor 0.0347, buildings 0.0724, contents 0.0639, ALL 0.0962; developed: motor 0.0470, buildings 0.0712, contents 0.0640, ALL 0.1025 (week 1 C5 ALL reported_raw 0.1026).
- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 714.0, buildings 552.2, contents 127.2.

<!-- auto:5-baseline_loc end -->

## Step 5-baseline_pool23: Baseline variant baseline_pool23

<!-- auto:5-baseline_pool23 start -->
**Script** `week_2/R/05_developed_baseline.R` · **run** 2026-10-25 22:16:35 SGT · **run time** 4.8 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| docs/assumptions_wendy07_final2.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| week_2/data/clean/developed_claims_matched.parquet | 8,295,706 | 80cf63199cbc3ad375ecbbda37cb4db8 |
| week_2/data/clean/emerging_claims_matched.parquet | 509,742 | e94de1fc19deccd5cc2624d050fd7dba |
| week_2/output/04_ibnr_trend/report_share_quarter.csv | 22,478 | 686c60b027e806c65310d1b6b3b7ed76 |
| week_2/data/features/developed_train_motor.parquet | 69,448,809 | 8189cc5cea6958f03b71ea9e2e896f1d |
| week_2/data/features/developed_train_buildings.parquet | 46,038,165 | 6b55c4b6f058a7ba0f1f3c5ca002154a |
| week_2/data/features/developed_train_contents.parquet | 46,577,493 | 3558cf2127c468bef972ce849a867a80 |
| week_2/data/features/emerging_train_motor.parquet | 3,194,789 | 05b67be9ec72b27383fc40d710396800 |
| week_2/data/features/emerging_extra_train_motor.parquet | 337,521 | 0250af69acd27f2ae6bfea3bc5d26eb1 |
| week_2/data/features/emerging_test_motor.parquet | 6,508,749 | 572cccb2d8a43f809a877203ee5cf342 |
| week_2/data/features/emerging_extra_test_motor.parquet | 635,015 | b11ae2dd388936ae458f0890d331ab2f |
| week_2/data/features/developed_test_motor.parquet | 17,516,894 | d1616ad05a75f6c0f60c5244981e29c7 |
| week_2/data/features/emerging_train_buildings.parquet | 1,691,768 | 082f934eb9d8b5fe9eaa47afb3546ac6 |
| week_2/data/features/emerging_extra_train_buildings.parquet | 190,934 | af0720b0abaf8089718b4ecb823433df |
| week_2/data/features/emerging_test_buildings.parquet | 3,652,456 | 5c7e3102d2970cafdda423fa1dfb5ee4 |
| week_2/data/features/emerging_extra_test_buildings.parquet | 379,069 | 39917cc0cd0a2b8646d2e564768e5105 |
| week_2/data/features/developed_test_buildings.parquet | 12,204,941 | 836a4adbebcc225d61cd16bff2b6dc2e |
| week_2/data/features/emerging_train_contents.parquet | 2,101,171 | 8891ac66c12252fb97c63e0055a8b17e |
| week_2/data/features/emerging_extra_train_contents.parquet | 247,730 | 1c3a4b128924c9360700795d49b869d2 |
| week_2/data/features/emerging_test_contents.parquet | 4,553,937 | d31e5f39d4cc63815ff4f00433576086 |
| week_2/data/features/emerging_extra_test_contents.parquet | 469,960 | 4d23063a77c18c4a4fed9b237b848c40 |
| week_2/data/features/developed_test_contents.parquet | 12,344,921 | 47ad96a1623e414dc48aa2f5fa05f0fc |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week_2/inputs/assumptions_week2_baseline_pool23.xlsx | 120,215 | 0f452b3e539a63860aaa2b0a66c37f9e |
| week_2/data/baseline_pool23/baseline_emerging_train.parquet | 9,481,147 | 61285554117f4b7c29362f1907f8ddd1 |
| week_2/data/baseline_pool23/baseline_emerging_test.parquet | 17,760,249 | a36f312cf371e261b3e1ec59d3238c34 |
| week_2/output/05_baseline_pool23/diagnostics_final.csv | 2,223 | 00b4d6d27095fb58e9bbd9568d46ab26 |
| week_2/output/05_baseline_pool23/baseline_burn.csv | 1,126 | 0bf9b6bb9dcc7857aad3f4d9905d45c7 |
| week_2/output/05_baseline_pool23/replication_check.csv | 347 | dfc17141d82aea698f9bb54e5cac84ad |
| week_2/output/05_baseline_pool23/features_used.csv | 13,528 | f6ae48bbe5491be12103640633047424 |
| week_2/output/05_baseline_pool23/structural_zero_check.csv | 416 | 07103f13da39808be6505f18248e8e17 |
| week_2/output/05_baseline_pool23/workbook_edits.csv | 1,198 | 8c516542f64b72e087d55dfee657481c |
| week_2/models/baseline_pool23/model_card.md | 4,552 | bb18984c1ebee8da194da2b1fb843d13 |

**Key numbers (from the script)**

- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 534.8, buildings 584.0, contents 110.0.

<!-- auto:5-baseline_pool23 end -->

## Step 5-baseline_pool24: Baseline variant baseline_pool24

<!-- auto:5-baseline_pool24 start -->
**Script** `week_2/R/05_developed_baseline.R` · **run** 2026-10-25 22:21:11 SGT · **run time** 4.6 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| docs/assumptions_wendy07_final2.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| week_2/data/clean/developed_claims_matched.parquet | 8,295,706 | 80cf63199cbc3ad375ecbbda37cb4db8 |
| week_2/data/clean/emerging_claims_matched.parquet | 509,742 | e94de1fc19deccd5cc2624d050fd7dba |
| week_2/output/04_ibnr_trend/report_share_quarter.csv | 22,478 | 686c60b027e806c65310d1b6b3b7ed76 |
| week_2/data/features/developed_train_motor.parquet | 69,448,809 | 8189cc5cea6958f03b71ea9e2e896f1d |
| week_2/data/features/developed_train_buildings.parquet | 46,038,165 | 6b55c4b6f058a7ba0f1f3c5ca002154a |
| week_2/data/features/developed_train_contents.parquet | 46,577,493 | 3558cf2127c468bef972ce849a867a80 |
| week_2/data/features/emerging_train_motor.parquet | 3,194,789 | 05b67be9ec72b27383fc40d710396800 |
| week_2/data/features/emerging_extra_train_motor.parquet | 337,521 | 0250af69acd27f2ae6bfea3bc5d26eb1 |
| week_2/data/features/emerging_test_motor.parquet | 6,508,749 | 572cccb2d8a43f809a877203ee5cf342 |
| week_2/data/features/emerging_extra_test_motor.parquet | 635,015 | b11ae2dd388936ae458f0890d331ab2f |
| week_2/data/features/developed_test_motor.parquet | 17,516,894 | d1616ad05a75f6c0f60c5244981e29c7 |
| week_2/data/features/emerging_train_buildings.parquet | 1,691,768 | 082f934eb9d8b5fe9eaa47afb3546ac6 |
| week_2/data/features/emerging_extra_train_buildings.parquet | 190,934 | af0720b0abaf8089718b4ecb823433df |
| week_2/data/features/emerging_test_buildings.parquet | 3,652,456 | 5c7e3102d2970cafdda423fa1dfb5ee4 |
| week_2/data/features/emerging_extra_test_buildings.parquet | 379,069 | 39917cc0cd0a2b8646d2e564768e5105 |
| week_2/data/features/developed_test_buildings.parquet | 12,204,941 | 836a4adbebcc225d61cd16bff2b6dc2e |
| week_2/data/features/emerging_train_contents.parquet | 2,101,171 | 8891ac66c12252fb97c63e0055a8b17e |
| week_2/data/features/emerging_extra_train_contents.parquet | 247,730 | 1c3a4b128924c9360700795d49b869d2 |
| week_2/data/features/emerging_test_contents.parquet | 4,553,937 | d31e5f39d4cc63815ff4f00433576086 |
| week_2/data/features/emerging_extra_test_contents.parquet | 469,960 | 4d23063a77c18c4a4fed9b237b848c40 |
| week_2/data/features/developed_test_contents.parquet | 12,344,921 | 47ad96a1623e414dc48aa2f5fa05f0fc |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week_2/inputs/assumptions_week2_baseline_pool24.xlsx | 120,215 | 2eef4133dc40f0f978aed2add3fca245 |
| week_2/data/baseline_pool24/baseline_emerging_train.parquet | 9,338,298 | 47bd3fc755b7add68fa4794fb5838f52 |
| week_2/data/baseline_pool24/baseline_emerging_test.parquet | 17,527,362 | 2eb696c182857d09b5e6bcca7c22bf96 |
| week_2/output/05_baseline_pool24/diagnostics_final.csv | 2,218 | 485966a445fe9fb7f21a60da97754af2 |
| week_2/output/05_baseline_pool24/baseline_burn.csv | 1,124 | 7ff562304c2967f0688716cf917be0d9 |
| week_2/output/05_baseline_pool24/replication_check.csv | 347 | dfc17141d82aea698f9bb54e5cac84ad |
| week_2/output/05_baseline_pool24/features_used.csv | 13,528 | f6ae48bbe5491be12103640633047424 |
| week_2/output/05_baseline_pool24/structural_zero_check.csv | 416 | 07103f13da39808be6505f18248e8e17 |
| week_2/output/05_baseline_pool24/workbook_edits.csv | 1,198 | 8c516542f64b72e087d55dfee657481c |
| week_2/models/baseline_pool24/model_card.md | 4,550 | f3aeee8ed4381641ca0c5552c3e2215e |

**Key numbers (from the script)**

- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 554.7, buildings 464.1, contents 105.9.

<!-- auto:5-baseline_pool24 end -->


## Improvement round (25 Oct 2026, after submission #1 = 0.15604 public)

Wendy approved gender, explained reference_policies (20 policies for the premium build-up; not used), and asked to try every idea and keep only what improves. Full table and reasoning: `week_2/docs/improvement_round_week2.md`; every comparison: `week_2/docs/experiment_log.csv`; gate script `week_2/R/13_compare_runs.R` (constant-mean D2, developed actuals, 2024 at the 2025 mix; paired bootstrap).

- Adopted: X1 gender / self_employed as emerging candidates (D027), X8 5-bag baseline (D028), X10 level credibility K 200/400 and factor ridge lambda 30 (D029). All now the script defaults; main rebuilt and checked identical to the X10 run.
- Reverted (D030): mix-weighted fitting, lighter K for rich perils, emerging-only severity, banded and smooth severity range multipliers, boosted emerging residual, motor location baseline, pooled developed + emerging baseline.
- Net: public proxy 0.14996 -> 0.15160; as-is 0.14551 -> 0.14975. Developed validation with 5 bags: ALL 0.0976 (1 bag 0.0965).
- Script fixes during the round: step 5 tagged outputs for variants (RUN_TAG), MOTOR_LOC / POOLED_YEAR / BAGS options; step 7 experiment switches; step 9 saves row predictions; step 12 reads a frozen run per submission (sub1).
## Step 3c: X21 emerging-only fields (credit_tier, region, n_lines, val_age_b, bldg_age_b, miss_n, va_missing)

<!-- auto:3c start -->
**Script** `week2/R/03c_emerging_extra2.R` · **run** 2026-10-27 14:43:23 SGT · **run time** 0.4 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| data/week_2/optionB/clean/emerging_train_motor.parquet | 3,714,162 | bb9bde44c10725ec350d4abc7def5513 |
| data/week_2/optionB/clean/emerging_test_motor.parquet | 7,436,217 | 2093fc9d31e42536d5149f209cc1ab94 |
| data/week_2/optionB/clean/emerging_train_buildings.parquet | 1,972,856 | c844ffa6fc65cf0b173466ef8beccbd1 |
| data/week_2/optionB/clean/emerging_test_buildings.parquet | 4,161,366 | b8539e055821e002969e76a65d67e555 |
| data/week_2/optionB/clean/emerging_train_contents.parquet | 2,416,238 | 9c151fb976c0e16674efdcc5a07f1928 |
| data/week_2/optionB/clean/emerging_test_contents.parquet | 5,115,375 | 7254a55f5765a1b2dca63273fc82f290 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| data/week_2/optionB/features/emerging_extra2_train_motor.parquet | 433,435 | 5a9995b438aef6679b174e639b981482 |
| data/week_2/optionB/features/emerging_extra2_test_motor.parquet | 831,195 | ef91695be8c75aa06d45e3bbe1fecefb |
| data/week_2/optionB/features/emerging_extra2_train_buildings.parquet | 239,789 | c9504f3bd267352e4402cb7a77c6e484 |
| data/week_2/optionB/features/emerging_extra2_test_buildings.parquet | 465,810 | bdc7ad443f511f6560f192abbdf7b2fb |
| data/week_2/optionB/features/emerging_extra2_train_contents.parquet | 300,466 | 1ac573a9335904a37f58a51468944feb |
| data/week_2/optionB/features/emerging_extra2_test_contents.parquet | 594,765 | 82223b8aef6b00a16f4d00f4b14e5507 |

**Key numbers (from the script)**

- Offered to step 7 only through X_NEW; developed baseline unchanged.

<!-- auto:3c end -->

## Step 5-m0ctl: Baseline variant m0ctl

<!-- auto:5-m0ctl start -->
**Script** `week2/R/05_developed_baseline.R` · **run** 2026-10-30 08:00:13 SGT · **run time** 18.0 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week1/docs/assumptions_wendy07_final2.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/developed_test_motor.parquet | 17,652,719 | 03fb8840d762c392715da9f7e703f895 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/inputs/assumptions_week2_m0ctl.xlsx | 120,238 | 4d4d380b89db5764f5a297fc6cc6a378 |
| data/week_2/optionB/m0ctl/baseline_emerging_train.parquet | 3,838,749 | e94cbaf501d1a645b21e78ae9fc67fad |
| data/week_2/optionB/m0ctl/baseline_emerging_test.parquet | 7,262,095 | fefc15dbb7829d6aa5b4af34cce823df |
| week2/output/05_m0ctl/diagnostics_final.csv | 840 | 8aa96d01d0e0b222b7284677ad981da4 |
| week2/output/05_m0ctl/baseline_burn.csv | 416 | 9f56e49138dac7c02ac03670650a273b |
| week2/output/05_m0ctl/replication_check.csv | 129 | 4075da15ee29fbf61d61e2dd4eb4bf48 |
| week2/output/05_m0ctl/features_used.csv | 4,421 | 8fd1d345bcf081b490a4a7e448a2b2b4 |
| week2/output/05_m0ctl/structural_zero_check.csv | 270 | fea2f3e6b1f5068a9acabc638b688b0f |
| week2/output/05_m0ctl/workbook_edits.csv | 1,217 | d47e853741f25fa33f98e10888f7fc11 |
| week2/models/m0ctl/model_card.md | 2,886 | 9acef0e0010d90004348382d8715e3c8 |

**Key numbers (from the script)**

- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 763.3.

<!-- auto:5-m0ctl end -->

## Step 5-m3cap: Baseline variant m3cap

<!-- auto:5-m3cap start -->
**Script** `week2/R/05_developed_baseline.R` · **run** 2026-10-30 08:10:37 SGT · **run time** 21.9 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week1/docs/assumptions_wendy07_final2.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/developed_test_motor.parquet | 17,652,719 | 03fb8840d762c392715da9f7e703f895 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/inputs/assumptions_week2_m3cap.xlsx | 120,238 | 54fc06f8d3d7dd124090f8ddb585eeb4 |
| data/week_2/optionB/m3cap/baseline_emerging_train.parquet | 3,838,749 | 24f4c82a7f9a93d7a5d1f5cfd4c4bec5 |
| data/week_2/optionB/m3cap/baseline_emerging_test.parquet | 7,262,095 | f186a9b4488b8d0bc3b50f345de2edf7 |
| week2/output/05_m3cap/diagnostics_final.csv | 841 | 05ae7f8aadef21efcb2d4ac9e412b600 |
| week2/output/05_m3cap/baseline_burn.csv | 418 | 87821a2d1f117dd2f0666e042c406773 |
| week2/output/05_m3cap/replication_check.csv | 129 | 4075da15ee29fbf61d61e2dd4eb4bf48 |
| week2/output/05_m3cap/features_used.csv | 4,421 | 8fd1d345bcf081b490a4a7e448a2b2b4 |
| week2/output/05_m3cap/structural_zero_check.csv | 270 | fea2f3e6b1f5068a9acabc638b688b0f |
| week2/output/05_m3cap/workbook_edits.csv | 1,217 | d47e853741f25fa33f98e10888f7fc11 |
| week2/models/m3cap/model_card.md | 2,886 | 23a9abd34e486988993d7884828bee71 |

**Key numbers (from the script)**

- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 763.8.

<!-- auto:5-m3cap end -->

## Step 5-m5mono: Baseline variant m5mono

<!-- auto:5-m5mono start -->
**Script** `week2/R/05_developed_baseline.R` · **run** 2026-10-30 08:10:40 SGT · **run time** 21.7 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week1/docs/assumptions_wendy07_final2.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/developed_test_motor.parquet | 17,652,719 | 03fb8840d762c392715da9f7e703f895 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/inputs/assumptions_week2_m5mono.xlsx | 120,238 | 89e6f75ec048de0086475d3c86bfc22e |
| data/week_2/optionB/m5mono/baseline_emerging_train.parquet | 3,828,101 | 49386ca3dbd07fccec0f204bb64e0ac3 |
| data/week_2/optionB/m5mono/baseline_emerging_test.parquet | 7,226,974 | b9627d04fa035ecdc348c8e2e7bf045d |
| week2/output/05_m5mono/diagnostics_final.csv | 840 | bf31ef3a8e76e183986f1b865b97da67 |
| week2/output/05_m5mono/baseline_burn.csv | 418 | 79d689cca91434b239905125447a7a5a |
| week2/output/05_m5mono/replication_check.csv | 129 | 4075da15ee29fbf61d61e2dd4eb4bf48 |
| week2/output/05_m5mono/features_used.csv | 4,426 | 548d55ba375a468b5858cbbcdaec73d0 |
| week2/output/05_m5mono/structural_zero_check.csv | 270 | fea2f3e6b1f5068a9acabc638b688b0f |
| week2/output/05_m5mono/workbook_edits.csv | 1,217 | d47e853741f25fa33f98e10888f7fc11 |
| week2/models/m5mono/model_card.md | 2,887 | 3e1554d2791e78787c9d61d5b54b7911 |

**Key numbers (from the script)**

- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 763.5.

<!-- auto:5-m5mono end -->

## Step 5-m6yw: Baseline variant m6yw

<!-- auto:5-m6yw start -->
**Script** `week2/R/05_developed_baseline.R` · **run** 2026-10-30 08:10:49 SGT · **run time** 21.6 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week1/docs/assumptions_wendy07_final2.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/developed_test_motor.parquet | 17,652,719 | 03fb8840d762c392715da9f7e703f895 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/inputs/assumptions_week2_m6yw.xlsx | 120,238 | fd18d150114534ddf09f909b9b459aca |
| data/week_2/optionB/m6yw/baseline_emerging_train.parquet | 3,839,326 | 02436b3d8dc3d511c76e3070d590ff4c |
| data/week_2/optionB/m6yw/baseline_emerging_test.parquet | 7,262,843 | 9356740ab5fd22b68067513ca0ee4fe1 |
| week2/output/05_m6yw/diagnostics_final.csv | 841 | 73929c170cda7ca9bd202f532a2de713 |
| week2/output/05_m6yw/baseline_burn.csv | 419 | ee0d3478f522efd645ce3438054a2db6 |
| week2/output/05_m6yw/replication_check.csv | 129 | 4075da15ee29fbf61d61e2dd4eb4bf48 |
| week2/output/05_m6yw/features_used.csv | 4,421 | 8fd1d345bcf081b490a4a7e448a2b2b4 |
| week2/output/05_m6yw/structural_zero_check.csv | 270 | fea2f3e6b1f5068a9acabc638b688b0f |
| week2/output/05_m6yw/workbook_edits.csv | 1,217 | d47e853741f25fa33f98e10888f7fc11 |
| week2/models/m6yw/model_card.md | 2,885 | b89261e4ac998f14485e7e0e13ed1710 |

**Key numbers (from the script)**

- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 764.5.

<!-- auto:5-m6yw end -->

## Step 5-m4bags15: Baseline variant m4bags15

<!-- auto:5-m4bags15 start -->
**Script** `week2/R/05_developed_baseline.R` · **run** 2026-10-30 08:17:51 SGT · **run time** 36.0 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week1/docs/assumptions_wendy07_final2.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/developed_test_motor.parquet | 17,652,719 | 03fb8840d762c392715da9f7e703f895 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/inputs/assumptions_week2_m4bags15.xlsx | 120,239 | fbc43ebbcac3e787da47877f3c5a57e6 |
| data/week_2/optionB/m4bags15/baseline_emerging_train.parquet | 3,844,178 | 3ab714b5c5c8a06a28600434c2a46a17 |
| data/week_2/optionB/m4bags15/baseline_emerging_test.parquet | 7,277,871 | 4232089b2339a2fa9b3c9a9293c71704 |
| week2/output/05_m4bags15/diagnostics_final.csv | 840 | 8b877db3f72ebc6d6c8a528243287f6d |
| week2/output/05_m4bags15/baseline_burn.csv | 419 | 047609d300ee44dd77173a34f0f6526c |
| week2/output/05_m4bags15/replication_check.csv | 129 | 4075da15ee29fbf61d61e2dd4eb4bf48 |
| week2/output/05_m4bags15/features_used.csv | 4,421 | 8fd1d345bcf081b490a4a7e448a2b2b4 |
| week2/output/05_m4bags15/structural_zero_check.csv | 270 | fea2f3e6b1f5068a9acabc638b688b0f |
| week2/output/05_m4bags15/workbook_edits.csv | 1,218 | 7880c1509ddaf73595681a863f4e7708 |
| week2/models/m4bags15/model_card.md | 2,892 | 815b31424a2057d4b04c19bd33d5ac10 |

**Key numbers (from the script)**

- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 760.5.

<!-- auto:5-m4bags15 end -->

## Step 5-m56: Baseline variant m56

<!-- auto:5-m56 start -->
**Script** `week2/R/05_developed_baseline.R` · **run** 2026-10-30 08:28:07 SGT · **run time** 10.1 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week1/docs/assumptions_wendy07_final2.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/developed_test_motor.parquet | 17,652,719 | 03fb8840d762c392715da9f7e703f895 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/inputs/assumptions_week2_m56.xlsx | 120,238 | 5ab7e7a329d5af570d81b00ef2503b6c |
| data/week_2/optionB/m56/baseline_emerging_train.parquet | 3,829,038 | e16e1c3c0a0f02aa34ed6e107db77e7e |
| data/week_2/optionB/m56/baseline_emerging_test.parquet | 7,225,808 | 6cf8cd1b6632bf8d21a89dfef835625e |
| week2/output/05_m56/diagnostics_final.csv | 840 | cf6a50e13c8dc25698a3196b9ad7e5cb |
| week2/output/05_m56/baseline_burn.csv | 420 | 63e8b985ed87eed5686445e1add694a6 |
| week2/output/05_m56/replication_check.csv | 129 | 4075da15ee29fbf61d61e2dd4eb4bf48 |
| week2/output/05_m56/features_used.csv | 4,426 | 548d55ba375a468b5858cbbcdaec73d0 |
| week2/output/05_m56/structural_zero_check.csv | 270 | fea2f3e6b1f5068a9acabc638b688b0f |
| week2/output/05_m56/workbook_edits.csv | 1,217 | d47e853741f25fa33f98e10888f7fc11 |
| week2/models/m56/model_card.md | 2,884 | 28222e6786478f43c8fe53d8e0a8854d |

**Key numbers (from the script)**

- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 765.7.

<!-- auto:5-m56 end -->

## Step 5-m6b: Baseline variant m6b

<!-- auto:5-m6b start -->
**Script** `week2/R/05_developed_baseline.R` · **run** 2026-10-30 08:28:14 SGT · **run time** 10.0 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week1/docs/assumptions_wendy07_final2.xlsx | 118,158 | 422a8e964874cafe1758ed111be074d9 |
| data/week_2/optionB/clean/developed_claims_matched.parquet | 8,377,901 | 4137db368597b152c9b5197c33486ded |
| week2/output/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/features/developed_train_motor.parquet | 70,014,328 | 859cd2afc8d556c32b1aa36a108712d0 |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_test_motor.parquet | 6,556,049 | f67474755d072d8bac80672693e6acbf |
| data/week_2/optionB/features/developed_test_motor.parquet | 17,652,719 | 03fb8840d762c392715da9f7e703f895 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2/inputs/assumptions_week2_m6b.xlsx | 120,238 | 2052dc4ea878ff733d9de892d27c75e4 |
| data/week_2/optionB/m6b/baseline_emerging_train.parquet | 3,837,008 | bbbb3ad943130dc3b2138907e5b10418 |
| data/week_2/optionB/m6b/baseline_emerging_test.parquet | 7,254,938 | 4f71987ca67364ff20addde898e37cd8 |
| week2/output/05_m6b/diagnostics_final.csv | 843 | accccfa9fe4271feb8ef6de517a2dac0 |
| week2/output/05_m6b/baseline_burn.csv | 418 | 5ed03437defba7b8b0c69a229e3fcdae |
| week2/output/05_m6b/replication_check.csv | 129 | 4075da15ee29fbf61d61e2dd4eb4bf48 |
| week2/output/05_m6b/features_used.csv | 4,421 | 8fd1d345bcf081b490a4a7e448a2b2b4 |
| week2/output/05_m6b/structural_zero_check.csv | 270 | fea2f3e6b1f5068a9acabc638b688b0f |
| week2/output/05_m6b/workbook_edits.csv | 1,217 | d47e853741f25fa33f98e10888f7fc11 |
| week2/models/m6b/model_card.md | 2,884 | 54a91e00d3777a0253c41d642411ac50 |

**Key numbers (from the script)**

- Replication of saved models: max abs diff 0.00e+00.
- Emerging test burn at developed level, by line: motor 764.7.

<!-- auto:5-m6b end -->

