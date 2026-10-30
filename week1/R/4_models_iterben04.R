# 4_models_iterben04.R ------------------------------------------------------
# BEN 4: LightGBM on point-in-time features with developed, capped targets; line Tweedie vs per-peril frequency x
# severity, blended per line. Each variant adds or removes one thing so its effect is measured.
#   Data:       week1/R/ben/ben4_data.R -> data/week_1/ben4/ (claims history at 1 January, previous row, prior declines, row shape in
#               its own year, holdings; per-peril claim-capped cost (p99.9), chain-ladder development per row and peril)
#   Targets:    cost = sum over perils of capped cost x cost development x loading (2m-limited / capped cost);
#               on-levelled to the scored year with the line's burn trend fitted on the fit years (clamped)
#   Variants:   v0 line Tweedie, BEN 1 features | v1 + BEN 4 features | v2 v1 without the row-shape group |
#               v3 v1 weighted by sqrt(exposure) (the metric on row totals) | v4 per-peril Poisson x Gamma, BEN 4 features |
#               v5 blend of the better of v1/v3 with v4, weight per line on mean developed D2
#   Folds:      fit 2021-22 -> score 2023, fit 2021-23 -> score 2024 (expanding window, as BEN 1 v6); final fit 2021-24
#   Selection:  per line, highest mean D2 over both folds against developed actuals (reported D2 shown too)
#   Ceiling:    expected D2 if the selected predictions were the true means (simulated claims), the most this model
#               family could score on these rows
# Run:     Rscript week1/R/ben/ben4_data.R; Rscript week1/R/4_models_iterben04.R   (quick test: env var B4_QUICK=1)
# Outputs: week1/models/ben_iteration_04/ (model_card.md, CSVs, fitted/), week1/output/submission/submission_<run id>.csv,
#          week1/output/4_models/run_history.csv (appended)

source("week1/R/0_setup.R")
source("week1/R/ben/ben_helpers.R")
STEP <- "4_models"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITERATION <- "BEN 4"
ITERATION_NOTE <- paste("LightGBM on point-in-time features (claims history at 1 January, previous row, prior declines,",
                        "row shape, holdings) with claim-capped, chain-ladder-developed, trended targets; line Tweedie vs",
                        "per-peril Poisson x Gamma, blended per line.")
ITER_DIR <- file.path("week1", "models", "ben_iteration_04")
B4_DATA <- file.path("data", "week_1", "ben4")
VALID_YEARS <- c(2023, 2024)
TARGET_YEAR <- 2025
TREND_CLAMP <- c(-0.03, 0.06)
QUICK <- Sys.getenv("B4_QUICK", "0") == "1"
THREADS <- max(1L, parallel::detectCores() - 2L)
MAX_ROUNDS <- if (QUICK) 150L else 3000L
BLEND_GRID <- seq(0, 1, by = 0.1)
unlink(file.path(ITER_DIR, "fitted"), recursive = TRUE)                # no stale model files from an earlier run
dir.create(file.path(ITER_DIR, "fitted"), recursive = TRUE, showWarnings = FALSE)

# BEN 1 EDA exclusions (week1/docs/workflow.md): calendar, duplicate and constant fields; premium as an index.
# SAM 3's noise / marketing fields out as well (week1/R/ben/ben4_tune.R: depth-3 trees without them scored best on motor).
BEN_EXCLUDE <- c("compulsory_excess", "years_with_insurer", "customer_since_year", "campaign_code", "written_premium",
                 "discount_applied", "email_domain", "vehicle_colour", "document_preference", "marketing_consent", "branch_id",
                 "marketing_segment")
SHAPE <- c("b4_ends_in_change", "b4_after_change", "b4_ends_early", "b4_rows_in_year")
CRED_LINE <- 200             # exposure-years of credibility when ordering text levels by cost rate (BEN 1)
CRED_CLAIMS <- 30            # per-peril models: credibility worth this many expected claims

# Tree settings from week1/R/ben/ben4_tune.R (setting E: depth 3, as BEN 1's XGBoost)
LGB_LINE <- list(objective = "tweedie", tweedie_variance_power = TWEEDIE_P, learning_rate = 0.05, num_leaves = 8,
                 max_depth = 3, min_data_in_leaf = 1000, feature_fraction = 0.6, bagging_fraction = 0.8, bagging_freq = 1,
                 lambda_l2 = 20, verbosity = -1, num_threads = THREADS, deterministic = TRUE, force_col_wise = TRUE)
