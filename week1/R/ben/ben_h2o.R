# ben/ben_h2o.R --------------------------------------------------------------
# h2o helpers for BEN iterations (BEN 2 v3: AutoML per peril). Source after week1/R/0_setup.R and week1/R/ben/ben_helpers.R.
# Kept here rather than in the shared week1/R/model_io.R: h2o models need a running h2o cluster (Java) to score.
#   ben_h2o_start()                 start h2o on a 64-bit Java (env var BEN_JAVA_HOME, else ~/tools/jdk-17*)
#   ben_h2o_frame(dt, feats, ...)   upload rows to h2o: text -> factor, yes/no -> 0/1, numbers as they are
#   ben_h2o_tune(...)               AutoML on one target; returns the leader's algorithm, refit settings, leaderboard
#   ben_h2o_refit(...)              fit that algorithm with those settings on another window (no early stopping)
#   ben_h2o_save_line() / ben_h2o_load_line() / ben_h2o_score_line()   save, reload and score a line's peril models

H2O_THREADS <- as.integer(Sys.getenv("BEN_H2O_THREADS", "16"))   # fixed so results repeat
H2O_MEM <- Sys.getenv("BEN_H2O_MEM", "32G")
H2O_ALGOS <- c("GBM", "GLM", "DRF")   # XGBoost is not available in h2o on Windows; no deep learning or stacked ensembles

ben_h2o_start <- function() {
  suppressPackageStartupMessages(library(h2o))
  jdk <- Sys.getenv("BEN_JAVA_HOME", "")
  if (!nzchar(jdk)) jdk <- tail(sort(Sys.glob(file.path(Sys.getenv("USERPROFILE"), "tools", "jdk-17*"))), 1)
  if (!length(jdk) || !dir.exists(jdk)) stop("No 64-bit Java found: set BEN_JAVA_HOME to a JDK 17 folder.")
  Sys.setenv(JAVA_HOME = jdk)
  h2o.init(nthreads = H2O_THREADS, max_mem_size = H2O_MEM, port = 54331, startH2O = TRUE)
  h2o.no_progress()
  invisible(TRUE)
}

# Rows as an h2o frame: text -> factor (h2o's native categorical handling), yes/no -> 0/1; extra = other columns
ben_h2o_frame <- function(dt, feats, extra = list()) {
  df <- as.data.frame(lapply(dt[, ..feats], function(x) {
    if (is.character(x)) factor(x) else if (is.logical(x)) as.integer(x) else x
  }), stringsAsFactors = FALSE)
  for (nm in names(extra)) df[[nm]] <- extra[[nm]]
  as.h2o(df)
}

# h2o monotone constraints for numeric features only (named list)
ben_h2o_mono <- function(rules, feats, dt) {
  rules <- rules[names(rules) %in% feats]
  rules <- rules[vapply(names(rules), function(f) is.numeric(dt[[f]]) && !all(is.na(dt[[f]])), logical(1))]
  if (length(rules)) as.list(rules) else NULL
}

# Settings of a fitted model that are worth carrying to a refit (early stopping replaced by its fitted size)
REFIT_DROP <- c("model_id", "training_frame", "validation_frame", "x", "y", "ignored_columns", "response_column",
                "weights_column", "offset_column", "fold_column", "nfolds", "fold_assignment", "checkpoint",
                "keep_cross_validation_models", "keep_cross_validation_predictions",
                "keep_cross_validation_fold_assignment", "stopping_rounds", "stopping_metric", "stopping_tolerance",
                "max_runtime_secs", "export_checkpoints_dir", "score_each_iteration", "score_tree_interval",
                "lambda_search", "nlambdas", "lambda_min_ratio", "beta_constraints", "plug_values", "build_tree_one_node",
                "calibrate_model", "calibration_frame", "custom_metric_func", "custom_distribution_func", "r2_stopping",
                "monotone_constraints")
refit_settings <- function(m) {
  algo <- m@algorithm
  fun <- switch(algo, gbm = h2o.gbm, glm = h2o.glm, drf = h2o.randomForest, stop("Unexpected algorithm: ", algo))
  p <- m@allparameters
  p <- p[intersect(names(p), setdiff(names(formals(fun)), REFIT_DROP))]
  if (algo %in% c("gbm", "drf")) p$ntrees <- m@model$model_summary$number_of_trees[1]
  if (algo == "drf") p$distribution <- NULL                       # random forests ignore it (mean of the target)
  if (algo == "glm") { p$lambda <- m@model$lambda_best; p$alpha <- m@allparameters$alpha[1] }
  list(algo = algo, params = p)
}

