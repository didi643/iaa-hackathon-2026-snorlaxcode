# 4_models_itermotor04.R ---------------------------------------------------------
# MOTOR 4: WENDY 9 per-peril LightGBM ladder rebuilt on MOTOR 2's motor features. Per peril three frequency versions,
# all multiplied by MOTOR 2's frozen severity x loading (week1/models/motor_iteration_02/final_config.csv):
#   glm    MOTOR 2 frequency (spline GLM, offset log(exposure x reported share); BI = 50/50 own GLM / pooled with TPP)
#   lgb    LightGBM Poisson with Wendy's per-peril recipe (ladder COMBO: OD/theft/GH G8, TPP G4, BI F11 params) on
#          MOTOR features + claim-history counts (hist_pol_n, hist_cust_other_n, claim_free_years, hist_coll_n,
#          hist_oth_n, coll_free_years); BI also gets the MOTOR 2 TPP frequency as a feature
#   boost  the same LightGBM started from the MOTOR 2 GLM frequency (init_score) - the trees only learn what the
#          spline GLM missed
# Folds: 2023 (fit 2021-22) is the SELECTION fold, 2024 (fit 2021-23) is the HELD-OUT fold; the final fit is 2021-24.
# This script only fits and saves components; week1/R/6_w9_motor04_eval.R selects on 2023 and decides on 2024.
# Outputs: week1/models/motor_iteration_04[_quick]/components.parquet (2023, 2024, 2025 rows), lgb_info.csv, lgb_importance.csv
# Env vars: MOTOR04_QUICK=1 (sampled policies)

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
suppressPackageStartupMessages({
  library(xgboost)
  library(splines)
})
T0 <- Sys.time()
QUICK <- Sys.getenv("MOTOR04_QUICK") == "1"
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
skip <- c("QUICK", "RUN_ID", "ITERATION_LABEL", "ITER_DIR", "FITTED_DIR", "T0", "checks", "in_header", "import_defs")
import_defs("week1/R/4_models_itermotor01.R", skip)
import_defs("week1/R/4_models_itermotor02.R", skip)

RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITER_DIR <- file.path("week1", "models", if (QUICK) "motor_iteration_04_quick" else "motor_iteration_04")
dir.create(ITER_DIR, recursive = TRUE, showWarnings = FALSE)
FOLDS <- c(2023L, 2024L)
COLL <- c("own_damage", "third_party_prop", "bodily_injury")
NEW_FEATS <- c("hist_coll_n", "hist_oth_n", "coll_free_years")
MONO <- c(MONO, hist_coll_n = 1, hist_oth_n = 1, coll_free_years = -1)
# MOTOR 2 final choices, frozen
CFG <- list(own_damage = list(freq = "glm", ftrend = 0, xgb = "x1", fw = 0, sev = "base", Z = 1, strend = 0, load = "raw"),
            third_party_prop = list(freq = "glm", ftrend = 1, xgb = "x1", fw = 0, sev = "base", Z = 0.5, strend = 1, load = "raw"),
            bodily_injury = list(freq = "mix", ftrend = 1, xgb = "x1", fw = 0, sev = "all", Z = 0, strend = 1, load = "raw"),
            theft = list(freq = "glm", ftrend = 1, xgb = "x1", fw = 0, sev = "base", Z = 1, strend = 1, load = "raw"),
            glass_hail = list(freq = "glm", ftrend = 1, xgb = "x1", fw = 0, sev = "base", Z = 0.75, strend = 1, load = "raw"))
# WENDY 9 LightGBM frequency settings (wendy_ladder_core.R FREQ_BASE + recipe P2A / G4 / G8)
LGB_BASE <- list(objective = "poisson", learning_rate = 0.05, feature_fraction = 0.7, bagging_fraction = 0.8,
                 bagging_freq = 1, lambda_l2 = 10, max_bin = 127, verbose = -1, num_threads = N_THREADS)
P2A <- list(num_leaves = 8, max_depth = 3, min_data_in_leaf = 100, min_sum_hessian_in_leaf = 60)
LGB_RECIPE <- list(own_damage = modifyList(P2A, list(min_sum_hessian_in_leaf = 6)),
                   third_party_prop = modifyList(P2A, list(num_leaves = 4, max_depth = 2)),
                   bodily_injury = P2A,
                   theft = modifyList(P2A, list(min_sum_hessian_in_leaf = 6)),
                   glass_hail = modifyList(P2A, list(min_sum_hessian_in_leaf = 6)))
LGB_MAX_ROUNDS <- if (QUICK) 500 else 3000