LGB_FREQ <- modifyList(LGB_LINE, list(objective = "poisson", num_leaves = 15, max_depth = 4))
LGB_SEV <- modifyList(LGB_LINE, list(objective = "gamma", learning_rate = 0.03, num_leaves = 7, max_depth = 3,
                                     min_data_in_leaf = 200, lambda_l2 = 50))

fit_seed <- function(ln, year, k) SEED + 1000 * match(ln, LINES) + 100 * k + (year - 2020)
read_b4 <- function(name) {
  f <- file.path(B4_DATA, paste0(name, ".parquet"))
  if (!file.exists(f)) stop("Missing ", f, " - run week1/R/ben/ben4_data.R first.")
  as.data.table(read_parquet(f))
}
loading <- fread(ben_out(file.path("ben4", "loading.csv")))

# Metric (as BEN 1 / week1/docs/workflow.md): Tweedie D2, p = 1.5, baseline = one cost per exposure-year x exposure
tweedie_dev <- function(y, mu, p = TWEEDIE_P) {
  mu <- pmax(mu, 1e-9)
  mean(2 * (ifelse(y > 0, y^(2 - p), 0) / ((1 - p) * (2 - p)) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p)))
}
d2_tweedie <- function(y, pred, exposure) 1 - tweedie_dev(y, pred) / tweedie_dev(y, exposure * sum(y) / sum(exposure))
d2_flat <- function(y, pred) 1 - tweedie_dev(y, pred) / tweedie_dev(y, rep(mean(y), length(y)))

# Features and encoding ---------------------------------------------------------------------------------------
features_for <- function(dt, set) {
  f <- setdiff(feature_cols(dt, include_new = TRUE), c(BEN_EXCLUDE, grep("^(dev_|act_)", names(dt), value = TRUE)))
  if (set == "base") f <- f[!startsWith(f, "b4_")]
  if (set == "no_shape") f <- setdiff(f, SHAPE)
  leak <- f[grepl("^(y_|act_|dev_)", f) | f %in% c(NON_FEATURES, "renewal_decision")]
  if (length(leak)) stop("Target or development columns among the features: ", paste(leak, collapse = ", "))
  f
}
# Text features become numbers: levels ordered by a credibility-weighted rate of the model's own target on the fit rows
# (as BEN 1). LightGBM's native categorical splits overfit here (week1/R/ben/ben4_tune.R: motor 2023 D2 0.022 native vs
# 0.037 ordered). k = credibility in units of w (exposure-years); unseen levels -> NA.
encoder <- function(dt, feats, y, w, k) {
  cats <- feats[vapply(dt[, ..feats], function(x) is.character(x) || is.factor(x), logical(1))]
  m <- sum(y) / sum(w)
  lv <- lapply(setNames(cats, cats), function(f) {
    r <- data.table(lv = as.character(dt[[f]]), y = y, w = w)[!is.na(lv), .(y = sum(y), w = sum(w)), by = lv]
    r[, rate := (y + k * m) / (w + k)]
    r[order(rate), lv]
  })
  list(features = feats, cat_levels = lv, caps = list(renewal_count = max(dt$renewal_count, na.rm = TRUE)))
}
to_matrix <- function(dt, enc) {
  vapply(enc$features, function(f) {
    if (f %in% names(enc$cat_levels)) return(as.numeric(match(as.character(dt[[f]]), enc$cat_levels[[f]]) - 1L))
    x <- as.numeric(dt[[f]])
    if (f %in% names(enc$caps)) pmin(x, enc$caps[[f]]) else x
  }, numeric(nrow(dt)))
}

# Targets -------------------------------------------------------------------------------------------------------
add_targets <- function(dt, ln) {
  ld <- loading[line == ln]
  dt[, y_dev := 0]
  for (p in PERILS[[ln]]) {
    lp <- ld[peril == p, loading]
    dt[, y_dev := y_dev + get(paste0("y_cap_", p)) * get(paste0("dev_w_", p)) * lp]
    dt[, paste0("act_dev_", p) := get(paste0("y_cost_", p)) * get(paste0("dev_w_", p))]
  }
  dt[, act_dev := Reduce(`+`, .SD), .SDcols = paste0("act_dev_", PERILS[[ln]])]   # uncapped developed actuals
  dt[]
}
# Log-linear burn trend over the fit years (developed, capped, loaded), clamped
fit_trend <- function(tr) {
  b <- tr[, .(burn = sum(y_dev) / sum(exposure), e = sum(exposure)), by = policy_year]
  g <- if (nrow(b) < 2) 0 else exp(coef(lm(log(burn) ~ policy_year, data = b, weights = e))[[2]]) - 1
  min(max(g, TREND_CLAMP[1]), TREND_CLAMP[2])
}

