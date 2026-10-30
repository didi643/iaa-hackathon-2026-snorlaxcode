# 3_ibnr_w2.R ----------------------------------------------------------------------------------------------------
# Week 2 step 3: claim reporting pattern (IBNR) for the emerging market, and what carries over from Part 1.
#   Curve      per line x peril, P(report lag <= x days), right-truncation corrected (Lynden-Bell product limit, as in the
#              week 1 IBNR study week1/R/3b_ibnr_study.R): each claim is only observable if reported by the valuation date.
#   Tail       the emerging market has at most ~2 years of lags. Its curve is estimated conditional on lag <= h (h = longest
#              observable lag) and the tail beyond h is taken from the developed market:
#                F_e(x) = F_e|h(x) x F_d(h) for x <= h,  F_d(x) beyond h.
#   Blend      F = z F_e + (1 - z) F_d, z = n / (n + k), n = the peril's emerging claim count. k is chosen by a backtest:
#              valuation 31 Dec 2023, predict the 2023-loss claims reported during 2024, compare with what was reported.
#   Shares     per training row and peril: reported share at 31 Dec 2024 = mean over 16 points of the row period of
#              F(31 Dec 2024 - t), floored at SHARE_FLOOR. Ultimate claim count = reported / share.
# Out: data/week_2/clean/emerging_report_shares.parquet (row_id, s_<peril>, y_dev_cost = sum_p y_cost_p / s_p, ...)
#      week2/output/3_ibnr/ (ibnr_report.md, curves, market comparison, backtest, chosen k)

source("week2/R/0_setup_w2.R")
STEP <- "3_ibnr"
LMAX <- 3650L
SHARE_FLOOR <- 0.05
K_GRID <- c(0, 30, 100, 300, 1000, Inf)        # 0 = emerging only, Inf = developed only
CUT <- as.Date("2023-12-31")                    # backtest valuation
N_BOOT <- 500L

# right-truncated reverse-time product limit; returns P(lag <= x | lag <= max observable age), x = 0..LMAX
lb_curve <- function(lag, age) {
  lag <- pmin(lag, LMAX); age <- pmin(age, LMAX)
  dv <- tabulate(lag + 1L, LMAX + 1L); av <- tabulate(age + 1L, LMAX + 1L)
  R <- cumsum(dv) - c(0, cumsum(av)[-(LMAX + 1L)])
  haz <- ifelse(R > 0, pmin(dv / R, 1 - 1e-12), 0)
  F <- exp(rev(cumsum(rev(c(log1p(-haz)[-1], 0)))))
  cummax(pmin(pmax(F, 0), 1))
}
claims_for <- function(mkt) {
  cl <- read_clean_w2(paste0(mkt, "_claims_matched"))[!is.na(row_id) & counts & net_cost > 0]
  cl[, `:=`(lag = as.integer(report_date - loss_date), lp = paste(line, peril, sep = "."))]
  cl
}
ce <- claims_for("emerging"); cd <- claims_for("developed")
LP <- rbindlist(lapply(LINES, function(ln) data.table(line = ln, peril = PERILS[[ln]])))[, lp := paste(line, peril, sep = ".")]

curves_at <- function(cut) {
  out <- list()
  for (k in LP$lp) {
    e <- ce[lp == k & report_date <= cut]; d <- cd[lp == k & report_date <= cut]
    Fd <- lb_curve(d$lag, as.integer(cut - d$loss_date))
    h <- min(max(as.integer(cut - e$loss_date)), LMAX)
    Fe_cond <- lb_curve(e$lag, as.integer(cut - e$loss_date))
    Fe <- c(Fe_cond[1:(h + 1L)] * Fd[h + 1L], Fd[(h + 2L):(LMAX + 1L)])
    out[[k]] <- list(Fe = cummax(Fe), Fd = Fd, n_e = nrow(e), n_d = nrow(d), h = h)
  }
  out
}
blend <- function(cv, k) { z <- if (is.infinite(k)) 0 else cv$n_e / (cv$n_e + k); z * cv$Fe + (1 - z) * cv$Fd }
F_at <- function(F, days) { out <- F[pmin(pmax(days, 0L), LMAX) + 1L]; out[days < 0] <- 0; out }

