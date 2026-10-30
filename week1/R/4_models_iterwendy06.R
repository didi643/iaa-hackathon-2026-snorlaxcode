# 4_models_iterwendy06.R ------------------------------------------------------------------------------------------
# WENDY 6: same actuarial basis as WENDY 4/5 (targets, features, caps, IBNR, trends, structural zeros); the learner is
# H2O AutoML per peril and component, with the SAME policy-grouped folds as WENDY 5 as AutoML's fold column.
#
#   Frequency  AutoML, distribution = poisson, response = positive-claim count / IBNR volume, weights = IBNR volume
#              (exposure x reported share). Weighted Poisson deviance on the rate equals the count deviance with a
#              log(volume) offset, so this is the usual offset model (AutoML has no offset argument).
#   Severity   AutoML, distribution = gamma, on claims capped and trended to the last training year.
#   Tweedie    optional third component (Settings automl_components), chosen per peril on the time check.
#   Phases     time_check: fit before time_check_year, score it vs developed actuals (comparable with WENDY 4/5).
#              final: fit all years, predict 2025; AutoML's out-of-fold predictions give component deviances that are
#              comparable with WENDY 5's component_cv (same folds, same targets).
#   Resume     every peril x phase is saved to week1/models/wendy_iteration_06/progress/; re-running skips finished ones.
#
# Run:   Rscript week1/R/4_models_iterwendy06.R            (~20 h at 20 min per AutoML run: 15 perils x 2 components x 2 phases)
#        FAST=1 Rscript week1/R/4_models_iterwendy06.R     (smoke test: 30 s per run, 3 folds)
# Needs: week1/R/0_setup.R, week1/R/wendy_core.R, week1/docs/assumptions_wendy06.xlsx, data/week_1/clean/*, packages h2o + readxl, and Java
#        (8-17 for H2O 3.44-3.46 - check the H2O release notes for your version).

source("week1/R/0_setup.R")
CFG_FILE <- Sys.getenv("ASSUMPTIONS_XLSX", "week1/docs/assumptions_wendy06.xlsx")
source("week1/R/wendy_core.R")
for (p in c("h2o", "readxl")) if (!requireNamespace(p, quietly = TRUE)) stop("Install package '", p, "'")
suppressPackageStartupMessages(library(h2o))

ITERATION <- "WENDY 6"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITER_DIR <- file.path("week1", "models", "wendy_iteration_06")
PROG_DIR <- file.path(ITER_DIR, "progress")
FAST <- Sys.getenv("FAST", "0") == "1"
T0 <- Sys.time()
dir.create(PROG_DIR, recursive = TRUE, showWarnings = FALSE)

CFG <- wc_config(CFG_FILE)
SCORE_P <- s_num("score_tweedie_p")
K <- if (FAST) 3L else as.integer(s_num("cv_folds"))
TIME_YEAR <- as.integer(s_num("time_check_year"))
SECS <- if (FAST) 30 else s_num("automl_seconds")
PHASES <- s_vec("automl_phases"); stopifnot(all(PHASES %in% c("time_check", "final")), "final" %in% PHASES)
COMPONENTS <- s_vec("automl_components"); stopifnot(all(COMPONENTS %in% c("freq", "sev", "tweedie")), all(c("freq", "sev") %in% COMPONENTS))
EXCL <- s_vec("automl_exclude_algos"); EXCL <- if (identical(tolower(EXCL), "none")) NULL else EXCL
MAXM <- as.integer(s_num("automl_max_models")); MAXM <- if (MAXM > 0) MAXM else NULL
ASEED <- as.integer(s_num("automl_seed"))
MONO <- s_yes("automl_monotone")
MIN_SEV_CLAIMS <- 200
if ("tweedie" %in% COMPONENTS && !"time_check" %in% PHASES) stop("tweedie needs the time_check phase to choose a method")

CLM <- wc_claims()
HIST <- wc_history_index()
ZERO <- wc_zero_check()

