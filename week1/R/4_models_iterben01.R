# 4_models_iterben01.R -----------------------------------------------------
# BEN 1: XGBoost Tweedie (from iteration 2), changed one step at a time so each change is measured.
#   Folds:      rolling 2-year windows 2021-22 -> 2023, 2022-23 -> 2024, final 2023-24 -> 2025; the expanding window
#               (all earlier years) is run alongside as a comparison. For 2023 both schemes fit on 2021-22.
#   Variants:   v0 iteration 2 setup -> v1 rolling window -> v2 EDA feature fixes -> v3 IBNR by peril -> v4 trend
#               to the scored year -> v5 tuned on a time fold with monotone constraints -> v6 = v5 on the expanding
#               window. Then feature groups are dropped one at a time (guardrail test) and v7 = best + helpful drops.
#   Selection:  per line, highest mean local D2 over 2023 and 2024 (Kaggle metric, actuals as reported).
#   Final fit:  the selected variant's window before 2025, scores the test rows -> submission.
# Run:     Rscript week1/R/4_models_iterben01.R  (quick test: env vars BEN_TUNE_SECONDS=60 BEN_GROUP_TEST=0)
# Outputs: week1/output/4_models/ (model_report.md, run_history.csv), week1/output/submission/,
#          week1/models/ben_iteration_01/ (model_card.md + CSVs + diagnostic plots + fitted models; tracked in git)

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
suppressPackageStartupMessages(library(xgboost))
STEP <- "4_models"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITERATION <- "BEN 1"
ITERATION_NOTE <- paste("XGBoost Tweedie on rolling 2-year windows (expanding window as comparison); EDA feature fixes",
                        "(premium index, weather averages, calendar and duplicate fields removed, renewal_count capped);",
                        "IBNR by peril; trend to the scored year; tuning on a time fold with monotone constraints;",
                        "feature-group drop test; model diagnostic plots.")
ITER_DIR <- file.path("week1", "models", "ben_iteration_01")
MODEL <- "xgb_tweedie"
VALID_YEARS <- c(2023, 2024)
TARGET_YEAR <- 2025
WINDOW <- 2
TREND_CAP <- 0.05            # annual trend clamped to +-5%
CRED_K <- 200                # exposure-years of credibility when ordering categorical levels by cost rate
XGB_MAX_ROUNDS <- as.integer(Sys.getenv("BEN_MAX_ROUNDS", "2000"))   # smoke test: BEN_MAX_ROUNDS=20
BEN_TUNE_SECONDS <- as.numeric(Sys.getenv("BEN_TUNE_SECONDS", "600"))
BEN_GROUP_TEST <- Sys.getenv("BEN_GROUP_TEST", "1") == "1"
TUNE_SHARE <- c(motor = 0.4, buildings = 0.3, contents = 0.3)
DROP_GAIN <- 0.0005          # a group is dropped if removing it lifts D2 by more than this in both years

# EDA findings (week1/docs/workflow.md): calendar, duplicate and constant fields out; premium as an index
BEN_EXCLUDE <- c("compulsory_excess", "years_with_insurer", "customer_since_year", "campaign_code", "written_premium")
CAP_FEATURES <- "renewal_count"
MONOTONE <- c(ncb_years = -1, prior_claims_5y = 1, licence_points = 1, missed_payments_12m = 1, flood_zone = 1,
              voluntary_excess = -1)
GROUPS <- list(
  premium_index = "premium_index",
  marketing = c("marketing_segment", "branch_id", "marketing_consent", "email_domain", "document_preference"),
  distribution = c("channel", "discount_applied", "days_quote_to_inception"),
  previous_insurer = "previous_insurer",
  occupation = "occupation",
  weather_yearly = WEATHER_VARS,
  weather_avg = paste0("wx_avg_", WEATHER_VARS),
  vehicle_colour = "vehicle_colour",
  make_model = "make_model"
)
TUNE_GRID <- CJ(max_depth = c(3, 4, 5), learning_rate = c(0.03, 0.05), min_child_weight = c(10, 50, 200),
                subsample = 0.8, colsample_bytree = c(0.6, 0.8), reg_lambda = c(1, 10),
                tweedie_variance_power = c(1.4, 1.5, 1.6))

fit_seed <- function(ln, year) SEED + 1000 * match(ln, LINES) + 700 + (year - 2020)
fit_years <- function(y, scheme) if (scheme == "rolling") (y - WINDOW):(y - 1) else min(TRAIN_YEARS):(y - 1)

