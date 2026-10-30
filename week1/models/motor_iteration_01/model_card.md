# MOTOR 1 - motor-only per-peril frequency x severity

**Run id** `20261023_1124` | **Quick mode** FALSE | **Runtime** 50 min | **Submission (own level)** `motor_only_20261023_1124.csv` | **Submission (SAM 4 level)** `motor_only_20261023_1124_samlevel.csv`

## Metrics used
- **Tweedie D2 (p = 1.5) on row cost** - the competition metric; zero rows count, so it judges frequency, severity and level together. Reported raw (as scored) and calibrated (prediction rescaled to the actual total, ranking only).
- **Poisson D2 on claim counts** (expected reported count = rate x exposure x reported share, calibrated) - the proper score for a log-link count model with an exposure offset.
- **Gamma D2 on cost per claim** (calibrated, claim-count weighted) - scale-free severity error, matches the Gamma GLM.
- **Normalised Gini** - ranking only, secondary. RMSE on log cost is not used: it drops zero rows and needs a retransformation correction.
- Keep rule for every change: mean gain > 0.0005 and better in at least 2 of the 3 folds (2022, 2023, 2024; each fitted on earlier years only).

## Headline

| model | d2_2022 | d2_2023 | d2_2024 | d2_mean |
|---|---|---|---|---|
| iteration-1 GLM replay | 0.0553 | 0.0555 | 0.0444 | 0.0517 |
| MOTOR 1 per-peril, no line blend | 0.0627 | 0.0502 | 0.0379 | 0.0502 |
| MOTOR 1 per-peril (final) | 0.0628 | 0.0501 | 0.0377 | 0.0502 |
| SAM 4 blend (reported) | 0.0596 | 0.0435 | 0.0463 | 0.0498 |
| single line-level Tweedie XGBoost (same folds/features) | 0.0493 | 0.0425 | 0.0320 | 0.0412 |

SAM 4 figures are its reported motor blend D2 on the same fold years (not re-run).

## Stage-by-stage before / after (total row cost and by peril)

`d2_<year>` = raw Tweedie D2 on total motor row cost; `peril_d2_<peril>` = mean raw Tweedie D2 of that peril's cost over the folds.

| stage | d2_2022 | d2_2023 | d2_2024 | d2_mean | d2_cal_mean | gini_mean | peril_d2_own_damage | peril_d2_third_party_prop | peril_d2_bodily_injury | peril_d2_theft | peril_d2_glass_hail |
|---|---|---|---|---|---|---|---|---|---|---|---|
| S0 base GLM (base features, base severity) | 0.0604 | 0.0483 | 0.0364 | 0.0484 | 0.0547 | 0.4041 | 0.1689 | 0.0595 | 0.0263 | 0.0735 | 0.1240 |
| S1 + frequency feature ladder | 0.0622 | 0.0475 | 0.0380 | 0.0492 | 0.0565 | 0.4085 | 0.1699 | 0.0616 | 0.0212 | 0.0743 | 0.1373 |
| S2 + severity feature choice | 0.0622 | 0.0475 | 0.0380 | 0.0492 | 0.0565 | 0.4085 | 0.1699 | 0.0616 | 0.0212 | 0.0743 | 0.1373 |
| S3 + severity credibility shrinkage | 0.0623 | 0.0498 | 0.0377 | 0.0499 | 0.0572 | 0.4111 | 0.1699 | 0.0619 | 0.0221 | 0.0743 | 0.1373 |
| S4 + open-claim recovery adjustment | 0.0623 | 0.0498 | 0.0377 | 0.0499 | 0.0572 | 0.4111 | 0.1699 | 0.0619 | 0.0221 | 0.0743 | 0.1373 |
| S5 + XGBoost frequency (per peril) | 0.0627 | 0.0502 | 0.0379 | 0.0502 | 0.0576 | 0.4119 | 0.1705 | 0.0619 | 0.0221 | 0.0763 | 0.1384 |
| S6 + XGBoost severity (own_damage, third_party_prop) | 0.0627 | 0.0502 | 0.0379 | 0.0502 | 0.0576 | 0.4119 | 0.1705 | 0.0619 | 0.0221 | 0.0763 | 0.1384 |
| S7 + line Tweedie blend | 0.0628 | 0.0501 | 0.0377 | 0.0502 | 0.0577 | 0.4120 | 0.1705 | 0.0619 | 0.0221 | 0.0763 | 0.1384 |

## Decisions