# One LightGBM fit with early stopping on a 15% policy holdout, then refit on all rows at the stopped round count
lgb_fit <- function(X, y, w, params, seed, pol) {
  set.seed(seed)
  hold <- pol %in% sample(unique(pol), round(0.15 * uniqueN(pol)))
  mk <- function(i) lgb.Dataset(X[i, , drop = FALSE], label = y[i], weight = w[i], free_raw_data = FALSE,
                                 params = list(verbosity = -1))
  p <- modifyList(params, list(seed = seed))
  b <- lgb.train(p, mk(!hold), nrounds = MAX_ROUNDS, valids = list(h = mk(hold)), early_stopping_rounds = 100, verbose = -1)
  n <- max(20L, round(b$best_iter * 1.1))
  lgb.train(p, mk(rep(TRUE, length(y))), nrounds = n, verbose = -1)
}
# Line Tweedie on the on-levelled cost rate
fit_line <- function(tr, feats, weight, seed, onlevel) {
  enc <- encoder(tr, feats, tr$y_dev * onlevel, tr$exposure, CRED_LINE)
  X <- to_matrix(tr, enc)
  y <- tr$y_dev * onlevel / tr$exposure
  w <- if (weight == "sqrt") sqrt(tr$exposure) else tr$exposure
  b <- lgb_fit(X, y, w, LGB_LINE, seed, tr$policy_id)
  bal <- sum(tr$y_dev * onlevel) / sum(predict(b, X) * tr$exposure)       # fitted total = target total
  list(kind = "line", enc = enc, booster = b, balance = bal)
}
# Per-peril Poisson frequency (developed counts) x Gamma severity (capped, developed, on-levelled), times the loading.
# Text levels are ordered by the peril's own developed claim frequency.
fit_peril <- function(tr, feats, seed, onlevel, ln) {
  out <- list(kind = "peril", perils = list())
  for (k in seq_along(PERILS[[ln]])) {
    p <- PERILS[[ln]][k]
    n <- tr[[paste0("y_n_", p)]]; cap <- tr[[paste0("y_cap_", p)]]
    dn <- tr[[paste0("dev_n_", p)]]; dw <- tr[[paste0("dev_w_", p)]]
    enc <- encoder(tr, feats, n * dn, tr$exposure, CRED_CLAIMS / max(sum(n * dn) / sum(tr$exposure), 1e-6))
    X <- to_matrix(tr, enc)
    fb <- lgb_fit(X, n * dn / tr$exposure, tr$exposure, LGB_FREQ, seed + 10 * k, tr$policy_id)
    s <- which(n > 0 & cap > 0)
    sev_y <- cap[s] / n[s] * (dw[s] / dn[s]) * onlevel[s]
    sb <- lgb_fit(X[s, , drop = FALSE], sev_y, n[s], LGB_SEV, seed + 10 * k + 5, tr$policy_id[s])
    lp <- loading[line == ln & peril == p, loading]
    f_hat <- predict(fb, X); s_hat <- predict(sb, X)
    bal <- sum(cap * dw * onlevel * lp) / sum(f_hat * s_hat * tr$exposure * lp)
    out$perils[[p]] <- list(enc = enc, freq = fb, sev = sb, loading = lp, balance = bal)
  }
  out
}
score_by_peril <- function(m, dt) {
  lapply(m$perils, function(q) {
    X <- to_matrix(dt, q$enc)
    list(freq = predict(q$freq, X) * q$balance * dt$exposure, sev = predict(q$sev, X) * q$loading)
  })
}
score <- function(m, dt) {
  if (m$kind == "line") return(predict(m$booster, to_matrix(dt, m$enc)) * m$balance * dt$exposure)
  Reduce(`+`, lapply(score_by_peril(m, dt), function(q) q$freq * q$sev))
}

