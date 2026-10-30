# 3b_ibnr_study.R ----------------------------------------------------------------------------------
# Standalone IBNR (late-reporting) study by line x peril. Fits candidate reporting-delay methods,
# backtests them at pseudo-valuation dates, ranks them and compares the winner with SAM 3's factors.
# Needs week1/R/2_clean.R output. Run from the project root: Rscript week1/R/3b_ibnr_study.R

source("week1/R/0_setup.R")
STEP <- "3b_ibnr"

LMAX <- 3650L                    # longest lag (days) held on the curve grid
SHARE_FLOOR <- 0.05              # same floor on the reported share as SAM 3
CLAIM_CAP_Q <- 0.995
LONG_TAIL_OPEN_SHARE <- 0.15
RECENT_DAYS <- 730L
CRED_K <- c(30, 100, 300, 1000, 3000)
MIN_STRATUM <- 300L
MATERIAL_SPREAD <- 0.02          # cost-weighted spread in P(lag > 30 days) that justifies a covariate split
N_BOOT <- 200L
OVERRIDE_SE <- 2                 # per-peril method override needs this many SEs (15 perils x 6 methods tested)
COMPLEXITY <- c(M0_current = 1, M2_chain_ladder = 2, M1_truncation_km = 3, M5_recent = 4, M4_credibility = 5,
                M3_parametric = 6, M6_stratified = 7)

month_end_add <- function(d, m) seq(d + 1, by = paste(m, "months"), length.out = 2)[2] - 1
mon_idx <- function(d) year(d) * 12L + month(d)
WINDOWS <- data.table(cut = as.Date(c("2022-12-31", "2022-12-31", "2023-06-30", "2023-12-31")),
                      months = c(12L, 24L, 12L, 12L))
WINDOWS[, end := do.call(c, Map(month_end_add, cut, months))][, window := paste0(cut, "+", months, "m")]
stopifnot(all(WINDOWS$end <= VALUATION_DATE))

# Data ------------------------------------------------------------------------------------------------
log_msg("Loading claims and policy rows")
cl <- read_clean("claims_matched")[!is.na(row_id) & status != "repudiated" & net_cost > 0]
rows <- rbindlist(lapply(LINES, function(ln) {
  as.data.table(read_parquet(file.path(PATHS$clean, paste0("train_", ln, ".parquet")),
                             col_select = c("row_id", "policy_year", "period_start", "period_end", "exposure",
                                            "channel", "region", "new_business")))[, line := ln]
}))
rows[, new_business := as.character(new_business)]
cl <- merge(cl, rows[, .(line, row_id, policy_year, period_start, channel, region, new_business)], by = c("line", "row_id"))
cl[, `:=`(lag = as.integer(report_date - loss_date), lp = paste(line, peril, sep = "."))]
cl[, net_cap := pmin(net_cost, quantile(net_cost, CLAIM_CAP_Q, names = FALSE)), by = lp]
LP <- rbindlist(lapply(LINES, function(ln) data.table(line = ln, peril = PERILS[[ln]])))[, lp := paste(line, peril, sep = ".")]
wts <- cl[year(loss_date) %in% 2021:2022, .(cost = sum(net_cap), n = .N), by = lp]
wts[, `:=`(w_cost = cost / sum(cost), w_count = n / sum(n))]
log_msg(nrow(cl), " claims across ", nrow(LP), " line x peril cells")

# Curves: daily vector F[x + 1] = P(lag <= x), or a monthly chain-ladder pattern G[k + 1] -----------------
daily <- function(F) list(type = "daily", F = cummax(pmin(pmax(F, 0), 1)))

share_at <- function(curve, loss_date, at) {
  if (curve$type == "daily") {
    a <- as.integer(at - loss_date)
    out <- curve$F[pmin(pmax(a, 0L), LMAX) + 1L]
    out[a < 0] <- 0
  } else {
    k <- mon_idx(at) - mon_idx(loss_date)
    out <- rep(1, length(k))
    inr <- k < length(curve$G)
    out[inr] <- curve$G[pmax(k[inr], 0L) + 1L]
  }
  out
}

# Right-truncated reverse-time product-limit (Lynden-Bell): uses every loss year without the short-lag bias
lb_curve <- function(lag, age, w = rep(1, length(lag))) {
  dv <- numeric(LMAX + 1L); s <- rowsum(w, lag); dv[as.integer(rownames(s)) + 1L] <- s[, 1]
  av <- numeric(LMAX + 1L); s <- rowsum(w, pmin(age, LMAX)); av[as.integer(rownames(s)) + 1L] <- s[, 1]
  R <- cumsum(dv) - c(0, cumsum(av)[-(LMAX + 1L)])
  haz <- ifelse(R > 0, pmin(dv / R, 1 - 1e-12), 0)
  x <- c(log1p(-haz)[-1], 0)
  exp(rev(cumsum(rev(x))))
}

