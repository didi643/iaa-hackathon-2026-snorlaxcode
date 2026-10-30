# 13_compare_runs.R -----------------------------------------------------------------------------------------------------
# Purpose : Experiment gate for the week 2 improvement round. Compares two runs (RUN_A = challenger, RUN_B = current best)
#           on the same emerging 2024 rows with the PUBLIC-BOARD PROXY: Tweedie D2 (p 1.5) against the constant mean, on
#           developed actuals, 2024 reweighted to the 2025 new-business x channel mix (local 0.1500 for public 0.15604,
#           submission #1). Also reports the as-is weighting and per line. Paired policy bootstrap, 200 draws.
#           Verdict "adopt" only if the proxy improves by more than 2 bootstrap SE; "revert" if it gets worse; otherwise
#           "within noise" (kept only if it is the simpler model or clearly sound - judgement, written in the log).
#           Appends one row per comparison to week2/docs/optionB/experiment_log.csv.
# Inputs  : data/week_2/optionB/valid_rows/<run>.parquet (written by 09_validate_compare.R), PRED_A / PRED_B = prediction
#           column (default pred_B)
# Outputs : week2/docs/optionB/experiment_log.csv (appended)
# Run     : RUN_A=<tag> RUN_B=<tag> EXP=<id> Rscript week2/R/13_compare_runs.R
# Time    : under 1 minute

source("week2/R/00_setup_week2.R")
start_script("13_compare_runs.R")
A <- Sys.getenv("RUN_A"); B <- Sys.getenv("RUN_B", "main"); EXP <- Sys.getenv("EXP", A)
PA <- Sys.getenv("PRED_A", "pred_B"); PB <- Sys.getenv("PRED_B", "pred_B"); NOTE <- Sys.getenv("NOTE", "")
ra <- read_w2(file.path(W2$data, "valid_rows", paste0(A, ".parquet")))
rb <- read_w2(file.path(W2$data, "valid_rows", paste0(B, ".parquet")))
m <- merge(ra[, .(row_id, line, policy_id, exposure, dev, w_mix, pa = get(PA))], rb[, .(row_id, pb = get(PB))], by = "row_id")
stopifnot(nrow(m) == nrow(ra), nrow(m) == nrow(rb))
d2c <- function(y, mu, w) { mbar <- sum(w * y) / sum(w); 1 - sum(w * tweedie_dev(y, mu)) / sum(w * tweedie_dev(y, rep(mbar, length(y)))) }
pol <- unique(m$policy_id); m[, pidx := match(policy_id, pol)]
set.seed(SEED)
W <- replicate(200, tabulate(sample.int(length(pol), length(pol), replace = TRUE), nbins = length(pol)))
res <- list()
for (wt in c("w_mix", "w_none")) {
  w0 <- if (wt == "w_mix") m$w_mix else rep(1, nrow(m))
  st <- function(bw) { w <- w0 * bw[m$pidx]; c(d2c(m$dev, m$pa, w), d2c(m$dev, m$pb, w)) }
  s0 <- st(rep(1, length(pol))); dr <- apply(W, 2, function(b) { s <- st(b); s[1] - s[2] })
  bl <- sapply(LINES, function(ln) { i <- m$line == ln; d2c(m$dev[i], m$pa[i], w0[i]) - d2c(m$dev[i], m$pb[i], w0[i]) })
  res[[wt]] <- data.table(date = format(Sys.time(), "%Y-%m-%d %H:%M", tz = "Asia/Singapore"), experiment = EXP, run_a = paste0(A, ":", PA), run_b = paste0(B, ":", PB),
    weighting = fifelse(wt == "w_mix", "mix_2025", "as_is"), d2_const_a = s0[1], d2_const_b = s0[2], diff = s0[1] - s0[2], boot_se = sd(dr),
    share_a_better = mean(dr > 0), diff_motor = bl[["motor"]], diff_buildings = bl[["buildings"]], diff_contents = bl[["contents"]],
    pva_a = sum(w0 * m$pa) / sum(w0 * m$dev), verdict = fifelse(s0[1] - s0[2] > 2 * sd(dr), "adopt", fifelse(s0[1] < s0[2], "revert", "within noise")), note = NOTE)
}
res <- rbindlist(res)
f <- file.path(W2$docs, "experiment_log.csv")
old <- if (file.exists(f)) fread(f, colClasses = list(character = c("note"))) else NULL
fwrite(rbind(old, res, fill = TRUE), f); track_output(f)
print(res[, .(experiment, weighting, d2_const_a = round(d2_const_a, 5), d2_const_b = round(d2_const_b, 5), diff = round(diff, 5), two_se = round(2 * boot_se, 5),
              motor = round(diff_motor, 4), buildings = round(diff_buildings, 4), contents = round(diff_contents, 4), verdict)])
end_script()
