# Re-runs WENDY 4's 2024 validation fold (fit 2021-23, score 2024 vs developed actuals), checks it reproduces the
# local D2 recorded in week1/models/wendy_iteration_04/, and lists it next to SAM iterations 2 and 3.
# NOTE: WENDY 4 is scored vs developed actuals and SAM vs reported cost, so the SAM rows are not like-for-like;
# week1/tests/test_wendy04_sam_basis_2024.R re-scores WENDY 4 on SAM's basis.
# Run from the project root: Rscript week1/tests/test_wendy04_validation_2024.R   (refits the 2024 fold, so it takes a while)
# Nothing is written to the model folders or week1/output/submission: only the validation part of week1/R/4_models_iterwendy04.R
# is evaluated (up to, not including, its final fit), and the result goes to week1/output/tests/.

W4_DIR <- file.path("week1", "models", "wendy_iteration_04")
W4_SCRIPT <- "week1/R/4_models_iterwendy04.R"
TOL_ALL <- 5e-4    # xgboost with several threads can differ slightly between runs
TOL_LINE <- 1e-3

# Use the workbook saved with the reported run (week1/docs/ may have been edited since) and the full, non-FAST setup
Sys.setenv(ASSUMPTIONS_XLSX = file.path(W4_DIR, "assumptions_wendy04.xlsx"), FAST = "0")
stopifnot(file.exists(Sys.getenv("ASSUMPTIONS_XLSX")), file.exists(file.path(W4_DIR, "validation_by_line.csv")))

src <- readLines(W4_SCRIPT, warn = FALSE)
i_vy <- grep("^VALID_YEARS <- ", src)
i_sel <- grep("^# Selection per peril", src)
i_line <- grep("^# Line and portfolio scores", src)
i_final <- grep("^# 8\\. Final fit", src)
stopifnot(length(i_vy) == 1, length(i_sel) == 1, length(i_line) == 1, length(i_final) == 1)

# Validation year 2024 only; the seeds depend on the year, so the 2024 fit is the same as in the full run
src[i_vy] <- "VALID_YEARS <- 2024L"
run <- function(lines) eval(parse(text = lines, keep.source = FALSE), envir = globalenv())
run(src[seq_len(i_sel - 1)])

# Method choice as reported (mean D2 over 2023-24 in the full run), not re-chosen on one fold
chosen <- fread(file.path(W4_DIR, "chosen_method.csv"))
run(src[i_line:(i_final - 1)])

new <- line_val[mix == "chosen" & valid_year == 2024, .(line, d2, gini, pred_vs_developed)]
old <- fread(file.path(W4_DIR, "validation_by_line.csv"))[mix == "chosen" & valid_year == 2024,
                                                          .(line, d2_reported = d2)]
chk <- merge(new, old, by = "line")[, diff := d2 - d2_reported]
print(chk)
stopifnot(abs(chk[line == "ALL", diff]) < TOL_ALL, all(abs(chk[line != "ALL", diff]) < TOL_LINE))
cat("WENDY 4 2024 validation reproduced the reported local D2\n")

# Comparison with SAM 2 and 3: submitted blend, local D2 2024 from each iteration's summary.csv
sam <- rbindlist(lapply(c(2, 3), function(i) {
  s <- fread(file.path("week1", "models", sprintf("sam_iteration_%02d", i), "summary.csv"))
  data.table(iteration = paste("SAM", i), motor = s$d2_motor_2024, buildings = s$d2_buildings_2024,
             contents = s$d2_contents_2024, ALL = s$local_d2_2024)
}))
w4 <- dcast(new, . ~ line, value.var = "d2")[, . := NULL][, iteration := "WENDY 4 (re-run)"]
cmp <- rbind(w4, sam, fill = TRUE)[, .(iteration, motor, buildings, contents, ALL)]
cmp[, vs_wendy4 := ALL - cmp[iteration == "WENDY 4 (re-run)", ALL]]
cat("\nLocal D2 2024 (fit 2021-23; WENDY 4 vs developed actuals, SAM vs reported cost - NOT the same basis)\n")
print(cmp, digits = 4)
fwrite(cmp, out_file("tests", "wendy04_vs_sam_local_d2_2024.csv"))
cat("comparison saved to week1/output/tests/wendy04_vs_sam_local_d2_2024.csv\n")
