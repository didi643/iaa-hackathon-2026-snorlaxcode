# 4_models_itermotor01.R ---------------------------------------------------------
# MOTOR 1: motor-only per-peril frequency x severity. Each peril has its own GLM feature set (natural splines,
# exposure x reported-share offset, chosen by a forward feature ladder on rolling folds), Gamma severity with a
# sample-size gate and credibility shrinkage, optional XGBoost Poisson frequency (offset as base_margin) and Gamma
# severity, compared with a single line-level Tweedie model, the iteration-1 GLM replay and SAM 4.
#   Phase A  data checks, claims development / IBNR by peril, 2025 weather check, engineered features
#   Phase B  rolling folds 2022 / 2023 / 2024 (fit on earlier years), in-fold caps, IBNR shares, target encodings
#   Phase C  frequency feature ladder per peril (GLM, calibrated Poisson D2)
#   Phase D  candidate fits per fold: GLM freq / severity variants, XGBoost freq + severity, line Tweedie, legacy GLM
#   Phase E  sequential per-peril decisions and a stage-by-stage before/after table (total and by peril)
#   Phase F  final fit on 2021-24, motor-only submission, saved model, replication check, model card
# Inputs: data/sam04 (from R/4_models_itersam04.R), output/3b_ibnr/recommended_*.csv, raw claims and weather.
# Outputs: models/motor_iteration_01/, output/submission/motor_only_<run id>[_samlevel].csv
# Env vars: MOTOR01_QUICK=1 (sampled policies, short boosting; writes to *_quick)

source("R/0_setup.R")
source("R/model_io.R")
suppressPackageStartupMessages({
  library(xgboost)
  library(splines)
})
T0 <- Sys.time()

QUICK <- Sys.getenv("MOTOR01_QUICK") == "1"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITERATION_LABEL <- if (QUICK) "motor_iteration_01_quick" else "motor_iteration_01"
ITER_DIR <- file.path("models", ITERATION_LABEL)
FITTED_DIR <- file.path(ITER_DIR, "fitted")
DATA_DIR <- file.path("data", "sam04")
IBNR_DIR <- file.path(PATHS$output, "3b_ibnr")
PR <- PERILS$motor

VALID_YEARS <- c(2022, 2023, 2024)
IMMATURE_YEAR <- 2024
CLAIM_CAP_Q <- 0.995
LONG_TAIL_SEV_BEFORE <- 2023
TREND_CAP <- log(1.10)
SPLINE_DF <- 4
MIN_LEVEL_SHARE <- 0.002
UNCOVERED_RATE_SHARE <- 0.02      # cover level with < 2% of the peril's average claim rate = peril not covered
ZERO_SAMPLE_LADDER <- if (QUICK) 30000 else 150000
ZERO_SAMPLE <- if (QUICK) 50000 else 400000
SEV_MIN_CLAIMS <- 3000            # below this a severity GLM keeps only its first SEV_GATE_FEATS factors
SEV_GATE_FEATS <- 3
TE_K <- 200                       # credibility (effective exposure-years) for target encodings
KEEP_GAIN <- 0.0005               # keep a change only if the mean gain exceeds this and it wins in >= 2 of 3 folds
SHRINK_GRID <- c(0, 0.25, 0.5, 0.75, 1)
MIX_GRID <- c(0, 0.5, 1)
TW_GRID <- c(0, 0.1, 0.2, 0.3)
QUICK_POLICIES <- 40000
N_THREADS <- 14
N_SEEDS_FINAL <- if (QUICK) 1 else 3
MAX_ROUNDS <- if (QUICK) 300 else 2000
XGB_PARAMS <- list(learning_rate = 0.05, max_depth = 4, min_child_weight = 20, subsample = 0.8,
                   colsample_bytree = 0.7, reg_lambda = 5)
SAM4_D2 <- c(`2022` = 0.0596, `2023` = 0.0435, `2024` = 0.0463)  # models/sam_iteration_04 motor blend, raw D2

CORE <- c("driver_age", "years_licensed", "ncb_years", "vehicle_value_group", "vehicle_age", "cover_type",
          "annual_mileage", "vehicle_use", "named_young_driver", "region", "urban_density", "voluntary_excess",
          "prior_claims_5y", "licence_points", "credit_band", "new_business", "payment_method", "telematics_opt_in")
FREQ_BASE <- list(
  own_damage = c(CORE, "overnight_parking", "body_type", "fuel_type"),
  third_party_prop = c(CORE, "overnight_parking", "body_type", "fuel_type"),
  bodily_injury = c(CORE, "overnight_parking", "body_type"),
  theft = c("vehicle_value_group", "vehicle_age", "cover_type", "overnight_parking", "region", "urban_density",
            "fuel_type", "credit_band", "voluntary_excess", "driver_age"),
  glass_hail = c("vehicle_value_group", "vehicle_age", "body_type", "cover_type", "region", "voluntary_excess",
                 "driver_age")
)
# Ladder groups in test order; a group with several options keeps the best option that passes the keep rule
GROUPS <- list(
  driver = list(c("licence_start_age", "ncb_gap", "nyd_age")),
  vehicle = list(c("value_per_cc", "vage_x_value", "engine_size_cc")),
  make_model_te = list("te_mm"),
  usage = list(c("use_parking", "annual_mileage")),
  mileage_per_exposure = list("mileage_per_exp"),
  telematics = list("telematics_score"),
  policy = list(c("missed_payments_12m", "renewal_count", "days_quote_to_inception", "channel_nb", "years_with_insurer")),
  customer = list(c("occupation", "marital_status", "years_at_address", "household_size")),
  region_urban_te = list("te_ru"),
  weather_primary = list(raw = c("hail_days", "freezing_days"),
                         avg = c("wx_avg_hail_days", "wx_avg_freezing_days"),
                         avg_dev = c("wx_avg_hail_days", "wx_avg_freezing_days", "wx_dev_hail_days", "wx_dev_freezing_days")),
  weather_other = list(c("wind_exposure_index", "dry_summer_index", "wildfire_index", "rainfall_mm", "mean_temperature_c")),
  claim_history = list(c("hist_pol_n", "hist_cust_other_n", "claim_free_years")),
  address_property = list(c("property_type", "flood_zone", "year_built"))
)
SEV_BASE <- list(
  own_damage = c("vehicle_value_group", "vehicle_age", "cover_type", "voluntary_excess", "region", "urban_density",
                 "driver_age", "body_type", "fuel_type"),
  third_party_prop = c("vehicle_value_group", "driver_age", "region", "urban_density", "vehicle_use"),
  bodily_injury = c("driver_age", "vehicle_value_group", "named_young_driver", "years_licensed", "body_type"),
  theft = c("vehicle_value_group", "vehicle_age", "cover_type", "voluntary_excess"),
  glass_hail = c("vehicle_value_group", "body_type", "voluntary_excess", "vehicle_age")
)
SEV_EXT <- list(
  own_damage = c("vage_x_value", "value_per_cc", "te_mm", "annual_mileage", "freezing_days"),
  third_party_prop = c("body_type", "engine_size_cc", "annual_mileage", "te_mm"),
  bodily_injury = c("engine_size_cc", "vehicle_age", "annual_mileage", "region"),
  theft = c("region", "urban_density", "overnight_parking", "te_mm"),
  glass_hail = c("region", "hail_days", "te_mm")
)
RECOVERY_PERILS <- c("own_damage", "theft")
SEV_XGB_PERILS <- c("own_damage", "third_party_prop")
TREE_CORE <- c("driver_age", "years_licensed", "ncb_years", "vehicle_value_group", "vehicle_age", "make_model",
               "engine_size_cc", "body_type", "transmission", "seats", "fuel_type", "driver_assist", "cover_type",
               "annual_mileage", "overnight_parking", "vehicle_use", "named_young_driver", "telematics_opt_in",
               "telematics_score", "telematics_missing", "voluntary_excess", "channel", "payment_method",
               "missed_payments_12m", "new_business", "renewal_count", "days_quote_to_inception", "occupation",
               "marital_status", "household_size", "credit_band", "prior_claims_5y", "licence_points",
               "years_at_address", "years_with_insurer", "customer_age", "start_month", "region", "urban_density",
               "hist_pol_n", "hist_cust_other_n", "licence_start_age", "ncb_gap")
MONO <- c(ncb_years = -1, prior_claims_5y = 1, licence_points = 1, missed_payments_12m = 1, hist_pol_n = 1,
          hist_cust_other_n = 1, claim_free_years = -1)
LEGACY_FEATS <- c("driver_age", "ncb_years", "years_licensed", "vehicle_value_group", "vehicle_age", "cover_type",
                  "annual_mileage", "overnight_parking", "vehicle_use", "named_young_driver", "fuel_type", "body_type",
                  "telematics_opt_in", "prior_claims_5y", "licence_points", "credit_band", "region", "urban_density",
                  "voluntary_excess", "occupation", "marital_status", "years_at_address", "renewal_count",
                  "new_business", "payment_method", "missed_payments_12m")
