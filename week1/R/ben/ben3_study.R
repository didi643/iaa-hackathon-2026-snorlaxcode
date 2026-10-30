# ben/ben3_study.R -----------------------------------------------------------
# BEN 3 groundwork: claim-level checks that decide the target, level and trend before any model is fitted.
# Reads data/week_1/clean/ only (run after week1/R/2_clean.R); fits nothing.
#   1. Excess: frequency and net severity by voluntary excess and peril (is the excess already taken off?)
#   2. Recoveries: who recovers, how much, and what open own-damage / theft claims are still likely to recover
#   3. Open vs closed: are open case estimates out of line with closed claims of the same peril, year and report lag?
#   4. IBNR by chain ladder: monthly accident x report-delay triangles per line and peril (counts and capped cost);
#      per-year vs per-row factors; backtest at a 31 Dec 2023 valuation against the claims reported during 2024
#   5. Level: developed frequency, severity and burn cost per line and year, trends, and the implied 2025 level
# Run:     Rscript week1/R/ben/ben3_study.R
# Outputs: week1/output/ben/ben3_study/ (ben3_study_report.md + CSVs)

source("week1/R/0_setup.R")
source("week1/R/ben/ben_helpers.R")
STUDY <- "ben3_study"
study_csv <- function(dt, f) fwrite(dt, ben_out(file.path(STUDY, f)))
SINGLE_CLAIM_LIMIT <- 2e6        # WENDY 4's limit; only the 11.9m motor bodily-injury claim exceeds it
# Chain-ladder helpers (dev_shares(), row_share(), month_index()) are in week1/R/ben/ben_helpers.R

rows <- rbindlist(lapply(LINES, function(ln) {
  d <- as.data.table(read_parquet(file.path(PATHS$clean, paste0("train_", ln, ".parquet"))))
  keep <- intersect(c("row_id", "period_start", "period_end", "policy_year", "exposure", "voluntary_excess",
                      "compulsory_excess", "cover_type", "accidental_damage_cover", "new_business"), names(d))
  d[, ..keep][, line := ln]
}), fill = TRUE)
claims <- read_clean("claims_matched")[, loss_year := year(loss_date)]
paid <- claims[counts == TRUE]
matched <- merge(paid[!is.na(row_id)], rows[, .(row_id, voluntary_excess, compulsory_excess, cover_type, policy_year)],
                 by = "row_id")

# 1. Excess -------------------------------------------------------------------------------------------------
compulsory <- rows[, .(rows = .N, exposure = sum(exposure)), by = .(line, compulsory_excess)]
exc_exp <- rows[, .(exposure = sum(exposure)), by = .(line, voluntary_excess)]
excess <- matched[, .(claims = .N, mean_net = mean(net_cost), median_net = median(net_cost),
                      p05_net = quantile(net_cost, 0.05, names = FALSE), min_net = min(net_cost),
                      share_below_250 = mean(net_cost < 250)), by = .(line, peril, voluntary_excess)]
excess <- merge(excess, exc_exp, by = c("line", "voluntary_excess"))[, frequency_per_1000 := 1000 * claims / exposure]
setorder(excess, line, peril, voluntary_excess)
excess[, `:=`(freq_rel_to_0 = frequency_per_1000 / frequency_per_1000[voluntary_excess == 0],
              median_shift_vs_0 = median_net - median_net[voluntary_excess == 0]), by = .(line, peril)]
study_csv(compulsory, "excess_compulsory.csv"); study_csv(excess, "excess_by_peril.csv")

# 2. Recoveries ------------------------------------------------------------------------------------------------
recov <- paid[, .(claims = .N, share_with_recovery = mean(recoveries > 0),
                  recovery_ratio = sum(recoveries) / sum(incurred_to_date),
                  ratio_when_recovered = sum(recoveries[recoveries > 0]) / sum(incurred_to_date[recoveries > 0])),
              by = .(line, peril, status, loss_year)][claims >= 20]
setorder(recov, line, peril, status, loss_year)
rec_ratio <- paid[status == "closed", .(rec_ratio = sum(recoveries) / sum(incurred_to_date)), by = .(line, peril)][rec_ratio > 0]
open_rec <- merge(paid[status == "open"], rec_ratio, by = c("line", "peril"))[
  , .(open_claims = .N, open_incurred = sum(incurred_to_date), expected_recovery = sum(incurred_to_date * rec_ratio)),
  by = .(line, peril, loss_year)]
