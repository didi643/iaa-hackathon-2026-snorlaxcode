# 4_models_iterwendy08.R --------------------------------------------------------------------------------------------
# WENDY 8: final2 (WENDY 7 C5 x SAM 3) with a Buhlmann-style credibility adjustment on each policy's own claim
# history. R translation of python/wendy08/ (week1/docs/wendy08_findings.md). Submitted 23 Oct 2026 as #13: public 0.12945.
#
#   Why        final2's A/E rises with the policy's prior claims in every line and both folds (e.g. buildings with one
#              prior claim A/E 1.31 / 1.22) and test rows carry up to 4 years of history (vs <= 3 in any training fold).
#   N          claims with net > 0 on the same policy, loss before the row start, reported before min(row start, 1 Jan 2025)
#   E          expected number of those claims: a-priori LightGBM Poisson claim-count model (no history features,
#              4 policy folds, out-of-fold), grossed up to ultimate and x share reported by the same cut-off
#   Adjustment prediction x (a + N) / (a + E), rescaled so each line's total is unchanged (level stays final2's)
#   a          submitted values motor 8, buildings 5, contents 5 (default); A_SELECT=1 re-picks a per line from the grid on
#              the local protocol (mean 2023-24 reported_raw D2 of the base model's out-of-time row predictions; the grid
#              optimum for buildings is 3, within noise of 5)
#
# Run:      Rscript week1/R/4_models_iterwendy08.R
#           BASE_TAG=wendy07_final2 BASE_SUB=week1/output/submission/submission_20261022_2328_wendy07_final2.csv (defaults)
# Needs:    week1/R/0_setup.R, week1/R/oof_io.R, week1/R/wendy_ladder_core.R, data/week_1/raw data/*, week1/output/4_check_reported/<BASE_TAG>/row_preds.parquet
# Outputs:  week1/models/wendy_iteration_08/ (prior_lambda_<line>.parquet, history_<line>.parquet, cred_grid.csv,
#           line_scores.csv, model_card.md), week1/output/4_check_reported/wendy08/, week1/output/submission/submission_<run>_wendy08.csv

source("week1/R/0_setup.R")
source("week1/R/oof_io.R")
source("week1/R/wendy_ladder_core.R")

ITERATION <- "WENDY 8"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
OUT <- wl_dir("wendy_iteration_08")
BASE_TAG <- Sys.getenv("BASE_TAG", "wendy07_final2")
BASE_SUB <- Sys.getenv("BASE_SUB", "week1/output/submission/submission_20261022_2328_wendy07_final2.csv")
A_GRID <- c(2, 3, 5, 8, 12, 20)
A_SUBMITTED <- c(motor = 8, buildings = 5, contents = 5)
A_SELECT <- Sys.getenv("A_SELECT", "0") == "1"
REUSE <- Sys.getenv("REUSE", "1") == "1"      # reuse saved prior_lambda / history files if present

# 1. History per line: a-priori lambda -> N, E for every train and test row -----------------------------------------
hist <- list()
for (ln in LINES) {
  fh <- file.path(OUT, paste0("history_", ln, ".parquet"))
  if (REUSE && file.exists(fh)) { hist[[ln]] <- as.data.table(read_parquet(fh)); next }
  log_msg(ln, ": building rows")
  d <- wl_rows(ln)
  fl <- file.path(OUT, paste0("prior_lambda_", ln, ".parquet"))
  lam <- if (REUSE && file.exists(fl)) as.data.table(read_parquet(fl)) else wl_prior_lambda(d)
  lam[, `:=`(period_start = as.IDate(period_start), period_end = as.IDate(period_end))]
  write_parquet(lam, fl)
  h <- wl_history(d, lam)[, line := ln]
  write_parquet(h, fh); hist[[ln]] <- h
  log_msg(ln, ": test mean N ", round(h[row_id %in% d[is_test == 1L, row_id], mean(N)], 4),
          ", mean E ", round(h[row_id %in% d[is_test == 1L, row_id], mean(E)], 4))
}
H <- rbindlist(hist, use.names = TRUE)

