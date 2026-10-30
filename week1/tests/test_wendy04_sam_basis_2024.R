# Like-for-like 2024 check of WENDY 4 (default: the SAM 2 clean-data variant) against SAM iterations 2 and 3.
#
# The local D2 2024 values in the model folders are NOT on the same basis:
#   WENDY 4 / WENDY 4 VSAM02 CLEAN  scored vs DEVELOPED actuals: claims after the outlier limit and the open-claim
#                                   recovery adjustment, divided by each row's reported share (IBNR development)
#   SAM 2 / SAM 3                   scored vs REPORTED actuals: y_cost = sum of reported net cost (no limit, no
#                                   development); developed actuals are only used for the A/E level check
# Same in both: fit 2021-23, score 2024, Tweedie D2 with p = 1.5 and an exposure-rate baseline, exposure = days / 365.
#
# This test re-runs the WENDY 2024 fold (validation part of the iteration script only, nothing written to the
# model folders or week1/output/submission), checks it reproduces the reported D2, then re-scores the same predictions
# against SAM's reported y_cost so all three iterations are compared on SAM's basis.
#
# Run from the project root (about 10-20 minutes; builds data/week_1/sam02 from data/week_1/raw data if it is not there yet):
#   Rscript week1/tests/test_wendy04_sam_basis_2024.R                          WENDY 4 VSAM02 CLEAN
#   WENDY_VARIANT=wendy04 Rscript week1/tests/test_wendy04_sam_basis_2024.R    WENDY 4 (needs data/week_1/sam02 from the run above)

VARIANT <- Sys.getenv("WENDY_VARIANT", "vsam02clean")
CFG <- list(
  vsam02clean = list(label = "WENDY 4 VSAM02 CLEAN", dir = file.path("week1", "models", "wendy_iteration_04_vsam02clean"),
                     script = "week1/R/4_models_iterwendy04_vsam02clean.R"),
  wendy04 = list(label = "WENDY 4", dir = file.path("week1", "models", "wendy_iteration_04"), script = "week1/R/4_models_iterwendy04.R")
)[[VARIANT]]
if (is.null(CFG)) stop("WENDY_VARIANT must be 'vsam02clean' or 'wendy04'")
SAM_DATA <- file.path("data", "week_1", "sam02")
SAM_P <- 1.5
TOL_ALL <- 5e-4
TOL_LINE <- 1e-3

# Workbook saved with the reported run, full (non-FAST) settings, reuse the SAM 2 data cache if it is complete
Sys.setenv(ASSUMPTIONS_XLSX = file.path(CFG$dir, "assumptions_wendy04.xlsx"), FAST = "0", SAM02_REUSE_DATA = "1")
stopifnot(file.exists(Sys.getenv("ASSUMPTIONS_XLSX")), file.exists(file.path(CFG$dir, "validation_by_line.csv")))
if (VARIANT == "wendy04" && !all(file.exists(file.path(SAM_DATA, paste0("train_", c("motor", "buildings", "contents"), ".parquet")))))
  stop("Run this test once without WENDY_VARIANT first: it builds ", SAM_DATA, " (SAM's reported y_cost).")

src <- readLines(CFG$script, warn = FALSE)
i_vy <- grep("^VALID_YEARS <- ", src)
i_sel <- grep("^# Selection per peril", src)
i_line <- grep("^# Line and portfolio scores", src)
i_final <- grep("^# 8\\. Final fit", src)
stopifnot(length(i_vy) == 1, length(i_sel) == 1, length(i_line) == 1, length(i_final) == 1)
src[i_vy] <- "VALID_YEARS <- 2024L"   # seeds depend on the year, so the 2024 fit equals the full run's
run <- function(lines) eval(parse(text = lines, keep.source = FALSE), envir = globalenv())
run(src[seq_len(i_sel - 1)])

# Method per peril as reported (chosen on mean D2 over 2023-24 in the full run)
chosen <- fread(file.path(CFG$dir, "chosen_method.csv"))
pick <- function(ln, pr) chosen[line == ln & peril == pr, method]

