# WENDY 6 - H2O AutoML per peril and component

**Run id** `20261022_0211` | **H2O** 3.44.0.3 | **Workbook** `docs/assumptions_wendy06.xlsx` | **Submission** `submission_20261022_0211_wendy06.csv` (MD5 `7ea164fbe4dea72b21fd2a6c162b6d99`)

1200 s per AutoML run, 5 policy-grouped folds, phases time_check + final.
AutoML with a time budget is not exactly reproducible; the leaders of the final phase are saved under `leaders/` (H2O binary models, same H2O version needed to load).

## Time check (Tweedie D2 vs developed actuals)
| line | time_2024 |
|---|---|
| ALL | 0.1007 |
| buildings | 0.0725 |
| contents | 0.0530 |
| motor | 0.0496 |

### By peril
| line | peril | freq_sev |
|---|---|---|
| buildings | accidental_damage | 0.1366 |
| buildings | escape_of_water | 0.0461 |
| buildings | fire | 0.0327 |
| buildings | flood | 0.4262 |
| buildings | storm | 0.0633 |
| buildings | subsidence | 0.0760 |
| contents | accidental_damage | 0.0822 |
| contents | escape_of_water | 0.0441 |
| contents | flood | 0.2654 |
| contents | theft | 0.0232 |
| motor | bodily_injury | 0.0342 |
| motor | glass_hail | 0.1389 |
| motor | own_damage | 0.1650 |
| motor | theft | 0.0794 |
| motor | third_party_prop | 0.0508 |

