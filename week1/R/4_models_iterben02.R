# 4_models_iterben02.R -----------------------------------------------------
# BEN 2: per-peril cost models (no frequency/severity split) on BEN 1's v6 setup, changed one step at a time.
#   Folds:      expanding window, fit 2021-22 -> 2023 and 2021-23 -> 2024; final fit 2021-24 -> 2025 (as BEN 1 v6).
#   Variants:   v0 BEN 1 v6, one XGBoost Tweedie per line (reproduces BEN 1)
#               v1 one XGBoost Tweedie per peril, line = sum of perils; per-peril large-loss cap, cap loading and
#                  IBNR factor; BEN 1's line trend applied to every peril
#               v2 + BEN's own cleaning (week1/R/ben/ben_clean.R -> data/week_1/ben/): types matching each column's meaning,
#                  claims history known when the row starts; cost-weighted IBNR per peril; trend per peril;
#                  sensible-direction constraints per peril (flood_zone only for flood; more past claims -> higher)
#               v3 v2's data and targets, but each peril's model type and settings chosen by h2o AutoML (GBM, GLM,
#                  random forest; fit 2021, ranked by D2 on 2022), refitted per window, plus a balance factor so each
#                  peril's predictions add up to its training cost (week1/R/ben/ben_h2o.R)
#   Selection:  per line, highest mean local D2 over 2023 and 2024 (Kaggle metric, actuals as reported), as BEN 1.
#   Unchanged from BEN 1 v6: features (EDA fixes), renewal_count cap, credibility-ordered categorical levels,
#   monotone constraints, tuned XGBoost parameters per line (week1/models/ben_iteration_01/xgb_tuning.csv), seeds.
# Run:     Rscript week1/R/ben/ben_clean.R, then Rscript week1/R/4_models_iterben02.R
#          smoke test: env vars BEN_MAX_ROUNDS=20 BEN_AML_MODELS=2 BEN_AML_SECS=30; h2o needs a 64-bit JDK 17
#          (BEN_JAVA_HOME, else ~/tools/jdk-17*)
# Outputs: week1/output/4_models/ (model_report.md, run_history.csv), week1/output/submission/,
#          week1/models/ben_iteration_02/ (model_card.md + CSVs + plots + fitted models; tracked in git)

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
source("week1/R/ben/ben_helpers.R")
suppressPackageStartupMessages(library(xgboost))
STEP <- "4_models"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITERATION <- "BEN 2"
ITERATION_NOTE <- paste("Per-peril XGBoost Tweedie cost models (no frequency/severity split) on BEN 1's v6 setup;",
                        "line = sum of perils with per-peril large-loss cap, cap loading and IBNR (v1);",
                        "v2 adds BEN's own cleaning (type fixes, claims history), cost-weighted IBNR, trend and",
                        "sensible-direction constraints per peril.")
ITER_DIR <- file.path("week1", "models", "ben_iteration_02")
VALID_YEARS <- c(2023, 2024)
TARGET_YEAR <- 2025
TREND_CAP <- 0.05            # annual trend clamped to +-5%
CRED_K <- 200                # exposure-years of credibility when ordering categorical levels by cost rate
XGB_MAX_ROUNDS <- as.integer(Sys.getenv("BEN_MAX_ROUNDS", "2000"))   # smoke test: BEN_MAX_ROUNDS=20
FORCE_VARIANT <- Sys.getenv("BEN_SELECT", "")   # testing only: use this variant for every line's final fit
AML_MODELS <- as.integer(Sys.getenv("BEN_AML_MODELS", "8"))    # AutoML candidates per peril (v3)
AML_SECS <- as.numeric(Sys.getenv("BEN_AML_SECS", "300"))      # AutoML time budget per peril (v3)

# Carried over from BEN 1 v6
BEN_EXCLUDE <- c("compulsory_excess", "years_with_insurer", "customer_since_year", "campaign_code", "written_premium")
CAP_FEATURES <- "renewal_count"
MONOTONE <- c(ncb_years = -1, prior_claims_5y = 1, licence_points = 1, missed_payments_12m = 1, flood_zone = 1,
              voluntary_excess = -1)
PARAM_NAMES <- c("max_depth", "learning_rate", "min_child_weight", "subsample", "colsample_bytree", "reg_lambda",
                 "tweedie_variance_power")
ben1_tuning <- fread("week1/models/ben_iteration_01/xgb_tuning.csv")
PARAMS <- lapply(setNames(LINES, LINES), function(ln) ben1_tuning[line == ln][which.max(d2_2022), ..PARAM_NAMES])

VARIANTS <- list(
  v0 = list(label = "BEN 1 v6: one XGBoost Tweedie per line", by_peril = FALSE, data = "clean", ibnr = "count",
            trend = "line", monotone = "line", learner = "xgb"),
  v1 = list(label = "+ one model per peril, line = sum of perils", by_peril = TRUE, data = "clean", ibnr = "count",
            trend = "line", monotone = "line", learner = "xgb"),
  v2 = list(label = "+ BEN cleaning (types, claims history), cost IBNR, trend and constraints per peril", by_peril = TRUE,
            data = "ben", ibnr = "cost", trend = "peril", monotone = "peril", learner = "xgb")
)
VARIANTS$v3 <- modifyList(VARIANTS$v2, list(label = "+ h2o AutoML per peril, plus a log-link GLM candidate (chosen on 2021 -> 2022), balance factor",
                                            learner = "h2o"))
# v2 constraints: flood_zone only for the flood perils; more past claims -> higher cost
HISTORY_MONOTONE <- setNames(rep(1, length(BEN_HISTORY)), BEN_HISTORY)
load_data <- function(name, v) if (v$data == "ben") read_ben(name) else read_clean(name)

