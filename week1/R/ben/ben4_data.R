# ben/ben4_data.R ------------------------------------------------------------
# BEN 4 data step: point-in-time features and developed, capped per-peril targets for week1/R/4_models_iterben04.R.
# Reads data/week_1/raw data/ (renewal_decision only), data/week_1/clean/ and data/week_1/ben/ (type fixes); writes data/week_1/ben4/ and week1/output/ben/ben4/.
# Nothing shared is changed. Every feature uses only what is known on 1 January of the row's policy year, or what the
# test file itself shows about the row (its dates), so train and test are built the same way.
#   A. Claims history at 1 January (replaces the 365-day window of data/week_1/ben/, which looked shorter for test rows that
#      start after January): the policy's claims in the previous calendar year and the one before, its claim rate over
#      all earlier years, peril of the last claim, years since it, repudiated claims; the customer's claims in its other
#      lines; property claims at the same address on other policies
#   B. Previous row of the same policy: its renewal outcome, service contacts, exposure, and what changed since
#      (premium position, voluntary excess, vehicle, address, sum insured); earlier declines by the insurer
#   C. Row shape in its own year, as given in the train and test files: the row ends in a mid-term change (another
#      row of the policy starts later the same year), follows one, or ends early with no next row (cancelled or lapsed)
#   D. Customer holdings in the same policy year
#   E. Targets: claim-level cap per peril (p99.9 of 2021-23 claims), loading = cost limited to 2m / capped cost,
#      chain-ladder share of ultimate reported by 31 Dec 2024 per row and peril (week1/R/ben/ben_helpers.R dev_shares/row_share)
# Run:     Rscript week1/R/ben/ben4_data.R  (after week1/R/2_clean.R and week1/R/ben/ben_clean.R)
# Outputs: data/week_1/ben4/{train,test}_<line>.parquet; week1/output/ben/ben4/ben4_data_report.md, caps.csv, signal.csv

source("week1/R/0_setup.R")
source("week1/R/ben/ben_helpers.R")
OUT <- "ben4"
B4_DATA <- file.path("data", "week_1", "ben4")
dir.create(B4_DATA, recursive = TRUE, showWarnings = FALSE)
CAP_Q <- 0.999            # claim-level cap per peril
LIMIT <- 2e6              # single-claim limit for the loading (one 11.9m bodily injury claim otherwise sets motor's level)

# Rows of all lines, train and test ---------------------------------------------------------------------------
rd <- rbindlist(lapply(LINES, function(ln) {
  as.data.table(read_parquet(file.path(PATHS$raw, paste0("policies_", ln, ".parquet")), col_select = c("row_id", "renewal_decision")))
}))
key_cols <- c("row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end", "policy_year", "exposure",
              "premium_index", "voluntary_excess", "customer_service_contacts", "make_model", "sum_insured")
rows <- rbindlist(lapply(LINES, function(ln) {
  get <- function(set) { d <- read_ben(paste0(set, "_", ln)); d[, intersect(key_cols, names(d)), with = FALSE][, set := set] }
  rbind(get("train"), get("test"), fill = TRUE)[, line := ln]
}), fill = TRUE)
rows <- merge(rows, rd, by = "row_id", all.x = TRUE)
setorder(rows, line, policy_id, period_start)

# B. Previous row and C. row shape ----------------------------------------------------------------------------
rows[, `:=`(prev_decision = shift(renewal_decision), prev_contacts = shift(customer_service_contacts),
            prev_exposure = shift(exposure), prev_premium_index = shift(premium_index), prev_excess = shift(voluntary_excess),
            prev_make_model = shift(make_model), prev_address = shift(address_id), prev_si = shift(sum_insured),
            prev_year = shift(policy_year), next_year = shift(policy_year, -1)), by = .(line, policy_id)]
rows[, `:=`(
  b4_prev_decision = fifelse(is.na(prev_decision), "none", prev_decision),
  b4_prev_contacts = prev_contacts,
  b4_prev_exposure = prev_exposure,
  b4_premium_move = premium_index / prev_premium_index,
  b4_excess_change = voluntary_excess - prev_excess,
  b4_vehicle_changed = fifelse(line != "motor" | is.na(prev_make_model), NA_integer_, as.integer(make_model != prev_make_model)),
  b4_moved = fifelse(is.na(prev_address), NA_integer_, as.integer(address_id != prev_address)),
  b4_si_ratio = fifelse(line == "motor" | is.na(prev_si), NA_real_, sum_insured / prev_si),
  b4_after_change = as.integer(!is.na(prev_year) & prev_year == policy_year),
  b4_ends_in_change = as.integer(!is.na(next_year) & next_year == policy_year),
  b4_ends_early = as.integer((is.na(next_year) | next_year != policy_year) &
                               period_end < as.Date(paste0(policy_year, "-12-30"))))]