| peril | decision | choice | detail |
|---|---|---|---|
| own_damage | severity features | base | Gamma D2 base 0.0372/0.0457/0.0488 vs extended 0.0365/0.0438/0.0486 |
| third_party_prop | severity features | base | Gamma D2 base -0.0017/0.0033/-6e-04 vs extended -0.003/0.0019/-0.0016 |
| bodily_injury | severity features | base | Gamma D2 base -0.0069/-0.0086/-0.0068 vs extended -0.0069/-0.0148/-0.013 |
| theft | severity features | base | Gamma D2 base 0.0258/0.0328/0.0401 vs extended 0.0258/0.0327/0.0349 |
| glass_hail | severity features | base | Gamma D2 base 0.0085/0.0098/0.0064 vs extended -9e-04/0.009/0.0044 |
| own_damage | severity credibility Z (0 = peril average, 1 = full GLM) | 1 | Z=0.00: 0.0000; Z=0.25: 0.0189; Z=0.50: 0.0326; Z=0.75: 0.0410; Z=1.00: 0.0439 |
| third_party_prop | severity credibility Z (0 = peril average, 1 = full GLM) | 0.5 | Z=0.00: 0.0000; Z=0.25: 0.0007; Z=0.50: 0.0011; Z=0.75: 0.0009; Z=1.00: 0.0003 |
| bodily_injury | severity credibility Z (0 = peril average, 1 = full GLM) | 0 | Z=0.00: 0.0000; Z=0.25: -0.0009; Z=0.50: -0.0025; Z=0.75: -0.0047; Z=1.00: -0.0075 |
| theft | severity credibility Z (0 = peril average, 1 = full GLM) | 1 | Z=0.00: 0.0000; Z=0.25: 0.0147; Z=0.50: 0.0251; Z=0.75: 0.0312; Z=1.00: 0.0329 |
| glass_hail | severity credibility Z (0 = peril average, 1 = full GLM) | 0.75 | Z=0.00: 0.0000; Z=0.25: 0.0042; Z=0.50: 0.0070; Z=0.75: 0.0084; Z=1.00: 0.0082 |
| own_damage | deduct expected recoveries from open claims | FALSE | peril Tweedie D2 on mature folds 2022/2023: raw 0.1654/0.1679 vs adjusted 0.1654/0.1679 |
| theft | deduct expected recoveries from open claims | FALSE | peril Tweedie D2 on mature folds 2022/2023: raw 0.072/0.0661 vs adjusted 0.072/0.066 |
| own_damage | XGBoost frequency weight | 0.5 | peril Tweedie D2 GLM 0.1654/0.1679/0.1765; w=0.5 0.1657/0.1684/0.1774; w=1 0.1622/0.1668/0.176 |
| third_party_prop | XGBoost frequency weight | 0 | peril Tweedie D2 GLM 0.0672/0.0621/0.0564; w=0.5 0.0657/0.0628/0.0564; w=1 0.0591/0.0609/0.054 |
| bodily_injury | XGBoost frequency weight | 0 | peril Tweedie D2 GLM 0.0632/0.0679/-0.0648; w=0.5 0.0612/0.0528/-0.067; w=1 0.0454/0.0261/-0.0696 |
| theft | XGBoost frequency weight | 0.5 | peril Tweedie D2 GLM 0.072/0.0661/0.0848; w=0.5 0.0678/0.0726/0.0886; w=1 0.0417/0.0675/0.0863 |
| glass_hail | XGBoost frequency weight | 0.5 | peril Tweedie D2 GLM 0.1301/0.1433/0.1383; w=0.5 0.1306/0.1447/0.1399; w=1 0.1226/0.1406/0.1379 |
| own_damage | XGBoost severity weight | 0 | peril Tweedie D2 GLM sev 0.1657/0.1684/0.1774; w=0.5 0.1651/0.1677/0.177; w=1 0.1622/0.166/0.1755 |
| third_party_prop | XGBoost severity weight | 0 | peril Tweedie D2 GLM sev 0.0672/0.0621/0.0564; w=0.5 0.0669/0.0617/0.0568; w=1 0.0642/0.0605/0.0566 |
| all | blend weight on the line-level Tweedie XGBoost | 0.1 | a=0.0: 0.0576; a=0.1: 0.0577; a=0.2: 0.0576; a=0.3: 0.0573 |

## Peril-by-peril performance (final configuration)

| peril | valid_year | claims | tweedie_d2 | gini | ae_developed | poisson_d2 | gamma_d2 |
|---|---|---|---|---|---|---|---|
| own_damage | 2022 | 12,871 | 0.1657 | 0.5341 | 0.8855 | 0.1411 | 0.0372 |
| own_damage | 2023 | 11,870 | 0.1684 | 0.5373 | 1.1809 | 0.1357 | 0.0457 |
| own_damage | 2024 | 11,537 | 0.1774 | 0.5422 | 0.9182 | 0.1407 | 0.0488 |
| third_party_prop | 2022 | 8,801 | 0.0672 | 0.4360 | 0.9028 | 0.0729 | 0.0004 |
| third_party_prop | 2023 | 8,357 | 0.0621 | 0.4347 | 1.0974 | 0.0686 | 0.0023 |
| third_party_prop | 2024 | 7,626 | 0.0564 | 0.4231 | 1.0032 | 0.0638 | 0.0005 |
| bodily_injury | 2022 | 2,141 | 0.0632 | 0.4508 | 0.9897 | 0.0479 | 0 |
| bodily_injury | 2023 | 2,049 | 0.0679 | 0.4983 | 1.0525 | 0.0455 | 0 |
| bodily_injury | 2024 | 1,178 | -0.0648 | 0.3993 | 1.6814 | 0.0421 | 0 |
| theft | 2022 | 1,536 | 0.0678 | 0.4100 | 1.0404 | 0.0358 | 0.0258 |
| theft | 2023 | 1,601 | 0.0726 | 0.4200 | 0.8090 | 0.0355 | 0.0328 |
| theft | 2024 | 1,503 | 0.0886 | 0.4498 | 1.0720 | 0.0439 | 0.0401 |
| glass_hail | 2022 | 3,939 | 0.1306 | 0.4730 | 0.9340 | 0.0725 | 0.0084 |
| glass_hail | 2023 | 4,112 | 0.1447 | 0.5155 | 0.8786 | 0.0849 | 0.0097 |
| glass_hail | 2024 | 4,020 | 0.1399 | 0.4950 | 1.1345 | 0.0829 | 0.0071 |

