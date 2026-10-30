# 4_models_iter01.R ---------------------------------------------------------
# Iteration 1 (baseline). Frozen: do not edit; copy the latest iteration script to start a new one.
# Step 6 (model iterations): compare candidate models, write a submission and a model card per iteration.
#   Validation on time: fit on earlier years, score 2024 and 2023; select per line on the Kaggle metric
#   (Tweedie D2, p = 1.5, vs a constant-rate baseline; higher = better).
#   Candidates per line (all predict expected row cost = rate x exposure):
#     burn_cost      - flat cost per exposure-year (floor benchmark)
#     premium_scaled - current written premium rescaled to the claims cost (current pricing benchmark)
#     glm_freq_sev   - Poisson frequency x Gamma severity GLM on binned rating factors (explainable)
#     lgb_tweedie    - LightGBM Tweedie on cost per exposure, weight = exposure (accuracy)
#   Targets: row cost capped at p99.9 per line, loaded back to total; 2023-24 rows scaled by IBNR factor.
# Outputs: week1/output/4_models/ (model_report.md, validation_metrics.csv, run_history.csv, lift plots, importances)
#          week1/output/submission/submission_provisional.csv and an archived copy submission_<run id>.csv
#          week1/models/iteration_XX/ (model_card.md + CSVs + importance plots; tracked in git)

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
STEP <- "4_models"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
# Bump ITERATION (and describe the change) whenever the method changes; re-runs overwrite the same model card
ITERATION <- 1
ITERATION_NOTE <- paste("Baseline: GLM frequency x severity vs LightGBM Tweedie, burn cost and rescaled premium per line;",
                        "row cost capped at p99.9 with cap loading; IBNR count factors; no trend.",
                        "Reproducible re-run: per-fit seeds, deterministic LightGBM, fitted models saved.")
ITER_DIR <- file.path("week1", "models", sprintf("iteration_%02d", ITERATION))
VALID_YEARS <- c(2024, 2023)
GLM_SAMPLE <- 250000          # rows used for the frequency GLM (memory)
GLM_MIN_LEVEL_SHARE <- 0.002  # levels below this exposure share are merged into the base level
LGB_MAX_ROUNDS <- 3000
LGB_PARAMS <- list(objective = "tweedie", tweedie_variance_power = TWEEDIE_P, learning_rate = 0.05,
                   num_leaves = 31, min_data_in_leaf = 500, feature_fraction = 0.8,
                   bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = 1, verbosity = -1,
                   seed = SEED, deterministic = TRUE, force_col_wise = TRUE, num_threads = 4)

# Each fit gets its own seed, so code changes elsewhere do not change its random sample
fit_seed <- function(ln, mn, year) SEED + 1000 * match(ln, LINES) + 100 * match(mn, names(MODELS)) + (year - 2020)

GLM_FEATURES <- list(
  motor = c("driver_age", "ncb_years", "years_licensed", "vehicle_value_group", "vehicle_age", "cover_type",
            "annual_mileage", "overnight_parking", "vehicle_use", "named_young_driver", "fuel_type", "body_type",
            "telematics_opt_in", "prior_claims_5y", "licence_points", "credit_band", "region", "urban_density",
            "voluntary_excess", "occupation", "marital_status", "years_at_address", "renewal_count",
            "new_business", "payment_method", "missed_payments_12m"),
  buildings = c("flood_zone", "elevation_m", "distance_to_river_km", "sum_insured", "bedrooms", "energy_rating",
                "year_built", "property_type", "construction_type", "occupancy", "prior_claims_5y",
                "missed_payments_12m", "region", "urban_density", "soil_type", "trees_within_5m", "roof_type",
                "basement", "listed_building", "accidental_damage_cover", "days_unoccupied", "voluntary_excess",
                "wind_exposure_index", "hail_days", "dry_summer_index", "rainfall_mm", "freezing_days"),
  contents = c("flood_zone", "elevation_m", "distance_to_river_km", "sum_insured", "tenure", "region",
               "policyholder_age", "prior_claims_5y", "urban_density", "missed_payments_12m", "voluntary_excess",
               "security_level", "high_value_items", "accidental_damage_cover", "works_from_home", "lodgers",
               "bicycle_cover", "property_type", "household_size")
)

