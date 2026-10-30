# ben/ben4_level.R -------------------------------------------------------------
# BEN 4 follow-up: is the motor level the reason for the public-score gap? Public D2 rises with the predicted 2025 motor
# cost per exposure-year across submissions (BEN 1 506 -> 0.12224, WENDY 4 521 -> 0.12671, BEN 3 549 -> 0.12698,
# SAM 3 603 -> 0.12818), while local D2 does not order them the same way. This script
#   1. shows local combined D2 of the BEN 4 selection with motor scaled by 1.00-1.20 (both folds, reported and developed)
#   2. writes a candidate with motor scaled to SAM 3's 2025 level (buildings and contents unchanged), as a public test
#      of level against ranking: if it scores above the unscaled file, motor level is under-predicted.
# Run:     Rscript week1/R/ben/ben4_level.R [run id]   (after week1/R/4_models_iterben04.R)
# Outputs: week1/output/ben/ben4/motor_level_sensitivity.csv; week1/output/submission/submission_<run id>_ben04_motor603.csv

source("week1/R/0_setup.R")
source("week1/R/ben/ben_helpers.R")
args <- commandArgs(trailingOnly = TRUE)
files <- sort(list.files(ben_out("ben4"), "^predictions_.*\\.parquet$", full.names = TRUE))
f <- if (length(args)) ben_out(file.path("ben4", paste0("predictions_", args[1], ".parquet"))) else tail(files, 1)
run_id <- sub("^predictions_(.*)\\.parquet$", "\\1", basename(f))
P <- as.data.table(read_parquet(f))
it_dir <- file.path("week1", "models", "ben_iteration_04")
bp <- unique(fread(file.path(it_dir, "blend_grid.csv"))[order(line, -d2_dev, -w_line)], by = "line")
sel <- fread(file.path(it_dir, "selection.csv"))
for (ln in LINES) {
  b <- bp[line == ln]
  P[line == ln, v5 := b$w_line * get(b$line_model) + (1 - b$w_line) * v4]
  P[line == ln, selected := get(sel[line == ln, variant])]
}
SAM3_MOTOR <- 603.26     # week1/models/sam_iteration_03/model_card.md, 2025 motor cost per exposure-year

tweedie_dev <- function(y, mu, p = TWEEDIE_P) {
  mu <- pmax(mu, 1e-9)
  mean(2 * (ifelse(y > 0, y^(2 - p), 0) / ((1 - p) * (2 - p)) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p)))
}
d2_tweedie <- function(y, pred, exposure) 1 - tweedie_dev(y, pred) / tweedie_dev(y, exposure * sum(y) / sum(exposure))

VAL <- P[year %in% c(2023, 2024)]
sens <- rbindlist(lapply(c(1, 1.05, 1.10, 1.15, 1.20), function(s) {
  VAL[, pr := selected * fifelse(line == "motor", s, 1)]
  VAL[, .(motor_scale = s, d2 = d2_tweedie(actual, pr, exposure), d2_dev = d2_tweedie(actual_dev, pr, exposure),
          motor_ae_dev = sum(pr[line == "motor"]) / sum(actual_dev[line == "motor"])), by = year]
}))
fwrite(sens, ben_out(file.path("ben4", "motor_level_sensitivity.csv")))
print(sens)

te <- P[year == 2025]
motor_now <- te[line == "motor", sum(selected) / sum(exposure)]
scale <- SAM3_MOTOR / motor_now
sub <- te[, .(row_id, prediction = pmax(selected * fifelse(line == "motor", scale, 1), 0))]
ids <- read_raw("sample_submission")$row_id
stopifnot(nrow(sub) == 626639, setequal(sub$row_id, ids), !anyNA(sub$prediction))
base_file <- file.path("week1", "output", "submission", paste0("submission_", run_id, ".csv"))
if (file.exists(base_file)) {          # unscaled rows must equal the iteration's submission
  b <- fread(base_file)
  chk <- merge(sub, b, by = "row_id")[, max(abs(prediction.x - prediction.y) * (substr(row_id, 1, 1) != "M"))]
  stopifnot(chk < 1e-6)
}
out <- out_file("submission", paste0("submission_", run_id, "_ben04_motor603.csv"))
fwrite(sub[match(ids, row_id)], out)
log_msg(sprintf("Motor %.1f -> %.1f (x%.4f). Candidate %s, MD5 %s", motor_now, SAM3_MOTOR, scale, out, unname(tools::md5sum(out))))
