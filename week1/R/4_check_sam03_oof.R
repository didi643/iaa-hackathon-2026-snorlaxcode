# 4_check_sam03_oof.R -------------------------------------------------------------------------------------------
# Saves SAM 3's out-of-time validation predictions in the week1/R/oof_io.R format so SAM 3 can be compared with and blended
# with WENDY 7 runs (backlog C1). Like week1/R/4_check_reported_w4.R, the SAM 3 code is NOT copied: week1/R/4_models_itersam03.R
# is parsed and every top-level expression before its "# Phase 0 diagnostics" section is run (data rebuild, tuning,
# rolling validation), so models, seeds and blend weights are SAM 3's own. Two settings are redirected so nothing of
# SAM 3 is overwritten: DATA_DIR -> data/week_1/wendy07_sam03 (own cache), ITER_DIR -> week1/output/4_check_reported/sam03/model.
# Actuals (reported_raw / reported_adj / developed) are taken from a WENDY 7 run on the same rows (BASE_TAG), so
# both runs are scored on identical actuals; SAM 3's own actual is kept as a check.
#
# Run:  BASE_TAG=wendy07_a0 Rscript week1/R/4_check_sam03_oof.R       (SAM03_REUSE_DATA=1 reuses data/week_1/wendy07_sam03)
# Out:  week1/output/4_check_reported/sam03/ row_preds.parquet (blend), row_preds_models.parquet (every SAM 3 candidate),
#       line_scores.csv

source("week1/R/0_setup.R")
source("week1/R/oof_io.R")
BASE_TAG <- Sys.getenv("BASE_TAG", "wendy07_a0")
SAM_SCRIPT <- "week1/R/4_models_itersam03.R"
OWN_DATA <- file.path("data", "week_1", "wendy07_sam03")

src <- readLines(SAM_SCRIPT, warn = FALSE)
stop_line <- grep("^# Phase 0 diagnostics", src)[1]
if (is.na(stop_line)) stop("Marker '# Phase 0 diagnostics' not found in ", SAM_SCRIPT)
exprs <- parse(SAM_SCRIPT, keep.source = TRUE)
starts <- vapply(attr(exprs, "srcref"), function(s) as.integer(s[1]), integer(1))
pre <- exprs[starts < stop_line]
log_msg("Running ", length(pre), " top-level expressions of ", SAM_SCRIPT, " (lines 1-", stop_line - 1, ")")
for (e in pre) {
  eval(e, envir = globalenv())
  if (exists("DATA_DIR") && identical(DATA_DIR, file.path("data", "week_1", "sam03"))) {
    assign("DATA_DIR", OWN_DATA, envir = globalenv()); log_msg("DATA_DIR redirected to ", OWN_DATA)
  }
  if (exists("ITER_DIR") && grepl("^week1/models/sam_iteration_03", ITER_DIR)) {
    assign("ITER_DIR", file.path(oof_dir("sam03"), "model"), envir = globalenv())
    assign("FITTED_DIR", file.path(ITER_DIR, "fitted"), envir = globalenv())
    log_msg("ITER_DIR redirected to ", ITER_DIR)
  }
}
if (!exists("vp_all")) stop("vp_all not built by ", SAM_SCRIPT)

base <- read_row_preds(BASE_TAG)
models <- intersect(c("blend", CANDIDATES), names(vp_all))
sp <- vp_all[valid_year %in% unique(base$valid_year), c("valid_year", "row_id", "actual", models), with = FALSE]
m <- merge(base[, c(OOF_KEYS, OOF_BASES), with = FALSE], sp, by = c("valid_year", "row_id"))
if (nrow(m) != nrow(base)) warning("SAM 3 covers ", nrow(m), " of ", nrow(base), " base rows")
log_msg("SAM 3 actual vs base reported_raw: total ratio ", round(sum(m$actual) / sum(m$reported_raw), 5),
        ", rows differing ", m[abs(actual - reported_raw) > 1e-6, .N])
line_rows <- m[, c(OOF_KEYS, OOF_BASES), with = FALSE][, pred := m$blend]
dir <- write_row_preds(line_rows, NULL, "sam03")
arrow::write_parquet(m, file.path(dir, "row_preds_models.parquet"))
ls <- score_row_preds(line_rows)[, iteration := "sam03"]
fwrite(ls, file.path(dir, "line_scores.csv"))
print(ls[basis == "reported_raw"])
log_msg("Done: ", dir)
