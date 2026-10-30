# 4_models_itermotor03.R ---------------------------------------------------------
# MOTOR 3: MOTOR 2 with its final configuration frozen (no re-selection on the folds) plus claim history split by
# peril group: prior collision claims (own_damage, third_party_prop, bodily_injury) vs prior theft / glass_hail claims,
# and years since the last collision claim (all as at 1 January of the row's year). Clean A/B against MOTOR 2: the only
# change is the new information. Writes fold predictions (2022-24) and a motor-only 2025 file (own level).
# Env vars: MOTOR03_QUICK=1 (sampled policies, short boosting)

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
suppressPackageStartupMessages({
  library(xgboost)
  library(splines)
})
T0 <- Sys.time()
QUICK <- Sys.getenv("MOTOR03_QUICK") == "1"
import_defs <- function(file, skip) {
  in_header <- TRUE
  for (e in parse(file, keep.source = FALSE)) {
    if (is.call(e) && identical(e[[1]], as.name("log_msg"))) in_header <- FALSE
    if (!is.call(e) || !identical(e[[1]], as.name("<-")) || !is.name(e[[2]])) next
    nm <- as.character(e[[2]])
    is_fun <- is.call(e[[3]]) && identical(e[[3]][[1]], as.name("function"))
    if (!nm %in% skip && (is_fun || in_header)) eval(e, globalenv())
  }
}
skip <- c("QUICK", "RUN_ID", "ITERATION_LABEL", "ITER_DIR", "FITTED_DIR", "T0", "checks", "in_header", "import_defs")
import_defs("week1/R/4_models_itermotor01.R", skip)
import_defs("week1/R/4_models_itermotor02.R", skip)

RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITER_DIR <- file.path("week1", "models", if (QUICK) "motor_iteration_03_quick" else "motor_iteration_03")
dir.create(ITER_DIR, recursive = TRUE, showWarnings = FALSE)
COLL <- c("own_damage", "third_party_prop", "bodily_injury")
NEW_FEATS <- c("hist_coll_n", "hist_oth_n", "coll_free_years")
for (pr in COLL) FREQ_SEL[[pr]] <- unique(c(FREQ_SEL[[pr]], NEW_FEATS))
BI_POOL_FEATS <- unique(c(BI_POOL_FEATS, "hist_coll_n"))
TREE_CORE <- unique(c(TREE_CORE, NEW_FEATS))
MONO <- c(MONO, hist_coll_n = 1, hist_oth_n = 1, coll_free_years = -1)
# MOTOR 2 final choices (week1/models/motor_iteration_02/final_config.csv, decisions.csv)
CFG <- list(own_damage = list(freq = "glm", ftrend = 0, xgb = "x1", fw = 0, sev = "base", Z = 1, strend = 0, load = "raw"),
            third_party_prop = list(freq = "glm", ftrend = 1, xgb = "x1", fw = 0, sev = "base", Z = 0.5, strend = 1, load = "raw"),
            bodily_injury = list(freq = "mix", ftrend = 1, xgb = "x1", fw = 0, sev = "all", Z = 0, strend = 1, load = "raw"),
            theft = list(freq = "glm", ftrend = 1, xgb = "x1", fw = 0, sev = "base", Z = 1, strend = 1, load = "raw"),
            glass_hail = list(freq = "glm", ftrend = 1, xgb = "x1", fw = 0, sev = "base", Z = 0.75, strend = 1, load = "raw"))
BLEND <- list(tw = 0.1, legacy = 0.2)

# Phase A: data (as MOTOR 2) + split claim history ---------------------------------------------------
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
rm(weather, raw_claims); gc(verbose = FALSE)

add_hist_split <- function(d) {
  parts <- lapply(sort(unique(d$policy_year)), function(Y) {
    y0 <- as.Date(sprintf("%d-01-01", Y))
    k <- CL[report_date < y0, .(n_coll = sum(peril %in% COLL), n_oth = sum(!peril %in% COLL),
                                last_coll = if (any(peril %in% COLL)) max(report_date[peril %in% COLL]) else as.Date(NA)),
            by = policy_id]
    x <- merge(d[policy_year == Y, .(row_id, policy_id, years_with_insurer)], k, by = "policy_id", all.x = TRUE)
    x[is.na(n_coll), n_coll := 0L]
    x[is.na(n_oth), n_oth := 0L]
    x[, coll_free_years := fifelse(is.na(last_coll), as.numeric(pmin(pmax(years_with_insurer, 0), Y - 2021)),
                                   as.numeric(y0 - last_coll) / 365)]
    x[, .(row_id, hist_coll_n = pmin(n_coll, 3L), hist_oth_n = pmin(n_oth, 3L), coll_free_years)]
  })
  d <- merge(d, rbindlist(parts), by = "row_id", all.x = TRUE, sort = FALSE)
  setorder(d, row_id)
  d
}
train <- add_hist_split(engineer(train))
test <- add_hist_split(engineer(test))
add_shares(train, ROW_SHARE)
hist_check <- train[policy_year %in% 2022:2023, .(exposure = sum(exposure), bi_freq = sum(y_npos_bodily_injury) / sum(exposure),
                                                  tpp_freq = sum(y_npos_third_party_prop) / sum(exposure)), by = hist_coll_n][order(hist_coll_n)]