line_cost <- paid[, .(net_cost = sum(net_cost)), by = .(line, loss_year)]
open_rec <- merge(open_rec, line_cost, by = c("line", "loss_year"))[, pct_of_line_cost := 100 * expected_recovery / net_cost]
study_csv(recov, "recoveries.csv"); study_csv(open_rec, "open_claim_expected_recoveries.csv")

# 3. Open vs closed --------------------------------------------------------------------------------------------
paid[, lag_band := cut(as.numeric(report_date - loss_date), c(-Inf, 7, 30, 90, 365, Inf),
                       labels = c("0-7d", "8-30d", "31-90d", "91-365d", ">1y"))]
oc <- paid[, .(claims = .N, share_open = mean(status == "open"),
               mean_closed = mean(net_cost[status == "closed"]), mean_open = mean(incurred_to_date[status == "open"]),
               open_paid_share = sum(paid_to_date[status == "open"]) / sum(incurred_to_date[status == "open"])),
           by = .(line, peril, loss_year)][, open_to_closed := mean_open / mean_closed]
setorder(oc, line, peril, loss_year)
oc_lag <- paid[, .(n_open = sum(status == "open"), n_closed = sum(status == "closed"),
                   mean_open = mean(incurred_to_date[status == "open"]), mean_closed = mean(net_cost[status == "closed"])),
               by = .(line, peril, loss_year, lag_band)][n_open >= 10 & n_closed >= 10][, open_to_closed := mean_open / mean_closed]
oc_lag_summary <- oc_lag[, .(cells = .N, median_ratio = median(open_to_closed), min_ratio = min(open_to_closed),
                             max_ratio = max(open_to_closed), open_claims = sum(n_open)), by = .(line, loss_year)]
study_csv(oc, "open_vs_closed.csv"); study_csv(oc_lag, "open_vs_closed_by_lag.csv")

# 4. IBNR by chain ladder (dev_shares() and row_share() in week1/R/ben/ben_helpers.R) ----------------------------------
caps <- paid[net_cost > 0, .(cost_cap = quantile(net_cost, LARGE_LOSS_QUANTILE, names = FALSE)), by = .(line, peril)]
paid <- merge(paid, caps, by = c("line", "peril"))


# Current method (week1/R/3_incidence.R): empirical report-lag distribution of losses two or more years before V
ecdf_share <- function(cc, V, years) {
  ref_years <- (year(V) - 3):(year(V) - 2)
  rbindlist(lapply(split(cc[year(loss_date) %in% ref_years], by = c("line", "peril")), function(x) {
    F <- ecdf(as.numeric(x$report_date - x$loss_date))
    rbindlist(lapply(years, function(y) {
      dd <- seq(as.Date(paste0(y, "-01-01")), min(as.Date(paste0(y, "-12-31")), V), by = "day")
      data.table(line = x$line[1], peril = x$peril[1], policy_year = y, share_ecdf = mean(F(as.numeric(V - dd))))
    }))
  }))
}

# 4a. Factors at the real valuation date, per year and per row, by the row's start quarter (2023-24 rows)
sh_now <- dev_shares(paid, VALUATION_DATE)
study_csv(sh_now, "chain_ladder_shares_by_month.csv")
r24 <- rows[policy_year >= 2023]
per_row <- row_share(r24, sh_now, VALUATION_DATE, "row")
per_row <- merge(per_row, r24[, .(row_id, line, policy_year, exposure, start_q = quarter(period_start))], by = "row_id")
per_year <- row_share(r24, sh_now, VALUATION_DATE, "year")
ecdf_now <- ecdf_share(paid, VALUATION_DATE, 2023:2024)
by_q <- per_row[, .(exposure = sum(exposure), row_factor_n = weighted.mean(1 / share_n, exposure),
                    row_factor_cost = weighted.mean(1 / share_w, exposure)), by = .(line, peril, policy_year, start_q)]
by_q <- merge(by_q, per_year[, .(line, peril, policy_year, year_factor_cl = 1 / share_w)], by = c("line", "peril", "policy_year"))
by_q <- merge(by_q, ecdf_now[, .(line, peril, policy_year, year_factor_ecdf = 1 / share_ecdf)], by = c("line", "peril", "policy_year"))
setorder(by_q, line, peril, policy_year, start_q)
study_csv(by_q, "ibnr_factor_by_start_quarter.csv")