if (s_yes("h2o_start")) {
  h2o.init(max_mem_size = s_get("h2o_max_mem"), nthreads = as.integer(s_num("h2o_nthreads")), port = as.integer(s_num("h2o_port")))
} else h2o.init(startH2O = FALSE, port = as.integer(s_num("h2o_port")))
h2o.no_progress()
log_msg(ITERATION, " | H2O ", h2o.getVersion(), " | ", SECS, " s per run | phases ", paste(PHASES, collapse = "+"),
        " | components ", paste(COMPONENTS, collapse = "+"), if (FAST) " [FAST]" else "")

# H2O helpers -------------------------------------------------------------------------------------------------------
h2o_frame <- function(d, feats, extra = list()) {
  df <- as.data.frame(d[, ..feats])
  for (f in feats) {
    v <- df[[f]]
    if (is.character(v)) df[[f]] <- factor(v) else if (is.logical(v)) df[[f]] <- as.integer(v)
  }
  for (nm in names(extra)) df[[nm]] <- extra[[nm]]
  as.h2o(df)
}
mono_list <- function(ln, pr, feats, part, d) {
  if (!MONO) return(NULL)
  m <- mono_for(ln, pr, feats, part)
  num <- vapply(feats, function(f) is.numeric(d[[f]]) || is.logical(d[[f]]), logical(1))
  keep <- m != 0 & num
  if (!any(keep)) NULL else as.list(setNames(m[keep], feats[keep]))
}
run_automl <- function(hf, feats, y, dist, weights, tag, mono) {
  args <- list(x = feats, y = y, training_frame = hf, fold_column = "fold__", distribution = dist,
               max_runtime_secs = SECS, seed = ASEED, sort_metric = "deviance", project_name = tag,
               keep_cross_validation_predictions = TRUE)
  if (!is.null(weights)) args$weights_column <- weights
  # H2O stacked ensembles do not pass weights_column to the metalearner, so an exposure-weighted Poisson / Tweedie
  # ensemble would be fitted unweighted: excluded for weighted runs (frequency, Tweedie); kept for severity
  excl <- unique(c(EXCL, if (!is.null(weights)) "StackedEnsemble"))
  if (length(excl)) args$exclude_algos <- excl
  if (!is.null(MAXM)) args$max_models <- MAXM
  if (!is.null(mono)) args$monotone_constraints <- mono
  do.call(h2o.automl, args)
}
# Leader by cross-validated deviance, excluding algorithms that cannot fit the distribution (DRF/XRT fall back to
# squared error, so their leaderboard "deviance" is an MSE on another scale and would win wrongly)
pick_leader <- function(aml, dist_name) {
  lb <- as.data.table(as.data.frame(h2o.get_leaderboard(aml, extra_columns = "ALL")))
  if (!"algo" %in% names(lb)) lb[, algo := tolower(sub("_.*$", "", model_id))]
  lb[, algo := tolower(algo)]
  ok <- if (dist_name == "gaussian") lb else lb[!algo %in% c("drf")]
  if (!nrow(ok)) stop("No AutoML model supports distribution ", dist_name)
  if (nrow(ok) < nrow(lb)) log_msg("  dropped ", nrow(lb) - nrow(ok), " DRF/XRT model(s) (no ", dist_name, " loss)")
  list(model = h2o.getModel(ok$model_id[1]), id = ok$model_id[1], algo = ok$algo[1], cv_dev = ok$mean_residual_deviance[1])
}
lb_table <- function(aml, n = 10) {
  lb <- as.data.table(as.data.frame(h2o.get_leaderboard(aml, extra_columns = "ALL")))
  head(lb, n)
}
# Out-of-fold predictions of the leader (or of the best model that has them) -> numeric vector + model id
oof_pred <- function(aml) {
  ids <- as.character(as.data.frame(aml@leaderboard$model_id)[, 1]); ids <- ids[!grepl("^(DRF|XRT)_", ids)]
  for (id in ids) {
    v <- tryCatch(as.data.frame(h2o.cross_validation_holdout_predictions(h2o.getModel(id)))[, 1], error = function(e) NULL)
    if (!is.null(v) && length(v)) return(list(pred = v, model = id))
  }
  list(pred = NULL, model = NA_character_)
}
# Variable importance of the leader, or of the best model that reports it (stacked ensembles do not)
varimp_of <- function(aml) {
  ids <- as.character(as.data.frame(aml@leaderboard$model_id)[, 1]); ids <- ids[!grepl("^(DRF|XRT)_", ids)]
  for (id in ids) {
    vi <- tryCatch(h2o.varimp(h2o.getModel(id)), error = function(e) NULL)
    if (!is.null(vi) && nrow(vi)) {
      vi <- as.data.table(vi)
      col <- intersect(c("relative_importance", "scaled_importance"), names(vi))[1]
      v <- vi[, .(feature = variable, importance = get(col))]
      return(v[, feature := sub("\\..*$", "", feature)][, .(importance = sum(importance)), by = feature][, model := id])
    }
  }
  NULL
}
predict_vec <- function(model, d, feats) {
  hf <- h2o_frame(d, feats)
  v <- as.data.frame(h2o.predict(model, hf))[, 1]
  h2o.rm(hf)
  v
}

