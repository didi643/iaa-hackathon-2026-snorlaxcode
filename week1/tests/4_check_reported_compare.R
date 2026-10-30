# 4_check_reported_compare.R ------------------------------------------------------------------------------------
# Compares two runs of week1/R/4_check_reported_w4.R on the SAME rows, fold and actual basis, and puts a noise band on the
# difference with a policy-level bootstrap (policies resampled with replacement; a policy's rows travel together).
# Use it for the Submit_Gate sheet: submit only if the difference is larger than about 2 x its bootstrap SE.
#
# Run (from the project root), e.g. Windows PowerShell:
#   $env:RUN_A="wendy04_sam02clean"; $env:RUN_B="wendy04"; $env:BASIS="reported_raw"; $env:FOLD="2024"
#   Rscript week1/R/4_check_reported_compare.R
# Settings: RUN_A, RUN_B = CHECK_TAG of each run; BASIS = reported_raw | reported_adj | developed; FOLD = 2023 | 2024;
#           NBOOT = bootstrap draws (default 200); SEED from week1/R/0_setup.R.
# Output:   week1/output/4_check_reported/compare_<A>_vs_<B>_<basis>_<fold>.csv (ALL and each line)

source("week1/R/0_setup.R")
RUN_A <- Sys.getenv("RUN_A", "wendy04_sam02clean")
RUN_B <- Sys.getenv("RUN_B", "wendy04")
BASIS <- Sys.getenv("BASIS", "reported_raw")
FOLD <- as.integer(Sys.getenv("FOLD", "2024"))
NBOOT <- as.integer(Sys.getenv("NBOOT", "200"))
stopifnot(BASIS %in% c("reported_raw", "reported_adj", "developed"))
dir_of <- function(tag) file.path(PATHS$output, "4_check_reported", tag)

rd <- function(tag) {
  f <- file.path(dir_of(tag), "row_preds.parquet")
  if (!file.exists(f)) stop("Missing ", f, " - run week1/R/4_check_reported_w4.R with CHECK_TAG=", tag, " first.")
  as.data.table(arrow::read_parquet(f))[valid_year == FOLD]
}
a <- rd(RUN_A)
b <- rd(RUN_B)
m <- merge(a[, .(row_id, line, policy_id, exposure, y = get(BASIS), pred_a = pred)],
           b[, .(row_id, y_b = get(BASIS), pred_b = pred)], by = "row_id")
if (nrow(m) != nrow(a) || nrow(m) != nrow(b)) {
  warning("Runs cover different rows: A ", nrow(a), ", B ", nrow(b), ", matched ", nrow(m), " - scoring matched rows only")
}
# The actual should be identical when both runs use the same claims basis; report the gap if not
act_gap <- m[, sum(abs(y - y_b)) / sum(y)]
if (act_gap > 1e-6) {
  warning(sprintf("Actuals differ between runs by %.3f%% of total (different cleaning) - each run is scored on run A's actuals", 100 * act_gap))
}

# Weighted Tweedie D2 (p = TWEEDIE_P), baseline = one cost rate per exposure-year (as in the model scripts)
unit_dev <- function(y, mu, p = TWEEDIE_P) {
  mu <- pmax(mu, 1e-6)
  2 * (ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
wd2 <- function(y, mu, e, w) {
  base <- e * sum(w * y) / sum(w * e)
  1 - sum(w * unit_dev(y, mu)) / sum(w * unit_dev(y, base))
}

compare_one <- function(d, label) {
  w1 <- rep(1, nrow(d))
  diff0 <- wd2(d$y, d$pred_a, d$exposure, w1) - wd2(d$y, d$pred_b, d$exposure, w1)
  pol <- unique(d$policy_id)
  idx <- match(d$policy_id, pol)
  set.seed(SEED)
  draws <- vapply(seq_len(NBOOT), function(i) {
    w <- tabulate(sample.int(length(pol), length(pol), replace = TRUE), nbins = length(pol))[idx]
    wd2(d$y, d$pred_a, d$exposure, w) - wd2(d$y, d$pred_b, d$exposure, w)
  }, numeric(1))
  data.table(line = label, rows = nrow(d), d2_a = wd2(d$y, d$pred_a, d$exposure, w1),
             d2_b = wd2(d$y, d$pred_b, d$exposure, w1), diff = diff0, boot_se = sd(draws),
             threshold_2se = 2 * sd(draws), share_draws_a_better = mean(draws > 0),
             verdict = fifelse(abs(diff0) < 2 * sd(draws), "within noise",
                               fifelse(diff0 > 0, "A better", "B better")))
}
log_msg("Bootstrap ", NBOOT, " draws: ", RUN_A, " vs ", RUN_B, ", ", BASIS, ", ", FOLD)
res <- rbind(compare_one(m, "ALL"), rbindlist(lapply(LINES, function(ln) compare_one(m[line == ln], ln))))
res[, `:=`(run_a = RUN_A, run_b = RUN_B, basis = BASIS, fold = FOLD)]
out <- file.path(PATHS$output, "4_check_reported", sprintf("compare_%s_vs_%s_%s_%d.csv", RUN_A, RUN_B, BASIS, FOLD))
fwrite(res, out)
num <- c("d2_a", "d2_b", "diff", "boot_se", "threshold_2se", "share_draws_a_better")
print(res[, (num) := lapply(.SD, round, 5), .SDcols = num][, c("line", num, "verdict"), with = FALSE])
log_msg("Done: ", out)
