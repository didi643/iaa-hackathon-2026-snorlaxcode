# 4_models_iterben03.R -----------------------------------------------------
# BEN 3: one model - frequency x severity per peril, with the model form chosen per peril.
#   Data:       data/week_1/ben3/ (week1/R/ben/ben3_data.R): recovery-adjusted claim costs, per-row chain-ladder reported shares,
#               SAM's engineered features, claims history as at 1 January, previous-row and holdings features
#   Frequency:  claims with cost > 0 over effective exposure (exposure x the row's reported share, so IBNR sits in the
#               denominator and late-starting rows count less); quasi-Poisson GLM with a capped year trend sets the
#               level; optionally an XGBoost Poisson bag sets the shape, rescaled to the GLM total of the scored rows
#   Severity:   Gamma GLM on claims capped at p99.5 per peril (with rating factors, or trend only), with a cap loading
#               that puts the capped-off cost back (incl. the 11.9m bodily-injury claim)
#   Per peril:  frequency {GLM, GLM level + tree shape} x severity {factors, trend only}, chosen on mean D2 against
#               developed peril cost over the 2023 and 2024 folds; trees for sparse perils are shallower
#   Validation: fit on the years before, score 2023 and 2024 (as SAM 3); line and combined D2 on reported actuals for
#               a like-for-like comparison with SAM 3's blend, plus A/E against developed actuals
#   Excluded:   written_premium / premium_index / discount (current pricing), noise and calendar fields
#   Scoring:    saved as `sam02_peril` artifacts, scored by week1/R/model_io.R (no changes to shared code)
# Run:     Rscript week1/R/ben/ben3_data.R, then Rscript week1/R/4_models_iterben03.R (BEN3_QUICK=1: sampled smoke test)
# Outputs: week1/models/ben_iteration_03/ (model card, CSVs, fitted), week1/output/submission/, week1/output/4_models/run_history.csv

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
source("week1/R/ben/ben_helpers.R")
suppressPackageStartupMessages(library(xgboost))

QUICK <- Sys.getenv("BEN3_QUICK") == "1"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITERATION <- "BEN 3"
ITERATION_NOTE <- paste("Frequency x severity per peril with the model form chosen per peril (GLM or GLM level + XGBoost shape;",
                        "severity GLM with factors or trend only); per-row chain-ladder IBNR as effective exposure; expected",
                        "recoveries on open claims; claims history as at 1 January; previous-row and holdings features.")
ITER_DIR <- file.path("week1", "models", if (QUICK) "ben_iteration_03_quick" else "ben_iteration_03")
FITTED_DIR <- file.path(ITER_DIR, "fitted")
DATA_DIR <- file.path("data", "week_1", "ben3")
VALID_YEARS <- c(2023, 2024)
TARGET_YEAR <- 2025
CLAIM_CAP_Q <- 0.995
TREND_CAP <- log(1.10)
GLM_BINS <- 6
GLM_MIN_LEVEL_SHARE <- 0.005
GLM_ZERO_SAMPLE <- if (QUICK) 50000 else 300000
SEV_MIN_CLAIMS <- 300            # fewer claims in the fit window: severity is trend only
SPARSE_CLAIMS <- 3000            # fewer claims in the fit window: shallower trees with larger leaves
N_SEEDS_VALID <- 1
N_SEEDS_FINAL <- if (QUICK) 1 else 3
N_THREADS <- 12
MAX_ROUNDS <- if (QUICK) 300 else 3000
QUICK_POLICIES <- 60000

DROP <- c("written_premium", "premium_index", "discount_applied", "email_domain", "vehicle_colour", "document_preference",
          "marketing_consent", "campaign_code", "branch_id", "marketing_segment", "compulsory_excess",
          "years_with_insurer", "customer_since_year")
