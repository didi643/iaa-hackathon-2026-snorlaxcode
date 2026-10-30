# 1_eda.R --------------------------------------------------------------------
# Step 3: quick exploratory data analysis of the RAW files (no cleaning applied), then (section 9) the
# column EDA with one plot per column.
# Outputs: week1/output/1_eda/  (eda_report.md, column_profiles.csv, *.csv checks, plots/)
#          week1/output/1_1_eda/ (column_eda_report.md with observations, one page and plot folder per table)

source("week1/R/0_setup.R")
STEP <- "1_eda"

tables <- c("customers", "addresses", "weather", "policies_motor", "policies_buildings",
            "policies_contents", "claims", "test_motor", "test_buildings", "test_contents",
            "sample_submission")
raw <- setNames(lapply(tables, read_raw), tables)
log_msg("Loaded ", length(raw), " raw tables")

# 1. Pre-EDA data dictionary and raw samples -------------------------------------------
column_descriptions <- c(
  row_id = "Unique identifier for a policy-period row in the submission.",
  policy_id = "Policy identifier; remains constant across policy years.",
  customer_id = "Customer identifier shared across the customer's policies.",
  address_id = "Insured address identifier; motor uses the customer's home address.",
  period_start = "First date covered by the policy row.",
  period_end = "Last date covered by the policy row.",
  exposure = "Time on cover in years as supplied in the raw file.",
  voluntary_excess = "Customer-selected excess in currency units.",
  compulsory_excess = "Insurer-set excess in currency units.",
  channel = "Distribution channel: direct, comparison site or broker.",
  payment_method = "Payment frequency: annual or monthly.",
  missed_payments_12m = "Number of missed payments in the previous 12 months.",
  new_business = "Whether this is the customer's first policy year.",
  renewal_count = "Number of previous renewals.",
  days_quote_to_inception = "Days between quotation and policy inception.",
  discount_applied = "Discount applied to the policy price.",
  written_premium = "Premium charged under the current pricing, in currency units.",
  customer_service_contacts = "Number of customer-service contacts; potentially target leakage.",
  renewal_decision = "Training-only outcome for the row: renewed, lapsed, cancelled, declined or changed.",
  driver_age = "Main driver's age at the start of the row.",
  years_licensed = "Number of years the main driver has held a licence.",
  ncb_years = "Years of no-claims bonus.",
  vehicle_value_group = "Vehicle value band from 1 (lowest) to 20.",
  vehicle_age = "Age of the insured vehicle.",
  make_model = "Anonymised vehicle make/model code.",
  engine_size_cc = "Vehicle engine size in cubic centimetres.",
  body_type = "Vehicle body type.",
  transmission = "Vehicle transmission type.",
  seats = "Number of vehicle seats.",
  vehicle_colour = "Vehicle colour.",
  fuel_type = "Vehicle fuel type.",
  driver_assist = "Whether the vehicle has driver-assistance technology.",
  cover_type = "Motor cover type.",
  annual_mileage = "Declared annual mileage.",
  overnight_parking = "Where the vehicle is parked overnight.",
  vehicle_use = "Main vehicle use: social, commuting or business.",
  named_young_driver = "Whether an under-25 named driver is covered.",
  telematics_opt_in = "Whether the customer opted into telematics.",
  telematics_score = "Telematics driving score; blank when not opted in.",
  policyholder_age = "Age of the buildings or contents policyholder.",
  sum_insured = "Maximum insured value in currency units.",
  construction_type = "Buildings construction type.",
  occupancy = "Buildings occupancy type.",
  days_unoccupied = "Longest period the building is unoccupied.",
  smoke_alarms = "Whether smoke alarms are present.",
  accidental_damage_cover = "Whether optional accidental-damage cover is included.",
  mortgage = "Whether the building is mortgaged.",
  tenure = "Contents policyholder tenure: owner or renter.",
  security_level = "Contents security level.",
  high_value_items = "Number of declared high-value items.",
  works_from_home = "Whether someone works from home.",
  lodgers = "Whether lodgers live at the address.",
  bicycle_cover = "Whether optional bicycle cover is included.",
  surname = "Anonymised customer surname.",
  date_of_birth = "Customer date of birth.",
  occupation = "Customer occupation.",
  marital_status = "Customer marital status.",
  household_size = "Number of people in the household.",
  credit_band = "Customer credit band from A (best) to E.",
  prior_claims_5y = "Claims declared from the five years before joining.",
  licence_points = "Driving-licence penalty points.",
  years_at_address = "Years the customer has lived at the address.",
  customer_since_year = "Year the customer joined the insurer.",
  email_domain = "Anonymised email domain.",
  marketing_consent = "Whether the customer has marketing consent.",
  document_preference = "Preferred document channel: email, post or app.",
  previous_insurer = "Previous insurer.",
  campaign_code = "Marketing campaign code, when present.",
  branch_id = "Insurer branch identifier.",
  marketing_segment = "Marketing segment assigned to the customer.",
  region = "Geographic region of the address.",
  urban_density = "Urban density classification.",
  flood_zone = "Flood-risk zone from 1 (lowest) to 5.",
  distance_to_river_km = "Distance from the address to a river in kilometres.",
  elevation_m = "Elevation above the local river level in metres.",
  soil_type = "Soil type at the address.",
  year_built = "Year the property was built.",
  property_type = "Property type.",
  roof_type = "Roof type.",
  basement = "Whether the property has a basement.",
  trees_within_5m = "Whether trees are within five metres of the property.",
  listed_building = "Whether the property is listed.",
  bedrooms = "Number of bedrooms.",
  energy_rating = "Property energy rating from A to G.",
  solar_panels = "Whether the property has solar panels.",
  year = "Calendar year for the address-weather observation.",
  hail_days = "Number of hail days in the year.",
  wind_exposure_index = "Local wind exposure index from 0 to 10.",
  freezing_days = "Number of freezing days in the year.",
  dry_summer_index = "Dry-summer index from 0 (wet) to 1 (very dry).",
  wildfire_index = "Wildfire-risk index from 0 to 1.",
  rainfall_mm = "Annual rainfall in millimetres.",
  mean_temperature_c = "Mean annual temperature in degrees Celsius.",
  claim_id = "Claim identifier.",
  line = "Insurance line: motor, buildings or contents.",
  peril = "Claim peril or cause of loss.",
  loss_date = "Date the insured loss occurred.",
  report_date = "Date the claim was reported.",
  status = "Claim status: closed, open or repudiated.",
  paid_to_date = "Paid claim cost to the valuation date, net of excess.",
  incurred_to_date = "Paid cost plus the outstanding case estimate.",
  recoveries = "Recoveries from third parties or salvage.",
  repairer_id = "Motor repairer identifier.",
  third_party_id = "Motor third-party identifier.",
  prediction = "Submitted expected claim cost for the test row."
)

