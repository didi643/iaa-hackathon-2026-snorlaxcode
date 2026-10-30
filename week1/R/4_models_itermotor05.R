# 4_models_itermotor05.R ---------------------------------------------------------
# MOTOR 5: penalised GAM (mgcv::bam, Poisson, REML-chosen smoothness) for motor bodily_injury frequency, added as extra
# BI versions next to MOTOR 4's glm / lgb / boost. Severity, loading and all other perils are unchanged (MOTOR 2 frozen).
#   gam_own   BI claims, offset log(exposure x reported share)
#   gam_pool  as gam_own plus log(MOTOR 2 TPP frequency) in the offset: the GAM models BI relative to TPP
#   gam_mix   50/50 of the two (as MOTOR 2's BI frequency mix)
# Smooths: driver_age, years_licensed, their interaction (ti), ncb_years, vehicle_age, vehicle_value_group,
# annual_mileage, claim_free_years; factors / linear terms as MOTOR 2's BI GLM plus the claim-history counts.
# Writes week1/models/motor_iteration_05/components.parquet = MOTOR 4 components + gam_* bodily_injury columns.
# Judge with: EVAL_DIR=week1/models/motor_iteration_05 EVAL_TAG=motor05 M4_VERS=glm,lgb,boost,gam_own,gam_pool,gam_mix
#             Rscript week1/R/6_w9_motor04_eval.R

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
suppressPackageStartupMessages({
  library(xgboost)
  library(splines)
  library(mgcv)
})
T0 <- Sys.time()
QUICK <- FALSE
import_defs <- function(file, skip) {
  in_header <- TRUE
  for (e in parse(file, keep.source = FALSE)) {
    if (is.call(e) && identical(e[[1]], as.name("log_msg"))) in_header <- FALSE
    if (!is.call(e) || !identical(e[[1]], as.name("<-")) || !is.name(e[[2]])) next
    nm <- as.character(e[[2]])
    is_fun <- is.call(e[[3]]) && identical(e[[3]][[1]], as.name("function"))
    if (!nm %in% skip && (is_fun || in_header)) eval(e, globalenv())
  }
}
skip <- c("QUICK", "RUN_ID", "ITERATION_LABEL", "ITER_DIR", "FITTED_DIR", "T0", "checks", "in_header", "import_defs", "skip")
import_defs("week1/R/4_models_itermotor01.R", skip)
import_defs("week1/R/4_models_itermotor02.R", skip)
import_defs("week1/R/4_models_itermotor04.R", skip)
ITER_DIR <- file.path("week1", "models", "motor_iteration_05")
dir.create(ITER_DIR, recursive = TRUE, showWarnings = FALSE)
M4_COMP <- file.path("week1", "models", "motor_iteration_04", "components.parquet")
GAM_SMOOTH <- c(driver_age = 10, years_licensed = 8, ncb_years = 6, vehicle_age = 6, vehicle_value_group = 6,
                annual_mileage = 8, claim_free_years = 5)
GAM_LIN <- c("prior_claims_5y", "licence_points", "hist_pol_n", "hist_cust_other_n", "hist_coll_n")
GAM_FAC <- c("cover_type", "vehicle_use", "named_young_driver", "region", "urban_density", "credit_band", "new_business",
             "payment_method", "telematics_opt_in", "overnight_parking", "body_type", "voluntary_excess")

