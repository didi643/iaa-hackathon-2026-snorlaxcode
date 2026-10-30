# 5b_joint_w2.R --------------------------------------------------------------------------------------------------
# Week 2 step 5b: improvement experiments after the first public score (0.14860, step 6 model). Steps 5 / 6 are kept
# unchanged; this script adds new candidates and scores them on the same validation fold (fit 2023, score 2024).
#   J1  joint LightGBM per peril: developed + emerging rows stacked, `market_e` flag, ALL features (weather, wx_avg,
#       region, make_model, gender) - the trees learn which parts of the developed shape carry over instead of one level
#   J2  J1 with emerging rows up-weighted (x W_EMER)
#   J3  J2 with the week 1 C5 settings: XGBoost, per-peril depth / min_child_weight from assumptions_wendy07_final2.xlsx,
#       eta 0.05, subsample / colsample 0.8, lambda 5, BAGS bags (own policy holdout each)
#   B4  step 5 transfer (developed LightGBM on shared features x emerging level) + a STRONGER emerging boost
#       (step 5's boost stopped after 1-26 rounds for most perils)
# Every joint model is balanced per peril to the emerging training rows. Variants "<model>c" also take step 6's
# credibility adjustment (k_freq 200, k_sev 100), which shrinks single-year peril levels (2023 fire spike).
# Labels, weights, caps and the cap loading are the same as step 5 (ultimate counts via the step 3 reported shares).
# Scored like step 6 (developed + reported basis, new-business rows, paired policy bootstrap vs the step 6 model), plus
# 50/50 blends with step 6 and a new-business uplift sensitivity.
# Run:  Rscript week2/R/5b_joint_w2.R          (W2_FOLDS=valid (default) | final | valid,final)
# Out:  data/week_2/clean/w2_joint_preds_<fold>.parquet (per model: cost, <model>_f expected claims, <model>_s severity),
#       week2/output/5b_joint/

source("week2/R/0_setup_w2.R")
suppressPackageStartupMessages({ library(lightgbm); library(xgboost); library(readxl) })
STEP <- "5b_joint"
FOLDS <- strsplit(Sys.getenv("W2_FOLDS", "valid"), ",")[[1]]
NTHREAD <- 12L
W_EMER <- as.numeric(Sys.getenv("W2_W_EMER", "5"))
BAGS <- as.integer(Sys.getenv("W2_BAGS", "3"))
N_BOOT <- 300L
MIN_SEV <- 300L
WX <- c(WEATHER_VARS, paste0("wx_avg_", WEATHER_VARS))
P_J  <- list(objective = "poisson", learning_rate = 0.05, num_leaves = 15, min_data_in_leaf = 500, feature_fraction = 0.7,
             bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = 10, max_bin = 127, num_threads = NTHREAD, seed = SEED, verbose = -1)
S_J  <- modifyList(P_J, list(objective = "gamma", min_data_in_leaf = 200, learning_rate = 0.03, num_leaves = 7))
P_B4 <- modifyList(P_J, list(num_leaves = 15, min_data_in_leaf = 150, learning_rate = 0.05, lambda_l2 = 5))   # stronger boost
S_B4 <- modifyList(S_J, list(min_data_in_leaf = 60, learning_rate = 0.05, lambda_l2 = 5))
C5 <- as.data.table(read_excel("week1/final_week1_R_Script/inputs/assumptions_wendy07_final2.xlsx", "Model_Spec"))[!is.na(peril)]
c5_of <- function(ln, p) { s <- C5[line == ln & peril == p]
  list(fd = s$freq_max_depth, fm = s$freq_min_child_weight, sd = if (s$sev_max_depth > 0) s$sev_max_depth else 2, sm = 100) }

feat_roles <- fread(file.path(PATHS_W2$output, "2_clean", "features_w2.csv"))
curves <- read_clean_w2("report_lag_curves")
curve_of <- function(ln, p) { k <- paste(ln, p, sep = "."); curves[curves$lp == k, F_developed] }

