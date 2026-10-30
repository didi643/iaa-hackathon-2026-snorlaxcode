# 1_checks_w2.R --------------------------------------------------------------------------------------------------
# Week 2 step 1: read-only checks of the raw data (nothing is changed here; fixes are in 2_clean_w2.R).
#   A. Inventory and schema: files, rows, columns only in one market
#   B. Integrity of the emerging tables: keys, joins, dates, exposure, sum insured, impossible values, missing values,
#      text variants in categorical columns, test levels never seen in training
#   C. Emerging claims: duplicates, amounts, dates, claims outside the market's policy years, match to policy rows
#   D. What has changed vs the developed market (Part 1): shared columns, category mix, experience by peril,
#      reporting lags, excess, weather, expense assumptions
#   E. 2025 test portfolio vs 2023-24 training (the broker portfolio is mostly new business)
# Run:  Rscript week2/R/1_checks_w2.R      Out: week2/output/1_checks/ (checks_report.md + CSVs)

source("week2/R/0_setup_w2.R")
STEP <- "1_checks"
reg <- new_checks()

files <- sub("\\.parquet$", "", list.files(PATHS_W2$raw_e, pattern = "\\.parquet$"))
E <- setNames(lapply(files, read_e), files)
D <- setNames(lapply(c("customers", "addresses", "weather", "claims", paste0("policies_", LINES), paste0("test_", LINES)), read_d),
              c("customers", "addresses", "weather", "claims", paste0("policies_", LINES), paste0("test_", LINES)))

# A. Inventory and schema ------------------------------------------------------------------------------------------
inventory <- rbindlist(lapply(files, function(f) data.table(
  file = f, rows_emerging = nrow(E[[f]]), cols_emerging = ncol(E[[f]]),
  rows_developed = if (!is.null(D[[f]])) nrow(D[[f]]) else NA_integer_,
  only_emerging = if (!is.null(D[[f]])) paste(setdiff(names(E[[f]]), names(D[[f]])), collapse = ", ") else "(emerging only)",
  only_developed = if (!is.null(D[[f]])) paste(setdiff(names(D[[f]]), names(E[[f]])), collapse = ", ") else "")))
dev_same <- vapply(list.files(PATHS_W2$raw_d), function(f)
  unname(tools::md5sum(file.path(PATHS_W2$raw_d, f)) == tools::md5sum(file.path(PATHS_W2$week1, f))), logical(1))
add_check(reg, "developed", "files byte-identical to data/week_1 (Part 1 data)", sum(dev_same), length(dev_same),
          "week 1 cleaning and models apply to the developed market unchanged")

# B. Integrity of the emerging tables ------------------------------------------------------------------------------
cu <- E$customers; ad <- E$addresses; wx <- E$weather; cl <- E$claims
add_check(reg, "customers", "duplicate customer_id", sum(duplicated(cu$customer_id)), nrow(cu), "none expected")
add_check(reg, "customers", "customer_id not 8 characters", sum(nchar(cu$customer_id) != 8), nrow(cu), "none expected")
add_check(reg, "addresses", "duplicate address_id", sum(duplicated(ad$address_id)), nrow(ad), "none expected")
add_check(reg, "addresses", "region outside E01-E06", sum(!ad$region %in% sprintf("E%02d", 1:6)), nrow(ad), "none expected")
add_check(reg, "weather", "duplicate address_id x year", sum(duplicated(wx, by = c("address_id", "year"))), nrow(wx), "none expected")
add_check(reg, "weather", "years present", uniqueN(wx$year), NA, paste(sort(unique(wx$year)), collapse = ", "))
add_check(reg, "weather", "addresses without weather in every year", sum(wx[, .N, by = address_id]$N < uniqueN(wx$year)), nrow(ad), "none expected")
occ <- clean_occupation(cu$occupation)
add_check(reg, "customers", "occupation: distinct raw spellings", uniqueN(na.omit(cu$occupation)), NA,
          paste0("free text; ", uniqueN(na.omit(occ$occupation)), " occupations after lower-case / trim / 'self-employed' split"), "issue")