fit_seed <- function(ln, year) SEED + 1000 * match(ln, LINES) + 700 + (year - 2020)   # as BEN 1

ibnr_peril_file <- file.path(PATHS$output, "3_incidence", "ibnr_factors_by_peril.csv")
if (!file.exists(ibnr_peril_file)) stop("Missing ", ibnr_peril_file, " - run week1/R/3_incidence.R first.")
ibnr_peril <- fread(ibnr_peril_file)
ibnr_cost_file <- ben_out("ibnr_cost_by_peril.csv")
if (!file.exists(ibnr_cost_file)) stop("Missing ", ibnr_cost_file, " - run week1/R/ben/ben_clean.R first.")
ibnr_cost <- fread(ibnr_cost_file)

# Development (IBNR) ---------------------------------------------------------------------------------------
# how = "count": week1/R/3_incidence.R count factors; "cost": cost-weighted factors from week1/R/ben/ben_clean.R
peril_dev <- function(years, ln, pr, how = "count") {
  tab <- (if (how == "cost") ibnr_cost else ibnr_peril)[line == ln & peril == pr]
  f <- tab$ibnr_factor[match(years, tab$policy_year)]
  f[is.na(f)] <- 1
  f
}
# Row factor for the line total: per-peril factors weighted by the row's peril costs (BEN 1 "IBNR by peril")
row_dev <- function(dt, ln) {
  num <- 0
  for (pr in PERILS[[ln]]) num <- num + dt[[paste0("y_cost_", pr)]] * peril_dev(dt$policy_year, ln, pr)
  fifelse(dt$y_cost > 0, num / dt$y_cost, 1)
}

# Annual trend in capped, developed burn cost of the years before `upto` (log-linear, exposure-weighted,
# clamped); cost = the line total (pr = NULL, as BEN 1) or one peril's cost
trend_rate <- function(dt, ln, upto, pr = NULL, how = "count") {
  d <- dt[policy_year < upto]
  if (uniqueN(d$policy_year) < 2) return(0)
  if (is.null(pr)) {
    cost <- d$y_cost; dev <- row_dev(d, ln)
  } else {
    cost <- d[[paste0("y_cost_", pr)]]; dev <- peril_dev(d$policy_year, ln, pr, how)
  }
  cap <- quantile(cost[cost > 0], LARGE_LOSS_QUANTILE, names = FALSE)
  y <- data.table(policy_year = d$policy_year, cost = pmin(cost, cap) * dev, exposure = d$exposure)[
    , .(burn = sum(cost) / sum(exposure), exposure = sum(exposure)), by = policy_year]
  if (any(y$burn <= 0)) return(0)
  b <- coef(lm(log(burn) ~ policy_year, data = y, weights = exposure))[["policy_year"]]
  max(min(b, TREND_CAP), -TREND_CAP)
}

# XGBoost --------------------------------------------------------------------------------------------------
# Categorical levels as integer codes ordered by a credibility-weighted cost rate of the model's own target
make_levels <- function(tr, feats, target, k = CRED_K) {
  cats <- feats[vapply(feats, function(f) is.character(tr[[f]]), logical(1))]
  base <- sum(target) / sum(tr$exposure)
  lapply(setNames(cats, cats), function(f) {
    r <- data.table(level = tr[[f]], t = target, e = tr$exposure)[, .(rate = (sum(t) + k * base) / (sum(e) + k)), by = level]
    r[order(rate, level)]$level
  })
}

# mode "line": BEN 1's constraints for every model; "peril": flood_zone only for the flood perils, plus claims history
mono_string <- function(feats, tr, peril = NULL, mode = "line") {
  rules <- MONOTONE
  if (mode == "peril") {
    if (!identical(peril, "flood")) rules <- rules[names(rules) != "flood_zone"]
    rules <- c(rules, HISTORY_MONOTONE)
  }
  m <- rules[feats]
  m[is.na(m) | !vapply(feats, function(f) is.numeric(tr[[f]]), logical(1))] <- 0
  paste0("(", paste(m, collapse = ","), ")")
}

xgb_train <- function(X, rate, w, hold, cfg, mono = NULL) {
  dtr <- xgb.DMatrix(X[!hold, , drop = FALSE], label = rate[!hold], weight = w[!hold], nthread = 4)
  dva <- xgb.DMatrix(X[hold, , drop = FALSE], label = rate[hold], weight = w[hold], nthread = 4)
  params <- c(list(objective = "reg:tweedie", tweedie_variance_power = cfg$tweedie_variance_power,
                   learning_rate = cfg$learning_rate, max_depth = cfg$max_depth, min_child_weight = cfg$min_child_weight,
                   subsample = cfg$subsample, colsample_bytree = cfg$colsample_bytree, reg_lambda = cfg$reg_lambda,
                   tree_method = "hist", nthread = 4, seed = SEED,
                   eval_metric = paste0("tweedie-nloglik@", cfg$tweedie_variance_power)),
              if (!is.null(mono)) list(monotone_constraints = mono))
  xgb.train(params = params, data = dtr, nrounds = XGB_MAX_ROUNDS, evals = list(holdout = dva),
            early_stopping_rounds = 50, verbose = 0)
}