ibnr_file <- file.path(PATHS$output, "3_incidence", "ibnr_factors.csv")
if (!file.exists(ibnr_file)) stop("Missing ", ibnr_file, " - run week1/R/3_incidence.R first.")
ibnr <- fread(ibnr_file)

# Targets ------------------------------------------------------------------------------------
prepare_targets <- function(tr, ln) {
  cap <- quantile(tr[y_cost > 0, y_cost], LARGE_LOSS_QUANTILE, names = FALSE)
  tr[, y_cost_capped := pmin(y_cost, cap)]
  tr[ibnr[line == ln], on = "policy_year", y_ibnr := i.ibnr_factor]
  tr[is.na(y_ibnr), y_ibnr := 1]
  tr[, `:=`(y_target = y_cost_capped * y_ibnr, y_count = y_n_claims * y_ibnr)]
  list(line = ln, cap = cap, loading = tr[, sum(y_cost) / sum(y_cost_capped)])
}

# Encoders -------------------------------------------------------------------------------------
make_glm_encoder <- function(tr, feats, n_bins = 8) {
  specs <- list()
  for (f in feats) {
    x <- tr[[f]]
    sp <- if (is.numeric(x) && uniqueN(x, na.rm = TRUE) > 10) {
      br <- unique(quantile(x, seq(0, 1, length.out = n_bins + 1), na.rm = TRUE, names = FALSE))
      list(type = "bin", breaks = c(-Inf, br[-c(1, length(br))], Inf))
    } else list(type = "cat")
    v <- encode_raw(x, sp)
    ex <- tapply(tr$exposure, v, sum)
    sp$base <- names(which.max(ex))
    lv <- names(ex)[ex / sum(ex) >= GLM_MIN_LEVEL_SHARE]
    lv <- if (sp$type == "bin") intersect(c(levels(cut(0, sp$breaks)), "missing"), lv)
          else lv[order(suppressWarnings(as.numeric(lv)), lv)]
    sp$levels <- lv
    if (length(sp$levels) >= 2) specs[[f]] <- sp
  }
  list(feats = names(specs), specs = specs, apply = function(dt) {
    as.data.table(Map(function(f, sp) relevel(factor(encode_level(dt[[f]], sp), levels = sp$levels), ref = sp$base),
                      names(specs), specs))
  })
}

make_lgb_encoder <- function(tr, feats) {
  cats <- feats[vapply(feats, function(f) is.character(tr[[f]]), logical(1))]
  lv <- lapply(setNames(cats, cats), function(f) sort(unique(tr[[f]])))
  list(cats = cats, cat_levels = lv, to_mat = function(dt) lgb_matrix(dt, feats, lv))
}

# Candidate models: each takes (train, newdata, ctx) and returns a saveable model (`artifact`) and its
# expected row cost for newdata, scored with score_model() exactly as a reloaded model would be -------------
fit_burn_cost <- function(tr, te, ctx) {
  art <- list(model = "burn_cost", line = ctx$line, loading = ctx$loading, rate = tr[, sum(y_target) / sum(exposure)])
  list(artifact = art, pred = score_model(art, te))
}

fit_premium_scaled <- function(tr, te, ctx) {
  art <- list(model = "premium_scaled", line = ctx$line, loading = ctx$loading,
              k = tr[, sum(y_target) / sum(written_premium * exposure)] * ctx$loading)
  list(artifact = art, pred = score_model(art, te))
}

fit_glm_freq_sev <- function(tr, te, ctx) {
  enc <- make_glm_encoder(tr, intersect(GLM_FEATURES[[ctx$line]], names(tr)))
  rhs <- paste(enc$feats, collapse = " + ")
  s <- tr[sample(.N, min(.N, GLM_SAMPLE))]
  Xf <- enc$apply(s)[, `:=`(y = s$y_count, off = log(s$exposure))]
  m_freq <- glm(as.formula(paste("y ~", rhs, "+ offset(off)")), family = quasipoisson(link = "log"), data = Xf)
  sv <- tr[y_n_claims > 0 & y_cost_capped > 0]
  Xs <- enc$apply(sv)[, `:=`(y = sv$y_cost_capped / sv$y_n_claims, w = sv$y_n_claims)]
  m_sev <- glm(as.formula(paste("y ~", rhs)), family = Gamma(link = "log"), data = Xs, weights = w,
               mustart = rep(weighted.mean(Xs$y, Xs$w), nrow(Xs)), control = glm.control(maxit = 100))
  art <- list(model = "glm_freq_sev", line = ctx$line, loading = ctx$loading, specs = enc$specs,
              coef_freq = coef(m_freq), coef_sev = coef(m_sev))
  list(artifact = art, pred = score_model(art, te), features = enc$feats,
       relativities = glm_relativities(m_freq, m_sev, enc, tr))
}

