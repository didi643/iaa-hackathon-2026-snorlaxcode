# 4_models_iter02.R ---------------------------------------------------------
# Iteration 2: XGBoost Tweedie for all three lines, hyper-parameters from a time-boxed random grid search.
# Frozen once its submission is logged; start iteration 3 as a copy of this file.
#   Grid search: random order over XGB_GRID (default first) until the budget runs out, tuned on a 20% policy
#                holdout of 2021-22 with the Kaggle metric, so both validation years stay out of time.
#   Validation:  fit on the years before each validation year, score 2024 and 2023 (Tweedie D2, p = 1.5).
#   Final fit:   2021-24, scores the 2025 test rows -> submission.
#   Targets: row cost capped at p99.9 per line, loaded back to total; rows scaled by their year's IBNR factor.
# Run:     Rscript week1/R/4_models_iter02.R  (quick test: set env var XGB_TUNE_SECONDS=60 first)
# Outputs: week1/output/4_models/ (model_report.md, validation CSVs, run_history.csv, plots)
#          week1/output/submission/submission_provisional.csv and an archived copy submission_<run id>.csv
#          week1/models/iteration_02/ (model_card.md + CSVs + plots + fitted models; tracked in git)

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
suppressPackageStartupMessages(library(xgboost))
STEP <- "4_models"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITERATION <- 2
ITERATION_NOTE <- paste("XGBoost Tweedie for motor, buildings and contents (same features as iteration 1's tree model;",
                        "categoricals coded by their training cost rate). Hyper-parameters per line from a random",
                        "grid search with a 10-minute budget on a 20% policy holdout of 2021-22.")
ITER_DIR <- file.path("week1", "models", sprintf("iteration_%02d", ITERATION))
MODEL <- "xgb_tweedie"
VALID_YEARS <- c(2024, 2023)

# Grid search: the budget (seconds, all lines) is split roughly by data size
XGB_TUNE_SECONDS <- as.numeric(Sys.getenv("XGB_TUNE_SECONDS", "600"))
XGB_TUNE_SHARE <- c(motor = 0.4, buildings = 0.3, contents = 0.3)
XGB_TUNE_YEARS <- 2021:2022
XGB_MAX_ROUNDS <- 2000
XGB_DEFAULT <- data.table(max_depth = 4, learning_rate = 0.1, min_child_weight = 10, subsample = 0.9,
                          colsample_bytree = 0.8, reg_lambda = 1, tweedie_variance_power = 1.5)
XGB_GRID <- CJ(max_depth = c(3, 4, 6, 8), learning_rate = c(0.03, 0.05, 0.1), min_child_weight = c(1, 10, 50),
               subsample = c(0.7, 0.9), colsample_bytree = c(0.6, 0.8, 1), reg_lambda = c(1, 10),
               tweedie_variance_power = c(1.3, 1.5, 1.7))

# Each fit gets its own seed; the 500 offset keeps the seeds of iteration 2's first run (model slot 5)
fit_seed <- function(ln, year) SEED + 1000 * match(ln, LINES) + 500 + (year - 2020)

ibnr_file <- file.path(PATHS$output, "3_incidence", "ibnr_factors.csv")
if (!file.exists(ibnr_file)) stop("Missing ", ibnr_file, " - run week1/R/3_incidence.R first.")
ibnr <- fread(ibnr_file)

# Targets ------------------------------------------------------------------------------------
prepare_targets <- function(tr, ln) {
  cap <- quantile(tr[y_cost > 0, y_cost], LARGE_LOSS_QUANTILE, names = FALSE)
  tr[, y_cost_capped := pmin(y_cost, cap)]
  tr[ibnr[line == ln], on = "policy_year", y_ibnr := i.ibnr_factor]
  tr[is.na(y_ibnr), y_ibnr := 1]
  tr[, y_target := y_cost_capped * y_ibnr]
  list(line = ln, cap = cap, loading = tr[, sum(y_cost) / sum(y_cost_capped)])
}

# XGBoost ----------------------------------------------------------------------------------------
# Categoricals as integer codes ordered by their training cost rate, so tree splits group similar risks
make_xgb_encoder <- function(tr, feats) {
  cats <- feats[vapply(feats, function(f) is.character(tr[[f]]), logical(1))]
  lv <- lapply(setNames(cats, cats), function(f) {
    r <- tr[, .(rate = sum(y_target) / sum(exposure)), by = f]
    r[order(rate, get(f))][[f]]
  })
  list(cat_levels = lv, to_mat = function(dt) lgb_matrix(dt, feats, lv))
}