# encoding (as step 5): one dictionary over both markets, character -> integer codes, logical -> 0/1
build_dict <- function(cols, dts) setNames(lapply(cols, function(cn) {
  v <- unique(unlist(lapply(dts, function(d) if (cn %in% names(d) && (is.character(d[[cn]]) || is.logical(d[[cn]]))) as.character(d[[cn]]))))
  if (length(v)) sort(v[!is.na(v)]) else NULL
}), cols)
to_matrix <- function(d, cols, dict) {
  X <- matrix(NA_real_, nrow(d), length(cols), dimnames = list(NULL, cols))
  for (j in seq_along(cols)) {
    cn <- cols[j]; v <- if (cn %in% names(d)) d[[cn]] else rep(NA, nrow(d))
    X[, j] <- if (!is.null(dict[[cn]])) match(as.character(v), dict[[cn]]) - 1 else as.numeric(v)
  }
  X
}
cat_idx <- function(cols, dict) { k <- which(cols %in% names(Filter(Negate(is.null), dict))); if (length(k)) k else NULL }
holdout <- function(pid, seed) { set.seed(seed); up <- unique(pid); pid %in% sample(up, round(0.2 * length(up))) }

# LightGBM: early stopping on a 20% policy holdout, refit on all rows with that many rounds (as step 5)
fit_lgb <- function(X, y, w, pid, params, cats, init = NULL, max_rounds = 3000L, es = 100L) {
  h <- holdout(pid, SEED)
  mk <- function(k) lgb.Dataset(X[k, , drop = FALSE], label = y[k], weight = if (is.null(w)) NULL else w[k],
                                init_score = if (is.null(init)) NULL else init[k], categorical_feature = cats, free_raw_data = FALSE)
  dtr <- mk(!h)
  dva <- lgb.Dataset.create.valid(dtr, X[h, , drop = FALSE], label = y[h], weight = if (is.null(w)) NULL else w[h],
                                  init_score = if (is.null(init)) NULL else init[h])
  m <- lgb.train(params, dtr, nrounds = max_rounds, valids = list(v = dva), early_stopping_rounds = es, verbose = -1)
  r <- max(m$best_iter, 1L)
  list(model = lgb.train(params, mk(rep(TRUE, length(y))), nrounds = r, verbose = -1), rounds = r)
}
lgb_raw <- function(fit, X) predict(fit$model, X, type = "raw")

