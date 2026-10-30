# What we carried over from Part 1

| Part 1 component | Status | What and why | Evidence |
|---|---|---|---|
| Cleaning rules (exposure recompute, 1000x sum insured, duplicate claims, unmatched claims, leakage guardrails) | **kept** | The same traps exist in emerging. One shared `clean_policy()` cleans both markets. | `week_2/output/02_clean/data_checks.csv` |
| Target definition (incurred - recoveries, repudiated = 0, net of excess, open-claim recovery adjustment, 2m single-claim limit) | **kept** | Same claim data structure. | `00_setup_week2.R` `claim_basis()` |
| Excluded fields (compulsory_excess, written_premium, customer_service_contacts, renewal_decision, marketing/noise) | **kept** | The leakage was re-checked and is still present in emerging. | `01_profile/customer_service_contacts_check.csv` |
| Feature set | **adjusted** | Shared fields only. Ages become bands; region, credit, mileage and telematics are dropped; construction and occupation codes are mapped. | `03_features/feature_map.csv` |
| Relativities (WENDY 7 C5 per-peril XGBoost frequency x severity) | **kept as the shape** | Refitted on developed 2021-24 with shared features. 1 bag instead of 5 (run time). Frequency x severity for every peril, including BI and contents EoW, where C5 used Tweedie, because step 7 adjusts frequency and severity separately. Developed D2 0.0965 vs C5 0.1026. | `models/baseline/model_card.md` |
| Level (developed intercept / balance) | **dropped** | Emerging frequency is 0.79-1.33x and severity 0.57-0.80x the developed level. Re-estimated per peril on emerging data with credibility toward the line's pooled level. | `07_adjust/levels.csv` |
| IBNR (chain ladder on counts, subsidence ECDF override) | **kept** | Emerging lags are statistically the same for the same loss years; the emerging-only chain ladder agrees. | `04_ibnr_trend/lag_comparison.csv` |
| Trends | **adjusted** | Developed log-linear trends are the prior, blended with the emerging 2023->24 change using Z = n/(n+2000). Frequency trend only for motor OD / TPP. Motor BI has no trend (as C5). | `04_ibnr_trend/trend_table.csv` |
| Caps and large-loss treatment | **adjusted** | Developed cap quantiles and load (the shape). Emerging severity level fitted on claims capped at the developed cap x emerging level. | `07_adjust/levels.csv` |
| Claim-history features (prior-year own policy, customer's other lines) | **kept** | Built the same way from each market's own claims, known at row start. 76% of 2025 rows are new business, so for them the history is NA. | `03_features/history_summary.csv` |
| WENDY 8 row credibility / WENDY 9 ladder / SAM 3 / MOTOR 2 blend | **dropped** | Needs long own histories (at most 1 prior year in emerging) or market-specific components; out of Option B scope. | - |
| Validation protocol (out-of-time folds, reported_raw + developed bases, paired policy bootstrap) | **adjusted** | One honest fold (emerging 2023 -> 2024), also reweighted to the 2025 new-business x channel mix. Noise is about 10x week 1's: 2 SE of B - L is 0.0010, and B's 90% interval is about 0.03 wide. | `09_validate/main/` |
| Credibility | **extended** | Week 1 used it on row history. Week 2 uses it for factor adjustments (ridge, lambda 100), peril levels (K 100 / 200 / 600) and the new-business and trend loadings. | `decision_register.csv` D018, D020, D022 |
| Method choice per peril on mixed-year CV | **not used** | Week 1 lesson: per-peril choices did not transfer across years. One method everywhere. | - |