# One peril, one phase -------------------------------------------------------------------------------------------------
run_peril <- function(tr, target, ln, pr, phase) {
  pd <- wc_peril_data(tr, ln, pr)
  tag <- gsub("[^A-Za-z0-9]", "_", paste("w6", ln, pr, phase, RUN_ID, sep = "_"))
  out <- list(line = ln, peril = pr, phase = phase, base_year = pd$base_year, sev_trend = pd$sev_trend,
              cap = pd$cap, load = pd$load, lb = list(), imp = list(), comp = list(), diag = list())
  keep <- which(!wc_zero_mask(target, ln, pr))
  tg <- target[keep]
  sev_year <- year_factor(pd$sev_trend, tg$policy_year, pd$base_year)
  # frequency
  ff <- feats_for(ln, pr, "freq")
  hf <- h2o_frame(pd$d, ff, list(rate__ = pd$n / pd$eff, w__ = pd$eff, fold__ = pd$d$fold__))
  aml <- run_automl(hf, ff, "rate__", "poisson", "w__", paste0(tag, "_f"), mono_list(ln, pr, ff, "freq", pd$d))
  pk <- pick_leader(aml, "poisson"); ld <- pk$model
  r_in <- as.data.frame(h2o.predict(ld, hf))[, 1]
  bal_f <- sum(pd$n) / sum(r_in * pd$eff)
  ftr <- wc_freq_trend(pd, pd$n, r_in * pd$eff * bal_f)
  freq_t <- predict_vec(ld, tg, ff) * bal_f * year_factor(ftr$g, tg$policy_year, ftr$mid)
  out$lb$freq <- lb_table(aml)[, part := "freq"]
  if (phase == "final") {
    # H2O's weighted mean deviance of the rate x mean weight = mean count deviance per row (WENDY 5's definition)
    o <- oof_pred(aml)
    out$comp$freq <- data.table(part = "freq", metric = "poisson_deviance", value = pk$cv_dev * mean(pd$eff),
      n = length(pd$n), model = pk$id,
      check_value = if (!is.null(o$pred)) wc_poisson_dev(pd$n, o$pred * pd$eff) else NA_real_, check_model = o$model)
    out$imp$freq <- varimp_of(aml)
    h2o.saveModel(ld, path = file.path(ITER_DIR, "leaders", paste(ln, pr, "freq", sep = "_")), force = TRUE)
  }
  out$diag$freq <- data.table(part = "freq", leader = pk$id, algo = pk$algo, models = nrow(aml@leaderboard),
                              bal = bal_f, trend = ftr$g)
  h2o.removeAll(); invisible(gc(verbose = FALSE))
  # severity
  fs <- feats_for(ln, pr, "sev"); sv <- pd$sv
  if (nrow(sv) >= MIN_SEV_CLAIMS && length(fs)) {
    hs <- h2o_frame(sv, fs, list(y__ = sv$capped, fold__ = sv$fold__))
    aml <- run_automl(hs, fs, "y__", "gamma", NULL, paste0(tag, "_s"), mono_list(ln, pr, fs, "sev", sv))
    pk <- pick_leader(aml, "gamma"); ld <- pk$model
    bal_s <- sum(sv$capped) / sum(as.data.frame(h2o.predict(ld, hs))[, 1])
    sev_t <- predict_vec(ld, tg, fs) * bal_s
    out$lb$sev <- lb_table(aml)[, part := "sev"]
    if (phase == "final") {
      o <- oof_pred(aml)
      out$comp$sev <- data.table(part = "sev", metric = "gamma_deviance", value = pk$cv_dev, n = nrow(sv), model = pk$id,
        check_value = if (!is.null(o$pred)) wc_gamma_dev(sv$capped, o$pred) else NA_real_, check_model = o$model)
      out$imp$sev <- varimp_of(aml)
      h2o.saveModel(ld, path = file.path(ITER_DIR, "leaders", paste(ln, pr, "sev", sep = "_")), force = TRUE)
    }
    out$diag$sev <- data.table(part = "sev", leader = pk$id, algo = pk$algo, models = nrow(aml@leaderboard),
                               bal = bal_s, trend = pd$sev_trend)
    h2o.removeAll(); invisible(gc(verbose = FALSE))
  } else {
    sev_t <- rep(mean(sv$capped), nrow(tg))
    out$diag$sev <- data.table(part = "sev", leader = "mean", algo = "mean", models = 0L, bal = 1, trend = pd$sev_trend)
  }
  p_fs <- numeric(nrow(target)); p_fs[keep] <- tg$exposure * freq_t * sev_t * sev_year * pd$load
  out$pred <- list(freq_sev = p_fs)
  # optional Tweedie
  if ("tweedie" %in% COMPONENTS) {
    fa <- feats_for(ln, pr, "all")
    ht <- h2o_frame(pd$d, fa, list(rate__ = pd$y / pd$eff, w__ = pd$eff, fold__ = pd$d$fold__))
    aml <- run_automl(ht, fa, "rate__", list(type = "tweedie", tweedie_power = pd$spec$tweedie_p), "w__",
                      paste0(tag, "_t"), mono_list(ln, pr, fa, "freq", pd$d))
    pk <- pick_leader(aml, "tweedie"); ld <- pk$model
    r_in <- as.data.frame(h2o.predict(ld, ht))[, 1]
    bal_t <- sum(pd$y) / sum(r_in * pd$eff)
    ttr <- wc_freq_trend(pd, pd$y, r_in * pd$eff * bal_t)
    p_tw <- numeric(nrow(target))
    p_tw[keep] <- tg$exposure * predict_vec(ld, tg, fa) * bal_t * year_factor(ttr$g, tg$policy_year, ttr$mid) * sev_year * pd$load
    out$pred$tweedie <- p_tw
    out$lb$tweedie <- lb_table(aml)[, part := "tweedie"]
    if (phase == "final") out$imp$tweedie <- varimp_of(aml)
    out$diag$tweedie <- data.table(part = "tweedie", leader = pk$id, algo = pk$algo, models = nrow(aml@leaderboard),
                                   bal = bal_t, trend = ttr$g)
    if (phase == "final") h2o.saveModel(ld, path = file.path(ITER_DIR, "leaders", paste(ln, pr, "tweedie", sep = "_")), force = TRUE)
    h2o.removeAll(); invisible(gc(verbose = FALSE))
  }
  out
}

