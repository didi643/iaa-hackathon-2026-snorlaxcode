# 5_models_w2.R --------------------------------------------------------------------------------------------------
# Week 2 step 5: frequency x severity candidates per line x peril for the emerging market (plan: modelling_plan_w2.md,
# evidence: findings_w2.md). Every candidate predicts the ULTIMATE claim count (reported / reported share, step 3).
#   F0 / S0   emerging average rate / mean capped severity                                 (baseline)
#   F1 / S1   emerging-only LightGBM, heavily regularised, all emerging features            (severity only with >= MIN_SEV claims)
#   F2 / S2   transfer, level only: developed LightGBM on the shared features (no weather, region, make_model) x one
#             emerging level factor per peril (findings: the shape transfers, the level does not)
#   F3 / S3   transfer + boost: F2 / S2 as init score, plus a small emerging LightGBM on all emerging features (weather,
#             region, gender, make_model: the parts that cannot transfer)
# Large claims: capped at cap_e = developed p99.5 x emerging/developed severity ratio; the cap loading is taken from the
# developed claims (emerging tails are thin). No trend here (step 6).
# Folds: "valid" fits emerging 2023 (developed 2021-23) and scores emerging 2024; "final" fits emerging 2023-24
# (developed 2021-24) and scores the 2025 test rows.
# Run:  Rscript week2/R/5_models_w2.R        (W2_FOLDS=valid or final to run one)
# Out:  data/week_2/clean/w2_preds_<fold>.parquet (row_id, line, peril, freq_F*, sev_S*), week2/output/5_models/

source("week2/R/0_setup_w2.R")
suppressPackageStartupMessages(library(lightgbm))
STEP <- "5_models"
FOLDS <- strsplit(Sys.getenv("W2_FOLDS", "valid,final"), ",")[[1]]
MIN_SEV <- 300L
NTHREAD <- 12L
WX <- c(WEATHER_VARS, paste0("wx_avg_", WEATHER_VARS))
P_DEV  <- list(objective = "poisson", learning_rate = 0.05, num_leaves = 15, min_data_in_leaf = 500, feature_fraction = 0.7,
               bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = 10, max_bin = 127, num_threads = NTHREAD, seed = SEED, verbose = -1)
P_EMER <- modifyList(P_DEV, list(num_leaves = 7, min_data_in_leaf = 300, learning_rate = 0.03, lambda_l2 = 30))
P_BOOST <- modifyList(P_DEV, list(num_leaves = 4, min_data_in_leaf = 400, learning_rate = 0.02, lambda_l2 = 30))
S_DEV  <- modifyList(P_DEV, list(objective = "gamma", min_data_in_leaf = 200, learning_rate = 0.03, num_leaves = 7))
S_EMER <- modifyList(S_DEV, list(min_data_in_leaf = 100, lambda_l2 = 30))

feat_roles <- fread(file.path(PATHS_W2$output, "2_clean", "features_w2.csv"))
curves <- read_clean_w2("report_lag_curves")
curve_of <- function(ln, p) { k <- paste(ln, p, sep = "."); curves[curves$lp == k, F_developed] }

# encoding shared by both markets: character -> integer codes from one dictionary, logical -> 0/1
build_dict <- function(cols, dts) setNames(lapply(cols, function(cn) {
  v <- unique(unlist(lapply(dts, function(d) if (cn %in% names(d) && (is.character(d[[cn]]) || is.logical(d[[cn]]))) as.character(d[[cn]]))))
  if (length(v)) sort(v[!is.na(v)]) else NULL
}), cols)
to_matrix <- function(d, cols, dict) {
  X <- matrix(NA_real_, nrow(d), length(cols), dimnames = list(NULL, cols))
  for (j in seq_along(cols)) {
    cn <- cols[j]; v <- d[[cn]]
    X[, j] <- if (!is.null(dict[[cn]])) match(as.character(v), dict[[cn]]) - 1 else as.numeric(v)
  }
  X
}
cat_idx <- function(cols, dict) { k <- which(cols %in% names(Filter(Negate(is.null), dict))); if (length(k)) k else NULL }

