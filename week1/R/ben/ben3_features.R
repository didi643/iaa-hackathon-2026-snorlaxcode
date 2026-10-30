# ben/ben3_features.R --------------------------------------------------------
# BEN 3 groundwork: candidate features built only from what is known before a row starts, and their signal.
# Reads data/week_1/raw data/ (renewal_decision), data/week_1/clean/ and data/week_1/ben/ (claims history); fits nothing.
#   A. Previous row of the same policy (known at renewal or mid-term change): its renewal outcome, service contacts,
#      exposure, and what changed since (premium position, voluntary excess, vehicle, address, sum insured, gap)
#   B. Claim history the insurer can see on 1 January of the row's policy year (one cut-off for train and test):
#      reported claims of the previous calendar year by count, repudiated claims, and the peril of the last claim
#   C. Customer holdings: lines and policies held by the customer in the same policy year
#   D. Point-in-time check of customer-table fields (one snapshot per customer, not per year)
# Signal = claim frequency relativity of 2022-24 train rows by level, overall and among rows with no claim in the
# policy's own history (so a feature that only repeats claims history shows little there); train vs test shares too.
# Run:     Rscript week1/R/ben/ben3_features.R (after week1/R/ben/ben_clean.R)
# Outputs: week1/output/ben/ben3_features/ (ben3_features_report.md + CSVs)

source("week1/R/0_setup.R")
source("week1/R/ben/ben_helpers.R")
STUDY <- "ben3_features"
study_csv <- function(dt, f) fwrite(dt, ben_out(file.path(STUDY, f)))

rd <- rbindlist(lapply(LINES, function(ln) {
  as.data.table(read_parquet(file.path(PATHS$raw, paste0("policies_", ln, ".parquet")), col_select = c("row_id", "renewal_decision")))
}))
base_cols <- c("row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end", "policy_year", "exposure",
               "premium_index", "voluntary_excess", "customer_service_contacts", "new_business", "make_model",
               "sum_insured", "years_at_address", "customer_age", "hist_policy_claims", "y_n_claims", "y_cost")
rows <- rbindlist(lapply(LINES, function(ln) {
  get <- function(set) { d <- read_ben(paste0(set, "_", ln)); d[, intersect(base_cols, names(d)), with = FALSE][, set := set] }
  rbind(get("train"), get("test"), fill = TRUE)[, line := ln]
}), fill = TRUE)
rows <- merge(rows, rd, by = "row_id", all.x = TRUE)

# A. Previous row of the same policy -------------------------------------------------------------------------
setorder(rows, line, policy_id, period_start)
rows[, `:=`(prev_decision = shift(renewal_decision), prev_contacts = shift(customer_service_contacts),
            prev_exposure = shift(exposure), prev_premium_index = shift(premium_index), prev_excess = shift(voluntary_excess),
            prev_make_model = shift(make_model), prev_address = shift(address_id), prev_si = shift(sum_insured),
            prev_end = shift(period_end)), by = .(line, policy_id)]
rows[, `:=`(
  f_prev_decision = fifelse(is.na(prev_decision), "no previous row", prev_decision),
  f_prev_contacts = fifelse(is.na(prev_contacts), "no previous row", as.character(pmin(prev_contacts, 3))),
  f_prev_short = fifelse(is.na(prev_exposure), "no previous row", fifelse(prev_exposure < 0.9, "previous row < 0.9 years", "full year")),
  f_premium_move = fifelse(is.na(prev_premium_index), "no previous row",
                           as.character(cut(premium_index / prev_premium_index, c(0, 0.9, 0.97, 1.03, 1.1, Inf),
                                            labels = c("<0.90", "0.90-0.97", "0.97-1.03", "1.03-1.10", ">1.10")))),
  f_excess_change = fifelse(is.na(prev_excess), "no previous row",
                            fifelse(voluntary_excess > prev_excess, "raised", fifelse(voluntary_excess < prev_excess, "lowered", "same"))),
  f_vehicle_changed = fifelse(line != "motor" | is.na(prev_make_model), NA_character_,
                              fifelse(make_model != prev_make_model, "changed", "same")),
  f_moved = fifelse(is.na(prev_address), "no previous row", fifelse(address_id != prev_address, "moved", "same")),
  f_si_change = fifelse(line == "motor" | is.na(prev_si), NA_character_,
                        as.character(cut(sum_insured / prev_si, c(0, 0.99, 1.01, 1.1, Inf), labels = c("down", "same", "up <10%", "up >10%")))),
  f_gap = fifelse(is.na(prev_end), "no previous row", fifelse(period_start - prev_end > 1, "gap", "continuous")))]

# B. Claims visible on 1 January of the policy year ------------------------------------------------------------
cl <- read_clean("claims_matched")
seen <- function(by_key, keep_status) {
  out <- list()
  for (y in 2022:2025) {
    cut_date <- as.Date(paste0(y, "-01-01"))
    c1 <- cl[report_date < cut_date & loss_date >= cut_date - 365 & status %in% keep_status]
    out[[as.character(y)]] <- c1[, .(n = .N, last_peril = peril[which.max(loss_date)]), by = c(by_key, "line")][, policy_year := y]
  }
  rbindlist(out)
}
pol_paid <- seen("policy_id", c("closed", "open"))
pol_rep <- seen("policy_id", "repudiated")
rows <- merge(rows, pol_paid[, .(policy_id, line, policy_year, jan_claims = n, last_peril)], by = c("policy_id", "line", "policy_year"), all.x = TRUE)
rows <- merge(rows, pol_rep[, .(policy_id, line, policy_year, jan_repudiated = n)], by = c("policy_id", "line", "policy_year"), all.x = TRUE)
rows[policy_year > 2021, `:=`(
  f_jan_claims = as.character(pmin(fcoalesce(jan_claims, 0L), 2L)),
  f_repudiated = fifelse(fcoalesce(jan_repudiated, 0L) > 0, "repudiated claim last year", "none"),
  f_last_peril = fifelse(is.na(last_peril), "no claim", last_peril))]
