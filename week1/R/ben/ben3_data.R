# ben/ben3_data.R ------------------------------------------------------------
# BEN 3 data step: the shared clean tables plus the targets, development and point-in-time features BEN 3 uses.
# Reads data/week_1/clean/ (run week1/R/2_clean.R first) and the raw renewal_decision; writes data/week_1/ben3/ (git-ignored) and
# week1/output/ben/ben3_data/ (report). Findings behind each choice: week1/output/ben/ben3_study/ and week1/output/ben/ben3_features/.
#   Targets   claims with net cost > 0 per peril (y_npos_<peril>), net cost after expected recoveries on open
#             own-damage / theft claims (y_costadj_<peril>; closed-claim recovery ratio x open incurred)
#   IBNR      per-row chain-ladder share of each peril's claims already reported at 31 Dec 2024 (y_sharen_<peril>,
#             counts; y_sharew_<peril>, capped cost): the row's own days, so late starters get their own development
#   Features  - types: ordered text -> natural-order integers (BEN_ORDINAL), labels stored as numbers -> categories
#             - engineered (SAM 2/3): young / novice driver, licence ratio, telematics missing, log sum insured,
#               property age, sum insured per bedroom / person, high-value items per 10k insured, flood and
#               subsidence scores
#             - claims history as at 1 January of the policy year: claims lost in the previous calendar year and
#               reported by 1 January, the same look-back for every year (2021 rows: NA, no earlier data)
#               hist_pol_n, hist_pol_cost (log, capped), hist_pol_n_<peril> (same peril), hist_cust_other_n
#               (customer's other lines), hist_addr_flood / water / subs / storm (property claims at the address)
#             - previous row of the policy: prev_declined (insurer declined at renewal), mid_term (a change within
#               the same policy year, also visible in test); n_lines (lines the customer holds that year)
# Run:     Rscript week1/R/ben/ben3_data.R

source("week1/R/0_setup.R")
source("week1/R/ben/ben_helpers.R")
BEN3_DIR <- file.path("data", "week_1", "ben3")
HIST_MAX_N <- 3
HIST_COST_CAP <- 50000
ADDR_GROUP <- c(flood = "flood", escape_of_water = "water", subsidence = "subs", storm = "storm")

recode_types <- function(dt) {
  for (f in intersect(names(BEN_ORDINAL), names(dt))) set(dt, j = f, value = match(dt[[f]], BEN_ORDINAL[[f]]))
  for (f in intersect(BEN_AS_CATEGORY, names(dt))) set(dt, j = f, value = as.character(dt[[f]]))
  dt
}

engineer <- function(dt, ln) {
  if (ln == "motor") {
    dt[, `:=`(young_driver = as.integer(driver_age < 25), novice_driver = as.integer(years_licensed < 3),
              licence_ratio = years_licensed / pmax(driver_age - 16, 1), telematics_missing = as.integer(is.na(telematics_score)))]
  } else {
    dt[, `:=`(log_sum_insured = log1p(sum_insured), property_age = policy_year - year_built,
              flood_score = flood_zone / (1 + pmax(elevation_m, 0) / 10))]
  }
  if (ln == "buildings") dt[, `:=`(si_per_bedroom = sum_insured / pmax(bedrooms, 1),
                                   subsidence_score = (soil_type == "clay") * as.numeric(trees_within_5m) * dry_summer_index)]
  if (ln == "contents") dt[, `:=`(si_per_person = sum_insured / pmax(household_size, 1),
                                  hvi_per_10k_si = high_value_items / (sum_insured / 1e4))]
  dt
}

