# IAA Hackathon 2026 – Project Handover

Oct 20, 2026 · @Wendy Low

Predict the 2025 expected ultimate claim cost for every motor, buildings and contents policy row; this page holds the task rules, data specification, known data traps and starting points so you can begin modelling without redoing the ingestion.

## Task and submission rules

For each row\_id in test\_motor, test\_buildings and test\_contents, predict the expected ultimate claim cost of that row in fictitious currency units (CU).

- **Target:** final cost of all claims with a loss date inside the row's period, net of policy excess and net of recoveries, excluding declined (repudiated) claims. It is the risk premium, not the premium charged.
- **Output:** ONE CSV covering all three test files, header `row_id,prediction` (e.g. `M02409311,583.47`). Predictions must be zero or above.
- **Size:** 626,639 rows (motor 254,986; buildings 184,155; contents 187,498). `sample_submission` has the exact row\_ids with prediction 0.0.
- **Data:** policy years 2021–2024 for training; the prediction year is 2025.
- **Brief:** you are on the pricing team of an established insurer in a developed market, reviewing technical pricing across private motor, home buildings and home contents. Models should be technically sound, adaptable, explainable and practical.
- **Hackathon aim:** accurate pricing assumptions with effective use of AI, trust, validation and guardrails, plus precise documentation of the methodology and results.

## Files and how tables link

All files are Parquet (zip: `iaa-ai-assisted-hackathon-2026-part-1.zip`, files under `public/`). Read every identifier as text.

| File | One row per | Rows | Notes |
| --- | --- | --- | --- |
| customers | Customer | 545,240 | Shared across all of a customer's policies |
| addresses | Address | 575,983 | Location and property traits |
| weather | Address × year | 2,879,915 | 2021–2025 for every address (2025 exists for test) |
| policies\_motor | Policy period | 979,968 | 308,109 policies, 2021–2024 |
| policies\_buildings | Policy period | 707,726 | 230,921 policies |
| policies\_contents | Policy period | 721,617 | 231,255 policies |
| claims | Claim | 163,150 | 125,103 policies; valued 31 Dec 2024 |
| test\_motor | Policy period | 254,986 | 236,008 policies, 2025 |
| test\_buildings | Policy period | 184,155 | 176,946 policies |
| test\_contents | Policy period | 187,498 | 176,957 policies |
| sample\_submission | Test row | 626,639 | row\_id, prediction (all 0.0) |

**Keys**

- `customer_id` links policies to customers; `address_id` links policies to addresses and weather (join weather on address\_id and the calendar year of period\_start); `policy_id` links claims to policies; `row_id` identifies test rows.
- `policy_id` stays constant across years, so match a claim to a policy row with `policy_id` + `line` and `period_start <= loss_date <= period_end`.
- A policy has more than one row in a year when it changed mid-term (new vehicle, address change); rows end early on cancellation or lapse. Rows of one policy are contiguous (no gaps or overlaps).
- `policy_id` and `customer_id` are 1:1 within a line. A customer can hold all three lines; several customers can share an address (20,044 addresses are shared).
- ID formats: policy\_id M/B/C + 8 digits; claim\_id CL + 8 digits; address\_id A + 7 digits; customer\_id 8-digit text.

## Column dictionary