EXCLUDED <- data.table(
  feature = c("written_premium, discount_applied, premium_index", "renewal_decision", "customer_service_contacts",
              "compulsory_excess", "email_domain, vehicle_colour, document_preference, marketing_consent",
              "campaign_code, branch_id, marketing_segment, previous_insurer",
              "soil_type, distance_to_river_km, elevation_m, roof_type, basement, trees_within_5m, listed_building, bedrooms, energy_rating, solar_panels",
              "customer_since_year, policy_year as a feature"),
  decision = c("excluded", "excluded", "excluded", "excluded (checked)", "excluded", "excluded", "excluded",
               "excluded (trend term only)"),
  reason = c("current pricing output: priced on past claims experience, so it carries the target into the features",
             "row outcome, training only (trap 7)",
             "about 3 contacts per row with a claim vs 0.4 without; recorded after the loss",
             "insurer-set, so potentially driven by claims experience; constant in the data (see data checks), so no signal either way",
             "look uniform / possible sensitive proxies (trap 9); not rating factors",
             "marketing or distribution codes, no causal motor link; previous_insurer unstable in BEN 1 drop test",
             "buildings-peril address fields; property_type, flood_zone and year_built are tested once as a group in the ladder",
             "calendar drift handled by a capped GLM trend, not by tree splits"))

dir.create(FITTED_DIR, recursive = TRUE, showWarnings = FALSE)
checks <- list()
add_chk <- function(check, value, note = "") {
  checks[[length(checks) + 1]] <<- data.table(check = check, value = value, note = note)
}

# ==========================================================================================================
# Helpers
# ==========================================================================================================
cat_raw <- function(x) {
  v <- as.character(x)
  v[is.na(v)] <- "missing"
  v
}
# Numerics with > 10 values -> natural spline on the 0.5-99.5% clamped value (+ NA flag); others -> factor
spec_build <- function(d, feats, sw) {
  specs <- list()
  for (f in intersect(feats, names(d))) {
    x <- d[[f]]
    if (is.numeric(x) && uniqueN(x[!is.na(x)]) > 10) {
      ok <- !is.na(x)
      q <- quantile(x[ok], c(0.005, 0.995), names = FALSE)
      if (q[2] <= q[1]) next
      xc <- pmin(pmax(x[ok], q[1]), q[2])
      kn <- unique(quantile(xc, seq_len(SPLINE_DF - 1) / SPLINE_DF, names = FALSE))
      specs[[f]] <- list(type = "spl", lo = q[1], hi = q[2], knots = kn[kn > q[1] & kn < q[2]],
                         fill = median(x[ok]), na = mean(!ok) > 0.001)
    } else {
      v <- cat_raw(x)
      ex <- tapply(sw, v, sum)
      lv <- names(ex)[ex / sum(ex) >= MIN_LEVEL_SHARE]
      base <- names(which.max(ex))
      if (length(lv) >= 2) specs[[f]] <- list(type = "cat", levels = setdiff(lv, base), base = base)
    }
  }
  specs
}
design <- function(d, specs) {
  cols <- list()
  for (f in names(specs)) {
    sp <- specs[[f]]
    if (sp$type == "spl") {
      x <- as.numeric(d[[f]])
      isna <- is.na(x)
      x[isna] <- sp$fill
      B <- ns(pmin(pmax(x, sp$lo), sp$hi), knots = sp$knots, Boundary.knots = c(sp$lo, sp$hi))
      for (j in seq_len(ncol(B))) cols[[paste0(f, "_s", j)]] <- as.numeric(B[, j])
      if (sp$na) cols[[paste0(f, "_na")]] <- as.numeric(isna)
    } else {
      v <- cat_raw(d[[f]])
      for (lv in sp$levels) cols[[paste0(f, "=", lv)]] <- as.numeric(v == lv)
    }
  }
  if (!length(cols)) return(matrix(0, nrow(d), 0))
  do.call(cbind, cols)
}
# Log-link GLM; centred policy_year trend (capped when scored) and an optional dummy for the immature year
fit_glm2 <- function(d, feats, y, w, offset, family, sw, imm = FALSE, mustart = NULL) {
  specs <- spec_build(d, feats, sw)
  X <- design(d, specs)
  yrs <- d$policy_year
  use_imm <- imm && any(yrs == IMMATURE_YEAR) && uniqueN(yrs) > 2
  mature <- if (use_imm) yrs != IMMATURE_YEAR else rep(TRUE, length(yrs))
  year_ref <- weighted.mean(yrs[mature], w[mature])
  Xf <- cbind(`(Intercept)` = 1, X)
  if (uniqueN(yrs[mature]) >= 2) Xf <- cbind(Xf, yc = yrs - year_ref)
  if (use_imm) Xf <- cbind(Xf, imm = as.numeric(yrs == IMMATURE_YEAR))
  fit <- function(M) tryCatch(suppressWarnings(glm.fit(M, y, weights = w, offset = offset, family = family,
                                                       mustart = mustart, control = glm.control(maxit = 50))),
                              error = function(e) NULL)
  m <- fit(Xf)
  if (is.null(m) || any(!is.finite(m$coefficients[!is.na(m$coefficients)]))) {
    log_msg("GLM failed; falling back to intercept + trend")
    specs <- list()
    X <- matrix(0, nrow(d), 0)
    Xf <- Xf[, intersect(colnames(Xf), c("(Intercept)", "yc", "imm")), drop = FALSE]
    m <- fit(Xf)
  }
  cf <- m$coefficients
  cf[is.na(cf)] <- 0
  raw <- if ("yc" %in% names(cf)) cf[["yc"]] else 0
  list(specs = specs, coef = cf[c("(Intercept)", colnames(X))], year_ref = year_ref, year_raw = raw,
       year_coef = max(-TREND_CAP, min(TREND_CAP, raw)), imm_coef = if (use_imm) cf[["imm"]] else NA_real_,
       converged = isTRUE(m$converged))
}
glm_eta <- function(g, d) {
  X <- design(d, g$specs)
  eta <- rep(g$coef[["(Intercept)"]], nrow(d))
  if (ncol(X)) eta <- eta + drop(X %*% g$coef[colnames(X)])
  eta
}
glm_trend <- function(g, d) g$year_coef * (d$policy_year - g$year_ref)
rfeat <- function(feats, pr) ifelse(feats %in% c("te_mm", "te_ru"), paste0(feats, "_", pr), feats)

# Credibility-weighted claim-rate relativity; out-of-fold (5 policy groups) on training rows
te_tab <- function(key, n, e) {
  f0 <- sum(n) / sum(e)
  data.table(k = key, n = n, e = e)[, .(rel = (sum(n) + TE_K * f0) / (f0 * (sum(e) + TE_K))), by = k]
}
te_apply <- function(tab, key) {
  r <- tab$rel[match(key, tab$k)]
  r[is.na(r)] <- 1
  r
}
te_oof <- function(key, n, e, pol, seed) {
  set.seed(seed)
  ids <- unique(pol)
  g <- sample(rep_len(1:5, length(ids)))[match(pol, ids)]
  out <- numeric(length(key))
  for (k in 1:5) out[g == k] <- te_apply(te_tab(key[g != k], n[g != k], e[g != k]), key[g == k])
  out
}

add_shares <- function(d, rs) {
  for (pr in PR) {
    s <- row_report_share(rs, pr, d$period_start, d$period_end)
    set(d, j = paste0("sh_", pr), value = s)
    set(d, j = paste0("effexp_", pr), value = d$exposure * s)
  }
  invisible(d)
}
add_te <- function(d, info) {
  for (pr in PR) {
    set(d, j = paste0("te_mm_", pr), value = te_apply(info$te[[pr]]$mm, d$make_model))
    set(d, j = paste0("te_ru_", pr), value = te_apply(info$te[[pr]]$ru, paste(d$region, d$urban_density, sep = "|")))
  }
  invisible(d)
}
cap_rows <- function(d, cl, caps) {
  cl <- merge(cl[row_id %in% d$row_id], caps, by = "peril")
  for (pr in PR) {
    a <- cl[peril == pr, .(c = sum(pmin(net, cap)), ca = sum(pmin(net_adj, cap))), by = row_id]
    i <- match(d$row_id, a$row_id)
    set(d, j = paste0("capc_", pr), value = fifelse(is.na(i), 0, a$c[i]))
    set(d, j = paste0("capa_", pr), value = fifelse(is.na(i), 0, a$ca[i]))
  }
  cl
}