# One XGBoost Tweedie model on one cost column (as reported): capped at p99.9 of its positive values, developed
# with `dev`, trended to target_year; scores te with score_model(), as a reloaded model would
fit_one <- function(tr, te, ln, cost, dev, trend, target_year, cfg, hold, peril, mono_mode = "line") {
  cap <- quantile(cost[cost > 0], LARGE_LOSS_QUANTILE, names = FALSE)
  loading <- sum(cost) / sum(pmin(cost, cap))
  target <- pmin(cost, cap) * dev * exp(trend * (target_year - tr$policy_year))
  feats <- setdiff(feature_cols(tr, include_new = TRUE), BEN_EXCLUDE)
  lv <- make_levels(tr, feats, target)
  cf <- intersect(CAP_FEATURES, feats)
  caps <- if (length(cf)) setNames(vapply(cf, function(f) max(tr[[f]], na.rm = TRUE), numeric(1)), cf)
  X <- lgb_matrix(tr, feats, lv, caps)
  m <- xgb_train(X, target / tr$exposure, tr$exposure, hold, cfg, mono_string(feats, tr, peril, mono_mode))
  rm(X); gc(verbose = FALSE)
  best_iter <- as.integer(xgb.attr(m, "best_iteration"))
  art <- list(model = "xgb_tweedie", line = ln, peril = peril, loading = loading, cap = cap, features = feats,
              cat_levels = lv, caps = caps, best_iter = best_iter, params = cfg, trend = trend, booster = m)
  list(artifact = art, pred = score_model(art, te), best_iter = best_iter)
}

# h2o (v3) -------------------------------------------------------------------------------------------------
USE_H2O <- any(vapply(VARIANTS, function(v) v$learner == "h2o", logical(1)))
if (USE_H2O) { source("week1/R/ben/ben_h2o.R"); ben_h2o_start() }
H2O_ALGOS_USED <- if (USE_H2O) H2O_ALGOS else "-"
H2O_THREADS_USED <- if (USE_H2O) H2O_THREADS else NA_integer_
H2O_SETTINGS <- list(); h2o_tuning <- list()

# One peril's target in a fit window: cost capped at p99.9 of its positive values, developed, trended
peril_target <- function(tr, ln, pr, how, trend, target_year) {
  cost <- tr[[paste0("y_cost_", pr)]]
  cap <- quantile(cost[cost > 0], LARGE_LOSS_QUANTILE, names = FALSE)
  list(target = pmin(cost, cap) * peril_dev(tr$policy_year, ln, pr, how) * exp(trend * (target_year - tr$policy_year)),
       cap = cap, loading = sum(cost) / sum(pmin(cost, cap)))
}
h2o_feats <- function(dt) setdiff(feature_cols(dt, include_new = TRUE), BEN_EXCLUDE)
# Off: h2o 3.44's GBM fails with monotone constraints under a Tweedie distribution ("Monotonicity constraint
# violated", IllegalStateException), so every GBM candidate would drop out. v0-v2 (XGBoost) keep their constraints.
H2O_MONOTONE <- FALSE
h2o_mono <- function(dt, feats, pr) {
  if (!H2O_MONOTONE) return(NULL)
  rules <- MONOTONE
  if (pr != "flood") rules <- rules[names(rules) != "flood_zone"]
  ben_h2o_mono(c(rules, HISTORY_MONOTONE), feats, dt)
}

# Model type and settings per peril: AutoML fitted on 2021 (10% policy holdout for early stopping), ranked by the
# Kaggle metric on 2022 - both validation years stay out
tune_h2o_line <- function(dt, ln) {
  tr <- dt[policy_year == 2021]; lb <- dt[policy_year == 2022]
  feats <- h2o_feats(dt)
  set.seed(fit_seed(ln, 2022))
  pol <- unique(tr$policy_id)
  hold <- tr$policy_id %in% sample(pol, round(0.1 * length(pol)))
  tg <- lapply(setNames(PERILS[[ln]], PERILS[[ln]]), function(pr) peril_target(tr, ln, pr, "cost", 0, 2022))
  ys <- setNames(lapply(tg, function(t) t$target / tr$exposure), paste0("y_", names(tg)))
  f_tr <- ben_h2o_frame(tr[!hold], feats, c(lapply(ys, `[`, !hold), list(w = tr$exposure[!hold])))
  f_va <- ben_h2o_frame(tr[hold], feats, c(lapply(ys, `[`, hold), list(w = tr$exposure[hold])))
  f_lb <- ben_h2o_frame(lb, feats, c(setNames(lapply(PERILS[[ln]], function(pr) lb[[paste0("y_cost_", pr)]] / lb$exposure),
                                              paste0("y_", PERILS[[ln]])), list(w = lb$exposure)))
  out <- list()
  for (pr in PERILS[[ln]]) {
    t0 <- Sys.time()
    out[[pr]] <- ben_h2o_tune(f_tr, f_va, f_lb, feats, paste0("y_", pr), "w", h2o_mono(tr, feats, pr),
                              lb[[paste0("y_cost_", pr)]], lb$exposure, tg[[pr]]$loading, AML_MODELS, AML_SECS,
                              seed = fit_seed(ln, 2022) + match(pr, PERILS[[ln]]),
                              name = paste0("ben02_", ln, "_", pr, "_", RUN_ID), d2_fun = d2_tweedie)
    log_msg("AutoML ", ln, " / ", pr, ": best ", out[[pr]]$ranking$model_id[1], " (D2 2022 ",
            round(out[[pr]]$ranking$d2_2022[1], 4), ") in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s")
  }
  h2o.rm(f_tr); h2o.rm(f_va); h2o.rm(f_lb)
  out
}

