# ben/ben_clean.R ------------------------------------------------------------
# BEN's own cleaning and feature steps, on top of week1/R/2_clean.R (run after it and after week1/R/3_incidence.R).
# Reads data/week_1/clean/ and writes copies with the changes below to data/week_1/ben/; reports go to week1/output/ben/.
# Shared files (data/week_1/clean/, week1/R/0_setup.R, week1/R/2_clean.R) are not changed, so other iterations are unaffected.
#   1. Data types: every feature's type matches its meaning for tree models (settings in week1/R/ben/ben_helpers.R)
#      - ordered text -> integers in natural order: credit_band, energy_rating, urban_density, security_level,
#        cover_type ("missing" -> NA)
#      - labels stored as numbers -> text, treated as categories: branch_id, start_month
#   2. Claims history known when the row starts: non-repudiated claims with a loss in the 365 days before the row
#      starts AND reported before it starts
#      - hist_policy_claims, hist_policy_cost: the same policy
#      - hist_customer_other_claims: the same customer's policies in the other two lines
#      - hist_address_property_claims: buildings and contents claims at the same address, other policies
#      2021 rows -> NA (the data has no claims history before 2021)
#   3. IBNR by peril on cost: report-lag factors weighted by claim cost (capped at p99.9 per peril), next to the
#      count-based factors of week1/R/3_incidence.R; late-reported claims are larger, so cost factors are higher
# Run:     Rscript week1/R/ben/ben_clean.R
# Outputs: data/week_1/ben/{train,test}_<line>.parquet, week1/output/ben/ (ben_clean_report.md, feature_types.csv,
#          history_summary.csv, ibnr_cost_by_peril.csv)

source("week1/R/0_setup.R")
source("week1/R/ben/ben_helpers.R")

key_cols <- c("row_id", "policy_id", "customer_id", "address_id", "period_start", "policy_year")
read_keys <- function(name, ln) {
  as.data.table(read_parquet(file.path(PATHS$clean, paste0(name, ".parquet")), col_select = tidyselect::all_of(key_cols)))[, line := ln]
}

# 1. Data types -------------------------------------------------------------------------------------------
recode_types <- function(dt) {
  for (f in intersect(names(BEN_ORDINAL), names(dt))) {
    unknown <- setdiff(unique(dt[[f]]), c(BEN_ORDINAL[[f]], "missing", NA))
    if (length(unknown)) stop(f, ": values without an order: ", paste(unknown, collapse = ", "))
    set(dt, j = f, value = match(dt[[f]], BEN_ORDINAL[[f]]))
  }
  for (f in intersect(BEN_AS_CATEGORY, names(dt))) set(dt, j = f, value = as.character(dt[[f]]))
  dt
}

# 2. Claims history ----------------------------------------------------------------------------------------
rows <- rbindlist(lapply(LINES, function(ln) rbind(read_keys(paste0("train_", ln), ln), read_keys(paste0("test_", ln), ln))))
cl <- read_clean("claims_matched")[counts == TRUE, .(claim_id, policy_id, line, peril, loss_date, report_date, net_cost, row_id)]
cl[, customer_id := rows$customer_id[match(policy_id, rows$policy_id)]]
cl[, address_id := rows$address_id[match(row_id, rows$row_id)]]     # address of the row the claim belongs to

