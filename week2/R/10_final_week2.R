# 10_final_week2.R ---------------------------------------------------------------------------------------------------
# Purpose : Build the 2025 candidate submission from the chosen candidate (B, decision D023): sum of the per-peril
#           2025 predictions per row (step 8), checks (every sample_submission row, no NA, >= 0, no duplicates), burn by
#           line and peril against the 2023-24 emerging experience (developed actuals, as-is and reweighted to the
#           2025 new-business x channel mix), and the uncertainty range per line (step 8 sensitivities + the
#           step 9 level uncertainty). NOT submitted (handover rule 5).
# Inputs  : data/week_2/optionB/final/main/pred_2025_peril.parquet, data/week_2/raw data/emerging/sample_submission.parquet,
#           week2/output/08_loadings/main/sensitivity.csv, week2/output/09_validate/main/calibration.csv,
#           data/week_2/optionB/features/emerging_{train,test}_<line>.parquet, emerging claims
# Outputs : week2/output/submission/submission_<runid>_week2_optionB.csv (+ .md5), week2/output/10_final/
#           (burn_by_line.csv, burn_by_peril.csv, uncertainty_by_line.csv, checks.csv, final_report.md)
# Run     : Rscript week2/R/10_final_week2.R      (CANDIDATE=B default)
# Time    : under 1 minute

source("week2/R/00_setup_week2.R")
start_script("10_final_week2.R")
STEP <- "10_final"
CAND <- Sys.getenv("CANDIDATE", "B")
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M", tz = "Asia/Singapore")
FEAT_DIR <- file.path(W2$data, "features")
shares <- load_report_shares()

fin <- read_w2(file.path(W2$data, "final", "main", "pred_2025_peril.parquet"))
pcol <- paste0("pred_", CAND)
sub <- fin[, .(prediction = sum(get(pcol))), by = row_id]
ss <- read_em("sample_submission")
checks <- data.table(check = c("rows = sample_submission", "same row_id set", "no duplicate row_id", "no NA", "all finite", "all >= 0"),
                     ok = c(nrow(sub) == nrow(ss), setequal(sub$row_id, ss$row_id), !anyDuplicated(sub$row_id), !anyNA(sub$prediction),
                            all(is.finite(sub$prediction)), all(sub$prediction >= 0)))
save_csv(checks, STEP, "checks.csv")
if (!all(checks$ok)) stop("Submission checks failed: ", paste(checks[ok == FALSE, check], collapse = ", "))
sub <- sub[match(ss$row_id, row_id)]
f_sub <- file.path(W2$output, "submission", sprintf("submission_%s_week2_optionB.csv", RUN_ID))
dir.create(dirname(f_sub), recursive = TRUE, showWarnings = FALSE)
fwrite(sub, f_sub, scipen = 50); track_output(f_sub)
md5 <- unname(tools::md5sum(f_sub)); writeLines(paste(md5, basename(f_sub)), paste0(f_sub, ".md5")); track_output(paste0(f_sub, ".md5"))

# 2023-24 emerging experience on developed actuals (claim basis / reported share), as-is and at the 2025 mix ------------------
clp <- claim_basis("emerging")
hist <- rbindlist(lapply(LINES, function(ln) {
  tr <- read_w2(file.path(FEAT_DIR, sprintf("emerging_train_%s.parquet", ln)))
  te <- read_w2(file.path(FEAT_DIR, sprintf("emerging_test_%s.parquet", ln)))
  mix <- te[, .(e = sum(exposure)), by = .(new_business, channel)][, s_test := e / sum(e)]
  cell <- tr[, .(e = sum(exposure)), by = .(policy_year, new_business, channel)][, s := e / sum(e), by = policy_year]
  cell <- merge(cell, mix[, .(new_business, channel, s_test)], by = c("new_business", "channel"))[, w := s_test / s]
  tr <- merge(tr, cell[, .(policy_year, new_business, channel, w)], by = c("policy_year", "new_business", "channel"))
  rbindlist(lapply(PERILS[[ln]], function(pr) {
    a <- clp[line == ln & peril == pr, .(c = sum(cost)), by = row_id][tr[, .(row_id, policy_year, exposure, w, period_start, period_end)], on = "row_id"]
    a[is.na(c), c := 0]
    a[, dev := c / row_report_share(shares, ln, pr, period_start, period_end)]
    a[, .(line = ln, peril = pr, exposure = sum(exposure), actual = sum(dev), exposure_w = sum(exposure * w), actual_w = sum(dev * w)), by = policy_year]
  }))
}))
bp <- fin[, .(pred_2025 = sum(get(pcol)), exposure_2025 = sum(exposure)), by = .(line, peril)]
hb <- dcast(hist[, .(burn = actual / exposure, burn_mix = actual_w / exposure_w, line, peril, policy_year)], line + peril ~ policy_year, value.var = c("burn", "burn_mix"))
burn_peril <- merge(bp[, .(line, peril, burn_2025 = pred_2025 / exposure_2025)], hb, by = c("line", "peril"))
save_csv(burn_peril, STEP, "burn_by_peril.csv")
expo25 <- fin[!duplicated(row_id), .(exposure_2025 = sum(exposure)), by = line]
burn_line <- merge(fin[, .(pred_2025 = sum(get(pcol))), by = line], expo25, by = "line")
hl <- hist[, .(actual = sum(actual), exposure = sum(exposure) / uniqueN(peril), actual_w = sum(actual_w), exposure_w = sum(exposure_w) / uniqueN(peril)), by = .(line, policy_year)]
hl <- dcast(hl[, .(line, policy_year, burn = actual / exposure, burn_mix = actual_w / exposure_w)], line ~ policy_year, value.var = c("burn", "burn_mix"))
burn_line <- merge(burn_line[, .(line, exposure_2025, burn_2025 = pred_2025 / exposure_2025)], hl, by = "line")
save_csv(burn_line, STEP, "burn_by_line.csv")

