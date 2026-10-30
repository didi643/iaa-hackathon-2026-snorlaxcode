# 6_blend_w2.R ---------------------------------------------------------------------------------------------------
# Week 2 step 6: from the step 5 candidates to the 2025 submission file (local only; never submitted without Wendy).
#   1. Credibility on the emerging levels. Step 5 multiplies the developed model by one emerging level per peril, which
#      copies single-year noise (buildings fire: x2.4 in 2023, x0.8 in 2024). Each peril's level is shrunk towards its
#      line's pooled level:  level_cred = z level_peril + (1 - z) level_line,  z = n / (n + k),  n = emerging claims.
#      Frequency and severity have their own k, chosen on the validation fold (fit 2023, score 2024).
#   2. Severity trend: none, or the developed market's per-peril log-linear trend in capped severity (clamped).
#   3. Model: transfer-level, transfer-boost, or their 50/50 average (week 1: averaging versions travels better).
#   Scored on the 2024 fold (developed and reported basis); paired policy bootstrap vs the step 5 transfer-level model;
#   new-business rows scored separately (2025 is 76% new business).
# Out: week2/output/6_blend/ (blend_report.md, grid, bootstrap), week2/output/submission/submission_w2_<run>.csv

source("week2/R/0_setup_w2.R")
STEP <- "6_blend"
K_GRID <- c(0, 25, 50, 100, 200, 400, 800, Inf)     # 0 = peril's own level (step 5), Inf = line level for every peril
TREND_CLAMP <- c(-0.02, 0.08)
N_BOOT <- 300L
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")

info <- rbind(fread(file.path(PATHS_W2$output, "5_models", "fit_info_valid.csv")),
              fread(file.path(PATHS_W2$output, "5_models", "fit_info_final.csv")))
pv <- read_clean_w2("w2_preds_valid"); pf <- read_clean_w2("w2_preds_final")

# pooled line levels: expected = observed / level per peril
line_levels <- function(fi, pr) {
  s0 <- pr[, .(s0 = S0[1]), by = .(line, peril)]
  x <- merge(fi, s0, by = c("line", "peril"))
  x[, `:=`(sum_ye = sev_claims_e * s0 / cap_loading)]
  x[, `:=`(E_f = claims_e / level_freq, E_s = sum_ye / level_sev)]
  x[, `:=`(line_f = sum(claims_e) / sum(E_f), line_s = sum(sum_ye) / sum(E_s)), by = line]
  x
}
cred <- function(lev, n, line_lev, k) { z <- if (is.infinite(k)) 0 else n / (n + k); z * lev + (1 - z) * line_lev }

# developed per-peril severity trend (capped mean by loss year), years up to the fold's last training year
dev_trend <- function(last_year) {
  cd <- read_clean_w2("developed_claims_matched")[counts & net_cost > 0 & !is.na(row_id) & year(loss_date) <= last_year]
  cd[, cap := quantile(net_cost, 0.995), by = .(line, peril)]
  s <- cd[, .(s = mean(pmin(net_cost, cap)), n = .N), by = .(line, peril, ly = year(loss_date))]
  s[, .(trend = { b <- coef(lm(log(s) ~ ly, weights = n))[2]; min(max(unname(b), TREND_CLAMP[1]), TREND_CLAMP[2]) }), by = .(line, peril)]
}

apply_cfg <- function(pr, lv, kf, ks, model, trend = NULL, years_ahead = 0) {
  x <- merge(pr, lv[, .(line, peril, claims_e, sev_claims_e, level_freq, level_sev, line_f, line_s)], by = c("line", "peril"))
  x[, `:=`(af = cred(level_freq, claims_e, line_f, kf) / level_freq, as = cred(level_sev, sev_claims_e, line_s, ks) / level_sev)]
  fr <- switch(model, level = x$F2, boost = x$F3, avg = 0.5 * (x$F2 + x$F3))
  sv <- switch(model, level = x$S2, boost = x$S3, avg = 0.5 * (x$S2 + x$S3))
  tf <- if (is.null(trend)) 1 else exp(trend$trend[match(paste(x$line, x$peril), paste(trend$line, trend$peril))] * years_ahead)
  x[, pred := fr * x$af * sv * x$as * tf]
  x
}