cl_pattern <- function(loss_date, report_date, cut) {
  m0 <- mon_idx(loss_date)
  cnt <- data.table(m0 = m0, k = mon_idx(report_date) - m0)[, .N, by = .(m0, k)]
  coh <- data.table(m0 = unique(m0))[, K := mon_idx(cut) - m0]
  grid <- coh[, .(k = 0:K), by = .(m0, K)]
  grid <- merge(grid, cnt, by = c("m0", "k"), all.x = TRUE)[is.na(N), N := 0]
  setorder(grid, m0, k)[, C := cumsum(N), by = m0]
  nd <- max(coh$K) + 1L
  f <- vapply(seq_len(nd - 1L) - 1L, function(j) {
    b <- grid[k == j & K >= j + 1L, sum(C)]
    if (b > 0) grid[k == j + 1L, sum(C)] / b else 1
  }, numeric(1))
  1 / rev(cumprod(rev(c(f, 1))))
}

# Discrete right-truncated MLE: P(lag = l) / P(lag <= age); best of lognormal, Weibull, 2-lognormal mix by AIC
fit_parametric <- function(lag, age) {
  pr <- data.table(l = lag, a = pmin(age, LMAX))[, .N, by = .(l, a)]
  nll <- function(p, Fc) {
    r <- suppressWarnings((Fc(pr$l + 1, p) - Fc(pr$l, p)) / Fc(pr$a + 1, p))
    if (any(!is.finite(r)) || any(r <= 0)) return(1e300)
    -sum(pr$N * log(r))
  }
  ll <- log(lag + 0.5); q <- quantile(lag + 0.5, c(0.5, 0.95), names = FALSE)
  specs <- list(
    lognormal = list(Fc = function(x, p) plnorm(x, p[1], exp(p[2])), start = c(mean(ll), log(max(sd(ll), 0.1)))),
    weibull = list(Fc = function(x, p) pweibull(x, exp(p[1]), exp(p[2])), start = c(log(0.7), log(q[1] * 1.5))),
    lognormal_mix = list(Fc = function(x, p) {
      w <- plogis(p[1]); w * plnorm(x, p[2], exp(p[3])) + (1 - w) * plnorm(x, p[4], exp(p[5]))
    }, start = c(1.5, log(q[1]), 0, log(q[2]), 0)))
  fits <- lapply(specs, function(sp) {
    o <- optim(sp$start, nll, Fc = sp$Fc, control = list(maxit = 4000))
    list(par = o$par, aic = 2 * o$value + 2 * length(sp$start), Fc = sp$Fc)
  })
  aic <- vapply(fits, `[[`, numeric(1), "aic")
  best <- fits[[which.min(aic)]]
  list(F = best$Fc(0:LMAX + 1, best$par), dist = names(fits)[which.min(aic)], aic = aic)
}

shared_perils <- names(which(table(unlist(PERILS)) > 1))
pool_of <- function(line, peril) ifelse(peril %in% shared_perils, paste0("peril.", peril), paste0("line.", line))

