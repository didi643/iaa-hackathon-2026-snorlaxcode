# 4_drift_w2.R ---------------------------------------------------------------------------------------------------
# Week 2 step 4: what has changed vs the developed market (Part 1), and what can be carried over.
# For every line x peril:
#   Frequency  Poisson GLM fitted on the DEVELOPED market (policy years 2023-24, same years as emerging) on the features both
#              markets share (numerics in developed quintiles, rare levels pooled), offset log(exposure x reported share).
#              Applied to the emerging rows: A/E = emerging reported claims / (developed rate x exposure x emerging share)
#              = the level difference. Then, one feature at a time, an emerging GLM with the developed prediction as offset:
#              a significant feature (LR test, p < 0.01) has a different shape in the emerging market.
#   Severity   Gamma GLM, same idea, on claims capped at the developed p99.5 of the peril (cap loading reported separately).
#   Also       new business vs renewal (2025 is mostly new business), claim size tails, region (different codes: not
#              transferable) and make_model (300 levels) are kept out of the transfer test.
# Out: week2/output/4_drift/ (drift_report.md, level_by_peril.csv, feature_shape_tests.csv, new_business.csv, tails.csv)

source("week2/R/0_setup_w2.R")
STEP <- "4_drift"
P_SHAPE <- 0.01
NOT_TRANSFER <- c("region", "make_model")
feat_roles <- fread(file.path(PATHS_W2$output, "2_clean", "features_w2.csv"))
curves <- read_clean_w2("report_lag_curves")

bin_spec <- function(x, w) {   # from the developed market
  if (is.numeric(x) && uniqueN(x) > 6) {
    br <- unique(quantile(x, seq(0, 1, 0.2), na.rm = TRUE, names = FALSE))
    list(type = "num", br = br)
  } else {
    x <- as.character(x); s <- tapply(w, x, sum) / sum(w)
    list(type = "cat", keep = names(s)[s >= 0.005])
  }
}
apply_bin <- function(x, sp) {
  if (sp$type == "num") {
    b <- as.character(cut(pmin(pmax(x, sp$br[1]), sp$br[length(sp$br)]), sp$br, include.lowest = TRUE, dig.lab = 6))
    b[is.na(b)] <- "NA"; b
  } else { x <- as.character(x); x[is.na(x)] <- "missing"; fifelse(x %in% sp$keep, x, "other") }
}
fit_gamma <- function(fml, data, offset = NULL) {   # log-link gamma GLM started from the mean (default starts often fail)
  d <- copy(data); d[, `:=`(.off = if (is.null(offset)) 0 else offset, .mu = mean(y))]
  v <- all.vars(fml)[-1]; v <- v[vapply(v, function(x) uniqueN(d[[x]]) >= 2, logical(1))]   # single-level features cannot be fitted
  f2 <- reformulate(c(if (length(v)) v else "1", "offset(.off)"), response = "y")
  tryCatch(glm(f2, family = Gamma(link = "log"), data = d, mustart = .mu, control = list(maxit = 100)),
           error = function(e) { message("gamma GLM failed: ", conditionMessage(e)); NULL })
}
predict_link <- function(fit, newdata) {   # levels the fit never saw (no claims) -> the fit's reference level
  nd <- copy(newdata); nd[, .off := 0]
  for (f in names(fit$xlevels)) { lv <- fit$xlevels[[f]]; v <- as.character(nd[[f]]); v[!v %in% lv] <- lv[1]; set(nd, j = f, value = factor(v, levels = lv)) }
  predict(fit, newdata = nd, type = "link")
}
pois_ci <- function(a, e) c(qchisq(0.025, 2 * a) / 2 / e, qchisq(0.975, 2 * (a + 1)) / 2 / e)