# 2. Choose a per line on the base model's out-of-time row predictions --------------------------------------------
rp <- read_row_preds(BASE_TAG)
rp <- merge(rp, H[, .(row_id, N, E)], by = "row_id", all.x = TRUE)
stopifnot(!anyNA(rp$N))
adj <- function(x, a) x[, pred_new := wl_rescale(pred * wl_cred(N, E, a), pred), by = .(valid_year, line)]
grid <- rbindlist(lapply(LINES, function(ln) rbindlist(lapply(A_GRID, function(a) {
  x <- adj(copy(rp[line == ln]), a)
  x[, .(gain = oof_d2(reported_raw, pred_new, exposure) - oof_d2(reported_raw, pred, exposure)), by = valid_year][,
    .(line = ln, a = a, gain_2023 = gain[valid_year == 2023], gain_2024 = gain[valid_year == 2024], gain_mean = mean(gain))]
}))))
fwrite(grid, file.path(OUT, "cred_grid.csv"))
A <- if (!A_SELECT) A_SUBMITTED else sapply(LINES, function(ln) grid[line == ln][which.max(gain_mean), a])
log_msg("a per line: ", paste(names(A), A, sep = " = ", collapse = ", "))

out <- rbindlist(lapply(LINES, function(ln) adj(copy(rp[line == ln]), A[[ln]])))
out[, pred := pred_new]
dir <- write_row_preds(out[, c(OOF_KEYS, "pred", OOF_BASES), with = FALSE], NULL, "wendy08")
ls <- score_row_preds(out)[, iteration := "wendy08"]
fwrite(ls, file.path(dir, "line_scores.csv")); fwrite(ls, file.path(OUT, "line_scores.csv"))
base_ls <- score_row_preds(read_row_preds(BASE_TAG))
log_msg("local mean reported_raw D2 ALL: ", round(ls[basis == "reported_raw" & line == "ALL", mean(d2)], 5),
        " vs base ", round(base_ls[basis == "reported_raw" & line == "ALL", mean(d2)], 5))
boot <- compare_row_preds("wendy08", BASE_TAG); fwrite(boot, file.path(OUT, "bootstrap_vs_base.csv")); print(boot)

# 3. 2025: adjust the base submission -----------------------------------------------------------------------------
sub <- fread(BASE_SUB, colClasses = list(character = "row_id"))
sample_sub <- read_raw("sample_submission")
stopifnot(nrow(sub) == nrow(sample_sub))
sub[, line := fcase(startsWith(row_id, "M"), "motor", startsWith(row_id, "B"), "buildings", startsWith(row_id, "C"), "contents")]
sub <- merge(sub, H[, .(row_id, N, E)], by = "row_id", all.x = TRUE, sort = FALSE)
stopifnot(!anyNA(sub$N))
sub[, new := wl_rescale(prediction * wl_cred(N, E, A[line]), prediction), by = line]
print(sub[, .(rows = .N, mean_N = mean(N), mean_E = mean(E), total_base = sum(prediction), total_new = sum(new),
              M_p01 = quantile(wl_cred(N, E, A[line]), 0.01), M_p99 = quantile(wl_cred(N, E, A[line]), 0.99)), by = line])
res <- sub[match(sample_sub$row_id, row_id), .(row_id, prediction = new)]
stopifnot(!anyNA(res$prediction), all(res$prediction >= 0), !anyDuplicated(res$row_id))
f <- out_file("submission", paste0("submission_", RUN_ID, "_wendy08.csv"))
fwrite(res, f, scipen = 50)
log_msg("WENDY 8 file: ", f, " MD5 ", unname(tools::md5sum(f)))

card <- c(paste0("# ", ITERATION, " - credibility on own-policy claim history (run ", RUN_ID, ")"), "",
  paste0("Base: `", BASE_TAG, "` / `", BASE_SUB, "`. a per line: ", paste(names(A), A, sep = " = ", collapse = ", "), "."), "",
  "## Credibility grid (gain in reported_raw D2 vs base)", md_table(grid, 5),
  "## Line scores", md_table(ls[basis %in% c("reported_raw", "developed")], 5),
  "## Bootstrap vs base", md_table(boot[, .(line, d2_a, d2_b, diff, threshold_2se, share_draws_a_better, verdict)], 5),
  paste0("Submission: `", f, "` (MD5 ", unname(tools::md5sum(f)), ")"))
writeLines(card, file.path(OUT, "model_card.md"))