rows[, b4_rows_in_year := .N, by = .(line, policy_id, policy_year)]
# earlier declines of the same policy (rows of earlier policy years only, so the decision was known by 1 January)
dec <- unique(rows[renewal_decision == "declined_by_insurer", .(line, policy_id, py = policy_year)])
pol_years <- unique(rows[, .(line, policy_id, policy_year)])
dj <- dec[pol_years, on = .(line, policy_id, py < policy_year), nomatch = NULL, .(n = .N), by = .EACHI]
setnames(dj, "py", "policy_year")
rows <- merge(rows, dj, by = c("line", "policy_id", "policy_year"), all.x = TRUE)
rows[, b4_prior_declines := fcoalesce(n, 0L)][, n := NULL]
# service contacts per exposure-year over all earlier policy years (tracks claims and complaints)
ctc <- rows[!is.na(customer_service_contacts), .(c = sum(customer_service_contacts), e = sum(exposure)), by = .(line, policy_id, py = policy_year)]
cj <- ctc[pol_years, on = .(line, policy_id, py < policy_year), nomatch = NULL, .(c = sum(c), e = sum(e)), by = .EACHI]
setnames(cj, "py", "policy_year")
rows <- merge(rows, cj, by = c("line", "policy_id", "policy_year"), all.x = TRUE)
rows[, `:=`(b4_prior_contacts_rate = c / e, b4_prior_exposure = fcoalesce(e, 0))][, c("c", "e") := NULL]

# D. Holdings ---------------------------------------------------------------------------------------------------
rows[, b4_n_lines := uniqueN(line), by = .(customer_id, policy_year)]
rows[, b4_policies_in_line := uniqueN(policy_id), by = .(customer_id, policy_year, line)]

# A. Claims history at 1 January ------------------------------------------------------------------------------
cl <- read_clean("claims_matched")[counts == TRUE]
cl[, customer_id := rows$customer_id[match(policy_id, rows$policy_id)]]
cl[, address_id := rows$address_id[match(row_id, rows$row_id)]]
caps <- cl[status != "repudiated" & year(loss_date) %in% 2021:2023,
           .(cap = quantile(net_cost[net_cost > 0], CAP_Q, names = FALSE)), by = .(line, peril)]
cl <- merge(cl, caps, by = c("line", "peril"), all.x = TRUE)
cl[, `:=`(cost_cap = cap, capped = pmin(net_cost, cap))]
paid <- cl[status != "repudiated"]
ny <- rows[, .(customer_id = customer_id[1], address_id = address_id[1]), by = .(line, policy_id, policy_year)]

# claims seen at 1 January of each policy year, by key
seen_at <- function(claims, years = 2022:2025) rbindlist(lapply(years, function(y) {
  cut_date <- as.Date(paste0(y, "-01-01"))
  claims[report_date < cut_date & loss_date < cut_date][, policy_year := y]
}))
ps <- seen_at(paid)
pol <- ps[, .(b4_n_prev1 = sum(year(loss_date) == policy_year - 1), b4_n_prev2 = sum(year(loss_date) == policy_year - 2),
              b4_n_all = .N, b4_cost_all = sum(capped), b4_last_peril = peril[which.max(loss_date)],
              b4_years_since = policy_year[1] - year(max(loss_date))), by = .(line, policy_id, policy_year)]
per_peril <- dcast(ps[, .N, by = .(line, policy_id, policy_year, peril)], line + policy_id + policy_year ~ paste0("b4_n_", peril),
                   value.var = "N", fill = 0)
rep <- seen_at(cl[status == "repudiated"])[, .(b4_n_repudiated = .N), by = .(line, policy_id, policy_year)]
# the customer's claims in its other lines, and property claims at the address on other policies
cus <- ny[, .(line, customer_id, policy_year)] |> unique()
cc <- ps[, .(c_line = line, customer_id, policy_year, prev1 = year(loss_date) == policy_year - 1)]
cus <- cc[cus, on = .(customer_id, policy_year), nomatch = NULL, allow.cartesian = TRUE][c_line != line,
          .(b4_cust_other_all = .N, b4_cust_other_prev1 = sum(prev1)), by = .(line, customer_id, policy_year)]
adr <- ps[line %in% c("buildings", "contents"), .(address_id, c_policy = policy_id, policy_year)]
adr <- adr[ny, on = .(address_id, policy_year), nomatch = NULL, allow.cartesian = TRUE][c_policy != policy_id,
          .(b4_addr_other_all = .N), by = .(line, policy_id, policy_year)]

hist <- Reduce(function(a, b) merge(a, b, by = intersect(names(a), names(b)), all.x = TRUE),
               list(ny, pol, per_peril, rep), accumulate = FALSE)
hist <- merge(hist, cus, by = c("line", "customer_id", "policy_year"), all.x = TRUE)
hist <- merge(hist, adr, by = c("line", "policy_id", "policy_year"), all.x = TRUE)
cnt <- setdiff(grep("^b4_(n_|cust_|addr_)", names(hist), value = TRUE), character(0))
for (f in c(cnt, "b4_cost_all")) set(hist, which(is.na(hist[[f]])), f, 0)
hist[is.na(b4_last_peril), b4_last_peril := "none"]
hist[is.na(b4_years_since), b4_years_since := 9]
# 2021 rows see no history; the year before 2022 is not observed either (claims start in 2021)
hist[policy_year == 2021, (c(cnt, "b4_cost_all", "b4_years_since")) := NA]
hist[policy_year == 2021, b4_last_peril := NA]
hist[policy_year == 2022, b4_n_prev2 := NA]
rows <- merge(rows, hist[, !c("customer_id", "address_id")], by = c("line", "policy_id", "policy_year"), all.x = TRUE)
# claim rate over all earlier years (rows of the same policy), the credibility input; exposure-weighted
rows[, b4_rate_all := fifelse(b4_prior_exposure > 0, b4_n_all / b4_prior_exposure, NA_real_)]