## Final configuration per peril (fit on 2021-24)

| peril | freq_features | freq_trend_fitted | freq_trend_used | imm_2024_rel | sev_variant | sev_features | sev_claims | sev_gated | sev_trend_used | Z | xgb_freq_w | xgb_sev_w | cap | loading | uncovered_cover |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| own_damage | driver_age, years_licensed, ncb_years, vehicle_value_group, vehicle_age, annual_mileage, vehicle_use, named_young_driver, region, urban_density, voluntary_excess, prior_claims_5y, licence_points, credit_band, new_business, payment_method, telematics_opt_in, overnight_parking, body_type, fuel_type, missed_payments_12m, renewal_count, days_quote_to_inception, channel_nb, years_with_insurer, hist_pol_n, hist_cust_other_n, claim_free_years | -0.014 | -0.014 |  | base | vehicle_value_group, vehicle_age, voluntary_excess, region, urban_density, driver_age, body_type, fuel_type | 48,258 | FALSE | 0.084 | 1 | 0.500 | 0 | 13,005.319 | 1.010 | third_party_only, third_party_fire_theft |
| third_party_prop | driver_age, years_licensed, ncb_years, vehicle_value_group, vehicle_age, cover_type, annual_mileage, vehicle_use, named_young_driver, region, urban_density, voluntary_excess, prior_claims_5y, licence_points, credit_band, new_business, payment_method, telematics_opt_in, overnight_parking, body_type, fuel_type, telematics_score, missed_payments_12m, renewal_count, days_quote_to_inception, channel_nb, years_with_insurer, hist_pol_n, hist_cust_other_n, claim_free_years | -0.037 | -0.037 |  | base | vehicle_value_group, driver_age, region, urban_density, vehicle_use | 32,963 | FALSE | 0.077 | 0.500 | 0 | 0 | 19,749.538 | 1.006 |  |
| bodily_injury | driver_age, years_licensed, ncb_years, vehicle_value_group, vehicle_age, cover_type, annual_mileage, vehicle_use, named_young_driver, region, urban_density, voluntary_excess, prior_claims_5y, licence_points, credit_band, new_business, payment_method, telematics_opt_in, overnight_parking, body_type, hist_pol_n, hist_cust_other_n, claim_free_years | 0.049 | 0.049 | 0.933 | base | driver_age, vehicle_value_group, named_young_driver, years_licensed, body_type | 4,285 | FALSE | 0.053 | 0 | 0 | 0 | 187,516.024 | 1.115 |  |
| theft | vehicle_value_group, vehicle_age, cover_type, overnight_parking, region, urban_density, fuel_type, credit_band, voluntary_excess, driver_age, missed_payments_12m, renewal_count, days_quote_to_inception, channel_nb, years_with_insurer | -0.001 | -0.001 |  | base | vehicle_value_group, vehicle_age, cover_type, voluntary_excess | 6,119 | FALSE | 0.062 | 1 | 0.500 | 0 | 38,459.515 | 1.007 | third_party_only |
| glass_hail | vehicle_value_group, vehicle_age, body_type, region, voluntary_excess, driver_age, use_parking, annual_mileage, missed_payments_12m, renewal_count, days_quote_to_inception, channel_nb, years_with_insurer, hail_days, freezing_days, hist_pol_n, hist_cust_other_n, claim_free_years | -0.008 | -0.008 |  | base | vehicle_value_group, body_type, voluntary_excess, vehicle_age | 15,643 | FALSE | 0.080 | 0.750 | 0.500 | 0 | 5,873.072 | 1.006 | third_party_only, third_party_fire_theft |

## Frequency feature ladder (GLM, calibrated Poisson D2 on covered validation rows)

Groups are added in order; `kept` marks the option that passed the keep rule and was carried forward.