fit_methods <- function(d, cut, cov6 = NULL) {
  d <- copy(d)[, `:=`(age = as.integer(cut - loss_date), pool = pool_of(line, peril))]
  by_lp <- split(d, by = "lp")
  m0 <- lapply(by_lp, function(x) {
    ref <- x[year(loss_date) <= year(cut) - 2]
    if (!nrow(ref)) ref <- x[year(loss_date) == min(year(loss_date))]
    daily(ecdf(ref$lag)(0:LMAX))
  })
  m1 <- lapply(by_lp, function(x) daily(lb_curve(x$lag, x$age)))
  m2 <- lapply(by_lp, function(x) list(type = "monthly", G = cl_pattern(x$loss_date, x$report_date, cut)))
  m3f <- lapply(by_lp, function(x) fit_parametric(x$lag, x$age))
  m5 <- lapply(names(by_lp), function(k) {
    r <- by_lp[[k]][loss_date > cut - RECENT_DAYS]
    if (nrow(r) < MIN_STRATUM) return(m1[[k]])
    F1 <- m1[[k]]$F
    daily(c(lb_curve(r$lag, r$age)[1:RECENT_DAYS] * F1[RECENT_DAYS], F1[(RECENT_DAYS + 1L):(LMAX + 1L)]))
  })
  names(m5) <- names(by_lp)
  pools <- lapply(split(d, by = "pool"), function(x) lb_curve(x$lag, x$age))
  out <- list(M0_current = list(curves = m0), M1_truncation_km = list(curves = m1),
              M2_chain_ladder = list(curves = m2), M3_parametric = list(curves = lapply(m3f, function(f) daily(f$F))),
              M5_recent = list(curves = m5))
  for (k in CRED_K) {
    out[[paste0("M4_k", k)]] <- list(curves = lapply(by_lp, function(x) {
      z <- nrow(x) / (nrow(x) + k)
      daily(z * m1[[x$lp[1]]]$F + (1 - z) * pools[[x$pool[1]]])
    }))
  }
  if (!is.null(cov6)) {
    strata <- d[, .N, by = c("lp", cov6)][N >= MIN_STRATUM]
    sc <- lapply(seq_len(nrow(strata)), function(i) {
      x <- d[lp == strata$lp[i] & get(cov6) == strata[[cov6]][i]]
      daily(lb_curve(x$lag, x$age))
    })
    names(sc) <- paste(strata$lp, strata[[cov6]], sep = "|")
    out$M6_stratified <- list(curves = c(m1, sc), by = cov6)
  }
  attr(out, "parametric") <- rbindlist(lapply(names(m3f), function(k) {
    data.table(lp = k, chosen = m3f[[k]]$dist, t(m3f[[k]]$aic))
  }))
  out
}

fit_share <- function(fit, d, at) {
  key <- d$lp
  if (!is.null(fit$by)) {
    k2 <- paste(d$lp, d[[fit$by]], sep = "|")
    key <- fifelse(k2 %in% names(fit$curves), k2, key)
  }
  out <- numeric(nrow(d))
  for (k in unique(key)) {
    i <- which(key == k)
    out[i] <- share_at(fit$curves[[k]], d$loss_date[i], at)
  }
  out
}

# Diagnostics needed before the backtest: covariate effects on reporting lag --------------------------------
log_msg("Diagnostic: covariates on reporting lag")
mature <- cl[loss_date <= VALUATION_DATE - 365]
mature[, `:=`(late = lag > 30, loss_month = month(loss_date))]
mature[, size_band := ceiling(4 * frank(net_cap, ties.method = "first") / .N), by = lp]
COVS <- c("channel", "region", "new_business")
lag_cov <- rbindlist(lapply(split(mature, by = "lp"), function(x) rbindlist(lapply(c(COVS, "loss_month", "size_band"), function(cv) {
  g <- x[, .(n = .N, late = sum(late)), by = .(level = as.character(get(cv)))]
  if (nrow(g) < 2 || sum(g$late) == 0) return(NULL)
  fit <- suppressWarnings(glm(cbind(late, n - late) ~ level, family = binomial, data = g))
  lr <- fit$null.deviance - fit$deviance
  gg <- g[n >= 200]
  data.table(lp = x$lp[1], covariate = cv, levels = nrow(g), share_late_30d = sum(g$late) / sum(g$n),
             lr_chisq = lr, df = nrow(g) - 1L, p_value = pchisq(lr, nrow(g) - 1L, lower.tail = FALSE),
             min_share = if (nrow(gg)) min(gg$late / gg$n) else NA_real_,
             max_share = if (nrow(gg)) max(gg$late / gg$n) else NA_real_)
}))))
lag_cov[, spread := max_share - min_share]
save_csv(lag_cov, STEP, "lag_covariates.csv")
cov_score <- merge(lag_cov[covariate %in% COVS & p_value < 0.01], wts[, .(lp, w_cost)], by = "lp")[
  , .(score = sum(w_cost * spread, na.rm = TRUE)), by = covariate][order(-score)]
COV6 <- if (nrow(cov_score) && cov_score$score[1] > MATERIAL_SPREAD) cov_score$covariate[1] else NULL
log_msg("M6 stratifier: ", if (is.null(COV6)) "none (no material covariate)" else COV6)