# Rows of all three lines (train + test) and the claims ----------------------------------------------------------
rows <- list()
for (ln in LINES) for (set_name in c("train", "test")) {
  d <- read_clean(paste0(set_name, "_", ln))
  rows[[paste(set_name, ln)]] <- d[, .(row_id, policy_id, customer_id, address_id, period_start, period_end, policy_year,
                                      line = ln, set = set_name)]
}
rows <- rbindlist(rows)
rd <- rbindlist(lapply(LINES, function(ln) {
  as.data.table(read_parquet(file.path(PATHS$raw, paste0("policies_", ln, ".parquet")), col_select = c("row_id", "renewal_decision")))
}))
rows <- merge(rows, rd, by = "row_id", all.x = TRUE)

cl <- read_clean("claims_matched")[counts == TRUE]
rec <- cl[status == "closed", .(rec_ratio = sum(recoveries) / sum(incurred_to_date)), by = .(line, peril)][rec_ratio > 0]
cl <- merge(cl, rec, by = c("line", "peril"), all.x = TRUE)[is.na(rec_ratio), rec_ratio := 0]
cl[, net_adj := net_cost - fifelse(status == "open", incurred_to_date * rec_ratio, 0)]
last_row <- rows[order(period_start)][, .SD[.N], by = policy_id]
cl[, `:=`(customer_id = last_row$customer_id[match(policy_id, last_row$policy_id)],
          address_id = fcoalesce(rows$address_id[match(row_id, rows$row_id)], last_row$address_id[match(policy_id, last_row$policy_id)]))]
claims_pos <- cl[!is.na(row_id) & net_adj > 0, .(claim_id, row_id, line, peril, status, loss_date, report_date, net_cost, net_adj)]
claims_pos[, policy_year := rows$policy_year[match(row_id, rows$row_id)]]

# IBNR: per-row chain-ladder reported shares ---------------------------------------------------------------------
cc <- cl[, .(line, peril, loss_date, report_date, net_cost)]
cc <- merge(cc, cc[net_cost > 0, .(cost_cap = quantile(net_cost, LARGE_LOSS_QUANTILE, names = FALSE)), by = .(line, peril)],
            by = c("line", "peril"))
sh <- dev_shares(cc, VALUATION_DATE)
shares <- row_share(rows[set == "train"], sh, VALUATION_DATE, "row")
fwrite(sh, ben_out("ben3_data/chain_ladder_shares_by_month.csv"))

# Claims history as at 1 January ----------------------------------------------------------------------------------
hist <- list()
for (Y in 2022:2025) {
  jan <- as.Date(sprintf("%d-01-01", Y))
  k <- cl[loss_date >= jan - 365 & loss_date < jan & report_date < jan]
  r <- rows[policy_year == Y, .(row_id, policy_id, customer_id, address_id, line)]
  hp <- k[, .(hist_pol_n = .N, hist_pol_cost = log1p(sum(pmin(net_adj, HIST_COST_CAP)))), by = .(line, policy_id)]
  hpp <- dcast(k[, .N, by = .(line, policy_id, v = paste0("hist_pol_n_", peril))], line + policy_id ~ v, value.var = "N", fill = 0)
  hc <- k[, .N, by = .(customer_id, c_line = line)]
  ha <- dcast(k[line %in% c("buildings", "contents") & peril %in% names(ADDR_GROUP), .N,
                by = .(address_id, v = paste0("hist_addr_", ADDR_GROUP[peril]))], address_id ~ v, value.var = "N", fill = 0)
  r <- merge(r, hp, by = c("line", "policy_id"), all.x = TRUE)
  r <- merge(r, hpp, by = c("line", "policy_id"), all.x = TRUE)
  r <- merge(r, ha, by = "address_id", all.x = TRUE)
  oth <- merge(r[, .(row_id, customer_id, line)], hc, by = "customer_id", allow.cartesian = TRUE)[c_line != line, .(hist_cust_other_n = sum(N)), by = row_id]
  r <- merge(r, oth, by = "row_id", all.x = TRUE)
  hist[[as.character(Y)]] <- r[, !c("policy_id", "customer_id", "address_id", "line")]
}
hist <- rbindlist(hist, fill = TRUE)
hcols <- setdiff(names(hist), "row_id")
for (cn in hcols) set(hist, which(is.na(hist[[cn]])), cn, 0)
for (cn in setdiff(hcols, "hist_pol_cost")) set(hist, j = cn, value = pmin(hist[[cn]], HIST_MAX_N))