# XGBoost, week 1 C5 style: each bag = own policy holdout + seed, early stopping 50, prediction = mean over bags
fit_xgb <- function(X, y, w, pid, objective, depth, mcw) {
  ms <- lapply(seq_len(BAGS), function(b) {
    h <- holdout(pid, SEED + b - 1L)
    dtr <- xgb.DMatrix(X[!h, , drop = FALSE], label = y[!h], weight = if (is.null(w)) NULL else w[!h], nthread = NTHREAD)
    dva <- xgb.DMatrix(X[h, , drop = FALSE], label = y[h], weight = if (is.null(w)) NULL else w[h], nthread = NTHREAD)
    xgb.train(params = list(objective = objective, learning_rate = 0.05, max_depth = depth, min_child_weight = mcw, subsample = 0.8,
                            colsample_bytree = 0.8, reg_lambda = 5, tree_method = "hist", nthread = NTHREAD, seed = SEED + b - 1L),
              data = dtr, nrounds = 3000L, evals = list(holdout = dva), early_stopping_rounds = 50L, verbose = 0)
  })
  list(models = ms, rounds = paste(vapply(ms, function(m) { b <- xgb.attr(m, "best_iteration"); if (is.null(b)) NA_integer_ else as.integer(b) }, 1L), collapse = "/"))
}
xgb_resp <- function(fit, X) rowMeans(vapply(fit$models, function(m) predict(m, X), numeric(nrow(X))))

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
    etr[, market_e := 1L]; esc[, market_e := 1L]; dtr[, market_e := 0L]
    fr <- feat_roles[line == ln & role == "feature"]
    f_all <- c("market_e", setdiff(fr[emerging == TRUE | developed == TRUE, column], "customer_since_year"))
    f_shared <- setdiff(fr[emerging & developed, column], c(WX, "region", "make_model", "customer_since_year"))
    f_emer <- setdiff(fr[emerging == TRUE, column], "customer_since_year")
    dict <- build_dict(union(f_all, f_shared), list(etr_all, esc, dtr))
    XdA <- to_matrix(dtr, f_all, dict); XeA <- to_matrix(etr, f_all, dict); XsA <- to_matrix(esc, f_all, dict)
    Xd_s <- to_matrix(dtr, f_shared, dict); Xe_s <- to_matrix(etr, f_shared, dict); Xs_s <- to_matrix(esc, f_shared, dict)
    Xe_e <- to_matrix(etr, f_emer, dict); Xs_e <- to_matrix(esc, f_emer, dict)
    cA <- cat_idx(f_all, dict); cS <- cat_idx(f_shared, dict); cE <- cat_idx(f_emer, dict)
    XJ <- rbind(XdA, XeA); pidJ <- c(paste0("d", dtr$policy_id), paste0("e", etr$policy_id))
    nd <- nrow(dtr); ie <- nd + seq_len(nrow(etr))
    ce_all <- read_clean_w2("emerging_claims_matched")[line == ln & counts & net_cost > 0 & row_id %in% etr$row_id]
    cd_all <- read_clean_w2("developed_claims_matched")[line == ln & counts & net_cost > 0 & row_id %in% dtr$row_id]
    out <- esc[, .(row_id, line = ln, exposure)]
    for (p in PERILS[[ln]]) {
      t0 <- Sys.time(); hp <- c5_of(ln, p)
      # ---- frequency: label = ultimate rate, weight = exposure x reported share (x W_EMER for emerging in J2 / J3)
      n_e <- etr[[paste0("y_n_", p)]]; w_e <- etr$exposure * etr[[paste0("s_", p)]]
      n_d <- dtr[[paste0("y_n_", p)]]; w_d <- dtr$exposure * row_share(curve_of(ln, p), dtr$period_start, dtr$period_end)
      yJ <- c(n_d / w_d, n_e / w_e); wJ1 <- c(w_d, w_e); wJ2 <- c(w_d, w_e * W_EMER)
      bal <- function(pe_tr) sum(n_e) / sum(pe_tr * w_e)      # balance to the emerging training rows
      j1 <- fit_lgb(XJ, yJ, wJ1, pidJ, P_J, cA); f1 <- bal(exp(lgb_raw(j1, XeA))) * exp(lgb_raw(j1, XsA))
      j2 <- fit_lgb(XJ, yJ, wJ2, pidJ, P_J, cA); f2 <- bal(exp(lgb_raw(j2, XeA))) * exp(lgb_raw(j2, XsA))
      j3 <- fit_xgb(XJ, yJ, wJ2, pidJ, "count:poisson", hp$fd, hp$fm); f3 <- bal(xgb_resp(j3, XeA)) * xgb_resp(j3, XsA)
      md <- fit_lgb(Xd_s, n_d / w_d, w_d, dtr$policy_id, P_J, cS)
      b_tr <- exp(lgb_raw(md, Xe_s)); lev_f <- sum(n_e) / sum(b_tr * w_e)
      b4 <- fit_lgb(Xe_e, n_e / w_e, w_e, etr$policy_id, P_B4, cE, init = log(lev_f * b_tr))
      f4 <- exp(log(lev_f * exp(lgb_raw(md, Xs_s))) + lgb_raw(b4, Xs_e))
      # ---- severity: capped at cap_d (developed) / cap_e (emerging, = cap_d x severity ratio), developed cap loading
      cd <- cd_all[peril == p]; ce <- ce_all[peril == p]
      cap_d <- quantile(cd$net_cost, 0.995, names = FALSE)
      load <- sum(cd$net_cost) / sum(pmin(cd$net_cost, cap_d))
      cap_e <- cap_d * mean(pmin(ce$net_cost, cap_d)) / mean(pmin(cd$net_cost, cap_d))
      ye <- pmin(ce$net_cost, cap_e); yd <- pmin(cd$net_cost, cap_d)
      re <- match(ce$row_id, etr$row_id); rd <- match(cd$row_id, dtr$row_id)
      XS <- rbind(XdA[rd, , drop = FALSE], XeA[re, , drop = FALSE]); pidS <- c(paste0("d", cd$policy_id), paste0("e", ce$policy_id))
      yS <- c(yd, ye); wS2 <- c(rep(1, length(yd)), rep(W_EMER, length(ye))); XeS <- XeA[re, , drop = FALSE]
      sbal <- function(pe_tr) mean(ye) / mean(pe_tr)
      s1 <- fit_lgb(XS, yS, NULL, pidS, S_J, cA); sv1 <- sbal(exp(lgb_raw(s1, XeS))) * exp(lgb_raw(s1, XsA))
      s2 <- fit_lgb(XS, yS, wS2, pidS, S_J, cA); sv2 <- sbal(exp(lgb_raw(s2, XeS))) * exp(lgb_raw(s2, XsA))
      s3 <- fit_xgb(XS, yS, wS2, pidS, "reg:gamma", hp$sd, hp$sm); sv3 <- sbal(xgb_resp(s3, XeS)) * xgb_resp(s3, XsA)
      ms <- fit_lgb(Xd_s[rd, , drop = FALSE], yd, NULL, cd$policy_id, S_J, cS)
      sb_tr <- exp(lgb_raw(ms, Xe_s[re, , drop = FALSE])); lev_s <- sum(ye) / sum(sb_tr)
      if (nrow(ce) >= MIN_SEV) {
        s4 <- fit_lgb(Xe_e[re, , drop = FALSE], ye, NULL, ce$policy_id, S_B4, cE, init = log(lev_s * sb_tr))
        sv4 <- sbal(exp(log(lev_s * sb_tr) + lgb_raw(s4, Xe_e[re, , drop = FALSE]))) * exp(log(lev_s * exp(lgb_raw(ms, Xs_s))) + lgb_raw(s4, Xs_e))
        r4 <- s4$rounds
      } else { sv4 <- lev_s * exp(lgb_raw(ms, Xs_s)); r4 <- NA_integer_ }
      for (k in 1:4) {   # cost, plus its frequency (expected ultimate claims) and severity (incl. cap loading) parts
        m <- c("J1", "J2", "J3", "B4")[k]; fq <- list(f1, f2, f3, f4)[[k]] * esc$exposure; sv <- list(sv1, sv2, sv3, sv4)[[k]] * load
        set(out, j = paste0(p, "_", m), value = fq * sv)
        set(out, j = paste0(p, "_", m, "_f"), value = fq); set(out, j = paste0(p, "_", m, "_s"), value = sv)
      }
      info[[paste(ln, p)]] <- data.table(fold, line = ln, peril = p, claims_e = sum(n_e), sev_claims_e = nrow(ce),
        rounds_J1 = j1$rounds, rounds_J2 = j2$rounds, rounds_J3 = j3$rounds, rounds_B4 = b4$rounds,
        rounds_sJ1 = s1$rounds, rounds_sJ2 = s2$rounds, rounds_sJ3 = s3$rounds, rounds_sB4 = r4,
        minutes = round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1))
      log_msg("  ", p, ": rounds freq J1/J2/J3/B4 ", j1$rounds, "/", j2$rounds, "/", j3$rounds, "/", b4$rounds,
              ", sev ", s1$rounds, "/", s2$rounds, "/", s3$rounds, "/", r4, " (", info[[paste(ln, p)]]$minutes, " min)")
    }
    preds[[ln]] <- out
    rm(dtr, XdA, Xd_s, XJ); gc(verbose = FALSE)
  }
  long <- rbindlist(lapply(preds, function(o) {
    ln <- o$line[1]
    rbindlist(lapply(PERILS[[ln]], function(p) {
      x <- o[, c("row_id", "line", "exposure", grep(paste0("^", p, "_(J[0-9]|B4)(_f|_s)?$"), names(o), value = TRUE)), with = FALSE]
      setnames(x, sub(paste0("^", p, "_"), "", names(x))); x[, peril := p]
    }))
  }))
  write_clean_w2(long, paste0("w2_joint_preds_", fold))
  info <- rbindlist(info); save_csv_w2(info, STEP, paste0("fit_info_", fold, ".csv"))
  list(preds = long, info = info)
}

