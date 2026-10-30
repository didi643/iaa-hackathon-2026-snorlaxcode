# 15_candidate_from_tag.R ----------------------------------------------------------------------------------------------
# Purpose : Build a public-board test file from an experiment run tag (step 8 output data/final/<tag>), with the same checks
#           as step 10 (every sample_submission row, no NA, finite, >= 0, no duplicates), without touching main's step 10
#           outputs or docs. Also compares the 2025 burn per line and peril with main, and the row-level change.
#           First use: X13b (50 / 50 motor severity blend, developed shape x emerging-only GLM), Wendy 26 Oct 2026.
# Inputs  : data/week_2/optionB/final/{<tag>,main}/pred_2025_peril.parquet, data/week_2/raw data/emerging/sample_submission.parquet
# Outputs : week2/output/submission/submission_<runid>_week2_optionB_<tag>.csv (+ .md5),
#           week2/output/15_candidate/<tag>_{checks,burn_vs_main}.csv
# Run     : SOURCE_TAG=x13b Rscript week2/R/15_candidate_from_tag.R
# Time    : seconds

source("week2/R/00_setup_week2.R")
start_script("15_candidate_from_tag.R")
STEP <- "15_candidate"
TAG <- Sys.getenv("SOURCE_TAG"); stopifnot(nzchar(TAG), TAG != "main")
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M", tz = "Asia/Singapore")
rd <- function(t) read_w2(file.path(W2$data, "final", t, "pred_2025_peril.parquet"))
fin <- rd(TAG); fm <- rd("main")
sub <- fin[, .(prediction = sum(pred_B)), by = row_id]
ss <- read_em("sample_submission")
checks <- data.table(check = c("rows = sample_submission", "same row_id set", "no duplicate row_id", "no NA", "all finite", "all >= 0"),
                     ok = c(nrow(sub) == nrow(ss), setequal(sub$row_id, ss$row_id), !anyDuplicated(sub$row_id), !anyNA(sub$prediction),
                            all(is.finite(sub$prediction)), all(sub$prediction >= 0)))
save_csv(checks, STEP, paste0(TAG, "_checks.csv"))
if (!all(checks$ok)) stop("Submission checks failed: ", paste(checks[ok == FALSE, check], collapse = ", "))
sub <- sub[match(ss$row_id, row_id)]
f_sub <- file.path(W2$output, "submission", sprintf("submission_%s_week2_optionB_%s.csv", RUN_ID, TAG))
fwrite(sub, f_sub, scipen = 50); track_output(f_sub)
md5 <- unname(tools::md5sum(f_sub)); writeLines(paste(md5, basename(f_sub)), paste0(f_sub, ".md5")); track_output(paste0(f_sub, ".md5"))

# Burn vs main (per exposure-year) and row-level change
e <- fin[!duplicated(row_id), .(exposure = sum(exposure)), by = line]
cmp <- merge(fin[, .(tag = sum(pred_B)), by = .(line, peril)], fm[, .(main = sum(pred_B)), by = .(line, peril)], by = c("line", "peril"))
cmp <- merge(cmp, e, by = "line")[, `:=`(burn_tag = tag / exposure, burn_main = main / exposure, ratio = tag / main)]
cl <- cmp[, .(peril = "ALL", tag = sum(tag), main = sum(main), exposure = exposure[1]), by = line][, `:=`(burn_tag = tag / exposure, burn_main = main / exposure, ratio = tag / main)]
out <- rbind(cmp, cl)[, .(line, peril, burn_main, burn_tag, ratio)]
save_csv(out, STEP, paste0(TAG, "_burn_vs_main.csv"))
rm_ <- merge(sub, fm[, .(main = sum(pred_B)), by = row_id], by = "row_id")[main > 0, r := prediction / main]
log_msg(sprintf("%s: %s, MD5 %s; total vs main %.4f; row ratio p1 / p50 / p99 = %.3f / %.3f / %.3f", TAG, basename(f_sub), md5,
                sum(sub$prediction) / sum(fm$pred_B), quantile(rm_$r, 0.01, na.rm = TRUE), median(rm_$r, na.rm = TRUE), quantile(rm_$r, 0.99, na.rm = TRUE)))
print(out[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 3) else x)])
end_script()
