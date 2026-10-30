# 4_stack_wendy07.R ---------------------------------------------------------------------------------------------
# Per-line stack of WENDY 7 runs and SAM 3 candidates on saved out-of-time row predictions (no refit).
# Greedy forward selection with replacement (STEPS steps of 1/STEPS, SAM 3's blend rule), weights >= 0, sum 1,
# chosen on the mean D2 (BASIS) over the folds. Honesty check: choose on one fold, score the other.
#
# Run:  W7_TAGS=wendy07_c4 SAM_TAG=sam03 Rscript week1/R/4_stack_wendy07.R
# Out:  week1/output/4_check_reported/wendy07_stack/ (row_preds.parquet, stack_weights.csv, stack_crossfold.csv)

source("week1/R/0_setup.R")
source("week1/R/oof_io.R")
setDTthreads(as.integer(Sys.getenv("DT_THREADS", "2")))
W7_TAGS <- trimws(strsplit(Sys.getenv("W7_TAGS", "wendy07_c4"), ",")[[1]])
SAM_TAG <- Sys.getenv("SAM_TAG", "sam03")
SAM_CANDS <- trimws(strsplit(Sys.getenv("SAM_CANDS", "peril_glm,peril_xgb,xgb_tweedie,peril_lgb,lgb_tweedie"), ",")[[1]])
BASIS <- Sys.getenv("BASIS", "reported_raw")
STEPS <- as.integer(Sys.getenv("STEPS", "20"))
OUT_TAG <- Sys.getenv("OUT_TAG", "wendy07_stack")

sm <- as.data.table(arrow::read_parquet(file.path(oof_dir(SAM_TAG), "row_preds_models.parquet")))
x <- sm[, c(OOF_KEYS, OOF_BASES, SAM_CANDS), with = FALSE]
setnames(x, SAM_CANDS, paste0("sam_", SAM_CANDS))
for (t in W7_TAGS) x <- merge(x, read_row_preds(t)[, .(valid_year, row_id, p = pred)][, setnames(.SD, "p", t)],
                              by = c("valid_year", "row_id"))
cands <- c(W7_TAGS, paste0("sam_", SAM_CANDS))

stack_line <- function(d, folds) {
  P <- as.matrix(d[, ..cands]); y <- d[[BASIS]]; e <- d$exposure; f <- d$valid_year
  sc <- function(w) mean(vapply(folds, function(k) { i <- f == k; oof_d2(y[i], drop(P[i, , drop = FALSE] %*% w), e[i]) }, numeric(1)))
  cnt <- setNames(numeric(length(cands)), cands)
  for (s in seq_len(STEPS)) {
    v <- vapply(cands, function(cc) { w <- cnt; w[cc] <- w[cc] + 1; sc(w / sum(w)) }, numeric(1))
    cnt[which.max(v)] <- cnt[which.max(v)] + 1
  }
  w <- cnt / sum(cnt)
  list(w = w, sc = sc)
}
folds <- sort(unique(x$valid_year))
res <- list(); wts <- list(); cross <- list(); out <- list()
for (ln in LINES) {
  d <- x[line == ln]
  s <- stack_line(d, folds)
  best_single <- max(vapply(cands, function(cc) s$sc(setNames(as.numeric(cands == cc), cands)), numeric(1)))
  w7_only <- s$sc(setNames(as.numeric(cands == W7_TAGS[1]), cands))
  cf <- vapply(folds, function(k) {
    o <- setdiff(folds, k); sk <- stack_line(d, k)
    so <- stack_line(d, o)$sc                                     # scorer on the other fold
    so(sk$w) - so(setNames(as.numeric(cands == W7_TAGS[1]), cands))
  }, numeric(1))
  wts[[ln]] <- data.table(line = ln, candidate = cands, weight = s$w)
  res[[ln]] <- data.table(line = ln, d2_stack = s$sc(s$w), d2_w7 = w7_only, best_single = best_single,
                          crossfold_gain_vs_w7 = paste(round(cf, 5), collapse = " / "))
  o <- d[, c(OOF_KEYS, OOF_BASES), with = FALSE]
  o[, pred := drop(as.matrix(d[, ..cands]) %*% s$w)]
  out[[ln]] <- o
}
print(rbindlist(res)); print(dcast(rbindlist(wts), candidate ~ line, value.var = "weight"))
lr <- rbindlist(out)
dir <- write_row_preds(lr, NULL, OUT_TAG)
fwrite(rbindlist(wts), file.path(dir, "stack_weights.csv")); fwrite(rbindlist(res), file.path(dir, "stack_crossfold.csv"))
ls <- score_row_preds(lr)[, iteration := OUT_TAG]; fwrite(ls, file.path(dir, "line_scores.csv"))
log_msg("Stack mean ", BASIS, " D2 ALL: ", round(ls[basis == BASIS & line == "ALL", mean(d2)], 5))
