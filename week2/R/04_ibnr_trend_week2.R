# 04_ibnr_trend_week2.R ---------------------------------------------------------------------------
# Purpose : Reporting patterns (IBNR) and trends for week 2.
#           IBNR: chain ladder on reported claim counts per peril from the DEVELOPED book (loss quarter x development
#           quarter, 2021-24 losses, volume-weighted factors, tail 1), as the week 1 C5 engine (week1/R/4_models_iterwendy07.R
#           section 1, copied logic); subsidence uses the lag ECDF averaged over the row's days (C5 override). Both
#           markets share the 31 Dec 2024 valuation date, so emerging 2023-24 losses are censored exactly like
#           developed 2023-24 losses: their lags are compared directly (same loss years), and an emerging-only chain
#           ladder (8 quarters) is computed as a check.
#           Trends: developed frequency (ultimate) and severity (capped p99.5) by year 2021-24, log-linear per peril;
#           emerging 2023 -> 2024 alongside; chosen trend = developed prior (emerging 1-year change too noisy to
#           carry weight beyond credibility Z = n / (n + k)); sensitivities.
# Inputs  : data/week_2/optionB/clean/{developed,emerging}_claims_matched.parquet, {market}_train_<line>.parquet
# Outputs : week2/output/04_ibnr_trend/ report_share_quarter.csv, lag_comparison.csv, emerging_chain_ladder_check.csv,
#           trend_table.csv, ibnr_trend_report.md
# Run     : Rscript week2/R/04_ibnr_trend_week2.R      (from the repo root)
# Time    : under 1 minute

source("week2/R/00_setup_week2.R")
start_script("04_ibnr_trend_week2.R")
STEP <- "04_ibnr_trend"
CAP_Q <- 0.995
CRED_K_SEV <- 2000   # claims for full credibility weight 0.5 on a 1-year severity change (judgement)
CRED_K_FREQ <- 2000

clp <- list(developed = claim_basis("developed"), emerging = claim_basis("emerging"))

# 1. Chain ladder per peril, quarter grid 2021Q1..2024Q4 -------------------------------------------------------
chain_ladder <- function(cl, first_year, last_year = 2024) {
  nq <- (last_year - first_year + 1) * 4L
  qi <- function(d) (year(d) - first_year) * 4L + (month(d) - 1L) %/% 3L
  x <- cl[loss_year >= first_year & lag >= 0, .(i = qi(loss_date), dev = qi(report_date) - qi(loss_date))]
  inc <- matrix(0, nq, nq)
  cnt <- x[, .N, by = .(i, dev)]
  inc[cbind(cnt$i + 1L, cnt$dev + 1L)] <- cnt$N
  cum <- t(apply(inc, 1, cumsum))
  f <- vapply(seq_len(nq - 1), function(j) { r <- seq_len(nq - j); den <- sum(cum[r, j]); if (den > 0) sum(cum[r, j + 1]) / den else 1 }, 1)
  cdf <- vapply(seq_len(nq), function(i) prod(f[seq_len(nq - 1) >= nq - i + 1]), 1)
  qs <- seq(as.Date(paste0(first_year, "-01-01")), by = "quarter", length.out = nq)
  data.table(q_start = qs, q_end = c(qs[-1] - 1, VALUATION_DATE), reported = cum[cbind(seq_len(nq), nq - seq_len(nq) + 1L)],
             cdf = cdf, share_cl = pmax(1 / cdf, MIN_SHARE))
}
# ECDF of 2021-22 developed lags, averaged over the days of each quarter (for subsidence, as C5's override)
ecdf_quarter <- function(lags, qtab) {
  F <- ecdf(lags); V <- as.numeric(VALUATION_DATE)
  vapply(seq_len(nrow(qtab)), function(q) mean(F(V - seq(as.numeric(qtab$q_start[q]), as.numeric(qtab$q_end[q])))), 1)
}

shares <- list(); em_cl <- list()
for (ln in LINES) for (pr in PERILS[[ln]]) {
  d <- clp$developed[line == ln & peril == pr]
  q <- chain_ladder(d, 2021)
  q[, share_ecdf := pmax(ecdf_quarter(d[loss_year %in% 2021:2022 & lag >= 0, lag], q), MIN_SHARE)]
  q[, method := if (pr == "subsidence") "ecdf_days" else "chain_ladder"]
  q[, share := if (pr == "subsidence") share_ecdf else share_cl]
  shares[[paste(ln, pr)]] <- q[, `:=`(line = ln, peril = pr)]
  e <- clp$emerging[line == ln & peril == pr]
  if (nrow(e) >= 30) {
    eq <- chain_ladder(e, 2023)
    em_cl[[paste(ln, pr)]] <- merge(eq[, .(q_start, em_reported = reported, em_share = share_cl)],
                                    q[, .(q_start, dev_share = share)], by = "q_start")[, `:=`(line = ln, peril = pr)]
  }
}
shares <- rbindlist(shares)
setcolorder(shares, c("line", "peril", "q_start", "q_end", "method", "share"))
shares[, `:=`(q_start = format(q_start), q_end = format(q_end))]
save_csv(shares, STEP, "report_share_quarter.csv")
em_cl <- rbindlist(em_cl)
save_csv(em_cl, STEP, "emerging_chain_ladder_check.csv")