| peril | step | group | option | d2_2022 | d2_2023 | d2_2024 | mean_gain | wins | kept | n_features |
|---|---|---|---|---|---|---|---|---|---|---|
| own_damage | 0 | base |  | 0.0798 | 0.0703 | 0.0731 |  |  | TRUE | 21 |
| own_damage | 1 | driver |  | 0.0793 | 0.0703 | 0.0731 | -0.0002 | 1 | FALSE | 24 |
| own_damage | 2 | vehicle |  | 0.0796 | 0.0704 | 0.0732 | -0.0000 | 2 | FALSE | 24 |
| own_damage | 3 | make_model_te |  | 0.0798 | 0.0702 | 0.0731 | -0.0000 | 1 | FALSE | 22 |
| own_damage | 4 | usage |  | 0.0797 | 0.0703 | 0.0730 | -0.0000 | 1 | FALSE | 22 |
| own_damage | 5 | mileage_per_exposure |  | 0.0797 | 0.0703 | 0.0731 | -0.0000 | 2 | FALSE | 22 |
| own_damage | 6 | telematics |  | 0.0799 | 0.0708 | 0.0737 | 0.0004 | 3 | FALSE | 22 |
| own_damage | 7 | policy |  | 0.0806 | 0.0710 | 0.0747 | 0.0010 | 3 | TRUE | 26 |
| own_damage | 8 | customer |  | 0.0811 | 0.0712 | 0.0748 | 0.0002 | 3 | FALSE | 30 |
| own_damage | 9 | region_urban_te |  | 0.0806 | 0.0709 | 0.0747 | -0.0000 | 1 | FALSE | 27 |
| own_damage | 10 | weather_primary | raw | 0.0801 | 0.0709 | 0.0747 | -0.0002 | 1 | FALSE | 28 |
| own_damage | 10 | weather_primary | avg | 0.0802 | 0.0707 | 0.0748 | -0.0002 | 1 | FALSE | 28 |
| own_damage | 10 | weather_primary | avg_dev | 0.0801 | 0.0705 | 0.0748 | -0.0003 | 1 | FALSE | 30 |
| own_damage | 11 | weather_other |  | 0.0791 | 0.0708 | 0.0745 | -0.0006 | 0 | FALSE | 31 |
| own_damage | 12 | claim_history |  | 0.0806 | 0.0721 | 0.0780 | 0.0015 | 2 | TRUE | 29 |
| own_damage | 13 | address_property |  | 0.0804 | 0.0720 | 0.0780 | -0.0001 | 0 | FALSE | 32 |
| third_party_prop | 0 | base |  | 0.0711 | 0.0661 | 0.0603 |  |  | TRUE | 21 |
| third_party_prop | 1 | driver |  | 0.0708 | 0.0659 | 0.0600 | -0.0003 | 0 | FALSE | 24 |
| third_party_prop | 2 | vehicle |  | 0.0708 | 0.0660 | 0.0601 | -0.0002 | 0 | FALSE | 24 |
| third_party_prop | 3 | make_model_te |  | 0.0710 | 0.0659 | 0.0603 | -0.0001 | 0 | FALSE | 22 |
| third_party_prop | 4 | usage |  | 0.0711 | 0.0661 | 0.0604 | -0.0000 | 1 | FALSE | 22 |
| third_party_prop | 5 | mileage_per_exposure |  | 0.0711 | 0.0661 | 0.0602 | -0.0001 | 0 | FALSE | 22 |
| third_party_prop | 6 | telematics |  | 0.0717 | 0.0669 | 0.0606 | 0.0005 | 3 | TRUE | 22 |
| third_party_prop | 7 | policy |  | 0.0728 | 0.0681 | 0.0620 | 0.0013 | 3 | TRUE | 27 |
| third_party_prop | 8 | customer |  | 0.0723 | 0.0683 | 0.0622 | -0.0001 | 2 | FALSE | 31 |
| third_party_prop | 9 | region_urban_te |  | 0.0726 | 0.0680 | 0.0620 | -0.0001 | 0 | FALSE | 28 |
| third_party_prop | 10 | weather_primary | raw | 0.0727 | 0.0680 | 0.0622 | -0.0000 | 1 | FALSE | 29 |
| third_party_prop | 10 | weather_primary | avg | 0.0728 | 0.0680 | 0.0621 | -0.0000 | 1 | FALSE | 29 |
| third_party_prop | 10 | weather_primary | avg_dev | 0.0725 | 0.0676 | 0.0620 | -0.0003 | 1 | FALSE | 31 |
| third_party_prop | 11 | weather_other |  | 0.0707 | 0.0679 | 0.0619 | -0.0008 | 0 | FALSE | 32 |
| third_party_prop | 12 | claim_history |  | 0.0728 | 0.0681 | 0.0635 | 0.0005 | 2 | TRUE | 30 |
| third_party_prop | 13 | address_property |  | 0.0726 | 0.0678 | 0.0636 | -0.0002 | 1 | FALSE | 33 |
| bodily_injury | 0 | base |  | 0.0477 | 0.0439 | 0.0402 |  |  | TRUE | 20 |
| bodily_injury | 1 | driver |  | 0.0469 | 0.0434 | 0.0404 | -0.0004 | 1 | FALSE | 23 |
| bodily_injury | 2 | vehicle |  | 0.0469 | 0.0438 | 0.0398 | -0.0005 | 0 | FALSE | 23 |
| bodily_injury | 3 | make_model_te |  | 0.0478 | 0.0439 | 0.0402 | -0.0000 | 1 | FALSE | 21 |
| bodily_injury | 4 | usage |  | 0.0472 | 0.0437 | 0.0401 | -0.0003 | 0 | FALSE | 21 |
| bodily_injury | 5 | mileage_per_exposure |  | 0.0476 | 0.0437 | 0.0403 | -0.0001 | 1 | FALSE | 21 |
| bodily_injury | 6 | telematics |  | 0.0477 | 0.0445 | 0.0406 | 0.0003 | 2 | FALSE | 21 |
| bodily_injury | 7 | policy |  | 0.0480 | 0.0442 | 0.0409 | 0.0004 | 3 | FALSE | 25 |
| bodily_injury | 8 | customer |  | 0.0460 | 0.0450 | 0.0391 | -0.0006 | 1 | FALSE | 24 |
| bodily_injury | 9 | region_urban_te |  | 0.0475 | 0.0437 | 0.0404 | -0.0001 | 1 | FALSE | 21 |
| bodily_injury | 10 | weather_primary | raw | 0.0472 | 0.0438 | 0.0402 | -0.0002 | 0 | FALSE | 22 |
| bodily_injury | 10 | weather_primary | avg | 0.0475 | 0.0435 | 0.0401 | -0.0003 | 0 | FALSE | 22 |
| bodily_injury | 10 | weather_primary | avg_dev | 0.0450 | 0.0429 | 0.0401 | -0.0013 | 0 | FALSE | 24 |
| bodily_injury | 11 | weather_other |  | 0.0438 | 0.0412 | 0.0403 | -0.0022 | 1 | FALSE | 25 |
| bodily_injury | 12 | claim_history |  | 0.0477 | 0.0452 | 0.0423 | 0.0011 | 2 | TRUE | 23 |
| bodily_injury | 13 | address_property |  | 0.0476 | 0.0451 | 0.0422 | -0.0001 | 0 | FALSE | 26 |
| theft | 0 | base |  | 0.0197 | 0.0151 | 0.0222 |  |  | TRUE | 10 |
| theft | 1 | driver |  | 0.0192 | 0.0149 | 0.0223 | -0.0002 | 1 | FALSE | 13 |
| theft | 2 | vehicle |  | 0.0182 | 0.0145 | 0.0220 | -0.0008 | 0 | FALSE | 13 |
| theft | 3 | make_model_te |  | 0.0192 | 0.0155 | 0.0226 | 0.0001 | 2 | FALSE | 11 |
| theft | 4 | usage |  | 0.0193 | 0.0149 | 0.0218 | -0.0003 | 0 | FALSE | 12 |
| theft | 5 | mileage_per_exposure |  | 0.0196 | 0.0150 | 0.0221 | -0.0001 | 0 | FALSE | 11 |
| theft | 6 | telematics |  | 0.0193 | 0.0150 | 0.0222 | -0.0002 | 1 | FALSE | 11 |
| theft | 7 | policy |  | 0.0196 | 0.0152 | 0.0241 | 0.0006 | 2 | TRUE | 15 |
| theft | 8 | customer |  | 0.0165 | 0.0141 | 0.0234 | -0.0016 | 0 | FALSE | 19 |
| theft | 9 | region_urban_te |  | 0.0192 | 0.0149 | 0.0240 | -0.0002 | 0 | FALSE | 16 |
| theft | 10 | weather_primary | raw | 0.0193 | 0.0152 | 0.0241 | -0.0001 | 2 | FALSE | 17 |
| theft | 10 | weather_primary | avg | 0.0192 | 0.0150 | 0.0241 | -0.0002 | 0 | FALSE | 17 |
| theft | 10 | weather_primary | avg_dev | 0.0156 | 0.0138 | 0.0239 | -0.0018 | 0 | FALSE | 19 |
| theft | 11 | weather_other |  | 0.0037 | 0.0140 | 0.0244 | -0.0056 | 1 | FALSE | 20 |
| theft | 12 | claim_history |  | 0.0196 | 0.0151 | 0.0256 | 0.0005 | 1 | FALSE | 18 |
| theft | 13 | address_property |  | 0.0183 | 0.0149 | 0.0239 | -0.0006 | 0 | FALSE | 18 |
| glass_hail | 0 | base |  | 0.0140 | 0.0201 | 0.0160 |  |  | TRUE | 7 |
| glass_hail | 1 | driver |  | 0.0139 | 0.0195 | 0.0161 | -0.0002 | 1 | FALSE | 10 |
| glass_hail | 2 | vehicle |  | 0.0134 | 0.0194 | 0.0159 | -0.0005 | 0 | FALSE | 10 |
| glass_hail | 3 | make_model_te |  | 0.0145 | 0.0197 | 0.0160 | 0.0000 | 2 | FALSE | 8 |
| glass_hail | 4 | usage |  | 0.0160 | 0.0225 | 0.0185 | 0.0023 | 3 | TRUE | 9 |
| glass_hail | 5 | mileage_per_exposure |  | 0.0157 | 0.0225 | 0.0185 | -0.0001 | 1 | FALSE | 10 |
| glass_hail | 6 | telematics |  | 0.0160 | 0.0225 | 0.0184 | -0.0001 | 0 | FALSE | 10 |
| glass_hail | 7 | policy |  | 0.0172 | 0.0243 | 0.0205 | 0.0016 | 3 | TRUE | 14 |
| glass_hail | 8 | customer |  | 0.0167 | 0.0233 | 0.0198 | -0.0007 | 0 | FALSE | 18 |
| glass_hail | 9 | region_urban_te |  | 0.0169 | 0.0240 | 0.0205 | -0.0002 | 1 | FALSE | 15 |
| glass_hail | 10 | weather_primary | raw | 0.0262 | 0.0346 | 0.0301 | 0.0096 | 3 | TRUE | 16 |
| glass_hail | 10 | weather_primary | avg | 0.0206 | 0.0287 | 0.0245 | 0.0039 | 3 | FALSE | 16 |
| glass_hail | 10 | weather_primary | avg_dev | 0.0259 | 0.0324 | 0.0292 | 0.0085 | 3 | FALSE | 18 |
| glass_hail | 11 | weather_other |  | 0.0203 | 0.0342 | 0.0294 | -0.0023 | 0 | FALSE | 21 |
| glass_hail | 12 | claim_history |  | 0.0262 | 0.0361 | 0.0332 | 0.0015 | 2 | TRUE | 19 |
| glass_hail | 13 | address_property |  | 0.0257 | 0.0359 | 0.0329 | -0.0003 | 0 | FALSE | 22 |