lgb_feats <- function(pr) {
  f <- setdiff(unique(c(TREE_CORE, FREQ_SEL[[pr]], "claim_free_years")), c("te_mm", "te_ru"))
  if (pr %in% COLL) f <- c(f, NEW_FEATS)
  if (pr == "glass_hail") f <- c(f, "hail_days", "freezing_days", "wx_avg_hail_days", "wx_avg_freezing_days")
  if (pr == BI) f <- c(f, "tpp_rate")
  unique(f)
}

# LightGBM Poisson on claims / effective exposure (weight = effective exposure, share floored at 5%); with init the
# trees start from log(GLM rate). Uncovered cover levels keep the GLM rate. Balanced to the training claim count.
lgb_freq <- function(tr, sc, pr, glm_tr, glm_sc, unc, use_init, seed) {
  cv <- !tr$cover_type %in% unc
  d <- tr[cv]
  n <- d[[paste0("y_npos_", pr)]]
  e <- pmax(d[[paste0("effexp_", pr)]], 0.05 * d$exposure)
  enc <- tree_enc(d, lgb_feats(pr), n, e)
  X <- lgb_matrix(d, enc$features, enc$cat_levels)
  base <- if (use_init) log(glm_tr[cv]) else rep(0, nrow(d))
  set.seed(seed)
  up <- unique(d$policy_id)
  h <- d$policy_id %in% sample(up, round(0.1 * length(up)))
  params <- c(LGB_BASE, LGB_RECIPE[[pr]], list(seed = seed, monotone_constraints = mono_of(enc$features)))
  mk <- function(i) lgb.Dataset(X[i, , drop = FALSE], label = n[i] / e[i], weight = e[i],
                                init_score = if (use_init) base[i] else NULL)
  dt <- mk(!h)
  dv <- lgb.Dataset.create.valid(dt, X[h, , drop = FALSE], label = n[h] / e[h], weight = e[h],
                                 init_score = if (use_init) base[h] else NULL)
  m <- lgb.train(params, dt, nrounds = LGB_MAX_ROUNDS, valids = list(v = dv), early_stopping_rounds = 100, verbose = -1)
  rounds <- max(m$best_iter, 5L)
  m <- lgb.train(params, mk(rep(TRUE, nrow(X))), nrounds = rounds, verbose = -1)
  bal <- sum(n) / sum(exp(predict(m, X, type = "raw") + base) * e)
  Xs <- lgb_matrix(sc, enc$features, enc$cat_levels)
  rate <- exp(predict(m, Xs, type = "raw") + (if (use_init) log(glm_sc) else 0)) * bal
  ucs <- sc$cover_type %in% unc
  rate[ucs] <- glm_sc[ucs]
  imp <- as.data.table(lgb.importance(m))[, .(feature = Feature, gain = Gain)]
  list(rate = rate, rounds = rounds, bal = bal, imp = imp)
}

# One fold (or the final fit): MOTOR 2 frozen GLMs, then the two LightGBM versions per peril
run_fold <- function(tr, sc, seed, label) {
  t1 <- Sys.time()
  info <- add_robust_loading(prep_fold(tr, sc, seed), tr)
  fits <- fit_all2(tr, info, seed, final = TRUE, cfg = CFG, blend = list(tw = 0, legacy = 0))
  P_tr <- lapply(setNames(PR, PR), function(pr) peril_parts2(fits$perils[[pr]], tr, info, pr))
  P_sc <- lapply(setNames(PR, PR), function(pr) peril_parts2(fits$perils[[pr]], sc, info, pr))
  f_tr <- sapply(PR, function(pr) freq_of2(P_tr[[pr]], CFG[[pr]], tr$exposure))
  f_sc <- sapply(PR, function(pr) freq_of2(P_sc[[pr]], CFG[[pr]], sc$exposure))
  set(tr, j = "tpp_rate", value = f_tr[, "third_party_prop"])
  set(sc, j = "tpp_rate", value = f_sc[, "third_party_prop"])
  out <- data.table(valid_year = as.integer(label), row_id = sc$row_id, policy_id = sc$policy_id, exposure = sc$exposure)
  lgi <- list(); imp <- list()
  for (k in seq_along(PR)) {
    pr <- PR[k]
    cfg <- CFG[[pr]]
    sev <- sev_of2(P_sc[[pr]], cfg) * P_sc[[pr]]$loading[[cfg$load]] * sc$exposure
    unc <- names(info$unc_rate[[pr]])
    set(out, j = paste0("glm_", pr), value = f_sc[, pr] * sev)
    for (v in c("lgb", "boost")) {
      o <- lgb_freq(tr, sc, pr, f_tr[, pr], f_sc[, pr], unc, v == "boost", seed + 10 * k + (v == "boost"))
      set(out, j = paste0(v, "_", pr), value = o$rate * sev)
      lgi[[paste(pr, v)]] <- data.table(fit = label, peril = pr, version = v, rounds = o$rounds, balance = o$bal)
      imp[[paste(pr, v)]] <- o$imp[, `:=`(fit = label, peril = pr, version = v)]
    }
    if ("y_cost" %in% names(sc)) {
      set(out, j = paste0("rep_", pr), value = sc[[paste0("y_cost_", pr)]])
      set(out, j = paste0("dev_", pr), value = sc[[paste0("y_cost_", pr)]] / sc[[paste0("sh_", pr)]])
    }
    log_msg(label, " ", pr, ": rounds lgb / boost ", lgi[[paste(pr, "lgb")]]$rounds, " / ", lgi[[paste(pr, "boost")]]$rounds)
  }
  log_msg("Fit ", label, " done in ", round(as.numeric(difftime(Sys.time(), t1, units = "mins")), 1), " min")
  list(out = out, info = rbindlist(lgi), imp = rbindlist(imp))
}

