# 23_nb_pooled_model.R -------------------------------------------------------------------------------------------------
# Purpose : NB round (27 Oct 2026), direction 7: pooled developed + emerging NEW-BUSINESS residual model, blended into the
#           current best run on new-business rows only. Per line, an xgboost Tweedie (p 1.5) cost model on NB rows only,
#           base margin = log of the current prediction (developed: step 5 out-of-fold baseline; emerging: the step 7 B model
#           x the NB load of SRC), shared rating / quote features + `market`, shallow and regularised. The multiplier is
#           renormalised to average 1 over the emerging NB training rows (shape only - the NB level stays SRC's) and applied
#           as m^W to every peril of the row.
#           Backtest: developed 2023 fold + emerging 2023 rows -> 2024 fold. Final: developed 2023-24 folds + emerging
#           2023-24 in-sample -> 2025 test.
# Inputs  : week2/output/05_baseline/row_preds.parquet, data/week_2/optionB/adjust/<ADJ_TAG>/{insample23,insample}_peril.parquet,
#           data/week_2/optionB/adjust/<SRC_TAG>/valid_2024_peril.parquet, data/week_2/optionB/final/<SRC_TAG>/pred_2025_peril.parquet,
#           week2/output/22_nb_backtest/<SRC_TAG>_loads.csv, week2/output/08_loadings/<SRC_TAG>/loadings.csv, features, claims
# Outputs : data/week_2/optionB/adjust/<RUN_TAG>/valid_2024_peril.parquet, data/week_2/optionB/final/<RUN_TAG>/pred_2025_peril.parquet,
#           week2/output/07_adjust/levels_<RUN_TAG>.csv, week2/output/23_nb_pooled/<RUN_TAG>_summary.csv
# Run     : RUN_TAG=nb7_pool SRC_TAG=nb1b_devonly ADJ_TAG=x20nb NB7_W=0.5 Rscript week2/R/23_nb_pooled_model.R
# Time    : a few minutes

source("week2/R/00_setup_week2.R")
start_script("23_nb_pooled_model.R")
TAG <- Sys.getenv("RUN_TAG"); SRC <- Sys.getenv("SRC_TAG", "nb1b_devonly"); ADJ <- Sys.getenv("ADJ_TAG", "x20nb")
W <- as.numeric(Sys.getenv("NB7_W", "0.5"))
stopifnot(nzchar(TAG), !TAG %in% c(SRC, ADJ, "main"))
FEAT_DIR <- file.path(W2$data, "features")
DROP <- c("market", "row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end", "policy_year", "exposure",
          "new_business", "renewal_count")