type_label <- function(x) paste(unique(c(typeof(x), class(x))), collapse = "/")
column_dictionary <- rbindlist(lapply(tables, function(t) {
  dt <- raw[[t]]
  data.table(table = t, column = names(dt),
             type = vapply(dt, type_label, character(1)),
             description = vapply(names(dt), function(cn) {
               if (!is.null(column_descriptions[[cn]])) column_descriptions[[cn]]
               else "Description not yet documented"
             }, character(1)))
}))
save_csv(column_dictionary, STEP, "column_dictionary.csv")

md_preview <- function(dt) {
  x <- copy(dt[seq_len(min(20L, nrow(dt)))])
  x[, row_number := .I]
  setcolorder(x, c("row_number", setdiff(names(x), "row_number")))
  for (cn in names(x)) {
    x[[cn]] <- gsub("\\|", "\\\\|", as.character(x[[cn]]))
    x[[cn]][is.na(x[[cn]])] <- "NA"
  }
  md_table(x, 3)
}

pre_eda_sections <- unlist(lapply(tables, function(t) {
  list(paste0("### ", t), "",
       md_table(column_dictionary[table == t, .(column, type, description)]),
       "First 20 raw rows:", "", md_preview(raw[[t]]))
}))

# 2. Table overview vs handover row counts --------------------------------------------
expected_rows <- c(customers = 545240, addresses = 575983, weather = 2879915,
                   policies_motor = 979968, policies_buildings = 707726, policies_contents = 721617,
                   claims = 163150, test_motor = 254986, test_buildings = 184155,
                   test_contents = 187498, sample_submission = 626639)