# Validation actuals ----------------------------------------------------------------------------------------------
shares <- read_clean_w2("emerging_report_shares")
act <- rbindlist(lapply(LINES, function(ln) {
  tr <- read_clean_w2(paste0("emerging_train_", ln))[policy_year == 2024L]
  sh <- shares[line == ln][match(tr$row_id, row_id)]
  rbindlist(lapply(PERILS[[ln]], function(p) data.table(row_id = tr$row_id, line = ln, peril = p, y_rep = tr[[paste0("y_cost_", p)]],
                                                        share = sh[[paste0("s_", p)]], new_business = tr$new_business)))
}))
pv <- merge(pv, act, by = c("row_id", "line", "peril"))
pv[, y_dev := y_rep / share]
lv_v <- line_levels(info[fold == "valid"], pv); lv_f <- line_levels(info[fold == "final"], pf)
tr_v <- dev_trend(2023L); tr_f <- dev_trend(2024L)

score <- function(x, by_nb = FALSE) {
  r <- x[, .(pred = sum(pred), pred_rep = sum(pred * share), y_dev = sum(y_dev), y_rep = sum(y_rep), exposure = exposure[1],
             nb = new_business[1]), by = .(line, row_id)]
  if (by_nb) r <- r[nb == TRUE]
  rbind(r[, .(d2_dev = d2_tweedie(y_dev, pred, exposure), d2_rep = d2_tweedie(y_rep, pred_rep, exposure), ae = sum(y_dev) / sum(pred)), by = line],
        r[, .(line = "ALL", d2_dev = d2_tweedie(y_dev, pred, exposure), d2_rep = d2_tweedie(y_rep, pred_rep, exposure), ae = sum(y_dev) / sum(pred))])
}

# Grid on the validation fold ---------------------------------------------------------------------------------------
grid <- CJ(kf = K_GRID, ks = K_GRID, model = c("level", "boost", "avg"), trend = c("none", "developed"))
res <- rbindlist(lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i]
  x <- apply_cfg(pv, lv_v, g$kf, g$ks, g$model, if (g$trend == "developed") tr_v else NULL, 1)
  cbind(g, dcast(score(x)[, .(line, d2_dev, d2_rep, ae)], . ~ line, value.var = c("d2_dev", "d2_rep", "ae"))[, -1])
}))
setorder(res, -d2_dev_ALL)
best <- res[1]
# simplest within noise: bootstrap the ALL D2 gain of each top-20 config over the step 5 transfer-level model
ref_cfg <- list(kf = 0, ks = 0, model = "level", trend = "none")
mk <- function(cfg) apply_cfg(pv, lv_v, cfg$kf, cfg$ks, cfg$model, if (cfg$trend == "developed") tr_v else NULL, 1)
rows_of <- function(x) x[, .(pred = sum(pred), y_dev = sum(y_dev), exposure = exposure[1]), by = .(line, row_id)]
ref_rows <- rows_of(mk(ref_cfg))
pid_map <- rbindlist(lapply(LINES, function(ln) read_clean_w2(paste0("emerging_train_", ln))[policy_year == 2024L, .(row_id, policy_id)]))
ref_rows[, policy_id := pid_map$policy_id[match(row_id, pid_map$row_id)]]
set.seed(SEED)
up <- unique(ref_rows$policy_id)
draws <- lapply(seq_len(N_BOOT), function(b) { s <- table(sample(up, length(up), replace = TRUE)); w <- as.numeric(s[match(ref_rows$policy_id, names(s))]); w[is.na(w)] <- 0; w })
unit_dev <- function(y, mu, p = 1.5) { mu <- pmax(mu, 1e-9); 2 * (ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p)) }
wd2 <- function(r, w) {   # D2 of a bootstrap resample, as row weights (= rows repeated w times)
  m0 <- r$exposure * sum(w * r$y_dev) / sum(w * r$exposure)
  1 - sum(w * unit_dev(r$y_dev, r$pred)) / sum(w * unit_dev(r$y_dev, m0))
}
boot_gain <- function(cfg) {
  r <- rows_of(mk(cfg)); r <- r[match(ref_rows$row_id, row_id)]
  g <- vapply(draws, function(w) wd2(r, w) - wd2(ref_rows, w), numeric(1))
  c(gain = d2_tweedie(r$y_dev, r$pred, r$exposure) - d2_tweedie(ref_rows$y_dev, ref_rows$pred, ref_rows$exposure), se = sd(g), share_better = mean(g > 0))
}
top <- res[1:20]
bt <- rbindlist(lapply(seq_len(nrow(top)), function(i) { b <- boot_gain(as.list(top[i, .(kf, ks, model, trend)])); cbind(top[i, .(kf, ks, model, trend, d2_dev_ALL)], t(b)) }))
# choice: among configs within 1 SE of the best gain, prefer averaging, no trend, then the most shrinkage (largest k)
bt[, within := gain >= max(gain) - se[which.max(gain)]]
auto <- bt[within == TRUE][order(-(model == "avg"), -(trend == "none"), -pmin(kf, 1e6), -pmin(ks, 1e6))][1]
# Judgement (25 Oct, Wendy's review): the validation plateau is flat for k_freq 200..Inf (within 0.001 of the best, SE 0.0036);
# its gain comes from buildings fire's one-year spike while motor and contents prefer peril levels, and step 4 found real peril
# differences (storm x1.42, CI 1.29-1.55). So the middle of the plateau keeps peril information: motor perils keep ~90% of their
# own frequency level, fire ~25%. Override with W2_CFG="kf,ks,model,trend".
cfg_env <- strsplit(Sys.getenv("W2_CFG", "200,100,avg,none"), ",")[[1]]
CFG <- list(kf = as.numeric(cfg_env[1]), ks = as.numeric(cfg_env[2]), model = cfg_env[3], trend = cfg_env[4])
pick <- cbind(res[kf == CFG$kf & ks == CFG$ks & model == CFG$model & trend == CFG$trend, .(kf, ks, model, trend, d2_dev_ALL)],
              t(boot_gain(CFG)))