| Table | Columns and meaning |
| --- | --- |
| All policy and test files | row\_id; policy\_id; customer\_id; address\_id (insured address; motor = home address); period\_start, period\_end (first and last day covered); exposure (years); voluntary\_excess (0, 250, 500, 1,000 CU, customer's choice); compulsory\_excess (insurer-set); channel (direct, comparison\_site, broker); payment\_method (annual, monthly); missed\_payments\_12m; new\_business (first policy year); renewal\_count (previous renewals); days\_quote\_to\_inception; discount\_applied; written\_premium (premium under current pricing); customer\_service\_contacts. **renewal\_decision exists in training only** (renewed, lapsed\_by\_customer, cancelled, declined\_by\_insurer, mid\_term\_change). |
| Motor | driver\_age (main driver, at row start); years\_licensed; ncb\_years; vehicle\_value\_group (1 lowest to 20); vehicle\_age; make\_model (code, 300 values); engine\_size\_cc; body\_type (hatchback, saloon, estate, suv, coupe); transmission; seats; vehicle\_colour; fuel\_type (petrol, diesel, hybrid, electric); driver\_assist (e.g. auto braking); cover\_type (comprehensive, third\_party\_fire\_theft, third\_party\_only); annual\_mileage (declared); overnight\_parking (garage, driveway, street); vehicle\_use (social, commuting, business); named\_young\_driver (under-25 named); telematics\_opt\_in; telematics\_score (1–100, blank if not opted in). |
| Buildings | policyholder\_age; sum\_insured; construction\_type (brick, stone, timber, non-standard); occupancy (owner\_occupied, let); days\_unoccupied (longest period); smoke\_alarms; accidental\_damage\_cover (optional); mortgage. |
| Contents | policyholder\_age; sum\_insured; tenure (owner, renter); security\_level (standard, locks, alarm\_and\_locks); high\_value\_items (number declared); accidental\_damage\_cover; works\_from\_home; lodgers; bicycle\_cover (optional). |
| customers | surname (anonymised); date\_of\_birth; occupation; marital\_status; household\_size; credit\_band (A best to E); prior\_claims\_5y (declared, five years before joining); licence\_points; years\_at\_address; customer\_since\_year; email\_domain; marketing\_consent; document\_preference (email, post, app); previous\_insurer; campaign\_code (if any); branch\_id; marketing\_segment (assigned by marketing). |
| addresses | region (R01–R12); urban\_density (rural, suburban, urban, dense\_urban); flood\_zone (1 lowest to 5); distance\_to\_river\_km; elevation\_m (above local river level); soil\_type (clay, sand, loam, chalk, rock); year\_built; property\_type (detached, semi\_detached, terraced, flat); roof\_type (pitched, flat); basement; trees\_within\_5m; listed\_building; bedrooms; energy\_rating (A best to G); solar\_panels. |
| weather (address × year) | hail\_days; wind\_exposure\_index (0–10); freezing\_days; dry\_summer\_index (0 wet to 1 very dry); wildfire\_index (0–1); rainfall\_mm; mean\_temperature\_c. |
| claims | claim\_id; policy\_id; line (motor, buildings, contents); peril; loss\_date; report\_date; status (closed, open, repudiated = declined); paid\_to\_date (net of excess); incurred\_to\_date (paid + case estimate on open claims); recoveries (third parties or salvage); repairer\_id (motor damage); third\_party\_id (motor third-party). |

**Perils.** Motor: own\_damage, third\_party\_prop, bodily\_injury, theft, glass\_hail. Buildings: storm, flood, escape\_of\_water, subsidence, fire, accidental\_damage. Contents: theft, escape\_of\_water, accidental\_damage, flood.

**Valuation.** Claims are valued at 31 Dec 2024; some 2024 claims were not yet reported and open claims may still develop.

## Data-quality traps and fixes

Found while ingesting the data (Python/polars). Treat the fixes as recommended, not yet validated by modelling.

| # | Issue | Evidence | Recommended fix |
| --- | --- | --- | --- |
| 1 | Motor customer\_id lost leading zeros | 98,110 train rows (30,822 customers) and 25,554 test rows fail to join to customers; customers.customer\_id is always 8 chars | Left-pad to 8 with zeros (polars `str.zfill(8)`; R `stringr::str_pad(x, 8, pad = "0")`, not tested). Gives 100% match in all six policy/test files. Buildings and contents are fine |
| 2 | Wrong exposure on some training rows | Motor: 4,719 rows = days/360 (365 days shows 1.0139) and 934 rows = raw days (365, 327); buildings 3,472 + 656; contents 3,524 + 729. Test is clean | Recompute exposure = (period\_end − period\_start + 1) / 365. Year convention is 365 days (2024 full-year rows end 30 Dec) |
| 3 | sum\_insured inflated 1000× on about 0.2% of rows | Train buildings 1,395 rows (min 52,000,000 vs normal max 953,000), contents 1,402 (min 8.2m vs normal max 347k); test buildings 370, contents 360. All divisible by 1000; dividing lands in the normal range | Divide by 1000 after checking against bedrooms or premium. Likely unit error, not confirmed |
| 4 | Messy buildings construction\_type | Casing variants (Brick/brick/BRICK, stone/STONE, non\_standard/NON\_STANDARD); T/t only in 2021–22, W/w only in 2023–24 and test; timber claim frequency stable at about 0.045 | Normalise to BRICK, STONE, NON\_STANDARD, TIMBER (T and W both timber – an inference) |
| 5 | 414 claims fit no policy row by loss date | 274 are Dec 2020 losses (252 on exactly 2020-12-01); 140 fall in 2021–23 outside their policy's rows (motor 297, buildings 67, contents 50) | Drop from row targets; investigate the 2020-12-01 spike |
| 6 | One extreme open claim | Motor bodily\_injury, open, incurred 11,894,277, paid 738,769 (loss 2023-06-25); next largest 1,118,868 | Large-loss capping or separate treatment |
| 7 | renewal\_decision leakage | Training only; describes the row's own outcome; 2021 has no cancelled/lapsed rows | Do not use as a feature |
| 8 | Minor inconsistencies | years\_licensed > driver\_age − 16 on about 0.3% of a motor sample; about 2.5% missing on many address, customer and policy fields | Cap or flag; impute with an explicit missing level |
| 9 | Possible noise or sensitive-proxy fields | email\_domain (about 20% each), vehicle\_colour (about 12.5% each), 600 surnames, document\_preference, marketing\_consent look uniform | Untested – check in modelling and document under guardrails |

## Target construction

Build the row-level training target as the sum of net claim cost over claims that fall inside each row.

1. Join claims to policy rows on `policy_id` + `line` with `period_start <= loss_date <= period_end`. 162,736 claims match exactly one row; 414 match none (see trap 5).
2. Claim net cost = `incurred_to_date − recoveries` for open and closed claims; repudiated claims count 0 (their paid and incurred are already 0).
3. Row target = sum of claim net cost in the row (0 if none). Use recomputed exposure (trap 2).

Checks that held: no claim has paid above incurred or recoveries above incurred, and no row target is negative. `paid_to_date` is already net of excess. Recoveries occur only on closed motor own\_damage (28.6% of those claims) and theft (12.0%).

**Immaturity.** The share of claims still open is 0.9% for 2021 losses, 1.5% for 2022, 3.2% for 2023 and 20.2% for 2024. Reported 2024 claims drop in Nov (3,024) and Dec (2,293) against about 3,300 a month. Report lag (days): median 9 motor, 9 buildings, 6 contents; p99 377, 239 and 63. So 2024 cost per exposure is understated (late-reported claims and open case estimates); the 2025 target is *ultimate*, so consider development or IBNR allowances.

## Experience and test-set profile

Non-repudiated claims, net of recoveries, valued 31 Dec 2024, recomputed exposure. Cost per exposure-year is for 2021 / 2022 / 2023 / 2024.

| Line | Claim frequency per exposure-year | Mean severity (CU) | Cost per exposure-year (CU) | Rows with a claim |
| --- | --- | --- | --- | --- |
| Motor | 0.146 / 0.149 / 0.140 / 0.129 | 3,871 / 3,931 / 4,191 / 3,506 | 563 / 584 / 587 / 454 | 11.1% to 9.1% |
| Buildings | 0.044 / 0.045 / 0.046 / 0.044 | 8,725 / 9,059 / 9,510 / 10,250 | 384 / 411 / 432 / 449 | 3.8% to 3.4% |
| Contents | 0.040 / 0.040 / 0.041 / 0.040 | 2,663 / 2,663 / 2,848 / 2,925 | 106 / 107 / 117 / 117 | 3.4% to 3.1% |

**Row cost when above zero (CU)**

| Line | Median | p90 | p99 | p99.9 | Max |
| --- | --- | --- | --- | --- | --- |
| Motor | 1,779 | 9,375 | 39,518 | 124,536 | 11,894,277 |
| Buildings | 3,250 | 22,005 | 102,929 | 285,246 | 631,246 |
| Contents | 1,238 | 7,146 | 23,104 | 45,465 | 111,900 |

**Mean claim severity by peril (CU):** buildings fire 51,685, flood 31,359, subsidence 23,786, escape\_of\_water 5,733, storm 3,454, accidental\_damage 1,218; contents flood 9,992, theft 3,648, escape\_of\_water 2,740, accidental\_damage 782; motor bodily\_injury 21,582, theft 6,302, third\_party\_prop 3,681, own\_damage 1,856, glass\_hail 1,086.

**Mean written\_premium, train / test (CU):** motor 561 / 601; buildings 323 / 367; contents 136 / 154. It does not shrink on short-exposure rows, so it looks like an annualised rate (not confirmed).

**Test set (2025)**

- Period starts run 2025-01-01 to 2025-12-30; exposure is correct. Total exposure: motor 199,984; buildings 150,244; contents 150,124. No claims and no renewal\_decision in test.
- Composition: all policies renewed at end-2024, 1,513 of 1,653 motor policies the insurer declined in 2024, and new business (motor 38,878 rows, buildings 27,891, contents 28,428). Lapsed and cancelled policies are absent.
- Extra rows per policy from 2025 mid-term changes: motor 18,978, buildings 7,209, contents 10,541.
- Drift versus train: motor ncb\_years mean 7.94 vs 7.24, vehicle\_age 9.28 vs 7.80, renewal\_count 5.87 vs 6.58. Test construction\_type uses W/w only and still has the sum\_insured outliers.

## Current modelling status

SAM 3 is the current submission candidate. It uses per-peril frequency x severity models with report-share-adjusted exposure for frequency, observed capped claim severity, claim-history features, trend terms and a calibrated LightGBM/XGBoost blend. The full run completed on 2026-10-22 with local combined D² of 0.1043 for 2023 and 0.0986 for 2024; model replication passed. See `models/sam_iteration_03/model_card.md` and `output/submission/submission_20261022_1159.csv`.

## Suggested approach and open questions

The following are remaining considerations rather than prerequisites for the current submission.

1. Apply fixes 1–4 in one shared cleaning script used on both train and test, so the two stay consistent.
2. Validate on time: train on 2021–23 and score 2024, remembering 2024 is immature; also compare to a 2021–22 fit against 2023.
3. Model each line separately, for example frequency and severity by peril (very different severity profiles), with exposure as an offset, then combine to a row-level expected cost. Treat bodily\_injury, fire, flood and subsidence as large-loss perils.
4. Check calibration by line and in total against the burn costs above, and document guardrails: monotonic or sensible effects, handling of sensitive or proxy fields, large-loss capping.
5. Clip predictions at zero and confirm the CSV has all 626,639 row\_ids.

**Open questions**

- [x] Is sum\_insured really inflated by 1000 on the outlier rows (and is the test treated the same way)? SAM 2/SAM 3 raw-data rebuilds apply the documented /1000 correction to the flagged training and test rows; checks are recorded in `models/sam_iteration_02/data_checks.csv`.
- [x] Are T and W both timber in construction\_type? Confirmed and normalised to timber in the shared modelling rebuild; see `docs/workflow.md`.
- [x] What development or IBNR allowance should apply to 2024 when targeting ultimate cost? SAM 3 uses per-peril report-lag factors as a frequency offset; open-claim case development remains outside the model.
- [ ] What is the submission deadline? The evaluation metric is now documented as Tweedie D² (p = 1.5); the deadline is still not recorded.
- [ ] Is written\_premium an annual rate or a row total?

## Environment notes and glossary

- The ingestion ran in Python 3 with polars and pyarrow (installed with pip). The cloud container had no R, so rerun the checks in R if you prefer it; the R fixes quoted above are untested.
- The extracted files were a temporary copy; re-extract the zip to work with them.
- Figures come from one profiling pass on 2026-10-20 – re-verify before quoting them in the methodology write-up.

| Term | Meaning |
| --- | --- |
| CU | Currency unit (fictional) |
| Exposure | Time on cover in years |
| Excess | Part of each claim the policyholder pays |
| NCB | No-claims bonus |
| Sum insured | Maximum the policy pays |
| Incurred | Paid plus outstanding case estimate |
| Ultimate | Final cost once all claims are reported and settled |
| Repudiated | Claim the insurer declined to pay |
| Comparison site | Price-comparison website |
| Telematics | Device recording driving behaviour |