VARIANTS <- list(
  v0 = list(label = "line Tweedie, BEN 1 features", kind = "line", features = "base", weight = "exposure"),
  v1 = list(label = "+ BEN 4 point-in-time features", kind = "line", features = "b4", weight = "exposure"),
  v2 = list(label = "v1 without the row-shape group", kind = "line", features = "no_shape", weight = "exposure"),
  v3 = list(label = "v1 weighted by sqrt(exposure)", kind = "line", features = "b4", weight = "sqrt"),
  v4 = list(label = "per-peril Poisson x Gamma, BEN 4 features", kind = "peril", features = "b4", weight = "exposure")
)

# Validation and final fit ------------------------------------------------------------------------------------
data <- list(); preds <- list(); trends <- list(); final <- list(); test_pred <- list(); ceiling_parts <- list()
for (ln in LINES) {
  log_msg(ln, ": reading data/week_1/ben4")
  train <- add_targets(read_b4(paste0("train_", ln)), ln)
  test <- read_b4(paste0("test_", ln))
  if (QUICK) train <- train[policy_id %in% sample(unique(policy_id), round(0.25 * uniqueN(policy_id)))]
  for (yr in c(VALID_YEARS, TARGET_YEAR)) {
    tr <- train[policy_year < yr]
    va <- if (yr == TARGET_YEAR) test else train[policy_year == yr]
    g <- fit_trend(tr)
    onlevel <- (1 + g)^(yr - tr$policy_year)
    trends[[paste(ln, yr)]] <- data.table(line = ln, year = yr, trend = g)
    vs <- if (yr == TARGET_YEAR) "final" else "valid"
    out <- data.table(row_id = va$row_id, line = ln, year = yr, exposure = va$exposure,
                      actual = if (vs == "valid") va$y_cost else NA_real_, actual_dev = if (vs == "valid") va$act_dev else NA_real_)
    for (v in names(VARIANTS)) {
      vv <- VARIANTS[[v]]
      t0 <- Sys.time()
      feats <- features_for(tr, vv$features)
      seed <- fit_seed(ln, yr, match(v, names(VARIANTS)))
      m <- if (vv$kind == "line") fit_line(tr, feats, vv$weight, seed, onlevel) else fit_peril(tr, feats, seed, onlevel, ln)
      set(out, j = v, value = score(m, va))
      # guardrail: no honest model of claim cost gets near this; stop instead of submitting a leak
      if (vs == "valid" && d2_tweedie(out$actual_dev, out[[v]], out$exposure) > 0.4) stop(ln, " ", yr, " ", v, ": D2 > 0.4, check for leakage")
      if (yr == TARGET_YEAR) final[[ln]][[v]] <- m
      if (yr == 2024 && v == "v4") ceiling_parts[[ln]] <- list(parts = score_by_peril(m, va), exposure = va$exposure)
      log_msg(sprintf("%s %d %s: %.1f min, %s", ln, yr, v, as.numeric(difftime(Sys.time(), t0, units = "mins")),
                      if (vs == "valid") sprintf("D2 %.4f, developed %.4f", d2_tweedie(out$actual, out[[v]], out$exposure),
                                                 d2_tweedie(out$actual_dev, out[[v]], out$exposure)) else "final"))
    }
    preds[[paste(ln, yr)]] <- out
  }
  rm(train, test); gc(verbose = FALSE)
}
P <- rbindlist(preds, fill = TRUE)
trends <- rbindlist(trends)
# row-level predictions of every variant (validation folds and test), for later blending; git-ignored
write_parquet(P, ben_out(file.path("ben4", paste0("predictions_", RUN_ID, ".parquet"))))
VAL <- P[year %in% VALID_YEARS]

# Blend v5 per line: the better line model (v1 or v3) with v4, weight on mean developed D2 over both folds
score_d2 <- function(d, col) d[, .(d2 = d2_tweedie(actual, get(col), exposure), d2_dev = d2_tweedie(actual_dev, get(col), exposure)),
                                by = .(line, year)]
blend <- rbindlist(lapply(LINES, function(ln) {
  d <- VAL[line == ln]
  best_line <- if (mean(score_d2(d, "v3")$d2_dev) > mean(score_d2(d, "v1")$d2_dev)) "v3" else "v1"
  rbindlist(lapply(BLEND_GRID, function(w) {
    d[, b := w * get(best_line) + (1 - w) * v4]
    data.table(line = ln, line_model = best_line, w_line = w, d2 = mean(score_d2(d, "b")$d2), d2_dev = mean(score_d2(d, "b")$d2_dev))
  }))
}))
blend_pick <- unique(blend[order(line, -d2_dev, -w_line)], by = "line")
for (ln in LINES) {
  bp <- blend_pick[line == ln]
  P[line == ln, v5 := bp$w_line * get(bp$line_model) + (1 - bp$w_line) * v4]
}
VAL <- P[year %in% VALID_YEARS]