## Leaders
| line | peril | phase | part | algo | models | bal | trend |
|---|---|---|---|---|---|---|---|
| motor | own_damage | time_check | freq | xgboost | 33 | 1.000 | -0.011 |
| motor | own_damage | time_check | sev | xgboost | 202 | 2.522 | 0.040 |
| motor | own_damage | final | freq | xgboost | 26 | 1.000 | -0.011 |
| motor | own_damage | final | sev | glm | 124 | 1.000 | 0.037 |
| motor | third_party_prop | time_check | freq | xgboost | 19 | 0.998 | 0.004 |
| motor | third_party_prop | time_check | sev | gbm | 172 | 1.001 | 0.078 |
| motor | third_party_prop | final | freq | xgboost | 17 | 1.000 | -0.017 |
| motor | third_party_prop | final | sev | gbm | 161 | 1.001 | 0.078 |
| motor | bodily_injury | time_check | freq | xgboost | 29 | 1.004 | 0.011 |
| motor | bodily_injury | time_check | sev | stackedensemble | 331 | 0.996 | 0.039 |
| motor | bodily_injury | final | freq | xgboost | 24 | 0.989 | -0.004 |
| motor | bodily_injury | final | sev | stackedensemble | 333 | 0.982 | -0.020 |
| motor | theft | time_check | freq | glm | 29 | 1.000 | 0 |
| motor | theft | time_check | sev | xgboost | 177 | 434.609 | 0.049 |
| motor | theft | final | freq | glm | 25 | 1.000 | 0 |
| motor | theft | final | sev | xgboost | 208 | 1.004 | 0.035 |
| motor | glass_hail | time_check | freq | glm | 37 | 1.000 | 0 |
| motor | glass_hail | time_check | sev | glm | 250 | 1.000 | 0.099 |
| motor | glass_hail | final | freq | glm | 30 | 1.000 | 0 |
| motor | glass_hail | final | sev | glm | 230 | 1.000 | 0.080 |
| buildings | storm | time_check | freq | xgboost | 74 | 1.005 | 0 |
| buildings | storm | time_check | sev | gbm | 636 | 1.013 | 0.083 |
| buildings | storm | final | freq | xgboost | 50 | 0.903 | 0 |
| buildings | storm | final | sev | gbm | 447 | 1.009 | 0.084 |
| buildings | flood | time_check | freq | xgboost | 91 | 1.021 | 0 |
| buildings | flood | time_check | sev | gbm | 1,133 | 1.020 | 0.066 |
| buildings | flood | final | freq | xgboost | 74 | 0.997 | 0 |
| buildings | flood | final | sev | gbm | 679 | 1.033 | 0.069 |
| buildings | escape_of_water | time_check | freq | glm | 67 | 1.000 | 0 |
| buildings | escape_of_water | time_check | sev | gbm | 594 | 1.009 | 0.079 |
| buildings | escape_of_water | final | freq | xgboost | 48 | 0.981 | 0 |
| buildings | escape_of_water | final | sev | gbm | 331 | 1.008 | 0.085 |
| buildings | subsidence | time_check | freq | xgboost | 76 | 1.002 | 0 |
| buildings | subsidence | time_check | sev | gbm | 832 | 1.048 | 0.033 |
| buildings | subsidence | final | freq | xgboost | 67 | 0.838 | 0 |
| buildings | subsidence | final | sev | gbm | 697 | 1.024 | 0.023 |
| buildings | fire | time_check | freq | glm | 51 | 1.000 | 0 |
| buildings | fire | time_check | sev | gbm | 834 | 1.033 | -0.020 |
| buildings | fire | final | freq | glm | 59 | 1.000 | 0 |
| buildings | fire | final | sev | gbm | 763 | 1.062 | -0.020 |
| buildings | accidental_damage | time_check | freq | glm | 60 | 1.000 | 0 |
| buildings | accidental_damage | time_check | sev | gbm | 819 | 1.004 | -0.003 |
| buildings | accidental_damage | final | freq | glm | 50 | 1.000 | 0 |
| buildings | accidental_damage | final | sev | gbm | 743 | 1.007 | 0.022 |
| contents | theft | time_check | freq | xgboost | 54 | 0.872 | 0 |
| contents | theft | time_check | sev | gbm | 394 | 1.017 | 0.020 |
| contents | theft | final | freq | glm | 44 | 1.000 | 0 |
| contents | theft | final | sev | gbm | 345 | 1.016 | 0.043 |
| contents | escape_of_water | time_check | freq | glm | 63 | 1.000 | 0 |
| contents | escape_of_water | time_check | sev | gbm | 474 | 1.024 | 0.034 |
| contents | escape_of_water | final | freq | glm | 58 | 1.000 | 0 |
| contents | escape_of_water | final | sev | gbm | 421 | 1.017 | 0.026 |
| contents | accidental_damage | time_check | freq | xgboost | 50 | 0.688 | 0 |
| contents | accidental_damage | time_check | sev | gbm | 499 | 1.009 | 0.015 |
| contents | accidental_damage | final | freq | glm | 41 | 1.000 | 0 |
| contents | accidental_damage | final | sev | gbm | 434 | 1.007 | 0.028 |
| contents | flood | time_check | freq | xgboost | 63 | 0.704 | 0 |
| contents | flood | time_check | sev | gbm | 627 | 1.022 | 0.048 |
| contents | flood | final | freq | xgboost | 56 | 0.530 | 0 |
| contents | flood | final | sev | gbm | 571 | 1.032 | 0.056 |