# v3 for one line: each peril refitted with its AutoML settings on the window, then a balance factor so its
# predictions on the fit rows add up to its (capped, developed, trended) training cost
fit_h2o_variant <- function(dt, tr, te, ln, target_year) {
  feats <- h2o_feats(tr)
  trends <- vapply(PERILS[[ln]], function(pr) trend_rate(dt, ln, target_year, pr, "cost"), numeric(1))
  tgs <- lapply(setNames(PERILS[[ln]], PERILS[[ln]]), function(pr) peril_target(tr, ln, pr, "cost", trends[[pr]], target_year))
  ys <- setNames(lapply(tgs, function(t) t$target / tr$exposure), paste0("y_", names(tgs)))
  f_tr <- ben_h2o_frame(tr, feats, c(ys, list(w = tr$exposure)))
  f_te <- ben_h2o_frame(te, feats)
  comps <- list(); preds <- list(); rounds <- c()
  for (pr in PERILS[[ln]]) {
    s <- H2O_SETTINGS[[ln]][[pr]]
    m <- ben_h2o_refit(s, f_tr, feats, paste0("y_", pr), "w", seed = fit_seed(ln, target_year) + match(pr, PERILS[[ln]]),
                       mono = h2o_mono(tr, feats, pr))
    balance <- sum(tgs[[pr]]$target) / sum(ben_h2o_predict(m, f_tr) * tr$exposure)
    preds[[pr]] <- ben_h2o_predict(m, f_te) * balance * tgs[[pr]]$loading * te$exposure
    rounds[pr] <- if (!is.null(s$params$ntrees)) as.integer(s$params$ntrees) else NA_integer_
    comps[[pr]] <- list(model = m, algo = s$algo, peril = pr, features = feats, balance = balance,
                        loading = tgs[[pr]]$loading, cap = tgs[[pr]]$cap, trend = trends[[pr]], best_iter = rounds[[pr]],
                        settings = s$params)
  }
  h2o.rm(f_tr); h2o.rm(f_te)
  list(artifact = list(model = "h2o_peril_sum", line = ln, components = comps), pred = Reduce(`+`, preds),
       peril_pred = preds, best_iter = rounds, trend = trends)
}
drop_h2o_models <- function(art) if (identical(art$model, "h2o_peril_sum")) for (cmp in art$components) h2o.rm(cmp$model)

# A variant's model for one line: one model on the line total (v0) or one per peril summed (v1-v3)
fit_variant <- function(dt, tr, te, ln, v, target_year, hold) {
  if (v$learner == "h2o") return(fit_h2o_variant(dt, tr, te, ln, target_year))
  cfg <- PARAMS[[ln]]
  line_trend <- trend_rate(dt, ln, target_year)
  if (!v$by_peril) {
    f <- fit_one(tr, te, ln, tr$y_cost, row_dev(tr, ln), line_trend, target_year, cfg, hold, "all")
    return(c(f, list(trend = c(all = line_trend))))
  }
  comps <- list(); preds <- list(); rounds <- c(); trends <- c()
  for (pr in PERILS[[ln]]) {
    tp <- if (v$trend == "peril") trend_rate(dt, ln, target_year, pr, v$ibnr) else line_trend
    f <- fit_one(tr, te, ln, tr[[paste0("y_cost_", pr)]], peril_dev(tr$policy_year, ln, pr, v$ibnr), tp, target_year,
                 cfg, hold, pr, v$monotone)
    comps[[pr]] <- f$artifact; preds[[pr]] <- f$pred; rounds[pr] <- f$best_iter; trends[pr] <- tp
  }
  list(artifact = list(model = "peril_sum", line = ln, components = comps), pred = Reduce(`+`, preds),
       peril_pred = preds, best_iter = rounds, trend = trends)
}