# Run all perils and phases (resumable) -----------------------------------------------------------------------------------
results <- list()
for (ln in LINES) {
  dt <- wc_load_line(paste0("train_", ln), ln)
  dt[, fold__ := wc_policy_folds(policy_id, K)]
  te <- if ("final" %in% PHASES) wc_load_line(paste0("test_", ln), ln) else NULL
  for (pr in PERILS[[ln]]) for (phase in PHASES) {
    f <- file.path(PROG_DIR, paste0(ln, "_", pr, "_", phase, if (FAST) "_fast", ".rds"))
    if (file.exists(f)) { results[[paste(ln, pr, phase)]] <- readRDS(f); log_msg("Resumed ", ln, "/", pr, " ", phase); next }
    t0 <- Sys.time()
    tr <- if (phase == "time_check") dt[policy_year < TIME_YEAR] else dt
    target <- if (phase == "time_check") dt[policy_year == TIME_YEAR] else te
    r <- run_peril(tr, target, ln, pr, phase)
    if (phase == "time_check") { dv <- wc_developed(target, ln, pr); r$dev <- dv$dev; r$exposure <- target$exposure }
    else r$row_id <- target$row_id
    saveRDS(r, f)
    results[[paste(ln, pr, phase)]] <- r
    log_msg(ln, "/", pr, " ", phase, " done in ", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
            " min (freq leader ", r$diag$freq$algo, ", sev leader ", r$diag$sev$algo, ")")
  }
  rm(dt, te); invisible(gc(verbose = FALSE))
}