# Claims on `key` with loss_date in [start - 365, start) and report_date < start, per row; `keep` filters the pairs
history <- function(key, claims, keep = NULL) {
  r <- rows[, .(row_id, k = get(key), r_line = line, r_policy = policy_id, start = period_start,
                from = period_start - BEN_HISTORY_DAYS)]
  cc <- claims[!is.na(get(key)), .(k = get(key), c_line = line, c_policy = policy_id, loss_date, report_date, net_cost)]
  j <- cc[r, on = .(k, loss_date >= from, loss_date < start), nomatch = NULL,
         .(row_id = i.row_id, r_line = i.r_line, r_policy = i.r_policy, start = i.start,
           c_line = x.c_line, c_policy = x.c_policy, report_date = x.report_date, net_cost = x.net_cost)]
  j <- j[report_date < start]
  if (!is.null(keep)) j <- j[eval(keep)]
  j[, .(n = .N, cost = sum(net_cost)), by = row_id]
}
h_policy <- history("policy_id", cl)
h_customer <- history("customer_id", cl, quote(c_line != r_line))
h_address <- history("address_id", cl[line %in% c("buildings", "contents")], quote(c_policy != r_policy))

hist_tab <- rows[, .(row_id, policy_year)]
hist_tab[, `:=`(hist_policy_claims = h_policy$n[match(row_id, h_policy$row_id)],
                hist_policy_cost = h_policy$cost[match(row_id, h_policy$row_id)],
                hist_customer_other_claims = h_customer$n[match(row_id, h_customer$row_id)],
                hist_address_property_claims = h_address$n[match(row_id, h_address$row_id)])]
for (f in BEN_HISTORY) {
  set(hist_tab, i = which(is.na(hist_tab[[f]])), j = f, value = 0)
  set(hist_tab, i = which(hist_tab$policy_year == 2021), j = f, value = NA)   # no history visible before 2021
}
rm(h_policy, h_customer, h_address); gc(verbose = FALSE)

# 3. IBNR by peril on cost ------------------------------------------------------------------------------
# Weighted ECDF of the report lag: share of (count or capped cost) reported within d days
weighted_ecdf <- function(lag, w) {
  s <- data.table(lag, w)[, .(w = sum(w)), keyby = lag][, cw := cumsum(w) / sum(w)]
  function(d) { i <- findInterval(d, s$lag); fifelse(i == 0, 0, s$cw[pmax(i, 1)]) }
}
lagged <- cl[!is.na(row_id)][, `:=`(lag = as.numeric(report_date - loss_date), loss_year = year(loss_date))]
ibnr_cost <- rbindlist(lapply(LINES, function(ln) rbindlist(lapply(PERILS[[ln]], function(pr) {
  ref <- lagged[line == ln & peril == pr & loss_year %in% 2021:2022]
  cap <- quantile(ref$net_cost[ref$net_cost > 0], LARGE_LOSS_QUANTILE, names = FALSE)
  F_count <- weighted_ecdf(ref$lag, rep(1, nrow(ref)))
  F_cost <- weighted_ecdf(ref$lag, pmin(ref$net_cost, cap))
  rbindlist(lapply(TRAIN_YEARS, function(y) {
    days <- as.numeric(VALUATION_DATE - seq(as.Date(paste0(y, "-01-01")), as.Date(paste0(y, "-12-31")), by = "day"))
    sc <- mean(F_count(days)); sk <- mean(F_cost(days))
    data.table(line = ln, peril = pr, policy_year = y, claims_2021_22 = nrow(ref), reported_share_count = sc,
               reported_share_cost = sk, ibnr_count = 1 / sc, ibnr_factor = 1 / sk)
  }))
}))))
fwrite(ibnr_cost, ben_out("ibnr_cost_by_peril.csv"))
log_msg("IBNR on cost: ", ibnr_cost[policy_year == 2024, paste(sprintf("%s/%s %.3f", line, peril, ibnr_factor), collapse = "; ")])