# Every level of every GLM factor with its training exposure share, frequency / severity / cost relativity
# to the base level and p-values (NA relativity = level aliased or absent from the fitted sample)
glm_relativities <- function(m_freq, m_sev, enc, tr) {
  X <- enc$apply(tr)
  cf <- summary(m_freq)$coefficients
  cs <- summary(m_sev)$coefficients
  coef_of <- function(tab, term, col) if (term %in% rownames(tab)) tab[term, col] else NA_real_
  rel <- rbindlist(lapply(enc$feats, function(f) {
    sp <- enc$specs[[f]]
    ex <- tapply(tr$exposure, X[[f]], sum)
    rbindlist(lapply(sp$levels, function(lv) {
      term <- paste0(f, lv)
      base <- lv == sp$base
      data.table(feature = f, level = lv, is_base = base, exposure_share = ex[lv] / sum(ex, na.rm = TRUE),
                 freq_rel = if (base) 1 else exp(coef_of(cf, term, 1)), freq_p = if (base) NA_real_ else coef_of(cf, term, 4),
                 sev_rel = if (base) 1 else exp(coef_of(cs, term, 1)), sev_p = if (base) NA_real_ else coef_of(cs, term, 4))
    }))
  }))
  rel[, cost_rel := freq_rel * sev_rel]
  rel[, intercept_freq := exp(coef(m_freq)[["(Intercept)"]])]
  rel[, intercept_sev := exp(coef(m_sev)[["(Intercept)"]])]
  rel
}

# Exposure-weighted spread of log relativities across a factor's levels (0 = factor has no effect)
glm_importance <- function(rel) {
  spread <- function(r, w) {
    ok <- is.finite(log(r)) & is.finite(w)
    if (sum(ok) < 2) return(NA_real_)
    w <- w[ok] / sum(w[ok]); lr <- log(r[ok])
    sqrt(sum(w * (lr - sum(w * lr))^2))
  }
  imp <- rel[, .(levels = .N, freq_spread = spread(freq_rel, exposure_share), sev_spread = spread(sev_rel, exposure_share),
                 cost_spread = spread(cost_rel, exposure_share), max_cost_rel = max(cost_rel, na.rm = TRUE),
                 min_cost_rel = min(cost_rel, na.rm = TRUE)), by = .(line, feature)]
  imp[order(line, -cost_spread)][, rank := seq_len(.N), by = line][]
}

fit_lgb_tweedie <- function(tr, te, ctx) {
  feats <- feature_cols(tr)
  enc <- make_lgb_encoder(tr, feats)
  pol <- unique(tr$policy_id)
  hold <- tr$policy_id %in% sample(pol, round(0.1 * length(pol)))  # inner early-stopping holdout by policy
  X <- enc$to_mat(tr)
  rate <- tr$y_target / tr$exposure
  dtr <- lgb.Dataset(X[!hold, ], label = rate[!hold], weight = tr$exposure[!hold], categorical_feature = enc$cats)
  dva <- lgb.Dataset.create.valid(dtr, X[hold, ], label = rate[hold], weight = tr$exposure[hold])
  m <- lgb.train(params = LGB_PARAMS, data = dtr, nrounds = LGB_MAX_ROUNDS, valids = list(holdout = dva),
                 early_stopping_rounds = 100, verbose = -1)
  rm(X, dtr, dva); gc(verbose = FALSE)
  art <- list(model = "lgb_tweedie", line = ctx$line, loading = ctx$loading, features = feats,
              cat_levels = enc$cat_levels, best_iter = m$best_iter, booster = m)
  list(artifact = art, pred = score_model(art, te), features = feats,
       importance = as.data.table(lgb.importance(m)), best_iter = m$best_iter)
}