## Claims development / IBNR by peril

`ibnr_count_factor` = developed / reported claims from the 3b report-lag pattern (method column); `cost_understatement` = share of developed cost not yet reported; `sev_open_vs_closed` = mean open / mean closed net cost.

| peril | policy_year | reported_claims | developed_claims | reported_cost | developed_cost | open_share | sev_open_vs_closed | paid_to_incurred_open | recovery_ratio_closed | median_report_lag | ibnr_count_factor | cost_understatement | method |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bodily_injury | 2021 | 2,144 | 2,144.802 | 45,990,507.580 | 46,007,778.774 | 0.150 | 0.968 | 0.331 | 0 | 129 | 1.000 | 0.000 | M0_current |
| bodily_injury | 2022 | 2,141 | 2,151.119 | 47,452,043.170 | 47,676,395.259 | 0.278 | 0.911 | 0.318 | 0 | 124 | 1.005 | 0.005 | M0_current |
| bodily_injury | 2023 | 2,049 | 2,167.034 | 47,757,789.460 | 50,522,247.003 | 0.493 | 1.640 | 0.178 | 0 | 117 | 1.058 | 0.055 | M0_current |
| bodily_injury | 2024 | 1,178 | 2,078.893 | 21,002,612.880 | 36,269,836.126 | 0.798 | 1.041 | 0.165 | 0 | 68 | 1.765 | 0.421 | M0_current |
| glass_hail | 2021 | 3,572 | 3,572 | 3,374,619.430 | 3,374,619.430 | 0 |  |  | 0 | 5 | 1 | 0 | M2_chain_ladder |
| glass_hail | 2022 | 3,939 | 3,939 | 4,144,808.510 | 4,144,808.510 | 0 |  |  | 0 | 6 | 1 | 0 | M2_chain_ladder |
| glass_hail | 2023 | 4,112 | 4,119.310 | 4,702,197.790 | 4,710,584.024 | 0 |  |  | 0 | 6 | 1.002 | 0.002 | M2_chain_ladder |
| glass_hail | 2024 | 4,020 | 4,128.780 | 4,786,720.970 | 4,915,041.189 | 0.056 | 0.991 | 0.250 | 0 | 5 | 1.027 | 0.026 | M2_chain_ladder |
| own_damage | 2021 | 11,980 | 11,980 | 20,689,886.530 | 20,689,886.530 | 0 |  |  | 0.237 | 7 | 1 | 0 | M2_chain_ladder |
| own_damage | 2022 | 12,871 | 12,871 | 23,141,076.060 | 23,141,076.060 | 0 |  |  | 0.227 | 7 | 1 | 0 | M2_chain_ladder |
| own_damage | 2023 | 11,870 | 11,882.282 | 22,245,952.090 | 22,269,240.380 | 0.002 | 0.817 | 0.403 | 0.238 | 7 | 1.001 | 0.001 | M2_chain_ladder |
| own_damage | 2024 | 11,537 | 11,928.085 | 23,525,799.820 | 24,348,557.171 | 0.171 | 1.463 | 0.246 | 0.243 | 7 | 1.034 | 0.034 | M2_chain_ladder |
| theft | 2021 | 1,479 | 1,479 | 8,982,966.210 | 8,982,966.210 | 0 |  |  | 0.035 | 4 | 1 | 0 | M2_chain_ladder |
| theft | 2022 | 1,536 | 1,536 | 9,048,594.890 | 9,048,594.890 | 0.001 | 5.236 | 0.555 | 0.045 | 4 | 1 | 0 | M2_chain_ladder |
| theft | 2023 | 1,601 | 1,602.796 | 10,666,907.060 | 10,679,185.709 | 0.001 | 0.708 | 0.077 | 0.037 | 4 | 1.001 | 0.001 | M2_chain_ladder |
| theft | 2024 | 1,503 | 1,532.084 | 9,860,005.610 | 10,051,391.286 | 0.161 | 1.159 | 0.223 | 0.045 | 4 | 1.019 | 0.019 | M2_chain_ladder |
| third_party_prop | 2021 | 8,179 | 8,179 | 26,859,461.330 | 26,859,461.330 | 0 |  |  | 0 | 15 | 1 | 0 | M2_chain_ladder |
| third_party_prop | 2022 | 8,801 | 8,801 | 31,104,202.280 | 31,104,202.280 | 0 |  |  | 0 | 14 | 1 | 0 | M2_chain_ladder |
| third_party_prop | 2023 | 8,357 | 8,369.494 | 31,934,857.300 | 31,982,692.895 | 0.006 | 1.131 | 0.429 | 0 | 14 | 1.001 | 0.001 | M2_chain_ladder |
| third_party_prop | 2024 | 7,626 | 8,125.036 | 31,491,837.610 | 33,567,459.845 | 0.268 | 1.053 | 0.235 | 0 | 13 | 1.065 | 0.062 | M2_chain_ladder |