BEN_EXTRA <- c("prev_declined", "n_lines")
GLM_FEATURES <- list(
  motor = c("driver_age", "ncb_years", "years_licensed", "vehicle_value_group", "vehicle_age", "cover_type",
            "annual_mileage", "overnight_parking", "vehicle_use", "named_young_driver", "fuel_type", "body_type",
            "telematics_opt_in", "prior_claims_5y", "licence_points", "credit_band", "region", "urban_density",
            "voluntary_excess", "new_business", "payment_method", "missed_payments_12m", "hail_days",
            "hist_pol_n", "hist_cust_other_n", BEN_EXTRA),
  buildings = c("flood_zone", "elevation_m", "distance_to_river_km", "sum_insured", "bedrooms", "property_age",
                "property_type", "construction_type", "occupancy", "prior_claims_5y", "missed_payments_12m",
                "region", "urban_density", "soil_type", "trees_within_5m", "roof_type", "basement",
                "listed_building", "accidental_damage_cover", "days_unoccupied", "voluntary_excess",
                "wind_exposure_index", "hail_days", "dry_summer_index", "rainfall_mm", "freezing_days",
                "hist_pol_n", "hist_addr_flood", "hist_addr_water", "hist_addr_subs", "hist_addr_storm", BEN_EXTRA),
  contents = c("flood_zone", "elevation_m", "distance_to_river_km", "sum_insured", "tenure", "region",
               "policyholder_age", "prior_claims_5y", "urban_density", "missed_payments_12m", "voluntary_excess",
               "security_level", "high_value_items", "accidental_damage_cover", "works_from_home", "lodgers",
               "bicycle_cover", "property_type", "household_size", "hist_pol_n", "hist_cust_other_n",
               "hist_addr_flood", "hist_addr_water", BEN_EXTRA)
)
# Rare perils: a short, physically motivated frequency list (SAM 3)
PERIL_GLM_FEATURES <- list(
  buildings.fire = c("sum_insured", "property_type", "construction_type", "occupancy", "smoke_alarms", "region",
                     "urban_density", "listed_building", "prior_claims_5y", "hist_pol_n"),
  buildings.flood = c("flood_zone", "elevation_m", "distance_to_river_km", "basement", "sum_insured", "region",
                      "rainfall_mm", "hist_addr_flood"),
  buildings.subsidence = c("soil_type", "trees_within_5m", "dry_summer_index", "property_age", "sum_insured",
                           "region", "hist_addr_subs"),
  contents.flood = c("flood_zone", "elevation_m", "distance_to_river_km", "property_type", "sum_insured", "region",
                     "rainfall_mm", "hist_addr_flood")
)
SEV_FEATURES <- list(
  motor = c("vehicle_value_group", "cover_type", "vehicle_age", "region", "driver_age", "voluntary_excess", "urban_density"),
  buildings = c("sum_insured", "property_type", "region", "flood_zone", "property_age", "accidental_damage_cover"),
  contents = c("sum_insured", "high_value_items", "region", "tenure", "accidental_damage_cover")
)
MONO <- c(ncb_years = -1, prior_claims_5y = 1, licence_points = 1, missed_payments_12m = 1, hist_pol_n = 1,
          hist_pol_cost = 1, hist_cust_other_n = 1, prev_declined = 1, voluntary_excess = -1)
sam_tuning <- fread("week1/models/sam_iteration_03/xgb_tuning.csv")
XGB_CFG <- lapply(setNames(LINES, LINES), function(ln) {
  cfg <- as.list(sam_tuning[line == ln][rank == 1, .(max_depth, learning_rate, subsample, colsample_bytree, reg_lambda)])
  modifyList(cfg, list(min_child_weight = 10))   # Poisson hessian = expected claims: about 10 claims per leaf
})
fit_seed <- function(ln, pr, year, k = 0) SEED + 1000 * match(ln, LINES) + 50 * match(pr, PERILS[[ln]]) + 10 * (year - 2020) + k

read_b3 <- function(name) as.data.table(read_parquet(file.path(DATA_DIR, paste0(name, ".parquet"))))
claims_pos <- read_b3("claims_pos")
sample_train <- function(tr, ln) {
  if (!QUICK) return(tr)
  set.seed(SEED + match(ln, LINES))
  tr[policy_id %in% sample(unique(policy_id), min(uniqueN(policy_id), QUICK_POLICIES))]
}

# Fold targets: claim caps and loadings from the fit rows; effective exposure from the per-row reported share
prepare_fold <- function(tr, ln) {
  cl <- claims_pos[line == ln & row_id %in% tr$row_id]
  caps <- cl[, .(cap = quantile(net_adj, CLAIM_CAP_Q, names = FALSE)), by = peril]
  cl <- caps[cl, on = "peril"]
  caps <- merge(caps, cl[, .(claims = .N, loading = sum(net_adj) / sum(pmin(net_adj, cap))), by = peril], by = "peril")
  cc <- cl[, .(capcost = sum(pmin(net_adj, cap))), by = .(row_id, peril)]
  for (pr in PERILS[[ln]]) {
    v <- cc[peril == pr]
    set(tr, j = paste0("y_capcost_", pr), value = fcoalesce(v$capcost[match(tr$row_id, v$row_id)], 0))
    set(tr, j = paste0("y_effexp_", pr), value = tr$exposure * tr[[paste0("y_sharen_", pr)]])
  }
  tr[, y_npos_all := rowSums(.SD), .SDcols = paste0("y_npos_", PERILS[[ln]])]
  caps[, line := ln]
}