overview <- data.table(table = tables,
                       rows = vapply(raw, nrow, integer(1)),
                       cols = vapply(raw, ncol, integer(1)),
                       expected_rows = expected_rows[tables])
overview[, rows_match := rows == expected_rows]
save_csv(overview, STEP, "table_overview.csv")

# 3. Column profiles (type, missingness, cardinality, range / top values) -------------
profile_column <- function(x) {
  n_miss <- sum(is.na(x))
  n_uniq <- uniqueN(x, na.rm = TRUE)
  res <- list(type = class(x)[1], n_missing = n_miss, pct_missing = round(100 * n_miss / length(x), 2),
              n_unique = n_uniq, min = NA_character_, median = NA_character_, max = NA_character_,
              top_values = NA_character_)
  xx <- x[!is.na(x)]
  if (length(xx) == 0) return(res)
  if (is.numeric(xx) || inherits(xx, "Date")) {
    res$min <- as.character(min(xx)); res$median <- as.character(median(xx)); res$max <- as.character(max(xx))
  } else if (n_uniq <= 1000) {
    tv <- sort(table(xx), decreasing = TRUE)[seq_len(min(5, n_uniq))]
    res$top_values <- paste0(names(tv), " (", round(100 * as.numeric(tv) / length(x), 1), "%)", collapse = "; ")
  } else {
    res$top_values <- "high cardinality"
  }
  res
}
profiles <- rbindlist(lapply(tables, function(t) {
  dt <- raw[[t]]
  rbindlist(lapply(names(dt), function(cn) c(list(table = t, column = cn), profile_column(dt[[cn]]))))
}))
save_csv(profiles, STEP, "column_profiles.csv")
log_msg("Column profiles done")

# 4. Identifier formats and join coverage -----------------------------------------------
cust_ids <- raw$customers$customer_id
addr_ids <- raw$addresses$address_id
wx_keys <- raw$weather[, paste(address_id, year)]
policy_tables <- grep("^(policies|test)_", tables, value = TRUE)

id_checks <- rbindlist(lapply(policy_tables, function(t) {
  dt <- raw[[t]]
  data.table(
    table = t,
    rows = nrow(dt),
    dup_row_id = sum(duplicated(dt$row_id)),
    bad_policy_id_format = sum(!grepl("^[MBC][0-9]{8}$", dt$policy_id)),
    customer_id_not_8_chars = sum(nchar(dt$customer_id) != 8, na.rm = TRUE),
    customer_match_raw_pct = round(100 * mean(dt$customer_id %in% cust_ids), 2),
    customer_match_padded_pct = round(100 * mean(pad_id(dt$customer_id) %in% cust_ids), 2),
    address_match_pct = round(100 * mean(dt$address_id %in% addr_ids), 2),
    weather_match_pct = round(100 * mean(paste(dt$address_id, year(dt$period_start)) %in% wx_keys), 2),
    period_end_before_start = sum(dt$period_end < dt$period_start),
    min_start = as.character(min(dt$period_start)),
    max_end = as.character(max(dt$period_end))
  )
}))
save_csv(id_checks, STEP, "id_and_join_checks.csv")

all_policy_ids <- unique(unlist(lapply(raw[grep("^policies_", tables, value = TRUE)], `[[`, "policy_id")))
sub_check <- data.table(
  check = c("sample_submission row_ids found in test files", "test row_ids found in sample_submission",
            "claims with unknown policy_id", "claims with bad claim_id format", "duplicate claim_id",
            "bad-format claim_ids duplicating another claim (policy, peril, dates, amounts)"),
  value = c(mean(raw$sample_submission$row_id %in% unlist(lapply(raw[grep("^test_", tables, value = TRUE)], `[[`, "row_id"))),
            mean(unlist(lapply(raw[grep("^test_", tables, value = TRUE)], `[[`, "row_id")) %in% raw$sample_submission$row_id),
            sum(!raw$claims$policy_id %in% all_policy_ids),
            sum(!grepl("^CL[0-9]{8}$", raw$claims$claim_id)),
            sum(duplicated(raw$claims$claim_id)),
            raw$claims[, n_same := .N, by = .(policy_id, peril, loss_date, report_date, incurred_to_date)][
              !grepl("^CL[0-9]{8}$", claim_id) & n_same > 1, .N])
)
raw$claims[, n_same := NULL]
save_csv(sub_check, STEP, "submission_and_claim_id_checks.csv")
log_msg("ID and join checks done")