# 4b. Backtest: value at 31 Dec 2023, predict the 2023-row claims that were then still unreported, compare with 2024
V0 <- as.Date("2023-12-31")
sh_bt <- dev_shares(paid, V0)
r23 <- rows[policy_year == 2023]
bt_row <- row_share(r23, sh_bt, V0, "row")
bt_year <- row_share(r23, sh_bt, V0, "year")
ecdf_bt <- ecdf_share(paid[report_date <= V0], V0, 2023)
c23 <- paid[row_id %in% r23$row_id & loss_date <= V0, .(row_id, line, peril, net_cost, cost_cap, late = report_date > V0)]
rep_row <- c23[, .(n_rep = sum(!late), w_rep = sum(pmin(net_cost, cost_cap)[!late]), n_late = sum(late),
                   w_late = sum(pmin(net_cost, cost_cap)[late])), by = .(row_id, peril)]
rep_row <- merge(rep_row, r23[, .(row_id, line, start_q = quarter(period_start))], by = "row_id")
rep_row <- merge(rep_row, bt_row, by = c("row_id", "peril"))
rep_row <- merge(rep_row, bt_year[, .(line, peril, ys_n = share_n, ys_w = share_w)], by = c("line", "peril"))
rep_row <- merge(rep_row, ecdf_bt[, .(line, peril, es = share_ecdf)], by = c("line", "peril"), all.x = TRUE)
backtest <- rep_row[, .(actual_late = sum(n_late), per_row_cl = sum(n_rep * (1 / share_n - 1)),
                        per_year_cl = sum(n_rep * (1 / ys_n - 1)), per_year_ecdf = sum(n_rep * (1 / es - 1), na.rm = TRUE),
                        actual_late_cost = sum(w_late), per_row_cl_cost = sum(w_rep * (1 / share_w - 1)),
                        per_year_cl_cost = sum(w_rep * (1 / ys_w - 1))), by = .(line, start_q)]
setorder(backtest, line, start_q)
backtest_peril <- rep_row[, .(actual_late = sum(n_late), per_row_cl = sum(n_rep * (1 / share_n - 1)),
                              per_year_cl = sum(n_rep * (1 / ys_n - 1)), per_year_ecdf = sum(n_rep * (1 / es - 1), na.rm = TRUE)),
                          by = .(line, peril)]
study_csv(backtest, "ibnr_backtest_2023_by_start_quarter.csv"); study_csv(backtest_peril, "ibnr_backtest_2023_by_peril.csv")

# 5. Level and trend ---------------------------------------------------------------------------------------------
# Ultimate per line x peril x loss year = reported / chain-ladder share of each loss month; costs net of expected
# recoveries on open claims, with the single-claim limit applied and shown separately
paid <- merge(paid, rec_ratio, by = c("line", "peril"), all.x = TRUE)
paid[is.na(rec_ratio), rec_ratio := 0]
paid[, `:=`(a = month_index(loss_date),
            cost_adj = pmin(net_cost - fifelse(status == "open", incurred_to_date * rec_ratio, 0), SINGLE_CLAIM_LIMIT))]
ult <- merge(paid[!is.na(row_id) & loss_year %in% TRAIN_YEARS], sh_now, by = c("line", "peril", "a"))
lev_peril <- ult[, .(claims = .N, claims_ult = sum(1 / share_n), cost_reported = sum(net_cost),
                     cost_adj = sum(cost_adj), cost_ult = sum(cost_adj / share_w)), by = .(line, peril, policy_year = loss_year)]
expo <- rows[, .(exposure = sum(exposure)), by = .(line, policy_year)]
lev_peril <- merge(lev_peril, expo, by = c("line", "policy_year"))
lev_peril[, `:=`(freq_ult = claims_ult / exposure, sev_ult = cost_ult / claims_ult, burn_ult = cost_ult / exposure)]
setorder(lev_peril, line, peril, policy_year)
lev_line <- lev_peril[, .(exposure = exposure[1], burn_reported = sum(cost_reported) / exposure[1],
                          burn_adj = sum(cost_adj) / exposure[1], burn_ult = sum(cost_ult) / exposure[1],
                          freq_ult = sum(claims_ult) / exposure[1], sev_ult = sum(cost_ult) / sum(claims_ult)),
                      by = .(line, policy_year)]