# 1. Backtest at 31 Dec 2023: 2023 losses reported later (by 31 Dec 2024) -----------------------------------------
cv_bt <- curves_at(CUT)
bt <- rbindlist(lapply(LP$lp, function(k) {
  rep <- ce[lp == k & loss_date <= CUT & report_date <= CUT]
  act <- ce[lp == k & loss_date <= CUT & report_date > CUT, .N]
  rbindlist(lapply(K_GRID, function(kk) {
    F <- blend(cv_bt[[k]], kk)
    s0 <- pmax(F_at(F, as.integer(CUT - rep$loss_date)), SHARE_FLOOR); s1 <- F_at(F, as.integer(VALUATION_DATE - rep$loss_date))
    data.table(lp = k, k = kk, reported_at_cut = nrow(rep), actual_late = act, expected_late = sum((s1 - s0) / s0))
  }))
}))
w <- ce[year(loss_date) == 2023, .(cost = sum(pmin(net_cost, quantile(net_cost, 0.995)))), by = lp][, w := cost / sum(cost)]
bt <- merge(bt, w[, .(lp, w)], by = "lp", all.x = TRUE)[is.na(w), w := 0]
bt[, abs_log := abs(log((actual_late + 0.5) / (expected_late + 0.5)))]
set.seed(SEED)
wl <- unique(bt[, .(lp, actual_late, w)])
Astar <- matrix(rpois(nrow(wl) * N_BOOT, wl$actual_late), nrow(wl))
k_rank <- rbindlist(lapply(K_GRID, function(kk) {
  e <- bt[k == kk][match(wl$lp, lp), expected_late]
  boot <- colSums(abs(log((Astar + 0.5) / (e + 0.5))) * wl$w)
  data.table(k = kk, score = sum(wl$w * abs(log((wl$actual_late + 0.5) / (e + 0.5)))), se = sd(boot),
             total_ae = sum(wl$actual_late) / sum(e))
}))[order(score)]
# the simplest (most developed-weighted) k within 1 SE of the best: emerging data is thin
k_rank[, within_1se := score <= min(score) + se[which.min(score)]]
K_CHOSEN <- max(k_rank[within_1se == TRUE, k])
log_msg("Backtest: best k ", k_rank$k[1], ", chosen k ", K_CHOSEN, " (largest within 1 SE)")

# 2. Final curves at 31 Dec 2024 and market comparison --------------------------------------------------------------
cv <- curves_at(VALUATION_DATE)
pts <- c(7, 30, 90, 180, 365, 730)
cmp <- rbindlist(lapply(LP$lp, function(k) {
  c0 <- cv[[k]]; Ff <- blend(c0, K_CHOSEN)
  data.table(lp = k, claims_emerging = c0$n_e, claims_developed = c0$n_d, h_emerging_days = c0$h,
             z = if (is.infinite(K_CHOSEN)) 0 else c0$n_e / (c0$n_e + K_CHOSEN),
             median_lag_emerging = median(ce[lp == k, lag]), median_lag_developed = median(cd[lp == k, lag]),
             t(setNames(round(c0$Fe[pts + 1L], 4), paste0("F_e_", pts))), t(setNames(round(c0$Fd[pts + 1L], 4), paste0("F_d_", pts))),
             t(setNames(round(Ff[pts + 1L], 4), paste0("F_", pts))))
}))
curves_long <- rbindlist(lapply(LP$lp, function(k) data.table(lp = k, lag_days = 0:730, F_emerging = cv[[k]]$Fe[1:731],
                                                           F_developed = cv[[k]]$Fd[1:731], F_final = blend(cv[[k]], K_CHOSEN)[1:731])))

