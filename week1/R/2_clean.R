# 2_clean.R ------------------------------------------------------------------
# Step 4: sensibility checks, cleaning with documented assumptions, target construction.
# The SAME clean_policy() function is applied to train and test so both stay consistent.
# Section 6 plots every column after cleaning (raw vs cleaned, and every model feature 2021-24 vs 2025).
# Outputs: data/week_1/clean/{train,test}_<line>.parquet, data/week_1/clean/claims_matched.parquet,
#          week1/output/2_clean/ (cleaning_report.md, data_checks.csv, unmatched_claims.csv, ...)
#          week1/output/2_1_clean_eda/ (clean_eda_report.md with observations, one page and plot folder per page)

source("week1/R/0_setup.R")
STEP <- "2_clean"

customers <- read_raw("customers")
addresses <- read_raw("addresses")
weather <- read_raw("weather")
claims <- read_raw("claims")

checks <- list()
add_check <- function(dataset, check, n, action, expected = NA_real_) {
  checks[[length(checks) + 1]] <<- data.table(dataset = dataset, check = check, n = n,
                                              expected_from_handover = expected, action = action)
}

# 1. Reference tables -----------------------------------------------------------------
add_check("customers", "duplicate customer_id", sum(duplicated(customers$customer_id)), "none expected")
add_check("addresses", "duplicate address_id", sum(duplicated(addresses$address_id)), "none expected")
add_check("weather", "duplicate address_id x year", sum(duplicated(weather, by = c("address_id", "year"))), "none expected")
customers[, surname := NULL]  # anonymised name: not a rating factor
setnames(weather, "year", "policy_year")
# Address weather averaged over the training years: the stable part of the weather exposure
weather_avg <- weather[policy_year %in% TRAIN_YEARS, lapply(.SD, mean, na.rm = TRUE), by = address_id, .SDcols = WEATHER_VARS]
setnames(weather_avg, WEATHER_VARS, paste0("wx_avg_", WEATHER_VARS))

