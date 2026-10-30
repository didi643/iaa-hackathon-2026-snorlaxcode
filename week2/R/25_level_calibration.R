# 25_level_calibration.R ------------------------------------------------------------------------------------------------
# Purpose : 2025 level calibration on top of the best file (submission 12, line_ensemble = x20_tblend motor rows +
#           rt_var_b8_floor_corrected buildings / contents rows). Applies multiplicative level factors by line or by
#           line/peril and writes a checked submission file. Used for the level probes (one line moved at a time) and
#           for the final calibrated file.
#           Why: the public 33% and the private 67% are the same 2025 book, so the 2025 cost level is the part of the
#           public score that carries over. Every past level increase gained on public; the 2024 fold cannot judge the
#           2025 level (different year, quiet 2024 for home perils).
# Inputs  : data/week_2/optionB/final/{x20_tblend,rt_var_b8_floor_corrected}/pred_2025_peril.parquet
# Outputs : week2/output/submission/submission_<runid>_week2_optionB_<TAG>.csv (+ .md5), week2/output/25_level/<TAG>_burn.csv
# Run     : TAG=lvl_m115 MULT="motor=1.15" Rscript week2/R/25_level_calibration.R
#           MULT entries are comma separated: "<line>=<x>" or "<line>/<peril>=<x>" (peril overrides line).
# Time    : seconds

suppressMessages({library(data.table); library(arrow)})
TAG <- Sys.getenv("TAG"); stopifnot(nzchar(TAG))
MULT <- Sys.getenv("MULT", "")
BASE_MOTOR <- Sys.getenv("BASE_MOTOR", "x20_tblend")
BASE_HOME <- Sys.getenv("BASE_HOME", "rt_var_b8_floor_corrected")
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M", tz = "Asia/Singapore")
rd <- function(t) as.data.table(read_parquet(file.path("data/week_2/optionB/final", t, "pred_2025_peril.parquet"),
                                             col_select = c("line", "peril", "row_id", "exposure", "pred_B")))
p <- rbind(rd(BASE_MOTOR)[line == "motor"], rd(BASE_HOME)[line != "motor"])
p[, m := 1]
if (nzchar(MULT)) {
  spec <- rbindlist(lapply(strsplit(strsplit(MULT, ",")[[1]], "="), function(x) data.table(k = trimws(x[1]), m = as.numeric(x[2]))))
  for (i in seq_len(nrow(spec))) if (!grepl("/", spec$k[i])) p[line == spec$k[i], m := spec$m[i]]
  for (i in seq_len(nrow(spec))) if (grepl("/", spec$k[i])) {
    k <- strsplit(spec$k[i], "/")[[1]]; stopifnot(p[line == k[1] & peril == k[2], .N] > 0)
    p[line == k[1] & peril == k[2], m := spec$m[i]]
  }
}
p[, pred := pred_B * m]
sub <- p[, .(prediction = sum(pred)), by = row_id]
ss <- as.data.table(read_parquet("data/week_2/raw data/emerging/sample_submission.parquet"))
ok <- c(nrow(sub) == nrow(ss), setequal(sub$row_id, ss$row_id), !anyDuplicated(sub$row_id), !anyNA(sub$prediction),
        all(is.finite(sub$prediction)), all(sub$prediction >= 0))
if (!all(ok)) stop("Submission checks failed")
sub <- sub[match(ss$row_id, row_id)]
f_sub <- file.path("week2/output/submission", sprintf("submission_%s_week2_optionB_%s.csv", RUN_ID, TAG))
fwrite(sub, f_sub, scipen = 50)
md5 <- unname(tools::md5sum(f_sub)); writeLines(paste(md5, basename(f_sub)), paste0(f_sub, ".md5"))
dir.create("week2/output/25_level", showWarnings = FALSE, recursive = TRUE)
e <- p[!duplicated(paste(line, row_id)), .(exposure = sum(exposure)), by = line]
burn <- merge(p[, .(base = sum(pred_B), new = sum(pred), m = m[1]), by = .(line, peril)], e, by = "line")
burn <- rbind(burn, burn[, .(peril = "ALL", base = sum(base), new = sum(new), m = sum(new) / sum(base), exposure = exposure[1]), by = line])
burn[, `:=`(burn_base = base / exposure, burn_new = new / exposure)]
fwrite(burn[, .(line, peril, m, burn_base, burn_new)], file.path("week2/output/25_level", paste0(TAG, "_burn.csv")))
cat(sprintf("%s: %s MD5 %s rows %d total vs base %.4f MULT '%s'\n", TAG, basename(f_sub), md5, nrow(sub),
            sum(p$pred) / sum(p$pred_B), MULT))