# In-fold: claim caps, recovery ratio for open claims, loadings, uncovered cover levels, target encodings
prep_fold <- function(tr, va, seed) {
  cl <- CL[row_id %in% c(tr$row_id, va$row_id)]
  ratio <- CL[row_id %in% tr$row_id & status == "closed", .(ratio = sum(recoveries) / sum(incurred_to_date)), by = peril]
  ratio[!peril %in% RECOVERY_PERILS, ratio := 0]
  cl <- merge(cl, ratio, by = "peril", all.x = TRUE)[is.na(ratio), ratio := 0]
  cl[, net_adj := fifelse(status == "open", net * (1 - ratio), net)]
  caps <- cl[row_id %in% tr$row_id, .(cap = quantile(net, CLAIM_CAP_Q, names = FALSE)), by = peril]
  cl_tr <- cap_rows(tr, cl, caps)
  cap_rows(va, cl, caps)
  info <- list(caps = caps, ratio = ratio, loading = list(), unc_rate = list(), te = list(), row_share = ROW_SHARE)
  y_target <- 0
  for (pr in PR) {
    n_col <- paste0("y_npos_", pr); e_col <- paste0("effexp_", pr)
    info$loading[[pr]] <- c(raw = sum(tr[[paste0("y_cost_", pr)]]) / sum(tr[[paste0("capc_", pr)]]),
                            adj = cl_tr[peril == pr, sum(net_adj)] / sum(tr[[paste0("capa_", pr)]]))
    y_target <- y_target + tr[[paste0("capc_", pr)]] / tr[[paste0("sh_", pr)]]
    r <- data.table(cover_type = tr$cover_type, n = tr[[n_col]], e = tr[[e_col]])[, .(n = sum(n), e = sum(e)), by = cover_type]
    unc <- r[n / e < UNCOVERED_RATE_SHARE * sum(r$n) / sum(r$e)]
    info$unc_rate[[pr]] <- setNames(pmax(unc$n, 0.5) / unc$e, unc$cover_type)
    covered <- !tr$cover_type %in% unc$cover_type
    n <- tr[[n_col]] * covered; e <- tr[[e_col]] * covered
    kmm <- tr$make_model; kru <- paste(tr$region, tr$urban_density, sep = "|")
    info$te[[pr]] <- list(mm = te_tab(kmm, n, e), ru = te_tab(kru, n, e))
    set(tr, j = paste0("te_mm_", pr), value = te_oof(kmm, n, e, tr$policy_id, seed))
    set(tr, j = paste0("te_ru_", pr), value = te_oof(kru, n, e, tr$policy_id, seed + 1))
  }
  set(tr, j = "y_target", value = y_target)
  set(tr, j = "y_npos_all", value = Reduce(`+`, lapply(PR, function(pr) tr[[paste0("y_npos_", pr)]])))
  set(tr, j = "y_nadj_all", value = Reduce(`+`, lapply(PR, function(pr) tr[[paste0("y_npos_", pr)]] / tr[[paste0("sh_", pr)]])))
  set(tr, j = "y_capcost_all", value = Reduce(`+`, lapply(PR, function(pr) tr[[paste0("capc_", pr)]])))
  add_te(va, info)
  info
}

freq_sample <- function(tr, pr, unc, nzero, seed) {
  set.seed(seed)
  cov <- !tr$cover_type %in% unc
  pos <- tr[[paste0("y_npos_", pr)]] > 0
  z <- which(cov & !pos)
  r <- min(1, nzero / max(1, length(z)))
  keep <- c(which(cov & pos), z[runif(length(z)) < r])
  list(idx = keep, w = ifelse(pos[keep], 1, 1 / r))
}
fit_freq <- function(tr, pr, feats, smp) {
  d <- tr[smp$idx]
  eff <- d[[paste0("effexp_", pr)]]
  fit_glm2(d, rfeat(feats, pr), d[[paste0("y_npos_", pr)]], smp$w, log(eff), poisson(), sw = eff * smp$w,
           imm = pr %in% LONG_TAIL)
}
sev_rows <- function(tr, pr, col) {
  ok <- tr[[paste0("y_npos_", pr)]] > 0 & tr[[col]] > 0
  if (pr %in% LONG_TAIL && any(ok & tr$policy_year < LONG_TAIL_SEV_BEFORE)) ok <- ok & tr$policy_year < LONG_TAIL_SEV_BEFORE
  ok
}
fit_sev <- function(tr, pr, feats, adj = FALSE) {
  col <- paste0(if (adj) "capa_" else "capc_", pr)
  ok <- sev_rows(tr, pr, col)
  d <- tr[ok]
  n <- d[[paste0("y_npos_", pr)]]
  y <- d[[col]] / n
  gated <- sum(n) < SEV_MIN_CLAIMS
  if (gated) feats <- head(feats, SEV_GATE_FEATS)
  g <- fit_glm2(d, rfeat(feats, pr), y, n, NULL, Gamma(link = "log"), sw = n,
                mustart = rep(weighted.mean(y, n), length(y)))
  g$eta_c <- weighted.mean(glm_eta(g, d), n)
  g$claims <- sum(n)
  g$gated <- gated
  g
}

# XGBoost: member 1 early-stops on a 10% policy holdout, others train on all rows for 1.1 x its best rounds
tree_enc <- function(d, feats, num, den) {
  feats <- intersect(feats, names(d))
  cats <- feats[vapply(feats, function(f) is.character(d[[f]]), logical(1))]
  lv <- lapply(setNames(cats, cats), function(f) {
    r <- data.table(k = d[[f]], n = num, e = den)[, .(rate = sum(n) / max(sum(e), 1e-9)), by = k]
    r[order(rate, k)]$k
  })
  list(features = feats, cat_levels = lv)
}
fit_xgb <- function(d, enc, y, w, margin, objective, mono, seed, n_seeds, extra = list()) {
  X <- lgb_matrix(d, enc$features, enc$cat_levels)
  set.seed(seed)
  up <- unique(d$policy_id)
  hold <- d$policy_id %in% sample(up, round(0.1 * length(up)))
  params <- c(XGB_PARAMS, list(objective = objective, tree_method = "hist", nthread = N_THREADS, seed = seed,
                               monotone_constraints = paste0("(", paste(mono, collapse = ","), ")")), extra)
  mk <- function(i) {
    xgb.DMatrix(X[i, , drop = FALSE], label = y[i], weight = if (is.null(w)) NULL else w[i],
                base_margin = if (is.null(margin)) NULL else margin[i], nthread = N_THREADS)
  }
  b1 <- xgb.train(params = params, data = mk(!hold), nrounds = MAX_ROUNDS, evals = list(holdout = mk(hold)),
                  early_stopping_rounds = 50, verbose = 0)
  best <- max(10L, as.integer(xgb.attr(b1, "best_iteration")) + 1L)
  boosters <- list(b1); iters <- best
  for (s in seq_len(n_seeds - 1)) {
    params$seed <- seed + s
    boosters[[s + 1]] <- xgb.train(params = params, data = mk(rep(TRUE, nrow(X))), nrounds = ceiling(1.1 * best), verbose = 0)
    iters <- c(iters, ceiling(1.1 * best))
  }
  list(kind = "xgb", boosters = boosters, iters = iters, best_iter = best, features = enc$features,
       cat_levels = enc$cat_levels)
}
tree_rate <- function(tm, d) {
  X <- lgb_matrix(d, tm$features, tm$cat_levels)
  Reduce(`+`, Map(function(b, it) predict(b, X, iterationrange = c(1, it)), tm$boosters, tm$iters)) / length(tm$boosters)
}
mono_of <- function(feats) {
  v <- unname(MONO[feats])
  v[is.na(v)] <- 0
  as.integer(v)
}
tree_imp <- function(tm) {
  imp <- as.data.table(xgb.importance(model = tm$boosters[[1]]))[, .(Feature = as.character(Feature), Gain)]
  imp[order(-Gain)][, rank := .I][]
}

# Fit every component a peril may use. final = TRUE fits only what cfg selects
fit_all <- function(tr, info, seed, final = FALSE, cfg = NULL, tw_w = 0) {
  out <- list(perils = list(), tw = NULL)
  for (k in seq_along(PR)) {
    pr <- PR[k]
    s <- seed + 100 * k
    fp <- list()
    smp <- freq_sample(tr, pr, names(info$unc_rate[[pr]]), ZERO_SAMPLE, s)
    if (!final) fp$freq_base <- fit_freq(tr, pr, FREQ_BASE[[pr]], smp)
    fp$freq <- fit_freq(tr, pr, FREQ_SEL[[pr]], smp)
    variants <- if (final) cfg[[pr]]$sev else c("base", "ext", if (pr %in% RECOVERY_PERILS) c("base_adj", "ext_adj"))
    fp$sev <- lapply(setNames(variants, variants), function(v) {
      feats <- if (startsWith(v, "ext")) c(SEV_BASE[[pr]], SEV_EXT[[pr]]) else SEV_BASE[[pr]]
      fit_sev(tr, pr, feats, adj = endsWith(v, "_adj"))
    })
    if (!final || cfg[[pr]]$fw > 0) {
      cov <- !tr$cover_type %in% names(info$unc_rate[[pr]])
      d <- tr[cov]
      n <- d[[paste0("y_npos_", pr)]]; e <- d[[paste0("effexp_", pr)]]
      enc <- tree_enc(d, unique(c(TREE_CORE, rfeat(FREQ_SEL[[pr]], pr))), n, e)
      fp$freq_xgb <- fit_xgb(d, enc, n, NULL, log(e), "count:poisson", mono_of(enc$features), s + 1,
                             if (final) N_SEEDS_FINAL else 1)
    }
    if (pr %in% SEV_XGB_PERILS && (!final || cfg[[pr]]$sw > 0)) {
      col <- paste0(if (final && endsWith(cfg[[pr]]$sev, "_adj")) "capa_" else "capc_", pr)
      d <- tr[sev_rows(tr, pr, col)]
      n <- d[[paste0("y_npos_", pr)]]; y <- d[[col]] / n
      enc <- tree_enc(d, unique(c(TREE_CORE, rfeat(SEV_EXT[[pr]], pr))), y * n, n)
      fp$sev_xgb <- fit_xgb(d, enc, y, n, NULL, "reg:gamma", rep(0L, length(enc$features)), s + 2,
                            if (final) N_SEEDS_FINAL else 1)
    }
    out$perils[[pr]] <- fp
  }
  if (!final || tw_w > 0) {
    enc <- tree_enc(tr, unique(c(TREE_CORE, "hail_days", "freezing_days")), tr$y_target, tr$exposure)
    out$tw <- fit_xgb(tr, enc, tr$y_target / tr$exposure, tr$exposure, NULL, "reg:tweedie", mono_of(enc$features),
                      seed + 7, if (final) N_SEEDS_FINAL else 1, list(tweedie_variance_power = TWEEDIE_P))
  }
  out
}