# 2. Policy cleaning (train and test) ----------------------------------------------------
clean_policy <- function(dt, line, dataset, expected = list()) {
  dt <- copy(dt)
  n0 <- nrow(dt)
  ex <- function(k) if (is.null(expected[[k]])) NA_real_ else expected[[k]]

  # Trap 1: customer_id lost leading zeros (motor)
  add_check(dataset, "customer_id shorter than 8 chars", sum(nchar(dt$customer_id) < 8, na.rm = TRUE),
            "left-padded with zeros to 8 chars", ex("short_id"))
  dt[, customer_id := pad_id(customer_id)]

  # Trap 2: exposure inconsistent with dates (days/360 or raw days)
  dt[, exposure_raw := exposure]
  dt[, exposure := as.numeric(period_end - period_start + 1) / DAYS_PER_YEAR]
  # raw exposure is stored rounded to 4 dp
  dt[, flag_exposure_fixed := abs(exposure_raw - round(exposure, 4)) > 1e-6 & abs(exposure_raw - exposure) > 1e-6]
  add_check(dataset, "exposure inconsistent with period dates", sum(dt$flag_exposure_fixed),
            "recomputed as (period_end - period_start + 1) / 365", ex("exposure"))
  add_check(dataset, "period_end before period_start", sum(dt$period_end < dt$period_start), "none expected")
  add_check(dataset, "recomputed exposure > 1.0027 (more than 366 days)", sum(dt$exposure > 366 / 365), "none expected")

  # Trap 3: sum_insured inflated 1000x (unit error assumption)
  if (line %in% c("buildings", "contents")) {
    si_cap <- c(buildings = 5e6, contents = 2e6)[[line]]
    dt[, flag_si_fixed := !is.na(sum_insured) & sum_insured > si_cap & sum_insured %% 1000 == 0]
    add_check(dataset, paste0("sum_insured > ", format(si_cap, big.mark = ","), " and divisible by 1000"),
              sum(dt$flag_si_fixed), "divided by 1000 (assumed unit error)", ex("si"))
    add_check(dataset, "sum_insured > cap but NOT divisible by 1000",
              sum(dt$sum_insured > si_cap & !dt$flag_si_fixed, na.rm = TRUE), "none expected; review if > 0")
    dt[flag_si_fixed == TRUE, sum_insured := sum_insured / 1000]
  }

  # Trap 4: construction_type casing and codes (T and W assumed to both mean timber)
  if (line == "buildings") {
    raw_ct <- dt$construction_type
    ct <- toupper(trimws(raw_ct))
    ct[ct %in% c("T", "W")] <- "TIMBER"
    dt[, construction_type := tolower(ct)]
    add_check(dataset, "construction_type not in canonical lower-case form",
              sum(raw_ct != dt$construction_type, na.rm = TRUE),
              "upper-cased, T/W -> timber, stored lower-case")
  }

  # Trap 8: years_licensed impossible for driver_age (licence assumed from age 16)
  if (line == "motor") {
    dt[, flag_licence_capped := !is.na(years_licensed) & !is.na(driver_age) &
         years_licensed > pmax(driver_age - 16L, 0L)]
    add_check(dataset, "years_licensed > driver_age - 16", sum(dt$flag_licence_capped),
              "capped at driver_age - 16")
    dt[flag_licence_capped == TRUE, years_licensed := pmax(driver_age - 16L, 0L)]
  }

  # Trap 7: renewal_decision describes the row's own outcome (leakage) - removed
  if ("renewal_decision" %in% names(dt)) dt[, renewal_decision := NULL]

  # Structure checks
  add_check(dataset, "duplicate row_id", sum(duplicated(dt$row_id)), "none expected")
  setorder(dt, policy_id, period_start)
  dt[, prev_end := shift(period_end), by = policy_id]
  add_check(dataset, "overlapping rows within a policy", sum(dt$period_start <= dt$prev_end, na.rm = TRUE),
            "none expected")
  dt[, prev_end := NULL]

  # Joins: customers, addresses, weather (calendar year of period_start)
  add_check(dataset, "customer_id not found in customers", sum(!dt$customer_id %in% customers$customer_id), "none expected after padding")
  add_check(dataset, "address_id not found in addresses", sum(!dt$address_id %in% addresses$address_id), "none expected")
  dt[, policy_year := year(period_start)]
  dt <- merge(dt, customers, by = "customer_id", all.x = TRUE, sort = FALSE)
  dt <- merge(dt, addresses, by = "address_id", all.x = TRUE, sort = FALSE)
  dt <- merge(dt, weather, by = c("address_id", "policy_year"), all.x = TRUE, sort = FALSE)
  add_check(dataset, "rows without weather after join", sum(is.na(dt$hail_days) & is.na(dt$rainfall_mm)), "none expected")
  if (nrow(dt) != n0) stop(dataset, ": row count changed during joins (", n0, " -> ", nrow(dt), ")")

  # Derived features
  dt[, customer_age := as.integer(floor(as.numeric(period_start - date_of_birth) / 365.25))]
  dt[, date_of_birth := NULL]
  dt[, start_month := month(period_start)]
  dt[, years_with_insurer := policy_year - customer_since_year]
  # Premium relative to its line and policy year, so annual rate changes do not read as risk
  dt[, premium_index := written_premium / weighted.mean(written_premium, exposure, na.rm = TRUE), by = policy_year]
  dt <- merge(dt, weather_avg, by = "address_id", all.x = TRUE, sort = FALSE)

  # Trap 8 (missing values): categorical NA -> explicit "missing" level; numeric NA left for the models
  chr_cols <- names(dt)[vapply(dt, is.character, logical(1))]
  chr_feats <- intersect(chr_cols, feature_cols(dt))
  for (cn in chr_feats) set(dt, which(is.na(dt[[cn]])), cn, "missing")

  setcolorder(dt, c("row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end",
                    "policy_year", "exposure"))
  setorder(dt, row_id)
  dt
}

expected <- list(
  policies_motor = list(short_id = 98110, exposure = 4719 + 934),
  policies_buildings = list(exposure = 3472 + 656, si = 1395),
  policies_contents = list(exposure = 3524 + 729, si = 1402),
  test_motor = list(short_id = 25554, exposure = 0),
  test_buildings = list(exposure = 0, si = 370),
  test_contents = list(exposure = 0, si = 360)
)