add_check(reg, "customers", "occupation entered as 'self-employed <job>'", sum(occ$self_employed), nrow(cu),
          "split into occupation + self_employed flag", "issue")
add_check(reg, "customers", "customer_since_year = 2025 (joined with the broker portfolio)", sum(cu$customer_since_year == 2025), nrow(cu), "information")
add_check(reg, "customers", "same customer_id also used in the developed market", sum(cu$customer_id %in% D$customers$customer_id), nrow(cu),
          "unrelated records (data notes): never join across markets", "info")
add_check(reg, "addresses", "same address_id also used in the developed market", sum(ad$address_id %in% D$addresses$address_id), nrow(ad),
          "unrelated records (data notes): never join across markets", "info")

pol_files <- c(paste0("policies_", LINES), paste0("test_", LINES))
for (f in pol_files) {
  x <- E[[f]]; n <- nrow(x); ln <- sub(".*_", "", f); days <- row_days(x)
  ex365 <- round(days / 365, 4)
  bad_exp <- abs(x$exposure - ex365) > 1e-6
  add_check(reg, f, "duplicate row_id", sum(duplicated(x$row_id)), n, "none expected")
  add_check(reg, f, "customer_id not in customers", sum(!x$customer_id %in% cu$customer_id), n, "none expected")
  add_check(reg, f, "address_id not in addresses", sum(!x$address_id %in% ad$address_id), n, "none expected")
  add_check(reg, f, "period_end before period_start", sum(x$period_end < x$period_start), n, "none expected")
  add_check(reg, f, "row longer than 366 days", sum(days > 366), n, "none expected")
  add_check(reg, f, "exposure inconsistent with period dates", sum(bad_exp), n, "recompute as days / 365 (2_clean_w2.R)",
            if (sum(bad_exp)) "issue" else "info")
  add_check(reg, f, "  of which exposure = days (not years)", sum(bad_exp & abs(x$exposure - days) < 1e-6), n, "")
  add_check(reg, f, "  of which exposure = days / 360", sum(bad_exp & abs(x$exposure - round(days / 360, 4)) < 1e-6), n, "")
  yrs <- if (startsWith(f, "test")) 2025 else TRAIN_YEARS_E
  add_check(reg, f, "period_start outside the file's years", sum(!year(x$period_start) %in% yrs), n, paste("expected", paste(yrs, collapse = "-")))
  setorder(x, policy_id, period_start)
  add_check(reg, f, "overlapping rows within a policy", sum(x$period_start <= shift(x$period_end) & x$policy_id == shift(x$policy_id), na.rm = TRUE), n, "none expected")
  if ("sum_insured" %in% names(x)) {
    big <- x$sum_insured > SI_CAP[[ln]]
    add_check(reg, f, sprintf("sum_insured > %s (all divisible by 1000: %s)", format(SI_CAP[[ln]], big.mark = ",", scientific = FALSE),
                              all(x$sum_insured[big] %% 1000 == 0)), sum(big), n, "divide by 1000 (unit error, week 1 rule)", if (any(big)) "issue" else "info")
  }
  if ("construction_type" %in% names(x))
    add_check(reg, f, "construction_type not a known local code (BRK/STN/WOD/MIX)", sum(!x$construction_type %in% names(CONSTRUCTION_MAP)), n,
              "map BRK/STN/WOD/MIX to brick/stone/timber/non_standard")
  band <- intersect(c("driver_age_band", "policyholder_age_band"), names(x))
  if (length(band)) add_check(reg, f, paste(band, "outside the 5 documented bands"), sum(!x[[band]] %in% AGE_BANDS), n, "none expected")
  if ("years_licensed" %in% names(x)) {
    hi <- c("17-24" = 24, "25-34" = 34, "35-49" = 49, "50-64" = 64, "65+" = 110)[x$driver_age_band]
    add_check(reg, f, "years_licensed > top of driver_age_band - 17", sum(x$years_licensed > hi - 17, na.rm = TRUE), n, "none expected")
    add_check(reg, f, "ncb_years > years_licensed", sum(x$ncb_years > x$years_licensed, na.rm = TRUE), n, "information")
  }
  add_check(reg, f, "new_business inconsistent with renewal_count", sum(x$new_business != (x$renewal_count == 0)), n, "none expected")
  add_check(reg, f, "new_business rows", sum(x$new_business), n, "information")
  add_check(reg, f, "compulsory_excess values", uniqueN(x$compulsory_excess), NA, paste(sort(unique(x$compulsory_excess)), collapse = ", "))
}

