# 01_profile_emerging.R ----------------------------------------------------------
# Purpose : Profile the developed (Part 1) and emerging (Part 2) markets in R before any cleaning: row counts, key
#           integrity, column differences, the section 2 data traps, experience by year x new business x line x
#           peril, report lags, the 2025 test mix, and how far emerging address / weather values sit inside the
#           developed ranges. Confirms or corrects the Python profiling numbers in the handover (section 2).
# Inputs  : data/week_1/raw data/*.parquet (developed), data/week_2/raw data/emerging/*.parquet (emerging)
# Outputs : week2/output/01_profile/*.csv, week2/output/01_profile/profile_report.md
# Run     : Rscript week2/R/01_profile_emerging.R      (from the repo root)
# Time    : about 1 minute

source("week2/R/00_setup_week2.R")
start_script("01_profile_emerging.R")
STEP <- "01_profile"

mk <- list(developed = read_dev, emerging = read_em)
raw <- list()
for (m in names(mk)) {
  for (t in c(paste0("policies_", LINES), paste0("test_", LINES), "claims", "customers", "addresses", "weather")) {
    raw[[m]][[t]] <- mk[[m]](t)
  }
}

# 1. Row counts and columns ------------------------------------------------------------------------
counts <- rbindlist(lapply(names(raw), function(m) data.table(market = m, table = names(raw[[m]]),
                                                              rows = vapply(raw[[m]], nrow, 1L))))
counts <- dcast(counts, table ~ market, value.var = "rows")
save_csv(counts, STEP, "row_counts.csv")

coldiff <- rbindlist(lapply(names(raw$emerging), function(t) {
  d <- names(raw$developed[[t]]); e <- names(raw$emerging[[t]])
  data.table(table = t, developed_only = paste(setdiff(d, e), collapse = ", "),
             emerging_only = paste(setdiff(e, d), collapse = ", "), shared = length(intersect(d, e)))
}))
save_csv(coldiff, STEP, "column_differences.csv")

# 2. Key integrity -------------------------------------------------------------------------------------
pad_id <- function(x, width = 8) { s <- !is.na(x) & nchar(x) < width; x[s] <- paste0(strrep("0", width - nchar(x[s])), x[s]); x }
keys <- list()
for (m in names(raw)) {
  r <- raw[[m]]
  keys[[length(keys) + 1]] <- data.table(market = m, table = c("customers", "addresses", "weather", "claims"),
    check = c("duplicate customer_id", "duplicate address_id", "duplicate address_id x year", "duplicate claim_id"),
    n = c(sum(duplicated(r$customers$customer_id)), sum(duplicated(r$addresses$address_id)),
          sum(duplicated(r$weather, by = c("address_id", "year"))), sum(duplicated(r$claims$claim_id))))
  for (t in c(paste0("policies_", LINES), paste0("test_", LINES))) {
    p <- r[[t]]
    keys[[length(keys) + 1]] <- data.table(market = m, table = t,
      check = c("duplicate row_id", "customer_id shorter than 8", "customer_id not in customers (after padding)",
                "address_id not in addresses", "address x year not in weather"),
      n = c(sum(duplicated(p$row_id)), sum(nchar(p$customer_id) < 8, na.rm = TRUE),
            sum(!pad_id(p$customer_id) %in% r$customers$customer_id), sum(!p$address_id %in% r$addresses$address_id),
            sum(!paste(p$address_id, year(p$period_start)) %in% paste(r$weather$address_id, r$weather$year))))
  }
}
keys <- rbindlist(keys)
save_csv(keys, STEP, "key_integrity.csv")