MODELS <- list(burn_cost = fit_burn_cost, premium_scaled = fit_premium_scaled,
               glm_freq_sev = fit_glm_freq_sev, lgb_tweedie = fit_lgb_tweedie)

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
  data.table(d2 = d2_tweedie(y, pred, exposure), tweedie_dev = tweedie_dev(y, pred), rmse = sqrt(mean((y - pred)^2)),
             mae = mean(abs(y - pred)), gini = norm_gini(y, pred), pred_vs_reported = sum(pred) / sum(y),
             pred_vs_developed = sum(pred) / y_dev)
}

# 1. Validation: fit on the years before each validation year, score that year -------------------------
results <- list(); lift <- list(); valid_preds <- list(); importances <- list(); glm_coefs <- list()
for (vy in VALID_YEARS) {
  for (ln in LINES) {
    dt <- read_clean(paste0("train_", ln))
    tr <- dt[policy_year < vy]
    va <- dt[policy_year == vy]
    rm(dt); gc(verbose = FALSE)
    ctx <- prepare_targets(tr, ln)
    y_dev <- sum(va$y_cost) * ibnr[line == ln & policy_year == vy, ibnr_factor]
    vp <- data.table(valid_year = vy, row_id = va$row_id, line = ln, exposure = va$exposure, actual = va$y_cost)

    for (mn in names(MODELS)) {
      t0 <- Sys.time()
      set.seed(fit_seed(ln, mn, vy))
      fit <- MODELS[[mn]](tr, va, ctx)
      secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
      set(vp, j = mn, value = fit$pred)
      results[[paste(vy, ln, mn)]] <- cbind(
        data.table(valid_year = vy, line = ln, model = mn), metrics(va$y_cost, fit$pred, va$exposure, y_dev),
        data.table(fit_seconds = round(secs), lgb_rounds = if (is.null(fit$best_iter)) NA_integer_ else fit$best_iter))
      if (vy == 2024) {
        dec <- data.table(actual = va$y_cost, pred = fit$pred)[, decile := ceiling(10 * frank(pred, ties.method = "first") / .N)]
        lift[[paste(ln, mn)]] <- dec[, .(actual = mean(actual), pred = mean(pred)), by = decile][, `:=`(line = ln, model = mn)]
        if (!is.null(fit$importance)) importances[[ln]] <- fit$importance[, line := ln]
        if (!is.null(fit$relativities)) glm_coefs[[ln]] <- fit$relativities[, line := ln]
      }
      log_msg(vy, " / ", ln, " / ", mn, " validated in ", round(secs), "s")
    }
    valid_preds[[paste(vy, ln)]] <- vp
    rm(tr, va); gc(verbose = FALSE)
  }
}

res <- rbindlist(results)
res[, mean_d2 := mean(d2), by = .(line, model)]
res[, best := mean_d2 == max(mean_d2), by = .(line, valid_year)]
vp_all <- rbindlist(valid_preds)
# Combined = all three lines scored together with ONE constant-rate baseline, as in the Kaggle file
combined <- rbindlist(lapply(VALID_YEARS, function(vy) {
  v <- vp_all[valid_year == vy]
  rbindlist(lapply(names(MODELS), function(mn) {
    cbind(data.table(valid_year = vy, line = "ALL", model = mn),
          metrics(v$actual, v[[mn]], v$exposure, NA_real_)[, !"pred_vs_developed"])
  }))
}))
# Same combination of best-per-line models as the submission
best_per_line <- unique(res[best == TRUE, .(line, model)])
vp_all[, best_pred := NA_real_]
for (i in seq_len(nrow(best_per_line))) {
  vp_all[line == best_per_line$line[i], best_pred := get(best_per_line$model[i])]
}
combined_best <- rbindlist(lapply(VALID_YEARS, function(vy) {
  v <- vp_all[valid_year == vy]
  cbind(data.table(valid_year = vy, line = "ALL", model = "best per line"),
        metrics(v$actual, v$best_pred, v$exposure, NA_real_)[, !"pred_vs_developed"])
}))
combined <- rbind(combined, combined_best)