# Metrics ------------------------------------------------------------------------------------------------
tweedie_dev <- function(y, mu, p = TWEEDIE_P) {
  mu <- pmax(mu, 1e-6)
  2 * mean(ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
norm_gini <- function(y, s) {
  g <- function(a, s) {
    a <- a[order(s, decreasing = TRUE)]
    n <- length(a)
    sum(cumsum(a) / sum(a) - seq_len(n) / n) / n
  }
  g(y, s) / g(y, y)
}
# Kaggle metric: Tweedie D2 (p = 1.5) vs a constant-rate baseline (one cost per exposure-year x exposure)
d2_tweedie <- function(y, pred, exposure, p = TWEEDIE_P) {
  baseline <- exposure * sum(y) / sum(exposure)
  1 - tweedie_dev(y, pred, p) / tweedie_dev(y, baseline, p)
}
fmt_named <- function(x, digits = 3) paste(sprintf(paste0("%s %.", digits, "f"), names(x), x), collapse = "; ")

# 1. Validation: every variant, both folds, per line -----------------------------------------------------
metrics <- list(); preds <- list(); peril_metrics <- list()
for (ln in LINES) {
  data_sets <- list(clean = read_clean(paste0("train_", ln)))
  if (any(vapply(VARIANTS, function(v) v$data == "ben", logical(1)))) data_sets$ben <- read_ben(paste0("train_", ln))
  stopifnot(all(vapply(data_sets, function(d) identical(d$row_id, data_sets$clean$row_id), logical(1))))   # same rows, same order
  if (USE_H2O) {
    H2O_SETTINGS[[ln]] <- tune_h2o_line(data_sets$ben, ln)
    h2o_tuning[[ln]] <- rbindlist(lapply(names(H2O_SETTINGS[[ln]]), function(pr)
      H2O_SETTINGS[[ln]][[pr]]$ranking[, `:=`(line = ln, peril = pr, rank = .I)]))
  }
  for (vn in names(VARIANTS)) {
    v <- VARIANTS[[vn]]
    dt <- data_sets[[v$data]]
    for (vy in VALID_YEARS) {
      tr <- dt[policy_year < vy]
      va <- dt[policy_year == vy]
      set.seed(fit_seed(ln, vy))
      pol <- unique(tr$policy_id)
      hold <- tr$policy_id %in% sample(pol, round(0.1 * length(pol)))   # same early-stopping holdout for every peril
      t0 <- Sys.time()
      fit <- fit_variant(dt, tr, va, ln, v, vy, hold)
      actual_dev <- va$y_cost * row_dev(va, ln)
      key <- paste(vn, ln, vy)
      metrics[[key]] <- data.table(
        variant = vn, line = ln, valid_year = vy, d2 = d2_tweedie(va$y_cost, fit$pred, va$exposure),
        d2_developed = d2_tweedie(actual_dev, fit$pred, va$exposure), gini = norm_gini(va$y_cost, fit$pred),
        pred_vs_reported = sum(fit$pred) / sum(va$y_cost), pred_vs_developed = sum(fit$pred) / sum(actual_dev),
        rounds = sum(fit$best_iter, na.rm = TRUE), trend = fmt_named(fit$trend),
        fit_seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))
      preds[[key]] <- data.table(variant = vn, line = ln, valid_year = vy, exposure = va$exposure,
                                 actual = va$y_cost, actual_dev = actual_dev, pred = fit$pred)
      if (v$by_peril) for (pr in names(fit$peril_pred)) {
        y <- va[[paste0("y_cost_", pr)]]
        p <- fit$peril_pred[[pr]]
        peril_metrics[[paste(key, pr)]] <- data.table(
          variant = vn, line = ln, peril = pr, valid_year = vy, cost_share = sum(y) / sum(va$y_cost),
          d2 = d2_tweedie(y, p, va$exposure), d2_developed = d2_tweedie(y * peril_dev(va$policy_year, ln, pr), p, va$exposure),
          pred_vs_reported = sum(p) / sum(y), trend = fit$trend[[pr]], rounds = fit$best_iter[[pr]])
      }
      log_msg(vn, " / ", ln, " / ", vy, ": D2 ", round(metrics[[key]]$d2, 4), " in ", metrics[[key]]$fit_seconds, "s")
      drop_h2o_models(fit$artifact)
      rm(tr, va, fit); gc(verbose = FALSE)
    }
  }
  rm(dt, data_sets); gc(verbose = FALSE)
}
res <- rbindlist(metrics)
pv <- rbindlist(preds)
peril_res <- rbindlist(peril_metrics)

res[, mean_d2 := mean(d2), by = .(line, variant)]
sel <- res[, .(mean_d2 = mean_d2[1]), by = .(line, variant)][order(-mean_d2), .SD[1], by = line][match(LINES, line)]
if (nzchar(FORCE_VARIANT)) sel <- res[variant == FORCE_VARIANT, .(mean_d2 = mean_d2[1]), by = .(line, variant)][match(LINES, line)]
sel[, label := vapply(variant, function(vn) VARIANTS[[vn]]$label, "")]
pv_sel <- pv[sel[, .(line, variant)], on = .(line, variant)]
for (ln in LINES) log_msg(ln, ": selected ", sel[line == ln, variant], " (", sel[line == ln, label], ")")

combined <- function(p) p[, .(d2 = d2_tweedie(actual, pred, exposure), d2_developed = d2_tweedie(actual_dev, pred, exposure),
                              gini = norm_gini(actual, pred)), by = valid_year]
all_variants <- rbind(rbindlist(lapply(names(VARIANTS), function(vn) combined(pv[variant == vn])[, variant := vn])),
                      combined(pv_sel)[, variant := "selected per line"])
line_score <- rbindlist(lapply(VALID_YEARS, function(vy) {
  v <- pv_sel[valid_year == vy]
  by_line <- v[, .(d2 = d2_tweedie(actual, pred, exposure), deviance = tweedie_dev(actual, pred) * .N), by = line]
  tot <- data.table(line = "ALL", d2 = d2_tweedie(v$actual, v$pred, v$exposure), deviance = sum(by_line$deviance))
  rbind(by_line, tot)[, `:=`(valid_year = vy, deviance_share = deviance / sum(by_line$deviance))]
}))
line_score_wide <- dcast(line_score, line ~ valid_year, value.var = c("d2", "deviance_share"))[match(c(LINES, "ALL"), line)]
variant_table <- dcast(res, line + variant ~ valid_year, value.var = c("d2", "d2_developed", "pred_vs_reported"))
variant_table[, `:=`(mean_d2 = (d2_2023 + d2_2024) / 2, label = vapply(variant, function(vn) VARIANTS[[vn]]$label, ""))]
setcolorder(variant_table, c("line", "variant", "label"))
peril_table <- dcast(peril_res, line + peril + variant ~ valid_year, value.var = c("cost_share", "d2", "d2_developed", "trend"))

# 2. Final fit 2021-24 per line with the selected variant, score 2025 -> submission ----------------------
unlink(ITER_DIR, recursive = TRUE)
FITTED_DIR <- file.path(ITER_DIR, "fitted")
dir.create(FITTED_DIR, recursive = TRUE, showWarnings = FALSE)   # OneDrive can keep the emptied folder
model_name <- function(ln, vn) {
  v <- VARIANTS[[vn]]
  paste(ln, if (v$learner == "h2o") "h2o_peril_sum" else if (v$by_peril) "xgb_peril_sum" else "xgb_tweedie", sep = "_")
}
sub_parts <- list(); test_summary <- list(); imp_final <- list(); features_used <- list(); trend_final <- list()
for (ln in LINES) {
  vn <- sel[line == ln, variant]
  dt <- load_data(paste0("train_", ln), VARIANTS[[vn]])
  te <- load_data(paste0("test_", ln), VARIANTS[[vn]])
  set.seed(fit_seed(ln, TARGET_YEAR))
  pol <- unique(dt$policy_id)
  hold <- dt$policy_id %in% sample(pol, round(0.1 * length(pol)))
  fit <- fit_variant(dt, dt, te, ln, VARIANTS[[vn]], TARGET_YEAR, hold)
  is_h2o <- identical(fit$artifact$model, "h2o_peril_sum")
  if (is_h2o) {
    ben_h2o_save_line(lapply(fit$artifact$components, `[[`, "model"),
                      lapply(fit$artifact$components, function(cmp) { cmp$model <- NULL; cmp }), FITTED_DIR, ln)
  } else save_model(fit$artifact, FITTED_DIR, model_name(ln, vn))
  pred <- pmax(fit$pred, 0)
  comps <- if (fit$artifact$model %in% c("peril_sum", "h2o_peril_sum")) fit$artifact$components else list(all = fit$artifact)
  q <- quantile(pred, c(0.5, 0.9, 0.99), names = FALSE)
  test_summary[[ln]] <- data.table(line = ln, variant = vn, models = length(comps), test_exposure = sum(te$exposure),
                                   predicted_total = sum(pred), predicted_burn_cost = sum(pred) / sum(te$exposure),
                                   train_burn_2023_24 = dt[policy_year >= 2023, sum(y_cost) / sum(exposure)],
                                   p50_row = q[1], p90_row = q[2], p99_row = q[3], max_row = max(pred))
  trend_final[[ln]] <- data.table(line = ln, model = names(comps), trend = fit$trend[names(comps)],
                                  cap = vapply(comps, `[[`, numeric(1), "cap"), cap_loading = vapply(comps, `[[`, numeric(1), "loading"),
                                  rounds = vapply(comps, `[[`, integer(1), "best_iter"))
  features_used[[ln]] <- data.table(line = ln, n_features = length(comps[[1]]$features),
                                    features = paste(comps[[1]]$features, collapse = ", "))
  imp_final[[ln]] <- rbindlist(lapply(names(comps), function(nm) {
    imp <- if (is_h2o) {
      vi <- as.data.table(h2o.varimp(comps[[nm]]$model))
      if (nrow(vi)) vi[, .(Feature = variable, Gain = percentage)] else data.table(Feature = character(), Gain = numeric())
    } else as.data.table(xgb.importance(model = comps[[nm]]$booster))
    imp[, `:=`(line = ln, model = if (is_h2o) paste(nm, comps[[nm]]$algo) else nm, rank = .I)]
  }), fill = TRUE)
  sub_parts[[ln]] <- data.table(row_id = te$row_id, prediction = pred)
  drop_h2o_models(fit$artifact)
  log_msg(ln, " (", vn, ") refitted on 2021-24 and scored on test")
  rm(dt, te, pred, fit); gc(verbose = FALSE)
}
test_summary <- rbindlist(test_summary); imp_final <- rbindlist(imp_final)
features_used <- rbindlist(features_used); trend_final <- rbindlist(trend_final)
sub <- rbindlist(sub_parts)
sample_sub <- read_raw("sample_submission")
stopifnot(nrow(sub) == nrow(sample_sub), setequal(sub$row_id, sample_sub$row_id),
          !anyDuplicated(sub$row_id), !anyNA(sub$prediction), all(sub$prediction >= 0))
sub <- sub[match(sample_sub$row_id, row_id)]
sub_file <- out_file("submission", "submission_provisional.csv")
fwrite(sub, sub_file, scipen = 50)
run_file <- out_file("submission", paste0("submission_", RUN_ID, ".csv"))
invisible(file.copy(sub_file, run_file, overwrite = TRUE))
sub_md5 <- unname(tools::md5sum(run_file))

# Replication check: reload the saved models from disk, re-score the test rows, compare with the submission
replication <- rbindlist(lapply(LINES, function(ln) {
  vn <- sel[line == ln, variant]
  te <- load_data(paste0("test_", ln), VARIANTS[[vn]])   # BEN-cleaned rows for v2 and v3 models
  nm <- model_name(ln, vn)
  re <- if (VARIANTS[[vn]]$learner == "h2o") {
    art <- ben_h2o_load_line(FITTED_DIR, ln)
    on.exit(drop_h2o_models(art))
    pmax(ben_h2o_score_line(art, te), 0)
  } else pmax(score_model(load_model(FITTED_DIR, nm), te), 0)
  data.table(line = ln, model = nm, rows = nrow(te), max_abs_diff = max(abs(re - sub[match(te$row_id, row_id), prediction])))
}))
replication_ok <- all(replication$max_abs_diff < 1e-6)
if (!replication_ok) warning("Reloaded models do not reproduce the submission - see the model card.")

# 3. Plots, run history, model card, report --------------------------------------------------------------
ggsave_card <- function(p, f, w, h) ggsave(file.path(ITER_DIR, f), p, width = w, height = h, dpi = 110, bg = "white")
vt <- melt(variant_table, id.vars = c("line", "variant"), measure.vars = c("d2_2023", "d2_2024"))
ggsave_card(ggplot(vt, aes(variant, value, fill = variable)) + geom_col(position = "dodge") +
              facet_wrap(~line, scales = "free_y") +
              labs(title = "Local D2 by variant (each adds one change)", x = NULL, y = "Tweedie D2", fill = NULL),
            "variants.png", 13, 5)
if (nrow(peril_res)) {
  ggsave_card(ggplot(peril_res, aes(peril, d2, fill = variant)) + geom_col(position = "dodge") +
                facet_grid(valid_year ~ line, scales = "free_x", space = "free_x") +
                labs(title = "Local D2 per peril model (against that peril's cost)", x = NULL, y = "Tweedie D2", fill = NULL) +
                theme(axis.text.x = element_text(angle = 45, hjust = 1)),
              "d2_by_peril.png", 13, 7)
}

d2_of <- function(ln, vy) line_score[line == ln & valid_year == vy, d2]
git_commit <- tryCatch({
  h <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)
  dirty <- length(system2("git", c("status", "--porcelain", "--untracked-files=no", "--", "week1/R"),
                          stdout = TRUE, stderr = FALSE)) > 0
  paste0(h, if (dirty) " + uncommitted changes in week1/R/" else "")
}, error = function(e) "unknown")
run_row <- data.table(iteration = ITERATION, run_id = RUN_ID, git_commit = git_commit, file = basename(run_file),
                      file_md5 = sub_md5, replication_check = if (replication_ok) "passed" else "FAILED",
                      models = paste(sprintf("%s=%s %s", LINES, sel$variant, sel$label), collapse = "; "),
                      local_d2_2023 = d2_of("ALL", 2023), local_d2_2024 = d2_of("ALL", 2024),
                      by_line_2023_2024 = paste(sprintf("%s %.3f / %.3f", LINES, sapply(LINES, d2_of, vy = 2023),
                                                        sapply(LINES, d2_of, vy = 2024)), collapse = "; "))
