# 3_incidence.R ----------------------------------------------------------------
# Step 5: incidence (frequency), severity and burn-cost dimensions with report and graphs.
#   A. Experience by line x policy year (frequency, severity, burn cost, loss ratio)
#   B. Experience by peril x year
#   C. Reporting delay and IBNR count factors by loss year (used by step 6)
#   D. One-way analysis of every candidate rating factor, ranked by how much it separates risk
# Outputs: week1/output/3_incidence/ (incidence_report.md, *.csv, plots/, oneway_<line>/)

source("week1/R/0_setup.R")
STEP <- "3_incidence"
ONEWAY_MIN_SHARE <- 0.01   # levels below this exposure share are ignored in the ranking score

train <- setNames(lapply(LINES, function(ln) read_clean(paste0("train_", ln))), LINES)

# Large-loss cap per line (row level) so one claim does not dominate the one-ways
caps <- sapply(LINES, function(ln) quantile(train[[ln]][y_cost > 0, y_cost], LARGE_LOSS_QUANTILE, names = FALSE))
for (ln in LINES) train[[ln]][, y_cost_capped := pmin(y_cost, caps[[ln]])]
cap_table <- data.table(line = LINES, cap = caps,
                        rows_capped = sapply(LINES, function(ln) train[[ln]][y_cost > caps[[ln]], .N]),
                        cost_removed_pct = sapply(LINES, function(ln) 100 * train[[ln]][, 1 - sum(y_cost_capped) / sum(y_cost)]))
save_csv(cap_table, STEP, "large_loss_caps.csv")

summarise_exp <- function(dt, by) {
  dt[, .(rows = .N, exposure = sum(exposure), claims = sum(y_n_claims), cost = sum(y_cost),
         cost_capped = sum(y_cost_capped), earned_premium = sum(written_premium * exposure)), by = by][
    , `:=`(frequency = claims / exposure, severity = cost_capped / claims, burn_cost = cost / exposure,
           burn_cost_capped = cost_capped / exposure, loss_ratio = cost_capped / earned_premium)][]
}

# A. Line x policy year --------------------------------------------------------------------
by_year <- rbindlist(lapply(LINES, function(ln) summarise_exp(train[[ln]], "policy_year")[, line := ln]))
setcolorder(by_year, "line"); setorder(by_year, line, policy_year)
save_csv(by_year, STEP, "experience_by_year.csv")

p <- ggplot(melt(by_year, id.vars = c("line", "policy_year"),
                 measure.vars = c("frequency", "severity", "burn_cost_capped", "loss_ratio")),
            aes(policy_year, value, colour = line)) + geom_line() + geom_point() +
  facet_wrap(~variable, scales = "free_y") +
  labs(title = "Experience by policy year (2024 is immature)", x = NULL, y = NULL)
save_plot(p, STEP, "plots/experience_by_year.png")

# B. Peril x year ---------------------------------------------------------------------------
by_peril <- rbindlist(lapply(LINES, function(ln) {
  dt <- train[[ln]]
  rbindlist(lapply(PERILS[[ln]], function(pr) {
    dt[, .(exposure = sum(exposure), claims = sum(get(paste0("y_n_", pr))), cost = sum(get(paste0("y_cost_", pr)))),
       by = policy_year][, `:=`(line = ln, peril = pr)]
  }))
}))
by_peril[, `:=`(frequency_per_1000 = 1000 * claims / exposure, severity = cost / claims, burn_cost = cost / exposure)]
setcolorder(by_peril, c("line", "peril", "policy_year")); setorder(by_peril, line, peril, policy_year)
save_csv(by_peril, STEP, "experience_by_peril_year.csv")

p <- ggplot(by_peril, aes(policy_year, frequency_per_1000, colour = peril)) + geom_line() + geom_point() +
  facet_wrap(~line, scales = "free_y") + labs(title = "Claim frequency per 1,000 exposure-years by peril", x = NULL)
save_plot(p, STEP, "plots/frequency_by_peril.png", width = 11)
p <- ggplot(by_peril, aes(policy_year, severity, colour = peril)) + geom_line() + geom_point() +
  facet_wrap(~line, scales = "free_y") + scale_y_log10(labels = scales::comma) +
  labs(title = "Mean severity by peril (uncapped, log scale)", x = NULL)