# 5. Claims overview ---------------------------------------------------------------------
cl <- copy(raw$claims)
cl[, `:=`(loss_year = year(loss_date), report_lag = as.numeric(report_date - loss_date))]
claims_status <- cl[, .(claims = .N, paid = sum(paid_to_date), incurred = sum(incurred_to_date),
                        recoveries = sum(recoveries)), by = .(line, status)][order(line, status)]
claims_peril <- cl[status != "repudiated", .(claims = .N, mean_incurred = mean(incurred_to_date),
                                             max_incurred = max(incurred_to_date)),
                   by = .(line, peril, loss_year)][order(line, peril, loss_year)]
open_share <- cl[, .(claims = .N, pct_open = round(100 * mean(status == "open"), 1)), by = .(loss_year)][order(loss_year)]
report_lag <- cl[, as.list(quantile(report_lag, c(0.5, 0.9, 0.99, 1))), by = line]
setnames(report_lag, c("line", "lag_p50", "lag_p90", "lag_p99", "lag_max"))
claim_sanity <- data.table(
  check = c("paid > incurred", "recoveries > incurred", "report_date < loss_date",
            "report_date after valuation date", "negative incurred", "repudiated with incurred > 0",
            "loss_date before 2021-01-01"),
  n = c(cl[paid_to_date > incurred_to_date + 1e-6, .N], cl[recoveries > incurred_to_date + 1e-6, .N],
        cl[report_date < loss_date, .N], cl[report_date > VALUATION_DATE, .N], cl[incurred_to_date < 0, .N],
        cl[status == "repudiated" & incurred_to_date > 0, .N], cl[loss_date < as.Date("2021-01-01"), .N])
)
top_claims <- cl[order(-incurred_to_date)][1:10, .(claim_id, line, peril, status, loss_date, paid_to_date, incurred_to_date)]
save_csv(claims_status, STEP, "claims_by_status.csv")
save_csv(claims_peril, STEP, "claims_by_peril_year.csv")
save_csv(claim_sanity, STEP, "claims_sanity_checks.csv")

# 6. Train vs test drift ------------------------------------------------------------------
drift <- rbindlist(lapply(LINES, function(ln) {
  tr <- raw[[paste0("policies_", ln)]]; te <- raw[[paste0("test_", ln)]]
  cols <- setdiff(intersect(names(tr), names(te)), c("row_id", "policy_id", "customer_id", "address_id"))
  rbindlist(lapply(cols, function(cn) {
    a <- tr[[cn]]; b <- te[[cn]]
    if (is.numeric(a)) {
      data.table(line = ln, column = cn, kind = "numeric", train_mean = mean(a, na.rm = TRUE),
                 test_mean = mean(b, na.rm = TRUE),
                 std_diff = (mean(b, na.rm = TRUE) - mean(a, na.rm = TRUE)) / sd(a, na.rm = TRUE),
                 max_share_diff = NA_real_)
    } else if (is.character(a) || is.logical(a)) {
      pa <- prop.table(table(a, useNA = "ifany")); pb <- prop.table(table(b, useNA = "ifany"))
      lv <- union(names(pa), names(pb))
      d <- abs(ifelse(is.na(pa[lv]), 0, pa[lv]) - ifelse(is.na(pb[lv]), 0, pb[lv]))
      data.table(line = ln, column = cn, kind = "categorical", train_mean = NA_real_, test_mean = NA_real_,
                 std_diff = NA_real_, max_share_diff = max(d))
    }
  }))
}))
drift[!is.finite(std_diff) & kind == "numeric", std_diff := 0]
drift[, drift_score := fifelse(kind == "numeric", abs(std_diff), max_share_diff * 5)]
setorder(drift, line, -drift_score)
save_csv(drift, STEP, "train_test_drift.csv")
log_msg("Claims and drift summaries done")

# 7. Plots ------------------------------------------------------------------------------------
stack_lines <- function(cols) {
  rbindlist(lapply(LINES, function(ln) {
    rbind(raw[[paste0("policies_", ln)]][, c(cols), with = FALSE][, `:=`(line = ln, set = "train")],
          raw[[paste0("test_", ln)]][, c(cols), with = FALSE][, `:=`(line = ln, set = "test")])
  }))
}
pol_all <- stack_lines(c("exposure", "written_premium", "period_start"))