xgb_train <- function(X, rate, w, hold, cfg) {
  dtr <- xgb.DMatrix(X[!hold, , drop = FALSE], label = rate[!hold], weight = w[!hold], nthread = 4)
  dva <- xgb.DMatrix(X[hold, , drop = FALSE], label = rate[hold], weight = w[hold], nthread = 4)
  params <- xgb.params(objective = "reg:tweedie", tweedie_variance_power = cfg$tweedie_variance_power,
                       learning_rate = cfg$learning_rate, max_depth = cfg$max_depth,
                       min_child_weight = cfg$min_child_weight, subsample = cfg$subsample,
                       colsample_bytree = cfg$colsample_bytree, reg_lambda = cfg$reg_lambda,
                       tree_method = "hist", nthread = 4, seed = SEED,
                       eval_metric = paste0("tweedie-nloglik@", cfg$tweedie_variance_power))
  xgb.train(params = params, data = dtr, nrounds = XGB_MAX_ROUNDS, evals = list(holdout = dva),
            early_stopping_rounds = 50, verbose = 0)
}

# Fits on tr (10% policy holdout for early stopping) and scores te with score_model(), as a reloaded model would
fit_xgb_tweedie <- function(tr, te, ctx) {
  cfg <- XGB_TUNED[[ctx$line]]
  feats <- feature_cols(tr)
  enc <- make_xgb_encoder(tr, feats)
  pol <- unique(tr$policy_id)
  hold <- tr$policy_id %in% sample(pol, round(0.1 * length(pol)))
  X <- enc$to_mat(tr)
  m <- xgb_train(X, tr$y_target / tr$exposure, tr$exposure, hold, cfg)
  rm(X); gc(verbose = FALSE)
  best_iter <- as.integer(xgb.attr(m, "best_iteration"))
  art <- list(model = MODEL, line = ctx$line, loading = ctx$loading, features = feats,
              cat_levels = enc$cat_levels, best_iter = best_iter, params = cfg, booster = m)
  list(artifact = art, pred = score_model(art, te), features = feats,
       importance = as.data.table(xgb.importance(model = m)), best_iter = best_iter)
}

# Metrics --------------------------------------------------------------------------------------------
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
metrics <- function(y, pred, exposure, y_dev) {
  data.table(d2 = d2_tweedie(y, pred, exposure), tweedie_dev = tweedie_dev(y, pred), gini = norm_gini(y, pred),
             pred_vs_reported = sum(pred) / sum(y), pred_vs_developed = sum(pred) / y_dev)
}

# 0. Grid search on 2021-22 only (20% policy holdout), so the 2023 and 2024 validation stay clean ----------
tune_xgb <- function(ln, budget) {
  dt <- read_clean(paste0("train_", ln))[policy_year %in% XGB_TUNE_YEARS]
  prepare_targets(dt, ln)
  enc <- make_xgb_encoder(dt, feature_cols(dt))
  X <- enc$to_mat(dt)
  rate <- dt$y_target / dt$exposure
  set.seed(SEED + 1000 * match(ln, LINES))
  pol <- unique(dt$policy_id)
  hold <- dt$policy_id %in% sample(pol, round(0.2 * length(pol)))
  grid <- unique(rbind(XGB_DEFAULT, XGB_GRID[sample(.N)]))
  t0 <- Sys.time(); out <- list(); secs <- numeric()
  for (i in seq_len(nrow(grid))) {
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    # stop when the next configuration would likely overrun the budget (always try at least the default)
    if (i > 1 && elapsed + median(secs) > budget) break
    s <- Sys.time()
    m <- xgb_train(X, rate, dt$exposure, hold, grid[i])
    pred <- predict(m, X[hold, , drop = FALSE]) * dt$exposure[hold]
    secs <- c(secs, as.numeric(difftime(Sys.time(), s, units = "secs")))
    out[[i]] <- cbind(data.table(line = ln, config = i), grid[i],
                      data.table(holdout_d2 = d2_tweedie(dt$y_target[hold], pred, dt$exposure[hold]),
                                 rounds = as.integer(xgb.attr(m, "best_iteration")), seconds = round(tail(secs, 1))))
    log_msg("Grid search ", ln, " config ", i, ": D2 ", round(out[[i]]$holdout_d2, 4), " in ", round(tail(secs, 1)), "s")
  }
  rbindlist(out)
}
xgb_tuning <- rbindlist(lapply(LINES, function(ln) tune_xgb(ln, XGB_TUNE_SECONDS * XGB_TUNE_SHARE[[ln]])))
xgb_tuning[, rank := frank(-holdout_d2, ties.method = "first"), by = line]
XGB_TUNED <- lapply(setNames(LINES, LINES), function(ln) {
  xgb_tuning[line == ln & rank == 1, names(XGB_DEFAULT), with = FALSE]
})
save_csv(xgb_tuning, STEP, "xgb_tuning.csv")