Treatment: frequency uses exposure x reported share (offset), so late-reported claims are allowed for per peril and per row; long-tail perils (
bodily_injury
) fit severity on policy years before 2023 and get a 2024 frequency dummy; open own_damage / theft claims can have expected recoveries deducted (decision above); other open case estimates are taken as adequate (one valuation date, so case development cannot be estimated).

## Weather

Join rule: address_id + calendar year of period_start. No row spans a calendar year (data checks), so the rule is exact. `ratio_2025` = spread of 2025 deviations from the address average relative to 2021-24; well below 1 would indicate a forecast / climatology.

| variable | year | mean | sd | sd_dev_from_addr_avg | cor_with_addr_avg | ratio_2025 |
|---|---|---|---|---|---|---|
| freezing_days | 2021 | 41.274 | 19.914 | 7.663 | 0.933 | 1.645 |
| freezing_days | 2022 | 36.978 | 21.806 | 6.416 | 0.956 | 1.645 |
| freezing_days | 2023 | 34.705 | 19.425 | 8.745 | 0.914 | 1.645 |
| freezing_days | 2024 | 39.482 | 24.552 | 8.551 | 0.949 | 1.645 |
| freezing_days | 2025 | 35.891 | 19.763 | 12.905 | 0.797 | 1.645 |
| hail_days | 2021 | 5.638 | 3.827 | 3.138 | 0.636 | 0.915 |
| hail_days | 2022 | 6.725 | 4.085 | 3.206 | 0.647 | 0.915 |
| hail_days | 2023 | 6.256 | 4.105 | 3.221 | 0.646 | 0.915 |
| hail_days | 2024 | 6.768 | 4.354 | 3.304 | 0.659 | 0.915 |
| hail_days | 2025 | 5.888 | 3.642 | 2.944 | 0.645 | 0.915 |

