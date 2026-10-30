# Week 2 submission log (emerging market)

Generated 2026-10-26 07:43:35 SGT by `week_2/R/12_submission_log.R` from `week_2/inputs/submissions_week2.csv` and the step 7 / 9 outputs.

## Submissions

| date | file | candidate | run_tag | public_score | note |
|---|---|---|---|---|---|
| 2026-10-25 | submission_20261025_2125_week2_optionB.csv | B | sub1 | 0.15604 | submitted by Wendy as submission_20261025_2125_week2_optionB_mactest.csv (byte-identical copy, Mac run) |
| 2026-10-26 | submission_20261025_2240_week2_optionB.csv | B | sub2 | 0.16562 | submitted by Wendy as submission_20261025_2240_week2_optionB_mactest.csv (byte-identical copy); main rebuilt with X1 gender + X8 5 bags + X10 K 200/400, lambda 30 |
| 2026-10-26 | submission_20261026_0714_week2_optionB_x13b.csv | B | sub3 | 0.16432 | submitted by Wendy as submission_20261026_0714_week2_optionB_x13b_mactest.csv (byte-identical copy); #2 with motor severity = 50/50 geometric blend of developed shape x level and emerging-only GLM (X13b) |
| 2026-10-26 | submission_20261026_0724_week2_optionB_x14e.csv | B | sub4 | 0.16557 | submitted by Wendy as submission_20261026_0724_week2_optionB_x14e_mactest.csv (byte-identical copy); #2 with 50/50 emerging severity shape on motor OD, glass, BI and contents EoW (CV-picked), each peril relevelled to #2's total (X14e); public board 2nd of field (best 0.17182) |
| 2026-10-26 | submission_20261026_0737_week2_optionB_x18b.csv | B | sub5 | 0.16612 | submitted by Wendy as submission_20261026_0737_week2_optionB_x18b_mactest.csv (byte-identical copy); #4 with motor frequency trend floored at 0 in fit and 2025 projection (X18b); motor 2025 burn +3.0%; best public score |


## #1 submission_20261025_2125_week2_optionB.csv - candidate B, public 0.15604

- File MD5 `98fc357cf004a2b04d2f972998401d3b`; submitted by Wendy as submission_20261025_2125_week2_optionB_mactest.csv (byte-identical copy, Mac run).
- Local fold: fit on emerging 2023 (baseline on developed 2021-24), score emerging 2024 (25.6k motor, 14.9k buildings, 18.7k contents rows).

### Line D2

d2_w1 = week 1 protocol (baseline: one cost rate per exposure-year); d2_const = Tweedie D2 against the constant mean (Kaggle / sklearn formula). mix_2025 = 2024 rows reweighted to the 2025 new-business x channel mix.

| weighting | basis | line | d2_w1 | d2_const | pred_vs_actual |
|---|---|---|---|---|---|
| as_is | reported_raw | ALL | 0.1042 | 0.1338 | 1.2046 |
| as_is | developed | ALL | 0.1127 | 0.1455 | 1.0429 |
| as_is | reported_raw | motor | 0.0358 | 0.0857 | 1.1847 |
| as_is | developed | motor | 0.0380 | 0.0914 | 0.9690 |
| as_is | reported_raw | buildings | 0.0925 | 0.0934 | 1.3012 |
| as_is | developed | buildings | 0.0965 | 0.0996 | 1.2285 |
| as_is | reported_raw | contents | 0.0573 | 0.0997 | 1.0464 |
| as_is | developed | contents | 0.0578 | 0.1001 | 1.0166 |
| mix_2025 | reported_raw | ALL | 0.0498 | 0.1319 | 1.2909 |
| mix_2025 | developed | ALL | 0.0650 | 0.1500 | 1.0919 |
| mix_2025 | reported_raw | motor | 0.0100 | 0.1015 | 1.2704 |
| mix_2025 | developed | motor | 0.0166 | 0.1146 | 1.0326 |
| mix_2025 | reported_raw | buildings | -0.0129 | 0.0621 | 1.6091 |
| mix_2025 | developed | buildings | 0.0029 | 0.0786 | 1.4239 |
| mix_2025 | reported_raw | contents | 0.0258 | 0.1303 | 0.8198 |
| mix_2025 | developed | contents | 0.0234 | 0.1269 | 0.7914 |

### Per peril: frequency, severity, cost (2024, as-is)

- freq_d2: Poisson deviance D2 of reported claim counts (expected = exposure x frequency x reported share; baseline = one rate per reported exposure). freq_ae = actual / expected.
- sev_d2: Gamma deviance D2 of each 2024 claim's cost vs the predicted severity of its row (baseline = mean claim); sev_d2_capped caps both at the emerging cap. sev_ae = mean actual / mean predicted.
- cost_*: Tweedie D2 of the row x peril cost on developed actuals (w1 and constant-mean) and reported_raw (w1); cost_ae_dev = actual / predicted.