# 1. Validation: fit on the years before each validation year, score that year -------------------------
results <- list(); lift <- list(); valid_preds <- list()
for (vy in VALID_YEARS) {
  for (ln in LINES) {
    dt <- read_clean(paste0("train_", ln))
    tr <- dt[policy_year < vy]
    va <- dt[policy_year == vy]
    rm(dt); gc(verbose = FALSE)
    ctx <- prepare_targets(tr, ln)
    y_dev <- sum(va$y_cost) * ibnr[line == ln & policy_year == vy, ibnr_factor]
    t0 <- Sys.time()
    set.seed(fit_seed(ln, vy))
    fit <- fit_xgb_tweedie(tr, va, ctx)
    secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    valid_preds[[paste(vy, ln)]] <- data.table(valid_year = vy, line = ln, exposure = va$exposure,
                                               actual = va$y_cost, pred = fit$pred)
    results[[paste(vy, ln)]] <- cbind(data.table(valid_year = vy, line = ln, model = MODEL),
                                      metrics(va$y_cost, fit$pred, va$exposure, y_dev),
                                      data.table(rounds = fit$best_iter, fit_seconds = round(secs)))
    if (vy == 2024) {
      dec <- data.table(actual = va$y_cost, pred = fit$pred)[, decile := ceiling(10 * frank(pred, ties.method = "first") / .N)]
      lift[[ln]] <- dec[, .(actual = mean(actual), pred = mean(pred)), by = decile][, line := ln]
    }
    log_msg(vy, " / ", ln, " validated in ", round(secs), "s")
    rm(tr, va); gc(verbose = FALSE)
  }
}
res <- rbindlist(results)
vp_all <- rbindlist(valid_preds)

# Line D2 uses the line's own baseline; ALL uses one baseline over all rows, as Kaggle scores the file.
# deviance_share = the line's share of the remaining combined error (cutting it by x% lifts ALL by ~x% x share x (1 - D2))
line_score <- rbindlist(lapply(VALID_YEARS, function(vy) {
  v <- vp_all[valid_year == vy]
  by_line <- v[, .(d2 = d2_tweedie(actual, pred, exposure), gini = norm_gini(actual, pred),
                   deviance = tweedie_dev(actual, pred) * .N), by = line]
  tot <- data.table(line = "ALL", d2 = d2_tweedie(v$actual, v$pred, v$exposure), gini = norm_gini(v$actual, v$pred),
                    deviance = sum(by_line$deviance))
  rbind(by_line, tot)[, `:=`(valid_year = vy, deviance_share = deviance / sum(by_line$deviance))]
}))
line_score_wide <- dcast(line_score, line ~ valid_year, value.var = c("d2", "gini", "deviance_share"))
line_score_wide <- line_score_wide[match(c(LINES, "ALL"), line)]
save_csv(res, STEP, "validation_metrics.csv")
save_csv(line_score, STEP, "local_d2_by_line.csv")
save_csv(rbindlist(lift), STEP, "lift_deciles.csv")

p <- ggplot(melt(rbindlist(lift), id.vars = c("line", "decile")), aes(decile, value, colour = variable)) +
  geom_line() + geom_point() + facet_wrap(~line, scales = "free_y") + scale_x_continuous(breaks = 1:10) +
  labs(title = "Lift on 2024 validation: mean actual vs predicted row cost by predicted decile",
       subtitle = "Actual 2024 is as reported (immature), so actual sits below predicted", y = "CU per row", colour = NULL)