# Model frame: numerics clamped to training 0.5-99.5% and NA -> training median; factors with training levels
gam_prep <- function(d, ref = NULL) {
  if (is.null(ref)) {
    ref <- list(num = lapply(setNames(c(names(GAM_SMOOTH), GAM_LIN), c(names(GAM_SMOOTH), GAM_LIN)), function(f) {
      x <- as.numeric(d[[f]])
      c(quantile(x, c(0.005, 0.995), na.rm = TRUE, names = FALSE), median(x, na.rm = TRUE))
    }), fac = lapply(setNames(GAM_FAC, GAM_FAC), function(f) {
      v <- cat_raw(d[[f]])
      names(sort(table(v), decreasing = TRUE))
    }), years = sort(unique(d$policy_year)))
  }
  m <- data.table(.r = seq_len(nrow(d)))
  for (f in names(ref$num)) {
    x <- as.numeric(d[[f]]); q <- ref$num[[f]]
    x[is.na(x)] <- q[3]
    set(m, j = f, value = pmin(pmax(x, q[1]), q[2]))
  }
  for (f in names(ref$fac)) {
    v <- cat_raw(d[[f]]); lv <- ref$fac[[f]]
    v[!v %in% lv] <- lv[1]
    set(m, j = f, value = factor(v, levels = lv))
  }
  yr <- pmin(d$policy_year, max(ref$years))
  set(m, j = "yr", value = factor(yr, levels = ref$years))
  list(m = m[, !".r"], ref = ref)
}
gam_formula <- function(m) {
  sm <- vapply(names(GAM_SMOOTH), function(f) {
    k <- min(GAM_SMOOTH[[f]], uniqueN(m[[f]]) - 1L)
    if (k >= 3) sprintf("s(%s, k = %d)", f, k) else f
  }, character(1))
  fac <- GAM_FAC[vapply(GAM_FAC, function(f) nlevels(droplevels(m[[f]])) > 1, logical(1))]
  as.formula(paste("y ~ yr +", paste(c(sm, "ti(driver_age, years_licensed, k = c(5, 5))", GAM_LIN, fac), collapse = " + "),
                   "+ offset(off)"))
}
fit_gam <- function(tr, idx, w, off, sc, off_sc) {
  p <- gam_prep(tr[idx])
  m <- p$m
  m[, `:=`(y = tr[[paste0("y_npos_", BI)]][idx], off = off, w = w)]
  g <- bam(gam_formula(m), family = poisson(), data = m, weights = w, method = "fREML", discrete = TRUE, nthreads = N_THREADS)
  s <- gam_prep(sc, p$ref)$m
  s[, `:=`(yr = factor(max(p$ref$years), levels = p$ref$years), off = 0)]
  list(rate = exp(predict(g, s, type = "link") + off_sc), edf = sum(g$edf),
       smooth = data.table(term = vapply(g$smooth, function(x) x$label, ""),
                           edf = vapply(seq_along(g$smooth), function(i) sum(g$edf[g$smooth[[i]]$first.para:g$smooth[[i]]$last.para]), 0)))
}

run_gam_fold <- function(tr, sc, seed, label) {
  t1 <- Sys.time()
  info <- add_robust_loading(prep_fold(tr, sc, seed), tr)
  fits <- fit_all2(tr, info, seed, final = TRUE, cfg = CFG, blend = list(tw = 0, legacy = 0))
  Ptr <- peril_parts2(fits$perils$third_party_prop, tr, info, "third_party_prop")
  Psc_t <- peril_parts2(fits$perils$third_party_prop, sc, info, "third_party_prop")
  Psc <- peril_parts2(fits$perils[[BI]], sc, info, BI)
  tpp_tr <- freq_of2(Ptr, CFG$third_party_prop, tr$exposure)
  tpp_sc <- freq_of2(Psc_t, CFG$third_party_prop, sc$exposure)
  f_glm <- freq_of2(Psc, CFG[[BI]], sc$exposure)
  cost_glm <- peril_cost2(Psc, CFG[[BI]], sc$exposure)
  unc <- names(info$unc_rate[[BI]])
  smp <- freq_sample(tr, BI, unc, ZERO_SAMPLE, seed + 300)
  eff <- tr[[paste0("effexp_", BI)]][smp$idx]
  own <- fit_gam(tr, smp$idx, smp$w, log(eff), sc, 0)
  pool <- fit_gam(tr, smp$idx, smp$w, log(eff) + log(tpp_tr[smp$idx]), sc, log(tpp_sc))
  out <- data.table(valid_year = as.integer(label), row_id = sc$row_id, glm_check = cost_glm)
  ucs <- sc$cover_type %in% unc
  for (v in c("own", "pool")) {
    r <- if (v == "own") own$rate else pool$rate
    r <- r * sum(f_glm) / sum(r)
    r[ucs] <- f_glm[ucs]
    set(out, j = paste0("gam_", v, "_", BI), value = cost_glm * r / f_glm)
  }
  out[, (paste0("gam_mix_", BI)) := 0.5 * get(paste0("gam_own_", BI)) + 0.5 * get(paste0("gam_pool_", BI))]
  log_msg(label, ": GAM edf own ", round(own$edf, 1), ", pool ", round(pool$edf, 1), " in ",
          round(as.numeric(difftime(Sys.time(), t1, units = "mins")), 1), " min")
  list(out = out, smooth = rbind(own$smooth[, `:=`(fit = label, gam = "own")], pool$smooth[, `:=`(fit = label, gam = "pool")]))
}

