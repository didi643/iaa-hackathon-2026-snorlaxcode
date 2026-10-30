# 20_post_process.R -----------------------------------------------------------------------------------------------------
# Purpose : X20 (26 Oct 2026): post-processing of finished runs, scored by 13_compare_runs.R and built by 15_candidate_from_tag.R
#             MODE=avg      arithmetic mean of pred_B over SOURCES (row x peril for 2025, row for the 2024 validation rows)
#             MODE=stretch  total prediction per row raised to POWER and rescaled per line so each line's total is unchanged
#                           (POWER > 1 widens the risk differentiation, < 1 dampens it); applied to SOURCES[1]
#           Validation and 2025 are processed the same way (the line totals are kept on each set separately).
# Inputs  : data/week_2/optionB/valid_rows/<source>.parquet, data/week_2/optionB/final/<source>/pred_2025_peril.parquet
# Outputs : data/week_2/optionB/valid_rows/<OUT>.parquet, data/week_2/optionB/final/<OUT>/pred_2025_peril.parquet
# Run     : OUT=x20_avg MODE=avg SOURCES=final,x19_hyb_bs,x14e Rscript week2/R/20_post_process.R
#           OUT=x20_st105 MODE=stretch SOURCES=final POWER=1.05 Rscript week2/R/20_post_process.R
# Time    : seconds

source("week2/R/00_setup_week2.R")
start_script("20_post_process.R")
OUT <- Sys.getenv("OUT"); MODE <- Sys.getenv("MODE"); SRC <- strsplit(Sys.getenv("SOURCES", "final"), ",")[[1]]
POWER <- as.numeric(Sys.getenv("POWER", "1"))
stopifnot(nzchar(OUT), MODE %in% c("avg", "stretch"))
vr <- lapply(SRC, function(t) read_w2(file.path(W2$data, "valid_rows", paste0(t, ".parquet"))))
fp <- lapply(SRC, function(t) read_w2(file.path(W2$data, "final", t, "pred_2025_peril.parquet")))
v <- copy(vr[[1]]); f <- copy(fp[[1]])
if (MODE == "avg") {
  for (k in seq_along(SRC)[-1]) {
    stopifnot(identical(vr[[k]]$row_id, v$row_id))
    m <- fp[[k]][, .(row_id, peril, p = pred_B)]; f[m, on = c("row_id", "peril"), pk := i.p]; stopifnot(!anyNA(f$pk))
    v[, pred_B := pred_B + vr[[k]]$pred_B]; f[, pred_B := pred_B + pk][, pk := NULL]
  }
  v[, pred_B := pred_B / length(SRC)]; f[, pred_B := pred_B / length(SRC)]
} else {
  stretch <- function(p, ln) { q <- p^POWER; q * ave(p, ln, FUN = sum) / ave(q, ln, FUN = sum) }
  v[pred_B > 0, pred_B := stretch(pred_B, line)]
  rt <- f[, .(tot = sum(pred_B)), by = .(row_id, line)][tot > 0][, new := stretch(tot, line)]
  f[rt, on = "row_id", pred_B := pred_B * i.new / i.tot]
}
write_w2(v, file.path(W2$data, "valid_rows", paste0(OUT, ".parquet")))
write_w2(f, file.path(W2$data, "final", OUT, "pred_2025_peril.parquet"))
log_msg(sprintf("%s: %s of %s%s; 2025 total %.0f (source 1: %.0f)", OUT, MODE, paste(SRC, collapse = ","), if (MODE == "stretch") sprintf(", power %.2f", POWER) else "",
                sum(f$pred_B), sum(fp[[1]]$pred_B)))
end_script()