# Results per variant: by line and combined (one baseline over the three lines, as Kaggle scores the file)
vnames <- c(names(VARIANTS), "v5")
res <- rbindlist(lapply(vnames, function(v) {
  by_line <- VAL[, .(d2 = d2_tweedie(actual, get(v), exposure), d2_dev = d2_tweedie(actual_dev, get(v), exposure),
                     pred_over_dev = sum(get(v)) / sum(actual_dev)), by = .(line, year)]
  comb <- VAL[, .(line = "combined", d2 = d2_tweedie(actual, get(v), exposure), d2_dev = d2_tweedie(actual_dev, get(v), exposure),
                  pred_over_dev = sum(get(v)) / sum(actual_dev), d2_flat = d2_flat(actual, get(v))), by = year]
  rbind(by_line, comb, fill = TRUE)[, variant := v]
}))
res[, label := c(sapply(VARIANTS, `[[`, "label"), v5 = "blend of the better line model with v4")[variant]]
selection <- res[line != "combined", .(d2_dev = mean(d2_dev), d2 = mean(d2)), by = .(line, variant)][
  , .SD[which.max(d2_dev)], by = line]
P[, selected := NA_real_]
for (ln in LINES) P[line == ln, selected := get(selection[line == ln, variant])]
VAL <- P[year %in% VALID_YEARS]
sel_comb <- VAL[, .(d2 = d2_tweedie(actual, selected, exposure), d2_dev = d2_tweedie(actual_dev, selected, exposure),
                    d2_flat = d2_flat(actual, selected)), by = year]
log_msg("Selected: ", paste(selection$line, selection$variant, collapse = ", "), " | combined D2 ",
        paste(sprintf("%d %.4f (dev %.4f)", sel_comb$year, sel_comb$d2, sel_comb$d2_dev), collapse = "; "))

# Ceiling: if v4's 2024 frequency and severity were the true means, what D2 would the same predictions score?
sim_ceiling <- function(reps = 3) {
  cl <- read_clean("claims_matched")[counts == TRUE & status != "repudiated" & year(loss_date) %in% 2021:2023]
  out <- c()
  for (r in seq_len(reps)) {
    set.seed(SEED + r)
    ys <- list(); mus <- list(); es <- list()
    for (ln in names(ceiling_parts)) {
      cp <- ceiling_parts[[ln]]
      y <- numeric(length(cp$exposure)); mu <- numeric(length(cp$exposure))
      for (p in names(cp$parts)) {
        f <- cp$parts[[p]]$freq; s <- cp$parts[[p]]$sev
        emp <- cl[line == ln & peril == p & net_cost > 0, net_cost]
        emp <- emp / mean(emp)                                          # shape of the peril's claim sizes
        n <- rpois(length(f), f)
        i <- which(n > 0)
        draws <- vapply(i, function(j) sum(sample(emp, n[j], replace = TRUE)), numeric(1))
        y[i] <- y[i] + draws * s[i]
        mu <- mu + f * s
      }
      ys[[ln]] <- y; mus[[ln]] <- mu; es[[ln]] <- cp$exposure
    }
    out <- c(out, d2_tweedie(unlist(ys), unlist(mus), unlist(es)))
  }
  out
}
ceiling_d2 <- if (length(ceiling_parts) == 3) sim_ceiling() else NA_real_
log_msg("Ceiling (v4 as truth, 2024 rows): ", paste(round(ceiling_d2, 4), collapse = ", "))

# Submission ----------------------------------------------------------------------------------------------------
sub <- P[year == TARGET_YEAR, .(row_id, prediction = pmax(selected, 0))]
sample_ids <- read_raw("sample_submission")$row_id
stopifnot(nrow(sub) == 626639, uniqueN(sub$row_id) == 626639, setequal(sub$row_id, sample_ids), !anyNA(sub$prediction))
sub <- sub[match(sample_ids, row_id)]
sub_file <- out_file("submission", paste0("submission_", RUN_ID, if (QUICK) "_quick_ben04" else "", ".csv"))
fwrite(sub, sub_file)
md5 <- unname(tools::md5sum(sub_file))
# every variant's test predictions too, for blending with other iterations later
fwrite(P[year == TARGET_YEAR, c("row_id", "line", "exposure", vnames, "selected"), with = FALSE],
       ben_out(file.path("ben4", "test_predictions_by_variant.csv.gz")))      # 37 MB: git-ignored, not in week1/models/