# missing values: emerging vs developed, shared columns
miss <- rbindlist(lapply(c("customers", "addresses", pol_files), function(f) {
  x <- E[[f]]; d <- D[[f]]
  rbindlist(lapply(names(x), function(cn) data.table(file = f, column = cn, na_emerging = mean(is.na(x[[cn]])),
                                                     na_developed = if (!is.null(d) && cn %in% names(d)) mean(is.na(d[[cn]])) else NA_real_)))
}))[na_emerging > 0 | na_developed > 0]
miss[, change := na_emerging - na_developed]

# text variants: categorical values that differ only by case / spaces, and test levels unseen in training
variants <- rbindlist(lapply(c("customers", "addresses", pol_files), function(f) {
  x <- E[[f]]; cols <- names(x)[vapply(x, is.character, logical(1)) & !grepl("_id$|^surname$", names(x))]
  rbindlist(lapply(cols, function(cn) { v <- na.omit(unique(x[[cn]])); k <- tolower(gsub("\\s+", " ", trimws(v)))
    data.table(file = f, column = cn, distinct = length(v), distinct_normalised = uniqueN(k)) }))
}))[distinct != distinct_normalised]
unseen <- rbindlist(lapply(LINES, function(ln) {
  tr <- E[[paste0("policies_", ln)]]; te <- E[[paste0("test_", ln)]]
  cols <- intersect(names(te)[vapply(te, function(v) is.character(v) || is.logical(v), logical(1))], names(tr))
  cols <- setdiff(cols, c("row_id", "policy_id", "customer_id", "address_id"))
  rbindlist(lapply(cols, function(cn) { u <- setdiff(unique(te[[cn]]), unique(tr[[cn]]))
    if (length(u)) data.table(line = ln, column = cn, unseen = paste(head(u, 5), collapse = ", "), test_rows = sum(te[[cn]] %in% u)) }))
}))
if (!nrow(unseen)) unseen <- data.table(line = character(), column = character(), unseen = character(), test_rows = integer())

# C. Emerging claims ---------------------------------------------------------------------------------------------
n <- nrow(cl)
add_check(reg, "claims", "duplicate claim_id", sum(duplicated(cl$claim_id)), n, "none expected")
cl[, n_same := .N, by = .(policy_id, line, peril, loss_date, report_date, status, incurred_to_date)]
add_check(reg, "claims", "exact twins (same policy, peril, dates, status, incurred)", sum(cl$n_same > 1), n, "none expected (week 1 trap)")
cl[, n_same := NULL]
add_check(reg, "claims", "claim_id not 'CL' + 8 digits", sum(!grepl("^CL[0-9]{8}$", cl$claim_id)), n, "none expected (week 1 trap)")
add_check(reg, "claims", "peril not valid for its line", sum(!mapply(function(l, p) p %in% PERILS[[l]], cl$line, cl$peril)), n, "none expected")
add_check(reg, "claims", "report_date before loss_date", sum(cl$report_date < cl$loss_date), n, "none expected")
add_check(reg, "claims", "report_date after valuation date (31 Dec 2024)", sum(cl$report_date > VALUATION_DATE), n, "none expected")
add_check(reg, "claims", "paid_to_date > incurred_to_date", sum(cl$paid_to_date > cl$incurred_to_date + 1e-6), n, "none expected")
add_check(reg, "claims", "recoveries > incurred_to_date", sum(cl$recoveries > cl$incurred_to_date + 1e-6), n, "none expected")
add_check(reg, "claims", "repudiated with incurred > 0", sum(cl$status == "repudiated" & cl$incurred_to_date > 0), n, "none expected")
add_check(reg, "claims", "closed with paid != incurred", sum(cl$status == "closed" & abs(cl$paid_to_date - cl$incurred_to_date) > 1e-6), n, "information")
add_check(reg, "claims", "zero incurred, not repudiated", sum(cl$status != "repudiated" & cl$incurred_to_date == 0), n, "information")
add_check(reg, "claims", "loss_date before 2023 (before the market's first policy year)", sum(year(cl$loss_date) < 2023), n,
          "cannot match a policy row; excluded from targets", if (any(year(cl$loss_date) < 2023)) "issue" else "info")