| line | peril | claims_2024 | exposure | freq_d2 | freq_ae | sev_d2 | sev_d2_capped | sev_ae | cost_d2_w1_dev | cost_d2_const_dev | cost_d2_w1_raw | cost_ae_dev |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | 67 | 12,095.4356 | 0.0568 | 0.9432 | -0.0055 | -0.0055 | 1.1093 | 0.0934 | 0.1364 | 0.0939 | 1.0552 |
| buildings | escape_of_water | 137 | 12,095.4356 | 0.0060 | 0.9683 | 0.0276 | 0.0200 | 0.8299 | 0.0035 | 0.0451 | 0.0015 | 0.8015 |
| buildings | fire | 21 | 12,095.4356 | -0.0337 | 0.4973 | -0.0215 | -0.0198 | 1.5502 | 0.0260 | 0.0663 | 0.0248 | 0.7799 |
| buildings | flood | 38 | 12,095.4356 | 0.3185 | 0.7804 | -0.0015 | -0.0015 | 1.0951 | 0.5112 | 0.4670 | 0.5101 | 0.8501 |
| buildings | storm | 254 | 12,095.4356 | 0.0581 | 1.0184 | 0.0291 | 0.0291 | 0.9812 | 0.0682 | 0.1031 | 0.0690 | 0.9997 |
| buildings | subsidence | 20 | 12,095.4356 | 0.0632 | 0.8321 | -0.2973 | -0.2973 | 0.6389 | 0.0562 | 0.0971 | -0.0403 | 0.5752 |
| contents | accidental_damage | 169 | 14,950.2849 | 0.1124 | 0.9708 | -0.0042 | -0.0055 | 0.9479 | 0.1742 | 0.2043 | 0.1725 | 0.9356 |
| contents | escape_of_water | 85 | 14,950.2849 | 0.0177 | 0.9703 | 0.1896 | 0.1896 | 0.9229 | 0.0505 | 0.1044 | 0.0468 | 0.8744 |
| contents | flood | 35 | 14,950.2849 | 0.2131 | 0.7609 | 0.1245 | 0.1245 | 1.1606 | 0.3565 | 0.3867 | 0.3566 | 0.8607 |
| contents | theft | 218 | 14,950.2849 | 0.0283 | 1.1483 | 0.0705 | 0.0705 | 0.9608 | 0.0531 | 0.0874 | 0.0532 | 1.1163 |
| motor | bodily_injury | 183 | 20,104.0247 | 0.0340 | 1.1009 | -0.0117 | -0.0141 | 0.9621 | 0.0205 | 0.0788 | -0.0124 | 1.0482 |
| motor | glass_hail | 744 | 20,104.0247 | 0.0337 | 1.0973 | 0.0060 | 0.0060 | 0.9838 | 0.1737 | 0.2074 | 0.1740 | 1.0942 |
| motor | own_damage | 1,295 | 20,104.0247 | 0.1495 | 0.9538 | 0.0139 | 0.0139 | 1.0334 | 0.1838 | 0.2137 | 0.1845 | 0.9899 |
| motor | theft | 195 | 20,104.0247 | 0.0298 | 1.0497 | 0.0334 | 0.0334 | 1.1161 | 0.1352 | 0.1441 | 0.1352 | 1.1905 |
| motor | third_party_prop | 1,074 | 20,104.0247 | 0.0573 | 1.0119 | -0.0013 | -0.0016 | 0.9720 | 0.0393 | 0.0854 | 0.0388 | 0.9820 |

### Reading

- Public 0.15604 vs local ALL (developed actuals): constant-mean D2 0.1455 as-is / 0.1500 at the 2025 mix; week 1 protocol 0.1127 / 0.0650. The constant-mean D2 at the 2025 mix is the closest local proxy for the public board (Kaggle scores against the mean, and the test file is 77% new business).
- Almost all ranking power is in frequency: severity D2 is close to 0 for every peril (the emerging severity adjustment is mostly a level), and the perils with high cost D2 (buildings flood 0.51, contents flood 0.36, motor own damage 0.18, glass 0.17) are the ones with strong frequency structure.

## #2 submission_20261025_2240_week2_optionB.csv - candidate B, public 0.16562

- File MD5 `62f2e1cbebcda4a1e6f86a666610251c`; submitted by Wendy as submission_20261025_2240_week2_optionB_mactest.csv (byte-identical copy); main rebuilt with X1 gender + X8 5 bags + X10 K 200/400, lambda 30.
- Local fold: fit on emerging 2023 (baseline on developed 2021-24), score emerging 2024 (25.6k motor, 14.9k buildings, 18.7k contents rows).