# LightGBM with early stopping on a 20% policy holdout, then refit on all rows with that many rounds
fit_lgb <- function(X, y, w, pid, params, cats, init = NULL, max_rounds = 3000L, es = 100L) {
  set.seed(SEED); up <- unique(pid); h <- pid %in% sample(up, round(0.2 * length(up)))
  mk <- function(k) lgb.Dataset(X[k, , drop = FALSE], label = y[k], weight = if (is.null(w)) NULL else w[k],
                                init_score = if (is.null(init)) NULL else init[k], categorical_feature = cats, free_raw_data = FALSE)
  dtr <- mk(!h)
  dva <- lgb.Dataset.create.valid(dtr, X[h, , drop = FALSE], label = y[h], weight = if (is.null(w)) NULL else w[h],
                                  init_score = if (is.null(init)) NULL else init[h])
  m <- lgb.train(params, dtr, nrounds = max_rounds, valids = list(v = dva), early_stopping_rounds = es, verbose = -1)
  r <- max(m$best_iter, 1L)
  list(model = lgb.train(params, mk(rep(TRUE, length(y))), nrounds = r, verbose = -1), rounds = r)
}
raw_pred <- function(fit, X) predict(fit$model, X, type = "raw")

run_fold <- function(fold) {
  e_years <- if (fold == "valid") 2023L else 2023:2024
  d_years <- if (fold == "valid") 2021:2023 else 2021:2024
  shares <- read_clean_w2("emerging_report_shares")
  preds <- list(); info <- list()
  for (ln in LINES) {
    log_msg(fold, " ", ln)
    etr_all <- read_clean_w2(paste0("emerging_train_", ln))
    etr_all <- merge(etr_all, shares[line == ln, c("row_id", paste0("s_", PERILS[[ln]])), with = FALSE], by = "row_id", sort = FALSE)
    etr <- etr_all[policy_year %in% e_years]
    esc <- if (fold == "valid") etr_all[policy_year == 2024L] else read_clean_w2(paste0("emerging_test_", ln))
    dtr <- read_clean_w2(paste0("developed_train_", ln))[policy_year %in% d_years]
    fr <- feat_roles[line == ln & role == "feature"]
    f_shared <- setdiff(fr[emerging & developed, column], c(WX, "region", "make_model", "customer_since_year"))
    f_emer <- setdiff(fr[emerging == TRUE, column], "customer_since_year")
    dict <- build_dict(union(f_shared, f_emer), list(etr_all, esc, dtr))
    Xd <- to_matrix(dtr, f_shared, dict); Xe_s <- to_matrix(etr, f_shared, dict); Xs_s <- to_matrix(esc, f_shared, dict)
    Xe_a <- to_matrix(etr, f_emer, dict); Xs_a <- to_matrix(esc, f_emer, dict)
    cs <- cat_idx(f_shared, dict); ca <- cat_idx(f_emer, dict)
    ce_all <- read_clean_w2("emerging_claims_matched")[line == ln & counts & net_cost > 0 & row_id %in% etr$row_id]
    cd_all <- read_clean_w2("developed_claims_matched")[line == ln & counts & net_cost > 0 & row_id %in% dtr$row_id]
    out <- esc[, .(row_id, line = ln, exposure)]
    for (p in PERILS[[ln]]) {
      t0 <- Sys.time()
      # ---- frequency (label = claims / (exposure x share), weight = exposure x share -> ultimate rate per exposure)
      n_e <- etr[[paste0("y_n_", p)]]; w_e <- etr$exposure * etr[[paste0("s_", p)]]
      sd_ <- row_share(curve_of(ln, p), dtr$period_start, dtr$period_end)
      n_d <- dtr[[paste0("y_n_", p)]]; w_d <- dtr$exposure * sd_
      f0 <- sum(n_e) / sum(w_e)
      m1 <- fit_lgb(Xe_a, n_e / w_e, w_e, etr$policy_id, P_EMER, ca)
      md <- fit_lgb(Xd, n_d / w_d, w_d, dtr$policy_id, P_DEV, cs)
      base_tr <- exp(raw_pred(md, Xe_s)); base_sc <- exp(raw_pred(md, Xs_s))
      lev_f <- sum(n_e) / sum(base_tr * w_e)
      m3 <- fit_lgb(Xe_a, n_e / w_e, w_e, etr$policy_id, P_BOOST, ca, init = log(lev_f * base_tr))
      set(out, j = paste0(p, "_F0"), value = f0 * esc$exposure)
      set(out, j = paste0(p, "_F1"), value = exp(raw_pred(m1, Xs_a)) * esc$exposure)
      set(out, j = paste0(p, "_F2"), value = lev_f * base_sc * esc$exposure)
      set(out, j = paste0(p, "_F3"), value = exp(log(lev_f * base_sc) + raw_pred(m3, Xs_a)) * esc$exposure)
      # ---- severity (capped; cap loading from the developed claims)
      cd <- cd_all[peril == p]; ce <- ce_all[peril == p]
      cap_d <- quantile(cd$net_cost, 0.995, names = FALSE)
      load <- sum(cd$net_cost) / sum(pmin(cd$net_cost, cap_d))
      r0 <- mean(pmin(ce$net_cost, cap_d)) / mean(pmin(cd$net_cost, cap_d))
      cap_e <- cap_d * r0
      ye <- pmin(ce$net_cost, cap_e); yd <- pmin(cd$net_cost, cap_d)
      re <- match(ce$row_id, etr$row_id); rd <- match(cd$row_id, dtr$row_id)
      s0 <- mean(ye)
      ms <- fit_lgb(Xd[rd, , drop = FALSE], yd, NULL, cd$policy_id, S_DEV, cs)
      sb_tr <- exp(raw_pred(ms, Xe_s[re, , drop = FALSE])); sb_sc <- exp(raw_pred(ms, Xs_s))
      lev_s <- sum(ye) / sum(sb_tr)
      if (nrow(ce) >= MIN_SEV) {
        s1 <- fit_lgb(Xe_a[re, , drop = FALSE], ye, NULL, ce$policy_id, S_EMER, ca)
        s3 <- fit_lgb(Xe_a[re, , drop = FALSE], ye, NULL, ce$policy_id, modifyList(S_EMER, list(learning_rate = 0.02)), ca,
                      init = log(lev_s * sb_tr))
        sev1 <- exp(raw_pred(s1, Xs_a)); sev3 <- exp(log(lev_s * sb_sc) + raw_pred(s3, Xs_a)); r1 <- s1$rounds; r3 <- s3$rounds
        bal1 <- mean(ye) / mean(exp(raw_pred(s1, Xe_a[re, , drop = FALSE])))
        bal3 <- mean(ye) / mean(exp(log(lev_s * sb_tr) + raw_pred(s3, Xe_a[re, , drop = FALSE])))
        sev1 <- sev1 * bal1; sev3 <- sev3 * bal3
      } else { sev1 <- rep(s0, nrow(esc)); sev3 <- lev_s * sb_sc; r1 <- r3 <- NA_integer_ }
      set(out, j = paste0(p, "_S0"), value = s0 * load)
      set(out, j = paste0(p, "_S1"), value = sev1 * load)
      set(out, j = paste0(p, "_S2"), value = lev_s * sb_sc * load)
      set(out, j = paste0(p, "_S3"), value = sev3 * load)
      info[[paste(ln, p)]] <- data.table(fold, line = ln, peril = p, claims_e = sum(n_e), sev_claims_e = nrow(ce),
        rate_F0 = f0, level_freq = lev_f, rounds_F1 = m1$rounds, rounds_dev = md$rounds, rounds_F3 = m3$rounds,
        cap_d = cap_d, sev_ratio_r0 = r0, cap_e = cap_e, cap_loading = load, level_sev = lev_s, rounds_S1 = r1, rounds_S3 = r3,
        rounds_dev_sev = ms$rounds, minutes = round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1))
      log_msg("  ", p, ": freq level ", round(lev_f, 3), " (rounds dev/F1/F3 ", md$rounds, "/", m1$rounds, "/", m3$rounds,
              "), sev level ", round(lev_s, 3), ", cap ", round(cap_e))
    }
    preds[[ln]] <- out
    rm(dtr, Xd); gc(verbose = FALSE)
  }
  long <- rbindlist(lapply(preds, function(o) {
    ln <- o$line[1]
    rbindlist(lapply(PERILS[[ln]], function(p) {
      x <- o[, c("row_id", "line", "exposure", grep(paste0("^", p, "_[FS][0-9]$"), names(o), value = TRUE)), with = FALSE]
      setnames(x, sub(paste0("^", p, "_"), "", names(x))); x[, peril := p]
    }))
  }))
  write_clean_w2(long, paste0("w2_preds_", fold))
  info <- rbindlist(info); save_csv_w2(info, STEP, paste0("fit_info_", fold, ".csv"))
  list(preds = long, info = info)
}