test_summary <- P[year == TARGET_YEAR, lapply(.SD, function(x) sum(x) / sum(exposure)), by = line, .SDcols = c(vnames, "selected")]

# Save fitted models (LightGBM text files + encoding/balance in rds) and check they reproduce the submission
for (ln in LINES) {
  v <- selection[line == ln, variant]
  parts <- if (v == "v5") c(blend_pick[line == ln, line_model], "v4") else v
  art <- list(line = ln, variant = v, w_line = if (v == "v5") blend_pick[line == ln, w_line] else 1, models = list())
  for (pv in parts) {
    m <- final[[ln]][[pv]]
    if (m$kind == "line") {
      f <- file.path(ITER_DIR, "fitted", sprintf("%s_%s_line.txt", ln, pv)); lgb.save(m$booster, f)
      art$models[[pv]] <- list(kind = "line", enc = m$enc, balance = m$balance, file = basename(f))
    } else {
      pl <- lapply(names(m$perils), function(p) {
        q <- m$perils[[p]]
        ff <- file.path(ITER_DIR, "fitted", sprintf("%s_%s_%s_freq.txt", ln, pv, p)); lgb.save(q$freq, ff)
        fs <- file.path(ITER_DIR, "fitted", sprintf("%s_%s_%s_sev.txt", ln, pv, p)); lgb.save(q$sev, fs)
        list(enc = q$enc, freq = basename(ff), sev = basename(fs), loading = q$loading, balance = q$balance)
      })
      art$models[[pv]] <- list(kind = "peril", perils = setNames(pl, names(m$perils)))
    }
  }
  saveRDS(art, file.path(ITER_DIR, "fitted", paste0(ln, "_ben04.rds")))
}
load_b4 <- function(ln) {
  art <- readRDS(file.path(ITER_DIR, "fitted", paste0(ln, "_ben04.rds")))
  for (nm in names(art$models)) {
    m <- art$models[[nm]]
    if (m$kind == "line") art$models[[nm]]$booster <- lgb.load(file.path(ITER_DIR, "fitted", m$file))
    else for (p in names(m$perils)) {
      art$models[[nm]]$perils[[p]]$freq <- lgb.load(file.path(ITER_DIR, "fitted", m$perils[[p]]$freq))
      art$models[[nm]]$perils[[p]]$sev <- lgb.load(file.path(ITER_DIR, "fitted", m$perils[[p]]$sev))
    }
  }
  art
}
replication <- rbindlist(lapply(LINES, function(ln) {
  art <- load_b4(ln)
  te <- read_b4(paste0("test_", ln))
  s <- lapply(art$models, score, dt = te)
  pred <- if (length(s) == 2) art$w_line * s[[1]] + (1 - art$w_line) * s[[2]] else s[[1]]
  data.table(line = ln, rows = nrow(te), max_abs_diff = max(abs(pmax(pred, 0) - sub$prediction[match(te$row_id, sub$row_id)])))
}))
rep_ok <- all(replication$max_abs_diff < 1e-6)

# Importance of the final line model (v1)
imp <- rbindlist(lapply(LINES, function(ln) {
  m <- final[[ln]][["v1"]]
  as.data.table(lgb.importance(m$booster))[, .(line = ln, feature = Feature, gain = Gain)][order(-gain)][1:min(.N, 30)]
}))

# Model card ------------------------------------------------------------------------------------------------------
git_commit <- tryCatch({
  h <- system("git rev-parse --short HEAD", intern = TRUE)
  dirty <- length(system("git status --porcelain week1/R/", intern = TRUE)) > 0
  paste0(h, if (dirty) " + uncommitted changes in week1/R/" else "")
}, error = function(e) "unknown")
fwrite(res, file.path(ITER_DIR, "variants.csv")); fwrite(blend, file.path(ITER_DIR, "blend_grid.csv"))
fwrite(selection, file.path(ITER_DIR, "selection.csv")); fwrite(trends, file.path(ITER_DIR, "trends.csv"))
fwrite(imp, file.path(ITER_DIR, "lgb_importance.csv")); fwrite(test_summary, file.path(ITER_DIR, "test_prediction_summary.csv"))
fwrite(replication, file.path(ITER_DIR, "replication.csv"))
wide <- dcast(res, variant + label ~ line + year, value.var = "d2_dev")
wide_rep <- dcast(res, variant + label ~ line + year, value.var = "d2")
by_line_txt <- res[variant %in% selection$variant & line != "combined"][selection, on = .(line, variant)][
  , paste(sprintf("%s %.3f / %.3f", line, d2[year == 2023], d2[year == 2024]), collapse = "; "), ]