### Line D2

d2_w1 = week 1 protocol (baseline: one cost rate per exposure-year); d2_const = Tweedie D2 against the constant mean (Kaggle / sklearn formula). mix_2025 = 2024 rows reweighted to the 2025 new-business x channel mix.

| weighting | basis | line | d2_w1 | d2_const | pred_vs_actual |
|---|---|---|---|---|---|
| as_is | reported_raw | ALL | 0.1085 | 0.1380 | 1.1825 |
| as_is | developed | ALL | 0.1171 | 0.1497 | 1.0237 |
| as_is | reported_raw | motor | 0.0394 | 0.0892 | 1.1894 |
| as_is | developed | motor | 0.0425 | 0.0957 | 0.9729 |
| as_is | reported_raw | buildings | 0.0994 | 0.1004 | 1.2173 |
| as_is | developed | buildings | 0.1024 | 0.1054 | 1.1492 |
| as_is | reported_raw | contents | 0.0603 | 0.1026 | 1.0421 |
| as_is | developed | contents | 0.0609 | 0.1030 | 1.0124 |
| mix_2025 | reported_raw | ALL | 0.0525 | 0.1344 | 1.2704 |
| mix_2025 | developed | ALL | 0.0668 | 0.1516 | 1.0746 |
| mix_2025 | reported_raw | motor | 0.0066 | 0.0984 | 1.2763 |
| mix_2025 | developed | motor | 0.0131 | 0.1114 | 1.0374 |
| mix_2025 | reported_raw | buildings | -0.0018 | 0.0724 | 1.4989 |
| mix_2025 | developed | buildings | 0.0113 | 0.0864 | 1.3264 |
| mix_2025 | reported_raw | contents | 0.0323 | 0.1361 | 0.8285 |
| mix_2025 | developed | contents | 0.0302 | 0.1329 | 0.7998 |

### Per peril: frequency, severity, cost (2024, as-is)

- freq_d2: Poisson deviance D2 of reported claim counts (expected = exposure x frequency x reported share; baseline = one rate per reported exposure). freq_ae = actual / expected.
- sev_d2: Gamma deviance D2 of each 2024 claim's cost vs the predicted severity of its row (baseline = mean claim); sev_d2_capped caps both at the emerging cap. sev_ae = mean actual / mean predicted.
- cost_*: Tweedie D2 of the row x peril cost on developed actuals (w1 and constant-mean) and reported_raw (w1); cost_ae_dev = actual / predicted.

| line | peril | claims_2024 | exposure | freq_d2 | freq_ae | sev_d2 | sev_d2_capped | sev_ae | cost_d2_w1_dev | cost_d2_const_dev | cost_d2_w1_raw | cost_ae_dev |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | 67 | 12,095.4356 | 0.0583 | 1.0039 | -0.0039 | -0.0039 | 1.0973 | 0.1044 | 0.1469 | 0.1054 | 1.1226 |
| buildings | escape_of_water | 137 | 12,095.4356 | 0.0069 | 1.0069 | 0.0240 | 0.0160 | 0.8185 | 0.0070 | 0.0485 | 0.0052 | 0.8230 |
| buildings | fire | 21 | 12,095.4356 | -0.0101 | 0.5888 | -0.0466 | -0.0446 | 1.6063 | 0.0403 | 0.0800 | 0.0400 | 0.9592 |
| buildings | flood | 38 | 12,095.4356 | 0.3205 | 0.7860 | -0.0012 | -0.0012 | 1.0933 | 0.5136 | 0.4696 | 0.5124 | 0.8554 |
| buildings | storm | 254 | 12,095.4356 | 0.0593 | 1.0188 | 0.0341 | 0.0341 | 0.9711 | 0.0720 | 0.1067 | 0.0725 | 0.9972 |
| buildings | subsidence | 20 | 12,095.4356 | 0.0688 | 0.8433 | -0.2946 | -0.2946 | 0.6420 | 0.0730 | 0.1131 | -0.0202 | 0.5838 |
| contents | accidental_damage | 169 | 14,950.2849 | 0.1137 | 0.9834 | -0.0048 | -0.0061 | 0.9464 | 0.1764 | 0.2063 | 0.1746 | 0.9463 |
| contents | escape_of_water | 85 | 14,950.2849 | 0.0172 | 0.9630 | 0.1963 | 0.1963 | 0.9296 | 0.0504 | 0.1043 | 0.0467 | 0.8767 |
| contents | flood | 35 | 14,950.2849 | 0.2187 | 0.7955 | 0.1252 | 0.1252 | 1.1568 | 0.3658 | 0.3955 | 0.3659 | 0.8951 |
| contents | theft | 218 | 14,950.2849 | 0.0298 | 1.1224 | 0.0705 | 0.0705 | 0.9624 | 0.0570 | 0.0912 | 0.0570 | 1.0933 |
| motor | bodily_injury | 183 | 20,104.0247 | 0.0415 | 1.1034 | -0.0122 | -0.0149 | 0.9535 | 0.0260 | 0.0840 | -0.0083 | 1.0415 |
| motor | glass_hail | 744 | 20,104.0247 | 0.0340 | 1.0704 | 0.0052 | 0.0052 | 0.9758 | 0.1754 | 0.2090 | 0.1756 | 1.0594 |
| motor | own_damage | 1,295 | 20,104.0247 | 0.1533 | 0.9630 | 0.0163 | 0.0163 | 1.0324 | 0.1872 | 0.2170 | 0.1877 | 0.9950 |
| motor | theft | 195 | 20,104.0247 | 0.0319 | 1.0426 | 0.0303 | 0.0303 | 1.1335 | 0.1373 | 0.1462 | 0.1374 | 1.2000 |
| motor | third_party_prop | 1,074 | 20,104.0247 | 0.0610 | 1.0061 | 0.0001 | -0.0003 | 0.9749 | 0.0414 | 0.0874 | 0.0410 | 0.9785 |