# Line breakdown of the submitted combination. A line's share of the remaining deviance is how much of the
# combined error sits in that line: cutting that line's deviance by x% lifts combined D2 by about x% x share x (1 - D2).
line_score <- rbindlist(lapply(VALID_YEARS, function(vy) {
  v <- vp_all[valid_year == vy]
  by_line <- v[, .(d2 = d2_tweedie(actual, best_pred, exposure), deviance = tweedie_dev(actual, best_pred) * .N,
                   exposure_share = sum(exposure)), by = line]
  tot <- data.table(line = "ALL", d2 = d2_tweedie(v$actual, v$best_pred, v$exposure),
                    deviance = sum(by_line$deviance), exposure_share = sum(by_line$exposure_share))
  out <- rbind(by_line, tot)
  out[, `:=`(valid_year = vy, deviance_share = deviance / sum(by_line$deviance),
             exposure_share = exposure_share / sum(by_line$exposure_share))]
}))
line_score_wide <- dcast(line_score, line ~ valid_year, value.var = c("d2", "deviance_share"))
line_score_wide <- merge(best_per_line, line_score_wide, by = "line", all.y = TRUE)
line_score_wide <- line_score_wide[match(c(LINES, "ALL"), line)]
line_score_wide[line == "ALL", model := "best per line"]
save_csv(line_score, STEP, "local_d2_by_line.csv")
save_csv(res, STEP, "validation_metrics.csv")
save_csv(combined, STEP, "validation_metrics_combined.csv")
save_csv(rbindlist(lift), STEP, "lift_deciles.csv")
save_csv(rbindlist(importances), STEP, "lgb_importance.csv")
save_csv(rbindlist(glm_coefs), STEP, "glm_relativities.csv")

p <- ggplot(melt(rbindlist(lift), id.vars = c("line", "model", "decile")), aes(decile, value, colour = variable)) +
  geom_line() + geom_point() + facet_grid(line ~ model, scales = "free_y") + scale_x_continuous(breaks = 1:10) +
  labs(title = "Lift on 2024 validation: mean actual vs predicted row cost by predicted decile",
       subtitle = "Actual 2024 is as reported (immature), so actual sits below predicted", y = "CU per row", colour = NULL)
save_plot(p, STEP, "plots/lift_by_model.png", width = 12, height = 8)

imp_top <- rbindlist(importances)[order(-Gain), head(.SD, 20), by = line]
p <- ggplot(imp_top, aes(reorder(Feature, Gain), Gain)) + geom_col(fill = "steelblue") + coord_flip() +
  facet_wrap(~line, scales = "free") + labs(title = "LightGBM gain importance (top 20)", x = NULL)
save_plot(p, STEP, "plots/lgb_importance.png", width = 13, height = 7)

# 2. Final fit: refit every candidate on 2021-24, score 2025; the best model per line forms the submission ------
unlink(ITER_DIR, recursive = TRUE)
FITTED_DIR <- file.path(ITER_DIR, "fitted")
dir.create(FITTED_DIR, recursive = TRUE)
best_models <- best_per_line
sub_parts <- list(); final_info <- list(); test_summary <- list()
glm_rel_final <- list(); lgb_imp_final <- list(); lgb_rounds_final <- list(); features_used <- list()
for (ln in LINES) {
  tr <- read_clean(paste0("train_", ln))
  te <- read_clean(paste0("test_", ln))
  ctx <- prepare_targets(tr, ln)
  preds <- list()
  for (mn in names(MODELS)) {
    set.seed(fit_seed(ln, mn, 2025))
    fit <- MODELS[[mn]](tr, te, ctx)
    save_model(fit$artifact, FITTED_DIR, paste(ln, mn, sep = "_"))
    preds[[mn]] <- pmax(fit$pred, 0)
    q <- quantile(preds[[mn]], c(0.5, 0.9, 0.99), names = FALSE)
    test_summary[[paste(ln, mn)]] <- data.table(
      line = ln, model = mn, submitted = mn == best_models[line == ln, model], predicted_total = sum(preds[[mn]]),
      predicted_burn_cost = sum(preds[[mn]]) / sum(te$exposure), mean_row = mean(preds[[mn]]),
      p50_row = q[1], p90_row = q[2], p99_row = q[3], max_row = max(preds[[mn]]))
    if (!is.null(fit$features)) features_used[[paste(ln, mn)]] <- data.table(line = ln, model = mn, n_features = length(fit$features),
                                                                         features = paste(fit$features, collapse = ", "))
    if (!is.null(fit$relativities)) glm_rel_final[[ln]] <- fit$relativities[, line := ln]
    if (!is.null(fit$importance)) {
      lgb_imp_final[[ln]] <- fit$importance[, `:=`(line = ln, rank = .I)]
      lgb_rounds_final[[ln]] <- fit$best_iter
    }
    log_msg(ln, " / ", mn, " refitted on 2021-24 and scored on test")
  }
  mn <- best_models[line == ln, model]
  sub_parts[[ln]] <- data.table(row_id = te$row_id, prediction = preds[[mn]])
  final_info[[ln]] <- data.table(line = ln, model = mn, cap = ctx$cap, cap_loading = ctx$loading,
                                 test_rows = nrow(te), test_exposure = sum(te$exposure),
                                 predicted_total = sum(preds[[mn]]), predicted_burn_cost = sum(preds[[mn]]) / sum(te$exposure),
                                 train_burn_2021_23 = tr[policy_year < 2024, sum(y_cost) / sum(exposure)])
  rm(tr, te, preds); gc(verbose = FALSE)
}
test_summary <- rbindlist(test_summary)
glm_rel_final <- rbindlist(glm_rel_final)
glm_imp_final <- glm_importance(glm_rel_final)
lgb_imp_final <- rbindlist(lgb_imp_final)
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
  mn <- best_models[line == ln, model]
  te <- read_clean(paste0("test_", ln))
  re <- pmax(score_model(load_model(FITTED_DIR, paste(ln, mn, sep = "_")), te), 0)
  data.table(line = ln, model = mn, rows = nrow(te),
             max_abs_diff = max(abs(re - sub[match(te$row_id, row_id), prediction])))
}))
replication_ok <- all(replication$max_abs_diff < 1e-6)
if (!replication_ok) warning("Reloaded models do not reproduce the submission - see the model card.")
log_msg("Replication check ", if (replication_ok) "passed" else "FAILED", " (max abs diff ",
        signif(max(replication$max_abs_diff), 3), ")")