Conclusion: 2025 weather behaves like observed weather; provenance is not documented. The ladder also tests the 2021-24 address average, which does not depend on 2025 values.

## Leakage and exclusions

| feature | decision | reason |
|---|---|---|
| written_premium, discount_applied, premium_index | excluded | current pricing output: priced on past claims experience, so it carries the target into the features |
| renewal_decision | excluded | row outcome, training only (trap 7) |
| customer_service_contacts | excluded | about 3 contacts per row with a claim vs 0.4 without; recorded after the loss |
| compulsory_excess | excluded (checked) | insurer-set, so potentially driven by claims experience; constant in the data (see data checks), so no signal either way |
| email_domain, vehicle_colour, document_preference, marketing_consent | excluded | look uniform / possible sensitive proxies (trap 9); not rating factors |
| campaign_code, branch_id, marketing_segment, previous_insurer | excluded | marketing or distribution codes, no causal motor link; previous_insurer unstable in BEN 1 drop test |
| soil_type, distance_to_river_km, elevation_m, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels | excluded | buildings-peril address fields; property_type, flood_zone and year_built are tested once as a group in the ladder |
| customer_since_year, policy_year as a feature | excluded (trend term only) | calendar drift handled by a capped GLM trend, not by tree splits |

Kept with justification: ncb_years and prior_claims_5y (declared / known at quote); hist_* and claim_free_years use only claims reported before 1 January of the row's year (same cut-off as 2025 quotes); telematics_score is used as flag + value (blank = not opted in, never imputed; NA becomes its own spline indicator / tree missing branch).

## Exposure handling

| component | handling |
|---|---|
| Frequency GLM | Poisson on claim counts with offset log(exposure x reported share) |
| Frequency GLM zero-row sampling | all claim rows + a random share r of zero rows, weighted 1/r so exposure totals are preserved |
| XGBoost frequency | count:poisson on counts with base_margin = log(exposure x reported share) |
| Severity GLM / XGBoost | claim-count weights (cost per claim; exposure is not relevant) |
| Line Tweedie XGBoost | label = capped developed cost / exposure, weight = exposure |
| Target encodings | credibility-weighted claims / effective exposure |
| D2 baseline | constant cost per exposure-year x row exposure |
| Normalised Gini | rows ranked and counted equally regardless of exposure - FLAG: secondary metric only |
| Legacy replay sample | 250k rows sampled uniformly (not exposure-weighted), then exposure-weighted fit - FLAG: inherited from SAM phase 0 |