write_md(list(
  paste0("# Iteration BEN 4 (`ben_iteration_04`)"), "",
  paste0("**Run id** `", RUN_ID, "` | **Generated** ", format(Sys.time(), "%Y-%m-%d %H:%M"), " | **Git commit** `", git_commit,
         "` | **Submission file** `", basename(sub_file), "` | **MD5** `", md5, "` | **Quick mode** ", QUICK), "",
  paste("**Change in this iteration:**", ITERATION_NOTE), "",
  "## Variants: D2 against developed actuals (selection basis), by line and year", md_table(wide, 4),
  "## Variants: D2 against reported actuals (as earlier BEN cards)", md_table(wide_rep, 4),
  "## Combined, all three lines (one exposure baseline; `d2_flat` = flat-mean baseline)",
  md_table(res[line == "combined", .(variant, year, d2, d2_dev, d2_flat, pred_over_dev)], 4),
  "## Selection (per line, mean developed D2 over 2023 and 2024)", md_table(selection, 4),
  "Selected combined D2:", "", md_table(sel_comb, 4),
  "## Blend weight of the line model (v5)", md_table(blend_pick, 4),
  "## Trend used (line burn, fitted on the fit years, clamped)", md_table(trends, 4),
  "## Ceiling", "",
  paste0("If v4's 2024 per-peril frequency and severity were the true means, the same predictions would score a combined D2 of ",
         paste(round(ceiling_d2, 4), collapse = " / "), " on the 2024 rows (3 simulations; claim sizes resampled from each peril's",
         " 2021-23 claims). Real D2 can only exceed this if the true risk varies more than the model believes."), "",
  "## 2025 predictions, cost per exposure-year", md_table(test_summary, 1),
  "Anchor from `week1/R/ben/ben3_study.R`: motor ~548 (~560 with a large-loss load), buildings ~489, contents ~128.", "",
  "## Top features (gain, final v1 line model)", md_table(imp[, .SD[1:12], by = line], 4),
  "## Replication (saved models reloaded and rescored)", md_table(replication, 6),
  paste0("Replication check: **", if (rep_ok) "passed" else "FAILED", "**"), "",
  "## Settings", "",
  paste0("- Line Tweedie: ", paste(names(LGB_LINE), unlist(LGB_LINE), sep = "=", collapse = ", ")),
  paste0("- Frequency: ", paste(names(LGB_FREQ), unlist(LGB_FREQ), sep = "=", collapse = ", ")),
  paste0("- Severity: ", paste(names(LGB_SEV), unlist(LGB_SEV), sep = "=", collapse = ", ")),
  paste0("- Rounds: early stopping (100) on a 15% policy holdout of the fit years, then refit on all at 1.1x the best round; max ",
         MAX_ROUNDS),
  paste0("- Excluded: ", paste(c(NON_FEATURES, BEN_EXCLUDE), collapse = ", ")),
  paste0("- Trend clamp ", paste(TREND_CLAMP, collapse = " to "), "; claim cap p99.9 per peril (2021-23); loading = 2m-limited / capped cost")
), file.path("..", ITER_DIR), "model_card.md")

hist_row <- data.table(iteration = ITERATION, run_id = RUN_ID, git_commit = git_commit, file = basename(sub_file),
                       models = paste(sprintf("%s=%s", selection$line, selection$variant), collapse = "; "),
                       local_d2_2023 = sel_comb[year == 2023, d2], local_d2_2024 = sel_comb[year == 2024, d2],
                       by_line_2023_2024 = by_line_txt, file_md5 = md5, replication_check = if (rep_ok) "passed" else "FAILED")
rh <- file.path(PATHS$output, STEP, "run_history.csv")
if (!QUICK) fwrite(hist_row, rh, append = file.exists(rh))
log_msg("Done. Card: ", file.path(ITER_DIR, "model_card.md"), " | submission ", sub_file)