# Backtest -------------------------------------------------------------------------------------------------
cells <- list(); parametric_choice <- list(); fits_bt <- list()
for (wi in seq_len(nrow(WINDOWS))) {
  W <- WINDOWS[wi]
  log_msg("Backtest ", W$window)
  d <- cl[report_date <= W$cut]
  fits <- fit_methods(d, W$cut, COV6)
  fits_bt[[W$window]] <- fits
  parametric_choice[[W$window]] <- attr(fits, "parametric")[, window := W$window]
  sev <- d[, .(sev = mean(net_cap)), by = .(lp, lm = mon_idx(loss_date))]
  act <- cl[loss_date <= W$cut & report_date > W$cut & report_date <= W$end,
            .(actual = .N, actual_cost = sum(net_cap)), by = .(lp, lm = mon_idx(loss_date))]
  for (m in names(fits)) {
    s0 <- fit_share(fits[[m]], d, W$cut); s1 <- fit_share(fits[[m]], d, W$end)
    pr <- d[, .(pred = sum((s1[.I] - s0[.I]) / pmax(s0[.I], SHARE_FLOOR)), reported = .N), by = .(lp, lm = mon_idx(loss_date))]
    x <- merge(merge(pr, act, by = c("lp", "lm"), all = TRUE), sev, by = c("lp", "lm"), all.x = TRUE)
    for (cn in c("pred", "reported", "actual", "actual_cost", "sev")) set(x, which(is.na(x[[cn]])), cn, 0)
    x[, `:=`(pred_cost = pred * sev, window = W$window, method = m, latest_year = lm > mon_idx(W$cut) - 12L)]
    cells[[paste(W$window, m)]] <- x
  }
}
cells <- rbindlist(cells)
cells[, loss_month := sprintf("%d-%02d", (lm - 1L) %/% 12L, (lm - 1L) %% 12L + 1L)]
pois_dev <- function(a, e) 2 * (ifelse(a > 0, a * log(a / pmax(e, 1e-9)), 0) - (a - e))

lat <- cells[latest_year == TRUE, .(A = sum(actual), E = sum(pred), A_cost = sum(actual_cost), E_cost = sum(pred_cost)),
             by = .(window, method, lp)]
lat[, abs_log := abs(log((A + 0.5) / (E + 0.5)))]
dev <- cells[, .(poisson_dev = sum(pois_dev(actual, pred))), by = .(window, method, lp)]
lat <- merge(merge(lat, dev, by = c("window", "method", "lp")), wts[, .(lp, w_cost, w_count)], by = "lp")

# Credibility k chosen leaving the scored window out
k_tab <- lat[startsWith(method, "M4_k"), .(primary = sum(w_cost * abs_log)), by = .(window, method)]
save_csv(k_tab, STEP, "credibility_k_tuning.csv")
k_pick <- rbindlist(lapply(WINDOWS$window, function(w) {
  data.table(window = w, method_src = k_tab[window != w, .(s = mean(primary)), by = method][which.min(s), method])
}))
K_ALL <- k_tab[, .(s = mean(primary)), by = method][which.min(s), method]
pick <- function(dt) {
  m4 <- merge(dt[startsWith(method, "M4_k")], k_pick, by.x = c("window", "method"), by.y = c("window", "method_src"))
  rbind(dt[!startsWith(method, "M4_k")], m4[, method := "M4_credibility"], use.names = TRUE)
}
lat <- pick(lat); cells <- pick(cells)
save_csv(cells[, .(window, method, lp, loss_month, latest_year, reported, pred, actual, pred_cost, actual_cost)],
         STEP, "backtest_cells.csv")
save_csv(lat, STEP, "backtest_metrics.csv")

# Ranking, with a Poisson bootstrap on the actual late-reported counts (paired across methods)
set.seed(SEED)
wl <- unique(lat[, .(window, lp, A)])
Astar <- matrix(rpois(nrow(wl) * N_BOOT, wl$A), nrow(wl), N_BOOT)
boot_abs <- function(m) {
  e <- lat[method == m][wl, on = .(window, lp)]
  abs(log((Astar + 0.5) / (e$E + 0.5)))
}
w_idx <- match(wl$window, WINDOWS$window); wc <- wts$w_cost[match(wl$lp, wts$lp)]
methods <- unique(lat$method)
boot_abs_m <- setNames(lapply(methods, boot_abs), methods)
boot_primary <- sapply(methods, function(m) colMeans(rowsum(boot_abs_m[[m]] * wc, w_idx) / rowsum(wc, w_idx)[, 1]))
ranking <- lat[, .(primary = sum(w_cost * abs_log) / sum(w_cost), count_weighted = sum(w_count * abs_log) / sum(w_count),
                   bias_cost_w = sum(w_cost * (E / pmax(A, 1) - 1)) / sum(w_cost),
                   cost_ae = sum(A_cost) / sum(E_cost), poisson_dev = sum(poisson_dev)), by = .(window, method)][
  , lapply(.SD, mean), by = method, .SDcols = !"window"]