save_plot(p, STEP, "plots/severity_by_peril.png", width = 11)

# C. Reporting delay and IBNR count factors -----------------------------------------------------
# Lag distribution from 2021-22 losses; expected share of claims already reported at the valuation
# date for each loss year, assuming losses spread evenly through the year.
cl <- read_clean("claims_matched")[counts == TRUE & !is.na(row_id)]
cl[, `:=`(lag = as.numeric(report_date - loss_date), loss_year = year(loss_date))]
ibnr <- rbindlist(lapply(LINES, function(ln) {
  F <- ecdf(cl[line == ln & loss_year %in% 2021:2022, lag])
  rbindlist(lapply(TRAIN_YEARS, function(y) {
    days <- seq(as.Date(paste0(y, "-01-01")), as.Date(paste0(y, "-12-31")), by = "day")
    share <- mean(F(as.numeric(VALUATION_DATE - days)))
    data.table(line = ln, policy_year = y, reported_share = share, ibnr_factor = 1 / share)
  }))
}))
open_share <- cl[, .(pct_open = 100 * mean(status == "open"),
                     open_case_share_of_incurred = 100 * sum(incurred_to_date[status == "open"]) / sum(incurred_to_date)),
                 by = .(line, policy_year = loss_year)]
ibnr <- merge(ibnr, open_share, by = c("line", "policy_year"), all.x = TRUE)
save_csv(ibnr, STEP, "ibnr_factors.csv")

p <- ggplot(cl[loss_year %in% 2021:2022], aes(lag + 1, colour = line)) + stat_ecdf() + scale_x_log10() +
  labs(title = "Reporting delay (2021-22 losses)", x = "days from loss to report + 1 (log)", y = "share reported")
save_plot(p, STEP, "plots/reporting_delay.png")

# C2. Reporting factors by peril (used from BEN 1) and an adequacy check -------------------------
# Same method per peril: late-reporting perils (bodily injury, subsidence) get their own, larger factor.
reported_share <- function(lags, y) {
  F <- ecdf(lags)
  days <- seq(as.Date(paste0(y, "-01-01")), as.Date(paste0(y, "-12-31")), by = "day")
  mean(F(as.numeric(VALUATION_DATE - days)))
}
ibnr_peril <- rbindlist(lapply(LINES, function(ln) rbindlist(lapply(PERILS[[ln]], function(pr) {
  lags <- cl[line == ln & peril == pr & loss_year %in% 2021:2022, lag]
  rbindlist(lapply(TRAIN_YEARS, function(y) {
    s <- reported_share(lags, y)
    data.table(line = ln, peril = pr, policy_year = y, claims_2021_22 = length(lags), reported_share = s,
               ibnr_factor = 1 / s)
  }))
}))))
save_csv(ibnr_peril, STEP, "ibnr_factors_by_peril.csv")

# Does the count factor explain the 2024 drop? Frequency as reported vs developed with the per-peril factors
freq_dev <- by_peril[ibnr_peril, on = .(line, peril, policy_year)][
  , .(frequency_reported = sum(claims) / exposure[1], frequency_developed = sum(claims * ibnr_factor) / exposure[1]),
  by = .(line, policy_year)]
freq_dev[, change_vs_prior_year_pct := 100 * (frequency_developed / shift(frequency_developed) - 1), by = line]
save_csv(freq_dev, STEP, "frequency_developed.csv")

# Open claims: case estimate vs the cost of closed claims of the same peril and loss year (no history to develop from)
case_check <- cl[, .(open_claims = sum(status == "open"), closed_claims = sum(status == "closed"),
                     mean_open_incurred = mean(incurred_to_date[status == "open"]),
                     mean_closed_cost = mean(net_cost[status == "closed"])), by = .(line, peril, loss_year)]
case_check[, open_to_closed := mean_open_incurred / mean_closed_cost]
setorder(case_check, line, peril, loss_year)
save_csv(case_check, STEP, "open_claim_case_check.csv")