loglin <- function(y, x, w) { b <- coef(lm(log(y) ~ x, weights = w)); c(rate = exp(b[[2]]) - 1, at2025 = exp(b[[1]] + b[[2]] * 2025)) }
trend <- rbindlist(lapply(list(`2021-23` = 2021:2023, `2021-24` = 2021:2024), function(yrs) {
  lev_line[policy_year %in% yrs, {
    bf <- loglin(burn_ult, policy_year, exposure); ff <- loglin(freq_ult, policy_year, exposure); sf <- loglin(sev_ult, policy_year, exposure)
    .(burn_trend = bf[["rate"]], freq_trend = ff[["rate"]], sev_trend = sf[["rate"]], burn_2025 = bf[["at2025"]],
      burn_2025_freq_x_sev = ff[["at2025"]] * sf[["at2025"]])
  }, by = line]
}), idcol = "fit_years")
peril_trend <- lev_peril[policy_year <= 2023 & claims >= 30, {
  ff <- loglin(freq_ult, policy_year, exposure); sf <- loglin(sev_ult, policy_year, claims_ult)
  .(freq_trend_21_23 = ff[["rate"]], sev_trend_21_23 = sf[["rate"]])
}, by = .(line, peril)]
team <- data.table(line = rep(LINES, 5), submission = rep(c("BEN 1/2", "WENDY 4", "WENDY 5", "SAM 2", "SAM 3"), each = 3),
                   public = rep(c(0.12224, 0.12671, 0.12636, 0.12796, 0.12818), each = 3),
                   burn_2025 = c(505.5, 456.4, 122.4, 521.2, 482.4, 125.0, 545.1, 475.4, 125.4, 604.1, 487.4, 125.1,
                                 603.3, 487.4, 125.2))
study_csv(lev_peril, "level_by_peril_year.csv"); study_csv(lev_line, "level_by_line_year.csv")
study_csv(trend, "trend_by_line.csv"); study_csv(peril_trend, "trend_by_peril.csv")

# Report -----------------------------------------------------------------------------------------------------------
write_md(list(
  "# BEN 3 study: excess, recoveries, open claims, chain-ladder IBNR, level", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/ben/ben3_study.R`. Claims valued 31 Dec 2024."), "",
  "## 1. Excess", "Compulsory excess by line:", "", md_table(compulsory, 0),
  "Frequency and net severity by voluntary excess (self-selected, so lower frequency is partly lower risk):", "",
  md_table(excess[, .(line, peril, voluntary_excess, claims, frequency_per_1000, freq_rel_to_0, median_net, median_shift_vs_0,
                      p05_net, share_below_250)], 3),
  "## 2. Recoveries", md_table(recov[status != "repudiated" & recovery_ratio > 0], 3),
  "Expected recoveries still to come on open claims (closed-claim recovery ratio x open incurred):", "",
  md_table(open_rec, 3),
  "## 3. Open vs closed", md_table(oc[loss_year >= 2023], 3),
  "Same peril, loss year and report-lag band (cells with >= 10 open and >= 10 closed claims):", "",
  md_table(oc_lag_summary, 3),
  "## 4. IBNR by chain ladder",
  "Monthly accident x report-delay triangles per line and peril; `row_factor` spreads each row's exposure over its own days,",
  "`year_factor` over the whole policy year (current method). Cost = capped net cost.", "",
  md_table(by_q[policy_year == 2024], 3),
  "### Backtest: valued at 31 Dec 2023, predicted late 2023 claims vs those reported in 2024", "",
  md_table(backtest, 1), md_table(backtest_peril, 1),
  "## 5. Level and trend",
  "Ultimate = reported / chain-ladder share, net of expected recoveries on open claims, single claims limited to 2m.", "",
  md_table(lev_line, 3), md_table(trend, 4),
  "Per-peril frequency and severity trends on 2021-23:", "", md_table(peril_trend, 4),
  "Predicted 2025 cost per exposure-year of the submissions so far:", "",
  md_table(dcast(team, submission + public ~ line, value.var = "burn_2025"), 1)
), file.path("ben", STUDY), "ben3_study_report.md")
log_msg("Done. Report: ", ben_out(file.path(STUDY, "ben3_study_report.md")))
