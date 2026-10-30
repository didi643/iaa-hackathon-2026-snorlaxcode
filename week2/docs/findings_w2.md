# Week 2 - findings: what changed vs Part 1 and what carries over

25 Oct 2026. The evidence is in:

- `week2/output/3_ibnr/ibnr_report.md` (step 3)
- `week2/output/4_drift/drift_report.md` (step 4)

These conclusions feed the modelling (steps 5-7) and the written report.

## 1. Claim reporting (IBNR): carry over

- **Same speed:** emerging and developed report claims at the same speed for every peril. Medians and the share reported within 7-730 days are nearly equal.
- **Backtest:** valuation 31 Dec 2023, predicting the 2023 losses reported during 2024. The developed curve predicts best: score 0.378 vs 0.474 for the emerging-only curve, total A/E 0.91.
- **Decision:** use the Part 1 reporting pattern.
- **Development to ultimate (on reported cost):**

  | Line | 2023 | 2024 |
  |---|---|---|
  | Motor | ×1.025 | ×1.227 (bodily injury only 57% reported) |
  | Buildings | ×1.003 | ×1.051 |
  | Contents | ×1.002 | ×1.021 |

## 2. Level: re-estimate per peril

Emerging experience against a developed GLM fitted on the shared features (same policy years 2023-24), with 95% intervals:

| Line | Frequency | Severity | Burn cost |
|---|---|---|---|
| Motor | ×1.12 (own damage) to ×1.41 (third-party property) | ×0.51 (bodily injury) to ×0.65 | ×0.66-0.88 |
| Buildings | storm ×1.42; flood ×0.78; accidental damage ×0.80; others ×1.0 | ×0.35 (subsidence) to ×0.75 | storm ×1.0, others ×0.35-0.67 |
| Contents | ×0.89-1.04 | ×0.69-0.87 | ×0.68-0.83 |

- **Severity is lower for every peril**, and the whole claim-size distribution is scaled down: the 50th, 90th and 99th percentiles are all lower by similar factors. That points to a lower cost level (repair, medical and building costs), not a different mix.
- **Motor claims are more frequent but cheaper.**
- **Storm is the one peril where emerging is as expensive as developed.** That fits the climate: about 2.4 times the hail days, windier, drier.

## 3. Shape: mostly carries over

- **Test:** for each peril and feature, an emerging GLM with the developed prediction as offset (LR test, p < 0.01).
- **Result:** most features don't differ. Per peril 0-5 of about 58 features differ (about 0.6 expected by chance), so developed relativities are a sound starting point, with the level re-estimated per peril.
- **Exception: weather.** Motor third-party property has 12 differing features, nearly all weather (temperature, freezing, dryness, wildfire, wind), and storm frequency has 3 weather features. The emerging climate lies outside the developed range, so developed weather effects shouldn't be extrapolated; estimate weather effects on emerging data or cap them.
- **Region (codes E01-E06) and make_model** can't transfer and must be estimated on emerging data.

## 4. New business: carry over the developed relativity

- After the developed model, emerging new-business and renewal rows have about the same A/E for motor (own damage 1.12 vs 1.12, bodily injury 1.31 vs 1.30). The developed model already has a new-business relativity of about 1.1-1.3.
- So the developed new-business effect explains the emerging new-business experience. Carry it over for the 2025 broker portfolio (76% new business).
- Home new-business claim counts are too thin to test (4-45 claims per peril), so the developed relativity is the best available.

## 5. Implications for the models

- **Transfer model:** developed shape (per-peril GLM / GBM on the shared features, without weather extrapolation), plus emerging level per peril for frequency and severity, plus emerging-estimated region, make_model and weather terms.
- **Emerging-only model:** a benchmark, credible only for motor (about 3.5k claims a year).
- **Large losses:** emerging tails are no heavier, so cap at the developed 99.5th percentile scaled by the severity ratio; with 50-80 claims a year for fire, flood and subsidence, the cap loading must come from developed data.
- **Uncertainty:** the levels for thin perils (fire 70 claims, subsidence 52, flood 80) have wide intervals (e.g. fire severity 0.32-0.85). Show these ranges in the report.