### Reading

- Public 0.16562 vs local ALL (developed actuals): constant-mean D2 0.1497 as-is / 0.1516 at the 2025 mix; week 1 protocol 0.1171 / 0.0668. The constant-mean D2 at the 2025 mix is the closest local proxy for the public board (Kaggle scores against the mean, and the test file is 77% new business).
- Almost all ranking power is in frequency: severity D2 is close to 0 for every peril (the emerging severity adjustment is mostly a level), and the perils with high cost D2 (buildings flood 0.51, contents flood 0.36, motor own damage 0.18, glass 0.17) are the ones with strong frequency structure.

## #3 submission_20261026_0714_week2_optionB_x13b.csv - candidate B, public 0.16432

- File MD5 `899b0ef3f7313b7f8bedd434168210ff`; submitted by Wendy as submission_20261026_0714_week2_optionB_x13b_mactest.csv (byte-identical copy); #2 with motor severity = 50/50 geometric blend of developed shape x level and emerging-only GLM (X13b).
- Local fold: fit on emerging 2023 (baseline on developed 2021-24), score emerging 2024 (25.6k motor, 14.9k buildings, 18.7k contents rows).

### Line D2

d2_w1 = week 1 protocol (baseline: one cost rate per exposure-year); d2_const = Tweedie D2 against the constant mean (Kaggle / sklearn formula). mix_2025 = 2024 rows reweighted to the 2025 new-business x channel mix.

| weighting | basis | line | d2_w1 | d2_const | pred_vs_actual |
|---|---|---|---|---|---|
| as_is | reported_raw | ALL | 0.1093 | 0.1388 | 1.1684 |
| as_is | developed | ALL | 0.1176 | 0.1502 | 1.0116 |
| as_is | reported_raw | motor | 0.0411 | 0.0908 | 1.1662 |
| as_is | developed | motor | 0.0434 | 0.0965 | 0.9539 |
| as_is | reported_raw | buildings | 0.0994 | 0.1004 | 1.2173 |
| as_is | developed | buildings | 0.1024 | 0.1054 | 1.1492 |
| as_is | reported_raw | contents | 0.0603 | 0.1026 | 1.0421 |
| as_is | developed | contents | 0.0609 | 0.1030 | 1.0124 |
| mix_2025 | reported_raw | ALL | 0.0533 | 0.1352 | 1.2597 |
| mix_2025 | developed | ALL | 0.0675 | 0.1522 | 1.0655 |
| mix_2025 | reported_raw | motor | 0.0083 | 0.1000 | 1.2597 |
| mix_2025 | developed | motor | 0.0144 | 0.1126 | 1.0239 |
| mix_2025 | reported_raw | buildings | -0.0018 | 0.0724 | 1.4989 |
| mix_2025 | developed | buildings | 0.0113 | 0.0864 | 1.3264 |
| mix_2025 | reported_raw | contents | 0.0323 | 0.1361 | 0.8285 |
| mix_2025 | developed | contents | 0.0302 | 0.1329 | 0.7998 |

### Per peril: frequency, severity, cost (2024, as-is)