# 1. Re-score the 2024 predictions against SAM's reported y_cost (before the script's line section drops vpred)
sam_rows <- rbindlist(lapply(LINES, function(ln) {
  ids <- read_clean(paste0("train_", ln))[policy_year == 2024, row_id]   # same rows and order as the fold
  pred <- Reduce(`+`, lapply(PERILS[[ln]], function(pr) vpred[[paste(2024, ln, pr, pick(ln, pr))]]))
  sd <- as.data.table(read_parquet(file.path(SAM_DATA, paste0("train_", ln, ".parquet")),
                                   col_select = c("row_id", "policy_year", "y_cost", "exposure")))
  m <- match(ids, sd$row_id)
  stopifnot(length(pred) == length(ids), !anyNA(m), setequal(ids, sd[policy_year == 2024, row_id]),
            max(abs(sd$exposure[m] - vpred[[paste(2024, ln, "exposure")]])) < 1e-8)
  data.table(line = ln, pred = pred, actual = sd$y_cost[m], exposure = sd$exposure[m])
}))
sam_d2 <- function(y, pred, e) 1 - tweedie_dev(y, pred, SAM_P) / tweedie_dev(y, e * sum(y) / sum(e), SAM_P)
sam_score <- function(d) d[, .(d2 = sam_d2(actual, pred, exposure), gini = norm_gini(actual, pred),
                               pred_vs_reported = sum(pred) / sum(actual))]
sam_basis <- rbind(sam_rows[, sam_score(.SD), by = line], cbind(line = "ALL", sam_score(sam_rows)))

# 2. Reproduce the reported 2024 D2 on WENDY's own (developed) basis
run(src[i_line:(i_final - 1)])
dev_basis <- line_val[mix == "chosen" & valid_year == 2024, .(line, d2, gini, pred_vs_developed)]
reported <- fread(file.path(CFG$dir, "validation_by_line.csv"))[mix == "chosen" & valid_year == 2024, .(line, d2_reported = d2)]
chk <- merge(dev_basis, reported, by = "line")[, diff := d2 - d2_reported]
print(chk)
stopifnot(abs(chk[line == "ALL", diff]) < TOL_ALL, all(abs(chk[line != "ALL", diff]) < TOL_LINE))
cat(CFG$label, "2024 validation reproduced the reported local D2 (developed basis)\n")

# 3. Comparison: everything on SAM's reported basis, plus WENDY's developed-basis figure for reference
wide <- function(d, it, basis) dcast(d, . ~ line, value.var = "d2")[, . := NULL][, `:=`(iteration = it, basis = basis)]
sam <- rbindlist(lapply(c(2, 3), function(i) {
  s <- fread(file.path("week1", "models", sprintf("sam_iteration_%02d", i), "summary.csv"))
  data.table(iteration = paste("SAM", i), basis = "reported (SAM)", motor = s$d2_motor_2024,
             buildings = s$d2_buildings_2024, contents = s$d2_contents_2024, ALL = s$local_d2_2024)
}))
cmp <- rbind(wide(sam_basis, CFG$label, "reported (SAM)"), sam,
             wide(dev_basis, CFG$label, "developed (WENDY, not comparable)"), fill = TRUE)[
  , .(iteration, basis, motor, buildings, contents, ALL)]
ref <- cmp[iteration == CFG$label & basis == "reported (SAM)", ALL]
cmp[basis == "reported (SAM)", vs_wendy_same_basis := ALL - ref]
cat("\nLocal D2 2024 (fit 2021-23, score 2024; higher = better)\n")
print(cmp, digits = 4)
cat("\n", CFG$label, " on SAM's basis: gini and pred / reported by line\n", sep = "")
print(sam_basis, digits = 4)
out <- out_file("tests", paste0(VARIANT, "_vs_sam_local_d2_2024_same_basis.csv"))
fwrite(cmp, out)
cat("comparison saved to", out, "\n")
