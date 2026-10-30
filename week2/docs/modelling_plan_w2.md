# Week 2 - modelling plan (emerging market)

Draft, 25 Oct 2026. Based on `cleaning_decisions_w2.md` and `week2/output/1_checks/checks_report.md`.

## Constraints from the data

- **Two training years** (2023, 2024), about 47k motor / 27k buildings / 35k contents rows and 3.5k / 0.5k / 0.5k claims a year. The developed market has 10-20 times the data.
- **Claims valued at 31 Dec 2024.** 2024 has 20-25% of claims still open and late-reported claims are missing. The emerging report lags look like the developed ones.
- **2025 is mostly new business** (76% vs 14% in training) from a broker. The age mix is younger.
- **Different market:** motor claims are more frequent but cheaper; storm and hail are heavier; escape of water is cheaper. Some features are missing (exact ages, telematics, mileage, credit band), and `gender` is new.

## Validation protocol (local, before any submission)

- **Fold:** fit on 2023, score 2024 (the only out-of-time fold). Also run 2-fold cross-validation on 2023-24 grouped by policy, for stability.
- **Metric:** Tweedie D² (p = 1.5) on reported actuals and on developed actuals (reported ÷ reported share), with a paired policy bootstrap, as in week 1.
- **New-business check:** score the new-business rows of 2024 separately, since 2025 is mostly new business.

## Build steps (each one a separate script)

| Step | Script | What |
|---|---|---|
| 3 | `3_ibnr_w2.R` | Reporting pattern per peril: emerging lags where credible, developed chain-ladder shares otherwise. Gives ultimate targets for training and developed actuals for validation |
| 4 | `4_drift_w2.R` | What changed vs Part 1: relativities of shared features (emerging GLM vs developed GLM on the common features), new-business vs renewal relativity in both markets, peril mix, severity distributions and tails. Decides what carries over |
| 5 | `5_models_w2_base.R` | Emerging-only models: per-peril Poisson frequency × gamma severity (GLM and lightly regularised LightGBM), large losses capped with a loading, trended to 2025 |
| 6 | `5_models_w2_transfer.R` | Transfer from Part 1: a developed model on the common features gives the shape, and the emerging data recalibrates it (level per peril plus boosting from the developed prediction as a base margin, or a credibility blend of relativities) |
| 7 | `6_blend_w2.R` | Blend per line or peril on the validation fold, new-business adjustment, final 2025 fit, submission file |
| 8 | `7_premium_w2.R` | Office premium build-up for the 20 reference policies (expenses, commission by channel, tax, catastrophe reinsurance on property, profit) |
| 9 | `8_uncertainty_w2.R` | Uncertainty: bootstrap ranges, sensitivity to IBNR / new business / trend / transfer weight, for the report |

## Carried over from week 1 (code and lessons)

- **Code:** the IBNR study (3b), freq × sev per peril, the Tweedie D² protocol and bootstrap.
- **Lessons:** post-hoc tuning on the folds did not transfer to public, and averaging versions / model families helps (TAKEAWAYS).
- **Not carried:** the exact week 1 models. They need features the emerging market doesn't have and too many years of history.