# 2. Lags: emerging vs developed for the SAME loss years (same censoring) ------------------------------------------
lag_cmp <- rbindlist(lapply(c(2023L, 2024L), function(ly) rbindlist(lapply(LINES, function(ln) rbindlist(lapply(PERILS[[ln]], function(pr) {
  a <- clp$developed[line == ln & peril == pr & loss_year == ly, lag]
  b <- clp$emerging[line == ln & peril == pr & loss_year == ly, lag]
  if (length(b) < 5) return(NULL)
  ks <- suppressWarnings(ks.test(a, b))
  data.table(loss_year = ly, line = ln, peril = pr, n_dev = length(a), n_em = length(b),
             median_dev = median(a), median_em = median(b), p90_dev = quantile(a, 0.9, names = FALSE), p90_em = quantile(b, 0.9, names = FALSE),
             ks_stat = unname(ks$statistic), ks_p = ks$p.value)
}))))))
save_csv(lag_cmp, STEP, "lag_comparison.csv")

# Emerging-implied vs developed share per loss year (exposure-free check: emerging share of the year's ultimate)
yr_share <- function(sh, ly) sh[year(as.Date(q_start)) == ly, mean(share)]
ibnr_year <- shares[, .(share_2023 = mean(share[year(as.Date(q_start)) == 2023]), share_2024 = mean(share[year(as.Date(q_start)) == 2024])),
                    by = .(line, peril, method)]
ibnr_year[, `:=`(ibnr_factor_2023 = 1 / share_2023, ibnr_factor_2024 = 1 / share_2024)]
if (nrow(em_cl)) ibnr_year <- merge(ibnr_year, em_cl[, .(em_share_2024 = mean(em_share[year(q_start) == 2024])), by = .(line, peril)],
                                    by = c("line", "peril"), all.x = TRUE)
save_csv(ibnr_year, STEP, "ibnr_by_year.csv")

# 3. Trends -------------------------------------------------------------------------------------------------------------
loglin <- function(yr, v, w) { ok <- v > 0 & w > 0; if (length(unique(yr[ok])) < 2) return(NA_real_); exp(coef(lm(log(v[ok]) ~ yr[ok], weights = w[ok]))[[2]]) - 1 }
trend_rows <- list()
for (mk in names(clp)) for (ln in LINES) {
  pol <- read_w2(file.path(W2$clean, sprintf("%s_train_%s.parquet", mk, ln)))[, .(row_id, period_start, period_end, exposure, policy_year)]
  for (pr in PERILS[[ln]]) {
    sh <- row_report_share(shares, ln, pr, pol$period_start, pol$period_end)
    c1 <- merge(clp[[mk]][line == ln & peril == pr], pol[, .(row_id, policy_year)], by = "row_id")
    cap <- quantile(clp$developed[line == ln & peril == pr, cost], CAP_Q, names = FALSE)
    fy <- data.table(policy_year = pol$policy_year, e = pol$exposure, eu = pol$exposure * sh)[, .(exposure = sum(e), eff = sum(eu)), by = policy_year]
    cy <- c1[, .(claims = .N, sev_capped = mean(pmin(cost, cap)), sev_closed_capped = mean(pmin(cost[status == "closed"], cap))), by = policy_year]
    y <- merge(fy, cy, by = "policy_year", all.x = TRUE)
    y[is.na(claims), claims := 0]
    y[, `:=`(freq_ult = claims / eff, market = mk, line = ln, peril = pr)]
    trend_rows[[paste(mk, ln, pr)]] <- y
  }
}
ty <- rbindlist(trend_rows)
save_csv(ty, STEP, "experience_by_year_ultimate.csv")

long_tail <- c("bodily_injury", "subsidence")
tr <- ty[market == "developed", .(dev_freq_trend = loglin(policy_year, freq_ult, claims),
                                  dev_sev_trend = loglin(policy_year[!(peril %in% long_tail & policy_year == 2024)],
                                                         sev_capped[!(peril %in% long_tail & policy_year == 2024)],
                                                         claims[!(peril %in% long_tail & policy_year == 2024)]),
                                  dev_claims = sum(claims)), by = .(line, peril)]