log_msg("Best ALL D2 ", round(best$d2_dev_ALL, 5), "; chosen kf=", CFG$kf, " ks=", CFG$ks, " model=", CFG$model, " trend=", CFG$trend,
        " (ALL D2 ", round(pick$d2_dev_ALL, 5), ", gain vs step 5 ", round(pick$gain, 5), " +/- ", round(pick$se, 5), ")")

xv <- mk(CFG)
val_chosen <- score(xv); val_nb <- score(xv, by_nb = TRUE); val_ref <- score(mk(ref_cfg)); val_ref_nb <- score(mk(ref_cfg), TRUE)
peril_ae <- xv[, .(claims_cost_dev = sum(y_dev), predicted = sum(pred)), by = .(line, peril)][, ae := claims_cost_dev / predicted]

# Final 2025 predictions -----------------------------------------------------------------------------------------
xf <- apply_cfg(pf, lv_f, CFG$kf, CFG$ks, CFG$model, if (CFG$trend == "developed") tr_f else NULL, 1.5)
sub_rows <- xf[, .(prediction = sum(pred)), by = .(line, row_id)]
ss <- read_e("sample_submission")
sub <- data.table(row_id = ss$row_id, prediction = sub_rows$prediction[match(ss$row_id, sub_rows$row_id)])
stopifnot(nrow(sub) == 209063L, !anyNA(sub$prediction), all(is.finite(sub$prediction)), all(sub$prediction >= 0), !anyDuplicated(sub$row_id))
f_sub <- out_w2("submission", paste0("submission_w2_", RUN_ID, ".csv"))
fwrite(sub, f_sub, scipen = 50)
expo <- rbindlist(lapply(LINES, function(ln) read_e(paste0("test_", ln))[, .(row_id, exposure, new_business, line = ln)]))
burn25 <- merge(sub_rows, expo, by = c("line", "row_id"))[, .(rows = .N, burn_2025 = sum(prediction) / sum(exposure),
                                                              burn_new_business = sum(prediction[new_business]) / sum(exposure[new_business]),
                                                              burn_renewal = sum(prediction[!new_business]) / sum(exposure[!new_business])), by = line]