# 3. Traps ---------------------------------------------------------------------------------------------
traps <- list()
expo_rows <- list()
for (m in names(raw)) for (t in c(paste0("policies_", LINES), paste0("test_", LINES))) {
  p <- raw[[m]][[t]]
  e2 <- as.numeric(p$period_end - p$period_start + 1) / DAYS_PER_YEAR
  bad <- abs(p$exposure - round(e2, 4)) > 1e-6 & abs(p$exposure - e2) > 1e-6
  traps[[length(traps) + 1]] <- data.table(market = m, table = t,
    check = c("exposure inconsistent with dates", "exposure > 1", "exposure > 1 and equal to days",
              "period_end before period_start", "recomputed exposure > 366/365"),
    n = c(sum(bad), sum(p$exposure > 1), sum(p$exposure > 1 & abs(p$exposure - (e2 * DAYS_PER_YEAR)) < 1.5),
          sum(p$period_end < p$period_start), sum(e2 > 366 / 365)))
  if (m == "emerging") expo_rows[[t]] <- p[bad, .(table = t, row_id, period_start, period_end, exposure_raw = exposure,
                                                  exposure_recomputed = e2[bad])]
}
save_csv(rbindlist(expo_rows), STEP, "emerging_exposure_fixes.csv")

# Claims: duplicates (week 1 trap 10), amounts, status, match to a policy row
match_claims <- function(cl, pol) {
  pol <- rbindlist(lapply(LINES, function(l) pol[[paste0("policies_", l)]][, .(row_id, policy_id, period_start, period_end, new_business, line = l)]))
  mm <- pol[cl, on = .(policy_id, period_start <= loss_date, period_end >= loss_date),
            .(claim_id = i.claim_id, row_id = x.row_id, new_business = x.new_business), allow.cartesian = TRUE]
  list(n_multi = mm[!is.na(row_id), .N, by = claim_id][N > 1, .N],
       m = unique(mm, by = "claim_id"))
}
claims <- list()
for (m in names(raw)) {
  cl <- copy(raw[[m]]$claims)
  cl[, n_same := .N, by = .(policy_id, line, peril, loss_date, report_date, status, incurred_to_date)]
  cl[, dup := !grepl("^CL[0-9]{8}$", claim_id) & n_same > 1]
  traps[[length(traps) + 1]] <- data.table(market = m, table = "claims",
    check = c("non-standard claim_id duplicating another claim", "non-standard claim_id (any)", "paid > incurred",
              "recoveries > incurred", "report_date before loss_date", "repudiated with incurred > 0",
              "negative incurred", "negative recoveries", "loss_date before 2023 (emerging) / 2021 (developed)",
              "loss_date after valuation 2024-12-31", "report_date after valuation"),
    n = c(sum(cl$dup), sum(!grepl("^CL[0-9]{8}$", cl$claim_id)), cl[paid_to_date > incurred_to_date + 1e-6, .N],
          cl[recoveries > incurred_to_date + 1e-6, .N], cl[report_date < loss_date, .N],
          cl[status == "repudiated" & incurred_to_date > 0, .N], cl[incurred_to_date < 0, .N], cl[recoveries < 0, .N],
          cl[loss_date < as.Date(if (m == "emerging") "2023-01-01" else "2021-01-01"), .N],
          cl[loss_date > VALUATION_DATE, .N], cl[report_date > VALUATION_DATE, .N]))
  cl <- cl[dup == FALSE][, c("dup", "n_same") := NULL]
  mc <- match_claims(cl, raw[[m]])
  cl <- merge(cl, mc$m, by = "claim_id", all.x = TRUE)
  traps[[length(traps) + 1]] <- data.table(market = m, table = "claims",
    check = c("claims matching more than one policy row", "claims matching no policy row",
              "unmatched with loss_date before 2023"),
    n = c(mc$n_multi, sum(is.na(cl$row_id)), cl[is.na(row_id) & loss_date < as.Date("2023-01-01"), .N]))
  cl[, market := m]
  cl[, net := fifelse(status == "repudiated", 0, incurred_to_date - recoveries)]
  cl[, lag := as.numeric(report_date - loss_date)]
  claims[[m]] <- cl
}
traps <- rbindlist(traps)
save_csv(traps, STEP, "data_traps.csv")
save_csv(claims$emerging[is.na(row_id), .(claim_id, policy_id, line, peril, loss_date, report_date, status, net)],
         STEP, "emerging_unmatched_claims.csv")