# GLM machinery (as SAM 3; scored by week1/R/model_io.R glm_link + sam02_glm_rate) -------------------------------------
glm_specs <- function(d, feats, w = d$exposure, n_bins = GLM_BINS, min_share = GLM_MIN_LEVEL_SHARE) {
  specs <- list()
  for (f in intersect(feats, names(d))) {
    x <- d[[f]]
    sp <- if (is.numeric(x) && uniqueN(x, na.rm = TRUE) > 10) {
      br <- unique(quantile(x, seq(0, 1, length.out = n_bins + 1), na.rm = TRUE, names = FALSE))
      list(type = "bin", breaks = c(-Inf, br[-c(1, length(br))], Inf))
    } else list(type = "cat")
    v <- encode_raw(x, sp)
    ex <- tapply(w, v, sum)
    sp$base <- names(which.max(ex))
    lv <- names(ex)[ex / sum(ex) >= min_share]
    lv <- if (sp$type == "bin") intersect(c(levels(cut(0, sp$breaks)), "missing"), lv)
          else lv[order(suppressWarnings(as.numeric(lv)), lv)]
    sp$levels <- lv
    if (length(lv) >= 2) specs[[f]] <- sp
  }
  specs
}

# Log-link GLM on a rate with a centred, capped year trend
fit_glm <- function(d, y, w, specs, family) {
  X <- data.table(y = y)
  for (f in names(specs)) {
    sp <- specs[[f]]
    set(X, j = f, value = relevel(factor(encode_level(d[[f]], sp), levels = sp$levels), ref = sp$base))
  }
  use_year <- uniqueN(d$policy_year) >= 2
  year_ref <- weighted.mean(d$policy_year, w)
  if (use_year) X[, yc := d$policy_year - year_ref]
  rhs <- setdiff(names(X), "y")
  fml <- as.formula(paste("y ~", if (length(rhs)) paste(rhs, collapse = " + ") else "1"))
  fit <- function(fml, X) suppressWarnings(glm(fml, family = family, data = X, weights = w, control = glm.control(maxit = 100),
                                               mustart = rep(weighted.mean(y, w), nrow(X))))
  m <- tryCatch(fit(fml, X), error = function(e) { log_msg("GLM failed (", conditionMessage(e), "); trend only"); NULL })
  if (is.null(m)) {
    specs <- list()
    X <- X[, intersect(c("y", "yc"), names(X)), with = FALSE]
    m <- fit(as.formula(paste("y ~", if ("yc" %in% names(X)) "yc" else "1")), X)
  }
  cf <- coef(m)
  cf[is.na(cf)] <- 0
  raw <- if (use_year) cf[["yc"]] else 0
  list(specs = specs, coef = cf, year_ref = year_ref, year_coef_raw = raw, year_coef = max(-TREND_CAP, min(TREND_CAP, raw)))
}

peril_freq_feats <- function(ln, pr) {
  k <- paste(ln, pr, sep = ".")
  base <- if (!is.null(PERIL_GLM_FEATURES[[k]])) PERIL_GLM_FEATURES[[k]] else GLM_FEATURES[[ln]]
  unique(c(base, paste0("hist_pol_n_", pr)))
}

fit_freq_glm <- function(tr, ln, pr, seed) {
  eff <- tr[[paste0("y_effexp_", pr)]]
  y <- tr[[paste0("y_npos_", pr)]] / eff
  pos <- y > 0
  set.seed(seed)
  r <- min(1, GLM_ZERO_SAMPLE / max(1, sum(!pos)))
  keep <- pos | runif(nrow(tr)) < r
  fit_glm(tr[keep], y[keep], eff[keep] * ifelse(pos[keep], 1, 1 / r), glm_specs(tr, peril_freq_feats(ln, pr)),
          quasipoisson(link = "log"))
}

fit_sev_glm <- function(tr, ln, pr, with_factors) {
  n <- tr[[paste0("y_npos_", pr)]]
  cc <- tr[[paste0("y_capcost_", pr)]]
  ok <- n > 0 & cc > 0
  d <- tr[ok]
  feats <- if (with_factors && sum(n[ok]) >= SEV_MIN_CLAIMS) SEV_FEATURES[[ln]] else character(0)
  fit_glm(d, cc[ok] / n[ok], n[ok], glm_specs(d, feats, w = n[ok]), Gamma(link = "log"))
}