ibnr_line <- fread(file.path(PATHS$output, "3_incidence", "ibnr_factors.csv"))
ibnr_peril_file <- file.path(PATHS$output, "3_incidence", "ibnr_factors_by_peril.csv")
if (!file.exists(ibnr_peril_file)) stop("Missing ", ibnr_peril_file, " - run week1/R/3_incidence.R first.")
ibnr_peril <- fread(ibnr_peril_file)
iter02_tuning <- fread("week1/models/iteration_02/xgb_tuning.csv")
PARAM_NAMES <- c("max_depth", "learning_rate", "min_child_weight", "subsample", "colsample_bytree", "reg_lambda",
                 "tweedie_variance_power")
PARAMS <- list(iter02 = lapply(setNames(LINES, LINES), function(ln) iter02_tuning[line == ln & rank == 1, ..PARAM_NAMES]))

# Variants: each adds one change to the previous one
v0 <- list(label = "iteration 2 setup, expanding window", scheme = "expanding", features = "iter02", k = 0,
           caps = FALSE, dev = "line", trend = FALSE, params = "iter02", monotone = FALSE, drop = character())
VARIANTS <- list(v0 = v0)
VARIANTS$v1 <- modifyList(VARIANTS$v0, list(label = "+ rolling 2-year window", scheme = "rolling"))
VARIANTS$v2 <- modifyList(VARIANTS$v1, list(label = "+ EDA feature fixes", features = "ben", k = CRED_K, caps = TRUE))
VARIANTS$v3 <- modifyList(VARIANTS$v2, list(label = "+ IBNR by peril", dev = "peril"))
VARIANTS$v4 <- modifyList(VARIANTS$v3, list(label = "+ trend to the scored year", trend = TRUE))
VARIANTS$v5 <- modifyList(VARIANTS$v4, list(label = "+ tuned on a time fold, monotone constraints", params = "ben",
                                            monotone = TRUE))
VARIANTS$v6 <- modifyList(VARIANTS$v5, list(label = "v5 on the expanding window", scheme = "expanding"))

# Targets ------------------------------------------------------------------------------------------------
# Development factor per row: line count factor, or per-peril factors weighted by the row's peril costs
row_dev <- function(dt, ln, how) {
  look <- function(tab) { f <- tab[match(dt$policy_year, tab$policy_year), ibnr_factor]; f[is.na(f)] <- 1; f }
  if (how == "line") return(look(ibnr_line[line == ln]))
  num <- 0
  for (pr in PERILS[[ln]]) num <- num + dt[[paste0("y_cost_", pr)]] * look(ibnr_peril[line == ln & peril == pr])
  fifelse(dt$y_cost > 0, num / dt$y_cost, 1)
}

# Annual trend in capped, developed burn cost before `upto` (log-linear, exposure-weighted, clamped)
trend_rate <- function(dt, ln, upto) {
  d <- dt[policy_year < upto]
  if (uniqueN(d$policy_year) < 2) return(0)
  cap <- quantile(d[y_cost > 0, y_cost], LARGE_LOSS_QUANTILE, names = FALSE)
  d[, dev := row_dev(d, ln, "peril")]
  y <- d[, .(burn = sum(pmin(y_cost, cap) * dev) / sum(exposure), exposure = sum(exposure)), by = policy_year]
  b <- coef(lm(log(burn) ~ policy_year, data = y, weights = exposure))[["policy_year"]]
  max(min(b, TREND_CAP), -TREND_CAP)
}

prepare_targets <- function(tr, ln, v, target_year, trend) {
  cap <- quantile(tr[y_cost > 0, y_cost], LARGE_LOSS_QUANTILE, names = FALSE)
  tf <- if (v$trend) exp(trend * (target_year - tr$policy_year)) else 1
  tr[, y_target := pmin(y_cost, cap) * row_dev(tr, ln, v$dev) * tf]
  list(line = ln, cap = cap, loading = tr[, sum(y_cost) / sum(pmin(y_cost, cap))], trend = if (v$trend) trend else 0)
}

# XGBoost ------------------------------------------------------------------------------------------------
variant_feats <- function(dt, v) {
  f <- if (v$features == "iter02") feature_cols(dt) else setdiff(feature_cols(dt, include_new = TRUE), BEN_EXCLUDE)
  setdiff(f, v$drop)
}

# Categorical levels as integer codes ordered by a credibility-weighted cost rate (k = 0: raw rate, as iteration 2)
make_levels <- function(tr, feats, k) {
  cats <- feats[vapply(feats, function(f) is.character(tr[[f]]), logical(1))]
  base <- tr[, sum(y_target) / sum(exposure)]
  lapply(setNames(cats, cats), function(f) {
    r <- tr[, .(rate = (sum(y_target) + k * base) / (sum(exposure) + k)), by = f]
    r[order(rate, get(f))][[f]]
  })
}