## Component out-of-fold deviance (compare with WENDY 5)
| line | peril | part | metric | value | n | model |
|---|---|---|---|---|---|---|
| motor | own_damage | freq | poisson_deviance | 0.25662 | 979,968 | XGBoost_3_AutoML_3_20261022_25335 |
| motor | own_damage | sev | gamma_deviance | 1.58090 | 48,258 | GLM_1_AutoML_4_20261022_31403 |
| motor | third_party_prop | freq | poisson_deviance | 0.21092 | 979,968 | XGBoost_3_AutoML_7_20261022_41454 |
| motor | third_party_prop | sev | gamma_deviance | 1.15666 | 32,963 | GBM_grid_1_AutoML_8_20261022_43531_model_87 |
| motor | bodily_injury | freq | poisson_deviance | 0.06977 | 979,968 | XGBoost_grid_1_AutoML_11_20261022_53436_model_1 |
| motor | bodily_injury | sev | gamma_deviance | 1.37202 | 6,334 | StackedEnsemble_Best1000_1_AutoML_12_20261022_55516 |
| motor | theft | freq | poisson_deviance | 0.06581 | 891,764 | GLM_1_AutoML_15_20261022_65430 |
| motor | theft | sev | gamma_deviance | 1.15996 | 6,119 | XGBoost_grid_1_AutoML_16_20261022_71507_model_4 |
| motor | glass_hail | freq | poisson_deviance | 0.14589 | 802,694 | GLM_1_AutoML_19_20261022_81324 |
| motor | glass_hail | sev | gamma_deviance | 1.15692 | 15,643 | GLM_1_AutoML_20_20261022_83358 |
| buildings | storm | freq | poisson_deviance | 0.09328 | 707,726 | XGBoost_grid_1_AutoML_23_20261022_94857_model_4 |
| buildings | storm | sev | gamma_deviance | 1.13280 | 7,762 | GBM_grid_1_AutoML_24_20261022_101417_model_242 |
| buildings | flood | freq | poisson_deviance | 0.02490 | 707,726 | XGBoost_grid_1_AutoML_27_20261022_111225_model_4 |
| buildings | flood | sev | gamma_deviance | 1.13649 | 2,219 | GBM_grid_1_AutoML_28_20261022_113329_model_210 |
| buildings | escape_of_water | freq | poisson_deviance | 0.11575 | 707,726 | XGBoost_grid_1_AutoML_31_20261022_123008_model_4 |
| buildings | escape_of_water | sev | gamma_deviance | 1.18153 | 10,065 | GBM_grid_1_AutoML_32_20261022_125037_model_241 |
| buildings | subsidence | freq | poisson_deviance | 0.02148 | 707,726 | XGBoost_grid_1_AutoML_35_20261022_134837_model_4 |
| buildings | subsidence | sev | gamma_deviance | 1.22931 | 997 | GBM_grid_1_AutoML_36_20261022_140923_model_485 |
| buildings | fire | freq | poisson_deviance | 0.01974 | 707,726 | GLM_1_AutoML_39_20261022_150603 |
| buildings | fire | sev | gamma_deviance | 1.32510 | 1,107 | GBM_grid_1_AutoML_40_20261022_152601_model_716 |
| buildings | accidental_damage | freq | poisson_deviance | 0.04983 | 707,726 | GLM_1_AutoML_43_20261022_162338 |
| buildings | accidental_damage | sev | gamma_deviance | 1.17227 | 3,825 | GBM_grid_1_AutoML_44_20261022_164411_model_107 |
| contents | theft | freq | poisson_deviance | 0.09311 | 721,617 | GLM_1_AutoML_47_20261022_174203 |
| contents | theft | sev | gamma_deviance | 1.16109 | 7,626 | GBM_grid_1_AutoML_48_20261022_180235_model_304 |
| contents | escape_of_water | freq | poisson_deviance | 0.07078 | 721,617 | GLM_1_AutoML_51_20261022_190028 |
| contents | escape_of_water | sev | gamma_deviance | 1.17599 | 5,366 | GBM_grid_1_AutoML_52_20261022_192106_model_250 |
| contents | accidental_damage | freq | poisson_deviance | 0.09615 | 721,617 | GLM_1_AutoML_55_20261022_201855 |
| contents | accidental_damage | sev | gamma_deviance | 1.18806 | 9,063 | GBM_grid_1_AutoML_56_20261022_203929_model_239 |
| contents | flood | freq | poisson_deviance | 0.01916 | 721,617 | XGBoost_grid_1_AutoML_59_20261022_213719_model_4 |
| contents | flood | sev | gamma_deviance | 1.14121 | 1,615 | GBM_grid_1_AutoML_60_20261022_215806_model_68 |

Run time this session 20.08 hours (resumed runs not included).