# customer_service_contacts leakage re-check: contacts on rows with / without a claim, and in test
csc <- list()
for (m in names(raw)) for (l in LINES) {
  p <- raw[[m]][[paste0("policies_", l)]]
  hc <- p$row_id %in% claims[[m]][!is.na(row_id) & status != "repudiated", row_id]
  te <- raw[[m]][[paste0("test_", l)]]
  csc[[length(csc) + 1]] <- data.table(market = m, line = l, mean_contacts_claim_rows = mean(p$customer_service_contacts[hc]),
                                       mean_contacts_no_claim_rows = mean(p$customer_service_contacts[!hc]),
                                       mean_contacts_test = mean(te$customer_service_contacts))
}
csc <- rbindlist(csc)
save_csv(csc, STEP, "customer_service_contacts_check.csv")

# renewal_decision levels (training only; future information)
rd <- rbindlist(lapply(names(raw), function(m) rbindlist(lapply(LINES, function(l)
  raw[[m]][[paste0("policies_", l)]][, .N, by = .(renewal_decision)][, `:=`(market = m, line = l)]))))
save_csv(rd, STEP, "renewal_decision_levels.csv")

# 4. Experience by market x line x year x new business x peril (net incurred, repudiated excluded, uncapped) ---
pol_all <- rbindlist(lapply(names(raw), function(m) rbindlist(lapply(LINES, function(l)
  raw[[m]][[paste0("policies_", l)]][, .(market = m, line = l, row_id, year = year(period_start), new_business,
                                         exposure = as.numeric(period_end - period_start + 1) / DAYS_PER_YEAR)]))))
cl_all <- rbindlist(claims, use.names = TRUE, fill = TRUE)[!is.na(row_id) & status != "repudiated"]
cl_all <- merge(cl_all, pol_all[, .(market, row_id, year)], by = c("market", "row_id"))
expo <- pol_all[, .(rows = .N, exposure = sum(exposure)), by = .(market, line, year, new_business)]
exp_line <- merge(expo, cl_all[, .(claims = .N, cost = sum(net)), by = .(market, line, year, new_business)],
                  by = c("market", "line", "year", "new_business"), all.x = TRUE)
exp_line[is.na(claims), `:=`(claims = 0L, cost = 0)]
exp_line[, `:=`(frequency = claims / exposure, severity = cost / pmax(claims, 1), burn = cost / exposure)]
save_csv(exp_line[order(market, line, year, new_business)], STEP, "experience_line_year_nb.csv")

expo_y <- pol_all[, .(exposure = sum(exposure)), by = .(market, line, year)]
exp_peril <- cl_all[, .(claims = .N, cost = sum(net)), by = .(market, line, peril, year)]
exp_peril <- merge(exp_peril, expo_y, by = c("market", "line", "year"))
exp_peril[, `:=`(frequency = claims / exposure, severity = cost / claims, burn = cost / exposure)]
save_csv(exp_peril[order(line, peril, market, year)], STEP, "experience_peril_year.csv")

exp_peril_nb <- cl_all[year >= 2023, .(claims = .N, cost = sum(net)), by = .(market, line, peril, year, new_business)]
exp_peril_nb <- merge(exp_peril_nb, expo[year >= 2023], by = c("market", "line", "year", "new_business"))
exp_peril_nb[, `:=`(frequency = claims / exposure, severity = cost / claims)]
save_csv(exp_peril_nb[order(line, peril, market, year, new_business)], STEP, "experience_peril_year_nb.csv")

# New business frequency relativity by market, line, year
nb_rel <- dcast(exp_line, market + line + year ~ new_business, value.var = c("frequency", "exposure"))
setnames(nb_rel, c("frequency_FALSE", "frequency_TRUE", "exposure_FALSE", "exposure_TRUE"),
         c("freq_renewal", "freq_nb", "expo_renewal", "expo_nb"))
nb_rel[, nb_freq_ratio := freq_nb / freq_renewal]
save_csv(nb_rel, STEP, "new_business_frequency_ratio.csv")

# 5. Report lags (days) by market x line x peril, 2023-24 loss years for a like-for-like window ---------------
lags <- rbindlist(claims, fill = TRUE)[status != "repudiated" & year(loss_date) %in% 2021:2024 & !is.na(row_id),
  .(claims = .N, median = median(lag), p75 = quantile(lag, 0.75), p90 = quantile(lag, 0.9), p99 = quantile(lag, 0.99),
    share_open = mean(status == "open")), by = .(market, line, peril, loss_years = fifelse(year(loss_date) >= 2023, "2023-24", "2021-22"))]