final_info <- rbindlist(final_info)
save_csv(final_info, STEP, "final_fit_summary.csv")

# Local Kaggle score of this run (combined and per line), kept in a run history for cross-checking the submission log
d2_of <- function(ln, vy) line_score[line == ln & valid_year == vy, d2]
git_commit <- tryCatch({
  h <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)
  dirty <- length(system2("git", c("status", "--porcelain", "--", "week1/R"), stdout = TRUE, stderr = FALSE)) > 0
  paste0(h, if (dirty) " + uncommitted changes in week1/R/" else "")
}, error = function(e) "unknown")
run_row <- data.table(iteration = ITERATION, run_id = RUN_ID, git_commit = git_commit, file = basename(run_file),
                      file_md5 = sub_md5, replication_check = if (replication_ok) "passed" else "FAILED",
                      models = paste(paste0(best_models$line, "=", best_models$model), collapse = "; "),
                      local_d2_2023 = d2_of("ALL", 2023), local_d2_2024 = d2_of("ALL", 2024),
                      by_line_2023_2024 = paste(sprintf("%s %.3f / %.3f", LINES, sapply(LINES, d2_of, vy = 2023),
                                                        sapply(LINES, d2_of, vy = 2024)), collapse = "; "))
for (ln in LINES) for (vy in VALID_YEARS) set(run_row, j = paste0("d2_", ln, "_", vy), value = d2_of(ln, vy))
hist_file <- out_file(STEP, "run_history.csv")
history <- if (file.exists(hist_file)) rbind(fread(hist_file, colClasses = list(character = "run_id")), run_row, fill = TRUE) else run_row
fwrite(history, hist_file)

# 3. Model card for this iteration (tracked in git under week1/models/, rendered on the site) ----------------------
fwrite(run_row, file.path(ITER_DIR, "summary.csv"))
fwrite(res, file.path(ITER_DIR, "validation_metrics.csv"))
fwrite(combined, file.path(ITER_DIR, "validation_combined.csv"))
fwrite(line_score, file.path(ITER_DIR, "local_d2_by_line.csv"))
fwrite(test_summary, file.path(ITER_DIR, "test_prediction_summary.csv"))
fwrite(features_used, file.path(ITER_DIR, "features_used.csv"))
fwrite(glm_rel_final, file.path(ITER_DIR, "glm_relativities.csv"))
fwrite(glm_imp_final, file.path(ITER_DIR, "glm_importance.csv"))
fwrite(lgb_imp_final, file.path(ITER_DIR, "lgb_importance.csv"))