- freq_d2: Poisson deviance D2 of reported claim counts (expected = exposure x frequency x reported share; baseline = one rate per reported exposure). freq_ae = actual / expected.
- sev_d2: Gamma deviance D2 of each 2024 claim's cost vs the predicted severity of its row (baseline = mean claim); sev_d2_capped caps both at the emerging cap. sev_ae = mean actual / mean predicted.
- cost_*: Tweedie D2 of the row x peril cost on developed actuals (w1 and constant-mean) and reported_raw (w1); cost_ae_dev = actual / predicted.

| line | peril | claims_2024 | exposure | freq_d2 | freq_ae | sev_d2 | sev_d2_capped | sev_ae | cost_d2_w1_dev | cost_d2_const_dev | cost_d2_w1_raw | cost_ae_dev |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | 67 | 12,095.4356 | 0.0583 | 1.0039 | -0.0039 | -0.0039 | 1.0973 | 0.1044 | 0.1469 | 0.1054 | 1.1226 |
| buildings | escape_of_water | 137 | 12,095.4356 | 0.0069 | 1.0069 | 0.0240 | 0.0160 | 0.8185 | 0.0070 | 0.0485 | 0.0052 | 0.8230 |
| buildings | fire | 21 | 12,095.4356 | -0.0101 | 0.5888 | -0.0466 | -0.0446 | 1.6063 | 0.0403 | 0.0800 | 0.0400 | 0.9592 |
| buildings | flood | 38 | 12,095.4356 | 0.3205 | 0.7860 | -0.0012 | -0.0012 | 1.0933 | 0.5136 | 0.4696 | 0.5124 | 0.8554 |
| buildings | storm | 254 | 12,095.4356 | 0.0593 | 1.0188 | 0.0341 | 0.0341 | 0.9711 | 0.0720 | 0.1067 | 0.0725 | 0.9972 |
| buildings | subsidence | 20 | 12,095.4356 | 0.0688 | 0.8433 | -0.2946 | -0.2946 | 0.6420 | 0.0730 | 0.1131 | -0.0202 | 0.5838 |
| contents | accidental_damage | 169 | 14,950.2849 | 0.1137 | 0.9834 | -0.0048 | -0.0061 | 0.9464 | 0.1764 | 0.2063 | 0.1746 | 0.9463 |
| contents | escape_of_water | 85 | 14,950.2849 | 0.0172 | 0.9630 | 0.1963 | 0.1963 | 0.9296 | 0.0504 | 0.1043 | 0.0467 | 0.8767 |
| contents | flood | 35 | 14,950.2849 | 0.2187 | 0.7955 | 0.1252 | 0.1252 | 1.1568 | 0.3658 | 0.3955 | 0.3659 | 0.8951 |
| contents | theft | 218 | 14,950.2849 | 0.0298 | 1.1224 | 0.0705 | 0.0705 | 0.9624 | 0.0570 | 0.0912 | 0.0570 | 1.0933 |
| motor | bodily_injury | 183 | 20,104.0247 | 0.0415 | 1.1034 | 0.0090 | 0.0075 | 1.0001 | 0.0293 | 0.0871 | 0.0007 | 1.0942 |
| motor | glass_hail | 744 | 20,104.0247 | 0.0340 | 1.0704 | 0.0134 | 0.0134 | 0.9970 | 0.1750 | 0.2086 | 0.1753 | 1.0798 |
| motor | own_damage | 1,295 | 20,104.0247 | 0.1533 | 0.9630 | 0.0250 | 0.0250 | 1.0336 | 0.1901 | 0.2198 | 0.1905 | 1.0001 |
| motor | theft | 195 | 20,104.0247 | 0.0319 | 1.0426 | 0.0356 | 0.0356 | 1.1276 | 0.1363 | 0.1451 | 0.1362 | 1.1846 |
| motor | third_party_prop | 1,074 | 20,104.0247 | 0.0610 | 1.0061 | 0.0010 | 0.0006 | 0.9760 | 0.0417 | 0.0877 | 0.0414 | 0.9802 |

### Reading

- Public 0.16432 vs local ALL (developed actuals): constant-mean D2 0.1502 as-is / 0.1522 at the 2025 mix; week 1 protocol 0.1176 / 0.0675. The constant-mean D2 at the 2025 mix is the closest local proxy for the public board (Kaggle scores against the mean, and the test file is 77% new business).
- Almost all ranking power is in frequency: severity D2 is close to 0 for every peril (the emerging severity adjustment is mostly a level), and the perils with high cost D2 (buildings flood 0.51, contents flood 0.36, motor own damage 0.18, glass 0.17) are the ones with strong frequency structure.

## #4 submission_20261026_0724_week2_optionB_x14e.csv - candidate B, public 0.16557