# Uncertainty per line: low / high from the step 8 scenarios (trend, NB, IBNR, large loss) combined in quadrature with the
# level uncertainty (step 9: 2024 A/E of B by line on developed actuals as a one-year level error) and the dropped-field cost
sens <- fread(file.path(W2$output, "08_loadings", "main", "sensitivity.csv")); track_input(file.path(W2$output, "08_loadings", "main", "sensitivity.csv"))
cal <- fread(file.path(W2$output, "09_validate", "main", "calibration.csv")); track_input(file.path(W2$output, "09_validate", "main", "calibration.csv"))
# level error = one-year A/E miss of B in 2024 combined with the 2023 -> 2024 swing of the emerging burn (year-to-year noise)
lvl_err <- cal[group == "line x peril", .(ae = sum(actual) / sum(pred), claims = sum(claims, na.rm = TRUE)), by = .(line = sub(" .*", "", level))]
lvl_err <- merge(lvl_err, burn_line[, .(line, swing = log(burn_2024 / burn_2023))], by = "line")
lvl_err[, lvl_sd := sqrt(log(ae)^2 + swing^2 / 2 + 1 / claims)]
comp <- sens[scenario %in% c("trend_low", "trend_high", "nb_none", "nb_full_emerging", "ibnr_plus5", "large_loss_emerging_load"),
             .(dn = min(0, min(vs_central)), up = max(0, max(vs_central))), by = .(line, scenario = sub("_(low|high|none|full_emerging|plus5|emerging_load)$", "", scenario))]
unc <- comp[, .(sd_dn = sqrt(sum(dn^2)), sd_up = sqrt(sum(up^2))), by = line]
unc <- merge(merge(unc, lvl_err[, .(line, lvl_sd)], by = "line"), burn_line[, .(line, burn_2025)], by = "line")
unc[, `:=`(low = burn_2025 * exp(-sqrt(sd_dn^2 + lvl_sd^2)), high = burn_2025 * exp(sqrt(sd_up^2 + lvl_sd^2)))]
save_csv(unc, STEP, "uncertainty_by_line.csv")

kl <- c(sprintf("- Candidate %s file `%s` (MD5 `%s`), %s rows, all checks passed. NOT submitted.", CAND, f_sub, md5, format(nrow(sub), big.mark = ",")),
        sprintf("- 2025 burn per exposure-year (central, low-high): %s.", paste(unc[, sprintf("%s %.0f (%.0f-%.0f)", line, burn_2025, low, high)], collapse = "; ")),
        sprintf("- 2023 / 2024 developed burn at the 2025 mix: %s.", paste(burn_line[, sprintf("%s %.0f / %.0f", line, burn_mix_2023, burn_mix_2024)], collapse = "; ")))
write_md(list("# Step 10: 2025 candidate file", "", paste("Generated", ts_sgt(), "by `week2/R/10_final_week2.R`."), "", kl, "",
              "## Checks", "", md_table(checks), "## Burn by line", "", md_table(burn_line, 1), "## Burn by peril", "", md_table(burn_peril, 2),
              "## Uncertainty by line", "", md_table(unc, 3)), STEP, "final_report.md")
add_decision("D024", "10", paste("Candidate file built from", CAND, "; not submitted - waiting for Wendy"), "Submit now", f_sub, "open question for Wendy")
update_step_log("10", "2025 candidate file", kl)
end_script()