## Overfitting check (Poisson D2 train sample vs validation)

| valid_year | peril | model | pois_d2_train | pois_d2_valid | gap |
|---|---|---|---|---|---|
| 2022 | own_damage | f_glm | 0.0848 | 0.0806 | 0.0042 |
| 2022 | own_damage | f_xgb | 0.1147 | 0.0768 | 0.0379 |
| 2022 | third_party_prop | f_glm | 0.0799 | 0.0729 | 0.0070 |
| 2022 | third_party_prop | f_xgb | 0.1147 | 0.0669 | 0.0478 |
| 2022 | bodily_injury | f_glm | 0.0568 | 0.0479 | 0.0089 |
| 2022 | bodily_injury | f_xgb | 0.1072 | 0.0354 | 0.0718 |
| 2022 | theft | f_glm | 0.0268 | 0.0196 | 0.0072 |
| 2022 | theft | f_xgb | 0.0799 | 0.0016 | 0.0782 |
| 2022 | glass_hail | f_glm | 0.0372 | 0.0262 | 0.0110 |
| 2022 | glass_hail | f_xgb | 0.0713 | 0.0179 | 0.0533 |
| 2023 | own_damage | f_glm | 0.0825 | 0.0724 | 0.0101 |
| 2023 | own_damage | f_xgb | 0.1000 | 0.0745 | 0.0254 |
| 2023 | third_party_prop | f_glm | 0.0792 | 0.0686 | 0.0106 |
| 2023 | third_party_prop | f_xgb | 0.0977 | 0.0690 | 0.0287 |
| 2023 | bodily_injury | f_glm | 0.0557 | 0.0455 | 0.0102 |
| 2023 | bodily_injury | f_xgb | 0.0801 | 0.0411 | 0.0390 |
| 2023 | theft | f_glm | 0.0204 | 0.0151 | 0.0053 |
| 2023 | theft | f_xgb | 0.0543 | 0.0112 | 0.0431 |
| 2023 | glass_hail | f_glm | 0.0334 | 0.0360 | -0.0026 |
| 2023 | glass_hail | f_xgb | 0.0539 | 0.0329 | 0.0210 |
| 2024 | own_damage | f_glm | 0.0806 | 0.0780 | 0.0026 |
| 2024 | own_damage | f_xgb | 0.0954 | 0.0782 | 0.0172 |
| 2024 | third_party_prop | f_glm | 0.0758 | 0.0638 | 0.0120 |
| 2024 | third_party_prop | f_xgb | 0.0934 | 0.0620 | 0.0314 |
| 2024 | bodily_injury | f_glm | 0.0565 | 0.0421 | 0.0144 |
| 2024 | bodily_injury | f_xgb | 0.0801 | 0.0406 | 0.0395 |
| 2024 | theft | f_glm | 0.0232 | 0.0239 | -0.0008 |
| 2024 | theft | f_xgb | 0.0513 | 0.0207 | 0.0306 |
| 2024 | glass_hail | f_glm | 0.0333 | 0.0331 | 0.0002 |
| 2024 | glass_hail | f_xgb | 0.0506 | 0.0314 | 0.0192 |

## Flags

- Claim-history features kept: their visible window grows from 0 years (2021) to 4 (2025), so part of their effect is confounded with calendar time and the 2025 distribution is outside the training range.
- Weather kept for some perils; 2025 values vary like observed years, but nothing in the data documents whether they are observed or forecast.
- Train-validation Poisson D2 gap > 0.02 for: own_damage f_xgb, third_party_prop f_xgb, bodily_injury f_xgb, theft f_xgb, glass_hail f_xgb.
- Decisions (ladder, severity, mixing weights, line blend) were chosen on the same three folds they are reported on, so the stage-table gains are optimistic; changes below about 0.001 D2 are within fold noise.
- 2024 actuals are immature (bodily_injury about 80% open), so the 2024 fold rewards under-prediction; level is judged on developed A/E and against SAM 4, not on raw 2024 D2.

## 2025 test predictions

| peril | predicted_total | cost_per_exposure_year |
|---|---|---|
| own_damage | 24,772,396.49 | 123.872151868024 |
| third_party_prop | 34,731,722.18 | 173.672868706499 |
| bodily_injury | 65,804,545.27 | 329.049740001219 |
| theft | 10,528,352.65 | 52.6460852952245 |
| glass_hail | 5,073,440.82 | 25.3692868083981 |
| total | 140,910,457.42 | 704.610132679365 |

Own level 704.61 vs SAM 4 607.41 per exposure-year (scale 0.8621). The public-score test (#10) favoured the SAM level, so `motor_only_20261023_1124_samlevel.csv` is the recommended file; `motor_only_20261023_1124.csv` keeps this model's own level.

Replication: saved model reloaded from `fitted/motor01_peril.rds` and re-scored, max abs diff 0.

