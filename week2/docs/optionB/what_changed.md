# What changed between the developed and the emerging market

How we found out: step 1 profiles both markets from the raw files (`week_2/output/01_profile/`). Step 6 scores every
emerging 2023-24 row with a model built only on the developed book and reads actual vs expected
(`week_2/output/06_ae/`). The developed numbers are 2023-24 unless stated otherwise. All costs are net incurred with
repudiated claims excluded.

## 1. Data fields

| Area | Developed | Emerging | Consequence |
|---|---|---|---|
| Driver / policyholder age | exact age | 5 bands only (17-24, 25-34, 35-49, 50-64, 65+) | Developed ages cut into the same bands (band edges checked: 24 is in 17-24) |
| Motor usage | annual_mileage, telematics_opt_in, telematics_score | absent | Dropped from the baseline |
| Customer | credit_band, date_of_birth | gender (instead) | credit and age-from-DOB dropped; gender excluded pending Wendy (D002) |
| Region | R01-R12 | E01-E06, no mapping | Dropped; geography comes from the shared address and weather fields |
| construction_type | brick / stone / timber / non_standard (plus T/W codes) | BRK / STN / WOD / MIX | Mapped (D006); the MIX -> non_standard A/E is in line with the other levels |
| occupation | 20 clean levels | 81 raw levels (case, spaces, "Self-employed " prefix) | Normalised to the 20 levels; prefix kept as `self_employed` (emerging only) |
| Missing values | about 2.5% on optional fields | about 12% on the same fields | Kept as missing; the trees handle NA |
| Data traps | exposure in days, 1000x sum insured, duplicate claims | exposure in days (609 rows), 1000x sum insured, 34 claims dated before the book existed | Same fixes as week 1 |
| Leakage | customer_service_contacts | same pattern (3.0-3.4 contacts on claim rows vs 0.42 otherwise) | Still excluded |

Losing the developed-only fields costs little on developed data. Developed validation D2 (week 1 folds, ALL lines) is
0.0965 on shared fields against 0.1026 for week 1 C5 with all fields. Motor loses the most, because region and mileage
mattered there.

## 2. Customer and portfolio mix

- **2025 is a takeover.** Test exposure is **3.9 times** 2024 on every line (motor 79.0k vs 20.1k vehicle-years), and
  **77% is new business**, against 6-9% in training. The handover's "1.5 times" is corrected here.
- The new business looks like training new business on age band, channel and cover type. Because there is so much of
  it, the 2025 book is younger: 25% in 17-24 and 25% in 25-34, against 19-20% each in 2024.
- Channel mix (70% broker, 25% direct, 5% comparison site) and motor cover mix are unchanged.

## 3. Climate and geography

- Emerging is hotter, wetter and more hail- and fire-prone:
  - hail days 14.2 vs 6.3;
  - wildfire index 0.53 vs 0.16 (only 34% of emerging values fall inside the developed 1-99% range);
  - rainfall 1,336 vs 1,045 mm;
  - freezing days 22 vs 38.
- The developed trees cannot extrapolate beyond the developed range. The motor A/E has a significant slope in hail days,
  and step 7 keeps an emerging hail-days adjustment for motor glass/hail, own damage and BI. Buildings storm and fire
  show no significant weather slope once the level is re-estimated.

## 4. Frequency and severity, by peril

Emerging level relative to the developed baseline, from the step 7 final fit with credibility:

| Line | Peril | Frequency | Severity | Burn ratio | Reading |
|---|---|---|---|---|---|
| motor | own damage | 1.09 | 0.64 | 0.70 | more claims, much cheaper repairs |
| motor | third-party property | 1.17 | 0.57 | 0.66 | |
| motor | bodily injury | 1.19 | 0.57 | 0.67 | lower injury awards |
| motor | theft | 1.29 | 0.65 | 0.84 | |
| motor | glass / hail | 1.33 | 0.60 | 0.80 | hail climate |
| buildings | storm | 1.32 | 0.64 | 0.85 | windier |
| buildings | flood | 0.90 | 0.66 | 0.59 | |
| buildings | escape of water | 0.89 | 0.60 | 0.53 | |
| buildings | subsidence | 1.06 | 0.65 | 0.69 | 52 claims, so the level is mostly the prior |
| buildings | fire | 1.06 | 0.71 | 0.75 | raw severity 1.22x developed, but on 70 claims; 2023 heavy, 2024 light |
| buildings | accidental damage | 0.91 | 0.67 | 0.61 | |
| contents | theft | 1.04 | 0.80 | 0.84 | |
| contents | escape of water | 0.88 | 0.79 | 0.69 | |
| contents | accidental damage | 0.79 | 0.77 | 0.61 | |
| contents | flood | 0.90 | 0.79 | 0.71 | |

The pattern is consistent: **claims cost 20-45% less** (a cheaper repair and legal market), while motor and storm claims
are **more frequent**. Within a line, the developed relativities mostly hold. The only factors whose emerging A/E slopes
significantly (p < 0.01) are motor occupation, voluntary excess, driver age band, hail days, years licensed and NCB
years. Buildings construction type and sum insured are weak (p 0.01-0.05). Contents is flat.

## 5. Reporting

Both markets share the 31 Dec 2024 valuation date, so emerging and developed claims from the same loss years are
censored identically and can be compared directly. No peril shows a significant lag difference (KS p >= 0.01
everywhere; for example own damage median 7 / p90 23-24 days in both). An emerging-only chain ladder gives 2024 reported
shares within about 0.02 of the developed ones (BI 0.557 vs 0.563). **Reporting did not change.** The developed pattern
is used.

## 6. New business

- Developed motor new business claims 1.36-1.43 times as often as renewals.
- Emerging motor: 1.42 in 2023, 1.23 in 2024.
- The baseline already carries the developed new-business relativity. After it, emerging new business still runs above
  the model in motor (residual A/E 1.24 on 697 claims) and contents (1.20 on 102 claims), and below it in buildings
  (0.83 on 77 claims).
- These residuals are loaded with credibility in step 8: motor 1.17, contents 1.05, buildings 0.97.
