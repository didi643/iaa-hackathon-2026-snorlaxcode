# oof_io.R ------------------------------------------------------------------------------------------------------
# Shared helper for the local validation protocol (week1/docs/HANDOFF_claude_code.md, section 3): writes, reads, scores
# and compares out-of-time row predictions so runs of different scripts can be compared and blended later.
#
# Files per run (folder week1/output/4_check_reported/<tag>/, the folder week1/R/4_check_reported_compare.R reads):
#   row_preds.parquet        line level, one row per scored policy row:
#                            valid_year, line, row_id, policy_id, exposure, pred, reported_raw, reported_adj, developed
#   row_preds_peril.parquet  same keys, one column set per peril (NA where the peril is not in the row's line):
#                            pred_<peril> (method in the line mix), pred_<peril>_<method> (every method fitted),
#                            reported_raw_<peril>, reported_adj_<peril>, developed_<peril>
#   line_scores.csv          basis x valid_year x line: d2, gini, pred_vs_actual (same columns as 4_check_reported_w4)
#
# Use (after source("week1/R/0_setup.R")):
#   source("week1/R/oof_io.R")
#   write_row_preds(line_rows, peril_rows, tag)        # validates the format, returns the folder
#   rp <- read_row_preds(tag)                           # level = "line" (default) or "peril"
#   score_row_preds(rp)                                 # line_scores table
#   compare_row_preds("run_a", "run_b")                 # paired policy bootstrap of mean 2023-24 D2 (A - B)

OOF_BASES <- c("reported_raw", "reported_adj", "developed")
OOF_KEYS <- c("valid_year", "line", "row_id", "policy_id", "exposure")
oof_dir <- function(tag) file.path(PATHS$output, "4_check_reported", tag)

# Tweedie deviance and D2 with optional row weights (bootstrap); baseline = one cost rate per exposure-year
oof_unit_dev <- function(y, mu, p = TWEEDIE_P) {
  mu <- pmax(mu, 1e-6)
  2 * (ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
oof_d2 <- function(y, mu, e, w = rep(1, length(y))) {
  base <- e * sum(w * y) / sum(w * e)
  1 - sum(w * oof_unit_dev(y, mu)) / sum(w * oof_unit_dev(y, base))
}
oof_gini <- function(y, s) {
  g <- function(a, s) { a <- a[order(s, decreasing = TRUE)]; n <- length(a); sum(cumsum(a) / sum(a) - seq_len(n) / n) / n }
  g(y, s) / g(y, y)
}

write_row_preds <- function(line_rows, peril_rows = NULL, tag) {
  line_rows <- as.data.table(line_rows)
  miss <- setdiff(c(OOF_KEYS, "pred", OOF_BASES), names(line_rows))
  if (length(miss)) stop("row_preds lacks columns: ", paste(miss, collapse = ", "))
  if (anyDuplicated(line_rows, by = c("valid_year", "row_id"))) stop("row_preds has duplicate valid_year x row_id")
  if (anyNA(line_rows$pred) || any(line_rows$pred < 0)) stop("row_preds has NA or negative predictions")
  dir <- oof_dir(tag)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  arrow::write_parquet(line_rows[, c(OOF_KEYS, "pred", OOF_BASES), with = FALSE], file.path(dir, "row_preds.parquet"))
  if (!is.null(peril_rows)) {
    peril_rows <- as.data.table(peril_rows)
    miss <- setdiff(OOF_KEYS, names(peril_rows))
    if (length(miss)) stop("row_preds_peril lacks columns: ", paste(miss, collapse = ", "))
    if (nrow(peril_rows) != nrow(line_rows)) stop("row_preds_peril and row_preds have different row counts")
    arrow::write_parquet(peril_rows, file.path(dir, "row_preds_peril.parquet"))
  }
  invisible(dir)
}

read_row_preds <- function(tag, level = c("line", "peril"), folds = NULL) {
  level <- match.arg(level)
  f <- file.path(oof_dir(tag), if (level == "line") "row_preds.parquet" else "row_preds_peril.parquet")
  if (!file.exists(f)) stop("Missing ", f)
  rp <- as.data.table(arrow::read_parquet(f))
  if (!is.null(folds)) rp <- rp[valid_year %in% folds]
  rp
}

score_row_preds <- function(rp, bases = OOF_BASES) {
  out <- rbindlist(lapply(bases, function(b) {
    rbind(rp[, .(d2 = oof_d2(get(b), pred, exposure), gini = oof_gini(get(b), pred),
                 pred_vs_actual = sum(pred) / sum(get(b))), by = .(valid_year, line)],
          rp[, .(line = "ALL", d2 = oof_d2(get(b), pred, exposure), gini = oof_gini(get(b), pred),
                 pred_vs_actual = sum(pred) / sum(get(b))), by = valid_year])[, basis := b]
  }))
  setcolorder(out, c("basis", "valid_year", "line"))
  setorder(out, basis, valid_year, line)
  out[]
}

# Paired policy bootstrap of the difference in mean-over-folds D2 (run A - run B) on the same rows. A policy keeps one
# bootstrap weight in every fold, so the two folds' errors stay correlated as in the data. Actuals come from run A.
compare_row_preds <- function(tag_a, tag_b, basis = "reported_raw", folds = c(2023L, 2024L), nboot = 200,
                              seed = SEED) {
  a <- read_row_preds(tag_a, folds = folds)
  b <- read_row_preds(tag_b, folds = folds)
  m <- merge(a[, .(valid_year, row_id, line, policy_id, exposure, y = get(basis), pred_a = pred)],
             b[, .(valid_year, row_id, y_b = get(basis), pred_b = pred)], by = c("valid_year", "row_id"))
  if (nrow(m) != nrow(a) || nrow(m) != nrow(b)) warning("Runs cover different rows: A ", nrow(a), ", B ", nrow(b),
                                                        ", matched ", nrow(m))
  gap <- m[, sum(abs(y - y_b)) / sum(y)]
  if (gap > 1e-6) warning(sprintf("Actuals differ between runs by %.3f%% - scored on run A's actuals", 100 * gap))
  pol <- unique(m$policy_id)
  m[, pidx := match(policy_id, pol)]
  set.seed(seed)
  W <- replicate(nboot, tabulate(sample.int(length(pol), length(pol), replace = TRUE), nbins = length(pol)))
  one <- function(d, label) {
    fy <- split(d, by = "valid_year")
    stat <- function(w_pol) {
      v <- vapply(fy, function(x) {
        w <- w_pol[x$pidx]
        c(oof_d2(x$y, x$pred_a, x$exposure, w), oof_d2(x$y, x$pred_b, x$exposure, w))
      }, numeric(2))
      rowMeans(v)
    }
    s0 <- stat(rep(1, length(pol)))
    draws <- apply(W, 2, function(w) { s <- stat(w); s[1] - s[2] })
    diff0 <- s0[1] - s0[2]
    data.table(line = label, folds = paste(sort(folds), collapse = "+"), d2_a = s0[1], d2_b = s0[2], diff = diff0,
               boot_se = sd(draws), threshold_2se = 2 * sd(draws), share_draws_a_better = mean(draws > 0),
               verdict = fifelse(abs(diff0) < 2 * sd(draws), "within noise", fifelse(diff0 > 0, "A better", "B better")))
  }
  res <- rbind(one(m, "ALL"), rbindlist(lapply(LINES, function(ln) one(m[line == ln], ln))))
  res[, `:=`(run_a = tag_a, run_b = tag_b, basis = basis)][]
}