p <- ggplot(pol_all, aes(exposure, fill = set)) +
  geom_histogram(bins = 60, position = "identity", alpha = 0.5) +
  facet_wrap(~line, scales = "free_y") + scale_x_continuous(limits = c(0, 2)) +
  labs(title = "Raw exposure: train vs test", subtitle = "Values > 1 are the days/360 and raw-days traps (raw days are off-scale)")
save_plot(p, STEP, "plots/exposure_train_vs_test.png")

p <- ggplot(pol_all, aes(written_premium, colour = set)) + geom_density() +
  facet_wrap(~line, scales = "free") + scale_x_log10(labels = scales::comma) +
  labs(title = "Written premium distribution (log scale)")
save_plot(p, STEP, "plots/written_premium_train_vs_test.png")

p <- ggplot(pol_all[set == "train", .(exposure = sum(exposure)), by = .(line, year = year(period_start))],
            aes(factor(year), exposure, fill = line)) + geom_col(position = "dodge") +
  scale_y_continuous(labels = scales::comma) + labs(x = "policy year", title = "Raw exposure by policy year")
save_plot(p, STEP, "plots/exposure_by_year.png")

si <- rbindlist(lapply(c("buildings", "contents"), function(ln) {
  rbind(raw[[paste0("policies_", ln)]][, .(sum_insured, line = ln, set = "train")],
        raw[[paste0("test_", ln)]][, .(sum_insured, line = ln, set = "test")])
}))
p <- ggplot(si, aes(sum_insured, fill = set)) + geom_histogram(bins = 80, position = "identity", alpha = 0.5) +
  facet_wrap(~line, scales = "free_y") + scale_x_log10(labels = scales::comma) +
  labs(title = "Sum insured (log scale)", subtitle = "Right-hand cluster = suspected 1000x unit error")
save_plot(p, STEP, "plots/sum_insured_outliers.png")

p <- ggplot(cl[, .N, by = .(line, month = as.Date(format(loss_date, "%Y-%m-01")))], aes(month, N, colour = line)) +
  geom_line() + geom_vline(xintercept = VALUATION_DATE, linetype = 2) +
  labs(title = "Claims by loss month", subtitle = "Dip at the end of 2024 = late reporting (IBNR)", y = "claims")
save_plot(p, STEP, "plots/claims_by_loss_month.png")

p <- ggplot(cl[status != "repudiated" & incurred_to_date > 0], aes(peril, incurred_to_date, fill = line)) +
  geom_boxplot(outlier.size = 0.3) + scale_y_log10(labels = scales::comma) + coord_flip() +
  facet_wrap(~line, scales = "free_y") + labs(title = "Incurred by peril (log scale, non-repudiated)")
save_plot(p, STEP, "plots/incurred_by_peril.png", width = 11)

p <- ggplot(cl[report_lag >= 0], aes(report_lag + 1, colour = line)) + stat_ecdf() + scale_x_log10() +
  labs(title = "Report lag ECDF (days + 1, log scale)", x = "days from loss to report + 1", y = "share reported")
save_plot(p, STEP, "plots/report_lag_ecdf.png")

miss <- profiles[pct_missing > 0][order(-pct_missing)][1:min(.N, 40)]
p <- ggplot(miss, aes(reorder(paste(table, column, sep = "."), pct_missing), pct_missing)) + geom_col() +
  coord_flip() + labs(x = NULL, y = "% missing", title = "Columns with missing values (top 40)")
save_plot(p, STEP, "plots/missingness.png", height = 8)
log_msg("Plots saved")