hist_burn <- shares[, .(burn_dev_ultimate = sum(y_dev_cost) / sum(exposure)), by = .(line, policy_year)]
burn25 <- merge(burn25, dcast(hist_burn, line ~ paste0("burn_ult_", policy_year), value.var = "burn_dev_ultimate"), by = "line")
lev_tab <- merge(lv_f[, .(line, peril, claims_e, level_freq, line_f, level_sev, line_s)],
                 xf[, .(af = af[1], as = as[1]), by = .(line, peril)], by = c("line", "peril"))
lev_tab[, `:=`(freq_level_used = level_freq * af, sev_level_used = level_sev * as)]
trend_used <- if (CFG$trend == "developed") tr_f else data.table(line = character(), peril = character(), trend = numeric())

# Outputs ----------------------------------------------------------------------------------------------------------
save_csv_w2(res, STEP, "validation_grid.csv"); save_csv_w2(bt, STEP, "bootstrap_top20.csv")
save_csv_w2(peril_ae, STEP, "validation_peril_ae.csv"); save_csv_w2(lev_tab, STEP, "levels_final.csv"); save_csv_w2(burn25, STEP, "burn_2025.csv")
cfg_txt <- sprintf("k_freq = %s, k_sev = %s, model = %s, trend = %s", CFG$kf, CFG$ks, CFG$model, CFG$trend)
write_md_w2(list(
  "# Week 2 - Step 6: credibility, blend and the 2025 file", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "by `week2/R/6_blend_w2.R`. File:", paste0("`", f_sub, "`"), "(local; not submitted)."), "",
  "## Choice", "",
  paste0("Chosen: **", cfg_txt, "** (validation ALL D2 ", round(pick$d2_dev_ALL, 4), ", gain vs step 5 ", round(pick$gain, 4), " +/- ", round(pick$se, 4), ")."),
  paste0("Best on this fold: k_freq = ", best$kf, ", k_sev = ", best$ks, ", ", best$model, ", trend ", best$trend, " (ALL D2 ", round(best$d2_dev_ALL, 4),
         "); the automatic rule (within 1 SE, most shrinkage) would give k_freq = ", auto$kf, ", k_sev = ", auto$ks, "."),
  "Why not full pooling: the plateau is flat for k_freq 200 to Inf (within 0.001, bootstrap SE 0.0036). The extra gain of pooling",
  "comes from buildings fire's one-year spike, while motor and contents score better with peril levels. Step 4 also found real",
  "peril differences (storm frequency x1.42, CI 1.29-1.55). k_freq = 200 keeps ~90% of each motor peril's own level and ~25% for fire.",
  "Credibility `z = n / (n + k)` shrinks each peril's level towards its line's pooled level (Inf = line level only).", "",
  "## Validation 2024 (fit 2023): chosen vs step 5 transfer-level", "",
  md_table(merge(val_chosen, val_ref, by = "line", suffixes = c("_chosen", "_step5")), 4),
  "New-business rows only:", "", md_table(merge(val_nb, val_ref_nb, by = "line", suffixes = c("_chosen", "_step5")), 4),
  "## Top 20 configs and paired policy bootstrap of the ALL D2 gain vs step 5", "", md_table(copy(bt)[, `:=`(kf = as.character(kf), ks = as.character(ks))], 5),
  "## Peril A/E on 2024 (chosen config)", "", md_table(peril_ae, 3),
  "## Levels used for 2025 (fit 2023-24)", "", md_table(lev_tab, 3),
  if (nrow(trend_used)) c("Severity trend per year (developed, 2021-24, clamped):", "", md_table(trend_used, 4)) else "No severity trend.", "",
  "## 2025 predicted burn cost vs emerging history (developed to ultimate)", "", md_table(burn25, 1)
), STEP, "blend_report.md")
print(burn25)
log_msg("Submission written: ", f_sub)