# D. One-way analysis per rating factor ----------------------------------------------------------
bin_var <- function(x, n_bins = 10, max_levels = 20) {
  if (is.numeric(x)) {
    vals <- sort(unique(x[!is.na(x)]))
    if (length(vals) <= max_levels) {
      f <- factor(x, levels = vals)
    } else {
      br <- unique(quantile(x, seq(0, 1, length.out = n_bins + 1), na.rm = TRUE, names = FALSE))
      f <- cut(x, br, include.lowest = TRUE, dig.lab = 6)
    }
  } else {
    x <- as.character(x)
    top <- names(sort(table(x), decreasing = TRUE))[seq_len(min(max_levels, uniqueN(x, na.rm = TRUE)))]
    x[!is.na(x) & !x %in% top] <- "(grouped)"
    f <- factor(x, levels = c(sort(top), if (any(x == "(grouped)", na.rm = TRUE)) "(grouped)"))
  }
  if (anyNA(f)) {
    f <- addNA(f)
    levels(f)[is.na(levels(f))] <- "missing"
  }
  f
}

one_way <- function(dt, var, tot) {
  b <- bin_var(dt[[var]])
  res <- dt[, .(exposure = sum(exposure), claims = sum(y_n_claims), cost = sum(y_cost_capped),
                earned_premium = sum(written_premium * exposure)), by = .(level = b)]
  setorder(res, level)
  res[, `:=`(exposure_share = exposure / sum(exposure), frequency = claims / exposure,
             severity = fifelse(claims > 0, cost / claims, NA_real_), burn_cost = cost / exposure,
             loss_ratio = cost / earned_premium)]
  res[, `:=`(freq_rel = frequency / tot$frequency, sev_rel = severity / tot$severity,
             burn_rel = burn_cost / tot$burn_cost, lr_rel = loss_ratio / tot$loss_ratio)]
  res[, variable := var]
  res
}

# Exposure-weighted spread of relativities over credible levels (0 = factor does not separate risk)
spread <- function(rel, share) {
  ok <- share >= ONEWAY_MIN_SHARE & is.finite(rel)
  if (sum(ok) < 2) return(0)
  w <- share[ok] / sum(share[ok])
  sqrt(sum(w * (rel[ok] - 1)^2))
}