save_csv(lags[order(line, peril, loss_years, market)], STEP, "report_lags.csv")

# 6. 2025 test portfolio vs training ---------------------------------------------------------------------
mix <- list()
for (l in LINES) {
  tr <- raw$emerging[[paste0("policies_", l)]]; te <- raw$emerging[[paste0("test_", l)]]
  age <- if (l == "motor") "driver_age_band" else "policyholder_age_band"
  vars <- c("new_business", "channel", age, if (l == "motor") "cover_type")
  for (v in vars) {
    a <- rbind(tr[, .(set = paste0("train_", year(period_start)), lvl = as.character(get(v)), nb = new_business,
                      e = as.numeric(period_end - period_start + 1) / DAYS_PER_YEAR)],
               te[, .(set = "test_2025", lvl = as.character(get(v)), nb = new_business,
                      e = as.numeric(period_end - period_start + 1) / DAYS_PER_YEAR)])
    s <- a[, .(exposure = sum(e)), by = .(set, nb_only = nb, lvl)]
    s <- rbind(s[, .(exposure = sum(exposure)), by = .(set, lvl)][, subset := "all"],
               s[nb_only == TRUE, .(exposure = sum(exposure)), by = .(set, lvl)][, subset := "new_business"])
    s[, share := exposure / sum(exposure), by = .(set, subset)]
    mix[[length(mix) + 1]] <- s[, `:=`(line = l, variable = v)]
  }
}
mix <- rbindlist(mix)
save_csv(dcast(mix, line + variable + subset + lvl ~ set, value.var = "share", fill = 0), STEP, "test_mix.csv")
test_size <- mix[variable == "new_business" & subset == "all", .(exposure = sum(exposure)), by = .(line, set)]
test_size <- dcast(test_size, line ~ set, value.var = "exposure")
test_size[, test_vs_2024 := test_2025 / train_2024]
save_csv(test_size, STEP, "test_exposure_vs_training.csv")

# 7. Categorical levels: emerging vs developed (shared columns of policy, customer, address tables) ------------
cat_cmp <- list()
for (t in c(paste0("policies_", LINES), "customers", "addresses")) {
  d <- raw$developed[[t]]; e <- raw$emerging[[t]]
  if (startsWith(t, "policies_")) e <- rbind(e, raw$emerging[[sub("policies_", "test_", t)]], fill = TRUE)
  for (cn in intersect(names(d), names(e))) {
    if (!(is.character(e[[cn]]) || is.logical(e[[cn]])) || grepl("_id$", cn) || cn %in% c("surname", "row_id")) next
    lv_e <- unique(as.character(e[[cn]])); lv_d <- unique(as.character(d[[cn]]))
    only_e <- setdiff(lv_e, lv_d)
    cat_cmp[[length(cat_cmp) + 1]] <- data.table(table = t, column = cn, levels_developed = length(lv_d),
      levels_emerging = length(lv_e), emerging_only_levels = length(only_e),
      emerging_rows_in_new_levels = sum(as.character(e[[cn]]) %in% only_e), rows_emerging = nrow(e),
      examples = paste(head(only_e, 6), collapse = "; "))
  }
}
cat_cmp <- rbindlist(cat_cmp)
save_csv(cat_cmp, STEP, "categorical_levels.csv")