for (ln in LINES) for (vy in VALID_YEARS) set(run_row, j = paste0("d2_", ln, "_", vy), value = d2_of(ln, vy))
hist_file <- out_file(STEP, "run_history.csv")
history <- if (file.exists(hist_file)) {
  rbind(fread(hist_file, colClasses = list(character = c("run_id", "iteration"))), run_row, fill = TRUE)
} else run_row
fwrite(history, hist_file)

fwrite(run_row, file.path(ITER_DIR, "summary.csv"))
fwrite(res, file.path(ITER_DIR, "validation_metrics.csv"))
fwrite(variant_table, file.path(ITER_DIR, "variants.csv"))
fwrite(peril_res, file.path(ITER_DIR, "validation_by_peril.csv"))
fwrite(line_score, file.path(ITER_DIR, "local_d2_by_line.csv"))
fwrite(test_summary, file.path(ITER_DIR, "test_prediction_summary.csv"))
fwrite(trend_final, file.path(ITER_DIR, "final_models.csv"))
fwrite(features_used, file.path(ITER_DIR, "features_used.csv"))
fwrite(imp_final, file.path(ITER_DIR, "xgb_importance.csv"))
aml_rank <- if (length(h2o_tuning)) rbindlist(h2o_tuning) else data.table()
if (nrow(aml_rank)) fwrite(aml_rank, file.path(ITER_DIR, "automl_ranking.csv"))
# Record of BEN's cleaning step used by v2 (week1/output/ben/ is git-ignored; these copies are tracked with the card)
dir.create(file.path(ITER_DIR, "ben_clean"), showWarnings = FALSE)
for (f in c("feature_types.csv", "ibnr_cost_by_peril.csv", "history_signal.csv", "history_summary.csv")) {
  invisible(file.copy(ben_out(f), file.path(ITER_DIR, "ben_clean", f), overwrite = TRUE))
}

