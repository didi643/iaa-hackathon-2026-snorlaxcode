# 4_models_itermotor02.R ---------------------------------------------------------
# MOTOR 2: MOTOR 1 per-peril frequency x severity with
#   - bodily_injury frequency pooled with third_party_prop (BI rate = TPP GLM rate x short BI relativity GLM)
#   - per-peril level choices judged on IBNR-developed actuals: frequency trend on/off, severity trend 1 / 0.5 / 0,
#     robust large-loss loading (single extreme claims limited to LOAD_MULT x cap), BI severity on mature or all years
#   - a second XGBoost frequency configuration and a final blend with the line Tweedie and the iteration-1 GLM replay
# Frequency features per peril are MOTOR 1's ladder result (models/motor_iteration_01/features_used.csv); helper
# functions and feature lists are taken from R/4_models_itermotor01.R without re-running it.
# Outputs: models/motor_iteration_02[_quick]/, output/submission/motor2_only_<run id>[_samlevel].csv
# Env vars: MOTOR02_QUICK=1 (sampled policies, short boosting)

source("R/0_setup.R")
source("R/model_io.R")
suppressPackageStartupMessages({
  library(xgboost)
  library(splines)
})
T0 <- Sys.time()
QUICK <- Sys.getenv("MOTOR02_QUICK") == "1"

# Import MOTOR 1 functions and its header constants (not its run-specific paths)
M1_SKIP <- c("QUICK", "RUN_ID", "ITERATION_LABEL", "ITER_DIR", "FITTED_DIR", "T0", "checks")
in_header <- TRUE
for (e in parse("R/4_models_itermotor01.R", keep.source = FALSE)) {
  if (is.call(e) && identical(e[[1]], as.name("log_msg"))) in_header <- FALSE
  if (!is.call(e) || !identical(e[[1]], as.name("<-")) || !is.name(e[[2]])) next
  nm <- as.character(e[[2]])
  is_fun <- is.call(e[[3]]) && identical(e[[3]][[1]], as.name("function"))
  if (!nm %in% M1_SKIP && (is_fun || in_header)) eval(e, globalenv())
}

RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITERATION_LABEL <- if (QUICK) "motor_iteration_02_quick" else "motor_iteration_02"
ITER_DIR <- file.path("models", ITERATION_LABEL)
FITTED_DIR <- file.path(ITER_DIR, "fitted")
LOAD_MULT <- 5
BI <- "bodily_injury"
BI_POOL_FEATS <- c("driver_age", "years_licensed", "named_young_driver", "vehicle_use", "annual_mileage", "region",
                   "urban_density", "vehicle_value_group")
XGB_CFGS <- list(x1 = XGB_PARAMS,
                 x2 = list(learning_rate = 0.03, max_depth = 6, min_child_weight = 50, subsample = 0.8,
                           colsample_bytree = 0.5, reg_lambda = 10))
M1_CFG <- list(own_damage = list(Z = 1, fw = 0.5), third_party_prop = list(Z = 0.5, fw = 0),
               bodily_injury = list(Z = 0, fw = 0), theft = list(Z = 1, fw = 0.5), glass_hail = list(Z = 0.75, fw = 0.5))
M1_TW <- 0.1
LEVEL_GRID <- CJ(ftrend = c(1, 0), strend = c(1, 0.5, 0), load = c("raw", "rob"))
BLEND_GRID <- CJ(tw = c(0, 0.1, 0.2), legacy = c(0, 0.1, 0.2, 0.3))
FREQ_SEL <- {
  fu <- fread(file.path("models", "motor_iteration_01", "features_used.csv"))
  setNames(lapply(strsplit(fu$features, ", "), trimws), fu$peril)
}
dir.create(FITTED_DIR, recursive = TRUE, showWarnings = FALSE)