# Per-peril scoring parts (all on the ultimate rate scale; trees take the GLM level of the scored rows)
peril_parts <- function(fp, d, info, pr) {
  e <- d$exposure
  ur_all <- info$unc_rate[[pr]]
  unc <- d$cover_type %in% names(ur_all)
  ur <- unname(ur_all[d$cover_type[unc]])
  fr <- function(g) {
    f <- exp(glm_eta(g, d) + glm_trend(g, d))
    f[unc] <- ur
    f
  }
  p <- list(loading = info$loading[[pr]], f_glm = fr(fp$freq))
  if (!is.null(fp$freq_base)) p$f_glm_base <- fr(fp$freq_base)
  if (!is.null(fp$freq_xgb)) {
    t <- tree_rate(fp$freq_xgb, d)
    t <- t * sum(p$f_glm[!unc] * e[!unc]) / sum(t[!unc] * e[!unc])
    t[unc] <- ur
    p$f_xgb <- t
  }
  p$sev <- lapply(fp$sev, function(g) list(eta = glm_eta(g, d), trend = glm_trend(g, d), eta_c = g$eta_c))
  if (!is.null(fp$sev_xgb)) p$s_xgb <- tree_rate(fp$sev_xgb, d)
  p
}
sev_of <- function(p, cfg) {
  sv <- p$sev[[cfg$sev]]
  exp(sv$eta_c + cfg$Z * (sv$eta - sv$eta_c) + sv$trend)
}
freq_of <- function(p, cfg) {
  f <- if (cfg$freq == "base") p$f_glm_base else p$f_glm
  if (cfg$fw > 0) f <- (1 - cfg$fw) * f + cfg$fw * p$f_xgb
  f
}
peril_cost <- function(p, cfg, e) {
  f <- freq_of(p, cfg)
  s <- sev_of(p, cfg)
  if (cfg$sw > 0) {
    t <- p$s_xgb * sum(f * e * s) / sum(f * e * p$s_xgb)
    s <- (1 - cfg$sw) * s + cfg$sw * t
  }
  f * s * p$loading[[if (endsWith(cfg$sev, "_adj")) "adj" else "raw"]] * e
}
tw_cost <- function(tm, d, ref_total) {
  t <- tree_rate(tm, d) * d$exposure
  t * ref_total / sum(t)
}

# Iteration-1 GLM replay (line frequency x severity, 8 exposure bins, no trend / history), as in SAM 3-5 phase 0
legacy_specs <- function(d, feats, w, n_bins = 8, min_share = 0.002) {
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
    sp$levels <- if (sp$type == "bin") intersect(c(levels(cut(0, sp$breaks)), "missing"), lv) else lv
    if (length(lv) >= 2) specs[[f]] <- sp
  }
  specs
}
legacy_glm <- function(d, y, w, specs, family) {
  X <- data.table(y = y)
  for (f in names(specs)) {
    sp <- specs[[f]]
    set(X, j = f, value = relevel(factor(encode_level(d[[f]], sp), levels = sp$levels), ref = sp$base))
  }
  m <- suppressWarnings(glm(as.formula(paste("y ~", paste(names(specs), collapse = " + "))), family = family, data = X,
                            weights = w, control = glm.control(maxit = 100), mustart = rep(weighted.mean(y, w), nrow(X))))
  cf <- coef(m)
  cf[is.na(cf)] <- 0
  cf
}
legacy_pred <- function(tr, va, seed) {
  set.seed(seed)
  s <- tr[sample(.N, min(.N, 250000))]
  specs <- legacy_specs(tr, LEGACY_FEATS, tr$exposure)
  cf <- legacy_glm(s, s$y_nadj_all / s$exposure, s$exposure, specs, quasipoisson(link = "log"))
  sv <- tr[y_npos_all > 0 & y_capcost_all > 0]
  cs <- legacy_glm(sv, sv$y_capcost_all / sv$y_npos_all, sv$y_npos_all, specs, Gamma(link = "log"))
  exp(glm_link(cf, specs, va)) * exp(glm_link(cs, specs, va)) * va$exposure * sum(tr$y_cost) / sum(tr$y_capcost_all)
}