# Tree machinery (XGBoost Poisson bag; scored by week1/R/model_io.R sam02_tree_rate) ----------------------------------
tree_feats <- function(dt) setdiff(feature_cols(dt, include_new = TRUE), DROP)
tree_encoder <- function(tr, feats) {
  cats <- feats[vapply(feats, function(f) is.character(tr[[f]]), logical(1))]
  lv <- lapply(setNames(cats, cats), function(f) {
    r <- tr[, .(rate = sum(y_npos_all) / sum(exposure)), by = f]   # codes ordered by the line's claim frequency
    r[order(rate, get(f))][[f]]
  })
  list(features = feats, cat_levels = lv)
}
mono_for <- function(feats, ln, pr) {
  m <- c(MONO, setNames(1, paste0("hist_pol_n_", pr)))
  if (pr == "flood") m <- c(m, flood_zone = 1, hist_addr_flood = 1, flood_score = 1)
  if (pr %in% c("bodily_injury", "third_party_prop")) m <- m[names(m) != "voluntary_excess"]   # excess: own claims only
  v <- unname(m[feats]); v[is.na(v)] <- 0
  paste0("(", paste(as.integer(v), collapse = ","), ")")
}
peril_cfg <- function(ln, claims) {
  cfg <- XGB_CFG[[ln]]
  if (claims < SPARSE_CLAIMS) cfg <- modifyList(cfg, list(max_depth = min(cfg$max_depth, 3), min_child_weight = 25))
  cfg
}
fit_booster <- function(X, label, w, hold, mono, seed, cfg, rounds = MAX_ROUNDS) {
  params <- list(objective = "count:poisson", learning_rate = cfg$learning_rate, max_depth = cfg$max_depth,
                 min_child_weight = cfg$min_child_weight, subsample = cfg$subsample, colsample_bytree = cfg$colsample_bytree,
                 reg_lambda = cfg$reg_lambda, tree_method = "hist", nthread = N_THREADS, seed = seed,
                 monotone_constraints = mono, max_delta_step = 0.7)
  if (is.null(hold)) return(xgb.train(params = params, data = xgb.DMatrix(X, label = label, weight = w, nthread = N_THREADS),
                                      nrounds = rounds, verbose = 0))
  dtr <- xgb.DMatrix(X[!hold, , drop = FALSE], label = label[!hold], weight = w[!hold], nthread = N_THREADS)
  dva <- xgb.DMatrix(X[hold, , drop = FALSE], label = label[hold], weight = w[hold], nthread = N_THREADS)
  xgb.train(params = params, data = dtr, nrounds = rounds, evals = list(holdout = dva), early_stopping_rounds = 50, verbose = 0)
}
# Bag: member 1 early-stops on a 10% policy holdout; the others train on all rows for 1.1 x its best rounds
fit_freq_tree <- function(X, enc, tr, ln, pr, n_seeds, seed, claims) {
  eff <- tr[[paste0("y_effexp_", pr)]]
  label <- tr[[paste0("y_npos_", pr)]] / pmax(eff, 1e-6)
  cfg <- peril_cfg(ln, claims)
  mono <- mono_for(enc$features, ln, pr)
  set.seed(seed)
  up <- unique(tr$policy_id)
  hold <- tr$policy_id %in% sample(up, round(0.1 * length(up)))
  b1 <- fit_booster(X, label, eff, hold, mono, seed, cfg)
  best <- max(10L, as.integer(xgb.attr(b1, "best_iteration")) + 1L)
  boosters <- list(b1)
  for (s in seq_len(n_seeds - 1)) boosters[[s + 1]] <- fit_booster(X, label, eff, NULL, mono, seed + s, cfg, ceiling(1.1 * best))
  list(kind = "xgb", boosters = boosters, features = enc$features, cat_levels = enc$cat_levels, best_iter = best,
       max_depth = cfg$max_depth, min_child_weight = cfg$min_child_weight)
}

peril_artifact <- function(ln, comps) list(model = "sam02_peril", line = ln, perils = comps)
peril_comp <- function(pr, fg, tree, sg, loading) list(peril = pr, freq_glm = fg, freq_tree = tree, sev_glm = sg, loading = loading)
CANDS <- data.table(cand = c("glm_x_sevfactors", "glm_x_sevtrend", "tree_x_sevfactors", "tree_x_sevtrend"),
                    tree = c(FALSE, FALSE, TRUE, TRUE), sev = c("factors", "trend", "factors", "trend"))