# 3. Claims checks and claim-level net cost ---------------------------------------------------
add_check("claims", "duplicate claim_id", sum(duplicated(claims$claim_id)), "none expected")
claims[, n_same := .N, by = .(policy_id, line, peril, loss_date, report_date, status, incurred_to_date)]
claims[, flag_duplicate := !grepl("^CL[0-9]{8}$", claim_id) & n_same > 1]
add_check("claims", "9-digit claim_id that duplicates another claim (trap 10)", sum(claims$flag_duplicate),
          "dropped (assumed duplicate booking)")
add_check("claims", "9-digit claim_id with no duplicate", sum(!grepl("^CL[0-9]{8}$", claims$claim_id) & claims$n_same == 1),
          "kept; review if > 0")
add_check("claims", "paid > incurred", claims[paid_to_date > incurred_to_date + 1e-6, .N], "none expected")
add_check("claims", "recoveries > incurred", claims[recoveries > incurred_to_date + 1e-6, .N], "none expected")
add_check("claims", "report_date before loss_date", claims[report_date < loss_date, .N], "none expected")
add_check("claims", "repudiated with incurred > 0", claims[status == "repudiated" & incurred_to_date > 0, .N], "none expected")
claims[, n_same := NULL]
dup_claims <- claims[flag_duplicate == TRUE]
claims <- claims[flag_duplicate == FALSE][, flag_duplicate := NULL]

claims[, counts := status != "repudiated"]
claims[, net_cost := fifelse(counts, incurred_to_date - recoveries, 0)]
add_check("claims", "negative net cost", claims[net_cost < 0, .N], "none expected")

# 4. Build each line: clean, match claims to rows, aggregate row targets ------------------------
matched_all <- list()
summary_rows <- list()
for (ln in LINES) {
  log_msg("Cleaning ", ln)
  tr <- clean_policy(read_raw(paste0("policies_", ln)), ln, paste0("policies_", ln), expected[[paste0("policies_", ln)]])
  te <- clean_policy(read_raw(paste0("test_", ln)), ln, paste0("test_", ln), expected[[paste0("test_", ln)]])

  # Match claims to the policy row covering the loss date
  cl <- claims[line == ln]
  m <- tr[cl, on = .(policy_id, period_start <= loss_date, period_end >= loss_date),
          .(claim_id = i.claim_id, row_id = x.row_id), allow.cartesian = TRUE]
  add_check(paste0("claims_", ln), "claims matching more than one policy row",
            m[!is.na(row_id), .N, by = claim_id][N > 1, .N], "none expected")
  cl <- merge(cl, unique(m, by = "claim_id"), by = "claim_id", all.x = TRUE)
  add_check(paste0("claims_", ln), "claims matching no policy row (trap 5)", sum(is.na(cl$row_id)),
            "excluded from row targets; listed in unmatched_claims.csv",
            c(motor = 297, buildings = 67, contents = 50)[[ln]])
  matched_all[[ln]] <- cl

  # Row-level targets (y_ prefix): totals, open claims, and per-peril cost and count
  mc <- cl[!is.na(row_id)]
  agg <- mc[, .(y_n_claims = sum(counts), y_cost = sum(net_cost), y_n_open = sum(status == "open"),
                y_max_claim = max(net_cost)), by = row_id]
  for (pr in PERILS[[ln]]) {
    pa <- mc[counts == TRUE & peril == pr, .(cost = sum(net_cost), n = .N), by = row_id]
    setnames(pa, c("cost", "n"), paste0(c("y_cost_", "y_n_"), pr))
    agg <- merge(agg, pa, by = "row_id", all.x = TRUE)
  }
  tr <- merge(tr, agg, by = "row_id", all.x = TRUE, sort = FALSE)
  ycols <- grep("^y_", names(tr), value = TRUE)
  for (cn in ycols) set(tr, which(is.na(tr[[cn]])), cn, 0)
  add_check(paste0("policies_", ln), "negative row target", sum(tr$y_cost < 0), "none expected")

  # Categorical levels in test never seen in train
  for (cn in intersect(feature_cols(te), names(te))) {
    if (is.character(te[[cn]])) {
      unseen <- setdiff(unique(te[[cn]]), unique(tr[[cn]]))
      if (length(unseen) > 0) add_check(paste0("test_", ln), paste0("levels unseen in train: ", cn),
                                        sum(te[[cn]] %in% unseen), paste(head(unseen, 5), collapse = ", "))
    }
  }

  summary_rows[[ln]] <- tr[, .(rows = .N, exposure = sum(exposure), claims = sum(y_n_claims), cost = sum(y_cost)),
                           by = policy_year][, `:=`(line = ln, frequency = claims / exposure,
                                                    severity = cost / claims, burn_cost = cost / exposure)]
  write_clean(tr, paste0("train_", ln))
  write_clean(te, paste0("test_", ln))
  log_msg(ln, ": train ", nrow(tr), " rows, test ", nrow(te), " rows written")
  rm(tr, te, m, mc, agg); gc(verbose = FALSE)
}