match_rows <- rbindlist(lapply(LINES, function(ln) {
  tr <- E[[paste0("policies_", ln)]]; c <- cl[line == ln]
  m <- tr[c, on = .(policy_id, period_start <= loss_date, period_end >= loss_date), .(claim_id = i.claim_id, row_id = x.row_id), allow.cartesian = TRUE]
  data.table(line = ln, claims = nrow(c), matched = uniqueN(m[!is.na(row_id), claim_id]), multi = m[!is.na(row_id), .N, by = claim_id][N > 1, .N],
             no_policy = sum(!c$policy_id %in% tr$policy_id))
}))
match_rows[, unmatched := claims - matched]
for (i in seq_len(nrow(match_rows))) {
  r <- match_rows[i]
  add_check(reg, paste0("claims_", r$line), "claims matching no policy row", r$unmatched, r$claims, "excluded from targets (listed by 2_clean_w2.R)",
            if (r$unmatched) "issue" else "info")
  add_check(reg, paste0("claims_", r$line), "claims matching more than one policy row", r$multi, r$claims, "none expected")
  add_check(reg, paste0("claims_", r$line), "claims whose policy_id is in no policy row", r$no_policy, r$claims, "none expected")
}

# D. What has changed vs the developed market ---------------------------------------------------------------------
# experience: claims matched to rows by loss date; net = incurred - recoveries (repudiated = 0); same years 2023-24
experience <- function(pol, clm, mkt) rbindlist(lapply(LINES, function(ln) {
  tr <- pol[[paste0("policies_", ln)]][year(period_start) %in% 2023:2024]; tr[, expo := row_days(tr) / 365]
  c <- clm[line == ln]; c[, net := fifelse(status == "repudiated", 0, incurred_to_date - recoveries)]
  m <- tr[c, on = .(policy_id, period_start <= loss_date, period_end >= loss_date), .(row_id = x.row_id, peril = i.peril, net = i.net, status = i.status,
          lag = as.numeric(i.report_date - i.loss_date), py = year(x.period_start)), nomatch = NULL]
  ex <- tr[, .(exposure = sum(expo)), by = .(py = year(period_start))]
  r <- m[net > 0, .(claims = .N, cost = sum(net), open_share = mean(status == "open"), median_lag_days = median(lag)), by = .(py, peril)]
  r <- merge(r, ex, by = "py")
  setnames(r, "py", "policy_year")
  r[, `:=`(market = mkt, line = ln, frequency = claims / exposure, severity = cost / claims, burn = cost / exposure)]
}))
exp_e <- experience(E, cl, "emerging"); exp_d <- experience(D, D$claims, "developed")
exp_all <- rbind(exp_e, exp_d)
setcolorder(exp_all, c("market", "line", "peril", "policy_year"))
exp_cmp <- dcast(exp_all, line + peril + policy_year ~ market, value.var = c("frequency", "severity", "burn", "median_lag_days", "open_share"))
exp_cmp[, `:=`(freq_ratio = frequency_emerging / frequency_developed, sev_ratio = severity_emerging / severity_developed,
               burn_ratio = burn_emerging / burn_developed)]