save_plot(p, STEP, "plots/lift.png", width = 12, height = 5)

# 2. Final fit on 2021-24, score 2025 -> submission ------------------------------------------------------
unlink(ITER_DIR, recursive = TRUE)
FITTED_DIR <- file.path(ITER_DIR, "fitted")
dir.create(FITTED_DIR, recursive = TRUE)
sub_parts <- list(); test_summary <- list(); imp_final <- list(); rounds_final <- list(); features_used <- list()
for (ln in LINES) {
  tr <- read_clean(paste0("train_", ln))
  te <- read_clean(paste0("test_", ln))
  ctx <- prepare_targets(tr, ln)
  set.seed(fit_seed(ln, 2025))
  fit <- fit_xgb_tweedie(tr, te, ctx)
  save_model(fit$artifact, FITTED_DIR, paste(ln, MODEL, sep = "_"))
  pred <- pmax(fit$pred, 0)
  q <- quantile(pred, c(0.5, 0.9, 0.99), names = FALSE)
  test_summary[[ln]] <- data.table(line = ln, model = MODEL, cap = ctx$cap, cap_loading = ctx$loading,
                                   test_rows = nrow(te), test_exposure = sum(te$exposure), predicted_total = sum(pred),
                                   predicted_burn_cost = sum(pred) / sum(te$exposure),
                                   train_burn_2021_23 = tr[policy_year < 2024, sum(y_cost) / sum(exposure)],
                                   p50_row = q[1], p90_row = q[2], p99_row = q[3], max_row = max(pred))
  features_used[[ln]] <- data.table(line = ln, n_features = length(fit$features), features = paste(fit$features, collapse = ", "))
  imp_final[[ln]] <- fit$importance[, `:=`(line = ln, rank = .I)]
  rounds_final[[ln]] <- fit$best_iter
  sub_parts[[ln]] <- data.table(row_id = te$row_id, prediction = pred)
  log_msg(ln, " refitted on 2021-24 and scored on test")
  rm(tr, te, pred); gc(verbose = FALSE)
}
test_summary <- rbindlist(test_summary)
imp_final <- rbindlist(imp_final)
features_used <- rbindlist(features_used)
sub <- rbindlist(sub_parts)
sample_sub <- read_raw("sample_submission")
stopifnot(nrow(sub) == nrow(sample_sub), setequal(sub$row_id, sample_sub$row_id),
          !anyDuplicated(sub$row_id), !anyNA(sub$prediction), all(sub$prediction >= 0))
sub <- sub[match(sample_sub$row_id, row_id)]
sub_file <- out_file("submission", "submission_provisional.csv")
fwrite(sub, sub_file, scipen = 50)
run_file <- out_file("submission", paste0("submission_", RUN_ID, ".csv"))
file.copy(sub_file, run_file, overwrite = TRUE)
sub_md5 <- unname(tools::md5sum(run_file))

# Replication check: reload the saved models from disk, re-score the test rows, compare with the submission
replication <- rbindlist(lapply(LINES, function(ln) {
  te <- read_clean(paste0("test_", ln))
  re <- pmax(score_model(load_model(FITTED_DIR, paste(ln, MODEL, sep = "_")), te), 0)
  data.table(line = ln, model = MODEL, rows = nrow(te), max_abs_diff = max(abs(re - sub[match(te$row_id, row_id), prediction])))
}))
replication_ok <- all(replication$max_abs_diff < 1e-6)
if (!replication_ok) warning("Reloaded models do not reproduce the submission - see the model card.")
log_msg("Replication check ", if (replication_ok) "passed" else "FAILED", " (max abs diff ",
        signif(max(replication$max_abs_diff), 3), ")")

# Run history: local Kaggle score of this run, for cross-checking the submission log
d2_of <- function(ln, vy) line_score[line == ln & valid_year == vy, d2]
git_commit <- tryCatch({
  h <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)
  dirty <- length(system2("git", c("status", "--porcelain", "--untracked-files=no", "--", "week1/R"),
                          stdout = TRUE, stderr = FALSE)) > 0
  paste0(h, if (dirty) " + uncommitted changes in week1/R/" else "")
}, error = function(e) "unknown")
run_row <- data.table(iteration = ITERATION, run_id = RUN_ID, git_commit = git_commit, file = basename(run_file),
                      file_md5 = sub_md5, replication_check = if (replication_ok) "passed" else "FAILED",
                      models = paste(paste0(LINES, "=", MODEL), collapse = "; "),
                      local_d2_2023 = d2_of("ALL", 2023), local_d2_2024 = d2_of("ALL", 2024),
                      by_line_2023_2024 = paste(sprintf("%s %.3f / %.3f", LINES, sapply(LINES, d2_of, vy = 2023),
                                                        sapply(LINES, d2_of, vy = 2024)), collapse = "; "))