claims_matched <- rbindlist(matched_all, use.names = TRUE)
write_clean(claims_matched, "claims_matched")

# 5. Reports ------------------------------------------------------------------------------------
checks_dt <- rbindlist(checks)
checks_dt[, matches_handover := fifelse(is.na(expected_from_handover), NA, n == expected_from_handover)]
save_csv(checks_dt, STEP, "data_checks.csv")
unmatched <- claims_matched[is.na(row_id), .(claim_id, policy_id, line, peril, loss_date, status, net_cost)]
save_csv(unmatched, STEP, "unmatched_claims.csv")
save_csv(dup_claims, STEP, "duplicate_claims_removed.csv")
experience <- rbindlist(summary_rows)[order(line, policy_year)]
setcolorder(experience, c("line", "policy_year"))
save_csv(experience, STEP, "experience_by_year.csv")

assumptions <- c(
  "1. customer_id left-padded with zeros to 8 characters (all lines; only motor affected).",
  "2. exposure recomputed as (period_end - period_start + 1) / 365 for every row; the raw value is kept as `exposure_raw`.",
  "3. sum_insured above 5m (buildings) / 2m (contents) and divisible by 1000 is divided by 1000 (assumed unit error).",
  "4. construction_type normalised to brick / stone / timber / non_standard; T and W both mapped to timber (inference).",
  "5. Claims whose loss date falls in no policy row are excluded from targets (see unmatched_claims.csv).",
  "6. Claims are NOT capped here; large-loss treatment is a modelling decision (steps 5 and 6).",
  "7. renewal_decision is dropped (describes the row's own outcome - leakage).",
  "8. years_licensed capped at driver_age - 16; categorical missing values set to the level 'missing'; numeric NAs kept.",
  "9. surname and date_of_birth dropped; customer_age derived at period_start.",
  "10. Claims with a 9-digit claim_id that duplicate another claim (same policy, peril, dates, status, incurred) are dropped.",
  "Target: y_cost = sum over the row's claims of (incurred_to_date - recoveries); repudiated claims count 0 and are not counted in y_n_claims."
)