# Data (as MOTOR 4) -----------------------------------------------------------------------------------------
log_msg("Data")
train <- as.data.table(read_parquet(file.path(DATA_DIR, "train_motor.parquet")))
test <- as.data.table(read_parquet(file.path(DATA_DIR, "test_motor.parquet")))
ibnr_rec <- fread(file.path(IBNR_DIR, "recommended_ibnr.csv"))[line == "motor"]
LONG_TAIL <- ibnr_rec[long_tail == TRUE, unique(peril)]
daily_share <- fread(file.path(IBNR_DIR, "recommended_daily_share.csv"))[line == "motor"][, date := as.Date(date)][order(peril, date)]
ROW_SHARE <- list(origin = min(daily_share$date), cumshare = lapply(split(daily_share, by = "peril"), function(x) cumsum(x$share)))
raw_claims <- read_raw("claims")[line == "motor"]
CL <- as.data.table(read_parquet(file.path(DATA_DIR, "claims_pos.parquet")))[line == "motor"]
CL <- merge(CL, raw_claims[, .(claim_id, policy_id, loss_date, report_date, paid_to_date, incurred_to_date, recoveries)],
            by = "claim_id", all.x = TRUE)
CL <- CL[row_id %in% train$row_id]
weather <- read_raw("weather")
wx_avg <- weather[year %in% 2021:2024, .(wx_avg_hail_days = mean(hail_days), wx_avg_freezing_days = mean(freezing_days)),
                  by = address_id]
first_claim <- CL[, .(policy_id, report_date)]
rm(weather, raw_claims); gc(verbose = FALSE)
train <- add_hist_split(engineer(train))
test <- add_hist_split(engineer(test))
add_shares(train, ROW_SHARE)
add_shares(test, ROW_SHARE)

res <- list()
for (vy in FOLDS) res[[as.character(vy)]] <- run_gam_fold(train[policy_year < vy], train[policy_year == vy], SEED + vy, vy)
res[["2025"]] <- run_gam_fold(copy(train), copy(test), SEED + 2025, 2025L)
g <- rbindlist(lapply(res, `[[`, "out"))
comp <- as.data.table(read_parquet(M4_COMP))
comp <- merge(comp, g, by = c("valid_year", "row_id"), sort = FALSE)
chk <- comp[, .(rows = .N, glm_max_rel_diff = max(abs(glm_check / glm_bodily_injury - 1))), by = valid_year]
print(chk)
comp[, glm_check := NULL]
write_parquet(comp, file.path(ITER_DIR, "components.parquet"))
fwrite(rbindlist(lapply(res, `[[`, "smooth")), file.path(ITER_DIR, "gam_smooth_edf.csv"))
log_msg("Done in ", round(as.numeric(difftime(Sys.time(), T0, units = "mins")), 1), " min -> ", ITER_DIR)
