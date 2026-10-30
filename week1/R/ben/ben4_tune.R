# ben/ben4_tune.R -------------------------------------------------------------
# BEN 4 tuning check for the line Tweedie: the first full run's LightGBM line models stopped after few rounds and
# scored below BEN 1's XGBoost (motor 2023 D2 0.022 vs 0.038). Compares, on both folds of one line:
#   categorical encoding (LightGBM native vs levels ordered by a credibility-weighted cost rate, as BEN 1),
#   SAM 3's noise-field exclusions, and tree size / regularisation.
# Run:     Rscript week1/R/ben/ben4_tune.R [line]   (after week1/R/ben/ben4_data.R)
# Outputs: week1/output/ben/ben4/tune_<line>.csv

source("week1/R/0_setup.R")
source("week1/R/ben/ben_helpers.R")
args <- commandArgs(trailingOnly = TRUE)
ln <- if (length(args)) args[1] else "motor"
THREADS <- max(1L, parallel::detectCores() - 2L)
BEN_EXCLUDE <- c("compulsory_excess", "years_with_insurer", "customer_since_year", "campaign_code", "written_premium")
NOISE <- c("discount_applied", "email_domain", "vehicle_colour", "document_preference", "marketing_consent", "branch_id",
           "marketing_segment")                                   # SAM 3 exclusions (besides written_premium, campaign_code)
CRED_K <- 200
loading <- fread(ben_out(file.path("ben4", "loading.csv")))

tweedie_dev <- function(y, mu, p = TWEEDIE_P) {
  mu <- pmax(mu, 1e-9)
  mean(2 * (ifelse(y > 0, y^(2 - p), 0) / ((1 - p) * (2 - p)) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p)))
}
d2_tweedie <- function(y, pred, exposure) 1 - tweedie_dev(y, pred) / tweedie_dev(y, exposure * sum(y) / sum(exposure))

dt <- as.data.table(read_parquet(file.path("data", "week_1", "ben4", paste0("train_", ln, ".parquet"))))
dt[, y_dev := 0]
for (p in PERILS[[ln]]) dt[, y_dev := y_dev + get(paste0("y_cap_", p)) * get(paste0("dev_w_", p)) * loading[line == ln & peril == p, loading]]
dt[, act_dev := 0]
for (p in PERILS[[ln]]) dt[, act_dev := act_dev + get(paste0("y_cost_", p)) * get(paste0("dev_w_", p))]
all_feats <- setdiff(feature_cols(dt, include_new = TRUE), c(BEN_EXCLUDE, grep("^(dev_|act_)", names(dt), value = TRUE)))

# levels ordered by credibility-weighted cost rate on the fit rows; unseen levels -> NA
order_levels <- function(tr, f) {
  r <- tr[, .(y = sum(y_dev), e = sum(exposure)), by = .(lv = as.character(get(f)))][!is.na(lv)]
  m <- sum(r$y) / sum(r$e)
  r[, rate := (y + CRED_K * m) / (e + CRED_K)]
  r[order(rate), lv]
}
make_X <- function(d, feats, cats, enc) {
  vapply(feats, function(f) {
    if (f %in% cats) return(as.numeric(match(as.character(d[[f]]), enc[[f]]) - 1L))
    as.numeric(d[[f]])
  }, numeric(nrow(d)))
}
run <- function(name, params, encoding = "ordered", drop = character(), patience = 100) {
  feats <- setdiff(all_feats, drop)
  cats <- feats[vapply(dt[, ..feats], is.character, logical(1))]
  rbindlist(lapply(c(2023, 2024), function(yr) {
    tr <- dt[policy_year < yr]; va <- dt[policy_year == yr]
    enc <- if (encoding == "ordered") lapply(setNames(cats, cats), function(f) order_levels(tr, f))
           else lapply(setNames(cats, cats), function(f) sort(unique(na.omit(tr[[f]]))))
    Xt <- make_X(tr, feats, cats, enc); Xv <- make_X(va, feats, cats, enc)
    cf <- if (encoding == "native") match(cats, feats) - 1L else NULL
    set.seed(SEED)
    hold <- tr$policy_id %in% sample(unique(tr$policy_id), round(0.15 * uniqueN(tr$policy_id)))
    mk <- function(i) lgb.Dataset(Xt[i, , drop = FALSE], label = tr$y_dev[i] / tr$exposure[i], weight = tr$exposure[i],
                                   categorical_feature = cf, free_raw_data = FALSE, params = list(verbosity = -1))
    p <- modifyList(list(objective = "tweedie", tweedie_variance_power = TWEEDIE_P, verbosity = -1, num_threads = THREADS,
                         deterministic = TRUE, force_col_wise = TRUE, seed = SEED, bagging_freq = 1), params)
    t0 <- Sys.time()
    b <- lgb.train(p, mk(!hold), nrounds = 5000, valids = list(h = mk(hold)), early_stopping_rounds = patience, verbose = -1)
    b2 <- lgb.train(p, mk(rep(TRUE, nrow(tr))), nrounds = max(20L, round(b$best_iter * 1.1)), verbose = -1)
    pr <- predict(b2, Xv) * va$exposure
    pr <- pr * sum(tr$y_dev) / sum(predict(b2, Xt) * tr$exposure)   # balance (no trend here: compares shapes)
    data.table(setting = name, year = yr, rounds = b$best_iter, minutes = round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 2),
               d2 = d2_tweedie(va$y_cost, pr, va$exposure), d2_dev = d2_tweedie(va$act_dev, pr, va$exposure))
  }))
}
base <- list(learning_rate = 0.03, num_leaves = 31, min_data_in_leaf = 800, feature_fraction = 0.7, bagging_fraction = 0.8,
             lambda_l2 = 10, cat_smooth = 50, cat_l2 = 10, min_data_per_group = 300, max_cat_threshold = 32)
small <- modifyList(base, list(num_leaves = 15, max_depth = 5, min_data_in_leaf = 2000, feature_fraction = 0.6, lambda_l2 = 20))
xgbish <- modifyList(base, list(num_leaves = 8, max_depth = 3, min_data_in_leaf = 1000, learning_rate = 0.05))
res <- rbindlist(list(
  run("A first full run: native categoricals", base, "native"),
  run("B ordered categoricals", base),
  run("C ordered + smaller trees", small),
  run("D C + SAM 3 noise fields out", small, drop = NOISE),
  run("E D, depth 3 (as BEN 1 XGBoost)", xgbish, drop = NOISE),
  run("F D, lr 0.02, min leaf 5000, patience 300", modifyList(small, list(learning_rate = 0.02, min_data_in_leaf = 5000)),
      drop = NOISE, patience = 300)
))
res[, line := ln]
fwrite(res, ben_out(file.path("ben4", paste0("tune_", ln, ".csv"))))
print(dcast(res, setting ~ year, value.var = c("d2_dev", "rounds")))
