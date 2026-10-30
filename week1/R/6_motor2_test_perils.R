# 6_motor2_test_perils.R ---------------------------------------------------------------------------------
# Scores the saved MOTOR 2 model (week1/models/motor_iteration_02/fitted/motor02_peril.rds) on test_motor and writes the
# per-peril 2025 costs (before the line Tweedie / legacy blend) to week1/output/submission/motor2_test_perils_<run>.csv.
# Run: Rscript week1/R/6_motor2_test_perils.R

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
suppressPackageStartupMessages({
  library(xgboost)
  library(splines)
})
QUICK <- FALSE
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
skip <- c("QUICK", "RUN_ID", "ITERATION_LABEL", "ITER_DIR", "FITTED_DIR", "T0", "checks", "in_header")
import_defs("week1/R/4_models_itermotor01.R", skip)
import_defs("week1/R/4_models_itermotor02.R", skip)

test <- as.data.table(read_parquet(file.path(DATA_DIR, "test_motor.parquet")))
train_ids <- as.data.table(read_parquet(file.path(DATA_DIR, "train_motor.parquet"), col_select = "row_id"))$row_id
raw_claims <- read_raw("claims")[line == "motor"]
CL <- as.data.table(read_parquet(file.path(DATA_DIR, "claims_pos.parquet")))[line == "motor"]
CL <- merge(CL, raw_claims[, .(claim_id, policy_id, report_date)], by = "claim_id", all.x = TRUE)[row_id %in% train_ids]
weather <- read_raw("weather")
wx_avg <- weather[year %in% 2021:2024, .(wx_avg_hail_days = mean(hail_days), wx_avg_freezing_days = mean(freezing_days)),
                  by = address_id]
first_claim <- CL[, .(policy_id, report_date)]
test <- engineer(test)

saved <- readRDS(file.path("week1", "models", "motor_iteration_02", "fitted", "motor02_peril.rds"))
sc <- score_art2(pack_art2(saved$art, sam02_unpack), test, saved$legacy_test)
ref <- fread(file.path(PATHS$output, "submission", "motor2_only_20261023_1359.csv"), colClasses = list(character = "row_id"))
stopifnot(max(abs(sc$total - ref$prediction[match(test$row_id, ref$row_id)])) < 1e-6)
out <- data.table(row_id = test$row_id, sc$perils)
setnames(out, PERILS$motor, paste0("m2_", PERILS$motor))
f <- out_file("submission", "motor2_test_perils_20261023_1359.csv")
fwrite(out, f, scipen = 50)
log_msg("Wrote ", f, "; total reproduces motor2_only_20261023_1359.csv")
