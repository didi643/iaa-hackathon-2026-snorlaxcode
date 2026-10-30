# 14_blend_severity.R --------------------------------------------------------------------------------------------------
# Purpose : X13 (Wendy's idea, 26 Oct 2026): blend two step 7 runs' severities geometrically, row by row:
#             sev = sev_A^(1 - w) x sev_B^w
#           A = developed severity shape x emerging level (main), B = emerging-only severity GLM (x12a_msel). Frequency, levels
#           and everything else are taken from A. Writes a new run tag that steps 8, 9 and 13 read like any step 7 output.
# Inputs  : data/week_2/optionB/adjust/{BLEND_A,BLEND_B}/*.parquet, week2/output/07_adjust/levels[_A].csv
# Outputs : data/week_2/optionB/adjust/<RUN_TAG>/*.parquet, week2/output/07_adjust/levels_<RUN_TAG>.csv
# Run     : RUN_TAG=<tag> BLEND_A=main BLEND_B=x12a_msel BLEND_W=0.5 BLEND_LINES=motor [BLEND_PERILS=motor/own_damage,...] Rscript week2/R/14_blend_severity.R
# Time    : seconds

source("week2/R/00_setup_week2.R")
start_script("14_blend_severity.R")
TAG <- Sys.getenv("RUN_TAG"); A <- Sys.getenv("BLEND_A", "main"); B <- Sys.getenv("BLEND_B", "x12a_msel")
W <- as.numeric(Sys.getenv("BLEND_W", "0.5")); BL <- strsplit(Sys.getenv("BLEND_LINES", "motor"), ",")[[1]]
BP <- Sys.getenv("BLEND_PERILS", "")   # X14: "line/peril,line/peril" - blend only these perils (overrides BLEND_LINES)
BP <- if (nzchar(BP)) strsplit(BP, ",")[[1]] else character(0)
RELEVEL <- Sys.getenv("BLEND_RELEVEL", "0") == "1"   # X14: rescale each blended peril so its total predicted cost equals A's (shape only)
stopifnot(nzchar(TAG), TAG != "main", W >= 0, W <= 1)
for (f in c("valid_2024_peril", "final_2025_peril", "insample_peril", "insample23_peril")) {
  fa <- file.path(W2$data, "adjust", A, paste0(f, ".parquet")); fb <- file.path(W2$data, "adjust", B, paste0(f, ".parquet"))
  if (!file.exists(fa)) next
  a <- read_w2(fa)
  if (!file.exists(fb)) {   # NB round: B runs older than the insample23 output - pass A through, relevel keeps totals anyway
    write_w2(a, file.path(W2$data, "adjust", TAG, paste0(f, ".parquet"))); next
  }
  b <- read_w2(fb)[, .(row_id, peril, sev_b = sev_B)]
  a <- merge(a, b, by = c("row_id", "peril"), all.x = TRUE, sort = FALSE)
  a[, pick := if (length(BP)) paste(line, peril, sep = "/") %in% BP else line %in% BL]
  stopifnot(a[pick == TRUE, !anyNA(sev_b)])
  fcol <- if ("freq_B" %in% names(a)) "freq_B" else stop("freq_B missing")
  a[, cost0 := exposure * freq_B * sev_B]
  a[pick == TRUE & sev_B > 0 & sev_b > 0, sev_B := sev_B^(1 - W) * sev_b^W]
  if (RELEVEL) a[pick == TRUE, sev_B := sev_B * sum(cost0) / sum(exposure * freq_B * sev_B), by = .(line, peril)]
  a[, c("sev_b", "pick", "cost0") := NULL]
  write_w2(a, file.path(W2$data, "adjust", TAG, paste0(f, ".parquet")))
}
lv_a <- file.path(W2$output, "07_adjust", if (A == "main") "levels.csv" else paste0("levels_", A, ".csv"))
file.copy(lv_a, file.path(W2$output, "07_adjust", paste0("levels_", TAG, ".csv")), overwrite = TRUE); track_input(lv_a)
log_msg(sprintf("%s = %s x %s severity blend, w = %.2f on %s", TAG, A, B, W, paste(if (length(BP)) BP else BL, collapse = ",")))
end_script()
