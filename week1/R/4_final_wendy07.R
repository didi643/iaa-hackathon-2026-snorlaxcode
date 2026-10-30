# 4_final_wendy07.R ---------------------------------------------------------------------------------------------
# Backlog C1 at line level: final WENDY 7 candidate = per line, a * WENDY 7 (per-peril method blend) + (1 - a) * SAM 3.
# a is chosen per line on the mean 2023-24 D2 (BASIS) of the saved out-of-time row predictions (grid 0.1); the
# honesty check chooses a on one fold and scores the other. The same a is applied to the 2025 predictions:
# WENDY 7 from its final fit (week1/models/wendy_iteration_07/<tag>/test_preds_peril.parquet, chosen method per peril), SAM 3 from its submitted file
# (Submission sheet of week1/models/sam_iteration_03/sam_iteration_03_model_summary.xlsx, or SAM03_SUB=<csv>).
# Writes a submission file for review only - NOT submitted (Wendy decides; Submit_Gate).
#
# Run:  W7_TAG=wendy07_c3 Rscript week1/R/4_final_wendy07.R
# Out:  week1/output/4_check_reported/wendy07_final/ (row_preds, weights, cross-fold check, line scores)
#       week1/output/submission/submission_<run id>_wendy07_final.csv

source("week1/R/0_setup.R")
source("week1/R/oof_io.R")
setDTthreads(as.integer(Sys.getenv("DT_THREADS", "2")))
W7_TAG <- Sys.getenv("W7_TAG", "wendy07_c3")
W7_TEST <- Sys.getenv("W7_TEST", file.path("week1", "models", "wendy_iteration_07", sub("^wendy07_", "", W7_TAG), "test_preds_peril.parquet"))
SAM_TAG <- Sys.getenv("SAM_TAG", "sam03")
BASIS <- Sys.getenv("BASIS", "reported_raw")
GRID <- seq(0, 1, by = 0.1)
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
FINAL_TAG <- Sys.getenv("FINAL_TAG", "wendy07_final")

w7 <- read_row_preds(W7_TAG)
sm <- read_row_preds(SAM_TAG)
m <- merge(w7[, c(OOF_KEYS, OOF_BASES, "pred"), with = FALSE], sm[, .(valid_year, row_id, pred_sam = pred)],
           by = c("valid_year", "row_id"))
if (nrow(m) != nrow(w7)) warning("Matched ", nrow(m), " of ", nrow(w7), " WENDY 7 rows to SAM 3")
folds <- sort(unique(m$valid_year))
score_a <- function(d, a, fl) mean(vapply(fl, function(f) { x <- d[valid_year == f]
  oof_d2(x[[BASIS]], a * x$pred + (1 - a) * x$pred_sam, x$exposure) }, numeric(1)))
pick_a <- function(d, fl) GRID[which.max(vapply(GRID, function(a) score_a(d, a, fl), numeric(1)))]
wts <- rbindlist(lapply(LINES, function(ln) {
  d <- m[line == ln]
  a <- pick_a(d, folds)
  cf <- vapply(folds, function(f) { o <- setdiff(folds, f); af <- pick_a(d, f); score_a(d, af, o) - score_a(d, 1, o) }, numeric(1))
  data.table(line = ln, a_wendy07 = a, d2_wendy07 = score_a(d, 1, folds), d2_sam03 = score_a(d, 0, folds),
             d2_blend = score_a(d, a, folds), crossfold_gain_vs_wendy07 = paste(round(cf, 5), collapse = " / "))
}))
print(wts)
m[wts, on = "line", pred_final := a_wendy07 * pred + (1 - a_wendy07) * pred_sam]
out <- m[, c(OOF_KEYS, OOF_BASES), with = FALSE][, pred := m$pred_final]
dir <- write_row_preds(out, NULL, FINAL_TAG)
ls <- score_row_preds(out)[, iteration := FINAL_TAG]
fwrite(ls, file.path(dir, "line_scores.csv")); fwrite(wts, file.path(dir, "line_weights.csv"))
log_msg("Final local mean ", BASIS, " D2 ALL: ", round(ls[basis == BASIS & line == "ALL", mean(d2)], 5),
        " (WENDY 7 ", round(score_row_preds(w7)[basis == BASIS & line == "ALL", mean(d2)], 5),
        ", SAM 3 ", round(score_row_preds(sm)[basis == BASIS & line == "ALL", mean(d2)], 5), ")")

# 2025
tw <- as.data.table(arrow::read_parquet(W7_TEST))
tw <- rbindlist(lapply(split(tw, by = "line"), function(d) d[, .(row_id, line, exposure,
  pred = pmax(Reduce(`+`, lapply(PERILS[[d$line[1]]], function(pr) d[[paste0("pred_", pr)]])), 0))]))
sam_sub <- Sys.getenv("SAM03_SUB", "")
ts <- if (nzchar(sam_sub)) fread(sam_sub) else
  as.data.table(openxlsx::read.xlsx("week1/models/sam_iteration_03/sam_iteration_03_model_summary.xlsx", "Submission"))
ts <- ts[, .(row_id, pred_sam = prediction)]
t <- merge(tw, ts, by = "row_id")
stopifnot(nrow(t) == nrow(tw), nrow(t) == nrow(ts))
t[wts, on = "line", prediction := pmax(a_wendy07 * pred + (1 - a_wendy07) * pred_sam, 0)]
print(t[, .(rows = .N, burn_wendy07 = sum(pred) / sum(exposure), burn_sam03 = sum(pred_sam) / sum(exposure),
            burn_final = sum(prediction) / sum(exposure), cor = cor(pred, pred_sam)), by = line])
sample_sub <- read_raw("sample_submission")
sub <- t[match(sample_sub$row_id, row_id), .(row_id, prediction)]
stopifnot(nrow(sub) == nrow(sample_sub), !anyNA(sub$prediction), all(is.finite(sub$prediction)),
          all(sub$prediction >= 0), !anyDuplicated(sub$row_id))
f <- out_file("submission", paste0("submission_", RUN_ID, "_", FINAL_TAG, ".csv"))
fwrite(sub, f, scipen = 50)
log_msg("Candidate file (not submitted): ", f, " MD5 ", unname(tools::md5sum(f)))
