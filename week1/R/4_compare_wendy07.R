# 4_compare_wendy07.R -------------------------------------------------------------------------------------------
# Paired policy bootstrap of mean 2023-24 D2 for WENDY 7 runs against a baseline (week1/R/oof_io.R compare_row_preds).
# Run:  BASE=wendy07_a0 RUNS=wendy07_a1,wendy07_a2 Rscript week1/R/4_compare_wendy07.R
# Out:  week1/output/4_check_reported/compare_wendy07_vs_<base>.csv (appends / replaces rows of the runs given)

source("week1/R/0_setup.R")
source("week1/R/oof_io.R")
setDTthreads(as.integer(Sys.getenv("DT_THREADS", "2")))
BASE <- Sys.getenv("BASE", "wendy07_a0")
RUNS <- trimws(strsplit(Sys.getenv("RUNS", "wendy07_a1,wendy07_a2"), ",")[[1]])
BASIS <- Sys.getenv("BASIS", "reported_raw")
NBOOT <- as.integer(Sys.getenv("NBOOT", "200"))

res <- rbindlist(lapply(RUNS, function(r) {
  log_msg("Bootstrap ", r, " vs ", BASE, " (", BASIS, ", ", NBOOT, " draws)")
  compare_row_preds(r, BASE, basis = BASIS, nboot = NBOOT)
}))
out <- file.path(PATHS$output, "4_check_reported", paste0("compare_wendy07_vs_", BASE, "_", BASIS, ".csv"))
if (file.exists(out)) res <- rbind(fread(out)[!run_a %in% RUNS], res, fill = TRUE)
fwrite(res, out)
num <- c("d2_a", "d2_b", "diff", "boot_se", "threshold_2se", "share_draws_a_better")
print(res[, (num) := lapply(.SD, round, 5), .SDcols = num][, c("run_a", "line", num, "verdict"), with = FALSE])