p <- ggplot(glm_imp_final[rank <= 20], aes(reorder(paste(feature, line, sep = "___"), cost_spread), cost_spread)) +
  geom_col(fill = "darkorange") + coord_flip() + facet_wrap(~line, scales = "free") +
  scale_x_discrete(labels = function(x) sub("___.*$", "", x)) +
  labs(title = "GLM factor importance (final fit, top 20)", x = NULL, y = "exposure-weighted SD of log cost relativity")
ggsave(file.path(ITER_DIR, "glm_importance.png"), p, width = 13, height = 7, dpi = 110, bg = "white")
p <- ggplot(lgb_imp_final[rank <= 20], aes(reorder(paste(Feature, line, sep = "___"), Gain), Gain)) +
  geom_col(fill = "steelblue") + coord_flip() + facet_wrap(~line, scales = "free") +
  scale_x_discrete(labels = function(x) sub("___.*$", "", x)) +
  labs(title = "LightGBM gain importance (final fit, top 20)", x = NULL, y = "share of total gain")
ggsave(file.path(ITER_DIR, "lgb_importance.png"), p, width = 13, height = 7, dpi = 110, bg = "white")

settings <- data.table(setting = c("Training years (final fit)", "Validation folds", "Selection rule", "Large-loss cap",
                                   "IBNR", "Tweedie power", "GLM frequency sample", "GLM min level share",
                                   "GLM numeric binning", "LightGBM params", "LightGBM rounds (final fit)",
                                   "Excluded from features", "Seed"),
                       value = c(paste(range(TRAIN_YEARS), collapse = "-"),
                                 paste(sprintf("fit < %d, score %d", VALID_YEARS, VALID_YEARS), collapse = "; "),
                                 "highest mean local D2 over the validation folds, per line",
                                 paste0("row cost capped at p", 100 * LARGE_LOSS_QUANTILE, " per line, cap loading on predictions"),
                                 "targets x IBNR count factor of their policy year (step 5)", TWEEDIE_P,
                                 paste(format(GLM_SAMPLE, big.mark = ","), "rows"), GLM_MIN_LEVEL_SHARE,
                                 "8 exposure quantile bins for numerics with > 10 values; NA = 'missing' level",
                                 paste(names(LGB_PARAMS), unlist(LGB_PARAMS), sep = "=", collapse = ", "),
                                 paste(names(lgb_rounds_final), unlist(lgb_rounds_final), sep = "=", collapse = ", "),
                                 paste(NON_FEATURES, collapse = ", "),
                                 paste0(SEED, " + per-fit offset by line, model and year (fit_seed())")))