ranking[, `:=`(se = apply(boot_primary[, method, drop = FALSE], 2, sd),
               diff_vs_M0 = primary - primary[method == "M0_current"],
               diff_vs_M0_se = apply(boot_primary[, method, drop = FALSE] - boot_primary[, "M0_current"], 2, sd),
               poisson_dev_vs_M0 = poisson_dev / poisson_dev[method == "M0_current"],
               complexity = COMPLEXITY[method])]
setorder(ranking, primary)[, rank := .I]
best <- ranking$method[1]
ranking[, within_1se_of_best := primary <= ranking$primary[1] + ranking$se[1]]
WINNER <- ranking[within_1se_of_best == TRUE][order(complexity), method[1]]
ranking[, selected := method == WINNER]
by_window <- dcast(lat[, .(primary = sum(w_cost * abs_log) / sum(w_cost)), by = .(window, method)], method ~ window,
                   value.var = "primary")
ranking <- merge(ranking, by_window, by = "method")[order(rank)]
save_csv(ranking, STEP, "method_ranking.csv")
log_msg("Best primary: ", best, "; selected (simplest within 1 SE): ", WINNER)

# Per-peril override when another method beats the winner by more than OVERRIDE_SE bootstrap SEs
per_lp <- lat[, .(abs_log = mean(abs_log), A = sum(A), E = sum(E)), by = .(lp, method)]
lp_idx <- match(wl$lp, LP$lp)
lp_boot <- function(m) rowsum(boot_abs_m[[m]], lp_idx) / as.vector(table(lp_idx))
per_lp_best <- rbindlist(lapply(LP$lp, function(k) {
  x <- per_lp[lp == k][order(abs_log)]
  i <- match(match(k, LP$lp), sort(unique(lp_idx)))
  dse <- sd(lp_boot(x$method[1])[i, ] - lp_boot(WINNER)[i, ])
  gain <- x[method == WINNER, abs_log] - x$abs_log[1]
  data.table(lp = k, winner_abs_log = x[method == WINNER, abs_log], best_method = x$method[1],
             best_abs_log = x$abs_log[1], gain = gain, gain_se = dse,
             use_method = if (x$method[1] != WINNER && gain > OVERRIDE_SE * dse) x$method[1] else WINNER)
}))
save_csv(per_lp_best, STEP, "per_peril_selection.csv")

# Factors at the real valuation date -------------------------------------------------------------------------
log_msg("Fitting all methods at ", VALUATION_DATE)
fitsV <- fit_methods(cl, VALUATION_DATE, COV6)
parametric_choice[["valuation"]] <- attr(fitsV, "parametric")[, window := "valuation"]
save_csv(rbindlist(parametric_choice), STEP, "parametric_choice.csv")
fitsV$M4_credibility <- fitsV[[K_ALL]]
fitsV <- fitsV[setdiff(names(fitsV), paste0("M4_k", CRED_K))]

shV <- sapply(names(fitsV), function(m) fit_share(fitsV[[m]], cl, VALUATION_DATE))
factors <- rbindlist(lapply(names(fitsV), function(m) {
  cl[, .(method = m, claims = .N, reported_share = mean(shV[.I, m]), ibnr_factor = mean(1 / pmax(shV[.I, m], SHARE_FLOOR))),
     by = .(line, peril, policy_year)]
}))
setorder(factors, method, line, peril, policy_year)
save_csv(factors, STEP, "ibnr_factors_by_method.csv")

open_share <- cl[, .(open_share = mean(status == "open")), by = .(line, peril, policy_year)]
long_tail <- open_share[policy_year == 2023 & open_share > LONG_TAIL_OPEN_SHARE, .(line, peril)][, long_tail := TRUE]
use <- per_lp_best[, .(lp, method = use_method)]
recommended <- merge(factors[, lp := paste(line, peril, sep = ".")], use, by = c("lp", "method"))
recommended <- merge(recommended, open_share, by = c("line", "peril", "policy_year"))
recommended <- merge(recommended, long_tail, by = c("line", "peril"), all.x = TRUE)[is.na(long_tail), long_tail := FALSE]
save_csv(recommended[, .(line, peril, policy_year, claims, ibnr_factor, open_share, long_tail)], STEP, "recommended_ibnr.csv")
save_csv(recommended[, .(line, peril, method)][, unique(.SD)], STEP, "recommended_method_by_peril.csv")