# Phase A: data (as MOTOR 3) ----------------------------------------------------------------------------
log_msg("Phase A: data")
train <- as.data.table(read_parquet(file.path(DATA_DIR, "train_motor.parquet")))
test <- as.data.table(read_parquet(file.path(DATA_DIR, "test_motor.parquet")))
if (QUICK) {
  set.seed(SEED)
  train <- train[policy_id %in% sample(unique(policy_id), QUICK_POLICIES)]
}
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
add_hist_split <- function(d) {
  parts <- lapply(sort(unique(d$policy_year)), function(Y) {
    y0 <- as.Date(sprintf("%d-01-01", Y))
    k <- CL[report_date < y0, .(n_coll = sum(peril %in% COLL), n_oth = sum(!peril %in% COLL),
                                last_coll = if (any(peril %in% COLL)) max(report_date[peril %in% COLL]) else as.Date(NA)),
            by = policy_id]
    x <- merge(d[policy_year == Y, .(row_id, policy_id, years_with_insurer)], k, by = "policy_id", all.x = TRUE)
    x[is.na(n_coll), n_coll := 0L]
    x[is.na(n_oth), n_oth := 0L]
    x[, coll_free_years := fifelse(is.na(last_coll), as.numeric(pmin(pmax(years_with_insurer, 0), Y - 2021)),
                                   as.numeric(y0 - last_coll) / 365)]
    x[, .(row_id, hist_coll_n = pmin(n_coll, 3L), hist_oth_n = pmin(n_oth, 3L), coll_free_years)]
  })
  d <- merge(d, rbindlist(parts), by = "row_id", all.x = TRUE, sort = FALSE)
  setorder(d, row_id)
  d
}
train <- add_hist_split(engineer(train))
test <- add_hist_split(engineer(test))
add_shares(train, ROW_SHARE)
add_shares(test, ROW_SHARE)

# Phase B: selection fold 2023, held-out fold 2024, final fit 2021-24 -> 2025 ----------------------------
res <- list()
for (vy in FOLDS) res[[as.character(vy)]] <- run_fold(train[policy_year < vy], train[policy_year == vy], SEED + vy, vy)
res[["2025"]] <- run_fold(copy(train), copy(test), SEED + 2025, 2025L)

comp <- rbindlist(lapply(res, `[[`, "out"), fill = TRUE)
write_parquet(comp, file.path(ITER_DIR, "components.parquet"))
fwrite(rbindlist(lapply(res, `[[`, "info")), file.path(ITER_DIR, "lgb_info.csv"))
fwrite(rbindlist(lapply(res, `[[`, "imp")), file.path(ITER_DIR, "lgb_importance.csv"))
sm <- comp[, c(list(rows = .N), lapply(.SD, function(x) sum(x) / sum(exposure))), by = valid_year,
           .SDcols = grep("^(glm|lgb|boost|dev)_", names(comp), value = TRUE)]
print(sm)
fwrite(sm, file.path(ITER_DIR, "burn_by_component.csv"))
fwrite(data.table(run_id = RUN_ID, quick = QUICK, minutes = round(as.numeric(difftime(Sys.time(), T0, units = "mins")), 1)),
       file.path(ITER_DIR, "summary.csv"))
log_msg("Done in ", round(as.numeric(difftime(Sys.time(), T0, units = "mins")), 1), " min -> ", ITER_DIR)