- File MD5 `1396622b27748b75a371fdaba893501b`; submitted by Wendy as submission_20261026_0724_week2_optionB_x14e_mactest.csv (byte-identical copy); #2 with 50/50 emerging severity shape on motor OD, glass, BI and contents EoW (CV-picked), each peril relevelled to #2's total (X14e); public board 2nd of field (best 0.17182).
- Local fold: fit on emerging 2023 (baseline on developed 2021-24), score emerging 2024 (25.6k motor, 14.9k buildings, 18.7k contents rows).

### Line D2

d2_w1 = week 1 protocol (baseline: one cost rate per exposure-year); d2_const = Tweedie D2 against the constant mean (Kaggle / sklearn formula). mix_2025 = 2024 rows reweighted to the 2025 new-business x channel mix.

| weighting | basis | line | d2_w1 | d2_const | pred_vs_actual |
|---|---|---|---|---|---|
| as_is | reported_raw | ALL | 0.1089 | 0.1383 | 1.1825 |
| as_is | developed | ALL | 0.1178 | 0.1503 | 1.0237 |
| as_is | reported_raw | motor | 0.0399 | 0.0897 | 1.1894 |
| as_is | developed | motor | 0.0436 | 0.0967 | 0.9729 |
| as_is | reported_raw | buildings | 0.0994 | 0.1004 | 1.2173 |
| as_is | developed | buildings | 0.1024 | 0.1054 | 1.1492 |
| as_is | reported_raw | contents | 0.0609 | 0.1031 | 1.0421 |
| as_is | developed | contents | 0.0615 | 0.1036 | 1.0124 |
| mix_2025 | reported_raw | ALL | 0.0529 | 0.1348 | 1.2700 |
| mix_2025 | developed | ALL | 0.0675 | 0.1522 | 1.0743 |
| mix_2025 | reported_raw | motor | 0.0068 | 0.0986 | 1.2758 |
| mix_2025 | developed | motor | 0.0138 | 0.1121 | 1.0370 |
| mix_2025 | reported_raw | buildings | -0.0018 | 0.0724 | 1.4989 |
| mix_2025 | developed | buildings | 0.0113 | 0.0864 | 1.3264 |
| mix_2025 | reported_raw | contents | 0.0336 | 0.1373 | 0.8284 |
| mix_2025 | developed | contents | 0.0316 | 0.1342 | 0.7997 |

### Per peril: frequency, severity, cost (2024, as-is)

- freq_d2: Poisson deviance D2 of reported claim counts (expected = exposure x frequency x reported share; baseline = one rate per reported exposure). freq_ae = actual / expected.
- sev_d2: Gamma deviance D2 of each 2024 claim's cost vs the predicted severity of its row (baseline = mean claim); sev_d2_capped caps both at the emerging cap. sev_ae = mean actual / mean predicted.
- cost_*: Tweedie D2 of the row x peril cost on developed actuals (w1 and constant-mean) and reported_raw (w1); cost_ae_dev = actual / predicted.

| line | peril | claims_2024 | exposure | freq_d2 | freq_ae | sev_d2 | sev_d2_capped | sev_ae | cost_d2_w1_dev | cost_d2_const_dev | cost_d2_w1_raw | cost_ae_dev |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | 67 | 12,095.4356 | 0.0583 | 1.0039 | -0.0039 | -0.0039 | 1.0973 | 0.1044 | 0.1469 | 0.1054 | 1.1226 |
| buildings | escape_of_water | 137 | 12,095.4356 | 0.0069 | 1.0069 | 0.0240 | 0.0160 | 0.8185 | 0.0070 | 0.0485 | 0.0052 | 0.8230 |
| buildings | fire | 21 | 12,095.4356 | -0.0101 | 0.5888 | -0.0466 | -0.0446 | 1.6063 | 0.0403 | 0.0800 | 0.0400 | 0.9592 |
| buildings | flood | 38 | 12,095.4356 | 0.3205 | 0.7860 | -0.0012 | -0.0012 | 1.0933 | 0.5136 | 0.4696 | 0.5124 | 0.8554 |
| buildings | storm | 254 | 12,095.4356 | 0.0593 | 1.0188 | 0.0341 | 0.0341 | 0.9711 | 0.0720 | 0.1067 | 0.0725 | 0.9972 |
| buildings | subsidence | 20 | 12,095.4356 | 0.0688 | 0.8433 | -0.2946 | -0.2946 | 0.6420 | 0.0730 | 0.1131 | -0.0202 | 0.5838 |
| contents | accidental_damage | 169 | 14,950.2849 | 0.1137 | 0.9834 | -0.0048 | -0.0061 | 0.9464 | 0.1764 | 0.2063 | 0.1746 | 0.9463 |
| contents | escape_of_water | 85 | 14,950.2849 | 0.0172 | 0.9630 | 0.1896 | 0.1896 | 0.9183 | 0.0538 | 0.1075 | 0.0498 | 0.8767 |
| contents | flood | 35 | 14,950.2849 | 0.2187 | 0.7955 | 0.1252 | 0.1252 | 1.1568 | 0.3658 | 0.3955 | 0.3659 | 0.8951 |
| contents | theft | 218 | 14,950.2849 | 0.0298 | 1.1224 | 0.0705 | 0.0705 | 0.9624 | 0.0570 | 0.0912 | 0.0570 | 1.0933 |
| motor | bodily_injury | 183 | 20,104.0247 | 0.0415 | 1.1034 | 0.0069 | 0.0033 | 0.9520 | 0.0303 | 0.0880 | -0.0058 | 1.0415 |
| motor | glass_hail | 744 | 20,104.0247 | 0.0340 | 1.0704 | 0.0130 | 0.0130 | 0.9782 | 0.1753 | 0.2089 | 0.1755 | 1.0594 |
| motor | own_damage | 1,295 | 20,104.0247 | 0.1533 | 0.9630 | 0.0252 | 0.0252 | 1.0282 | 0.1901 | 0.2198 | 0.1905 | 0.9950 |
| motor | theft | 195 | 20,104.0247 | 0.0319 | 1.0426 | 0.0303 | 0.0303 | 1.1335 | 0.1373 | 0.1462 | 0.1374 | 1.2000 |
| motor | third_party_prop | 1,074 | 20,104.0247 | 0.0610 | 1.0061 | 0.0001 | -0.0003 | 0.9749 | 0.0414 | 0.0874 | 0.0410 | 0.9785 |