line_exp <- exp_all[, .(claims = sum(claims), cost = sum(cost), exposure = exposure[1]), by = .(market, line, policy_year, peril)][
  , .(claims = sum(claims), cost = sum(cost), exposure = exposure[1]), by = .(market, line, policy_year)][
  , `:=`(frequency = claims / exposure, severity = cost / claims, burn = cost / exposure)]

# shared numeric columns: emerging training vs developed training (2023-24 rows)
num_cmp <- rbindlist(lapply(c("customers", "addresses", paste0("policies_", LINES)), function(f) {
  x <- E[[f]]; d <- D[[f]]
  if (startsWith(f, "policies_")) d <- d[year(period_start) %in% 2023:2024]
  cols <- intersect(names(x)[vapply(x, is.numeric, logical(1))], names(d)[vapply(d, is.numeric, logical(1))])
  cols <- setdiff(cols, "exposure")
  rbindlist(lapply(cols, function(cn) data.table(file = f, column = cn, mean_emerging = mean(x[[cn]], na.rm = TRUE), mean_developed = mean(d[[cn]], na.rm = TRUE),
                                                  median_emerging = median(x[[cn]], na.rm = TRUE), median_developed = median(d[[cn]], na.rm = TRUE))))
}))
num_cmp[, ratio := mean_emerging / mean_developed]
wx_cmp <- rbind(E$weather[, c(list(market = "emerging"), lapply(.SD, mean)), by = year, .SDcols = WEATHER_VARS],
                D$weather[, c(list(market = "developed"), lapply(.SD, mean)), by = year, .SDcols = WEATHER_VARS])
psi <- function(a, b, bins = 10) {
  if (is.numeric(a) && uniqueN(na.omit(c(a, b))) > bins) {
    br <- unique(quantile(c(a, b), seq(0, 1, length.out = bins + 1), na.rm = TRUE)); a <- cut(a, br, include.lowest = TRUE); b <- cut(b, br, include.lowest = TRUE)
  }
  a <- addNA(factor(a)); b <- addNA(factor(b, levels = levels(a)))
  pa <- pmax(prop.table(table(a)), 1e-4); pb <- pmax(prop.table(table(b)), 1e-4)
  sum((pa - pb) * log(pa / pb))
}
cat_cmp <- rbindlist(lapply(paste0("policies_", LINES), function(f) {
  x <- E[[f]]; d <- D[[f]][year(period_start) %in% 2023:2024]
  cols <- setdiff(intersect(names(x), names(d)), c("row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end", "exposure", "renewal_decision"))
  rbindlist(lapply(cols, function(cn) data.table(file = f, column = cn, psi_emerging_vs_developed = psi(x[[cn]], d[[cn]]))))
}))

# E. 2025 test portfolio vs 2023-24 training ----------------------------------------------------------------------
shift_tbl <- rbindlist(lapply(LINES, function(ln) {
  tr <- E[[paste0("policies_", ln)]]; te <- E[[paste0("test_", ln)]]
  cols <- setdiff(intersect(names(te), names(tr)), c("row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end", "exposure"))
  rbindlist(lapply(cols, function(cn) data.table(line = ln, column = cn, psi_test_vs_train = psi(te[[cn]], tr[[cn]]),
    train = if (is.numeric(tr[[cn]])) sprintf("mean %.3g", mean(tr[[cn]], na.rm = TRUE)) else { t <- sort(prop.table(table(tr[[cn]])), decreasing = TRUE); paste(sprintf("%s %.0f%%", names(t)[1:min(3, length(t))], 100 * t[1:min(3, length(t))]), collapse = ", ") },
    test = if (is.numeric(te[[cn]])) sprintf("mean %.3g", mean(te[[cn]], na.rm = TRUE)) else { t <- sort(prop.table(table(te[[cn]])), decreasing = TRUE); paste(sprintf("%s %.0f%%", names(t)[1:min(3, length(t))], 100 * t[1:min(3, length(t))]), collapse = ", ") })))
}))[order(-psi_test_vs_train)]