level <- list(); shape <- list(); nb <- list(); tails <- list()
for (ln in LINES) {
  log_msg("Line ", ln)
  em <- read_clean_w2(paste0("emerging_train_", ln))
  sh <- read_clean_w2("emerging_report_shares")[line == ln]
  em <- merge(em, sh[, c("row_id", paste0("s_", PERILS[[ln]])), with = FALSE], by = "row_id")
  dv <- read_clean_w2(paste0("developed_train_", ln))[policy_year %in% 2023:2024]
  feats <- feat_roles[line == ln & role == "feature" & emerging == TRUE & developed == TRUE, column]
  feats <- setdiff(feats, c(NOT_TRANSFER, grep("^y_|^s_", feats, value = TRUE)))
  specs <- setNames(lapply(feats, function(f) bin_spec(dv[[f]], dv$exposure)), feats)
  specs <- specs[vapply(specs, function(s) if (s$type == "cat") length(s$keep) >= 2 else length(s$br) >= 3, logical(1))]
  feats <- names(specs)
  B <- function(d) { x <- as.data.table(lapply(feats, function(f) apply_bin(d[[f]], specs[[f]]))); setnames(x, feats); x }
  Xd <- B(dv); Xe <- B(em)
  for (f in feats) {   # emerging levels unseen in the developed market -> the developed modal level
    tb <- table(Xd[[f]]); lv <- names(tb); ref <- names(which.max(tb))
    Xd[[f]] <- factor(Xd[[f]], levels = lv); Xe[[f]] <- factor(fifelse(Xe[[f]] %in% lv, Xe[[f]], ref), levels = lv)
  }
  cd_all <- read_clean_w2("developed_claims_matched")[line == ln & counts & net_cost > 0 & row_id %in% dv$row_id]
  ce_all <- read_clean_w2("emerging_claims_matched")[line == ln & counts & net_cost > 0 & !is.na(row_id)]
  fml <- reformulate(feats, response = "y")

  for (p in PERILS[[ln]]) {
    lp <- paste(ln, p, sep = ".")
    lp_key <- lp
    sd_ <- row_share(curves[curves$lp == lp_key, F_developed], dv$period_start, dv$period_end)
    stopifnot(length(curves[curves$lp == lp_key, F_developed]) > 1000)
    dd <- cbind(Xd, y = dv[[paste0("y_n_", p)]], off = log(dv$exposure * sd_))
    g <- glm(fml, family = poisson(), data = dd, offset = off, control = list(maxit = 50))
    se_ <- em[[paste0("s_", p)]]
    de <- cbind(Xe, y = em[[paste0("y_n_", p)]])
    de[, off := 0]
    de[, off := predict(g, newdata = de, type = "link") + log(em$exposure * se_)]   # developed rate x emerging exposure x share
    A <- sum(de$y); E <- sum(exp(de$off)); ci <- pois_ci(A, E)
    # severity: capped at the developed p99.5, gamma GLM on claim level
    cdp <- cd_all[peril == p]
    cap <- quantile(cdp$net_cost, 0.995, names = FALSE)
    ce <- ce_all[peril == p]
    sev_d <- cbind(Xd[match(cdp$row_id, dv$row_id)], y = pmin(cdp$net_cost, cap))
    gs <- fit_gamma(fml, sev_d)
    sev_e <- cbind(Xe[match(ce$row_id, em$row_id)], y = pmin(ce$net_cost, cap))
    if (!is.null(gs)) sev_e[, off := predict_link(gs, sev_e)]
    sev_ratio <- if (!is.null(gs) && nrow(sev_e)) sum(sev_e$y) / sum(exp(sev_e$off)) else NA_real_
    bs <- if (!is.null(gs) && nrow(sev_e) >= 5) { set.seed(SEED); r <- replicate(400, { i <- sample.int(nrow(sev_e), replace = TRUE); sum(sev_e$y[i]) / sum(exp(sev_e$off[i])) }); quantile(r, c(.025, .975)) } else c(NA, NA)
    level[[lp]] <- data.table(line = ln, peril = p, claims_emerging = A, freq_ae = A / E, freq_lo = ci[1], freq_hi = ci[2],
                              sev_claims = nrow(sev_e), sev_ratio = sev_ratio, sev_lo = bs[1], sev_hi = bs[2],
                              cap_developed_p995 = cap, share_emerging_cost_above_cap = sum(pmax(ce$net_cost - cap, 0)) / sum(ce$net_cost),
                              burn_ratio = A / E * sev_ratio)
    # shape tests (frequency, then severity), one feature at a time
    base_ll <- glm(y ~ 1, family = poisson(), data = de, offset = off)
    for (f in feats) {
      if (uniqueN(de[[f]]) < 2) next
      m1 <- glm(reformulate(f, response = "y"), family = poisson(), data = de, offset = off)
      lr <- base_ll$deviance - m1$deviance; df <- base_ll$df.residual - m1$df.residual
      rel <- exp(coef(m1)[-1]); rel <- rel[is.finite(rel)]
      shape[[paste(lp, "freq", f)]] <- data.table(line = ln, peril = p, part = "frequency", feature = f, lr = lr, df = df,
                                                  p_value = pchisq(lr, max(df, 1), lower.tail = FALSE),
                                                  max_rel_change = if (length(rel)) max(abs(log(c(1, rel)))) else 0)
    }
    if (!is.null(gs) && nrow(sev_e) >= 100 && !is.null(b0 <- fit_gamma(y ~ 1, sev_e, sev_e$off))) {
      for (f in feats) {
        if (uniqueN(sev_e[[f]]) < 2) next
        m1 <- fit_gamma(reformulate(f, response = "y"), sev_e, sev_e$off)
        if (is.null(m1)) next
        ft <- anova(b0, m1, test = "F")
        shape[[paste(lp, "sev", f)]] <- data.table(line = ln, peril = p, part = "severity", feature = f, lr = ft$Deviance[2], df = ft$Df[2],
                                                   p_value = ft$`Pr(>F)`[2], max_rel_change = max(abs(coef(m1)[-1]), na.rm = TRUE))
      }
    }
    # new business: emerging A/E split, and the developed GLM's own new_business relativity
    if ("new_business" %in% feats) {
      nbx <- de[, .(A = sum(y), E = sum(exp(off))), by = .(new_business = as.character(new_business))]
      cf <- coef(g); k <- grep("^new_business", names(cf))
      nb[[lp]] <- data.table(line = ln, peril = p, nbx[, .(new_business, claims = A, freq_ae = A / E)],
                             developed_nb_relativity = if (length(k)) exp(cf[k[1]]) else NA_real_)
    }
    tails[[lp]] <- rbind(data.table(market = "developed", line = ln, peril = p, t(quantile(cdp$net_cost, c(.5, .9, .99, .999, 1)))),
                         data.table(market = "emerging", line = ln, peril = p, t(quantile(ce$net_cost, c(.5, .9, .99, .999, 1)))))
    log_msg("  ", p, ": freq A/E ", round(A / E, 3), ", sev ratio ", round(sev_ratio, 3))
  }
  rm(dv, Xd, dd); gc(verbose = FALSE)
}