# Scores, method choice ------------------------------------------------------------------------------------------------
time_scores <- list(); chosen <- list(); time_line <- list()
for (ln in LINES) {
  lp <- NULL; ld <- NULL
  for (pr in PERILS[[ln]]) {
    m_pick <- "freq_sev"
    if ("time_check" %in% PHASES) {
      r <- results[[paste(ln, pr, "time_check")]]
      sc <- rbindlist(lapply(names(r$pred), function(m) data.table(line = ln, peril = pr, method = m,
        d2 = wc_d2(r$dev, r$pred[[m]], r$exposure, SCORE_P), gini = wc_gini(r$dev, r$pred[[m]]),
        pred_vs_developed = sum(r$pred[[m]]) / sum(r$dev))))
      time_scores[[paste(ln, pr)]] <- sc
      m_pick <- sc[which.max(d2), method]
      lp <- if (is.null(lp)) r$pred[[m_pick]] else lp + r$pred[[m_pick]]
      ld <- if (is.null(ld)) r$dev else ld + r$dev
      ex <- r$exposure
    }
    chosen[[paste(ln, pr)]] <- data.table(line = ln, peril = pr, method = m_pick)
  }
  if (!is.null(lp)) time_line[[ln]] <- data.table(line = ln, pred = lp, dev = ld, exposure = ex)
}
chosen <- rbindlist(chosen); time_scores <- rbindlist(time_scores)

# Submission ---------------------------------------------------------------------------------------------------------
sub_parts <- list(); peril_preds <- list()
for (ln in LINES) {
  rr <- lapply(PERILS[[ln]], function(pr) results[[paste(ln, pr, "final")]])
  ids <- rr[[1]]$row_id
  pp <- data.table(row_id = ids)
  for (i in seq_along(rr)) {
    stopifnot(identical(rr[[i]]$row_id, ids))
    set(pp, j = PERILS[[ln]][i], value = rr[[i]]$pred[[chosen[line == ln & peril == PERILS[[ln]][i], method]]])
  }
  sub_parts[[ln]] <- data.table(row_id = ids, prediction = pmax(rowSums(as.matrix(pp[, PERILS[[ln]], with = FALSE])), 0))
  peril_preds[[ln]] <- melt(pp, id.vars = "row_id", variable.name = "peril", value.name = "prediction", variable.factor = FALSE)[, line := ln]
}
sub <- rbindlist(sub_parts)
ss <- read_raw("sample_submission")
stopifnot(nrow(sub) == nrow(ss), setequal(sub$row_id, ss$row_id), !anyDuplicated(sub$row_id),
          all(is.finite(sub$prediction)), all(sub$prediction >= 0))
sub <- sub[match(ss$row_id, row_id)]
sub_file <- out_file("submission", "submission_provisional.csv")
fwrite(sub, sub_file, scipen = 50)
run_file <- out_file("submission", paste0("submission_", RUN_ID, "_wendy06.csv"))
invisible(file.copy(sub_file, run_file, overwrite = TRUE))