res <- setNames(lapply(FOLDS, run_fold), FOLDS)

# Validation: compare with the step 6 model (k_freq 200, k_sev 100, avg, no trend) -----------------------------------
if ("valid" %in% FOLDS) {
  pj <- res$valid$preds
  info5 <- fread(file.path(PATHS_W2$output, "5_models", "fit_info_valid.csv"))
  p5 <- read_clean_w2("w2_preds_valid")
  # step 6 credibility (copied from 6_blend_w2.R so this script does not change it)
  s0 <- p5[, .(s0 = S0[1]), by = .(line, peril)]
  lv <- merge(info5, s0, by = c("line", "peril"))
  lv[, sum_ye := sev_claims_e * s0 / cap_loading][, `:=`(E_f = claims_e / level_freq, E_s = sum_ye / level_sev)]
  lv[, `:=`(line_f = sum(claims_e) / sum(E_f), line_s = sum(sum_ye) / sum(E_s)), by = line]
  cred <- function(lev, n, line_lev, k) { z <- n / (n + k); z * lev + (1 - z) * line_lev }
  lv[, adj := cred(level_freq, claims_e, line_f, 200) / level_freq * cred(level_sev, sev_claims_e, line_s, 100) / level_sev]
  x <- merge(p5[, .(row_id, line, peril, exposure, S6 = 0.5 * (F2 + F3) * 0.5 * (S2 + S3))], pj[, !"exposure"], by = c("row_id", "line", "peril"))
  x <- merge(x, lv[, .(line, peril, adj)], by = c("line", "peril"))
  x[, S6 := S6 * adj]
  for (m in c("J1", "J2", "J3", "B4")) set(x, j = paste0(m, "c"), value = x[[m]] * x$adj)
  x[, `:=`(J3c_B4c = 0.5 * (J3c + B4c), S6_J2c = 0.5 * (S6 + J2c), S6_J3c = 0.5 * (S6 + J3c), S6_B4c = 0.5 * (S6 + B4c),
           S6_J3c_B4c = (S6 + J3c + B4c) / 3, J1_J2_J3 = (J1 + J2 + J3) / 3)]
  shares <- read_clean_w2("emerging_report_shares")
  act <- rbindlist(lapply(LINES, function(ln) {
    tr <- read_clean_w2(paste0("emerging_train_", ln))[policy_year == 2024L]
    sh <- shares[line == ln][match(tr$row_id, row_id)]
    rbindlist(lapply(PERILS[[ln]], function(p) data.table(row_id = tr$row_id, line = ln, peril = p, y_rep = tr[[paste0("y_cost_", p)]],
                                                          share = sh[[paste0("s_", p)]], new_business = tr$new_business, policy_id = tr$policy_id)))
  }))
  x <- merge(x, act, by = c("row_id", "line", "peril")); x[, y_dev := y_rep / share]
  MODELS <- c("S6", "J1", "J2", "J3", "B4", "J1c", "J2c", "J3c", "B4c", "J1_J2_J3", "J3c_B4c", "S6_J2c", "S6_J3c", "S6_B4c", "S6_J3c_B4c")
  rows <- x[, c(list(exposure = exposure[1], nb = new_business[1], policy_id = policy_id[1], y_dev = sum(y_dev), y_rep = sum(y_rep)),
                lapply(.SD, sum), setNames(lapply(.SD, function(v) sum(v * share)), paste0(MODELS, "_rep"))),
            by = .(line, row_id), .SDcols = MODELS]
  sc <- function(r, lab) rbindlist(lapply(MODELS, function(m) rbind(
    r[, .(d2_dev = d2_tweedie(y_dev, get(m), exposure), d2_rep = d2_tweedie(y_rep, get(paste0(m, "_rep")), exposure), ae = sum(y_dev) / sum(get(m))), by = line],
    r[, .(line = "ALL", d2_dev = d2_tweedie(y_dev, get(m), exposure), d2_rep = d2_tweedie(y_rep, get(paste0(m, "_rep")), exposure), ae = sum(y_dev) / sum(get(m)))])[, `:=`(model = m, rows = lab)]))
  scores <- rbind(sc(rows, "all"), sc(rows[nb == TRUE], "new_business"))
  peril_sc <- rbindlist(lapply(MODELS[1:9], function(m) x[, .(d2_dev = d2_tweedie(y_dev, get(m), exposure), ae = sum(y_dev) / sum(get(m))), by = .(line, peril)][, model := m]))
  # paired policy bootstrap: gain in ALL D2 (developed basis) vs S6
  unit_dev <- function(y, mu, p = 1.5) { mu <- pmax(mu, 1e-9); 2 * (ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p)) }
  rows[, pkey := paste(line, policy_id)]
  set.seed(SEED); up <- unique(rows$pkey)
  draws <- lapply(seq_len(N_BOOT), function(b) { s <- table(sample(up, length(up), replace = TRUE)); w <- as.numeric(s[match(rows$pkey, names(s))]); w[is.na(w)] <- 0; w })
  wd2 <- function(m, w) { mu0 <- sum(w * rows$y_dev) / sum(w * rows$exposure) * rows$exposure
    1 - sum(w * unit_dev(rows$y_dev, rows[[m]])) / sum(w * unit_dev(rows$y_dev, mu0)) }
  boot <- rbindlist(lapply(MODELS[-1], function(m) { g <- vapply(draws, function(w) wd2(m, w) - wd2("S6", w), 0)
    data.table(model = m, gain_vs_S6 = mean(g), se = sd(g), p_better = mean(g > 0)) }))
  # new-business uplift: multiply the new-business rows by u, score ALL and new-business rows
  nb_sens <- rbindlist(lapply(c("S6", "S6_J3c_B4c", "J3c"), function(m) rbindlist(lapply(seq(0.8, 1.2, 0.05), function(u) {
    pr <- rows[[m]] * ifelse(rows$nb, u, 1)
    data.table(model = m, nb_uplift = u, d2_all = d2_tweedie(rows$y_dev, pr, rows$exposure),
               d2_nb = rows[nb == TRUE, d2_tweedie(y_dev, pr[rows$nb], exposure)], ae_nb = rows[nb == TRUE, sum(y_dev)] / sum(pr[rows$nb]))
  }))))
  save_csv_w2(scores, STEP, "validation_scores.csv"); save_csv_w2(peril_sc, STEP, "validation_peril_scores.csv")
  save_csv_w2(boot, STEP, "bootstrap_vs_S6.csv"); save_csv_w2(nb_sens, STEP, "new_business_uplift.csv")
  wide <- function(r, v) dcast(scores[rows == r], model ~ line, value.var = v)[match(MODELS, model)]
  write_md_w2(list(
    "# Week 2 - Step 5b: joint models and stronger boost, validation 2023 -> 2024", "",
    paste0("Generated ", format(Sys.time(), "%Y-%m-%d %H:%M"), " by `week2/R/5b_joint_w2.R` (W_EMER = ", W_EMER, ", XGBoost bags = ", BAGS, ")."), "",
    "- `S6`: step 6 model (submitted, public 0.14860)",
    "- `J1` / `J2`: joint LightGBM, emerging weight 1 / W_EMER",
    "- `J3`: joint XGBoost with the week 1 C5 settings",
    "- `B4`: step 5 transfer with a stronger emerging boost",
    "- suffix `c`: step 6 credibility adjustment",
    "- `a_b`: equal-weight average",
    "",
    "## D2, developed basis, all 2024 rows", "", md_table(wide("all", "d2_dev"), 4),
    "## D2, reported basis, all 2024 rows", "", md_table(wide("all", "d2_rep"), 4),
    "## A/E (developed basis)", "", md_table(wide("all", "ae"), 3),
    "## D2, new-business rows only (2025 is 76% new business)", "", md_table(wide("new_business", "d2_dev"), 4),
    paste0("## Paired policy bootstrap (", N_BOOT, " draws): gain in ALL D2 vs S6"), "", md_table(boot, 4),
    "## New-business uplift sensitivity (new-business predictions x u)", "", md_table(dcast(nb_sens, nb_uplift ~ model, value.var = "d2_all"), 4),
    "New-business rows only:", "", md_table(dcast(nb_sens, nb_uplift ~ model, value.var = "d2_nb"), 4),
    "## Peril D2 (developed basis)", "", md_table(dcast(peril_sc, line + peril ~ model, value.var = "d2_dev"), 4),
    "## Fit details", "", md_table(res$valid$info, 2)
  ), STEP, "validation_report.md")
  print(wide("all", "d2_dev")); print(boot)
}
log_msg("Step 5b done: ", paste(FOLDS, collapse = ", "))