level <- rbindlist(level); shape <- rbindlist(shape); nb <- rbindlist(nb); tails <- rbindlist(tails)
setnames(tails, c("50%", "90%", "99%", "99.9%", "100%"), c("p50", "p90", "p99", "p99_9", "max"))
shape[, shape_differs := p_value < P_SHAPE]
shape_sum <- shape[, .(features_tested = .N, differ = sum(shape_differs),
                       which_differ = paste(feature[shape_differs][order(p_value[shape_differs])], collapse = ", ")), by = .(line, peril, part)]
decision <- merge(level[, .(line, peril, claims_emerging, freq_ae, sev_ratio, burn_ratio)],
                  dcast(shape_sum, line + peril ~ part, value.var = c("differ", "which_differ")), by = c("line", "peril"), all.x = TRUE)
save_csv_w2(level, STEP, "level_by_peril.csv"); save_csv_w2(shape, STEP, "feature_shape_tests.csv")
save_csv_w2(nb, STEP, "new_business.csv"); save_csv_w2(tails, STEP, "tails.csv"); save_csv_w2(decision, STEP, "carry_over_summary.csv")
feat_freq <- shape[part == "frequency", .(perils_tested = .N, perils_differ = sum(shape_differs)), by = feature][order(-perils_differ)]

write_md_w2(list(
  "# Week 2 - Step 4: what has changed vs Part 1 (developed market)", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "by `week2/R/4_drift_w2.R`."), "",
  "## Method", "",
  "- **Developed GLMs:** per line x peril, Poisson frequency and gamma severity GLMs fitted on the developed market (policy years 2023-24),",
  "  using the features both markets share. Numerics are in developed quintiles and rare levels are pooled. Frequency offset: exposure x reported share.",
  "- **Level:** applied to the emerging rows, `freq_ae` = emerging claims / developed-model expectation (with a Poisson 95% CI),",
  "  and `sev_ratio` = emerging capped severity / developed-model severity (bootstrap 95% CI).",
  "- **Shape:** one feature at a time, refit on emerging with the developed prediction as offset. If p < 0.01 the feature's",
  "  effect differs in the emerging market; otherwise the developed relativity can be carried over (only the level changes).",
  "- **Not tested:** region (different codes per market) and make_model (300 levels) cannot transfer and are left out.", "",
  "## Level by peril (emerging vs the developed model)", "",
  md_table(level[, .(line, peril, claims_emerging, freq_ae, freq_lo, freq_hi, sev_claims, sev_ratio, sev_lo, sev_hi, burn_ratio,
                     cap_developed_p995, share_emerging_cost_above_cap)], 3),
  "## Carry-over summary (features whose shape differs, p < 0.01)", "", md_table(decision, 3),
  "## Features that differ most often (frequency, across the 15 perils)", "", md_table(feat_freq[perils_differ > 0], 0),
  "## New business vs renewal (frequency A/E against the developed model)", "", md_table(nb, 3),
  "## Claim size tails (net cost per claim)", "", md_table(tails[order(line, peril, market)], 0)
), STEP, "drift_report.md")
log_msg("Drift done")