### Reading

- Public 0.16557 vs local ALL (developed actuals): constant-mean D2 0.1503 as-is / 0.1522 at the 2025 mix; week 1 protocol 0.1178 / 0.0675. The constant-mean D2 at the 2025 mix is the closest local proxy for the public board (Kaggle scores against the mean, and the test file is 77% new business).
- Almost all ranking power is in frequency: severity D2 is close to 0 for every peril (the emerging severity adjustment is mostly a level), and the perils with high cost D2 (buildings flood 0.51, contents flood 0.36, motor own damage 0.18, glass 0.17) are the ones with strong frequency structure.

## #5 submission_20261026_0737_week2_optionB_x18b.csv - candidate B, public 0.16612

- File MD5 `6a5011cc9752fc1204c0056f0f4ec985`; submitted by Wendy as submission_20261026_0737_week2_optionB_x18b_mactest.csv (byte-identical copy); #4 with motor frequency trend floored at 0 in fit and 2025 projection (X18b); motor 2025 burn +3.0%; best public score.
- Local fold: fit on emerging 2023 (baseline on developed 2021-24), score emerging 2024 (25.6k motor, 14.9k buildings, 18.7k contents rows).

### Line D2

d2_w1 = week 1 protocol (baseline: one cost rate per exposure-year); d2_const = Tweedie D2 against the constant mean (Kaggle / sklearn formula). mix_2025 = 2024 rows reweighted to the 2025 new-business x channel mix.

| weighting | basis | line | d2_w1 | d2_const | pred_vs_actual |
|---|---|---|---|---|---|
| as_is | reported_raw | ALL | 0.1084 | 0.1379 | 1.1968 |
| as_is | developed | ALL | 0.1178 | 0.1504 | 1.0361 |
| as_is | reported_raw | motor | 0.0389 | 0.0887 | 1.2130 |
| as_is | developed | motor | 0.0437 | 0.0969 | 0.9922 |
| as_is | reported_raw | buildings | 0.0994 | 0.1004 | 1.2173 |
| as_is | developed | buildings | 0.1024 | 0.1054 | 1.1492 |
| as_is | reported_raw | contents | 0.0609 | 0.1031 | 1.0421 |
| as_is | developed | contents | 0.0615 | 0.1036 | 1.0124 |
| mix_2025 | reported_raw | ALL | 0.0523 | 0.1342 | 1.2866 |
| mix_2025 | developed | ALL | 0.0674 | 0.1522 | 1.0883 |
| mix_2025 | reported_raw | motor | 0.0054 | 0.0973 | 1.3016 |
| mix_2025 | developed | motor | 0.0138 | 0.1121 | 1.0580 |
| mix_2025 | reported_raw | buildings | -0.0018 | 0.0724 | 1.4989 |
| mix_2025 | developed | buildings | 0.0113 | 0.0864 | 1.3264 |
| mix_2025 | reported_raw | contents | 0.0336 | 0.1373 | 0.8284 |
| mix_2025 | developed | contents | 0.0316 | 0.1342 | 0.7997 |

### Per peril: frequency, severity, cost (2024, as-is)