# E. Targets ----------------------------------------------------------------------------------------------------
row_cap <- dcast(paid[!is.na(row_id), .(capped = sum(capped), lim = sum(pmin(net_cost, LIMIT))), by = .(row_id, peril)],
                 row_id ~ peril, value.var = c("capped", "lim"), fill = 0)
loading <- paid[year(loss_date) %in% 2021:2024, .(cap = cost_cap[1], claims = .N, capped = sum(capped),
                                                     limited = sum(pmin(net_cost, LIMIT)), total = sum(net_cost)), by = .(line, peril)]
loading[, loading := limited / capped]
sh <- dev_shares(paid[, .(line, peril, loss_date, report_date, net_cost, cost_cap)], VALUATION_DATE)
tr_rows <- rows[set == "train", .(row_id, line, policy_year, period_start, period_end)]
shares <- row_share(tr_rows, sh, VALUATION_DATE, "row")
shares <- dcast(shares, row_id ~ peril, value.var = c("share_n", "share_w"))

B4_FEATURES <- c(grep("^b4_", names(rows), value = TRUE))
signal <- list()
for (ln in LINES) for (set_name in c("train", "test")) {
  name <- paste0(set_name, "_", ln)
  dt <- read_ben(name)
  dt[, (BEN_HISTORY) := NULL]                                  # 365-day window replaced by the 1 January cut-off
  add <- rows[line == ln & set == set_name, c("row_id", B4_FEATURES), with = FALSE]
  add <- add[, which(vapply(add, function(x) !all(is.na(x)), logical(1))), with = FALSE]   # e.g. vehicle fields in property
  dt <- merge(dt, add, by = "row_id", all.x = TRUE, sort = FALSE)
  if (set_name == "train") {
    pc <- row_cap[match(dt$row_id, row_cap$row_id)]
    s <- shares[match(dt$row_id, shares$row_id)]
    for (p in PERILS[[ln]]) {
      cap_col <- paste0("capped_", p); lim_col <- paste0("lim_", p)
      set(dt, j = paste0("y_cap_", p), value = fcoalesce(if (cap_col %in% names(pc)) pc[[cap_col]] else NA_real_, 0))
      set(dt, j = paste0("y_lim_", p), value = fcoalesce(if (lim_col %in% names(pc)) pc[[lim_col]] else NA_real_, 0))
      set(dt, j = paste0("dev_n_", p), value = pmin(1 / fcoalesce(s[[paste0("share_n_", p)]], 1), 20))
      set(dt, j = paste0("dev_w_", p), value = pmin(1 / fcoalesce(s[[paste0("share_w_", p)]], 1), 20))
    }
    sig <- rbindlist(lapply(c("b4_n_prev1", "b4_n_all", "b4_prior_declines", "b4_prev_contacts", "b4_ends_in_change", "b4_after_change",
                              "b4_ends_early", "b4_cust_other_all", "b4_addr_other_all", "b4_last_peril", "b4_prev_decision"), function(f) {
      if (!f %in% names(dt)) return(NULL)
      d <- dt[policy_year >= 2022]
      base <- d[, sum(y_cost) / sum(exposure)]
      d[, .(exposure = sum(exposure), burn = sum(y_cost) / sum(exposure), freq = sum(y_n_claims) / sum(exposure)),
        by = .(level = as.character(if (is.numeric(get(f))) pmin(round(get(f)), 3) else get(f)))][
        , `:=`(line = ln, feature = f, burn_rel = burn / base)][order(level)]
    }))
    signal[[ln]] <- sig
  }
  write_parquet(dt, file.path(B4_DATA, paste0(name, ".parquet")))
  log_msg(name, ": ", nrow(dt), " rows, ", ncol(dt), " columns")
  rm(dt); gc(verbose = FALSE)
}
signal <- rbindlist(signal)
fwrite(caps, ben_out(file.path(OUT, "caps.csv"))); fwrite(loading, ben_out(file.path(OUT, "loading.csv")))
fwrite(signal, ben_out(file.path(OUT, "signal.csv")))
write_md(list(
  "# BEN 4 data step", "", paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/ben/ben4_data.R`."), "",
  "## Claim caps and loading (2021-24 claims; loading = cost limited to 2m / capped cost)", md_table(loading, 3),
  "## One-way signal of the new features (train 2022-24; burn = reported cost per exposure-year)",
  md_table(signal[exposure > 500, .(line, feature, level, exposure, freq, burn, burn_rel)], 3)
), file.path("ben", OUT), "ben4_data_report.md")
log_msg("Done: ", B4_DATA)