# MOTOR 2 overrides --------------------------------------------------------------------------------------
sev_rows <- function(tr, pr, col, all_years = FALSE) {
  ok <- tr[[paste0("y_npos_", pr)]] > 0 & tr[[col]] > 0
  if (!all_years && pr %in% LONG_TAIL && any(ok & tr$policy_year < LONG_TAIL_SEV_BEFORE)) ok <- ok & tr$policy_year < LONG_TAIL_SEV_BEFORE
  ok
}
fit_sev <- function(tr, pr, feats, all_years = FALSE) {
  col <- paste0("capc_", pr)
  ok <- sev_rows(tr, pr, col, all_years)
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
fit_xgb <- function(d, enc, y, w, margin, objective, mono, seed, n_seeds, extra = list(), cfg = XGB_PARAMS) {
  X <- lgb_matrix(d, enc$features, enc$cat_levels)
  set.seed(seed)
  up <- unique(d$policy_id)
  hold <- d$policy_id %in% sample(up, round(0.1 * length(up)))
  params <- c(cfg, list(objective = objective, tree_method = "hist", nthread = N_THREADS, seed = seed,
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
# Robust loading: claims above the cap count up to LOAD_MULT x cap, so one extreme open claim cannot set the level
add_robust_loading <- function(info, tr) {
  cl <- merge(CL[row_id %in% tr$row_id], info$caps, by = "peril")
  for (pr in PR) {
    x <- cl[peril == pr]
    info$loading[[pr]][["rob"]] <- sum(pmin(x$net, LOAD_MULT * x$cap)) / sum(pmin(x$net, x$cap))
  }
  info
}
fit_bi_pool <- function(tr, smp, g_tpp) {
  d <- tr[smp$idx]
  eff <- d[[paste0("effexp_", BI)]]
  off <- log(eff) + glm_eta(g_tpp, d) + glm_trend(g_tpp, d)
  g <- fit_glm2(d, BI_POOL_FEATS, d[[paste0("y_npos_", BI)]], smp$w, off, poisson(), sw = eff * smp$w, imm = TRUE)
  g$tpp <- g_tpp
  g
}

# fit everything a peril may use; final = TRUE fits only what cfg selects
fit_all2 <- function(tr, info, seed, final = FALSE, cfg = NULL, blend = NULL) {
  out <- list(perils = list())
  for (k in seq_along(PR)) {
    pr <- PR[k]
    smp <- freq_sample(tr, pr, names(info$unc_rate[[pr]]), ZERO_SAMPLE, seed + 100 * k)
    out$perils[[pr]] <- list(freq = fit_freq(tr, pr, FREQ_SEL[[pr]], smp))
  }
  # BI pooled frequency needs the TPP GLM of the same fold
  if (!final || cfg[[BI]]$freq != "glm") {
    smp <- freq_sample(tr, BI, names(info$unc_rate[[BI]]), ZERO_SAMPLE, seed + 300)
    out$perils[[BI]]$freq_pool <- fit_bi_pool(tr, smp, out$perils$third_party_prop$freq)
  }
  for (k in seq_along(PR)) {
    pr <- PR[k]
    s <- seed + 100 * k
    cp <- cfg[[pr]]
    fp <- out$perils[[pr]]
    variants <- if (final) cp$sev else c("base", "ext", if (pr == BI) "all")
    fp$sev <- lapply(setNames(variants, variants), function(v) {
      feats <- if (v == "ext") c(SEV_BASE[[pr]], SEV_EXT[[pr]]) else SEV_BASE[[pr]]
      fit_sev(tr, pr, feats, all_years = v == "all")
    })
    xs <- if (final) (if (cp$fw > 0) cp$xgb else character()) else names(XGB_CFGS)
    if (length(xs)) {
      cov <- !tr$cover_type %in% names(info$unc_rate[[pr]])
      d <- tr[cov]
      n <- d[[paste0("y_npos_", pr)]]; e <- d[[paste0("effexp_", pr)]]
      enc <- tree_enc(d, unique(c(TREE_CORE, rfeat(FREQ_SEL[[pr]], pr))), n, e)
      for (x in xs) {
        fp[[paste0("freq_", x)]] <- fit_xgb(d, enc, n, NULL, log(e), "count:poisson", mono_of(enc$features),
                                           s + match(x, names(XGB_CFGS)), if (final) N_SEEDS_FINAL else 1,
                                           cfg = XGB_CFGS[[x]])
      }
    }
    out$perils[[pr]] <- fp
  }
  if (!final || blend$tw > 0) {
    enc <- tree_enc(tr, unique(c(TREE_CORE, "hail_days", "freezing_days")), tr$y_target, tr$exposure)
    out$tw <- fit_xgb(tr, enc, tr$y_target / tr$exposure, tr$exposure, NULL, "reg:tweedie", mono_of(enc$features),
                      seed + 7, if (final) N_SEEDS_FINAL else 1, list(tweedie_variance_power = TWEEDIE_P))
  }
  out
}

peril_parts2 <- function(fp, d, info, pr) {
  ur_all <- info$unc_rate[[pr]]
  unc <- d$cover_type %in% names(ur_all)
  ur <- unname(ur_all[d$cover_type[unc]])
  glm_f <- function(eta, tr) {
    f <- exp(eta + tr); f[unc] <- ur
    t <- exp(tr); t[unc] <- 1
    list(f = f, trend = t)
  }
  p <- list(loading = info$loading[[pr]], cov = !unc)
  a <- glm_f(glm_eta(fp$freq, d), glm_trend(fp$freq, d))
  p$f_glm <- a$f; p$t_glm <- a$trend
  if (!is.null(fp$freq_pool)) {
    g <- fp$freq_pool
    a <- glm_f(glm_eta(g$tpp, d) + glm_eta(g, d), glm_trend(g$tpp, d) + glm_trend(g, d))
    p$f_pool <- a$f; p$t_pool <- a$trend
  }
  for (x in names(XGB_CFGS)) if (!is.null(fp[[paste0("freq_", x)]])) p[[paste0("f_", x)]] <- tree_rate(fp[[paste0("freq_", x)]], d)
  p$sev <- lapply(fp$sev, function(g) list(eta = glm_eta(g, d), trend = glm_trend(g, d), eta_c = g$eta_c))
  p
}
freq_of2 <- function(p, cfg, e) {
  one <- function(f, t) f / t^(1 - cfg$ftrend)
  fg <- switch(cfg$freq, glm = one(p$f_glm, p$t_glm), pool = one(p$f_pool, p$t_pool),
               mix = 0.5 * one(p$f_glm, p$t_glm) + 0.5 * one(p$f_pool, p$t_pool))
  if (cfg$fw == 0) return(fg)
  t <- p[[paste0("f_", cfg$xgb)]]
  cv <- p$cov
  t <- t * sum(fg[cv] * e[cv]) / sum(t[cv] * e[cv])
  t[!cv] <- fg[!cv]
  (1 - cfg$fw) * fg + cfg$fw * t
}
sev_of2 <- function(p, cfg) {
  sv <- p$sev[[cfg$sev]]
  exp(sv$eta_c + cfg$Z * (sv$eta - sv$eta_c) + cfg$strend * sv$trend)
}
peril_cost2 <- function(p, cfg, e) freq_of2(p, cfg, e) * sev_of2(p, cfg) * p$loading[[cfg$load]] * e

# ==========================================================================================================
# Phase A: data (same preparation as MOTOR 1)
# ==========================================================================================================
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
train <- engineer(train)
test <- engineer(test)
rm(weather, raw_claims); gc(verbose = FALSE)
add_shares(train, ROW_SHARE)
bi_hist <- rbindlist(lapply(2021:2024, function(y) {
  d <- train[policy_year == y]
  x <- CL[peril == BI & policy_year == y]
  data.table(policy_year = y, exposure = sum(d$exposure), reported_claims = sum(d[[paste0("y_npos_", BI)]]),
             developed_claims = sum(d[[paste0("y_npos_", BI)]] / d[[paste0("sh_", BI)]]),
             open_share = mean(x$status == "open"), mean_net = mean(x$net), median_net = median(x$net),
             mean_net_capped_200k = mean(pmin(x$net, 2e5)), max_net = max(x$net),
             developed_cost_per_exposure = sum(d[[paste0("y_cost_", BI)]] / d[[paste0("sh_", BI)]]) / sum(d$exposure))
}))[, developed_frequency := developed_claims / exposure]

# ==========================================================================================================
# Phase B / D: folds and candidate fits
# ==========================================================================================================
log_msg("Phase B: folds and candidate fits")
P <- list(); VA <- list(); fit_info <- list()
for (vy in VALID_YEARS) {
  k <- as.character(vy)
  t1 <- Sys.time()
  tr <- train[policy_year < vy]
  va <- train[policy_year == vy]
  info <- add_robust_loading(prep_fold(tr, va, SEED + vy), tr)
  fits <- fit_all2(tr, info, SEED + vy)
  P[[k]] <- lapply(setNames(PR, PR), function(pr) peril_parts2(fits$perils[[pr]], va, info, pr))
  ref <- Reduce(`+`, lapply(PR, function(pr) {
    peril_cost2(P[[k]][[pr]], list(freq = "glm", ftrend = 1, fw = 0, sev = "base", Z = 1, strend = 1, load = "raw"), va$exposure)
  }))
  keep_cols <- c("row_id", "exposure", "y_cost", paste0(c("y_cost_", "y_npos_", "effexp_", "capc_", "sh_"), rep(PR, each = 5)))
  VA[[k]] <- list(d = va[, ..keep_cols], tw = tw_cost(fits$tw, va, sum(ref)), legacy = legacy_pred(tr, va, SEED + vy))
  set(VA[[k]]$d, j = "developed", value = Reduce(`+`, lapply(PR, function(pr) va[[paste0("y_cost_", pr)]] / va[[paste0("sh_", pr)]])))
  fit_info[[k]] <- rbindlist(lapply(PR, function(pr) {
    fp <- fits$perils[[pr]]
    rbind(data.table(valid_year = vy, peril = pr, part = "freq_glm", trend_fitted = exp(fp$freq$year_raw) - 1,
                     claims = NA_real_, loading_raw = info$loading[[pr]][["raw"]], loading_rob = info$loading[[pr]][["rob"]]),
          if (!is.null(fp$freq_pool)) data.table(valid_year = vy, peril = pr, part = "freq_pool (BI rel. trend)",
                                                 trend_fitted = exp(fp$freq_pool$year_raw) - 1, claims = NA_real_,
                                                 loading_raw = NA_real_, loading_rob = NA_real_),
          rbindlist(lapply(names(fp$sev), function(v) data.table(valid_year = vy, peril = pr, part = paste0("sev_", v),
                                                                 trend_fitted = exp(fp$sev[[v]]$year_raw) - 1,
                                                                 claims = fp$sev[[v]]$claims, loading_raw = NA_real_,
                                                                 loading_rob = NA_real_))))
  }))
  rm(tr, va, fits); gc(verbose = FALSE)
  log_msg("Fold ", vy, " fitted in ", round(as.numeric(difftime(Sys.time(), t1, units = "mins")), 1), " min")
}
fit_info <- rbindlist(fit_info)

# ==========================================================================================================
# Phase E: decisions (ranking on calibrated D2, level on developed D2) and stage table
# ==========================================================================================================
log_msg("Phase E: decisions")
pd2 <- function(pr, cfg, kind = c("cal", "dev", "raw")) {
  kind <- match.arg(kind)
  sapply(names(VA), function(k) {
    d <- VA[[k]]$d
    y <- d[[paste0("y_cost_", pr)]]
    p <- peril_cost2(P[[k]][[pr]], cfg, d$exposure)
    switch(kind, cal = d2_cal(y, p, d$exposure), raw = d2_tweedie(y, p, d$exposure),
           dev = d2_tweedie(y / d[[paste0("sh_", pr)]], p, d$exposure))
  })
}
fd2 <- function(pr, cfg) {
  sapply(names(VA), function(k) {
    d <- VA[[k]]$d
    e <- d[[paste0("effexp_", pr)]]
    pois_d2(d[[paste0("y_npos_", pr)]], freq_of2(P[[k]][[pr]], cfg, d$exposure) * e, e)
  })
}
sd2 <- function(pr, cfg) {
  sapply(names(VA), function(k) {
    d <- VA[[k]]$d
    ok <- d[[paste0("y_npos_", pr)]] > 0 & d[[paste0("capc_", pr)]] > 0
    n <- d[[paste0("y_npos_", pr)]][ok]
    gamma_d2(d[[paste0("capc_", pr)]][ok] / n, sev_of2(P[[k]][[pr]], cfg)[ok], n)
  })
}
decisions <- list()
note <- function(pr, what, choice, detail) {
  decisions[[length(decisions) + 1]] <<- data.table(peril = pr, decision = what, choice = as.character(choice), detail = detail)
}
fmt3 <- function(x) paste(sprintf("%.4f", x), collapse = "/")
# Total-row D2 per fold with one peril's configuration swapped (cal = ranking, dev = level vs developed cost)
td2 <- function(pr, cpr, kind = c("cal", "dev")) {
  kind <- match.arg(kind)
  sapply(names(VA), function(k) {
    d <- VA[[k]]$d
    tot <- Reduce(`+`, lapply(PR, function(q) peril_cost2(P[[k]][[q]], if (q == pr) cpr else CFG[[q]], d$exposure)))
    if (kind == "cal") d2_cal(d$y_cost, tot, d$exposure) else d2_tweedie(d$developed, tot, d$exposure)
  })
}
CFG <- lapply(setNames(PR, PR), function(pr) list(freq = "glm", ftrend = 1, xgb = "x1", fw = M1_CFG[[pr]]$fw,
                                                  sev = "base", Z = M1_CFG[[pr]]$Z, strend = 1, load = "raw"))
BLEND <- list(tw = M1_TW, legacy = 0)
stages <- list(list(stage = "S0 MOTOR 1 configuration (refit)", cfg = CFG, blend = BLEND))

# 1. bodily_injury frequency: own GLM vs pooled with third_party_prop vs 50/50
b <- fd2(BI, CFG[[BI]])
alts <- lapply(c(pool = "pool", mix = "mix"), function(f) fd2(BI, modifyList(CFG[[BI]], list(freq = f))))
j <- which.max(sapply(alts, function(s) mean(s - b)))
if (keep_rule(alts[[j]], b)) CFG[[BI]]$freq <- names(alts)[j]
note(BI, "frequency: own GLM / pooled with TPP / 50-50", CFG[[BI]]$freq,
     sprintf("Poisson D2 own %s; pooled %s; mix %s", fmt3(b), fmt3(alts$pool), fmt3(alts$mix)))
stages[[length(stages) + 1]] <- list(stage = "S1 + bodily_injury frequency pooling", cfg = CFG, blend = BLEND)

# 2. XGBoost frequency configuration and weight per peril (total-row calibrated D2; peril D2 reported)
for (pr in PR) {
  base <- modifyList(CFG[[pr]], list(fw = 0))
  b <- td2(pr, base, "cal")
  opts <- CJ(xgb = names(XGB_CFGS), fw = c(0.5, 1))
  sc <- lapply(seq_len(nrow(opts)), function(i) td2(pr, modifyList(base, list(xgb = opts$xgb[i], fw = opts$fw[i])), "cal"))
  j <- which.max(sapply(sc, function(s) mean(s - b)))
  CFG[[pr]] <- if (keep_rule(sc[[j]], b)) modifyList(base, list(xgb = opts$xgb[j], fw = opts$fw[j])) else base
  note(pr, "XGBoost frequency config x weight (total calibrated D2)", paste(CFG[[pr]]$xgb, CFG[[pr]]$fw),
       paste(c(sprintf("GLM %s", fmt3(b)), sprintf("%s w=%.1f %s", opts$xgb, opts$fw, sapply(sc, fmt3))), collapse = "; "))
}
stages[[length(stages) + 1]] <- list(stage = "S2 + XGBoost frequency config / weight re-chosen", cfg = CFG, blend = BLEND)

# 3. Severity features and credibility Z (Gamma D2)
for (pr in PR) {
  x <- sd2(pr, modifyList(CFG[[pr]], list(sev = "ext", Z = 1)))
  b1 <- sd2(pr, modifyList(CFG[[pr]], list(Z = 1)))
  if (keep_rule(x, b1)) CFG[[pr]]$sev <- "ext"
  sc <- sapply(SHRINK_GRID, function(z) mean(sd2(pr, modifyList(CFG[[pr]], list(Z = z)))))
  CFG[[pr]]$Z <- SHRINK_GRID[which.max(sc)]
  note(pr, "severity features / Z", paste(CFG[[pr]]$sev, CFG[[pr]]$Z),
       sprintf("Gamma D2 base %s, extended %s; Z grid %s", fmt3(b1), fmt3(x), paste(sprintf("%.2f:%.4f", SHRINK_GRID, sc), collapse = " ")))
}
stages[[length(stages) + 1]] <- list(stage = "S3 + severity features / credibility re-chosen", cfg = CFG, blend = BLEND)

# 4. Level per peril on developed actuals: frequency trend, severity trend, robust loading (+ BI severity years)
level_tab <- list()
for (pr in PR) {
  grid <- copy(LEVEL_GRID)
  grid[, sev := CFG[[pr]]$sev]
  if (pr == BI) grid <- rbind(grid, copy(LEVEL_GRID)[, sev := "all"])
  res <- lapply(seq_len(nrow(grid)), function(i) {
    c <- modifyList(CFG[[pr]], as.list(grid[i]))
    list(dev = td2(pr, c, "dev"), peril_dev = pd2(pr, c, "dev"), cfg = c)
  })
  cur <- td2(pr, CFG[[pr]], "dev")
  g <- sapply(res, function(r) mean(r$dev - cur))
  j <- which.max(g)
  # Level options often differ only in folds whose training has immature years, so require no fold to get worse
  kept <- mean(res[[j]]$dev - cur) > KEEP_GAIN && all(res[[j]]$dev >= cur - 1e-4)
  if (kept) CFG[[pr]] <- res[[j]]$cfg
  level_tab[[pr]] <- cbind(data.table(peril = pr), grid,
                           data.table(total_dev_d2_mean = sapply(res, function(r) mean(r$dev)),
                                      peril_dev_d2_mean = sapply(res, function(r) mean(r$peril_dev)),
                                      total_dev_d2 = sapply(res, function(r) fmt3(r$dev)), chosen = seq_len(nrow(grid)) == j & kept))
  note(pr, "level: freq trend / sev trend / loading / sev years (total developed D2)",
       paste(CFG[[pr]]$ftrend, CFG[[pr]]$strend, CFG[[pr]]$load, CFG[[pr]]$sev),
       sprintf("total developed D2 current %s -> best %s", fmt3(cur), fmt3(res[[j]]$dev)))
}
level_tab <- rbindlist(level_tab)
stages[[length(stages) + 1]] <- list(stage = "S4 + level choices on developed actuals", cfg = CFG, blend = BLEND)

# 5. Final blend with the line Tweedie and the iteration-1 GLM replay (ranking, calibrated D2)
total_of2 <- function(k, cfg, blend) {
  d <- VA[[k]]$d
  tot <- Reduce(`+`, lapply(PR, function(pr) peril_cost2(P[[k]][[pr]], cfg[[pr]], d$exposure)))
  w0 <- 1 - blend$tw - blend$legacy
  w0 * tot + blend$tw * VA[[k]]$tw * sum(tot) / sum(VA[[k]]$tw) + blend$legacy * VA[[k]]$legacy * sum(tot) / sum(VA[[k]]$legacy)
}
bsc <- sapply(seq_len(nrow(BLEND_GRID)), function(i) mean(sapply(names(VA), function(k) {
  d <- VA[[k]]$d
  d2_cal(d$y_cost, total_of2(k, CFG, as.list(BLEND_GRID[i])), d$exposure)
})))
cur <- mean(sapply(names(VA), function(k) d2_cal(VA[[k]]$d$y_cost, total_of2(k, CFG, BLEND), VA[[k]]$d$exposure)))
j <- which.max(bsc)
if (bsc[j] > cur) BLEND <- as.list(BLEND_GRID[j])
note("all", "blend weights (line Tweedie, iteration-1 GLM)", paste(BLEND$tw, BLEND$legacy),
     paste(sprintf("tw=%.1f leg=%.1f: %.4f", BLEND_GRID$tw, BLEND_GRID$legacy, bsc), collapse = "; "))
stages[[length(stages) + 1]] <- list(stage = "S5 + blend with line Tweedie / iteration-1 GLM", cfg = CFG, blend = BLEND)
decisions <- rbindlist(decisions)

total_metrics2 <- function(pred_fun, label) {
  rbindlist(lapply(names(VA), function(k) {
    d <- VA[[k]]$d
    p <- pred_fun(k)
    data.table(model = label, valid_year = as.integer(k), d2 = d2_tweedie(d$y_cost, p, d$exposure),
               d2_cal = d2_cal(d$y_cost, p, d$exposure), d2_dev = d2_tweedie(d$developed, p, d$exposure),
               gini = norm_gini(d$y_cost, p), ae_developed = sum(p) / sum(d$developed))
  }))
}
stage_tab <- rbindlist(lapply(stages, function(s) {
  tm <- total_metrics2(function(k) total_of2(k, s$cfg, s$blend), s$stage)
  w <- dcast(tm, model ~ valid_year, value.var = c("d2", "d2_cal"))
  setnames(w, "model", "stage")
  cbind(w, data.table(d2_mean = mean(tm$d2), d2_cal_mean = mean(tm$d2_cal), d2_dev_mean = mean(tm$d2_dev)),
        as.data.table(as.list(setNames(sapply(PR, function(pr) mean(pd2(pr, s$cfg[[pr]], "cal"))), paste0("cal_", PR)))),
        as.data.table(as.list(setNames(sapply(PR, function(pr) mean(pd2(pr, s$cfg[[pr]], "dev"))), paste0("dev_", PR)))))
}))
peril_metrics <- rbindlist(lapply(PR, function(pr) {
  data.table(peril = pr, valid_year = VALID_YEARS, raw_d2 = pd2(pr, CFG[[pr]], "raw"), cal_d2 = pd2(pr, CFG[[pr]], "cal"),
             dev_d2 = pd2(pr, CFG[[pr]], "dev"), poisson_d2 = fd2(pr, CFG[[pr]]), gamma_d2 = sd2(pr, CFG[[pr]]),
             ae_developed = sapply(names(VA), function(k) {
               d <- VA[[k]]$d
               sum(peril_cost2(P[[k]][[pr]], CFG[[pr]], d$exposure)) / sum(d[[paste0("y_cost_", pr)]] / d[[paste0("sh_", pr)]])
             }))
}))
comparison <- rbind(
  total_metrics2(function(k) total_of2(k, CFG, BLEND), "MOTOR 2 (final)"),
  total_metrics2(function(k) total_of2(k, stages[[1]]$cfg, stages[[1]]$blend), "MOTOR 1 configuration (refit here)"),
  total_metrics2(function(k) VA[[k]]$tw, "single line-level Tweedie XGBoost"),
  total_metrics2(function(k) VA[[k]]$legacy, "iteration-1 GLM replay"),
  data.table(model = "SAM 4 blend (reported)", valid_year = VALID_YEARS, d2 = unname(SAM4_D2),
             d2_cal = c(0.0595, 0.0438, 0.0577), d2_dev = NA_real_, gini = NA_real_, ae_developed = NA_real_))
comparison_w <- dcast(comparison, model ~ valid_year, value.var = c("d2", "d2_cal"))
comparison_w[, `:=`(d2_mean = rowMeans(.SD[, paste0("d2_", VALID_YEARS), with = FALSE]),
                    d2_cal_mean = rowMeans(.SD[, paste0("d2_cal_", VALID_YEARS), with = FALSE]))]
setorder(comparison_w, -d2_cal_mean)

fold_pred <- rbindlist(lapply(names(VA), function(k) {
  d <- VA[[k]]$d
  out <- d[, .(valid_year = as.integer(k), row_id, exposure, actual = y_cost, developed)]
  for (pr in PR) set(out, j = paste0("pred_", pr), value = peril_cost2(P[[k]][[pr]], CFG[[pr]], d$exposure))
  out[, `:=`(pred_final = total_of2(k, CFG, BLEND), pred_line_tweedie = VA[[k]]$tw, pred_legacy_glm = VA[[k]]$legacy)]
}))

# ==========================================================================================================
# Phase F: final fit on 2021-24
# ==========================================================================================================
log_msg("Phase F: final fit on 2021-24")
rm(P); gc(verbose = FALSE)
tr <- copy(train)
te <- copy(test)
add_shares(te, ROW_SHARE)
info <- add_robust_loading(prep_fold(tr, te, SEED + 2025), tr)
fits <- fit_all2(tr, info, SEED + 2025, final = TRUE, cfg = CFG, blend = BLEND)
leg_final <- if (BLEND$legacy > 0) legacy_pred(tr, te, SEED + 2025) else NULL
art <- list(model = "motor02_peril", info = info, perils = fits$perils, tw = fits$tw, cfg = CFG, blend = BLEND,
            row_share = ROW_SHARE)
score_art2 <- function(art, d, legacy = NULL) {
  d <- copy(d)
  add_shares(d, art$row_share)
  add_te(d, art$info)
  costs <- sapply(PR, function(pr) peril_cost2(peril_parts2(art$perils[[pr]], d, art$info, pr), art$cfg[[pr]], d$exposure))
  tot <- rowSums(costs)
  b <- art$blend
  out <- (1 - b$tw - b$legacy) * tot
  if (b$tw > 0) out <- out + b$tw * tw_cost(art$tw, d, sum(tot))
  if (b$legacy > 0) out <- out + b$legacy * legacy * sum(tot) / sum(legacy)
  list(total = pmax(out, 0), perils = costs)
}
sc <- score_art2(art, test, leg_final)
pred <- sc$total
sam4 <- fread(file.path("models", "sam_iteration_04", "test_prediction_summary.csv"))[line == "motor" & model == "blend"]
level_scale <- sam4$predicted_total / sum(pred)
test_summary <- data.table(peril = c(PR, "total"), predicted_total = c(colSums(sc$perils), sum(pred)))[
  , cost_per_exposure_year := predicted_total / sum(test$exposure)]
final_cfg <- rbindlist(lapply(PR, function(pr) {
  fp <- fits$perils[[pr]]
  c <- CFG[[pr]]
  data.table(peril = pr, freq = c$freq, freq_trend_fitted = exp(fp$freq$year_raw) - 1, freq_trend_on = c$ftrend,
             xgb = if (c$fw > 0) c$xgb else "-", xgb_w = c$fw, sev = c$sev, Z = c$Z,
             sev_trend_fitted = exp(fp$sev[[1]]$year_raw) - 1, sev_trend_share = c$strend, loading = c$load,
             loading_value = info$loading[[pr]][[c$load]], loading_raw = info$loading[[pr]][["raw"]], cap = info$caps[peril == pr, cap])
}))

unlink(FITTED_DIR, recursive = TRUE)
dir.create(FITTED_DIR, recursive = TRUE)
pack_art2 <- function(a, f) {
  for (pr in PR) for (m in paste0("freq_", names(XGB_CFGS))) if (!is.null(a$perils[[pr]][[m]])) a$perils[[pr]][[m]] <- f(a$perils[[pr]][[m]])
  if (!is.null(a$tw)) a$tw <- f(a$tw)
  a
}
saveRDS(list(art = pack_art2(art, sam02_pack), legacy_test = leg_final), file.path(FITTED_DIR, "motor02_peril.rds"))
sub <- data.table(row_id = test$row_id, prediction = pred)
sample_sub <- read_raw("sample_submission")
stopifnot(nrow(sub) == nrow(test), setequal(sub$row_id, sample_sub$row_id[sample_sub$row_id %in% test$row_id]),
          !anyDuplicated(sub$row_id), !anyNA(sub$prediction), all(sub$prediction >= 0))
f_own <- out_file("submission", paste0("motor2_only_", RUN_ID, if (QUICK) "_quick", ".csv"))
f_sam <- out_file("submission", paste0("motor2_only_", RUN_ID, if (QUICK) "_quick", "_samlevel.csv"))
fwrite(sub, f_own, scipen = 50)
fwrite(sub[, .(row_id, prediction = prediction * level_scale)], f_sam, scipen = 50)
saved <- readRDS(file.path(FITTED_DIR, "motor02_peril.rds"))
replication_diff <- max(abs(score_art2(pack_art2(saved$art, sam02_unpack), test, saved$legacy_test)$total - pred))
log_msg("Replication max abs diff ", signif(replication_diff, 3))

# Outputs and card --------------------------------------------------------------------------------------
fwrite(decisions, file.path(ITER_DIR, "decisions.csv"))
fwrite(stage_tab, file.path(ITER_DIR, "stage_table.csv"))
fwrite(level_tab, file.path(ITER_DIR, "level_grid.csv"))
fwrite(peril_metrics, file.path(ITER_DIR, "peril_metrics.csv"))
fwrite(comparison, file.path(ITER_DIR, "comparison.csv"))
fwrite(fit_info, file.path(ITER_DIR, "fit_info.csv"))
fwrite(bi_hist, file.path(ITER_DIR, "bodily_injury_history.csv"))
fwrite(final_cfg, file.path(ITER_DIR, "final_config.csv"))
fwrite(test_summary, file.path(ITER_DIR, "test_prediction_summary.csv"))
write_parquet(fold_pred, file.path(ITER_DIR, "fold_predictions.parquet"))
minutes <- round(as.numeric(difftime(Sys.time(), T0, units = "mins")), 1)
fwrite(data.table(run_id = RUN_ID, quick = QUICK, minutes = minutes, burn_2025_own = sum(pred) / sum(test$exposure),
                  burn_2025_sam4 = sam4$predicted_burn_cost, level_scale = level_scale, replication_max_diff = replication_diff),
       file.path(ITER_DIR, "summary.csv"))

card <- c(
  "# MOTOR 2 - per-peril frequency x severity, bodily_injury rework", "",
  sprintf("**Run id** `%s` | **Quick** %s | **Runtime** %.0f min | **Files** `%s` (own level), `%s` (SAM 4 level)",
          RUN_ID, QUICK, minutes, basename(f_own), basename(f_sam)), "",
  "Metrics: `d2` = raw Tweedie D2 (p = 1.5) vs reported cost (the local Kaggle proxy); `d2_cal` = after rescaling to the actual total (ranking only); `d2_dev` = vs IBNR-developed row cost (cost / reported share), used for level decisions because 2024 reported cost is immature. Ranking choices use calibrated D2 or Poisson / Gamma D2; level choices use developed D2. Keep rule: mean gain > 0.0005 and better in >= 2 of 3 folds (level choices: mean gain > 0.0005 and no fold worse, since only folds trained on immature years can separate them).", "",
  "## Comparison (sorted by calibrated D2)", "", md_table(comparison_w, 4),
  "## Stage table", "", "`cal_<peril>` / `dev_<peril>` = mean calibrated / developed Tweedie D2 of that peril's cost.", "",
  md_table(stage_tab, 4),
  "## Decisions", "", md_table(decisions, 4),
  "## Level grid (developed D2 per option)", "", md_table(level_tab, 4),
  "## Peril metrics (final configuration)", "", md_table(peril_metrics, 4),
  "## bodily_injury history", "",
  "Developed = reported / reported share (3b pattern; SAM 3 ECDF for BI). Case estimates are taken as adequate, so 2023-24 severities may still develop (IBNER); the level choice on developed actuals inherits that assumption.", "",
  md_table(bi_hist, 3),
  "## Fitted trends and loadings by fold", "", md_table(fit_info, 3),
  "## Final configuration (fit on 2021-24)", "", md_table(final_cfg, 3),
  "## 2025 predictions", "", md_table(test_summary, 2),
  sprintf("Own level %.2f vs SAM 4 %.2f per exposure-year (scale %.4f). Replication max abs diff %s.",
          sum(pred) / sum(test$exposure), sam4$predicted_burn_cost, level_scale, signif(replication_diff, 3)), "",
  "## Flags", "",
  "- Level options are chosen on three folds whose 2024 developed actuals rest on a 1.74 BI report-lag factor and unaudited case reserves; a lower BI level that wins locally may still be too low for 2025 ultimate (the public test #10 favoured the higher SAM level). Use the SAM-level file unless the public score says otherwise.",
  "- All choices are made and reported on the same folds, so gains below about 0.001 are within noise.",
  "- The iteration-1 GLM replay in the blend has no trend and no claim history; it is rescaled to the per-peril total, so it only contributes ranking.")
writeLines(card, file.path(ITER_DIR, "model_card.md"))
log_msg("Done in ", minutes, " min; card at ", file.path(ITER_DIR, "model_card.md"))