# Share of a loss on each calendar day reported by the valuation date: row-level effective exposure in SAM 4
loss_days <- seq(as.Date("2021-01-01"), VALUATION_DATE, by = "day")
daily_share <- rbindlist(lapply(seq_len(nrow(use)), function(i) {
  data.table(lp = use$lp[i], method = use$method[i], date = loss_days,
             share = pmax(share_at(fitsV[[use$method[i]]]$curves[[use$lp[i]]], loss_days, VALUATION_DATE), SHARE_FLOOR))
}))
daily_share <- merge(daily_share, LP, by = "lp")[order(line, peril, date)]
save_csv(daily_share[, .(line, peril, method, date, share)], STEP, "recommended_daily_share.csv")

# Comparison with SAM 3 -----------------------------------------------------------------------------------
sam03_file <- file.path("data", "week_1", "sam03", "ibnr.csv")
m0_check <- NA_real_
comparison <- recommended[, .(line, peril, policy_year, claims, method, recommended_factor = ibnr_factor)]
if (file.exists(sam03_file)) {
  sam03 <- fread(sam03_file)[, .(line, peril, policy_year, sam03_claims = claims, sam03_factor = ibnr_factor)]
  m0 <- merge(factors[method == "M0_current", .(line, peril, policy_year, claims, ibnr_factor)], sam03,
              by = c("line", "peril", "policy_year"))
  m0_check <- m0[, max(abs(ibnr_factor - sam03_factor))]
  log_msg("M0 replica vs data/week_1/sam03/ibnr.csv: max |factor diff| = ", signif(m0_check, 3),
          ", claim count mismatches = ", m0[claims != sam03_claims, .N])
  comparison <- merge(comparison, sam03, by = c("line", "peril", "policy_year"), all.x = TRUE)
  comparison[, `:=`(diff = recommended_factor - sam03_factor, pct_change = 100 * (recommended_factor / sam03_factor - 1))]
}
save_csv(comparison[order(line, peril, policy_year)], STEP, "comparison_vs_sam03.csv")

expo <- rows[, .(exposure = sum(exposure)), by = .(line, policy_year)]
freq_dev <- rbind(factors[method == "M0_current"][, basis := "sam03_m0"],
                  merge(factors, use, by = c("lp", "method"))[, basis := "recommended"], use.names = TRUE)
freq_dev <- freq_dev[, .(developed_claims = sum(claims * ibnr_factor), reported_claims = sum(claims)), by = .(line, policy_year, basis)]
freq_dev <- dcast(merge(freq_dev, expo, by = c("line", "policy_year"))[
  , `:=`(frequency_reported = reported_claims / exposure, frequency_developed = developed_claims / exposure)],
  line + policy_year + frequency_reported ~ basis, value.var = "frequency_developed")
save_csv(freq_dev, STEP, "frequency_developed.csv")

# Diagnostics: cost side ---------------------------------------------------------------------------------------
log_msg("Diagnostics: severity by lag, cost-weighted factors, open claims")
lag_breaks <- c(-1, 7, 30, 90, 180, 365, Inf)
lag_labels <- c("0-7", "8-30", "31-90", "91-180", "181-365", "366+")
sev_lag <- cl[status == "closed" & year(loss_date) %in% 2021:2022,
              .(n = .N, mean_net_capped = mean(net_cap)), by = .(lp, lag_band = cut(lag, lag_breaks, lag_labels))]
sev_lag[, rel_to_peril_mean := mean_net_capped / (sum(mean_net_capped * n) / sum(n)), by = lp]
save_csv(sev_lag[order(lp, lag_band)], STEP, "severity_by_lag.csv")

ageV <- as.integer(VALUATION_DATE - cl$loss_date)
cost_count <- rbindlist(lapply(split(cl[, .(lp, line, peril, policy_year, lag, net_cap, i = .I)], by = "lp"), function(x) {
  Fn <- lb_curve(x$lag, ageV[x$i]); Fw <- lb_curve(x$lag, ageV[x$i], x$net_cap)
  sn <- Fn[pmin(ageV[x$i], LMAX) + 1L]; sw <- Fw[pmin(ageV[x$i], LMAX) + 1L]
  x[, .(claims = .N, count_factor = mean(1 / pmax(sn[.I], SHARE_FLOOR)),
        cost_factor = sum(net_cap / pmax(sw[.I], SHARE_FLOOR)) / sum(net_cap)), by = .(line, peril, policy_year)]
}))
cost_count[, implied_severity_adjustment := cost_factor / count_factor]
save_csv(cost_count[order(line, peril, policy_year)], STEP, "cost_vs_count_factors.csv")