- freq_d2: Poisson deviance D2 of reported claim counts (expected = exposure x frequency x reported share; baseline = one rate per reported exposure). freq_ae = actual / expected.
- sev_d2: Gamma deviance D2 of each 2024 claim's cost vs the predicted severity of its row (baseline = mean claim); sev_d2_capped caps both at the emerging cap. sev_ae = mean actual / mean predicted.
- cost_*: Tweedie D2 of the row x peril cost on developed actuals (w1 and constant-mean) and reported_raw (w1); cost_ae_dev = actual / predicted.

| line | peril | claims_2024 | exposure | freq_d2 | freq_ae | sev_d2 | sev_d2_capped | sev_ae | cost_d2_w1_dev | cost_d2_const_dev | cost_d2_w1_raw | cost_ae_dev |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| buildings | accidental_damage | 67 | 12,095.4356 | 0.0583 | 1.0039 | -0.0039 | -0.0039 | 1.0973 | 0.1044 | 0.1469 | 0.1054 | 1.1226 |
| buildings | escape_of_water | 137 | 12,095.4356 | 0.0069 | 1.0069 | 0.0240 | 0.0160 | 0.8185 | 0.0070 | 0.0485 | 0.0052 | 0.8230 |
| buildings | fire | 21 | 12,095.4356 | -0.0101 | 0.5888 | -0.0466 | -0.0446 | 1.6063 | 0.0403 | 0.0800 | 0.0400 | 0.9592 |
| buildings | flood | 38 | 12,095.4356 | 0.3205 | 0.7860 | -0.0012 | -0.0012 | 1.0933 | 0.5136 | 0.4696 | 0.5124 | 0.8554 |
| buildings | storm | 254 | 12,095.4356 | 0.0593 | 1.0188 | 0.0341 | 0.0341 | 0.9711 | 0.0720 | 0.1067 | 0.0725 | 0.9972 |
| buildings | subsidence | 20 | 12,095.4356 | 0.0688 | 0.8433 | -0.2946 | -0.2946 | 0.6420 | 0.0730 | 0.1131 | -0.0202 | 0.5838 |
| contents | accidental_damage | 169 | 14,950.2849 | 0.1137 | 0.9834 | -0.0048 | -0.0061 | 0.9464 | 0.1764 | 0.2063 | 0.1746 | 0.9463 |
| contents | escape_of_water | 85 | 14,950.2849 | 0.0172 | 0.9630 | 0.1896 | 0.1896 | 0.9183 | 0.0538 | 0.1075 | 0.0498 | 0.8767 |
| contents | flood | 35 | 14,950.2849 | 0.2187 | 0.7955 | 0.1252 | 0.1252 | 1.1568 | 0.3658 | 0.3955 | 0.3659 | 0.8951 |
| contents | theft | 218 | 14,950.2849 | 0.0298 | 1.1224 | 0.0705 | 0.0705 | 0.9624 | 0.0570 | 0.0912 | 0.0570 | 1.0933 |
| motor | bodily_injury | 183 | 20,104.0247 | 0.0415 | 1.1034 | 0.0069 | 0.0033 | 0.9520 | 0.0303 | 0.0880 | -0.0058 | 1.0415 |
| motor | glass_hail | 744 | 20,104.0247 | 0.0340 | 1.0704 | 0.0130 | 0.0130 | 0.9782 | 0.1753 | 0.2089 | 0.1755 | 1.0594 |
| motor | own_damage | 1,295 | 20,104.0247 | 0.1522 | 0.9149 | 0.0252 | 0.0252 | 1.0282 | 0.1896 | 0.2193 | 0.1904 | 0.9453 |
| motor | theft | 195 | 20,104.0247 | 0.0319 | 1.0426 | 0.0303 | 0.0303 | 1.1335 | 0.1373 | 0.1462 | 0.1374 | 1.2000 |
| motor | third_party_prop | 1,074 | 20,104.0247 | 0.0608 | 0.9720 | 0.0001 | -0.0003 | 0.9749 | 0.0413 | 0.0873 | 0.0402 | 0.9454 |

### Reading

- Public 0.16612 vs local ALL (developed actuals): constant-mean D2 0.1504 as-is / 0.1522 at the 2025 mix; week 1 protocol 0.1178 / 0.0674. The constant-mean D2 at the 2025 mix is the closest local proxy for the public board (Kaggle scores against the mean, and the test file is 77% new business).
- Almost all ranking power is in frequency: severity D2 is close to 0 for every peril (the emerging severity adjustment is mostly a level), and the perils with high cost D2 (buildings flood 0.51, contents flood 0.36, motor own damage 0.18, glass 0.17) are the ones with strong frequency structure.