# AutoML on one target (rate per exposure-year, weight = exposure): candidates fitted on `train` (early stopping on
# `valid`), then ranked on `lb` by the Kaggle metric (Tweedie D2 of rate x exposure x loading against `lb_cost`),
# not by AutoML's own leaderboard, which uses squared error. Returns the best candidate's refit settings and the ranking.
ben_h2o_tune <- function(train, valid, lb, feats, y, w, mono, lb_cost, lb_exposure, loading, max_models, max_secs,
                         seed, name, d2_fun) {
  aml <- h2o.automl(x = feats, y = y, training_frame = train, validation_frame = valid, leaderboard_frame = lb,
                    weights_column = w, nfolds = 0, distribution = list(type = "tweedie", tweedie_power = TWEEDIE_P),
                    include_algos = H2O_ALGOS, max_models = max_models, max_runtime_secs = max_secs,
                    monotone_constraints = mono, seed = seed, project_name = name)
  # Extra candidate: AutoML's GLMs keep h2o's default identity link for Tweedie (near-flat predictions), so one
  # log-link Tweedie GLM is added and ranked with the rest
  glm_log <- h2o.glm(x = feats, y = y, training_frame = train, validation_frame = valid, weights_column = w,
                     family = "tweedie", tweedie_variance_power = TWEEDIE_P, tweedie_link_power = 0, alpha = 0,
                     lambda_search = TRUE, nlambdas = 20, seed = seed, model_id = paste0(name, "_GLM_log_link"))
  ids <- c(as.character(as.data.frame(aml@leaderboard$model_id)[[1]]), glm_log@model_id)
  ranking <- rbindlist(lapply(ids, function(id) {
    m <- h2o.getModel(id)
    p <- ben_h2o_predict(m, lb) * lb_exposure * loading
    data.table(model_id = id, algo = m@algorithm, d2_2022 = d2_fun(lb_cost, p, lb_exposure), pred_vs_actual = sum(p) / sum(lb_cost))
  }))[order(-d2_2022)]
  best <- h2o.getModel(ranking$model_id[1])
  out <- c(refit_settings(best), list(ranking = ranking))
  h2o.rm(aml); h2o.rm(glm_log); out
}

# Refit with fixed settings (no early stopping); `mono` = constraints for this window (h2o drops all-NA columns,
# so the claims history only enters from 2022)
ben_h2o_refit <- function(settings, train, feats, y, w, seed, mono = NULL) {
  fun <- switch(settings$algo, gbm = h2o.gbm, glm = h2o.glm, drf = h2o.randomForest)
  args <- c(settings$params, list(x = feats, y = y, training_frame = train, weights_column = w, seed = seed))
  if (settings$algo == "glm") args$lambda_search <- FALSE
  if (settings$algo == "gbm" && length(mono)) args$monotone_constraints <- mono
  do.call(fun, args[!duplicated(names(args), fromLast = TRUE)])
}

ben_h2o_predict <- function(m, frame) as.data.frame(h2o.predict(m, frame))$predict

# A line's peril models: <line>_<peril>_h2o.zip (MOJO) plus <line>_h2o_peril_sum.rds with each peril's balance
# factor, cap loading, features and settings
ben_h2o_save_line <- function(models, info, dir, ln) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  for (pr in names(models)) {
    f <- h2o.save_mojo(models[[pr]], path = normalizePath(dir), force = TRUE)
    target <- file.path(dir, paste0(ln, "_", pr, "_h2o.zip"))
    if (normalizePath(f, mustWork = FALSE) != normalizePath(target, mustWork = FALSE)) file.rename(f, target)
    info[[pr]]$mojo <- basename(target)
  }
  saveRDS(list(model = "h2o_peril_sum", line = ln, components = info), file.path(dir, paste0(ln, "_h2o_peril_sum.rds")))
}

ben_h2o_load_line <- function(dir, ln) {
  art <- readRDS(file.path(dir, paste0(ln, "_h2o_peril_sum.rds")))
  for (pr in names(art$components)) art$components[[pr]]$model <- h2o.import_mojo(normalizePath(file.path(dir, art$components[[pr]]$mojo)))
  art
}

# Expected row cost: sum over perils of rate x balance x cap loading x exposure
ben_h2o_score_line <- function(art, dt) {
  frame <- ben_h2o_frame(dt, art$components[[1]]$features)
  total <- 0
  for (pr in names(art$components)) {
    cmp <- art$components[[pr]]
    total <- total + ben_h2o_predict(cmp$model, frame) * cmp$balance * cmp$loading * dt$exposure
  }
  h2o.rm(frame)
  total
}
