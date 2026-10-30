# 4_check_ibnr_backtest.R ---------------------------------------------------------------------------------------
# One-year-ahead backtest of the IBNR count methods (backlog A), which the local D2 protocol cannot judge because the
# fold training rows are mostly mature. Pretend the valuation date is 31 Dec 2023: use only claims reported by then,
# project each 2021-23 loss quarter's reported count to 31 Dec 2024, compare with the count actually reported by then.
#   ecdf_mid   A0: lag ECDF of the earliest loss year (2021, as A0 uses the two years before the latest two), ratio
#              F(age + 1y) / F(age) at the quarter's mid-date
#   ecdf_days  A1: same ECDF averaged over the quarter's days
#   chain_ladder  A2: volume-weighted age-to-age factors on the 12-quarter count triangle, next 4 factors
# Claims: positive net cost, counted, matched (the frequency target of the WENDY engine).
# Run:  Rscript week1/R/4_check_ibnr_backtest.R      Out: week1/output/4_check_reported/ibnr_backtest.csv (+ _summary.csv)

source("week1/R/0_setup.R")
setDTthreads(2)
V1 <- as.Date("2023-12-31"); V2 <- VALUATION_DATE
cl <- read_clean("claims_matched")[counts == TRUE & !is.na(row_id) & net_cost > 0 & report_date >= loss_date,
                                   .(line, peril, loss_date, report_date, lag = as.numeric(report_date - loss_date))]
cl <- cl[loss_date >= as.Date("2021-01-01") & loss_date <= V1]
qi <- function(d) (year(d) - 2021L) * 4L + (month(d) - 1L) %/% 3L
NQ <- 12L
qs <- seq(as.Date("2021-01-01"), by = "quarter", length.out = NQ)
qe <- c(qs[-1] - 1, V1)

res <- list()
for (ln in LINES) for (pr in PERILS[[ln]]) {
  x <- cl[line == ln & peril == pr]
  seen <- x[report_date <= V1]
  if (nrow(seen) < 30) next
  actual <- x[report_date <= V2, .N, by = .(q = qi(loss_date))]
  reported <- seen[, .N, by = .(q = qi(loss_date))]
  # A0 / A1: ECDF of 2021 losses' lags as seen at V1
  F <- ecdf(seen[year(loss_date) == 2021, lag])
  ratio_mid <- ratio_days <- numeric(NQ)
  for (q in seq_len(NQ)) {
    days <- as.numeric(seq(qs[q], qe[q], by = "day"))
    age <- as.numeric(V1) - days
    mid <- mean(age)
    ratio_mid[q] <- min(F(mid + 366) / max(F(mid), 1e-3), 1 / 0.05)
    ratio_days[q] <- min(mean(F(age + 366)) / max(mean(F(age)), 1e-3), 1 / 0.05)
  }
  # A2: chain ladder at V1
  inc <- matrix(0, NQ, NQ)
  cnt <- seen[, .N, by = .(i = qi(loss_date), dev = qi(report_date) - qi(loss_date))]
  inc[cbind(cnt$i + 1L, cnt$dev + 1L)] <- cnt$N
  cum <- t(apply(inc, 1, cumsum))
  f <- vapply(seq_len(NQ - 1), function(j) { r <- seq_len(NQ - j); d <- sum(cum[r, j]); if (d > 0) sum(cum[r, j + 1]) / d else 1 }, numeric(1))
  ratio_cl <- vapply(seq_len(NQ), function(q) {
    k0 <- NQ - q + 1L                                              # latest dev (1-based column) of loss quarter q
    steps <- k0:(k0 + 3L); steps <- steps[steps <= NQ - 1L]       # next 4 factors, tail 1 beyond the triangle
    prod(f[steps])
  }, numeric(1))
  d <- data.table(line = ln, peril = pr, q = 0:(NQ - 1L), loss_quarter = format(qs))
  d[reported, on = "q", rep_v1 := i.N][actual, on = "q", act_v2 := i.N]
  d[is.na(rep_v1), rep_v1 := 0][is.na(act_v2), act_v2 := 0]
  d[, `:=`(ecdf_mid = rep_v1 * ratio_mid, ecdf_days = rep_v1 * ratio_days, chain_ladder = rep_v1 * ratio_cl)]
  res[[paste(ln, pr)]] <- d
}
res <- rbindlist(res)
res[, loss_year := 2021L + q %/% 4L]
fwrite(res, file.path(PATHS$output, "4_check_reported", "ibnr_backtest.csv"))
long <- melt(res, id.vars = c("line", "peril", "loss_year", "q", "act_v2", "rep_v1"),
             measure.vars = c("ecdf_mid", "ecdf_days", "chain_ladder"), variable.name = "method", value.name = "proj")
summ <- long[loss_year >= 2022, .(projected_over_actual = sum(proj) / sum(act_v2),
                                  reported_v1_over_actual = sum(rep_v1) / sum(act_v2),
                                  abs_err_quarters = sum(abs(proj - act_v2)) / sum(act_v2)), by = .(line, peril, loss_year, method)]
fwrite(summ, file.path(PATHS$output, "4_check_reported", "ibnr_backtest_summary.csv"))
print(dcast(summ[loss_year == 2023], line + peril ~ method, value.var = "projected_over_actual")[
  , lapply(.SD, function(v) if (is.numeric(v)) round(v, 3) else v)])
print(long[loss_year >= 2022, .(projected_over_actual = sum(proj) / sum(act_v2),
                                mean_abs_err = sum(abs(proj - act_v2)) / sum(act_v2)), by = .(loss_year, method)])