res <- setNames(lapply(FOLDS, run_fold), FOLDS)

# Validation scores: line D2 on 2024 (developed basis, and reported basis with predictions x reported share) ---------
if ("valid" %in% FOLDS) {
  pv <- res$valid$preds
  shares <- read_clean_w2("emerging_report_shares")
  combos <- list(burn = c("F0", "S0"), emerging_only = c("F1", "S1"), transfer_level = c("F2", "S2"), transfer_boost = c("F3", "S3"),
                 boost_freq_level_sev = c("F3", "S2"), level_freq_boost_sev = c("F2", "S3"))
  act <- rbindlist(lapply(LINES, function(ln) {
    tr <- read_clean_w2(paste0("emerging_train_", ln))[policy_year == 2024L]
    sh <- shares[line == ln][match(tr$row_id, row_id)]
    rbindlist(lapply(PERILS[[ln]], function(p) data.table(row_id = tr$row_id, line = ln, peril = p, y_rep = tr[[paste0("y_cost_", p)]],
                                                          share = sh[[paste0("s_", p)]])))
  }))
  pv <- merge(pv, act, by = c("row_id", "line", "peril"))
  pv[, y_dev := y_rep / share]
  scores <- rbindlist(lapply(names(combos), function(cb) {
    k <- combos[[cb]]; x <- copy(pv)[, pred := get(k[1]) * get(k[2])]
    byrow <- x[, .(pred = sum(pred), pred_rep = sum(pred * share), y_dev = sum(y_dev), y_rep = sum(y_rep), exposure = exposure[1]), by = .(line, row_id)]
    rbind(byrow[, .(d2_developed = d2_tweedie(y_dev, pred, exposure), d2_reported = d2_tweedie(y_rep, pred_rep, exposure),
                    ae_developed = sum(y_dev) / sum(pred)), by = line],
          byrow[, .(line = "ALL", d2_developed = d2_tweedie(y_dev, pred, exposure), d2_reported = d2_tweedie(y_rep, pred_rep, exposure),
                    ae_developed = sum(y_dev) / sum(pred))])[, model := cb]
  }))
  setcolorder(scores, c("model", "line"))
  peril_scores <- rbindlist(lapply(names(combos), function(cb) {
    k <- combos[[cb]]; x <- copy(pv)[, pred := get(k[1]) * get(k[2])]
    x[, .(d2_developed = d2_tweedie(y_dev, pred, exposure), ae_developed = sum(y_dev) / sum(pred)), by = .(line, peril)][, model := cb]
  }))
  save_csv_w2(scores, STEP, "validation_line_scores.csv"); save_csv_w2(peril_scores, STEP, "validation_peril_scores.csv")
  write_md_w2(list(
    "# Week 2 - Step 5: candidate models, validation 2023 -> 2024", "",
    paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "by `week2/R/5_models_w2.R`. Fit on emerging 2023 (developed 2021-23), scored on emerging 2024."), "",
    "Combos (frequency x severity):",
    "- `burn`: emerging averages",
    "- `emerging_only`: emerging LightGBM",
    "- `transfer_level`: developed LightGBM x emerging level per peril",
    "- `transfer_boost`: that plus a small emerging LightGBM",
    "",
    "Actuals: `developed` = reported / reported share (step 3). For `reported`, predictions are multiplied by the reported share.", "",
    "## Line D2 (Tweedie p = 1.5)", "", md_table(dcast(scores, model ~ line, value.var = "d2_developed"), 4),
    "Reported basis:", "", md_table(dcast(scores, model ~ line, value.var = "d2_reported"), 4),
    "A/E (developed actual / predicted):", "", md_table(dcast(scores, model ~ line, value.var = "ae_developed"), 3),
    "## Peril D2 (developed basis)", "", md_table(dcast(peril_scores, line + peril ~ model, value.var = "d2_developed"), 4),
    "## Fit details", "", md_table(res$valid$info, 3)
  ), STEP, "validation_report.md")
  print(dcast(scores, model ~ line, value.var = "d2_developed"))
}
log_msg("Step 5 done: ", paste(FOLDS, collapse = ", "))
