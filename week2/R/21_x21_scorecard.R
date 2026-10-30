# 21_x21_scorecard.R ----------------------------------------------------------------------------------------------------
# Purpose : X21 round (27 Oct 2026): standard week 2 scorecard (score_w2.R: frequency / severity / cost D2 and A/E by peril,
#           line and ALL on the 2024 validation fold) for an Option B run tag and the reference run, plus the per-peril
#           deltas (tag - reference) used to document each X21 step.
# Inputs  : data/week_2/optionB/adjust/<tag>/valid_2024_peril.parquet (freq_B per exposure-year, sev_B), same for REF
# Outputs : week2/output/scores/x21/<tag>_vs_<ref>.csv (+ .md); model_scores.csv rows for MODEL (if RECORD=1)
# Run     : RUN_TAG=<tag> REF=x20_tblend MODEL=OPTB_X21A RECORD=1 Rscript week2/R/21_x21_scorecard.R
# Time    : < 1 min

source("week2/R/0_setup_w2.R"); source("week2/R/score_w2.R")
TAG <- Sys.getenv("RUN_TAG"); REF <- Sys.getenv("REF", "x20_tblend"); MODEL <- Sys.getenv("MODEL", toupper(paste0("OPTB_", TAG)))
DESC <- Sys.getenv("DESC", TAG)
sc_of <- function(tag, model, desc) {
  vp <- as.data.table(arrow::read_parquet(file.path("data", "week_2", "optionB", "adjust", tag, "valid_2024_peril.parquet")))
  score_model_w2(vp[, .(row_id, line, peril, exposure, freq = exposure * freq_B, sev = sev_B)], model, desc,
                 "week2/R/07_emerging_adjust.R -> 14 -> 08 -> 09 (X21 round)")
}
s_ref <- sc_of(REF, toupper(paste0("OPTB_", REF)), REF); s_tag <- sc_of(TAG, MODEL, DESC)
k <- c("component", "level", "line", "peril")
d <- merge(s_ref[, c(k, "d2", "ae"), with = FALSE], s_tag[, c(k, "d2", "ae"), with = FALSE], by = k, suffixes = c("_ref", "_new"))
d[, d2_delta := d2_new - d2_ref][, verdict := fifelse(abs(d2_delta) < 5e-5, "same", fifelse(d2_delta > 0, "improve", "worse"))]
d[, level := factor(level, c("peril", "line", "all"))]; setorder(d, component, level, line, peril)
dir.create(file.path(PATHS_W2$output, "scores", "x21"), recursive = TRUE, showWarnings = FALSE)
fwrite(d, file.path(PATHS_W2$output, "scores", "x21", sprintf("%s_vs_%s.csv", TAG, REF)))
w <- dcast(d, line + peril ~ component, value.var = "d2_delta")
f <- function(v) formatC(v, format = "f", digits = 4)
md <- c(sprintf("# %s vs %s: D2 change (new - ref) on the 2024 validation fold", TAG, REF), "",
        "| line | peril | frequency | severity | cost |", "|---|---|---|---|---|",
        w[, sprintf("| %s | %s | %s | %s | %s |", line, peril, f(frequency), f(severity), f(cost))])
writeLines(md, file.path(PATHS_W2$output, "scores", "x21", sprintf("%s_vs_%s.md", TAG, REF)))
cat(md, sep = "\n")
if (Sys.getenv("RECORD", "0") == "1") record_scores_w2(s_tag)