# Metrics (as SAM 3) -------------------------------------------------------------------------------------------
tweedie_dev <- function(y, mu, p = TWEEDIE_P) {
  mu <- pmax(mu, 1e-6)
  2 * mean(ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
norm_gini <- function(y, s) {
  g <- function(a, s) { a <- a[order(s, decreasing = TRUE)]; n <- length(a); sum(cumsum(a) / sum(a) - seq_len(n) / n) / n }
  g(y, s) / g(y, y)
}
d2_tweedie <- function(y, pred, exposure) {
  baseline <- exposure * sum(y) / sum(exposure)
  1 - tweedie_dev(y, pred) / tweedie_dev(y, baseline)
}
d2_cal <- function(y, pred, exposure) d2_tweedie(y, pred * sum(y) / sum(pred), exposure)

# Fit every candidate component of one line on tr; score va (validation) --------------------------------------------
fit_line_candidates <- function(tr, va, ln, year) {
  caps <- prepare_fold(tr, ln)
  enc <- tree_encoder(tr, tree_feats(tr))
  X <- lgb_matrix(tr, enc$features, enc$cat_levels)
  out <- list(); trends <- list()
  for (pr in PERILS[[ln]]) {
    t0 <- Sys.time()
    cp <- caps[peril == pr]
    fg <- fit_freq_glm(tr, ln, pr, fit_seed(ln, pr, year))
    sev <- list(factors = fit_sev_glm(tr, ln, pr, TRUE), trend = fit_sev_glm(tr, ln, pr, FALSE))
    tree <- fit_freq_tree(X, enc, tr, ln, pr, N_SEEDS_VALID, fit_seed(ln, pr, year, 1), cp$claims)
    for (i in seq_len(nrow(CANDS))) {
      art <- peril_artifact(ln, setNames(list(peril_comp(pr, fg, if (CANDS$tree[i]) tree, sev[[CANDS$sev[i]]], cp$loading)), pr))
      out[[paste(pr, CANDS$cand[i])]] <- data.table(peril = pr, cand = CANDS$cand[i], row = seq_len(nrow(va)), pred = score_model(art, va))
    }
    trends[[pr]] <- data.table(line = ln, peril = pr, valid_year = year, claims = cp$claims, loading = cp$loading,
                               freq_trend = exp(fg$year_coef) - 1, sev_trend_factors = exp(sev$factors$year_coef) - 1,
                               sev_trend_only = exp(sev$trend$year_coef) - 1, tree_rounds = tree$best_iter,
                               tree_depth = tree$max_depth)
    log_msg(ln, " ", year, " / ", pr, ": fitted in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s (",
            cp$claims, " claims, tree ", tree$best_iter, " rounds)")
  }
  rm(X); gc(verbose = FALSE)
  list(preds = rbindlist(out), trends = rbindlist(trends))
}

# 1. Validation: all candidates per peril, folds 2023 and 2024 ----------------------------------------------------
peril_scores <- list(); fold_preds <- list(); trend_valid <- list()
for (vy in VALID_YEARS) for (ln in LINES) {
  dt <- read_b3(paste0("train_", ln))
  tr <- sample_train(dt[policy_year < vy], ln)
  va <- dt[policy_year == vy]
  rm(dt); gc(verbose = FALSE)
  fit <- fit_line_candidates(tr, va, ln, vy)
  p <- fit$preds
  for (pr in PERILS[[ln]]) {
    rep_cost <- va[[paste0("y_cost_", pr)]]
    dev_cost <- va[[paste0("y_costadj_", pr)]] / va[[paste0("y_sharew_", pr)]]
    peril_scores[[paste(vy, ln, pr)]] <- p[peril == pr, .(
      valid_year = vy, line = ln, d2_developed = d2_tweedie(dev_cost[row], pred, va$exposure[row]),
      d2_reported = d2_tweedie(rep_cost[row], pred, va$exposure[row]), ae_developed = sum(pred) / sum(dev_cost)), by = .(peril, cand)]
  }
  fold_preds[[paste(vy, ln)]] <- list(va = va[, c("row_id", "exposure", "y_cost", paste0("y_cost_", PERILS[[ln]]),
                                                  paste0("y_costadj_", PERILS[[ln]]), paste0("y_sharew_", PERILS[[ln]])), with = FALSE],
                                      preds = p)
  trend_valid[[paste(vy, ln)]] <- fit$trends
  rm(tr, va, fit, p); gc(verbose = FALSE)
}
peril_scores <- rbindlist(peril_scores)
trend_valid <- rbindlist(trend_valid)

# 2. Model form per peril: best mean developed D2 over the folds --------------------------------------------------
choice_tab <- peril_scores[, .(d2_developed = mean(d2_developed), d2_reported = mean(d2_reported), ae_developed = mean(ae_developed)),
                           by = .(line, peril, cand)]
choice <- choice_tab[order(-d2_developed), .SD[1], by = .(line, peril)][, .(line, peril, cand)]
choice <- merge(choice, CANDS, by = "cand")
log_msg("Chosen per peril: ", paste(sprintf("%s/%s=%s", choice$line, choice$peril, choice$cand), collapse = "; "))

# Line and combined validation scores of the chosen combination (rows as reported, as SAM 3 scores them)
val <- rbindlist(lapply(names(fold_preds), function(k) {
  f <- fold_preds[[k]]; vy <- as.integer(substr(k, 1, 4)); ln <- sub("^[0-9]+ ", "", k)
  ch <- choice[line == ln]
  p <- merge(f$preds, ch[, .(peril, cand)], by = c("peril", "cand"))[, .(pred = sum(pred)), by = row]
  v <- f$va
  developed <- Reduce(`+`, lapply(PERILS[[ln]], function(pr) v[[paste0("y_costadj_", pr)]] / v[[paste0("y_sharew_", pr)]]))
  data.table(valid_year = vy, line = ln, exposure = v$exposure, actual = v$y_cost, developed = developed,
             pred = p$pred[match(seq_len(nrow(v)), p$row)])
}))
line_metrics <- val[, .(d2 = d2_tweedie(actual, pred, exposure), d2_cal = d2_cal(actual, pred, exposure),
                        gini = norm_gini(actual, pred), ae_reported = sum(pred) / sum(actual),
                        ae_developed = sum(pred) / sum(developed)), by = .(valid_year, line)]
combined_metrics <- val[, .(line = "ALL", d2 = d2_tweedie(actual, pred, exposure), d2_cal = d2_cal(actual, pred, exposure),
                            gini = norm_gini(actual, pred), ae_reported = sum(pred) / sum(actual),
                            ae_developed = sum(pred) / sum(developed)), by = valid_year]
metrics_all <- rbind(line_metrics, combined_metrics)

# SAM 3's blend on the same folds (its card: week1/models/sam_iteration_03/validation_*.csv; same actuals and D2 definition)
sam_line <- unique(fread("week1/models/sam_iteration_03/validation_metrics.csv")[model == "blend" & valid_year %in% VALID_YEARS,
                                                                            .(valid_year, line, d2, d2_cal, gini, ae_reported)])
sam_comb <- unique(fread("week1/models/sam_iteration_03/validation_combined.csv")[model == "blend" & valid_year %in% VALID_YEARS,
                                                                            .(valid_year, line = "ALL", d2, gini)])
sam <- rbind(sam_line, sam_comb, fill = TRUE)
comparison <- merge(metrics_all[, .(valid_year, line, ben3_d2 = d2, ben3_d2_cal = d2_cal, ben3_gini = gini, ben3_ae_reported = ae_reported)],
                    sam[, .(valid_year, line, sam3_d2 = d2, sam3_d2_cal = d2_cal, sam3_gini = gini, sam3_ae_reported = ae_reported)],
                    by = c("valid_year", "line"), all.x = TRUE)[, d2_diff := ben3_d2 - sam3_d2]
comparison <- comparison[order(valid_year, match(line, c(LINES, "ALL")))]

# 3. Final fit on 2021-24 with each peril's chosen form; score 2025 ------------------------------------------------
unlink(ITER_DIR, recursive = TRUE)
dir.create(FITTED_DIR, recursive = TRUE, showWarnings = FALSE)
sub_parts <- list(); test_summary <- list(); final_trends <- list(); importance <- list(); final_caps <- list(); peril_test <- list()
for (ln in LINES) {
  tr <- sample_train(read_b3(paste0("train_", ln)), ln)
  te <- read_b3(paste0("test_", ln))
  caps <- prepare_fold(tr, ln)
  enc <- tree_encoder(tr, tree_feats(tr))
  X <- if (any(choice[line == ln, tree])) lgb_matrix(tr, enc$features, enc$cat_levels)
  comps <- list()
  for (pr in PERILS[[ln]]) {
    ch <- choice[line == ln & peril == pr]
    cp <- caps[peril == pr]
    fg <- fit_freq_glm(tr, ln, pr, fit_seed(ln, pr, TARGET_YEAR))
    sg <- fit_sev_glm(tr, ln, pr, ch$sev == "factors")
    tree <- if (ch$tree) fit_freq_tree(X, enc, tr, ln, pr, N_SEEDS_FINAL, fit_seed(ln, pr, TARGET_YEAR, 1), cp$claims)
    comps[[pr]] <- peril_comp(pr, fg, tree, sg, cp$loading)
    final_trends[[paste(ln, pr)]] <- data.table(line = ln, peril = pr, form = ch$cand, claims = cp$claims, cap = cp$cap,
                                                loading = cp$loading, freq_trend = exp(fg$year_coef) - 1,
                                                freq_trend_unclamped = exp(fg$year_coef_raw) - 1, sev_trend = exp(sg$year_coef) - 1,
                                                freq_factors = paste(names(fg$specs), collapse = ", "),
                                                sev_factors = paste(names(sg$specs), collapse = ", "),
                                                tree_rounds = if (ch$tree) tree$best_iter else NA_integer_)
    if (ch$tree) importance[[paste(ln, pr)]] <- as.data.table(xgb.importance(model = tree$boosters[[1]]))[
      order(-Gain)][, .(line = ln, peril = pr, rank = .I, Feature, Gain)]
    peril_test[[paste(ln, pr)]] <- data.table(line = ln, peril = pr,
      burn = sum(score_model(peril_artifact(ln, setNames(list(comps[[pr]]), pr)), te)) / sum(te$exposure))
    log_msg(ln, " / ", pr, ": final ", ch$cand)
  }
  art <- c(peril_artifact(ln, comps), list(iteration = ITERATION, forms = setNames(choice[line == ln, cand], choice[line == ln, peril])))
  save_model(art, FITTED_DIR, paste0(ln, "_ben3"))
  pred <- pmax(score_model(art, te), 0)
  q <- quantile(pred, c(0.5, 0.9, 0.99), names = FALSE)
  test_summary[[ln]] <- data.table(line = ln, test_exposure = sum(te$exposure), predicted_total = sum(pred),
                                   predicted_burn_cost = sum(pred) / sum(te$exposure), p50_row = q[1], p90_row = q[2],
                                   p99_row = q[3], max_row = max(pred))
  if (ln == "motor") {
    zero_check <- data.table(cover_type = te$cover_type, glass = score_model(peril_artifact(ln, comps["glass_hail"]), te) / te$exposure,
                             theft = score_model(peril_artifact(ln, comps["theft"]), te) / te$exposure)[
      , .(rows = .N, glass_hail_rate = mean(glass), theft_rate = mean(theft)), keyby = cover_type]
  }
  final_caps[[ln]] <- caps
  sub_parts[[ln]] <- data.table(row_id = te$row_id, prediction = pred)
  log_msg(ln, ": cost per exposure-year ", round(sum(pred) / sum(te$exposure), 2))
  rm(tr, te, X, pred); gc(verbose = FALSE)
}
test_summary <- rbindlist(test_summary); final_trends <- rbindlist(final_trends); final_caps <- rbindlist(final_caps)
importance <- rbindlist(importance); peril_test <- rbindlist(peril_test)

sub <- rbindlist(sub_parts)
sample_sub <- read_raw("sample_submission")
stopifnot(nrow(sub) == nrow(sample_sub), setequal(sub$row_id, sample_sub$row_id), !anyDuplicated(sub$row_id),
          !anyNA(sub$prediction), all(sub$prediction >= 0))
sub <- sub[match(sample_sub$row_id, row_id)]
run_file <- out_file("submission", paste0("submission_", RUN_ID, if (QUICK) "_quick", "_ben03.csv"))
fwrite(sub, run_file, scipen = 50)
if (!QUICK) invisible(file.copy(run_file, out_file("submission", "submission_provisional.csv"), overwrite = TRUE))
sub_md5 <- unname(tools::md5sum(run_file))

replication <- rbindlist(lapply(LINES, function(ln) {
  te <- read_b3(paste0("test_", ln))
  re <- pmax(score_model(load_model(FITTED_DIR, paste0(ln, "_ben3")), te), 0)
  data.table(line = ln, rows = nrow(te), max_abs_diff = max(abs(re - sub[match(te$row_id, row_id), prediction])))
}))
replication_ok <- all(replication$max_abs_diff < 1e-6)
if (!replication_ok) warning("Reloaded models do not reproduce the submission - see the model card.")

# 4. Card, CSVs, run history ----------------------------------------------------------------------------------------
git_commit <- tryCatch({
  h <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)
  dirty <- length(system2("git", c("status", "--porcelain", "--untracked-files=no", "--", "week1/R"), stdout = TRUE, stderr = FALSE)) > 0
  paste0(h, if (dirty) " + uncommitted changes in week1/R/" else "")
}, error = function(e) "unknown")
d2_of <- function(vy, ln = "ALL") metrics_all[valid_year == vy & line == ln, d2]
run_row <- data.table(iteration = ITERATION, run_id = RUN_ID, git_commit = git_commit, file = basename(run_file), file_md5 = sub_md5,
                      replication_check = if (replication_ok) "passed" else "FAILED",
                      models = paste(sprintf("%s=%s", choice$line, paste(choice$peril, choice$cand, sep = ":")), collapse = "; "),
                      local_d2_2023 = d2_of(2023), local_d2_2024 = d2_of(2024),
                      by_line_2023_2024 = paste(sprintf("%s %.3f / %.3f", LINES, sapply(LINES, d2_of, vy = 2023),
                                                        sapply(LINES, d2_of, vy = 2024)), collapse = "; "))
if (!QUICK) {
  hist_file <- out_file("4_models", "run_history.csv")
  history <- if (file.exists(hist_file)) rbind(fread(hist_file, colClasses = list(character = c("run_id", "iteration"))), run_row, fill = TRUE) else run_row
  fwrite(history, hist_file)
}
fwrite(run_row, file.path(ITER_DIR, "summary.csv"))
fwrite(peril_scores, file.path(ITER_DIR, "validation_by_peril_candidate.csv"))
fwrite(choice_tab, file.path(ITER_DIR, "peril_choice_scores.csv"))
fwrite(choice, file.path(ITER_DIR, "peril_choice.csv"))
fwrite(metrics_all, file.path(ITER_DIR, "validation_metrics.csv"))
fwrite(comparison, file.path(ITER_DIR, "comparison_sam03.csv"))
fwrite(trend_valid, file.path(ITER_DIR, "trend_by_fold.csv"))
fwrite(final_trends, file.path(ITER_DIR, "final_models.csv"))
fwrite(test_summary, file.path(ITER_DIR, "test_prediction_summary.csv"))
fwrite(peril_test, file.path(ITER_DIR, "test_burn_by_peril.csv"))
fwrite(importance, file.path(ITER_DIR, "tree_importance.csv"))

levels_tab <- data.table(source = c("BEN 1/2", "WENDY 4", "WENDY 5", "SAM 3", "Level anchor (ben3_study)"),
                         public = c(0.12224, 0.12671, 0.12636, 0.12818, NA),
                         motor = c(505.5, 521.2, 545.1, 603.3, 548), buildings = c(456.4, 482.4, 475.4, 487.4, 489),
                         contents = c(122.4, 125.0, 125.4, 125.2, 128))
levels_tab <- rbind(levels_tab, data.table(source = ITERATION, public = NA, motor = test_summary[line == "motor", predicted_burn_cost],
                                           buildings = test_summary[line == "buildings", predicted_burn_cost],
                                           contents = test_summary[line == "contents", predicted_burn_cost]))
card <- c(
  paste0("# ", ITERATION, " - frequency x severity per peril, model form chosen per peril"), "",
  paste0("**Run id** `", RUN_ID, "` | **Generated** ", format(Sys.time(), "%Y-%m-%d %H:%M"), " | **Git commit** `", git_commit,
         "` | **Submission file** `", basename(run_file), "` | **MD5** `", sub_md5, "` | **Replication check** ",
         if (replication_ok) "passed" else "FAILED"), "",
  if (QUICK) c("> **Smoke test:** sampled training rows and short trees; scores are not representative.", ""),
  if (grepl("uncommitted", git_commit)) c("> **Warning:** generated from uncommitted code.", ""),
  paste0("**Change:** ", ITERATION_NOTE), "",
  "## Local validation vs SAM 3 (same folds, same actuals as reported, same D2)",
  "SAM 3 = its submitted blend (`week1/models/sam_iteration_03/validation_*.csv`). Both choose their components on these folds.", "",
  md_table(comparison, 4),
  "A/E against developed actuals (per-row chain ladder, after expected recoveries):", "",
  md_table(metrics_all[, .(valid_year, line, ae_reported, ae_developed, d2_cal, gini)], 3),
  "## Model form per peril",
  "Candidates: frequency GLM alone or GLM level + XGBoost Poisson shape; severity GLM with factors or trend only. Score = mean",
  "D2 against the peril's developed cost over 2023 and 2024.", "",
  md_table(dcast(choice_tab, line + peril ~ cand, value.var = "d2_developed")[, chosen := choice$cand[match(paste(line, peril), paste(choice$line, choice$peril))]], 4),
  "## Final models (fit 2021-24)", md_table(final_trends[, .(line, peril, form, claims, cap, loading, freq_trend, sev_trend, tree_rounds)], 3),
  "Factors in each GLM:", "", md_table(final_trends[, .(line, peril, freq_factors, sev_factors)]),
  "## 2025 predictions",
  md_table(test_summary, 2),
  "Cost per exposure-year against earlier submissions and the level anchor from `week1/R/ben/ben3_study.R`:", "",
  md_table(levels_tab, 1),
  "By peril:", "", md_table(dcast(peril_test, peril ~ line, value.var = "burn"), 2),
  "Motor rates by cover type (glass and theft should be near zero where not covered):", "", md_table(zero_check, 3),
  "## Tree importance (top 5 per peril with a tree)", md_table(importance[rank <= 5], 3),
  "## Replication", md_table(replication, 10)
)
writeLines(card, file.path(ITER_DIR, "model_card.md"))
log_msg("Done. Card: ", file.path(ITER_DIR, "model_card.md"), " | Submission: ", run_file)