# 8. Emerging numeric address / weather / policy values inside developed ranges ------------------------------------
rng <- list()
num_cmp <- function(t, d, e) {
  for (cn in intersect(names(d), names(e))) {
    if (!is.numeric(e[[cn]]) || cn %in% c("year", "exposure")) next
    dv <- d[[cn]][!is.na(d[[cn]])]; ev <- e[[cn]][!is.na(e[[cn]])]
    q <- quantile(dv, c(0.01, 0.99))
    rng[[length(rng) + 1]] <<- data.table(table = t, column = cn, dev_mean = mean(dv), em_mean = mean(ev),
      dev_p01 = q[[1]], dev_p99 = q[[2]], em_p01 = quantile(ev, 0.01), em_p99 = quantile(ev, 0.99),
      share_em_in_dev_minmax = mean(ev >= min(dv) & ev <= max(dv)),
      share_em_in_dev_p01_p99 = mean(ev >= q[[1]] & ev <= q[[2]]),
      na_share_dev = mean(is.na(d[[cn]])), na_share_em = mean(is.na(e[[cn]])))
  }
}
num_cmp("addresses", raw$developed$addresses, raw$emerging$addresses)
num_cmp("weather", raw$developed$weather, raw$emerging$weather)
num_cmp("customers", raw$developed$customers, raw$emerging$customers)
for (l in LINES) num_cmp(paste0("policies_", l), raw$developed[[paste0("policies_", l)]], raw$emerging[[paste0("policies_", l)]])
rng <- rbindlist(rng)
save_csv(rng, STEP, "numeric_ranges.csv")

# 9. Report --------------------------------------------------------------------------------------------------------
sev_cmp <- exp_peril[year >= 2023, .(claims = sum(claims), cost = sum(cost), exposure = sum(exposure)), by = .(market, line, peril)]
sev_cmp[, `:=`(frequency = claims / exposure, severity = cost / claims, burn = cost / exposure)]
sev_cmp <- dcast(sev_cmp, line + peril ~ market, value.var = c("claims", "frequency", "severity", "burn"))
save_csv(sev_cmp, STEP, "peril_2023_24_market_comparison.csv")

motor_nb <- nb_rel[line == "motor", .(market, year, freq_renewal, freq_nb, nb_freq_ratio, expo_nb)]
key_lines <- c(
  sprintf("- Emerging claims %s (handover 9,258); unmatched %d, of which loss date before 2023: %d.",
          format(nrow(raw$emerging$claims), big.mark = ","), traps[market == "emerging" & check == "claims matching no policy row", n],
          traps[market == "emerging" & check == "unmatched with loss_date before 2023", n]),
  sprintf("- Emerging exposure fixes: %s.", paste(traps[market == "emerging" & check == "exposure inconsistent with dates",
                                                     paste0(table, " ", n)], collapse = ", ")),
  sprintf("- Test exposure vs 2024: %s.", paste(sprintf("%s %.2fx", test_size$line, test_size$test_vs_2024), collapse = ", ")),
  sprintf("- Test new-business share of exposure: %s.", paste(mix[variable == "new_business" & subset == "all" & set == "test_2025" & lvl == "TRUE",
                                                                 sprintf("%s %.1f%%", line, 100 * share)], collapse = ", "))
)

write_md(list(
  "# Step 1: profile of the developed and emerging markets", "",
  paste("Generated", ts_sgt(), "by `week2/R/01_profile_emerging.R`. All counts from the raw files, before cleaning."), "",
  "## Headline numbers", "", key_lines, "",
  "## Row counts", "", md_table(counts),
  "## Column differences (shared tables)", "", md_table(coldiff),
  "## Key integrity", "", md_table(keys[n > 0 | market == "emerging"]),
  "## Data traps", "", md_table(traps),
  "## customer_service_contacts (leakage re-check)", "",
  "Mean contacts per row on training rows with at least one non-repudiated claim, without, and in the 2025 test file.", "",
  md_table(csc, 2),
  "## Experience 2023-24 by peril, developed vs emerging (net incurred, repudiated excluded, uncapped, reported at 31 Dec 2024)", "",
  md_table(sev_cmp, 4),
  "## New-business frequency vs renewals (all perils)", "", md_table(nb_rel, 4),
  "## Report lags (days, non-repudiated matched claims)", "", md_table(lags[order(line, peril, loss_years, market)], 1),
  "## 2025 test file vs training", "", md_table(test_size, 2),
  md_table(dcast(mix[variable != "new_business"], line + variable + subset + lvl ~ set, value.var = "share", fill = 0), 3),
  "## Categorical levels: emerging vs developed", "", md_table(cat_cmp),
  "## Numeric ranges: emerging inside developed?", "", md_table(rng, 3),
  "Files: every table above is also a CSV in this folder."
), STEP, "profile_report.md")

update_step_log("1", "Profile both markets", key_lines)
end_script()