clp <- claim_basis("emerging")
rp <- read_w2(file.path(W2$output, "05_baseline", "row_preds.parquet"))
src_bt <- fread(file.path(W2$output, "22_nb_backtest", paste0(SRC, "_loads.csv")))[, .(line, peril, nb_load, nb_factor)]
src_fn <- fread(file.path(W2$output, "08_loadings", SRC, "loadings.csv"))[, .(line, peril, nb_load = nb_load_peril, nb_factor)]
em_rows <- function(f, loads) {   # emerging NB rows: row-level current prediction (B x NB load) and developed-basis actual
  x <- read_w2(file.path(W2$data, "adjust", ADJ, f))
  x <- merge(x, loads, by = c("line", "peril"))
  x <- merge(x, clp[, .(adj = sum(cost)), by = .(row_id, peril)], by = c("row_id", "peril"), all.x = TRUE); x[is.na(adj), adj := 0]
  x[, .(pred = sum(exposure * freq_B * sev_B * fifelse(nb_factor, 1, nb_load)), y = sum(adj / share)), by = row_id]
}
fit_line <- function(ln, dev_years, em_tab, targets) {
  fd <- read_w2(file.path(FEAT_DIR, sprintf("developed_train_%s.parquet", ln)))
  fe <- read_w2(file.path(FEAT_DIR, sprintf("emerging_train_%s.parquet", ln)))
  ft <- read_w2(file.path(FEAT_DIR, sprintf("emerging_test_%s.parquet", ln)))
  feats <- setdiff(Reduce(intersect, list(names(fd), names(fe), names(ft))), c(DROP, grep("^(y_|n_|hist_)", names(fd), value = TRUE)))
  d <- merge(rp[line == ln & valid_year %in% dev_years, .(row_id, pred, y = developed)], fd[new_business == TRUE], by = "row_id")[, mk := 0]
  e <- merge(em_tab, fe[new_business == TRUE], by = "row_id")[, mk := 1]
  tr <- rbind(d[, c("pred", "y", "mk", "policy_id", feats), with = FALSE], e[, c("pred", "y", "mk", "policy_id", feats), with = FALSE])
  tr <- tr[pred > 0]
  enc <- function(z) {
    X <- sapply(feats, function(f) { v <- z[[f]]; if (is.numeric(v) || is.logical(v)) as.numeric(v) else
      match(as.character(v), sort(unique(c(as.character(fd[[f]]), as.character(fe[[f]]), as.character(ft[[f]]))))) })
    cbind(X, market = z$mk)
  }
  X <- enc(tr); set.seed(SEED)
  pid <- unique(tr$policy_id); hold <- tr$policy_id %chin% sample(pid, round(0.25 * length(pid)))
  dm <- function(i) xgboost::xgb.DMatrix(X[i, , drop = FALSE], label = tr$y[i], base_margin = log(tr$pred[i]))
  m <- xgboost::xgb.train(params = list(objective = "reg:tweedie", tweedie_variance_power = 1.5, learning_rate = 0.03, max_depth = 2,
                                        min_child_weight = 50, subsample = 0.8, colsample_bytree = 0.8, reg_lambda = 5, nthread = 2, seed = SEED),
                          data = dm(!hold), nrounds = 500, evals = list(hold = dm(hold)), early_stopping_rounds = 30, verbose = 0)
  mult <- function(z) exp(predict(m, xgboost::xgb.DMatrix(enc(z), base_margin = rep(0, nrow(z))), outputmargin = TRUE))
  me <- mult(tr[mk == 1]); k <- sum(tr[mk == 1]$pred) / sum(tr[mk == 1]$pred * me)
  tg <- copy(targets)[, mk := 1]
  list(rows = data.table(row_id = tg$row_id, m = (mult(tg) * k)^W),
       info = data.table(line = ln, rows_dev = nrow(d), rows_em = nrow(e), rounds = m$best_iteration, norm = k))
}
apply_m <- function(x, mm, col) {
  x <- merge(x, mm, by = "row_id", all.x = TRUE, sort = FALSE); x[is.na(m), m := 1]
  x[, (col) := get(col) * m]; x[, m := NULL]; x
}
info <- list()
# Backtest: 2024 fold
em23 <- em_rows("insample23_peril.parquet", src_bt)
v <- read_w2(file.path(W2$data, "adjust", SRC, "valid_2024_peril.parquet")); cols <- names(v)
mm <- rbindlist(lapply(LINES, function(ln) {
  fe <- read_w2(file.path(FEAT_DIR, sprintf("emerging_train_%s.parquet", ln)))
  r <- fit_line(ln, 2023L, em23, fe[policy_year == 2024 & new_business == TRUE]); info[[paste("bt", ln)]] <<- r$info[, fold := "backtest"]; r$rows }))
v <- apply_m(v, mm, "freq_B")
write_w2(v[, ..cols], file.path(W2$data, "adjust", TAG, "valid_2024_peril.parquet"))
# Final: 2025 test
emall <- em_rows("insample_peril.parquet", src_fn)
fin <- read_w2(file.path(W2$data, "final", SRC, "pred_2025_peril.parquet"))
mf <- rbindlist(lapply(LINES, function(ln) {
  ft <- read_w2(file.path(FEAT_DIR, sprintf("emerging_test_%s.parquet", ln)))
  r <- fit_line(ln, c(2023L, 2024L), emall, ft[new_business == TRUE]); info[[paste("fn", ln)]] <<- r$info[, fold := "final"]; r$rows }))
fin <- apply_m(fin, mf, "pred_B")
write_w2(fin, file.path(W2$data, "final", TAG, "pred_2025_peril.parquet"))
file.copy(file.path(W2$output, "07_adjust", paste0("levels_", SRC, ".csv")), file.path(W2$output, "07_adjust", paste0("levels_", TAG, ".csv")), overwrite = TRUE)
info <- rbindlist(info)
info <- merge(info, rbind(mm[, .(fold = "backtest", m)], mf[, .(fold = "final", m)])[, .(m_p05 = quantile(m, 0.05), m_p95 = quantile(m, 0.95)), by = fold], by = "fold")
save_csv(info, "23_nb_pooled", paste0(TAG, "_summary.csv"))
print(info)
end_script()