for (ln in LINES) for (vy in VALID_YEARS) set(run_row, j = paste0("d2_", ln, "_", vy), value = d2_of(ln, vy))
hist_file <- out_file(STEP, "run_history.csv")
history <- if (file.exists(hist_file)) rbind(fread(hist_file, colClasses = list(character = "run_id")), run_row, fill = TRUE) else run_row
fwrite(history, hist_file)

# 3. Model card (tracked in git under week1/models/, rendered on the site) ----------------------------------------
fwrite(run_row, file.path(ITER_DIR, "summary.csv"))
fwrite(res, file.path(ITER_DIR, "validation_metrics.csv"))
fwrite(line_score, file.path(ITER_DIR, "local_d2_by_line.csv"))
fwrite(test_summary, file.path(ITER_DIR, "test_prediction_summary.csv"))
fwrite(features_used, file.path(ITER_DIR, "features_used.csv"))
fwrite(imp_final, file.path(ITER_DIR, "xgb_importance.csv"))
fwrite(xgb_tuning, file.path(ITER_DIR, "xgb_tuning.csv"))

p <- ggplot(imp_final[rank <= 20], aes(reorder(paste(Feature, line, sep = "___"), Gain), Gain)) +
  geom_col(fill = "steelblue") + coord_flip() + facet_wrap(~line, scales = "free") +
  scale_x_discrete(labels = function(x) sub("___.*$", "", x)) +
  labs(title = "XGBoost gain importance (final fit, top 20)", x = NULL, y = "share of total gain")
ggsave(file.path(ITER_DIR, "xgb_importance.png"), p, width = 13, height = 7, dpi = 110, bg = "white")
p <- ggplot(xgb_tuning, aes(config, holdout_d2)) + geom_point(colour = "grey50") +
  geom_point(data = xgb_tuning[rank == 1], colour = "red", size = 3) + facet_wrap(~line, scales = "free") +
  labs(title = "Grid search: holdout D2 per configuration tried", subtitle = "red = selected",
       x = "configuration (order tried)", y = "holdout D2 (2021-22, 20% policies)")
ggsave(file.path(ITER_DIR, "xgb_tuning.png"), p, width = 13, height = 5, dpi = 110, bg = "white")

settings <- data.table(
  setting = c("Model", "Training years (final fit)", "Validation folds", "Large-loss cap", "IBNR", "Grid search",
              "Selected params", "Boosting rounds (final fit)", "Excluded from features", "Seed"),
  value = c("XGBoost reg:tweedie on cost per exposure-year, weight = exposure, hist trees, early stopping on a 10% policy holdout",
            paste(range(TRAIN_YEARS), collapse = "-"),
            paste(sprintf("fit < %d, score %d", VALID_YEARS, VALID_YEARS), collapse = "; "),
            paste0("row cost capped at p", 100 * LARGE_LOSS_QUANTILE, " per line, cap loading on predictions"),
            "targets x IBNR count factor of their policy year (step 5)",
            sprintf("%d-second budget, random order over %s configurations, tuned on %s (20%% policy holdout); tried %s",
                    XGB_TUNE_SECONDS, format(nrow(XGB_GRID), big.mark = ","), paste(range(XGB_TUNE_YEARS), collapse = "-"),
                    paste(xgb_tuning[, .N, by = line][, paste(line, N)], collapse = ", ")),
            paste(sapply(LINES, function(ln) paste0(ln, ": ", paste(names(XGB_TUNED[[ln]]), unlist(XGB_TUNED[[ln]]),
                                                                    sep = "=", collapse = ", "))), collapse = "; "),
            paste(names(rounds_final), unlist(rounds_final), sep = "=", collapse = ", "),
            paste(NON_FEATURES, collapse = ", "),
            paste0(SEED, " + per-fit offset by line and year (fit_seed())")))

