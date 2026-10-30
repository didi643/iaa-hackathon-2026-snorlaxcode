# 4_blend_wendy07.R ---------------------------------------------------------------------------------------------
# Backlog B3 / C1 on saved row predictions (no refit): per peril, blend weight w of freq_sev vs tweedie
# (pred = w * freq_sev + (1 - w) * tweedie, grid BLEND_GRID), chosen by coordinate ascent on the ALL-lines D2 of
# BASIS averaged over the folds. Optimism is measured by choosing on one fold and scoring the other.
#
# Run:   RUN_TAG=wendy07_a0 Rscript week1/R/4_blend_wendy07.R
# Out:   week1/output/4_check_reported/<tag>_blend/ (row_preds.parquet etc. in the week1/R/oof_io.R format, blend_weights.csv,
#        blend_crossfold.csv) - compare with compare_row_preds("<tag>_blend", "<tag>")

source("week1/R/0_setup.R")
source("week1/R/oof_io.R")
setDTthreads(as.integer(Sys.getenv("DT_THREADS", "2")))   # leave cores to xgboost runs in parallel
TAG <- Sys.getenv("RUN_TAG", "wendy07_a0")
BASIS <- Sys.getenv("BASIS", "reported_raw")
GRID <- seq(0, 1, by = 0.25)

pp <- read_row_preds(TAG, level = "peril")
pk <- rbindlist(lapply(LINES, function(ln) data.table(line = ln, peril = PERILS[[ln]])))
pk <- pk[vapply(seq_len(nrow(pk)), function(i) all(paste0("pred_", pk$peril[i], c("_freq_sev", "_tweedie")) %in% names(pp)), logical(1))]

line_pred <- function(d, w) {                  # w: named by "line peril"; perils without a weight keep pred_<peril>
  ln <- d$line[1]
  Reduce(`+`, lapply(PERILS[[ln]], function(pr) {
    k <- paste(ln, pr)
    if (k %in% names(w)) w[[k]] * d[[paste0("pred_", pr, "_freq_sev")]] + (1 - w[[k]]) * d[[paste0("pred_", pr, "_tweedie")]]
    else d[[paste0("pred_", pr)]]
  }))
}
actual <- function(d) Reduce(`+`, lapply(PERILS[[d$line[1]]], function(pr) d[[paste0(BASIS, "_", pr)]]))
by_line <- split(pp, by = "line")
act <- lapply(by_line, actual)
score <- function(w, folds) {
  p <- unlist(lapply(by_line, line_pred, w = w)); y <- unlist(act)
  vy <- unlist(lapply(by_line, `[[`, "valid_year")); e <- unlist(lapply(by_line, `[[`, "exposure"))
  mean(vapply(folds, function(f) { i <- vy == f; oof_d2(y[i], p[i], e[i]) }, numeric(1)))
}
choose <- function(folds) {
  w <- setNames(as.numeric(pk[, mapply(function(ln, pr) {
    all(pp[line == ln, get(paste0("pred_", pr))] == pp[line == ln, get(paste0("pred_", pr, "_freq_sev"))])
  }, line, peril)]), pk[, paste(line, peril)])          # start at the run's own mix (1 = freq_sev, 0 = tweedie)
  best <- score(w, folds)
  for (it in 1:3) {
    moved <- FALSE
    for (k in names(w)) for (g in GRID) {
      if (g == w[[k]]) next
      w2 <- w; w2[[k]] <- g
      s <- score(w2, folds)
      if (s > best + 1e-6) { best <- s; w <- w2; moved <- TRUE }
    }
    if (!moved) break
  }
  list(w = w, score = best)
}

folds <- sort(unique(pp$valid_year))
w0 <- choose(folds)$w
base <- score(setNames(numeric(0), character(0)), folds)
cross <- rbindlist(lapply(folds, function(f) {
  o <- setdiff(folds, f)
  wf <- choose(f)$w
  data.table(chosen_on = f, scored_on = o, d2_base = score(setNames(numeric(0), character(0)), o),
             d2_blend = score(wf, o))[, gain := d2_blend - d2_base]
}))
print(cross)
log_msg("Mean ", BASIS, " D2 over folds: run mix ", round(base, 5), ", blend ", round(score(w0, folds), 5),
        " (in-sample); cross-fold gain ", paste(round(cross$gain, 5), collapse = " / "))

out_tag <- paste0(TAG, "_blend")
lr <- rbindlist(lapply(by_line, function(d) {
  o <- d[, ..OOF_KEYS]
  o[, pred := line_pred(d, w0)]
  for (b in OOF_BASES) set(o, j = b, value = Reduce(`+`, lapply(PERILS[[d$line[1]]], function(pr) d[[paste0(b, "_", pr)]])))
  o
}))
dir <- write_row_preds(lr, NULL, out_tag)
fwrite(data.table(pk_ = names(w0), w_freq_sev = w0)[, c("line", "peril") := tstrsplit(pk_, " ")][, .(line, peril, w_freq_sev)],
       file.path(dir, "blend_weights.csv"))
fwrite(cross, file.path(dir, "blend_crossfold.csv"))
ls <- score_row_preds(lr)[, iteration := out_tag]
fwrite(ls, file.path(dir, "line_scores.csv"))
print(data.table(peril_key = names(w0), w_freq_sev = w0))

# Optional: apply the weights to a final fit's 2025 per-peril predictions (FINAL_METHODS=all run)
TEST_PREDS <- Sys.getenv("TEST_PREDS", "")
if (nzchar(TEST_PREDS)) {
  tp <- as.data.table(arrow::read_parquet(TEST_PREDS))
  tb <- rbindlist(lapply(split(tp, by = "line"), function(d) d[, .(row_id, line, exposure, pred = pmax(line_pred(d, w0), 0))]))
  arrow::write_parquet(tb, file.path(dir, "test_pred_blend.parquet"))
  print(tb[, .(rows = .N, burn = sum(pred) / sum(exposure)), by = line])
  log_msg("2025 blended predictions: ", file.path(dir, "test_pred_blend.parquet"))
}