plot_one_way <- function(res, var, ln) {
  long <- melt(res, id.vars = "level", measure.vars = c("exposure_share", "freq_rel", "sev_rel", "burn_rel", "lr_rel"),
               variable.name = "metric")
  long[, metric := factor(metric, levels = c("exposure_share", "freq_rel", "sev_rel", "burn_rel", "lr_rel"),
                          labels = c("Exposure share", "Frequency rel.", "Severity rel.", "Burn cost rel.", "Loss ratio rel."))]
  ggplot(long, aes(level, value, group = 1)) +
    geom_col(data = long[metric == "Exposure share"], fill = "grey70") +
    geom_hline(data = data.frame(metric = levels(long$metric)[-1], y = 1), aes(yintercept = y), linetype = 2, colour = "grey50") +
    geom_line(data = long[metric != "Exposure share"], colour = "steelblue") +
    geom_point(data = long[metric != "Exposure share"], colour = "steelblue") +
    facet_wrap(~metric, scales = "free_y", ncol = 1) +
    labs(title = paste0(ln, ": ", var), subtitle = "Relativities vs line average (capped cost, all years)", x = NULL, y = NULL) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

oneway_all <- list(); ranking_all <- list()
unlink(file.path(PATHS$output, STEP, paste0("oneway_", LINES)), recursive = TRUE)  # plot names carry the rank
for (ln in LINES) {
  dt <- train[[ln]]
  tot <- dt[, .(frequency = sum(y_n_claims) / sum(exposure), severity = sum(y_cost_capped) / sum(y_n_claims),
                burn_cost = sum(y_cost_capped) / sum(exposure),
                loss_ratio = sum(y_cost_capped) / sum(written_premium * exposure))]
  vars <- c(feature_cols(dt), "policy_year")
  res <- rbindlist(lapply(vars, function(v) one_way(dt, v, tot)))
  res[, level := as.character(level)]
  rank <- res[, .(levels = .N, burn_spread = spread(burn_rel, exposure_share), freq_spread = spread(freq_rel, exposure_share),
                  sev_spread = spread(sev_rel, exposure_share), lr_spread = spread(lr_rel, exposure_share)), by = variable]
  setorder(rank, -burn_spread)
  rank[, `:=`(rank = .I, line = ln)]
  oneway_all[[ln]] <- res[, line := ln]
  ranking_all[[ln]] <- rank

  for (i in seq_len(nrow(rank))) {
    v <- rank$variable[i]
    one <- one_way(dt, v, tot)
    save_plot(plot_one_way(one, v, ln), STEP, sprintf("oneway_%s/%02d_%s.png", ln, i, v),
              width = max(6, 0.35 * nrow(one) + 3), height = 7)
  }
  p <- ggplot(rank[1:min(25, .N)], aes(reorder(variable, burn_spread), burn_spread)) + geom_col(fill = "steelblue") +
    coord_flip() + labs(title = paste0(ln, ": top rating factors by burn-cost spread"), x = NULL,
                        y = "exposure-weighted SD of burn-cost relativity")
  save_plot(p, STEP, paste0("plots/factor_ranking_", ln, ".png"), height = 7)
  log_msg(ln, ": one-way analysis of ", length(vars), " variables done")
}
oneway <- rbindlist(oneway_all); ranking <- rbindlist(ranking_all)
setcolorder(oneway, c("line", "variable", "level")); setcolorder(ranking, c("line", "rank", "variable"))
save_csv(oneway, STEP, "oneway_tables.csv")
save_csv(ranking, STEP, "factor_ranking.csv")

# Report -------------------------------------------------------------------------------------------
top_tbl <- function(ln) ranking[line == ln][1:15, .(rank, variable, levels, burn_spread, freq_spread, sev_spread, lr_spread)]
write_md(list(
  "# Step 5 - Incidence rate dimensions", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/3_incidence.R`."), "",
  "Definitions: frequency = non-repudiated claims / exposure-years; severity = capped cost / claims;",
  "burn cost = cost / exposure; loss ratio = capped cost / (written_premium x exposure).", "",
  "## Large-loss caps (row level, p99.9 of positive row cost)", md_table(cap_table, 2),
  "## A. Experience by line and policy year", "![](plots/experience_by_year.png)", "",
  md_table(by_year[, .(line, policy_year, exposure, claims, frequency, severity, burn_cost, burn_cost_capped, loss_ratio)]),
  "## B. Experience by peril", "![](plots/frequency_by_peril.png)", "", "![](plots/severity_by_peril.png)", "",
  "Full table: `experience_by_peril_year.csv`.", "",
  "## C. Reporting delay and IBNR count factors",
  "`ibnr_factor` = 1 / expected share of claims already reported at 31 Dec 2024 (lag distribution from 2021-22 losses).",
  "It covers late-reported claims only; development of open case estimates (`open_case_share_of_incurred`) is NOT included.", "",
  "![](plots/reporting_delay.png)", "", md_table(ibnr, 4),
  "### C2. By peril, and is the count factor adequate?",
  "Per-peril factors (`ibnr_factors_by_peril.csv`, used from BEN 1) use the same method within each peril.",
  "Frequency developed with them shows whether late reporting explains the 2024 drop: what remains is a trend.", "",
  md_table(freq_dev, 4),
  "Open claims cannot be developed from a single valuation date (no history of case estimates). As a check, the",
  "mean case estimate of open claims is compared with the mean cost of closed claims of the same peril and loss year",
  "(`open_case_share_of_incurred` above shows how much of each year rests on case estimates):", "",
  md_table(case_check[loss_year >= 2023 & open_claims >= 20], 2),
  "## D. One-way analysis - top 15 factors per line",
  "Spread = exposure-weighted standard deviation of the relativity across levels with >= 1% exposure.",
  "`lr_spread` high = current pricing does not fully reflect the factor (opportunity to improve).",
  "Plots per factor are in `oneway_<line>/`, numbered by rank.", "",
  unlist(lapply(LINES, function(ln) c(paste0("### ", ln), paste0("![](plots/factor_ranking_", ln, ".png)"), "", md_table(top_tbl(ln)))))
), STEP, "incidence_report.md")

log_msg("Done. Report: ", out_file(STEP, "incidence_report.md"))
