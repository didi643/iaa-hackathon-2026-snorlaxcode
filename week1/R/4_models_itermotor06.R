# 4_models_itermotor06.R ---------------------------------------------------------
# MOTOR 6: MOTOR 4 with telematics feature engineering for the collision perils (own_damage, third_party_prop,
# bodily_injury). week1/R/6_telematics_study.R showed that MOTOR 2's own_damage / BI GLMs use only telematics_opt_in, and
# the score leaves a residual gradient (own_damage A/E by score band 1.03 -> 0.71 in 2023, 1.34 -> 0.86 in 2024);
# opt-in and score never change within a policy, so there is no dynamic (year-on-year) telematics signal.
#   GLM frequency (spline + not-opted-in flag): telematics_score added to own_damage and BI (TPP already has it),
#     and to the BI-vs-TPP pooled relativity
#   LightGBM frequency: + tele_rel (score minus the mean score of the driver-age band x young-driver group) and
#     tele_risk_miles ((100 - score) x mileage / 10k); telematics_score monotone decreasing
# Everything else as MOTOR 4 (folds 2023 selection / 2024 held out / final 2021-24, MOTOR 2 severity).
# Needs data/week_1/telematics/tele_features.parquet (week1/R/6_telematics_study.R).
# Judge: MOTOR04_DIR=week1/models/motor_iteration_06 EVAL_TAG=motor06 Rscript week1/R/6_w9_motor04_eval.R

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
suppressPackageStartupMessages({
  library(xgboost)
  library(splines)
})
T0 <- Sys.time()
QUICK <- Sys.getenv("MOTOR06_QUICK") == "1"
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
skip <- c("QUICK", "RUN_ID", "ITERATION_LABEL", "ITER_DIR", "FITTED_DIR", "T0", "checks", "in_header", "import_defs", "skip")
import_defs("week1/R/4_models_itermotor01.R", skip)
import_defs("week1/R/4_models_itermotor02.R", skip)
import_defs("week1/R/4_models_itermotor04.R", skip)
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITER_DIR <- file.path("week1", "models", if (QUICK) "motor_iteration_06_quick" else "motor_iteration_06")
dir.create(ITER_DIR, recursive = TRUE, showWarnings = FALSE)
TELE_GLM <- "telematics_score"
TELE_TREE <- c("tele_rel", "tele_risk_miles")
for (pr in c("own_damage", BI)) FREQ_SEL[[pr]] <- unique(c(FREQ_SEL[[pr]], TELE_GLM))
BI_POOL_FEATS <- unique(c(BI_POOL_FEATS, TELE_GLM))
MONO <- c(MONO, telematics_score = -1)
lgb_feats_m4 <- lgb_feats
lgb_feats <- function(pr) unique(c(lgb_feats_m4(pr), if (pr %in% COLL) TELE_TREE))

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
tele <- as.data.table(read_parquet(file.path("data", "week_1", "telematics", "tele_features.parquet")))[, c("row_id", TELE_TREE), with = FALSE]
add_tele <- function(d) {
  d <- merge(d, tele, by = "row_id", all.x = TRUE, sort = FALSE)
  setorder(d, row_id)
  d
}
train <- add_tele(add_hist_split(engineer(train)))
test <- add_tele(add_hist_split(engineer(test)))
stopifnot(!anyNA(train$row_id), nrow(test) == 254986)
add_shares(train, ROW_SHARE)
add_shares(test, ROW_SHARE)

res <- list()
for (vy in FOLDS) res[[as.character(vy)]] <- run_fold(train[policy_year < vy], train[policy_year == vy], SEED + vy, vy)
res[["2025"]] <- run_fold(copy(train), copy(test), SEED + 2025, 2025L)
comp <- rbindlist(lapply(res, `[[`, "out"), fill = TRUE)
write_parquet(comp, file.path(ITER_DIR, "components.parquet"))
fwrite(rbindlist(lapply(res, `[[`, "info")), file.path(ITER_DIR, "lgb_info.csv"))
fwrite(rbindlist(lapply(res, `[[`, "imp")), file.path(ITER_DIR, "lgb_importance.csv"))
sm <- comp[, c(list(rows = .N), lapply(.SD, function(x) sum(x) / sum(exposure))), by = valid_year,
           .SDcols = grep("^(glm|lgb|boost|dev)_", names(comp), value = TRUE)]
fwrite(sm, file.path(ITER_DIR, "burn_by_component.csv"))
fwrite(data.table(run_id = RUN_ID, quick = QUICK, minutes = round(as.numeric(difftime(Sys.time(), T0, units = "mins")), 1)),
       file.path(ITER_DIR, "summary.csv"))
log_msg("Done in ", round(as.numeric(difftime(Sys.time(), T0, units = "mins")), 1), " min -> ", ITER_DIR)