# Outputs --------------------------------------------------------------------------------------------------------
checks <- checks_table(reg)
save_csv_w2(inventory, STEP, "inventory.csv")
save_csv_w2(checks, STEP, "data_checks.csv")
save_csv_w2(miss, STEP, "missing_values.csv")
save_csv_w2(variants, STEP, "text_variants.csv")
save_csv_w2(unseen, STEP, "test_levels_unseen_in_train.csv")
save_csv_w2(match_rows, STEP, "claims_matching.csv")
save_csv_w2(exp_all, STEP, "experience_by_peril_market.csv")
save_csv_w2(exp_cmp, STEP, "experience_emerging_vs_developed.csv")
save_csv_w2(line_exp, STEP, "experience_by_line_market.csv")
save_csv_w2(num_cmp, STEP, "numeric_emerging_vs_developed.csv")
save_csv_w2(cat_cmp, STEP, "psi_emerging_vs_developed.csv")
save_csv_w2(wx_cmp, STEP, "weather_by_market_year.csv")
save_csv_w2(shift_tbl, STEP, "test_vs_train_shift.csv")
save_csv_w2(E$expenses, STEP, "expenses.csv")

pct <- function(x) ifelse(is.na(x), "", sprintf("%.1f%%", 100 * x))
write_md_w2(list(
  "# Week 2 - Step 1: raw data checks (emerging market)", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "by `week2/R/1_checks_w2.R`. Read-only: no data is changed here.",
        "The fixes and their assumptions are in `week2/output/2_clean/cleaning_report.md`."), "",
  "## A. Inventory", "", md_table(inventory), "",
  "## B-C. Checks", "`severity`: issue = needs a fix or a decision, fixed = handled in cleaning, info = for the record.", "",
  md_table(checks[, .(dataset, check, n, share = pct(share), severity, action)]),
  "### Missing values (share of rows; developed = same file in Part 1)", "",
  md_table(miss[order(-na_emerging)][, .(file, column, na_emerging = pct(na_emerging), na_developed = pct(na_developed), change = pct(change))]),
  "### Categorical columns with case / spacing variants", "", md_table(variants),
  "### Test levels never seen in training", "", md_table(unseen),
  "### Claims matched to policy rows", "", md_table(match_rows),
  "## D. What has changed vs the developed market", "",
  "Line experience, policy years 2023-24 (claims with net cost > 0, as at 31 Dec 2024; not developed to ultimate):", "",
  md_table(line_exp[order(line, policy_year, market)], 4),
  "Peril experience, emerging / developed ratios (same policy years):", "",
  md_table(exp_cmp[, .(line, peril, policy_year, freq_ratio, sev_ratio, burn_ratio, median_lag_emerging = median_lag_days_emerging,
                       median_lag_developed = median_lag_days_developed)][order(line, peril, policy_year)], 2),
  "Shared numeric columns (means; developed restricted to 2023-24 rows):", "", md_table(num_cmp[order(file, column)], 3),
  "Distribution shift of shared policy columns (PSI > 0.25 = large):", "", md_table(cat_cmp[order(-psi_emerging_vs_developed)][1:min(25, .N)], 3),
  "Weather means by market and year:", "", md_table(wx_cmp[order(market, year)], 3),
  "Expense assumptions (emerging folder):", "", md_table(E$expenses),
  "## E. 2025 test portfolio vs 2023-24 training (top 25 by PSI)", "", md_table(shift_tbl[1:min(25, .N)], 3)
), STEP, "checks_report.md")
log_msg("Checks written to ", file.path(PATHS_W2$output, STEP), ": ", nrow(checks), " checks, ", sum(checks$severity == "issue"), " issues")