# Outputs ------------------------------------------------------------------------------------------------------------
fin <- results[grepl(" final$", names(results))]
grab <- function(rs, el) rbindlist(lapply(rs, function(r) if (length(r[[el]])) rbindlist(r[[el]], fill = TRUE)[, `:=`(line = r$line, peril = r$peril, phase = r$phase)]), fill = TRUE)
leaderboards <- grab(results, "lb")
diag <- grab(results, "diag")
comp_cv <- grab(fin, "comp")
imp <- grab(lapply(fin, function(r) { r$imp <- lapply(names(r$imp), function(p) if (!is.null(r$imp[[p]])) r$imp[[p]][, part := p]); r }), "imp")
fwrite(leaderboards, file.path(ITER_DIR, "leaderboards.csv"))
fwrite(diag, file.path(ITER_DIR, "leaders.csv"))
fwrite(chosen, file.path(ITER_DIR, "chosen_method.csv"))
if (nrow(time_scores)) fwrite(time_scores, file.path(ITER_DIR, "time_check_by_peril.csv"))
fwrite(rbindlist(peril_preds), file.path(ITER_DIR, "test_preds_by_peril.csv.gz"))
invisible(file.copy(CFG_FILE, file.path(ITER_DIR, basename(CFG_FILE)), overwrite = TRUE))

peril_scores <- if (nrow(time_scores)) merge(time_scores, chosen, by = c("line", "peril", "method"))[
  , .(iteration = ITERATION, scheme = paste0("time_", TIME_YEAR), line, peril, method, d2, gini, pred_vs_developed)] else NULL
line_scores <- if (length(time_line)) wc_line_scores(time_line, ITERATION, paste0("time_", TIME_YEAR)) else NULL
wc_write_comparison(ITER_DIR, peril_scores = peril_scores, line_scores = line_scores,
  component_cv = if (nrow(comp_cv)) comp_cv[, .(line, peril, part, metric, value, n, iteration = ITERATION, model)] else NULL,
  importance = if (nrow(imp)) imp[, share := importance / sum(importance), by = .(line, peril, part)][
    , .(iteration = ITERATION, line, peril, part, feature, share)] else NULL,
  changes = c("WENDY 6 vs WENDY 5:", paste0("- learner: H2O AutoML (", SECS, " s per run, excluded: ", paste(EXCL, collapse = ", "), ") instead of tuned XGBoost"),
              "- same targets, features, caps, IBNR, trends, structural zeros and policy folds",
              if (!MONO) "- no monotone constraints (WENDY 5 used them)"))

card <- c(
  paste0("# ", ITERATION, " - H2O AutoML per peril and component"), "",
  paste0("**Run id** `", RUN_ID, "` | **H2O** ", h2o.getVersion(), " | **Workbook** `", CFG_FILE, "` | **Submission** `", basename(run_file),
         "` (MD5 `", unname(tools::md5sum(run_file)), "`)", if (FAST) " | **FAST - not for submission**" else ""), "",
  paste0(SECS, " s per AutoML run, ", K, " policy-grouped folds, phases ", paste(PHASES, collapse = " + "), "."),
  "AutoML with a time budget is not exactly reproducible; the leaders of the final phase are saved under `leaders/` (H2O binary models, same H2O version needed to load).", "",
  if (!is.null(line_scores)) c("## Time check (Tweedie D2 vs developed actuals)", md_table(dcast(line_scores, line ~ scheme, value.var = "d2"), 4)),
  if (nrow(time_scores)) c("### By peril", md_table(dcast(time_scores, line + peril ~ method, value.var = "d2"), 4)),
  "## Leaders", md_table(diag[, .(line, peril, phase, part, algo, models, bal, trend)], 3),
  if (nrow(comp_cv)) c("## Component out-of-fold deviance (compare with WENDY 5)", md_table(comp_cv[, .(line, peril, part, metric, value, n, model)], 5)),
  paste0("Run time this session ", round(as.numeric(difftime(Sys.time(), T0, units = "hours")), 2), " hours (resumed runs not included).")
)
writeLines(card, file.path(ITER_DIR, "model_card.md"))
log_msg("Done. Submission: ", sub_file, " | card: ", file.path(ITER_DIR, "model_card.md"))