settings <- data.table(
  setting = c("Model", "Folds", "Final fit", "Per-peril models (v1 on)", "Large-loss cap", "IBNR", "Trend",
              "Features", "Categorical encoding", "XGBoost parameters", "Monotone constraints", "AutoML (v3)", "Seed"),
  value = c("XGBoost reg:tweedie on cost per exposure-year, weight = exposure, hist trees, early stopping on a 10% policy holdout",
            "expanding window: 2021-22 -> 2023, 2021-23 -> 2024", "2021-24 -> 2025",
            "one model per peril on that peril's cost (`y_cost_<peril>`); line prediction = sum of the peril predictions; every peril model shares the line's early-stopping holdout",
            paste0("cost capped at p", 100 * LARGE_LOSS_QUANTILE, " of its positive values in the fit years (line total in v0, each peril in v1 on); cap loading on predictions"),
            "per-peril count factors (`ibnr_factors_by_peril.csv`): weighted by the row's peril costs for the line total (v0), the peril's own factor (v1); v2 the peril's cost-weighted factor (`week1/output/ben/ibnr_cost_by_peril.csv`). Validation 'developed' actuals always use the count factors, so variants compare like for like",
            sprintf("log-linear trend in capped, developed burn cost over all years before the scored year, clamped to +-%.0f%%; v0-v1 the line's trend, v2 each peril's own", 100 * TREND_CAP),
            paste("as BEN 1 v6: excluded", paste(BEN_EXCLUDE, collapse = ", "), "; premium_index and 2021-24 address weather averages; renewal_count capped at the training maximum.",
                  "v2 reads data/week_1/ben/ (week1/R/ben/ben_clean.R): ordered text as natural-order integers (", paste(names(BEN_ORDINAL), collapse = ", "),
                  "), labels stored as numbers as categories (", paste(BEN_AS_CATEGORY, collapse = ", "), "), plus claims history", paste(BEN_HISTORY, collapse = ", ")),
            sprintf("levels ordered by the model's own cost rate with %d exposure-years of credibility towards its mean", CRED_K),
            paste(sprintf("%s: %s", LINES, vapply(LINES, function(ln) paste(PARAM_NAMES, unlist(PARAMS[[ln]]), sep = "=", collapse = ", "), "")),
                  collapse = " | "),
            paste0(paste(names(MONOTONE), ifelse(MONOTONE > 0, "increasing", "decreasing"), collapse = "; "),
                   ". v2: flood_zone only in the flood models; claims history increasing"),
            sprintf(paste("h2o %s, algorithms %s (no XGBoost on Windows, no deep learning or stacked ensembles); per peril up to",
                          "%d candidates / %.0f s, fit on 2021 (10%% policy holdout for early stopping), ranked by Tweedie D2 on 2022;",
                          "the best candidate's settings are refitted per window with a fixed size; text columns as native h2o",
                          "categories; balance factor per peril; no monotone constraints (h2o 3.44 GBM fails with them under",
                          "Tweedie); %d threads"),
                    if (USE_H2O) as.character(packageVersion("h2o")) else "-", paste(H2O_ALGOS_USED, collapse = ", "),
                    AML_MODELS, AML_SECS, H2O_THREADS_USED),
            paste0(SEED, " + per-fit offset by line and year (fit_seed(), as BEN 1)")))