# Metrics -----------------------------------------------------------------------------------------------
tweedie_dev <- function(y, mu, p = TWEEDIE_P) {
  mu <- pmax(mu, 1e-6)
  2 * mean(ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
d2_tweedie <- function(y, pred, exposure) 1 - tweedie_dev(y, pred) / tweedie_dev(y, exposure * sum(y) / sum(exposure))
d2_cal <- function(y, pred, exposure) d2_tweedie(y, pred * sum(y) / sum(pred), exposure)
norm_gini <- function(y, s) {
  g <- function(a, s) {
    a <- a[order(s, decreasing = TRUE)]
    n <- length(a)
    sum(cumsum(a) / sum(a) - seq_len(n) / n) / n
  }
  g(y, s) / g(y, y)
}
# Poisson on reported counts vs rate x effective exposure, calibrated to the fold total (ranking only)
pois_dev <- function(y, mu) 2 * sum(ifelse(y > 0, y * log(y / mu), 0) - (y - mu))
pois_d2 <- function(y, mu, e) {
  mu <- pmax(mu * sum(y) / sum(mu), 1e-9)
  1 - pois_dev(y, mu) / pois_dev(y, e * sum(y) / sum(e))
}
gamma_d2 <- function(y, mu, w) {
  mu <- mu * sum(w * y) / sum(w * mu)
  dv <- function(m) 2 * sum(w * (-log(y / m) + (y - m) / m))
  1 - dv(mu) / dv(rep(sum(w * y) / sum(w), length(y)))
}
keep_rule <- function(new, old) mean(new - old) > KEEP_GAIN && sum(new > old) >= 2

# ==========================================================================================================
# Phase A: data, checks, development, weather
# ==========================================================================================================
log_msg("Phase A: data checks, development by peril, 2025 weather check")
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
ibnr_method <- unique(daily_share[, .(peril, method)])

raw_claims <- read_raw("claims")[line == "motor"]
CL <- as.data.table(read_parquet(file.path(DATA_DIR, "claims_pos.parquet")))[line == "motor"]
CL <- merge(CL, raw_claims[, .(claim_id, policy_id, loss_date, report_date, paid_to_date, incurred_to_date, recoveries)],
            by = "claim_id", all.x = TRUE)
CL <- CL[row_id %in% c(train$row_id)]
add_chk("motor claims (non-repudiated, net > 0, matched to a row)", nrow(CL))
add_chk("claims without a raw-claims match", CL[is.na(loss_date), .N], "none expected")
mm <- train[CL, on = "row_id", .(loss_date = i.loss_date, period_start = x.period_start, period_end = x.period_end,
                                    pol_ok = x.policy_id == i.policy_id)]
add_chk("claims whose loss_date falls outside their row's [period_start, period_end]",
        mm[loss_date < period_start | loss_date > period_end | !pol_ok, .N], "none expected (range join on policy_id)")
add_chk("train rows spanning a calendar year", train[year(period_start) != year(period_end), .N],
        "0 -> weather joins on year(period_start) exactly")
add_chk("test rows spanning a calendar year", test[year(period_start) != year(period_end), .N], "")
add_chk("train rows without weather", train[is.na(hail_days), .N], "")
add_chk("test rows without weather", test[is.na(hail_days), .N], "")
add_chk("distinct compulsory_excess values (train / test)",
        paste(uniqueN(train$compulsory_excess), uniqueN(test$compulsory_excess), sep = " / "), "constant -> excluded")
add_chk("telematics_score blank and opted in / filled and not opted in",
        paste(train[is.na(telematics_score) & telematics_opt_in %in% TRUE, .N],
              train[!is.na(telematics_score) & !telematics_opt_in %in% TRUE, .N], sep = " / "),
        "0 / 0 -> blank = not opted in (informative)")
for (ct in unique(train$cover_type)) {
  add_chk(paste0("claims on cover_type ", ct, " (OD / TPP / BI / theft / GH)"),
          paste(sapply(PR, function(pr) sum(train[cover_type == ct][[paste0("y_npos_", pr)]])), collapse = " / "))
}

# Engineered features --------------------------------------------------------------------------------
weather <- read_raw("weather")
wx_avg <- weather[year %in% 2021:2024, .(wx_avg_hail_days = mean(hail_days), wx_avg_freezing_days = mean(freezing_days)),
                  by = address_id]
first_claim <- CL[, .(policy_id, report_date)]
engineer <- function(d) {
  d <- merge(d, wx_avg, by = "address_id", all.x = TRUE, sort = FALSE)
  d[, `:=`(wx_dev_hail_days = hail_days - wx_avg_hail_days, wx_dev_freezing_days = freezing_days - wx_avg_freezing_days,
           licence_start_age = driver_age - years_licensed,
           ncb_gap = years_licensed - ncb_years,
           nyd_age = fifelse(named_young_driver %in% TRUE,
                             paste0("nyd_", as.character(cut(driver_age, c(-Inf, 30, 45, 60, Inf), labels = c("u30", "30_44", "45_59", "60p")))),
                             "none"),
           value_per_cc = vehicle_value_group / pmax(engine_size_cc / 1000, 0.5),
           vage_x_value = vehicle_age * vehicle_value_group,
           mileage_per_exp = annual_mileage / pmax(exposure, 1 / 12),
           use_parking = paste(vehicle_use, overnight_parking, sep = "|"),
           channel_nb = paste(channel, new_business, sep = "|"),
           telematics_missing = as.integer(is.na(telematics_score)))]
  # Years since the last claim reported before 1 Jan of the row's year; claim-free rows get the visible window
  parts <- lapply(sort(unique(d$policy_year)), function(Y) {
    y0 <- as.Date(sprintf("%d-01-01", Y))
    last <- first_claim[report_date < y0, .(last = max(report_date)), by = policy_id]
    x <- d[policy_year == Y, .(row_id, policy_id, years_with_insurer)]
    x[last, on = "policy_id", last := i.last]
    window <- Y - 2021
    x[, claim_free_years := fifelse(is.na(last), as.numeric(pmin(pmax(years_with_insurer, 0), window)),
                                    as.numeric(y0 - last) / 365)]
    x[, .(row_id, claim_free_years)]
  })
  d <- merge(d, rbindlist(parts), by = "row_id", all.x = TRUE, sort = FALSE)
  setorder(d, row_id)
  d
}
train <- engineer(train)
test <- engineer(test)

# 2025 weather: observed or forecast? A forecast/climatology would sit closer to the address average than real years
wx_vars <- c("hail_days", "freezing_days", "wind_exposure_index", "dry_summer_index", "wildfire_index", "rainfall_mm",
             "mean_temperature_c")
weather_check <- rbindlist(lapply(wx_vars, function(v) {
  w <- weather[, .(address_id, year, x = get(v))]
  w[, s := sum(x[year %in% 2021:2024]), by = address_id]
  w[, ref := fifelse(year %in% 2021:2024, (s - x) / 3, s / 4)]  # leave-one-out 2021-24 address average
  w[, .(variable = v, mean = mean(x), sd = sd(x), sd_dev_from_addr_avg = sd(x - ref), cor_with_addr_avg = cor(x, ref)),
    by = year]
}))
wc <- weather_check[, .(ratio_2025 = sd_dev_from_addr_avg[year == 2025] / mean(sd_dev_from_addr_avg[year < 2025])), by = variable]
weather_check <- merge(weather_check, wc, by = "variable")
WEATHER_2025_FORECAST_LIKE <- wc[variable %in% c("hail_days", "freezing_days"), any(ratio_2025 < 0.8)]
add_chk("2025 hail/freezing deviation spread vs 2021-24 (ratio)",
        paste(round(wc[variable %in% c("hail_days", "freezing_days")]$ratio_2025, 2), collapse = " / "),
        if (WEATHER_2025_FORECAST_LIKE) "shrunk -> forecast-like" else "~1 -> behaves like observed weather")
rm(weather, raw_claims); gc(verbose = FALSE)

# Development by peril: report-lag share, open claims, open vs closed severity, recovery ratio ------------
add_shares(train, ROW_SHARE)
dev_tab <- rbindlist(lapply(PR, function(pr) {
  a <- data.table(policy_year = train$policy_year, n = train[[paste0("y_npos_", pr)]], s = train[[paste0("sh_", pr)]],
                  cst = train[[paste0("y_cost_", pr)]])[, .(reported_claims = sum(n), developed_claims = sum(n / s),
                                                            reported_cost = sum(cst), developed_cost = sum(cst / s)), by = policy_year]
  b <- CL[peril == pr, .(open_share = mean(status == "open"),
                         sev_open_vs_closed = mean(net[status == "open"]) / mean(net[status == "closed"]),
                         paid_to_incurred_open = sum(paid_to_date[status == "open"]) / sum(incurred_to_date[status == "open"]),
                         recovery_ratio_closed = sum(recoveries[status == "closed"]) / sum(incurred_to_date[status == "closed"]),
                         median_report_lag = as.numeric(median(report_date - loss_date))), by = policy_year]
  merge(a, b, by = "policy_year")[, `:=`(peril = pr, ibnr_count_factor = developed_claims / reported_claims,
                                         cost_understatement = 1 - reported_cost / developed_cost)]
}))
setcolorder(dev_tab, c("peril", "policy_year"))
dev_tab <- merge(dev_tab, ibnr_method, by = "peril")[order(peril, policy_year)]

# ==========================================================================================================
# Phase B: rolling folds
# ==========================================================================================================
log_msg("Phase B: rolling folds")
folds <- list()
for (vy in VALID_YEARS) {
  tr <- train[policy_year < vy]
  va <- train[policy_year == vy]
  info <- prep_fold(tr, va, SEED + vy)
  set(va, j = "developed", value = Reduce(`+`, lapply(PR, function(pr) va[[paste0("y_cost_", pr)]] / va[[paste0("sh_", pr)]])))
  smp <- lapply(setNames(seq_along(PR), PR), function(k) {
    freq_sample(tr, PR[k], names(info$unc_rate[[PR[k]]]), ZERO_SAMPLE_LADDER, SEED + vy + 10 * k)
  })
  folds[[as.character(vy)]] <- list(tr = tr, va = va, info = info, smp = smp)
}
rm(tr, va); gc(verbose = FALSE)

# ==========================================================================================================
# Phase C: frequency feature ladder per peril (GLM, calibrated Poisson D2 on covered validation rows)
# ==========================================================================================================
log_msg("Phase C: frequency feature ladder")
eval_freq <- function(pr, feats) {
  sapply(folds, function(F) {
    g <- fit_freq(F$tr, pr, feats, F$smp[[pr]])
    cov <- !F$va$cover_type %in% names(F$info$unc_rate[[pr]])
    v <- F$va[cov]
    pois_d2(v[[paste0("y_npos_", pr)]], exp(glm_eta(g, v) + glm_trend(g, v)) * v[[paste0("effexp_", pr)]],
            v[[paste0("effexp_", pr)]])
  })
}
FREQ_SEL <- list(); ladder <- list()
for (pr in PR) {
  feats <- FREQ_BASE[[pr]]
  cur <- eval_freq(pr, feats)
  ladder[[paste(pr, "base")]] <- data.table(peril = pr, step = 0L, group = "base", option = "", d2_2022 = cur[1],
                                            d2_2023 = cur[2], d2_2024 = cur[3], mean_gain = NA_real_, wins = NA_integer_,
                                            kept = TRUE, n_features = length(feats))
  for (gi in seq_along(GROUPS)) {
    opts <- GROUPS[[gi]]
    onames <- if (is.null(names(opts))) rep("", length(opts)) else names(opts)
    res <- lapply(opts, function(o) if (all(o %in% feats)) NULL else eval_freq(pr, union(feats, o)))
    gain <- sapply(res, function(s) if (is.null(s)) -Inf else mean(s - cur))
    best <- which.max(gain)
    kept <- !is.null(res[[best]]) && keep_rule(res[[best]], cur)
    for (j in seq_along(opts)) {
      if (is.null(res[[j]])) next
      ladder[[paste(pr, gi, j)]] <- data.table(peril = pr, step = gi, group = names(GROUPS)[gi], option = onames[j],
                                               d2_2022 = res[[j]][1], d2_2023 = res[[j]][2], d2_2024 = res[[j]][3],
                                               mean_gain = gain[j], wins = sum(res[[j]] > cur),
                                               kept = kept && j == best, n_features = length(union(feats, opts[[j]])))
    }
    if (kept) {
      feats <- union(feats, opts[[best]])
      cur <- res[[best]]
    }
  }
  FREQ_SEL[[pr]] <- feats
  log_msg("Ladder ", pr, ": ", length(feats), " features, Poisson D2 ", paste(round(cur, 4), collapse = " / "))
}
ladder <- rbindlist(ladder)

# ==========================================================================================================
# Phase D: candidate fits per fold
# ==========================================================================================================
log_msg("Phase D: candidate fits per fold")
P <- list(); VA <- list(); overfit <- list(); fold_imp <- list(); sev_info <- list()
for (k in names(folds)) {
  F <- folds[[k]]
  vy <- as.integer(k)
  t1 <- Sys.time()
  fits <- fit_all(F$tr, F$info, SEED + vy)
  P[[k]] <- lapply(setNames(PR, PR), function(pr) peril_parts(fits$perils[[pr]], F$va, F$info, pr))
  glm_total <- Reduce(`+`, lapply(PR, function(pr) {
    peril_cost(P[[k]][[pr]], list(freq = "sel", sev = "base", Z = 1, fw = 0, sw = 0), F$va$exposure)
  }))
  VA[[k]] <- list(d = F$va[, c("row_id", "policy_year", "exposure", "y_cost", "developed",
                               paste0(c("y_cost_", "y_npos_", "effexp_", "capc_"), rep(PR, each = 4))), with = FALSE],
                  tw = tw_cost(fits$tw, F$va, sum(glm_total)), legacy = legacy_pred(F$tr, F$va, SEED + vy))
  # In-sample vs out-of-sample frequency fit on a 200k training sample (overfitting check)
  set.seed(SEED + vy)
  trs <- F$tr[sample(.N, min(.N, 200000))]
  for (pr in PR) {
    fp <- fits$perils[[pr]]
    pt <- peril_parts(fp, trs, F$info, pr)
    cov_t <- !trs$cover_type %in% names(F$info$unc_rate[[pr]])
    cov_v <- !F$va$cover_type %in% names(F$info$unc_rate[[pr]])
    pv <- P[[k]][[pr]]
    nt <- trs[[paste0("y_npos_", pr)]]; et <- trs[[paste0("effexp_", pr)]]
    nv <- F$va[[paste0("y_npos_", pr)]]; ev <- F$va[[paste0("effexp_", pr)]]
    for (m in c("f_glm", "f_xgb")) {
      overfit[[paste(k, pr, m)]] <- data.table(valid_year = vy, peril = pr, model = m,
                                               pois_d2_train = pois_d2(nt[cov_t], (pt[[m]] * et)[cov_t], et[cov_t]),
                                               pois_d2_valid = pois_d2(nv[cov_v], (pv[[m]] * ev)[cov_v], ev[cov_v]))
    }
    fold_imp[[paste(k, pr)]] <- tree_imp(fp$freq_xgb)[rank <= 15][, `:=`(valid_year = vy, peril = pr)]
    sev_info[[paste(k, pr)]] <- rbindlist(lapply(names(fp$sev), function(v) data.table(
      valid_year = vy, peril = pr, variant = v, claims = fp$sev[[v]]$claims, gated = fp$sev[[v]]$gated,
      converged = fp$sev[[v]]$converged, sev_trend_fitted = exp(fp$sev[[v]]$year_raw) - 1)))
    sev_info[[paste(k, pr, "freq")]] <- data.table(valid_year = vy, peril = pr, variant = "freq_sel", claims = NA_real_,
                                                   gated = NA, converged = fp$freq$converged,
                                                   sev_trend_fitted = exp(fp$freq$year_raw) - 1)
  }
  rm(fits, trs); gc(verbose = FALSE)
  log_msg("Fold ", vy, " fitted in ", round(as.numeric(difftime(Sys.time(), t1, units = "mins")), 1), " min")
}
overfit <- rbindlist(overfit)[, gap := pois_d2_train - pois_d2_valid]
fold_imp <- rbindlist(fold_imp)
sev_info <- rbindlist(sev_info)

# ==========================================================================================================
# Phase E: sequential decisions per peril and the before/after stage table
# ==========================================================================================================
log_msg("Phase E: decisions and stage table")
peril_d2 <- function(pr, cfg, years = VALID_YEARS) {
  sapply(as.character(years), function(k) {
    d <- VA[[k]]$d
    d2_tweedie(d[[paste0("y_cost_", pr)]], peril_cost(P[[k]][[pr]], cfg, d$exposure), d$exposure)
  })
}
sev_d2 <- function(pr, cfg) {
  sapply(names(VA), function(k) {
    d <- VA[[k]]$d
    ok <- d[[paste0("y_npos_", pr)]] > 0 & d[[paste0("capc_", pr)]] > 0
    n <- d[[paste0("y_npos_", pr)]][ok]
    gamma_d2(d[[paste0("capc_", pr)]][ok] / n, sev_of(P[[k]][[pr]], cfg)[ok], n)
  })
}
freq_d2 <- function(pr, cfg) {
  sapply(names(VA), function(k) {
    d <- VA[[k]]$d
    e <- d[[paste0("effexp_", pr)]]
    pois_d2(d[[paste0("y_npos_", pr)]], freq_of(P[[k]][[pr]], cfg) * e, e)
  })
}
CFG <- lapply(setNames(PR, PR), function(pr) list(freq = "base", sev = "base", Z = 1, fw = 0, sw = 0))
stages <- list(list(stage = "S0 base GLM (base features, base severity)", cfg = CFG, tw = 0))
decisions <- list()
note <- function(pr, what, choice, detail) {
  decisions[[length(decisions) + 1]] <<- data.table(peril = pr, decision = what, choice = as.character(choice), detail = detail)
}

for (pr in PR) CFG[[pr]]$freq <- "sel"
stages[[length(stages) + 1]] <- list(stage = "S1 + frequency feature ladder", cfg = CFG, tw = 0)

for (pr in PR) {
  b <- sev_d2(pr, CFG[[pr]]); x <- sev_d2(pr, modifyList(CFG[[pr]], list(sev = "ext")))
  keep <- keep_rule(x, b)
  if (keep) CFG[[pr]]$sev <- "ext"
  note(pr, "severity features", if (keep) "extended" else "base",
       sprintf("Gamma D2 base %s vs extended %s", paste(round(b, 4), collapse = "/"), paste(round(x, 4), collapse = "/")))
}
stages[[length(stages) + 1]] <- list(stage = "S2 + severity feature choice", cfg = CFG, tw = 0)

for (pr in PR) {
  sc <- sapply(SHRINK_GRID, function(z) mean(sev_d2(pr, modifyList(CFG[[pr]], list(Z = z)))))
  CFG[[pr]]$Z <- SHRINK_GRID[which.max(sc)]
  note(pr, "severity credibility Z (0 = peril average, 1 = full GLM)", CFG[[pr]]$Z,
       paste(sprintf("Z=%.2f: %.4f", SHRINK_GRID, sc), collapse = "; "))
}
stages[[length(stages) + 1]] <- list(stage = "S3 + severity credibility shrinkage", cfg = CFG, tw = 0)

for (pr in RECOVERY_PERILS) {
  alt <- modifyList(CFG[[pr]], list(sev = paste0(CFG[[pr]]$sev, "_adj")))
  b <- peril_d2(pr, CFG[[pr]], 2022:2023); x <- peril_d2(pr, alt, 2022:2023)
  keep <- mean(x - b) > 0 && all(x >= b)
  if (keep) CFG[[pr]] <- alt
  note(pr, "deduct expected recoveries from open claims", keep,
       sprintf("peril Tweedie D2 on mature folds 2022/2023: raw %s vs adjusted %s", paste(round(b, 4), collapse = "/"),
               paste(round(x, 4), collapse = "/")))
}
stages[[length(stages) + 1]] <- list(stage = "S4 + open-claim recovery adjustment", cfg = CFG, tw = 0)

for (pr in PR) {
  b <- peril_d2(pr, CFG[[pr]])
  sc <- lapply(MIX_GRID[-1], function(w) peril_d2(pr, modifyList(CFG[[pr]], list(fw = w))))
  g <- sapply(sc, function(s) mean(s - b))
  j <- which.max(g)
  if (keep_rule(sc[[j]], b)) CFG[[pr]]$fw <- MIX_GRID[-1][j]
  note(pr, "XGBoost frequency weight", CFG[[pr]]$fw,
       sprintf("peril Tweedie D2 GLM %s; w=0.5 %s; w=1 %s", paste(round(b, 4), collapse = "/"),
               paste(round(sc[[1]], 4), collapse = "/"), paste(round(sc[[2]], 4), collapse = "/")))
}
stages[[length(stages) + 1]] <- list(stage = "S5 + XGBoost frequency (per peril)", cfg = CFG, tw = 0)

for (pr in SEV_XGB_PERILS) {
  b <- peril_d2(pr, CFG[[pr]])
  sc <- lapply(MIX_GRID[-1], function(w) peril_d2(pr, modifyList(CFG[[pr]], list(sw = w))))
  g <- sapply(sc, function(s) mean(s - b))
  j <- which.max(g)
  if (keep_rule(sc[[j]], b)) CFG[[pr]]$sw <- MIX_GRID[-1][j]
  note(pr, "XGBoost severity weight", CFG[[pr]]$sw,
       sprintf("peril Tweedie D2 GLM sev %s; w=0.5 %s; w=1 %s", paste(round(b, 4), collapse = "/"),
               paste(round(sc[[1]], 4), collapse = "/"), paste(round(sc[[2]], 4), collapse = "/")))
}
stages[[length(stages) + 1]] <- list(stage = "S6 + XGBoost severity (own_damage, third_party_prop)", cfg = CFG, tw = 0)

total_of <- function(k, cfg, tw = 0) {
  d <- VA[[k]]$d
  tot <- Reduce(`+`, lapply(PR, function(pr) peril_cost(P[[k]][[pr]], cfg[[pr]], d$exposure)))
  if (tw > 0) tot <- (1 - tw) * tot + tw * VA[[k]]$tw * sum(tot) / sum(VA[[k]]$tw)
  tot
}
tw_sc <- sapply(TW_GRID, function(a) mean(sapply(names(VA), function(k) {
  d <- VA[[k]]$d
  d2_cal(d$y_cost, total_of(k, CFG, a), d$exposure)
})))
TW_W <- TW_GRID[which.max(tw_sc)]
note("all", "blend weight on the line-level Tweedie XGBoost", TW_W,
     paste(sprintf("a=%.1f: %.4f", TW_GRID, tw_sc), collapse = "; "))
stages[[length(stages) + 1]] <- list(stage = "S7 + line Tweedie blend", cfg = CFG, tw = TW_W)
decisions <- rbindlist(decisions)

total_metrics <- function(pred_fun, label) {
  rbindlist(lapply(names(VA), function(k) {
    d <- VA[[k]]$d
    p <- pred_fun(k)
    data.table(model = label, valid_year = as.integer(k), d2 = d2_tweedie(d$y_cost, p, d$exposure),
               d2_cal = d2_cal(d$y_cost, p, d$exposure), gini = norm_gini(d$y_cost, p),
               ae_developed = sum(p) / sum(d$developed), ae_reported = sum(p) / sum(d$y_cost))
  }))
}
stage_tab <- rbindlist(lapply(stages, function(s) {
  tm <- total_metrics(function(k) total_of(k, s$cfg, s$tw), s$stage)
  pm <- sapply(PR, function(pr) mean(peril_d2(pr, s$cfg[[pr]])))
  w <- dcast(tm, model ~ valid_year, value.var = "d2")
  setnames(w, c("stage", paste0("d2_", names(w)[-1])))
  cbind(w, data.table(d2_mean = mean(tm$d2), d2_cal_mean = mean(tm$d2_cal), gini_mean = mean(tm$gini)),
        as.data.table(as.list(setNames(pm, paste0("peril_d2_", PR)))))
}))

# Peril-by-peril metrics of the final configuration, and the single-model comparison
peril_metrics <- rbindlist(lapply(PR, function(pr) {
  rbindlist(lapply(names(VA), function(k) {
    d <- VA[[k]]$d
    pc <- peril_cost(P[[k]][[pr]], CFG[[pr]], d$exposure)
    data.table(peril = pr, valid_year = as.integer(k), claims = sum(d[[paste0("y_npos_", pr)]]),
               tweedie_d2 = d2_tweedie(d[[paste0("y_cost_", pr)]], pc, d$exposure),
               gini = norm_gini(d[[paste0("y_cost_", pr)]], pc),
               ae_developed = sum(pc) / sum(d[[paste0("y_cost_", pr)]] / pmax(d[[paste0("effexp_", pr)]] / d$exposure, 1e-9)))
  }))[, `:=`(poisson_d2 = freq_d2(pr, CFG[[pr]]), gamma_d2 = sev_d2(pr, CFG[[pr]]))]
}))
comparison <- rbind(
  total_metrics(function(k) total_of(k, CFG, TW_W), "MOTOR 1 per-peril (final)"),
  total_metrics(function(k) total_of(k, CFG, 0), "MOTOR 1 per-peril, no line blend"),
  total_metrics(function(k) VA[[k]]$tw, "single line-level Tweedie XGBoost (same folds/features)"),
  total_metrics(function(k) VA[[k]]$legacy, "iteration-1 GLM replay"),
  data.table(model = "SAM 4 blend (reported)", valid_year = VALID_YEARS, d2 = unname(SAM4_D2), d2_cal = NA_real_,
             gini = NA_real_, ae_developed = NA_real_, ae_reported = NA_real_))
comparison_w <- dcast(comparison, model ~ valid_year, value.var = "d2")
setnames(comparison_w, c("model", paste0("d2_", names(comparison_w)[-1])))
comparison_w[, d2_mean := rowMeans(.SD), .SDcols = patterns("^d2_20")]
setorder(comparison_w, -d2_mean)

fold_pred <- rbindlist(lapply(names(VA), function(k) {
  d <- VA[[k]]$d
  out <- d[, .(valid_year = as.integer(k), row_id, exposure, actual = y_cost, developed)]
  for (pr in PR) set(out, j = paste0("pred_", pr), value = peril_cost(P[[k]][[pr]], CFG[[pr]], d$exposure))
  out[, `:=`(pred_final = total_of(k, CFG, TW_W), pred_line_tweedie = VA[[k]]$tw, pred_legacy_glm = VA[[k]]$legacy)]
}))

# ==========================================================================================================
# Phase F: final fit on 2021-24, motor-only submission, saved model, replication, card
# ==========================================================================================================
log_msg("Phase F: final fit on 2021-24")
rm(folds, P); gc(verbose = FALSE)
tr <- copy(train)
te <- copy(test)
add_shares(te, ROW_SHARE)
info <- prep_fold(tr, te, SEED + 2025)
fits <- fit_all(tr, info, SEED + 2025, final = TRUE, cfg = CFG, tw_w = TW_W)
art <- list(model = "motor01_peril", info = info, perils = fits$perils, tw = fits$tw, cfg = CFG, tw_w = TW_W,
            row_share = ROW_SHARE)
score_art <- function(art, d) {
  d <- copy(d)
  add_shares(d, art$row_share)
  add_te(d, art$info)
  costs <- sapply(PR, function(pr) peril_cost(peril_parts(art$perils[[pr]], d, art$info, pr), art$cfg[[pr]], d$exposure))
  tot <- rowSums(costs)
  if (art$tw_w > 0) tot <- (1 - art$tw_w) * tot + art$tw_w * tw_cost(art$tw, d, sum(tot))
  list(total = pmax(tot, 0), perils = costs)
}
sc <- score_art(art, test)
pred <- sc$total
sam4 <- fread(file.path("models", "sam_iteration_04", "test_prediction_summary.csv"))[line == "motor" & model == "blend"]
level_scale <- sam4$predicted_total / sum(pred)
final_imp <- rbindlist(lapply(PR, function(pr) {
  if (is.null(fits$perils[[pr]]$freq_xgb)) return(NULL)
  tree_imp(fits$perils[[pr]]$freq_xgb)[rank <= 20][, peril := pr]
}))
final_glm <- rbindlist(lapply(PR, function(pr) {
  fp <- fits$perils[[pr]]
  data.table(peril = pr, freq_features = paste(names(fp$freq$specs), collapse = ", "),
             freq_trend_fitted = exp(fp$freq$year_raw) - 1, freq_trend_used = exp(fp$freq$year_coef) - 1,
             imm_2024_rel = exp(fp$freq$imm_coef),
             sev_variant = CFG[[pr]]$sev, sev_features = paste(names(fp$sev[[1]]$specs), collapse = ", "),
             sev_claims = fp$sev[[1]]$claims, sev_gated = fp$sev[[1]]$gated,
             sev_trend_used = exp(fp$sev[[1]]$year_coef) - 1, Z = CFG[[pr]]$Z, xgb_freq_w = CFG[[pr]]$fw,
             xgb_sev_w = CFG[[pr]]$sw, cap = info$caps[peril == pr, cap],
             loading = info$loading[[pr]][[if (endsWith(CFG[[pr]]$sev, "_adj")) "adj" else "raw"]],
             uncovered_cover = paste(names(info$unc_rate[[pr]]), collapse = ", "))
}))
test_summary <- data.table(peril = c(PR, "total"), predicted_total = c(colSums(sc$perils), sum(pred)))[
  , cost_per_exposure_year := predicted_total / sum(test$exposure)]
rm(fits); gc(verbose = FALSE)

unlink(FITTED_DIR, recursive = TRUE)
dir.create(FITTED_DIR, recursive = TRUE)
pack_art <- function(a, f) {
  for (pr in PR) for (m in c("freq_xgb", "sev_xgb")) if (!is.null(a$perils[[pr]][[m]])) a$perils[[pr]][[m]] <- f(a$perils[[pr]][[m]])
  if (!is.null(a$tw)) a$tw <- f(a$tw)
  a
}
saveRDS(pack_art(art, sam02_pack), file.path(FITTED_DIR, "motor01_peril.rds"))
sub <- data.table(row_id = test$row_id, prediction = pred)
sub_sam <- data.table(row_id = test$row_id, prediction = pred * level_scale)
sample_sub <- read_raw("sample_submission")
motor_ids <- sample_sub$row_id[sample_sub$row_id %in% test$row_id]
stopifnot(nrow(sub) == nrow(test), setequal(sub$row_id, motor_ids), !anyDuplicated(sub$row_id),
          !anyNA(sub$prediction), all(sub$prediction >= 0))
f_own <- out_file("submission", paste0("motor_only_", RUN_ID, if (QUICK) "_quick", ".csv"))
f_sam <- out_file("submission", paste0("motor_only_", RUN_ID, if (QUICK) "_quick", "_samlevel.csv"))
fwrite(sub, f_own, scipen = 50)
fwrite(sub_sam, f_sam, scipen = 50)
re <- score_art(pack_art(readRDS(file.path(FITTED_DIR, "motor01_peril.rds")), sam02_unpack), test)$total
replication_diff <- max(abs(re - pred))
log_msg("Replication max abs diff ", signif(replication_diff, 3))

# Flags: gains that could be leakage, overfitting to the folds or confounding ------------------------------
flags <- character()
sel_all <- unique(unlist(FREQ_SEL))
if (any(c("te_mm", "te_ru") %in% sel_all)) flags <- c(flags, "Target-encoded make_model / region x urban kept: computed out-of-fold on training years only, but encodings carry the most overfitting risk; check its gain is stable across folds in the ladder table.")
if ("claim_free_years" %in% sel_all || "hist_pol_n" %in% sel_all) flags <- c(flags, "Claim-history features kept: their visible window grows from 0 years (2021) to 4 (2025), so part of their effect is confounded with calendar time and the 2025 distribution is outside the training range.")
if ("mileage_per_exp" %in% sel_all) flags <- c(flags, "mileage_per_exp kept: it is annual_mileage / exposure, so it re-introduces exposure as a feature next to the offset; treat as suspect (short rows = mid-term changes / cancellations).")
if (any(grepl("^wx_|hail_days|freezing_days", sel_all))) flags <- c(flags, sprintf("Weather kept for some perils; 2025 values %s.", if (WEATHER_2025_FORECAST_LIKE) "look forecast-like (shrunk towards the address average), so their 2025 effect carries extra uncertainty" else "vary like observed years, but nothing in the data documents whether they are observed or forecast"))
big_gap <- overfit[gap > 0.02]
if (nrow(big_gap)) flags <- c(flags, sprintf("Train-validation Poisson D2 gap > 0.02 for: %s.", paste(unique(paste(big_gap$peril, big_gap$model)), collapse = ", ")))
flags <- c(flags, "Decisions (ladder, severity, mixing weights, line blend) were chosen on the same three folds they are reported on, so the stage-table gains are optimistic; changes below about 0.001 D2 are within fold noise.",
           "2024 actuals are immature (bodily_injury about 80% open), so the 2024 fold rewards under-prediction; level is judged on developed A/E and against SAM 4, not on raw 2024 D2.")

# Model card ------------------------------------------------------------------------------------------
fwrite(rbindlist(checks), file.path(ITER_DIR, "data_checks.csv"))
fwrite(dev_tab, file.path(ITER_DIR, "development_by_peril.csv"))
fwrite(weather_check, file.path(ITER_DIR, "weather_2025_check.csv"))
fwrite(ladder, file.path(ITER_DIR, "freq_ladder.csv"))
fwrite(decisions, file.path(ITER_DIR, "decisions.csv"))
fwrite(stage_tab, file.path(ITER_DIR, "stage_table.csv"))
fwrite(peril_metrics, file.path(ITER_DIR, "peril_metrics.csv"))
fwrite(comparison, file.path(ITER_DIR, "comparison.csv"))
fwrite(overfit, file.path(ITER_DIR, "overfit_check.csv"))
fwrite(sev_info, file.path(ITER_DIR, "glm_fit_info.csv"))
fwrite(fold_imp, file.path(ITER_DIR, "xgb_freq_importance_folds.csv"))
fwrite(final_imp, file.path(ITER_DIR, "xgb_freq_importance_final.csv"))
fwrite(final_glm, file.path(ITER_DIR, "final_config.csv"))
fwrite(test_summary, file.path(ITER_DIR, "test_prediction_summary.csv"))
fwrite(EXCLUDED, file.path(ITER_DIR, "leakage_exclusions.csv"))
fwrite(data.table(peril = PR, features = sapply(FREQ_SEL, paste, collapse = ", ")), file.path(ITER_DIR, "features_used.csv"))
write_parquet(fold_pred, file.path(ITER_DIR, "fold_predictions.parquet"))
summary_row <- data.table(run_id = RUN_ID, quick = QUICK, d2_2022 = comparison[model == "MOTOR 1 per-peril (final)" & valid_year == 2022, d2],
                          d2_2023 = comparison[model == "MOTOR 1 per-peril (final)" & valid_year == 2023, d2],
                          d2_2024 = comparison[model == "MOTOR 1 per-peril (final)" & valid_year == 2024, d2],
                          burn_2025_own = sum(pred) / sum(test$exposure), burn_2025_sam4 = sam4$predicted_burn_cost,
                          level_scale = level_scale, replication_max_diff = replication_diff,
                          minutes = round(as.numeric(difftime(Sys.time(), T0, units = "mins")), 1))
fwrite(summary_row, file.path(ITER_DIR, "summary.csv"))

exposure_audit <- data.table(
  component = c("Frequency GLM", "Frequency GLM zero-row sampling", "XGBoost frequency", "Severity GLM / XGBoost",
                "Line Tweedie XGBoost", "Target encodings", "D2 baseline", "Normalised Gini", "Legacy replay sample"),
  handling = c("Poisson on claim counts with offset log(exposure x reported share)",
               "all claim rows + a random share r of zero rows, weighted 1/r so exposure totals are preserved",
               "count:poisson on counts with base_margin = log(exposure x reported share)",
               "claim-count weights (cost per claim; exposure is not relevant)",
               "label = capped developed cost / exposure, weight = exposure",
               "credibility-weighted claims / effective exposure",
               "constant cost per exposure-year x row exposure",
               "rows ranked and counted equally regardless of exposure - FLAG: secondary metric only",
               "250k rows sampled uniformly (not exposure-weighted), then exposure-weighted fit - FLAG: inherited from SAM phase 0"))

pct <- function(x) sprintf("%.1f%%", 100 * x)
card <- c(
  "# MOTOR 1 - motor-only per-peril frequency x severity", "",
  sprintf("**Run id** `%s` | **Quick mode** %s | **Runtime** %.0f min | **Submission (own level)** `%s` | **Submission (SAM 4 level)** `%s`",
          RUN_ID, QUICK, summary_row$minutes, basename(f_own), basename(f_sam)), "",
  "## Metrics used",
  "- **Tweedie D2 (p = 1.5) on row cost** - the competition metric; zero rows count, so it judges frequency, severity and level together. Reported raw (as scored) and calibrated (prediction rescaled to the actual total, ranking only).",
  "- **Poisson D2 on claim counts** (expected reported count = rate x exposure x reported share, calibrated) - the proper score for a log-link count model with an exposure offset.",
  "- **Gamma D2 on cost per claim** (calibrated, claim-count weighted) - scale-free severity error, matches the Gamma GLM.",
  "- **Normalised Gini** - ranking only, secondary. RMSE on log cost is not used: it drops zero rows and needs a retransformation correction.",
  sprintf("- Keep rule for every change: mean gain > %.4f and better in at least 2 of the 3 folds (2022, 2023, 2024; each fitted on earlier years only).", KEEP_GAIN), "",
  "## Headline", "",
  md_table(comparison_w, 4),
  "SAM 4 figures are its reported motor blend D2 on the same fold years (not re-run).", "",
  "## Stage-by-stage before / after (total row cost and by peril)", "",
  "`d2_<year>` = raw Tweedie D2 on total motor row cost; `peril_d2_<peril>` = mean raw Tweedie D2 of that peril's cost over the folds.", "",
  md_table(stage_tab, 4),
  "## Decisions", "", md_table(decisions, 4),
  "## Peril-by-peril performance (final configuration)", "", md_table(peril_metrics, 4),
  "## Final configuration per peril (fit on 2021-24)", "", md_table(final_glm, 3),
  "## Frequency feature ladder (GLM, calibrated Poisson D2 on covered validation rows)", "",
  "Groups are added in order; `kept` marks the option that passed the keep rule and was carried forward.", "",
  md_table(ladder, 4),
  "## Claims development / IBNR by peril", "",
  "`ibnr_count_factor` = developed / reported claims from the 3b report-lag pattern (method column); `cost_understatement` = share of developed cost not yet reported; `sev_open_vs_closed` = mean open / mean closed net cost.", "",
  md_table(dev_tab, 3),
  "Treatment: frequency uses exposure x reported share (offset), so late-reported claims are allowed for per peril and per row; long-tail perils (", paste(LONG_TAIL, collapse = ", "), sprintf(") fit severity on policy years before %d and get a %d frequency dummy; open own_damage / theft claims can have expected recoveries deducted (decision above); other open case estimates are taken as adequate (one valuation date, so case development cannot be estimated).", LONG_TAIL_SEV_BEFORE, IMMATURE_YEAR), "",
  "## Weather", "",
  "Join rule: address_id + calendar year of period_start. No row spans a calendar year (data checks), so the rule is exact. `ratio_2025` = spread of 2025 deviations from the address average relative to 2021-24; well below 1 would indicate a forecast / climatology.", "",
  md_table(weather_check[variable %in% c("hail_days", "freezing_days")], 3),
  sprintf("Conclusion: 2025 weather %s. The ladder also tests the 2021-24 address average, which does not depend on 2025 values.",
          if (WEATHER_2025_FORECAST_LIKE) "looks forecast-like" else "behaves like observed weather; provenance is not documented"), "",
  "## Leakage and exclusions", "", md_table(EXCLUDED),
  "Kept with justification: ncb_years and prior_claims_5y (declared / known at quote); hist_* and claim_free_years use only claims reported before 1 January of the row's year (same cut-off as 2025 quotes); telematics_score is used as flag + value (blank = not opted in, never imputed; NA becomes its own spline indicator / tree missing branch).", "",
  "## Exposure handling", "", md_table(exposure_audit),
  "## Overfitting check (Poisson D2 train sample vs validation)", "", md_table(overfit, 4),
  "## Flags", "", paste0("- ", flags), "",
  "## 2025 test predictions", "", md_table(test_summary, 2),
  sprintf("Own level %.2f vs SAM 4 %.2f per exposure-year (scale %.4f). The public-score test (#10) favoured the SAM level, so `%s` is the recommended file; `%s` keeps this model's own level.",
          summary_row$burn_2025_own, sam4$predicted_burn_cost, level_scale, basename(f_sam), basename(f_own)), "",
  sprintf("Replication: saved model reloaded from `fitted/motor01_peril.rds` and re-scored, max abs diff %s.", signif(replication_diff, 3)), "")
writeLines(card, file.path(ITER_DIR, "model_card.md"))
log_msg("Done in ", summary_row$minutes, " min; card at ", file.path(ITER_DIR, "model_card.md"))
