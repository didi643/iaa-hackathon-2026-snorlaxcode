# Week 2 - data checks and cleaning decisions (emerging market)

Prepared 25 Oct 2026. This is the reasoning behind `week2/R/1_checks_w2.R` (read-only checks) and `week2/R/2_clean_w2.R`
(cleaning). The generated reports with every count are:

- `week2/output/1_checks/checks_report.md`
- `week2/output/2_clean/cleaning_report.md`

Week 1 work is not touched. It lives in `week1/` and `data/week_1/`.

## The task

Predict the 2025 claim cost of every row in `emerging/test_{motor,buildings,contents}`.

- **Training history:** two policy years, 2023 and 2024, valued at 31 Dec 2024.
- **2025 portfolio:** mostly a portfolio taken over from a broker. 76% of test rows are new business, against 14% in training.
- **Part 1 data:** the `developed/` folder is the Part 1 (week 1) market. It is byte-identical to `data/week_1/raw data/`.

## Data issues found and how they are handled

| # | Issue (emerging) | Evidence | Decision |
|---|---|---|---|
| 1 | Exposure inconsistent with the period dates | 254 motor, 155 buildings, 200 contents training rows. A few hold days, most hold days/360. None in test | Recompute as (end - start + 1) / 365. Same trap and rule as week 1 |
| 2 | Sum insured ×1000 | 53 buildings and 57 contents training rows, 104 and 135 test rows above 5m / 2m. All are divisible by 1000; 99th percentile ~0.5m / ~0.12m | Divide by 1000. Same rule as week 1 |
| 3 | `construction_type` uses local codes | BRK / STN / WOD / MIX on every emerging row. The data notes give the mapping | Map to brick / stone / timber / non_standard, so the developed market uses the same levels (its own casing and T/W variants are fixed as in week 1) |
| 4 | `occupation` is free text | 80 spellings ("Retired", "retired", "Retired "). 12k customers (8.8%) entered "self-employed <job>" | Lower-case and trim, giving 20 occupations. "Self-employed" becomes its own flag (`self_employed`); it isn't a separate occupation |
| 5 | Claims before the market existed | 34 claims with loss dates in 2021-22 (policies start in 2023), plus 2 in gaps between policy rows | They match no policy row, so they are excluded from targets and listed in `unmatched_claims.csv` |
| 6 | Ages only in bands | `driver_age_band` / `policyholder_age_band` (5 bands); no date of birth | Developed ages are banded the same way, so the markets share one age feature. The exact developed ages are kept with a `_developed` suffix |
| 7 | `customer_service_contacts` leaks the outcome | Motor rows with a claim average 3.4 contacts, against 0.4 without (same as week 1) | Kept in the data, excluded as a feature (`features_w2.csv`) |
| 8 | `renewal_decision` is the row's own outcome | Training files only | Dropped (as in week 1) |
| 9 | About 12% missing values in several fields | e.g. `vehicle_age`, `engine_size_cc`, `overnight_parking`, `security_level`, `smoke_alarms`, `soil_type`, `energy_rating`, `occupation`, `marital_status` | Missing categories become a level, `missing`; missing numbers stay NA. Missingness may carry signal, so the decision is left to the model |
| 10 | IDs overlap across markets | 752 customer ids and 8,046 address ids also appear in the developed market | Unrelated records (data notes). Never join across markets; every table stays within its own market |

Checks that passed:

- no duplicate or malformed ids, no duplicate claim bookings (the week 1 trap 10 is absent here)
- no reversed dates, no overlapping rows, no impossible years licensed for the age band
- new business is consistent with renewal count
- claim amounts are consistent (paid ≤ incurred, recoveries ≤ incurred, repudiated = 0)
- every policy row joins to a customer, an address and that year's weather

## What is different about the emerging market (first look)

From `checks_report.md`, section D. These are reported figures at 31 Dec 2024, not developed to ultimate; 2024 is immature in both markets.

| Area | Emerging vs developed (policy years 2023-24) | Why it matters |
|---|---|---|
| Motor | Claim frequency ×1.1-1.8 and severity ×0.45-0.7 across perils; burn ×0.6-1.2 | Cheaper claims but more of them. Carrying over the developed level would overprice |
| Buildings | Storm frequency ×1.3-1.7; escape of water burn ×0.4; fire volatile (×3.0 in 2023, ×0.9 in 2024) | Thin data per peril: about 500 buildings claims a year |
| Contents | Frequency ×0.85, severity ×0.8, burn about ×0.75 | |
| Climate | About 2.4 times the hail days, 3.5 times the wildfire index, warmer (15.5 vs 13.0 °C), half the freezing days | Weather perils behave differently; developed weather effects may not transfer |
| Portfolio | Broker channel about 70% (developed is mostly direct / comparison sites); older vehicles (10.3 vs 8.5 years); fewer no-claims-bonus years; discounts halved | Channel and mix shift; the PSI of `channel` is 1.1 |
| Features | Emerging has `gender`. It lacks exact ages, telematics, annual mileage and credit band | Part 1 models that use those features can't be applied directly |
| 2025 test | 76% new business; more young age bands (17-34 make up 50% of motor test rows, against 39% in training) | Training is mostly renewals: a big mix shift |
| Expenses | Fixed 85 vs 45 CU; broker commission 20%; catastrophe reinsurance 12% vs 6%; target profit 8% | For the office premium build-up in the report |

## Open questions for modelling (not cleaning decisions)

- **Development to ultimate (IBNR):** emerging 2024 has 20-25% of claims still open. Its report lags are similar to the developed market's, so developed reporting patterns could be borrowed.
- **New business:** how to price the broker portfolio when training is mostly renewals. Options are new-business relativities or carrying them over from developed.
- **Large losses:** buildings has about 500 claims a year and a single claim reaches 361k CU. That needs a credible cap and loading.
- **2025 weather:** the files include realised 2025 weather, as in week 1. Decide whether to use it or long-run averages (`wx_avg_*` over 2023-24 for emerging).