card <- c(
  paste0("# ", ITERATION, " - per-peril cost models"), "",
  paste0("**Run id** `", RUN_ID, "` | **Generated** ", format(Sys.time(), "%Y-%m-%d %H:%M"),
         " | **Git commit** `", git_commit, "` | **Submission file** `", basename(run_file), "`"), "",
  paste0("**Change in this iteration:** ", ITERATION_NOTE), "",
  if (grepl("uncommitted", git_commit))
    c("> **Warning:** generated from uncommitted code, so the git commit above does not fully describe this run.", ""),
  if (XGB_MAX_ROUNDS < 2000) c(sprintf("> **Smoke test:** XGBoost limited to %d rounds; scores are not representative.", XGB_MAX_ROUNDS), ""),
  if (nzchar(FORCE_VARIANT)) c(sprintf("> **Test run:** variant %s forced for every line (BEN_SELECT), not selected on validation.", FORCE_VARIANT), ""),
  "## Reproducibility",
  paste0("Submission file MD5 `", sub_md5, "`. Final models in `", FITTED_DIR, "/`; reload with `load_model()` and score with",
         " `score_model()` (`week1/R/model_io.R`; per-peril models load as a `peril_sum`). Replication check: **",
         if (replication_ok) "passed" else "FAILED", "**"), "",
  md_table(replication, 10),
  "## Settings", md_table(settings),
  "## Variants: what each change does",
  "Each variant adds one change to the one before, with the same seeds; v0 reproduces BEN 1's selected model (v6).", "",
  "![](variants.png)", "",
  md_table(variant_table[order(line, variant)], 4),
  "Three lines combined (one baseline, as Kaggle scores the file):", "",
  md_table(dcast(all_variants, variant ~ valid_year, value.var = c("d2", "d2_developed", "gini")), 4),
  "## Selected per line", md_table(sel[, .(line, variant, label, mean_d2)], 4),
  "## Accuracy of the selection - local Kaggle score",
  "`deviance_share` = the line's share of the remaining combined error.", "",
  md_table(line_score_wide, 4),
  if (nrow(peril_res)) c("## Per-peril models",
                         "Each peril model's D2 against that peril's own cost (low for rare perils, which are mostly zeros).", "",
                         "![](d2_by_peril.png)", "", md_table(peril_table[order(line, peril, variant)], 4)),
  "## BEN cleaning used by v2 (`week1/R/ben/ben_clean.R`)",
  "Details and how to import it into the shared pipeline: `week1/R/ben/README.md`. Copies of its outputs: `ben_clean/`.", "",
  md_table(fread(ben_out("feature_types.csv"))[, .(line, feature, type_before, type_after, encoding)]),
  "Claim frequency of the row by its own claims in the previous 365 days (2022-24):", "",
  md_table(fread(ben_out("history_signal.csv"))[feature == "hist_policy_claims", .(line, level, exposure, frequency)], 4),
  if (nrow(aml_rank)) c("## v3: AutoML per peril",
                        "Best candidate per peril (fit 2021, ranked by Tweedie D2 on 2022); every candidate is in `automl_ranking.csv`.",
                        paste("h2o 3.44 limits seen in testing: AutoML's Tweedie GLMs use an identity link (near-flat predictions),",
                              "hence the extra log-link GLM candidate (`*_GLM_log_link`); its Tweedie GBMs under-predict by about",
                              "half with near-zero predictions on some rows, and fail outright with monotone constraints; no",
                              "XGBoost on Windows."), "",
                        md_table(aml_rank[rank == 1, .(line, peril, algo, model_id, d2_2022, pred_vs_actual)], 4),
                        md_table(aml_rank[, .(candidates = .N, best_d2_2022 = max(d2_2022)), by = .(line, algo)], 4)),
  "## Final models (fit 2021-24)", md_table(trend_final, 4),
  "## 2025 test predictions", md_table(test_summary, 3),
  "## Features used", md_table(features_used),
  "## Variable importance (final fit, share of total gain, top 5 per model)",
  md_table(imp_final[rank <= 5, .(line, model, rank, Feature, Gain)], 4)
)
writeLines(card, file.path(ITER_DIR, "model_card.md"))

write_md(list(
  "# Step 6 - Model iterations (latest run)", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/4_models_iterben02.R`, iteration", ITERATION,
        "run id", paste0("`", RUN_ID, "`."), "The full model card is in", paste0("`", ITER_DIR, "/model_card.md`.")), "",
  "## Local Kaggle score by line and combined", md_table(line_score_wide, 4),
  "Row for the submission log in `week1/docs/workflow.md`:", "",
  md_table(run_row[, .(iteration, run_id, file, models, local_d2_2023, local_d2_2024, by_line_2023_2024)], 4),
  "## Variants", md_table(variant_table[order(line, variant), .(line, variant, label, d2_2023, d2_2024, mean_d2)], 4),
  "## Submission", paste0("Written to `", sub_file, "` and archived as `", run_file, "`."), "",
  md_table(test_summary, 3)
), STEP, "model_report.md")

if (USE_H2O) h2o.shutdown(prompt = FALSE)
log_msg("Done. Card: ", file.path(ITER_DIR, "model_card.md"), " | Submission: ", sub_file)