# Previous row and holdings ------------------------------------------------------------------------------------------
setorder(rows, line, policy_id, period_start)
rows[, `:=`(prev_declined = as.integer(fcoalesce(shift(renewal_decision) == "declined_by_insurer", FALSE)),
            mid_term = as.integer(fcoalesce(shift(policy_year) == policy_year, FALSE))), by = .(line, policy_id)]
rows[, n_lines := uniqueN(line), by = .(customer_id, policy_year)]

# Write -----------------------------------------------------------------------------------------------------------
dir.create(BEN3_DIR, recursive = TRUE, showWarnings = FALSE)
write_parquet(claims_pos, file.path(BEN3_DIR, "claims_pos.parquet"))
summary_rows <- list()
for (ln in LINES) for (set_name in c("train", "test")) {
  d <- engineer(recode_types(read_clean(paste0(set_name, "_", ln))), ln)
  d <- merge(d, rows[, .(row_id, prev_declined, mid_term, n_lines)], by = "row_id", all.x = TRUE)
  d <- merge(d, hist, by = "row_id", all.x = TRUE)
  for (pr in PERILS[[ln]]) {                       # every peril's history column exists, even with no claims
    cn <- paste0("hist_pol_n_", pr)
    if (!cn %in% names(d)) d[, (cn) := fifelse(policy_year > 2021, 0, NA_real_)]
  }
  if (set_name == "train") {
    p <- claims_pos[line == ln]
    for (pr in PERILS[[ln]]) {
      a <- p[peril == pr, .(n = .N, c = sum(net_adj)), by = row_id]
      d[, (paste0("y_npos_", pr)) := fcoalesce(a$n[match(row_id, a$row_id)], 0L)]
      d[, (paste0("y_costadj_", pr)) := fcoalesce(a$c[match(row_id, a$row_id)], 0)]
      s <- shares[peril == pr]
      d[, (paste0("y_sharen_", pr)) := fcoalesce(s$share_n[match(row_id, s$row_id)], 1)]
      d[, (paste0("y_sharew_", pr)) := fcoalesce(s$share_w[match(row_id, s$row_id)], 1)]
    }
  }
  setorder(d, row_id)
  write_parquet(d, file.path(BEN3_DIR, paste0(set_name, "_", ln, ".parquet")))
  new_cols <- c("prev_declined", "mid_term", "n_lines", grep("^hist_", names(d), value = TRUE))
  summary_rows[[paste(set_name, ln)]] <- rbindlist(lapply(new_cols, function(f) d[policy_year >= 2022, .(
    set = set_name, line = ln, feature = f, mean = mean(get(f), na.rm = TRUE), share_positive = mean(get(f) > 0, na.rm = TRUE)),
    by = .(start_q = quarter(period_start))]))
  log_msg(set_name, "_", ln, ": ", nrow(d), " rows written to ", BEN3_DIR)
  rm(d); gc(verbose = FALSE)
}
feat_summary <- rbindlist(summary_rows)
fwrite(feat_summary, ben_out("ben3_data/feature_summary.csv"))
cmp <- dcast(feat_summary, line + feature + start_q ~ set, value.var = "share_positive")
write_md(list(
  "# BEN 3 data step", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/ben/ben3_data.R`; writes `data/week_1/ben3/`."), "",
  "Expected recoveries on open claims (closed-claim recovery ratio):", "", md_table(rec, 3),
  "Share of rows with a positive value, train (2022-24) vs test (2025), by start quarter. History counted as at",
  "1 January, so a row starting late in 2025 sees the same look-back as one starting late in 2023.", "",
  md_table(cmp, 4)
), file.path("ben", "ben3_data"), "ben3_data_report.md")
log_msg("Done. Data in ", BEN3_DIR)