# 4. Write data/week_1/ben/ ------------------------------------------------------------------------------------
dir.create(BEN_PATHS$data, recursive = TRUE, showWarnings = FALSE)
types <- list(); hist_summary <- list()
for (ln in LINES) for (set_name in c("train", "test")) {
  name <- paste0(set_name, "_", ln)
  dt <- read_clean(name)
  before <- vapply(dt, function(x) class(x)[1], character(1))
  dt <- recode_types(dt)
  h <- hist_tab[match(dt$row_id, hist_tab$row_id), ..BEN_HISTORY]
  dt[, (BEN_HISTORY) := h]
  write_parquet(dt, file.path(BEN_PATHS$data, paste0(name, ".parquet")))
  if (set_name == "train") {
    changed <- c(intersect(names(BEN_ORDINAL), names(dt)), intersect(BEN_AS_CATEGORY, names(dt)))
    types[[ln]] <- data.table(line = ln, feature = changed, type_before = before[changed],
                              type_after = vapply(dt[, ..changed], function(x) class(x)[1], character(1)),
                              encoding = ifelse(changed %in% names(BEN_ORDINAL),
                                                vapply(changed, function(f) paste(BEN_ORDINAL[[f]], collapse = " < "), ""),
                                                "category (levels ordered by credibility-weighted cost rate in the model)"),
                              pct_na_after = vapply(changed, function(f) 100 * mean(is.na(dt[[f]])), numeric(1)))
  }
  hist_summary[[name]] <- rbindlist(lapply(BEN_HISTORY, function(f) {
    dt[, .(set = set_name, line = ln, feature = f, rows = .N, pct_na = 100 * mean(is.na(get(f))),
           mean = mean(get(f), na.rm = TRUE), pct_positive = 100 * mean(get(f) > 0, na.rm = TRUE)), by = policy_year]
  }))
  log_msg(name, ": ", nrow(dt), " rows written to ", BEN_PATHS$data)
  rm(dt); gc(verbose = FALSE)
}
types <- rbindlist(types); hist_summary <- rbindlist(hist_summary)
fwrite(types, ben_out("feature_types.csv"))
fwrite(hist_summary, ben_out("history_summary.csv"))

# Claims history vs claims in the row (train): does a claim last year signal more claims this year?
signal <- rbindlist(lapply(LINES, function(ln) {
  dt <- read_ben(paste0("train_", ln))[policy_year > 2021]
  rbindlist(lapply(BEN_HISTORY[BEN_HISTORY != "hist_policy_cost"], function(f) {
    dt[, .(exposure = sum(exposure), frequency = sum(y_n_claims) / sum(exposure)), keyby = .(level = pmin(get(f), 2))][
      , `:=`(line = ln, feature = f, level = ifelse(level == 2, "2+", as.character(level)))]
  }))
}))
fwrite(signal, ben_out("history_signal.csv"))

write_md(list(
  "# BEN cleaning and features", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/ben/ben_clean.R`. Reads `data/week_1/clean/`, writes `data/week_1/ben/`;",
        "shared tables and scripts are unchanged."), "",
  "## 1. Data types", "",
  "XGBoost splits numbers on less-than / greater-than, so a number must carry an order. Ordered text is mapped to its",
  "natural order (\"missing\" -> NA, routed by the model); labels stored as numbers become categories.", "",
  md_table(types, 2),
  "## 2. Claims history known when the row starts", "",
  paste0("Non-repudiated claims with a loss in the ", BEN_HISTORY_DAYS, " days before the row starts and reported before it starts.",
         " 2021 rows are NA: the data has no claims before 2021."), "",
  md_table(hist_summary[set == "train" & policy_year == 2024 | set == "test", .(set, line, feature, policy_year, pct_na, mean, pct_positive)], 3),
  "Claim frequency of the row by its history (2022-24 train rows):", "",
  md_table(signal[, .(line, feature, level, exposure, frequency)], 4),
  "## 3. IBNR by peril on cost", "",
  "Report-lag factors from 2021-22 losses; the cost factor weights each claim by its cost (capped at p99.9 per peril).", "",
  md_table(ibnr_cost[policy_year >= 2023, .(line, peril, policy_year, claims_2021_22, ibnr_count, ibnr_factor)], 4)
), "ben", "ben_clean_report.md")

log_msg("Done. Report: ", ben_out("ben_clean_report.md"))
