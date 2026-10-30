# Week 2 step log (emerging market, Option B)

One section per step. The `auto` blocks are written by the scripts (inputs and outputs with MD5,
run time, key numbers); the decision text around them is written by hand.

## Step 6: Score emerging with the baseline (A/E)

<!-- auto:6 start -->
**Script** `week2/R/06_score_emerging_baseline.R` · **run** 2026-10-28 19:45:05 SGT · **run time** 0.1 min

**Inputs**

| file | bytes | md5 |
|---|---|---|
| week2\week1_retune\output\chain_b8_combo_f/04_ibnr_trend/report_share_quarter.csv | 22,719 | 82013916997649854ee1cb21fe868769 |
| data/week_2/optionB/clean/emerging_claims_matched.parquet | 512,923 | 1588dcfe42835f5c380b2d623e421775 |
| data/week_2/week1_retune/b8_combo_f/baseline_emerging_train.parquet | 9,722,050 | c25ebe70871fa1bda44e66a431d370e4 |
| week2\week1_retune/output/b8_combo_f/diagnostics_final.csv | 2,238 | 7e84b9cb0bc9b46254045a1ceac581ab |
| data/week_2/optionB/features/emerging_train_motor.parquet | 3,206,923 | ae038e95a5f0718f9b0f7541c84019cf |
| data/week_2/optionB/features/emerging_train_buildings.parquet | 1,700,814 | e4b352330c75e3c79f9e0df09e6a697d |
| data/week_2/optionB/features/emerging_train_contents.parquet | 2,109,480 | 19008e4596d174d35c5190636c6e4555 |

**Outputs**

| file | bytes | md5 |
|---|---|---|
| week2\week1_retune\output\chain_b8_combo_f/06_ae/ae_line_peril.csv | 9,407 | 14d0582e50248dfed593911acda96020 |
| week2\week1_retune\output\chain_b8_combo_f/06_ae/ae_factor.csv | 48,150 | abda3de1eca76ef3852b33c2072fe4c2 |
| week2\week1_retune\output\chain_b8_combo_f/06_ae/ae_slopes.csv | 7,109 | 90bad1e0818c6c7da2ceb6e6ca136f12 |
| week2\week1_retune\output\chain_b8_combo_f/06_ae/ae_motor_factors.png | 19,417 | 9088189db32f1104e3dfccff87b7f912 |
| week2\week1_retune\output\chain_b8_combo_f/06_ae/ae_buildings_factors.png | 13,366 | 890e4ee0116832947daabd71301ccb86 |
| week2\week1_retune\output\chain_b8_combo_f/06_ae/ae_contents_factors.png | 8,573 | 9e80e152b47990c642b5d210bdf96ebd |
| week2\week1_retune\output\chain_b8_combo_f/06_ae/ae_report.md | 37,368 | 06500e589605076b9d45f6b040762cd1 |

**Key numbers (from the script)**

- Frequency A/E (2023-24, reported basis) by peril: b/accidental_damage 0.81, b/escape_of_water 0.91, b/fire 1.20, b/flood 0.75, b/storm 1.39, b/subsidence 1.05, c/accidental_damage 0.84, c/escape_of_water 0.87, c/flood 0.83, c/theft 1.10, m/bodily_injury 1.23, m/glass_hail 1.26, m/own_damage 1.12, m/theft 1.37, m/third_party_prop 1.28.
- Capped severity A/E by peril: b/accidental_damage 0.70, b/escape_of_water 0.55, b/fire 1.22, b/flood 0.70, b/storm 0.62, b/subsidence 0.58, c/accidental_damage 0.78, c/escape_of_water 0.77, c/flood 0.85, c/theft 0.78, m/bodily_injury 0.54, m/glass_hail 0.58, m/own_damage 0.62, m/theft 0.64, m/third_party_prop 0.55.
- Factors with a significant A/E slope (p < 0.01): buildings:construction_type, motor:occupation, motor:voluntary_excess.

<!-- auto:6 end -->