rel_cols <- c("feature", "level", "exposure_share", "freq_rel", "sev_rel", "cost_rel", "freq_p", "sev_p")
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
  paste0("Submission file MD5 `", sub_md5, "`. Every candidate's final model is saved in `", FITTED_DIR,
         "/` (`<line>_<model>.rds`, LightGBM trees in `.txt`). Each fit uses its own seed (`fit_seed()`), and",
         " LightGBM runs in deterministic mode."), "",
  "Reload and score without refitting:", "",
  "```r", "source(\"week1/R/0_setup.R\"); source(\"week1/R/model_io.R\")",
  paste0("art  <- load_model(\"", FITTED_DIR, "\", \"motor_glm_freq_sev\")"),
  "pred <- pmax(score_model(art, read_clean(\"test_motor\")), 0)", "```", "",
  paste0("Replication check (saved models reloaded and re-scored vs the submission): **",
         if (replication_ok) "passed" else "FAILED", "**"), "",
  md_table(replication, 10),
  "## Settings", md_table(settings),
  "## Accuracy - local Kaggle score (Tweedie D2, p = 1.5, higher = better)",
  "### Submitted combination by line and combined",
  "`deviance_share` = the line's share of the remaining combined error (where improvement moves the score most).", "",
  md_table(line_score_wide, 4),
  "### Every candidate model by line",
  md_table(dcast(res, line + model ~ valid_year, value.var = c("d2", "gini", "pred_vs_reported"))[
    order(line, -d2_2023)], 4),
  "### Every candidate model, three lines combined",
  md_table(dcast(combined, model ~ valid_year, value.var = c("d2", "gini"))[order(-d2_2023)], 4),
  "## 2025 test predictions (final fit on 2021-24)",
  "`submitted` = the model used for that line in the submission file.", "",
  md_table(test_summary, 2),
  md_table(final_info[, .(line, model, cap, cap_loading, predicted_burn_cost, train_burn_2021_23)], 2),
  "## Features used", md_table(features_used),
  "## Variable importance (final fit)",
  "### GLM: exposure-weighted spread of the log relativities",
  "![](glm_importance.png)", "",
  md_table(glm_imp_final[, .(line, rank, feature, levels, cost_spread, freq_spread, sev_spread, min_cost_rel, max_cost_rel)], 3),
  "### LightGBM: share of total gain",
  "![](lgb_importance.png)", "",
  md_table(lgb_imp_final[, .(line, rank, Feature, Gain, Cover, Frequency)], 4),
  "## GLM relativities (final fit)",
  paste("Relativity to the base level (`1` = base, the level with most exposure). `cost_rel` = frequency x severity.",
        "Small p-values = level differs clearly from the base. Blank = level aliased or absent from the fitted sample."),
  "Full detail: `glm_relativities.csv`.", "",
  unlist(lapply(LINES, function(ln) {
    r <- glm_rel_final[line == ln]
    c(paste0("### ", ln),
      sprintf("Base frequency %.4f claims per exposure-year, base severity %.0f CU.", r$intercept_freq[1], r$intercept_sev[1]), "",
      md_table(r[, ..rel_cols], 4))
  }))
)
writeLines(card, file.path(ITER_DIR, "model_card.md"))
log_msg("Model card: ", file.path(ITER_DIR, "model_card.md"))

# 4. Report ----------------------------------------------------------------------------------------------
write_md(list(
  "# Step 6 - Model iterations (latest run)", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "from `week1/R/4_models_iter01.R`, iteration", ITERATION,
        "run id", paste0("`", RUN_ID, "`."), "The full model card is in", paste0("`", ITER_DIR, "/model_card.md`.")), "",
  "Validation on time: fit on the years before each validation year, then score that year (2023 is more mature,",
  "2024 is *as reported* and immature). Models are selected per line on the mean **Tweedie D2** across both years,",
  "the Kaggle metric (higher = better; 0 = constant-rate baseline). `gini` = ranking power; `pred_vs_developed`",
  "compares the total with actual grossed up by the IBNR count factor (open-claim development not included).", "",
  "## Local Kaggle score (Tweedie D2, p = 1.5)",
  "### Submitted combination: by line and combined",
  "Line D2 uses that line's own constant-rate baseline; ALL uses one baseline over all rows, as Kaggle scores the file,",
  "so ALL is not an average of the lines. `deviance_share` = the line's share of the remaining combined error:",
  "the larger it is, the more an improvement in that line moves the Kaggle score.", "",
  md_table(line_score_wide, 4),
  "### All candidates, three lines combined",
  md_table(combined[order(valid_year, -d2), .(valid_year, model, d2, tweedie_dev, gini, pred_vs_reported)], 4),
  "Row for the submission log in `week1/docs/workflow.md` (fill in date, time and public score after uploading):", "",
  md_table(run_row[, .(iteration, run_id, file, models, local_d2_2023, local_d2_2024, by_line_2023_2024)], 4),
  "## Validation metrics by line", md_table(res[order(line, valid_year, -d2)], 3),
  "## Lift", "![](plots/lift_by_model.png)", "",
  "## LightGBM importance", "![](plots/lgb_importance.png)", "",
  "GLM relativities: see the model card.", "",
  "## Provisional submission", paste0("Best model per line refitted on 2021-24 and written to `", sub_file,
                                     "` and archived as `", run_file, "`."), "",
  md_table(final_info, 2),
  "## Known limitations / next steps",
  "- No trend: buildings and contents severity rise each year; consider a trend factor to 2025.",
  "- IBNR covers late reporting only; open-claim case development is not modelled.",
  "- Single frequency/severity across perils; by-peril models (fire, flood, subsidence, bodily_injury) are a next step.",
  "- `written_premium` is used as a LightGBM feature (current pricing signal); review for the guardrails write-up."
), STEP, "model_report.md")

log_msg("Done. Report: ", out_file(STEP, "model_report.md"), " | Submission: ", sub_file)