mono_string <- function(feats, tr) {
  m <- MONOTONE[feats]
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

# Fits on tr (10% policy holdout for early stopping) and scores te with score_model(), as a reloaded model would
fit_xgb <- function(tr, te, ctx, v, cfg) {
  feats <- variant_feats(tr, v)
  lv <- make_levels(tr, feats, v$k)
  cf <- if (v$caps) intersect(CAP_FEATURES, feats) else character()
  caps <- if (length(cf)) setNames(vapply(cf, function(f) max(tr[[f]], na.rm = TRUE), numeric(1)), cf)
  pol <- unique(tr$policy_id)
  hold <- tr$policy_id %in% sample(pol, round(0.1 * length(pol)))
  X <- lgb_matrix(tr, feats, lv, caps)
  m <- xgb_train(X, tr$y_target / tr$exposure, tr$exposure, hold, cfg, if (v$monotone) mono_string(feats, tr))
  rm(X); gc(verbose = FALSE)
  best_iter <- as.integer(xgb.attr(m, "best_iteration"))
  art <- list(model = MODEL, line = ctx$line, loading = ctx$loading, features = feats, cat_levels = lv, caps = caps,
              best_iter = best_iter, params = cfg, trend = ctx$trend, booster = m)
  list(artifact = art, pred = score_model(art, te), best_iter = best_iter)
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

# 0. Tuning on a time fold: fit 2021, score 2022 (both validation years stay out) ---------------------------
tune_line <- function(dt, ln, budget) {
  v <- VARIANTS$v4
  tr <- dt[policy_year == 2021]; va <- dt[policy_year == 2022]
  ctx <- prepare_targets(tr, ln, v, 2022, trend_rate(dt, ln, 2022))
  feats <- variant_feats(tr, v)
  lv <- make_levels(tr, feats, v$k)
  X <- lgb_matrix(tr, feats, lv); Xv <- lgb_matrix(va, feats, lv)
  set.seed(SEED + 1000 * match(ln, LINES) + 700)
  pol <- unique(tr$policy_id)
  hold <- tr$policy_id %in% sample(pol, round(0.1 * length(pol)))
  grid <- unique(rbind(PARAMS$iter02[[ln]], TUNE_GRID[sample(.N)]))
  mono <- mono_string(feats, tr)
  t0 <- Sys.time(); out <- list(); secs <- numeric()
  for (i in seq_len(nrow(grid))) {
    if (i > 1 && as.numeric(difftime(Sys.time(), t0, units = "secs")) + median(secs) > budget) break
    s <- Sys.time()
    m <- xgb_train(X, tr$y_target / tr$exposure, tr$exposure, hold, grid[i], mono)
    pred <- predict(m, Xv) * va$exposure * ctx$loading
    secs <- c(secs, as.numeric(difftime(Sys.time(), s, units = "secs")))
    out[[i]] <- cbind(data.table(line = ln, config = i), grid[i],
                      data.table(d2_2022 = d2_tweedie(va$y_cost, pred, va$exposure),
                                 rounds = as.integer(xgb.attr(m, "best_iteration")), seconds = round(tail(secs, 1))))
  }
  log_msg("Tuning ", ln, ": ", length(out), " configurations in ", round(sum(secs)), "s")
  rbindlist(out)
}

# Validation of one variant for one line: both folds; returns metrics, predictions and the fitted artifacts
validate <- function(dt, ln, vname, v, cfg) {
  out <- list()
  for (vy in VALID_YEARS) {
    tr <- dt[policy_year %in% fit_years(vy, v$scheme)]
    va <- dt[policy_year == vy]
    ctx <- prepare_targets(tr, ln, v, vy, trend_rate(dt, ln, vy))
    set.seed(fit_seed(ln, vy))
    t0 <- Sys.time()
    fit <- fit_xgb(tr, va, ctx, v, cfg)
    actual_dev <- va$y_cost * row_dev(va, ln, "peril")
    out[[as.character(vy)]] <- list(
      metrics = data.table(variant = vname, line = ln, valid_year = vy, fit_years = paste(range(fit_years(vy, v$scheme)), collapse = "-"),
                           d2 = d2_tweedie(va$y_cost, fit$pred, va$exposure),
                           d2_developed = d2_tweedie(actual_dev, fit$pred, va$exposure),
                           gini = norm_gini(va$y_cost, fit$pred), pred_vs_reported = sum(fit$pred) / sum(va$y_cost),
                           pred_vs_developed = sum(fit$pred) / sum(actual_dev), trend = ctx$trend, rounds = fit$best_iter,
                           fit_seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")))),
      pred = data.table(variant = vname, line = ln, valid_year = vy, exposure = va$exposure, actual = va$y_cost,
                        actual_dev = actual_dev, pred = fit$pred),
      artifact = fit$artifact)
    log_msg(vname, " / ", ln, " / ", vy, ": D2 ", round(out[[as.character(vy)]]$metrics$d2, 4))
    rm(tr, va); gc(verbose = FALSE)
  }
  out
}
cfg_for <- function(v, ln) PARAMS[[v$params]][[ln]]

# 1. Tuning, variants, group-drop test, per line ------------------------------------------------------------
tuning <- list(); metrics <- list(); preds <- list(); arts <- list(); selected <- list(); group_test <- list()
keep <- function(r, key) {
  for (vy in names(r)) {
    metrics[[paste(key, vy)]] <<- r[[vy]]$metrics
    preds[[paste(key, vy)]] <<- r[[vy]]$pred
    arts[[paste(key, vy)]] <<- r[[vy]]$artifact
  }
}
mean_d2 <- function(r) mean(vapply(r, function(x) x$metrics$d2, numeric(1)))
BASE_VARIANTS <- names(VARIANTS)
PARAMS$ben <- list()
for (ln in LINES) {
  dt <- read_clean(paste0("train_", ln))
  tuning[[ln]] <- tune_line(dt, ln, BEN_TUNE_SECONDS * TUNE_SHARE[[ln]])
  PARAMS$ben[[ln]] <- tuning[[ln]][which.max(d2_2022), ..PARAM_NAMES]

  scores <- c()
  for (vn in BASE_VARIANTS) {
    r <- validate(dt, ln, vn, VARIANTS[[vn]], cfg_for(VARIANTS[[vn]], ln))
    keep(r, paste(vn, ln)); scores[vn] <- mean_d2(r)
  }
  best <- names(which.max(scores))
  vb <- VARIANTS[[best]]

  # Guardrail test: drop one feature group at a time from the best variant
  helpful <- character()
  if (BEN_GROUP_TEST) {
    feats <- variant_feats(dt, vb)
    for (g in names(GROUPS)) {
      if (!any(GROUPS[[g]] %in% feats)) next
      r <- validate(dt, ln, paste0("drop_", g), modifyList(vb, list(drop = GROUPS[[g]])), cfg_for(vb, ln))
      keep(r, paste0("drop_", g, " ", ln))
      gain <- vapply(as.character(VALID_YEARS), function(vy) r[[vy]]$metrics$d2 - metrics[[paste(best, ln, vy)]]$d2, numeric(1))
      group_test[[paste(ln, g)]] <- data.table(line = ln, group = g, features = paste(intersect(GROUPS[[g]], feats), collapse = ", "),
                                               d2_change_2023 = gain[["2023"]], d2_change_2024 = gain[["2024"]],
                                               dropped = all(gain > DROP_GAIN))
      if (all(gain > DROP_GAIN)) helpful <- c(helpful, g)
    }
  }
  if (length(helpful)) {
    v7 <- modifyList(vb, list(label = paste0(best, " without ", paste(helpful, collapse = ", ")),
                              drop = unlist(GROUPS[helpful], use.names = FALSE)))
    VARIANTS[[paste0("v7_", ln)]] <- v7
    r <- validate(dt, ln, "v7", v7, cfg_for(v7, ln))
    keep(r, paste("v7", ln)); scores["v7"] <- mean_d2(r)
    if (scores["v7"] > scores[best]) { best <- "v7"; vb <- v7 }
  }
  selected[[ln]] <- list(name = best, variant = vb, cfg = cfg_for(vb, ln))
  log_msg(ln, ": selected ", best, " (", vb$label, "), mean D2 ", round(scores[best], 4))
  rm(dt); gc(verbose = FALSE)
}
tuning <- rbindlist(tuning)
res <- rbindlist(metrics)
pv <- rbindlist(preds)
group_test <- rbindlist(group_test)
sel <- data.table(line = LINES, variant = vapply(LINES, function(ln) selected[[ln]]$name, ""),
                  label = vapply(LINES, function(ln) selected[[ln]]$variant$label, ""),
                  scheme = vapply(LINES, function(ln) selected[[ln]]$variant$scheme, ""))
pv_sel <- pv[sel[, .(line, variant)], on = .(line, variant)]

# Combined (all three lines, one baseline as in the submission file) per variant and for the selection
combined <- function(p) p[, .(d2 = d2_tweedie(actual, pred, exposure), d2_developed = d2_tweedie(actual_dev, pred, exposure),
                              gini = norm_gini(actual, pred)), by = valid_year]
all_variants <- rbindlist(lapply(BASE_VARIANTS, function(vn)
  combined(pv[variant == vn])[, variant := vn]))
all_selected <- combined(pv_sel)[, variant := "selected per line"]
line_score <- rbindlist(lapply(VALID_YEARS, function(vy) {
  v <- pv_sel[valid_year == vy]
  by_line <- v[, .(d2 = d2_tweedie(actual, pred, exposure), deviance = tweedie_dev(actual, pred) * .N), by = line]
  tot <- data.table(line = "ALL", d2 = d2_tweedie(v$actual, v$pred, v$exposure), deviance = sum(by_line$deviance))
  rbind(by_line, tot)[, `:=`(valid_year = vy, deviance_share = deviance / sum(by_line$deviance))]
}))
line_score_wide <- dcast(line_score, line ~ valid_year, value.var = c("d2", "deviance_share"))[match(c(LINES, "ALL"), line)]

variant_table <- dcast(res[variant %in% c(BASE_VARIANTS, "v7")], line + variant ~ valid_year,
                       value.var = c("d2", "d2_developed", "pred_vs_reported"))
variant_table[, mean_d2 := (d2_2023 + d2_2024) / 2]
variant_table[, label := vapply(seq_len(.N), function(i) {
  vn <- if (variant[i] == "v7") paste0("v7_", line[i]) else variant[i]
  VARIANTS[[vn]]$label
}, "")]
setcolorder(variant_table, c("line", "variant", "label"))

# 2. Final fit before 2025, score the test rows -> submission ----------------------------------------------
unlink(ITER_DIR, recursive = TRUE)
FITTED_DIR <- file.path(ITER_DIR, "fitted")
dir.create(FITTED_DIR, recursive = TRUE)
sub_parts <- list(); test_summary <- list(); imp_final <- list(); features_used <- list(); trend_table <- list()
for (ln in LINES) {
  s <- selected[[ln]]
  dt <- read_clean(paste0("train_", ln))
  te <- read_clean(paste0("test_", ln))
  yrs <- fit_years(TARGET_YEAR, s$variant$scheme)
  tr <- dt[policy_year %in% yrs]
  trend <- trend_rate(dt, ln, TARGET_YEAR)
  trend_table[[ln]] <- data.table(line = ln, trend_2021_24 = trend,
                                  trend_by_fold = paste(sprintf("%d: %.3f", VALID_YEARS, sapply(VALID_YEARS, function(vy) trend_rate(dt, ln, vy))), collapse = "; "))
  ctx <- prepare_targets(tr, ln, s$variant, TARGET_YEAR, trend)
  set.seed(fit_seed(ln, TARGET_YEAR))
  fit <- fit_xgb(tr, te, ctx, s$variant, s$cfg)
  save_model(fit$artifact, FITTED_DIR, paste(ln, MODEL, sep = "_"))
  pred <- pmax(fit$pred, 0)
  q <- quantile(pred, c(0.5, 0.9, 0.99), names = FALSE)
  test_summary[[ln]] <- data.table(line = ln, variant = s$name, fit_years = paste(range(yrs), collapse = "-"),
                                   cap = ctx$cap, cap_loading = ctx$loading, trend = ctx$trend,
                                   test_exposure = sum(te$exposure), predicted_total = sum(pred),
                                   predicted_burn_cost = sum(pred) / sum(te$exposure),
                                   train_burn_2023_24 = dt[policy_year >= 2023, sum(y_cost) / sum(exposure)],
                                   p50_row = q[1], p90_row = q[2], p99_row = q[3], max_row = max(pred))
  features_used[[ln]] <- data.table(line = ln, n_features = length(fit$artifact$features),
                                    features = paste(fit$artifact$features, collapse = ", "))
  imp_final[[ln]] <- as.data.table(xgb.importance(model = fit$artifact$booster))[, `:=`(line = ln, rank = .I)]
  sub_parts[[ln]] <- data.table(row_id = te$row_id, prediction = pred)
  log_msg(ln, " refitted on ", paste(range(yrs), collapse = "-"), " and scored on test")
  rm(dt, te, tr, pred); gc(verbose = FALSE)
}
test_summary <- rbindlist(test_summary); imp_final <- rbindlist(imp_final)
features_used <- rbindlist(features_used); trend_table <- rbindlist(trend_table)
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

replication <- rbindlist(lapply(LINES, function(ln) {
  te <- read_clean(paste0("test_", ln))
  re <- pmax(score_model(load_model(FITTED_DIR, paste(ln, MODEL, sep = "_")), te), 0)
  data.table(line = ln, model = MODEL, rows = nrow(te), max_abs_diff = max(abs(re - sub[match(te$row_id, row_id), prediction])))
}))
replication_ok <- all(replication$max_abs_diff < 1e-6)
if (!replication_ok) warning("Reloaded models do not reproduce the submission - see the model card.")

# 3. Diagnostics on the validation years (selected variant per line) ---------------------------------------
bin_feature <- function(x) {
  if (is.numeric(x) && uniqueN(x) > 20) {
    f <- cut(x, unique(quantile(x, seq(0, 1, length.out = 9), na.rm = TRUE)), include.lowest = TRUE, dig.lab = 5)
  } else if (is.numeric(x)) {
    f <- factor(x, levels = sort(unique(x)))
  } else {
    x <- as.character(x)
    top <- names(sort(table(x), decreasing = TRUE))[seq_len(min(15, uniqueN(x)))]
    x[!x %in% top] <- "(other)"
    f <- factor(x)
  }
  if (anyNA(f)) { f <- addNA(f); levels(f)[is.na(levels(f))] <- "missing" }
  f
}
pdp <- function(art, s, f) {
  grid <- unique(quantile(s[[f]], seq(0.02, 0.98, length.out = 15), na.rm = TRUE, names = FALSE))
  rbindlist(lapply(grid, function(g) {
    s2 <- copy(s)
    set(s2, j = f, value = rep(if (is.integer(s2[[f]])) as.integer(round(g)) else g, nrow(s2)))
    data.table(feature = f, value = g, rate = sum(score_model(art, s2)) / sum(s2$exposure))
  }))
}
ave_all <- list(); pdp_all <- list()
for (ln in LINES) {
  vn <- sel[line == ln, variant]
  dt <- read_clean(paste0("train_", ln))
  art24 <- arts[[paste(vn, ln, 2024)]]
  top <- head(as.data.table(xgb.importance(model = art24$booster))$Feature, 12)
  va <- dt[policy_year %in% VALID_YEARS][order(policy_year)]
  p <- pv_sel[line == ln][order(valid_year)]
  ave_all[[ln]] <- rbindlist(lapply(top, function(f) {
    data.table(level = bin_feature(va[[f]]), exposure = va$exposure, actual = p$actual_dev, pred = p$pred)[
      , .(exposure = sum(exposure), actual = sum(actual) / sum(exposure), predicted = sum(pred) / sum(exposure)), keyby = level][
      , `:=`(feature = f, line = ln, level = as.character(level))]
  }))
  set.seed(SEED)
  s <- dt[policy_year == 2024][sample(.N, min(3000, .N))]
  num_top <- head(Filter(function(f) is.numeric(dt[[f]]) && uniqueN(dt[[f]]) > 2, top), 6)
  pdp_all[[ln]] <- rbindlist(lapply(num_top, function(f) pdp(art24, s, f)))[, line := ln]
  rm(dt, va); gc(verbose = FALSE)
}
ave_all <- rbindlist(ave_all); pdp_all <- rbindlist(pdp_all)

dec <- function(p, by) p[, decile := ceiling(10 * frank(get(by), ties.method = "first") / .N), by = .(line, valid_year)]
lift <- dec(copy(pv_sel), "pred")[, .(actual = mean(actual_dev), predicted = mean(pred)), by = .(line, valid_year, decile)]
dl <- merge(pv_sel[, .(line, valid_year, i = seq_len(.N), actual_dev, pred)],
            pv[variant == "v0", .(line, valid_year, i = seq_len(.N), v0 = pred)], by = c("line", "valid_year", "i"))
dl[, ratio := pred / pmax(v0, 1e-9)]
double_lift <- dec(dl, "ratio")[, .(actual = mean(actual_dev), ben_1 = mean(pred), iteration_2_setup = mean(v0)),
                                by = .(line, valid_year, decile)]

ggsave_card <- function(p, f, w, h) ggsave(file.path(ITER_DIR, f), p, width = w, height = h, dpi = 110, bg = "white")
vt <- melt(variant_table, id.vars = c("line", "variant"), measure.vars = c("d2_2023", "d2_2024"))
ggsave_card(ggplot(vt, aes(variant, value, fill = variable)) + geom_col(position = "dodge") +
              facet_wrap(~line, scales = "free_y") +
              labs(title = "Local D2 by variant (each adds one change)", x = NULL, y = "Tweedie D2", fill = NULL),
            "variants.png", 13, 5)
ggsave_card(ggplot(melt(lift, id.vars = c("line", "valid_year", "decile")), aes(decile, value, colour = variable)) +
              geom_line() + geom_point() + facet_grid(valid_year ~ line, scales = "free_y") +
              scale_x_continuous(breaks = 1:10) +
              labs(title = "Lift: mean developed actual vs predicted cost per row by predicted decile", y = "CU per row", colour = NULL),
            "lift.png", 13, 7)
ggsave_card(ggplot(melt(double_lift, id.vars = c("line", "valid_year", "decile")), aes(decile, value, colour = variable)) +
              geom_line() + geom_point() + facet_grid(valid_year ~ line, scales = "free_y") +
              scale_x_continuous(breaks = 1:10) +
              labs(title = "Double lift vs the iteration 2 setup (v0)",
                   subtitle = "Rows sorted by BEN 1 / v0 prediction; the model closer to actual at both ends ranks better",
                   y = "CU per row", colour = NULL),
            "double_lift.png", 13, 7)
for (ln in LINES) {
  a <- ave_all[line == ln]
  a[, level := factor(level, unique(level))]
  sc <- max(a$actual, a$predicted, na.rm = TRUE) / max(a$exposure)
  p <- ggplot(a, aes(level)) + geom_col(aes(y = exposure * sc), fill = "grey85") +
    geom_line(aes(y = actual, group = 1, colour = "actual (developed)")) + geom_point(aes(y = actual, colour = "actual (developed)")) +
    geom_line(aes(y = predicted, group = 1, colour = "predicted")) + geom_point(aes(y = predicted, colour = "predicted")) +
    facet_wrap(~feature, scales = "free", ncol = 3) +
    labs(title = paste0(ln, ": actual vs expected by factor, validation 2023-24 (top 12 by gain)"),
         subtitle = "Cost per exposure-year; grey bars = exposure (scaled)", x = NULL, y = "CU per exposure-year", colour = NULL) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7), legend.position = "top")
  ggsave_card(p, paste0("ave_", ln, ".png"), 13, 12)
}
ggsave_card(ggplot(pdp_all, aes(value, rate)) + geom_line(colour = "steelblue") + geom_point(colour = "steelblue", size = 1) +
              facet_wrap(line ~ feature, scales = "free", ncol = 6) +
              labs(title = "Partial dependence (2024 fold model, 3,000 rows of 2024)", x = NULL, y = "predicted CU per exposure-year"),
            "pdp.png", 16, 8)
imp_plot <- ggplot(imp_final[rank <= 20], aes(reorder(paste(Feature, line, sep = "___"), Gain), Gain)) +
  geom_col(fill = "steelblue") + coord_flip() + facet_wrap(~line, scales = "free") +
  scale_x_discrete(labels = function(x) sub("___.*$", "", x)) +
  labs(title = "XGBoost gain importance (final fit, top 20)", x = NULL, y = "share of total gain")
ggsave_card(imp_plot, "xgb_importance.png", 13, 7)

# 4. Run history, model card, report ---------------------------------------------------------------------
d2_of <- function(ln, vy) line_score[line == ln & valid_year == vy, d2]
git_commit <- tryCatch({
  h <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)
  dirty <- length(system2("git", c("status", "--porcelain", "--untracked-files=no", "--", "week1/R"),
                          stdout = TRUE, stderr = FALSE)) > 0
  paste0(h, if (dirty) " + uncommitted changes in week1/R/" else "")
}, error = function(e) "unknown")
run_row <- data.table(iteration = ITERATION, run_id = RUN_ID, git_commit = git_commit, file = basename(run_file),
                      file_md5 = sub_md5, replication_check = if (replication_ok) "passed" else "FAILED",
                      models = paste(paste0(LINES, "=", MODEL, " ", sel$variant), collapse = "; "),
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
fwrite(group_test, file.path(ITER_DIR, "group_drop_test.csv"))
fwrite(line_score, file.path(ITER_DIR, "local_d2_by_line.csv"))
fwrite(test_summary, file.path(ITER_DIR, "test_prediction_summary.csv"))
fwrite(features_used, file.path(ITER_DIR, "features_used.csv"))
fwrite(imp_final, file.path(ITER_DIR, "xgb_importance.csv"))
fwrite(tuning, file.path(ITER_DIR, "xgb_tuning.csv"))
fwrite(ave_all, file.path(ITER_DIR, "ave_by_factor.csv"))

settings <- data.table(
  setting = c("Model", "Folds (rolling, main)", "Folds (expanding, comparison)", "Final fit", "Large-loss cap",
              "IBNR", "Trend", "Features", "Categorical encoding", "Tuning", "Monotone constraints",
              "Group drop test", "Seed"),
  value = c("XGBoost reg:tweedie on cost per exposure-year, weight = exposure, hist trees, early stopping on a 10% policy holdout",
            "2021-22 -> 2023, 2022-23 -> 2024, 2023-24 -> 2025", "2021-22 -> 2023, 2021-23 -> 2024, 2021-24 -> 2025",
            paste(sprintf("%s %s", test_summary$line, test_summary$fit_years), collapse = "; "),
            paste0("row cost capped at p", 100 * LARGE_LOSS_QUANTILE, " of the fit years, cap loading on predictions"),
            "v0-v2: line count factor of the policy year; v3 on: per-peril count factors weighted by the row's peril costs (`ibnr_factors_by_peril.csv`)",
            sprintf("v4 on: log-linear trend in capped, developed burn cost over all years before the scored year, clamped to +-%.0f%%; targets moved to the scored year", 100 * TREND_CAP),
            paste("v2 on: excluded", paste(BEN_EXCLUDE, collapse = ", "), "; added premium_index and 2021-24 address weather averages; renewal_count capped at the training maximum"),
            sprintf("levels ordered by cost rate with %d exposure-years of credibility towards the line mean (v0-v1: raw rate, as iteration 2)", CRED_K),
            sprintf("fit 2021, score 2022 (Kaggle metric), %d-second budget, %d-configuration grid plus iteration 2's parameters; tried %s",
                    BEN_TUNE_SECONDS, nrow(TUNE_GRID), paste(tuning[, .N, by = line][, paste(line, N)], collapse = ", ")),
            paste(names(MONOTONE), ifelse(MONOTONE > 0, "increasing", "decreasing"), collapse = "; "),
            if (BEN_GROUP_TEST) sprintf("each group dropped from the best variant; dropped for good if D2 rises by > %.4f in both years", DROP_GAIN) else "skipped",
            paste0(SEED, " + per-fit offset by line and year (fit_seed()); same seed for every variant")))

card <- c(
  paste0("# ", ITERATION, " - XGBoost variant ladder"), "",
  paste0("**Run id** `", RUN_ID, "` | **Generated** ", format(Sys.time(), "%Y-%m-%d %H:%M"),
         " | **Git commit** `", git_commit, "` | **Submission file** `", basename(run_file), "`"), "",
  paste0("**Change in this iteration:** ", ITERATION_NOTE), "",
  if (grepl("uncommitted", git_commit))
    c("> **Warning:** generated from uncommitted code, so the git commit above does not fully describe this run.", ""),
  "## Reproducibility",
  paste0("Submission file MD5 `", sub_md5, "`. Final models in `", FITTED_DIR, "/`; reload with `load_model()` and score with",
         " `score_model()` (`week1/R/model_io.R`). Replication check: **", if (replication_ok) "passed" else "FAILED", "**"), "",
  md_table(replication, 10),
  "## Settings", md_table(settings),
  "## Variants: what each change does",
  "Each variant adds one change to the one before; the same seeds are used throughout, so differences come from the change.",
  "For 2023 the rolling and expanding windows are the same (2021-22).", "",
  "![](variants.png)", "",
  md_table(variant_table[order(line, variant)], 4),
  "Three lines combined (one baseline, as Kaggle scores the file):", "",
  md_table(dcast(rbind(all_variants, all_selected), variant ~ valid_year, value.var = c("d2", "d2_developed")), 4),
  "## Selected per line", md_table(sel),
  if (nrow(group_test)) c("## Feature-group drop test (guardrails)",
                          "Change in D2 when the group is removed from the selected variant (positive = the model is better without it).", "",
                          md_table(group_test, 4)),
  "## Accuracy of the selection - local Kaggle score",
  "`deviance_share` = the line's share of the remaining combined error.", "",
  md_table(line_score_wide, 4),
  md_table(res[sel[, .(line, variant)], on = .(line, variant)][order(line, valid_year),
                                                               .(line, variant, valid_year, fit_years, d2, d2_developed, gini, pred_vs_reported, pred_vs_developed, trend, rounds)], 4),
  "## Trend", md_table(trend_table, 4),
  "## Diagnostics (validation years 2023-24, selected variant)",
  "Actuals are developed with the per-peril IBNR factors so 2024 is comparable with predictions at ultimate.", "",
  "### Lift", "![](lift.png)", "",
  "### Double lift vs the iteration 2 setup", "![](double_lift.png)", "",
  "### Actual vs expected by factor", unlist(lapply(LINES, function(ln) c(paste0("![](ave_", ln, ".png)"), ""))),
  "### Partial dependence", "![](pdp.png)", "",
  "## Tuning (fit 2021, score 2022)", md_table(tuning[order(line, -d2_2022)][, head(.SD, 5), by = line], 4),
  "## 2025 test predictions", md_table(test_summary, 3),
  "## Features used", md_table(features_used),
  "## Variable importance (final fit, share of total gain)", "![](xgb_importance.png)", "",
  md_table(imp_final[rank <= 25, .(line, rank, Feature, Gain, Cover, Frequency)], 4)
)
writeLines(card, file.path(ITER_DIR, "model_card.md"))

write_md(list(
  "# Step 6 - Model iterations (latest run)", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/4_models_iterben01.R`, iteration", ITERATION,
        "run id", paste0("`", RUN_ID, "`."), "The full model card is in", paste0("`", ITER_DIR, "/model_card.md`.")), "",
  "## Local Kaggle score by line and combined", md_table(line_score_wide, 4),
  "Row for the submission log in `week1/docs/workflow.md`:", "",
  md_table(run_row[, .(iteration, run_id, file, models, local_d2_2023, local_d2_2024, by_line_2023_2024)], 4),
  "## Variants", md_table(variant_table[order(line, variant), .(line, variant, label, d2_2023, d2_2024, mean_d2)], 4),
  "## Submission", paste0("Written to `", sub_file, "` and archived as `", run_file, "`."), "",
  md_table(test_summary, 3)
), STEP, "model_report.md")

log_msg("Done. Card: ", file.path(ITER_DIR, "model_card.md"), " | Submission: ", sub_file)