# 8. Markdown report ----------------------------------------------------------------------------
write_md(list(
  "# Step 3 - Quick EDA (raw data)", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/1_eda.R`. No cleaning applied."), "",
  "## Pre-EDA: data dictionary and first 20 raw rows",
  "Expand each dataset below to inspect its columns, raw R types and first 20 rows before reading the summary checks.",
  "<details>", "<summary>Show data dictionary and raw samples</summary>", "",
  pre_eda_sections,
  "</details>", "",
  "## Tables vs handover row counts", md_table(overview),
  "## Identifier formats and join coverage",
  "`customer_match_padded_pct` shows the effect of left-padding customer_id to 8 characters (trap 1).", "",
  md_table(id_checks),
  "## Submission and claim id checks", md_table(sub_check, 4),
  "## Claims by line and status", md_table(claims_status, 0),
  "## Share of open claims by loss year (immaturity)", md_table(open_share, 1),
  "## Report lag (days) by line", md_table(report_lag, 0),
  "## Claim sanity checks", md_table(claim_sanity),
  "## Ten largest claims", md_table(top_claims, 0),
  "## Largest train-vs-test drift (top 8 per line)",
  "Numeric: standardised mean difference. Categorical: largest absolute change in level share.", "",
  md_table(drift[, head(.SD, 8), by = line][, .(line, column, kind, train_mean, test_mean, std_diff, max_share_diff)]),
  "## Plots", paste0("- [", list.files(file.path(PATHS$output, STEP, "plots")), "](plots/",
                     list.files(file.path(PATHS$output, STEP, "plots")), ")"), "",
  "Full column-level detail: `column_dictionary.csv`, `column_profiles.csv`, `train_test_drift.csv`, `claims_by_peril_year.csv`."
), STEP, "eda_report.md")

log_msg("Quick EDA done. Report: ", out_file(STEP, "eda_report.md"))

# 9. Column EDA of the raw data: one plot per column ------------------------------------------------
#   Each line's policies (2021-24) vs test (2025), weather 2021-24 vs 2025, and customers, addresses and claims
#   as one set. Identifiers and dates are skipped. Each column gets summary statistics, warning flags and, where
#   there are two sets, a drift score (PSI). The cleaned-data version is at the bottom of week1/R/2_clean.R.
# Outputs: week1/output/1_1_eda/ (column_eda_report.md, column_summary.csv, pages.csv, one <page>.md and one
#          <page>/ plot folder per table). week1/R/5_build_site.R adds the pages to the website.
source("week1/R/eda_helpers.R")  # its profile_column() replaces the one above, which is no longer needed
STEP <- "1_1_eda"
OVERVIEW <- "column_eda_report.md"
RAW_ID_COLS <- c("row_id", "policy_id", "customer_id", "address_id", "claim_id", "repairer_id",
                 "third_party_id", "surname")

raw_cols <- function(dt) {
  nm <- names(dt)
  is_date <- vapply(dt, function(x) inherits(x, c("Date", "POSIXt")), logical(1))
  nm[!nm %in% RAW_ID_COLS & !is_date]
}

unlink(file.path(PATHS$output, STEP), recursive = TRUE)
summaries <- list()

for (ln in LINES) {
  a <- raw[[paste0("policies_", ln)]]; b <- raw[[paste0("test_", ln)]]
  page <- paste0("raw_", ln)
  sets <- c("policies 2021-24", "test 2025")
  st <- eda_columns(page, a, b, sets, union(raw_cols(a), raw_cols(b)))
  summaries[[page]] <- write_eda_page(page, paste0("Raw ", ln, ": policies vs test"),
                                      two_set_intro(sets[1], sets[2]), st, OVERVIEW)
}

for (tb in c("customers", "addresses")) {
  page <- paste0("raw_", tb)
  st <- eda_columns(page, raw[[tb]], NULL, tb, raw_cols(raw[[tb]]))
  summaries[[page]] <- write_eda_page(page, paste0("Raw ", tb),
                                      "Share of rows in each value or bin (one row per table row).", st, OVERVIEW)
}

wx <- raw$weather
sets <- c("2021-24", "2025 (test year)")
st <- eda_columns("raw_weather", wx[year < 2025], wx[year == 2025], sets, setdiff(raw_cols(wx), "year"))
summaries$raw_weather <- write_eda_page("raw_weather", "Raw weather: 2021-24 vs 2025",
                                        two_set_intro(sets[1], sets[2]), st, OVERVIEW)

st <- eda_columns("raw_claims", raw$claims, NULL, "claims", raw_cols(raw$claims))
summaries$raw_claims <- write_eda_page("raw_claims", "Raw claims",
                                       "Share of claims in each value or bin, all lines together (one row per claim).",
                                       st, OVERVIEW)

col_summary <- rbindlist(summaries, fill = TRUE)
pages <- names(summaries)
write_page_index(col_summary, pages)

# Observations: figures are recomputed on each run so the text stays in line with the data
psi_of <- function(pg, col) sprintf("%.2f", col_summary[page == pg & column == col, psi][1])
wx_sd <- wx[, .(dry_sd = sd(dry_summer_index)), keyby = year]
wx_cor <- merge(wx[year < 2025, .(t = mean(mean_temperature_c), f = mean(freezing_days)), by = address_id],
                wx[year == 2025, .(address_id, mean_temperature_c, freezing_days)], by = "address_id")
contacts <- raw$policies_motor[, .(contacts = mean(customer_service_contacts)),
                               by = .(has_claim = policy_id %in% raw$claims[status != "repudiated", policy_id])]
observations <- c(
  "## Observations and recommended changes", "",
  "| # | Observation | Recommendation |", "|---|---|---|",
  "| 1 | `compulsory_excess` has a single value in every line | No information: exclude from the models |",
  sprintf("| 2 | `renewal_count` shifts in 2025 (PSI %s motor); about 2.8%% of 2025 rows have a count one above the 2021-24 maximum (one more year of renewals) | Cap at the 2021-24 maximum so GLM bins and tree splits treat the new top value like the old one |",
          psi_of("raw_motor", "renewal_count")),
  sprintf("| 3 | `construction_type` drifts (PSI %s) only because T is used in 2021-22 and W in 2023-24 and 2025 | Cleaning maps both to timber; the cleaned column EDA shows timber frequency flat across the switch |",
          psi_of("raw_buildings", "construction_type")),
  sprintf("| 4 | `vehicle_age` is older in 2025 (PSI %s); the mean rises by about 1.5 years | Check the fitted effect is smooth and monotone at the top end |",
          psi_of("raw_motor", "vehicle_age")),
  sprintf("| 5 | Weather drifts strongly (PSI temperature %s, dry summer %s, freezing days %s) while the means barely move; the spread changes by year (dry-summer SD %s) | Weather is the actual weather of each policy year, so part of it is year noise. 2025 values correlate %.2f (temperature) and %.2f (freezing days) with each address's 2021-24 average: test the address average (stable exposure) next to the yearly values |",
          psi_of("raw_weather", "mean_temperature_c"), psi_of("raw_weather", "dry_summer_index"),
          psi_of("raw_weather", "freezing_days"), paste(sprintf("%d %.2f", wx_sd$year, wx_sd$dry_sd), collapse = ", "),
          cor(wx_cor$t, wx_cor$mean_temperature_c), cor(wx_cor$f, wx_cor$freezing_days)),
  sprintf("| 6 | `customer_service_contacts`: %.2f per motor row on policies with a claim vs %.2f without (PSI %s) | Leakage (contacts follow the claim); already excluded in `NON_FEATURES` |",
          contacts[has_claim == TRUE, contacts], contacts[has_claim == FALSE, contacts], psi_of("raw_motor", "customer_service_contacts")),
  "| 7 | `telematics_score` is missing for about 87% of motor rows (not opted in) | Missing means 'no telematics', not a low score: keep `telematics_opt_in` alongside the score |",
  "| 8 | `campaign_code` is missing for about half of customers; `previous_insurer` has 40 levels | Marketing fields: check over time (cleaned column EDA) and in the models before relying on them |",
  "| 9 | `listed_building` (97%) and `lodgers` (95%) are dominated by one value | Keep, but expect little credibility |",
  "| 10 | `recoveries` are zero on 91% of claims | Only closed motor own-damage and theft claims recover; net cost already subtracts them |",
  ""
)

write_md(list(
  "# Column EDA - raw data", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/1_eda.R` (section 9). No cleaning applied."), "",
  "One plot per column showing the distribution of its values as a share of rows. Where a table has two sets,",
  "blue is 2021-24 and orange is 2025 (test), so differences between the training years and the year we predict",
  "are visible directly. The cleaned data and raw vs cleaned comparisons are at the bottom of `week1/R/2_clean.R`.", "",
  method_lines(),
  observations,
  "## Pages", "", page_links(col_summary, pages),
  "## Flagged columns", "", flag_table(col_summary, pages),
  "Full table with every statistic: `column_summary.csv`."
), STEP, OVERVIEW)

log_msg("Done. Reports: ", out_file("1_eda", "eda_report.md"), ", ", out_file(STEP, OVERVIEW))