card <- c(
  paste0("# Iteration ", ITERATION), "",
  paste0("**Run id** `", RUN_ID, "` | **Generated** ", format(Sys.time(), "%Y-%m-%d %H:%M"),
         " | **Git commit** `", git_commit, "` | **Submission file** `", basename(run_file), "`"), "",
  paste0("**Change in this iteration:** ", ITERATION_NOTE), "",
  if (grepl("uncommitted", git_commit))
    c("> **Warning:** generated from uncommitted code, so the git commit above does not fully describe this run.", ""),
  "Public Kaggle scores for this iteration are in the submission log (`Iteration` column) and on the",
  "Model iterations overview page.", "",
  "## Reproducibility",
  paste0("Submission file MD5 `", sub_md5, "`. The final models are saved in `", FITTED_DIR,
         "/` (`<line>_xgb_tweedie.rds` + `.ubj`). Each fit uses its own seed (`fit_seed()`)."), "",
  "Reload and score without refitting:", "",
  "```r", "source(\"week1/R/0_setup.R\"); source(\"week1/R/model_io.R\"); library(xgboost)",
  paste0("art  <- load_model(\"", FITTED_DIR, "\", \"motor_xgb_tweedie\")"),
  "pred <- pmax(score_model(art, read_clean(\"test_motor\")), 0)", "```", "",
  paste0("Replication check (saved models reloaded and re-scored vs the submission): **",
         if (replication_ok) "passed" else "FAILED", "**"), "",
  md_table(replication, 10),
  "## Settings", md_table(settings),
  "## Grid search",
  paste("Each configuration is trained on 80% of 2021-22 policies and scored on the other 20% with the Kaggle metric;",
        "the best per line is used for every later fit (with its own early stopping)."), "",
  "![](xgb_tuning.png)", "",
  md_table(xgb_tuning[rank <= 10][order(line, rank)], 4),
  "## Accuracy - local Kaggle score (Tweedie D2, p = 1.5, higher = better)",
  "`deviance_share` = the line's share of the remaining combined error (where improvement moves the score most).", "",
  md_table(line_score_wide, 4),
  md_table(res[order(line, valid_year), .(line, valid_year, d2, gini, pred_vs_reported, pred_vs_developed, rounds)], 4),
  "## 2025 test predictions (final fit on 2021-24)", md_table(test_summary, 2),
  "## Features used", md_table(features_used),
  "## Variable importance (final fit, share of total gain)",
  "![](xgb_importance.png)", "",
  md_table(imp_final[, .(line, rank, Feature, Gain, Cover, Frequency)], 4)
)
writeLines(card, file.path(ITER_DIR, "model_card.md"))
log_msg("Model card: ", file.path(ITER_DIR, "model_card.md"))

# 4. Report (latest run) -------------------------------------------------------------------------------
write_md(list(
  "# Step 6 - Model iterations (latest run)", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/4_models_iter02.R`, iteration", ITERATION,
        "run id", paste0("`", RUN_ID, "`."), "The full model card is in", paste0("`", ITER_DIR, "/model_card.md`.")), "",
  "Validation on time: fit on the years before each validation year, then score that year (2023 is more mature,",
  "2024 is *as reported* and immature). Local score = **Tweedie D2**, the Kaggle metric (higher = better).", "",
  "## Local Kaggle score by line and combined", md_table(line_score_wide, 4),
  "Row for the submission log in `week1/docs/workflow.md` (fill in date, time and public score after uploading):", "",
  md_table(run_row[, .(iteration, run_id, file, models, local_d2_2023, local_d2_2024, by_line_2023_2024)], 4),
  "## Lift", "![](plots/lift.png)", "",
  "## Submission", paste0("Written to `", sub_file, "` and archived as `", run_file, "`."), "",
  md_table(test_summary, 2),
  "## Known limitations / next steps",
  "- `written_premium` is a feature (current pricing signal); review for the guardrails write-up.",
  "- IBNR covers late reporting only; open-claim case development is not modelled.",
  "- Grid search budget is short (about 10 configurations per line); a longer or narrower search may help."
), STEP, "model_report.md")

log_msg("Done. Report: ", out_file(STEP, "model_report.md"), " | Submission: ", sub_file)