# The current claims history (365 days before the row start) vs the 1 January cut-off, by start quarter
hist_window <- rows[policy_year >= 2024, .(rows = .N, share_hist_365d = mean(hist_policy_claims > 0, na.rm = TRUE),
                                           share_jan_cutoff = mean(fcoalesce(jan_claims, 0L) > 0)),
                    by = .(line, set, start_q = quarter(period_start))][order(line, set, start_q)]

# C. Customer holdings in the same policy year ---------------------------------------------------------------
hold <- rows[, .(n_lines = uniqueN(line), n_policies = uniqueN(policy_id)), by = .(customer_id, policy_year)]
rows <- merge(rows, hold, by = c("customer_id", "policy_year"), all.x = TRUE)
rows[, f_n_lines := as.character(n_lines)]
rows[, f_policies_in_line := as.character(pmin(.N, 3L)), by = .(customer_id, policy_year, line)]

# Signal -----------------------------------------------------------------------------------------------------
FEATURES <- c("f_prev_decision", "f_prev_contacts", "f_prev_short", "f_premium_move", "f_excess_change", "f_vehicle_changed",
              "f_moved", "f_si_change", "f_gap", "f_jan_claims", "f_repudiated", "f_last_peril", "f_n_lines", "f_policies_in_line")
tr <- rows[set == "train" & policy_year >= 2022]
signal <- rbindlist(lapply(FEATURES, function(f) {
  d <- tr[!is.na(get(f))]
  base <- d[, .(f_all = sum(y_n_claims) / sum(exposure), f_clean = sum(y_n_claims[hist_policy_claims == 0]) / sum(exposure[hist_policy_claims == 0])), by = line]
  s <- d[, .(exposure = sum(exposure), frequency = sum(y_n_claims) / sum(exposure),
             exposure_no_history = sum(exposure[hist_policy_claims == 0]),
             frequency_no_history = sum(y_n_claims[hist_policy_claims == 0]) / sum(exposure[hist_policy_claims == 0]),
             burn = sum(y_cost) / sum(exposure)), by = .(line, level = get(f))]
  s <- merge(s, base, by = "line")[, `:=`(feature = f, rel = frequency / f_all, rel_no_history = frequency_no_history / f_clean,
                                          share_train = exposure / sum(exposure)), by = line]
  te <- rows[set == "test" & !is.na(get(f)), .(share_test = sum(exposure)), by = .(line, level = get(f))][, share_test := share_test / sum(share_test), by = line]
  merge(s, te, by = c("line", "level"), all.x = TRUE)[, !c("f_all", "f_clean")]
}))
setcolorder(signal, c("line", "feature", "level"))
setorder(signal, line, feature, -exposure)
# Spread of the relativity among rows without claims history: what the feature adds beyond it
strength <- signal[share_train >= 0.005, .(levels = .N, spread_all = sqrt(sum(share_train * (rel - 1)^2)),
                                           spread_no_history = sqrt(sum(share_train * (rel_no_history - 1)^2, na.rm = TRUE)),
                                           max_shift_train_test = max(abs(share_test - share_train), na.rm = TRUE)),
                   by = .(line, feature)][order(line, -spread_no_history)]

# D. Point-in-time check: customer-table fields are one value per customer for every year ----------------------
snap <- rows[set == "train", .(rows = .N, years_at_address_varies = uniqueN(years_at_address) > 1), by = customer_id][
  , .(customers = .N, share_varying = mean(years_at_address_varies))]
yaa <- rows[set == "train" | set == "test", .(rows = .N, mean_years_at_address = mean(years_at_address, na.rm = TRUE),
                                               share_exceeds_age_minus_18 = mean(years_at_address > customer_age - 18, na.rm = TRUE)),
            by = .(set, policy_year)][order(policy_year)]

study_csv(signal, "signal_by_level.csv"); study_csv(strength, "signal_strength.csv")
study_csv(hist_window, "history_window_by_start_quarter.csv"); study_csv(yaa, "point_in_time_years_at_address.csv")
write_md(list(
  "# BEN 3 candidate point-in-time features", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/ben/ben3_features.R`. Train rows 2022-24; `rel` = claim",
        "frequency relative to the line, `rel_no_history` the same among rows whose policy had no claim in the previous 365 days."), "",
  "## Strength (exposure-weighted spread of the relativity; levels with >= 0.5% exposure)", md_table(strength, 3),
  "## Claims history: 365 days before the row vs claims reported by 1 January of its policy year",
  "Share of 2024 train and 2025 test rows with a prior policy claim, by the quarter the row starts.", "",
  md_table(hist_window, 4),
  "## Point in time: customer table", md_table(snap, 3), md_table(yaa, 3),
  "## Every level", md_table(signal[, .(line, feature, level, exposure, share_train, share_test, rel, rel_no_history)], 3)
), file.path("ben", STUDY), "ben3_features_report.md")
log_msg("Done. Report: ", ben_out(file.path(STUDY, "ben3_features_report.md")))