# 3. Row shares and developed actuals -----------------------------------------------------------------------------
shares <- rbindlist(lapply(LINES, function(ln) {
  tr <- read_clean_w2(paste0("emerging_train_", ln))
  s <- as.numeric(tr$period_start); e <- as.numeric(tr$period_end); v <- as.numeric(VALUATION_DATE)
  out <- tr[, .(row_id, line = ln, policy_year, exposure)]
  dev <- numeric(nrow(tr))
  for (p in PERILS[[ln]]) {
    F <- blend(cv[[paste(ln, p, sep = ".")]], K_CHOSEN); acc <- numeric(nrow(tr))
    for (q in (0:15 + 0.5) / 16) acc <- acc + F_at(F, as.integer(floor(v - (s + (e - s) * q))))
    sp <- pmax(acc / 16, SHARE_FLOOR)
    set(out, j = paste0("s_", p), value = sp)
    dev <- dev + tr[[paste0("y_cost_", p)]] / sp
  }
  out[, `:=`(y_cost = tr$y_cost, y_dev_cost = dev)]
  out
}), fill = TRUE)
write_clean_w2(shares, "emerging_report_shares")
share_summary <- melt(shares, id.vars = c("row_id", "line", "policy_year", "exposure"), measure.vars = patterns("^s_"),
                      variable.name = "peril", value.name = "share", na.rm = TRUE)[
  , .(reported_share = weighted.mean(share, exposure)), by = .(line, peril = sub("^s_", "", peril), policy_year)]
share_wide <- dcast(share_summary, line + peril ~ policy_year, value.var = "reported_share")
ult <- shares[, .(reported_cost = sum(y_cost), developed_cost = sum(y_dev_cost)), by = .(line, policy_year)][, factor := developed_cost / reported_cost]

# Outputs ----------------------------------------------------------------------------------------------------------
write_clean_w2(rbindlist(lapply(LP$lp, function(k) data.table(lp = k, lag_days = 0:LMAX, F_developed = cv[[k]]$Fd, F_final = blend(cv[[k]], K_CHOSEN)))),
               "report_lag_curves")
save_csv_w2(bt, STEP, "backtest_by_peril.csv"); save_csv_w2(k_rank, STEP, "backtest_k_ranking.csv")
save_csv_w2(cmp, STEP, "curve_comparison.csv"); save_csv_w2(curves_long, STEP, "curves_0_730_days.csv")
save_csv_w2(share_wide, STEP, "reported_share_by_year.csv"); save_csv_w2(ult, STEP, "development_factor_by_line_year.csv")
write_md_w2(list(
  "# Week 2 - Step 3: reporting pattern (IBNR), emerging market", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "by `week2/R/3_ibnr_w2.R`."), "",
  "## Method", "",
  "- **Curve per line x peril:** reporting-delay distribution, corrected for right truncation (week 1 method).",
  "- **Tail:** the emerging market has at most about 2 years of lags, so its tail comes from the developed market.",
  "- **Blend:** `F = z F_emerging + (1 - z) F_developed`, with `z = n / (n + k)`.",
  "- **Choosing k:** backtest at a 31 Dec 2023 valuation, predicting the 2023 losses reported during 2024.",
  "  The chosen k is the most developed-weighted value within 1 bootstrap SE of the best,",
  "  because the emerging data is thin and one backtest window is noisy.", "",
  "## Backtest (2023 losses reported in 2024; score = cost-weighted mean |log(A/E)|)", "",
  md_table(copy(k_rank)[, k := as.character(k)], 4), paste0("Chosen k = **", K_CHOSEN, "** (Inf = developed curve only)."), "",
  "By peril (actual vs expected late reports at the chosen k and at the two extremes):", "",
  md_table(dcast(bt[k %in% c(0, K_CHOSEN, Inf)][, k := paste0("expected_k_", k)], lp + actual_late ~ k, value.var = "expected_late"), 1),
  "## Emerging vs developed reporting (curves at 31 Dec 2024)", "",
  "`F_e_x` / `F_d_x` = share reported within x days (emerging / developed); `F_x` = blended curve used.", "",
  md_table(cmp, 3),
  "## Reported share at 31 Dec 2024 (exposure-weighted, by policy year)", "", md_table(share_wide, 4),
  "## Development: reported vs developed cost by line and policy year", "", md_table(ult, 4)
), STEP, "ibnr_report.md")
log_msg("IBNR done: k = ", K_CHOSEN, "; shares in ", file.path(PATHS_W2$clean, "emerging_report_shares.parquet"))