open_check <- cl[, .(claims = .N, open_share = mean(status == "open"),
                     sev_closed = mean(net_cap[status == "closed"]), sev_open = mean(net_cap[status == "open"]),
                     paid_to_incurred_open = sum(paid_to_date[status == "open"]) / sum(incurred_to_date[status == "open"])),
                 by = .(line, peril, policy_year)]
open_check[, open_to_closed_sev := sev_open / sev_closed]
save_csv(open_check[order(line, peril, policy_year)], STEP, "open_claims_check.csv")

# Diagnostics: granularity (row-level vs policy-year factors) -----------------------------------------------------
log_msg("Diagnostics: row-level factors")
row_method <- if (fitsV[[WINNER]]$curves[[1]]$type == "daily" && is.null(fitsV[[WINNER]]$by)) WINNER else "M1_truncation_km"
Wc <- WINDOWS[cut == max(cut)]
fit_c <- fits_bt[[Wc$window]][[if (WINNER == "M4_credibility") k_pick[window == Wc$window, method_src] else WINNER]]
pyc <- year(Wc$cut)
dc <- cl[report_date <= Wc$cut & policy_year == pyc]
dc[, ratio := {s0 <- fit_share(fit_c, dc, Wc$cut); (fit_share(fit_c, dc, Wc$end) - s0) / pmax(s0, SHARE_FLOOR)}]
dc[, ratio_year := mean(ratio), by = lp]
row_cal <- merge(dc[, .(reported = .N, E_claim_level = sum(ratio), E_year_level = sum(ratio_year)),
                    by = .(lp, start_quarter = quarter(period_start))],
                 cl[policy_year == pyc & report_date > Wc$cut & report_date <= Wc$end, .(actual = .N),
                    by = .(lp, start_quarter = quarter(period_start))], by = c("lp", "start_quarter"), all = TRUE)
for (cn in c("reported", "E_claim_level", "E_year_level", "actual")) set(row_cal, which(is.na(row_cal[[cn]])), cn, 0)
row_cal[, `:=`(window = Wc$window, method = WINNER, ae_claim_level = actual / E_claim_level, ae_year_level = actual / E_year_level)]
save_csv(row_cal[order(lp, start_quarter)], STEP, "row_level_calibration.csv")

rv <- rows[policy_year >= 2023]
a_hi <- as.integer(VALUATION_DATE - rv$period_start); a_lo <- as.integer(VALUATION_DATE - rv$period_end)
row_fac <- rbindlist(lapply(seq_len(nrow(LP)), function(j) {
  idx <- which(rv$line == LP$line[j])
  CF <- cumsum(fitsV[[row_method]]$curves[[LP$lp[j]]]$F)
  S <- function(x) ifelse(x < 0, 0, CF[pmin(x, LMAX) + 1L])
  sub <- rv[idx][, sh := (S(a_hi[idx]) - S(a_lo[idx] - 1L)) / (a_hi[idx] - a_lo[idx] + 1L)]
  sub[, .(exposure = sum(exposure), row_level_factor = sum(exposure) / sum(exposure * pmax(sh, SHARE_FLOOR))),
      by = .(policy_year, start_quarter = quarter(period_start))][, `:=`(line = LP$line[j], peril = LP$peril[j])]
}))
row_fac <- merge(row_fac, factors[method == row_method, .(line, peril, policy_year, policy_year_factor = ibnr_factor)],
                 by = c("line", "peril", "policy_year"))
row_fac[, method := row_method]
save_csv(row_fac[order(line, peril, policy_year, start_quarter)], STEP, "row_level_factors.csv")

# Plots -------------------------------------------------------------------------------------------------------
xs <- c(0:30, seq(35, 1460, by = 5))
curve_dt <- rbindlist(lapply(names(fitsV), function(m) rbindlist(lapply(LP$lp, function(k) {
  cv <- fitsV[[m]]$curves[[k]]
  if (cv$type == "daily") data.table(method = m, lp = k, lag = xs, share = cv$F[xs + 1L])
  else data.table(method = m, lp = k, lag = (seq_along(cv$G) - 0.5) * 30.4375, share = cv$G)
}))))
p <- ggplot(curve_dt[lag <= 1460], aes(lag, share, colour = method)) + geom_line() + facet_wrap(~lp, ncol = 5) +
  scale_x_continuous(trans = "log1p", breaks = c(0, 7, 30, 90, 365, 1460)) +
  labs(title = paste("Reporting-delay curves at", VALUATION_DATE), x = "days from loss to report", y = "share reported")