em <- ty[market == "emerging"]
em <- dcast(em, line + peril ~ policy_year, value.var = c("freq_ult", "sev_capped", "claims"))
em[, `:=`(em_freq_change = freq_ult_2024 / freq_ult_2023 - 1, em_sev_change = sev_capped_2024 / sev_capped_2023 - 1,
          em_claims = claims_2023 + claims_2024)]
tr <- merge(tr, em[, .(line, peril, em_freq_change, em_sev_change, em_claims)], by = c("line", "peril"))
# Credibility blend of the 1-year emerging change towards the developed prior; then clamp as week 1 C5 Settings
tr[, `:=`(z_freq = em_claims / (em_claims + CRED_K_FREQ), z_sev = em_claims / (em_claims + CRED_K_SEV))]
tr[, freq_trend_blend := pmin(pmax((1 - z_freq) * dev_freq_trend + z_freq * em_freq_change, -0.05), 0.03)]
tr[, sev_trend_blend := pmin(pmax((1 - z_sev) * dev_sev_trend + z_sev * em_sev_change, -0.02), 0.10)]
# Chosen: week 1 rule kept (frequency trend only where week 1 estimated one: motor own damage and TPP; severity trend all perils)
tr[, freq_trend_chosen := fifelse(line == "motor" & peril %in% c("own_damage", "third_party_prop"), freq_trend_blend, 0)]
tr[, sev_trend_chosen := sev_trend_blend]
# Motor BI: week 1 C5 used no trend (IBNER vs real decline unresolved) -> keep 0
tr[line == "motor" & peril == "bodily_injury", `:=`(freq_trend_chosen = 0, sev_trend_chosen = 0)]
tr[, `:=`(sens_low = pmin(freq_trend_chosen, 0) - 0.02, sens_high = sev_trend_chosen + 0.03)]
save_csv(tr, STEP, "trend_table.csv")

add_decision("D014", "4", "IBNR: developed chain ladder on counts per peril (C5 method; subsidence lag-ECDF days override) applied to emerging rows",
             "Emerging-only chain ladder (8 quarters, thin); no IBNR", "week2/output/04_ibnr_trend/lag_comparison.csv; emerging_chain_ladder_check.csv", "decided")
add_decision("D015", "4", "Trend: developed log-linear prior per peril, credibility-blended with the emerging 2023->24 change (Z = n/(n+2000)), clamped as C5; frequency trend only motor OD/TPP; BI none",
             "Emerging change alone; no trend", "week2/output/04_ibnr_trend/trend_table.csv", "decided")
add_assumption("A005", "4", "IBNR reporting pattern", "developed chain ladder (counts) per peril", "developed", "1 (emerging lags match)", "see uncertainty.md: +/-5% on 2024 shares of BI/subsidence")
add_assumption("A006", "4", "Trend credibility constant k", CRED_K_SEV, "judgement", "Z = n/(n+k)", "trend +/-2-3% a year (sens_low / sens_high in trend_table.csv)")

kl <- c(sprintf("- Lags (same loss years, KS p < 0.01): %s.", {x <- lag_cmp[ks_p < 0.01, paste(loss_year, line, peril)]; if (length(x)) paste(x, collapse = "; ") else "none"}),
        sprintf("- 2024 IBNR factor (developed CL): %s.", paste(ibnr_year[, sprintf("%s/%s %.3f", substr(line, 1, 1), peril, ibnr_factor_2024)], collapse = ", ")),
        sprintf("- Chosen severity trend: %s.", paste(tr[, sprintf("%s/%s %+.1f%%", substr(line, 1, 1), peril, 100 * sev_trend_chosen)], collapse = ", ")),
        sprintf("- Chosen frequency trend: %s.", paste(tr[freq_trend_chosen != 0, sprintf("%s/%s %+.1f%%", line, peril, 100 * freq_trend_chosen)], collapse = ", ")))
write_md(list("# Step 4: IBNR and trend", "", paste("Generated", ts_sgt(), "by `week2/R/04_ibnr_trend_week2.R`."), "", kl, "",
              "## Report lags, same loss years", "", md_table(lag_cmp, 3),
              "## Reported share and IBNR factor by loss year (developed pattern) and emerging-only chain ladder check", "", md_table(ibnr_year, 3),
              "## Experience by year, ultimate frequency and capped severity", "", md_table(ty[, .(market, line, peril, policy_year, exposure, claims, freq_ult, sev_capped)], 4),
              "## Trends", "", md_table(tr, 4)), STEP, "ibnr_trend_report.md")
update_step_log("4", "IBNR and trend", kl)
end_script()