print(hist_check)

# Phase B: folds with the frozen configuration --------------------------------------------------------
fold_pred <- list()
for (vy in VALID_YEARS) {
  t1 <- Sys.time()
  tr <- train[policy_year < vy]
  va <- train[policy_year == vy]
  info <- add_robust_loading(prep_fold(tr, va, SEED + vy), tr)
  fits <- fit_all2(tr, info, SEED + vy, final = TRUE, cfg = CFG, blend = BLEND)
  costs <- sapply(PR, function(pr) peril_cost2(peril_parts2(fits$perils[[pr]], va, info, pr), CFG[[pr]], va$exposure))
  tot <- rowSums(costs)
  lg <- legacy_pred(tr, va, SEED + vy)
  final <- (1 - BLEND$tw - BLEND$legacy) * tot + BLEND$tw * tw_cost(fits$tw, va, sum(tot)) + BLEND$legacy * lg * sum(tot) / sum(lg)
  out <- data.table(valid_year = vy, row_id = va$row_id, exposure = va$exposure, actual = va$y_cost, pred_final = final)
  for (pr in PR) set(out, j = paste0("pred_", pr), value = costs[, pr])
  fold_pred[[as.character(vy)]] <- out
  log_msg("Fold ", vy, ": raw D2 ", round(d2_tweedie(out$actual, final, out$exposure), 5), " in ",
          round(as.numeric(difftime(Sys.time(), t1, units = "mins")), 1), " min")
  rm(tr, va, fits); gc(verbose = FALSE)
}
fold_pred <- rbindlist(fold_pred)
write_parquet(fold_pred, file.path(ITER_DIR, "fold_predictions.parquet"))
m2 <- as.data.table(read_parquet(file.path("week1", "models", "motor_iteration_02", "fold_predictions.parquet")))[, .(row_id, valid_year, m2 = pred_final)]
cmp <- merge(fold_pred, m2, by = c("row_id", "valid_year"))
ab <- cmp[, .(rows = .N, d2_motor3 = d2_tweedie(actual, pred_final, exposure), d2_motor2 = d2_tweedie(actual, m2, exposure),
              d2cal_motor3 = d2_cal(actual, pred_final, exposure), d2cal_motor2 = d2_cal(actual, m2, exposure)), by = valid_year]
print(ab)
fwrite(ab, file.path(ITER_DIR, "ab_vs_motor2.csv"))

# Phase F: final fit on 2021-24 --------------------------------------------------------------------------
log_msg("Phase F: final fit")
tr <- copy(train)
te <- copy(test)
add_shares(te, ROW_SHARE)
info <- add_robust_loading(prep_fold(tr, te, SEED + 2025), tr)
fits <- fit_all2(tr, info, SEED + 2025, final = TRUE, cfg = CFG, blend = BLEND)
leg <- legacy_pred(tr, te, SEED + 2025)
art <- list(model = "motor03_peril", info = info, perils = fits$perils, tw = fits$tw, cfg = CFG, blend = BLEND, row_share = ROW_SHARE)
sc <- score_art2(art, test, leg)
stopifnot(nrow(test) == length(sc$total), !anyNA(sc$total), all(sc$total >= 0))
f_own <- out_file("submission", paste0("motor3_only_", RUN_ID, if (QUICK) "_quick", ".csv"))
fwrite(data.table(row_id = test$row_id, prediction = sc$total), f_own, scipen = 50)
per <- data.table(row_id = test$row_id, sc$perils)
setnames(per, PR, paste0("m3_", PR))
fwrite(per, out_file("submission", paste0("motor3_test_perils_", RUN_ID, if (QUICK) "_quick", ".csv")), scipen = 50)
log_msg("Wrote ", f_own, "; 2025 motor burn ", round(sum(sc$total) / sum(test$exposure), 1),
        "; done in ", round(as.numeric(difftime(Sys.time(), T0, units = "mins")), 1), " min")