save_plot(p, STEP, "plots/lag_curves_by_method.png", width = 16, height = 9)

p <- ggplot(melt(by_window, id.vars = "method", variable.name = "window", value.name = "primary"),
            aes(method, primary, fill = window)) + geom_col(position = "dodge") + coord_flip() +
  labs(title = "Backtest: cost-weighted mean |log(A/E)| of late-reported counts (lower is better)", x = NULL, y = NULL)
save_plot(p, STEP, "plots/backtest_by_method.png")

if ("sam03_factor" %in% names(comparison)) {
  cmp <- melt(comparison[policy_year %in% 2023:2024, .(lp = paste(line, peril, sep = "."), policy_year, sam03_factor, recommended_factor)],
              id.vars = c("lp", "policy_year"), variable.name = "basis", value.name = "ibnr_factor")
  p <- ggplot(cmp, aes(lp, ibnr_factor, fill = basis)) + geom_col(position = "dodge") + coord_flip() + facet_wrap(~policy_year) +
    labs(title = "IBNR factors: SAM 3 vs recommended", x = NULL, y = NULL)
  save_plot(p, STEP, "plots/factors_sam03_vs_recommended.png", height = 7)
}

# Report --------------------------------------------------------------------------------------------------------
rk <- ranking[, .(rank, method, primary, se, diff_vs_M0, diff_vs_M0_se, count_weighted, bias_cost_w, cost_ae,
                  poisson_dev_vs_M0, selected)]
cmp24 <- if ("sam03_factor" %in% names(comparison)) comparison[policy_year == 2024, .(line, peril, method, sam03_factor, recommended_factor, pct_change)] else comparison[policy_year == 2024]
write_md(list(
  "# Step 3b - IBNR method study", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/3b_ibnr_study.R`. Standalone; not used by any model yet."), "",
  "## Backtest design",
  "Each method is fitted on claims reported by a pseudo-valuation date and predicts, per claim, the late-reported count",
  "(F(cut + h - t) - F(cut - t)) / max(F(cut - t), 0.05). Actual = claims reported in (cut, cut + h], fully observed at 2024-12-31.",
  paste("Windows:", paste(WINDOWS$window, collapse = ", ")),
  "Primary metric: mean over windows of the cost-weighted (2021-22 capped cost share) |log((A + 0.5) / (E + 0.5))| over line x peril,",
  "for losses in the 12 months before the cut. SE: Poisson bootstrap on the actual counts (process noise only, paired across methods).", "",
  "## Ranking", md_table(rk, 4),
  paste0("Selected: **", WINNER, "** (simplest method within 1 SE of the best, ", best, ")."),
  paste0("Credibility k (all windows): ", K_ALL, ". M6 stratifier: ", if (is.null(COV6)) "none" else COV6, "."), "",
  "## Per-peril selection", paste0("Override only when another method beats the winner by more than ", OVERRIDE_SE, " bootstrap SEs."), "",
  md_table(per_lp_best, 4),
  "## Replication of SAM 3", paste0("M0 at 2024-12-31 vs `data/week_1/sam03/ibnr.csv`: max |factor difference| = ", signif(m0_check, 3), "."), "",
  "## Policy-year 2024 factors: SAM 3 vs recommended", md_table(cmp24, 4),
  "## Diagnostics",
  "- `cost_vs_count_factors.csv`: cost-weighted / count-weighted factor = implied severity adjustment for late claims (diagnostic only).",
  "- `severity_by_lag.csv`: mean capped severity of closed 2021-22 claims by report lag.",
  "- `open_claims_check.csv`: open vs closed severity; open-claim case development is not estimable from one valuation.",
  "- `row_level_calibration.csv` / `row_level_factors.csv`: claim-level vs policy-year factors by policy start quarter.",
  "- `lag_covariates.csv`: covariate effects on P(lag > 30 days) for losses at least a year old.",
  "", "## Caveats",
  "- Only counts are backtested; incurred values as at an earlier date cannot be rebuilt from one snapshot.",
  "- Tails beyond the observed lag range (about 4 years) are untested; M3 extrapolates, the others assume none.",
  "- Covariate choice for M6 and the credibility k for the final factors use all data (mild look-ahead)."
), STEP, "report.md")
log_msg("Done: week1/output/", STEP)