write_md(list(
  "# Step 4 - Data checks and cleaning", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/2_clean.R`."), "",
  "## Cleaning assumptions", assumptions, "",
  "## Checks", "`matches_handover` compares the count with the figure quoted in the handover (blank = no figure quoted).", "",
  md_table(checks_dt[, .(dataset, check, n, expected_from_handover, matches_handover, action)]),
  "## Experience after cleaning (as reported at 31 Dec 2024, uncapped)",
  md_table(experience[, .(line, policy_year, rows, exposure, claims, frequency, severity, burn_cost)]),
  "## Outputs",
  "- `data/week_1/clean/train_<line>.parquet` - cleaned rows + customers + addresses + weather + `y_*` targets",
  "- `data/week_1/clean/test_<line>.parquet` - cleaned test rows with the same features",
  "- `data/week_1/clean/claims_matched.parquet` - claims with `row_id` (NA = unmatched) and `net_cost`"
), STEP, "cleaning_report.md")

log_msg("Cleaning done. Report: ", out_file(STEP, "cleaning_report.md"))

# 6. Column plots after cleaning -------------------------------------------------------------------
#   A. Before vs after: each column the cleaning transforms, raw policies vs cleaned train rows (same rows),
#      with the number of rows the cleaning changed.
#   B. Model features: every column the models can use (feature_cols()), train 2021-24 vs test 2025, grouped by
#      the table it comes from (policy, customer, address, weather, derived).
# Outputs: week1/output/2_1_clean_eda/ (clean_eda_report.md, column_summary.csv, cleaning_changes.csv, pages.csv,
#          one <page>.md and one <page>/ plot folder per page). week1/R/5_build_site.R adds the pages to the website.
source("week1/R/eda_helpers.R")
STEP <- "2_1_clean_eda"
OVERVIEW <- "clean_eda_report.md"
BEFORE_AFTER <- list(
  motor     = c("exposure", "years_licensed"),
  buildings = c("exposure", "sum_insured", "construction_type"),
  contents  = c("exposure", "sum_insured")
)
CHANGE_NOTES <- c(
  exposure = "recomputed as (period_end - period_start + 1) / 365",
  years_licensed = "capped at driver_age - 16",
  sum_insured = "values above 5m (buildings) / 2m (contents) and divisible by 1000 divided by 1000",
  construction_type = "trimmed, case-normalised, T and W mapped to timber"
)
SOURCE_LABELS <- c(policy = "Policy (line-specific columns)", customer = "Customer", address = "Address",
                   weather = "Weather (address x year)", derived = "Derived in week1/R/2_clean.R")
LINE_LABELS <- c(motor = "Motor", buildings = "Buildings", contents = "Contents")

# Rows whose value the cleaning changed (raw rounded to 4 decimals is not a change), matched on row_id
rows_changed <- function(raw, clean, v) {
  x <- raw[[v]]
  y <- clean[[v]][match(raw$row_id, clean$row_id)]
  differs <- if (is.numeric(x)) abs(x - y) > 1e-4 * pmax(1, abs(y)) else x != y
  sum(xor(is.na(x), is.na(y)) | (!is.na(x) & !is.na(y) & differs))
}

shared <- list(customer = names(customers), address = names(addresses), weather = names(weather))
unlink(file.path(PATHS$output, STEP), recursive = TRUE)
summaries <- list(); before_after <- list(); changes <- list(); obs <- list()
n_ba <- 0L

for (ln in LINES) {
  raw <- read_raw(paste0("policies_", ln))
  tr <- read_clean(paste0("train_", ln))
  te <- read_clean(paste0("test_", ln))

  cols <- BEFORE_AFTER[[ln]]
  before_after[[ln]] <- eda_columns("before_after", raw, tr, c("raw", "cleaned"), cols, src = rep(ln, length(cols)),
                                    comparison = "cleaning", start = n_ba + 1L)
  n_ba <- n_ba + length(cols)
  changes[[ln]] <- data.table(line = ln, column = cols, rows = nrow(raw),
                              rows_changed = vapply(cols, function(v) rows_changed(raw, tr, v), numeric(1)),
                              change = CHANGE_NOTES[cols])

  feats <- intersect(feature_cols(te, include_new = TRUE), names(tr))
  src <- fifelse(feats %in% names(raw), "policy", fifelse(feats %in% shared$customer, "customer",
           fifelse(feats %in% shared$address, "address", fifelse(feats %in% shared$weather, "weather", "derived"))))
  ord <- order(match(src, names(SOURCE_LABELS)), feats)
  page <- paste0("clean_", ln)
  sets <- c("train 2021-24", "test 2025")
  st <- eda_columns(page, tr, te, sets, feats[ord], src[ord])
  summaries[[page]] <- write_eda_page(page, paste0("Model features: ", ln, " (cleaned)"),
                                      paste(two_set_intro(sets[1], sets[2]),
                                            "These are exactly the columns the models can use (`feature_cols()` in `week1/R/0_setup.R`)."),
                                      st, OVERVIEW, SOURCE_LABELS)

  # Inputs for the observations: feature trends by policy year, with the 2025 test rows as the last year
  by_year <- rbind(tr[, .(premium = sum(written_premium * exposure) / sum(exposure),
                          campaign_missing = mean(campaign_code == "missing")), keyby = policy_year],
                   te[, .(policy_year = 2025L, premium = sum(written_premium * exposure) / sum(exposure),
                          campaign_missing = mean(campaign_code == "missing"))])
  obs[[ln]] <- list(by_year = by_year,
                    tenure_same = mean(tr$years_with_insurer == tr$renewal_count, na.rm = TRUE),
                    since_2025 = mean(te$customer_since_year == 2025, na.rm = TRUE))
  if (ln == "buildings") {
    obs$timber <- tr[construction_type == "timber", .(freq = sum(y_n_claims) / sum(exposure)), keyby = policy_year]
  }
  rm(raw, tr, te); gc(verbose = FALSE)
}

changes <- rbindlist(changes)[, pct_rows_changed := 100 * rows_changed / rows]
save_csv(changes, STEP, "cleaning_changes.csv")
ba <- rbindlist(before_after)
ba_intro <- c(
  "Blue = raw policies 2021-24 as supplied, orange = the same rows after `week1/R/2_clean.R` (test rows are cleaned the",
  "same way). Here PSI measures how much the cleaning moved the distribution, not drift.", "",
  md_table(changes[, .(line, column, change, rows_changed, pct_rows_changed)], 2),
  "For `construction_type`, most changed rows are only `Brick` written as `brick`; the recoding itself is T/W -> timber.")
summaries <- c(list(before_after = write_eda_page("before_after", "Cleaning: before vs after", ba_intro, ba,
                                                  OVERVIEW, LINE_LABELS)),
               summaries)

col_summary <- rbindlist(summaries, fill = TRUE)
pages <- names(summaries)
write_page_index(col_summary, pages)
feature_pages <- setdiff(pages, "before_after")

yr_txt <- function(dt, v, fmt) paste(sprintf(paste0("%d ", fmt), dt$policy_year, dt[[v]]), collapse = ", ")
bm <- obs$buildings$by_year
observations <- c(
  "## Observations and recommended changes", "",
  "| # | Observation | Recommendation |", "|---|---|---|",
  sprintf("| 1 | `years_with_insurer` equals `renewal_count` on %.1f%% of rows | Duplicate feature: drop `years_with_insurer` |",
          100 * obs$buildings$tenure_same),
  sprintf("| 2 | `customer_since_year` is a calendar year: %.1f%% of 2025 rows have 2025, a value never seen in training (PSI %.2f) | Tenure is already in `renewal_count`; drop `customer_since_year` so the models do not extrapolate a calendar trend |",
          100 * obs$buildings$since_2025, col_summary[page == "clean_buildings" & column == "customer_since_year", psi]),
  sprintf("| 3 | `campaign_code` missing share falls every year (buildings: %s) | It tracks calendar time and marketing activity, not risk: drop it |",
          yr_txt(bm, "campaign_missing", "%.2f")),
  sprintf("| 4 | `written_premium` rises about 5%% a year from rate changes (buildings mean: %s) | As a raw feature it mixes rate level with risk; use the premium relative to its line and year mean (`premium_index`) |",
          yr_txt(bm, "premium", "%.0f")),
  sprintf("| 5 | Timber claim frequency is flat across the T (2021-22) to W (2023-24) coding switch: %s | Confirms the T/W -> timber mapping |",
          yr_txt(obs$timber, "freq", "%.4f")),
  "| 6 | Weather features drift (PSI 0.25-0.46) although their means barely move; the year-to-year spread changes | Compare yearly weather with each address's 2021-24 average in the models |",
  "| 7 | `compulsory_excess` has one value in every line | Drop |",
  "| 8 | The `sum_insured` and exposure fixes move only 0.2-0.6% of rows; the `years_licensed` cap 0.3% | Cleaning is targeted; no further change needed |",
  ""
)

write_md(list(
  "# Column plots after cleaning", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/2_clean.R` (section 6), using `data/week_1/clean/`."), "",
  "One plot per column showing the distribution of its values as a share of rows. The before vs after page puts",
  "each transformed column's raw and cleaned values side by side; the model-feature pages compare the training",
  "years (blue, 2021-24) with the year we predict (orange, 2025). Raw-data plots are in `week1/R/1_eda.R` (section 9).", "",
  method_lines(),
  observations,
  "## Pages", "", page_links(col_summary, pages),
  "## What the cleaning changed", "",
  md_table(changes[, .(line, column, change, rows_changed, pct_rows_changed)], 2),
  "## Flagged model features", "", flag_table(col_summary, feature_pages),
  "## Largest drift 2021-24 vs 2025 - model features (top 10 per line)", "",
  md_table(col_summary[page %in% feature_pages][order(-psi), head(.SD, 10), by = page][
    , .(page, column, source, kind, psi, mean_first, mean_second)], 3),
  "Full table with every statistic: `column_summary.csv`."
), STEP, OVERVIEW)

log_msg("Done. Reports: ", out_file("2_clean", "cleaning_report.md"), ", ", out_file(STEP, OVERVIEW))
