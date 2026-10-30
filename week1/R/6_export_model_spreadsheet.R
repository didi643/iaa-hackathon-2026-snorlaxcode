# 6_export_model_spreadsheet.R -----------------------------------------------
# Export saved sam_iteration_02 results to one workbook without refitting.

suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
})

MODEL_DIR <- file.path("week1", "models", "sam_iteration_02")
OUT_FILE <- file.path(MODEL_DIR, "sam_iteration_02_model_summary.xlsx")

read_model_csv <- function(name) {
  f <- file.path(MODEL_DIR, name)
  if (!file.exists(f)) stop("Missing model output: ", f)
  fread(f)
}

wb <- createWorkbook()
header_style <- createStyle(fontColour = "#FFFFFF", fgFill = "#1F4E78", textDecoration = "bold",
                            halign = "center", valign = "center")
section_style <- createStyle(fontColour = "#FFFFFF", fgFill = "#548235", textDecoration = "bold")
number_style <- createStyle(numFmt = "#,##0.0000")
integer_style <- createStyle(numFmt = "#,##0")
percent_style <- createStyle(numFmt = "0.00%")

add_table <- function(sheet, x, widths = NULL, freeze = TRUE) {
  addWorksheet(wb, sheet, gridLines = FALSE)
  writeDataTable(wb, sheet, x, tableStyle = "TableStyleMedium2", withFilter = TRUE)
  addStyle(wb, sheet, header_style, rows = 1, cols = seq_len(ncol(x)), gridExpand = TRUE)
  if (!is.null(widths)) setColWidths(wb, sheet, seq_along(widths), widths)
  else setColWidths(wb, sheet, seq_len(ncol(x)), "auto")
  if (freeze) freezePane(wb, sheet, firstRow = TRUE)
}

summary <- data.table(
  item = c("Model", "Submission file", "Public D2", "Local D2 2022", "Local D2 2023", "Local D2 2024",
           "Previous best public D2", "Improvement vs previous best", "Replication check", "Training years",
           "Validation folds", "Blend selection", "Feature policy"),
  value = c("sam_iteration_02", "submission_20261021_1528.csv", "0.12796", "0.1143", "0.1045", "0.0982",
            "0.12149", "0.00647 (5.33%)", "passed", "2021-2024",
            "Rolling 2022, 2023 and 2024", "Greedy blend on calibrated D2", "Written premium and sensitive proxy fields excluded")
)
add_table("Summary", summary, c(30, 85), freeze = FALSE)

methodology <- data.table(
  area = c("Objective", "Lines", "Target", "Features", "Claim history", "Peril modelling", "Trend",
           "Large losses", "IBNR", "Tree models", "Blend", "Guardrails", "Reproducibility"),
  description = c(
    "Predict expected ultimate claim cost for each 2025 policy row.",
    "Motor, buildings and contents.",
    "Non-repudiated incurred cost minus recoveries, matched to the policy period.",
    "Raw policy, customer, address and weather fields plus engineered variables.",
    "Prior policy, cross-line customer and address claims using information available before the policy year.",
    "Frequency and severity are modelled separately for each peril.",
    "Policy-year trend in frequency and severity, capped at +/-10% annually.",
    "Claim-level caps by line and peril with a loading to return expected total cost.",
    "Per-line and peril report-lag factors, with long-tail treatment for immature perils.",
    "LightGBM and XGBoost frequency bags plus line-level Tweedie bags.",
    "Greedy 10-step blend selected using calibrated D2 across rolling time folds.",
    "No renewal-decision or customer-service leakage; predictions are non-negative.",
    "Saved artifacts reload and reproduce the submitted predictions exactly."
  )
)
add_table("Methodology", methodology, c(22, 120), freeze = FALSE)

files <- c(
  validation_metrics = "validation_metrics.csv",
  validation_combined = "validation_combined.csv",
  blend_weights = "blend_weights.csv",
  test_predictions = "test_prediction_summary.csv",
  trend_by_peril = "trend_by_peril.csv",
  ibnr_by_peril = "ibnr_by_peril.csv",
  claim_caps = "claim_caps.csv",
  tree_importance = "tree_importance.csv",
  tree_rounds = "tree_rounds.csv",
  xgb_tuning = "xgb_tuning.csv",
  data_checks = "data_checks.csv",
  segment_ae = "segment_ae.csv",
  overfit_check = "overfit_check.csv",
  phase0_replay = "phase0_replay.csv",
  feature_usage = "features_used.csv"
)
for (i in seq_along(files)) {
  x <- read_model_csv(unname(files[i]))
  add_table(names(files)[i], x)
}

# Add a compact comparison sheet using the public scores recorded in the workflow log.
comparison <- data.table(
  submission = c("Iteration 1 GLM", "Iteration 2 XGBoost", "sam_iteration_01", "sam_iteration_02"),
  public_d2 = c(0.11904, 0.12149, 0.11876, 0.12796),
  local_d2_2023 = c(0.1055, 0.0997, 0.1071, 0.1045),
  local_d2_2024 = c(0.0944, 0.0973, 0.0959, 0.0982),
  motor_burn_cost_2025 = c(518.12, 498.80, 518.12, 604.13),
  buildings_burn_cost_2025 = c(425.08, 434.25, 411.79, 487.37),
  contents_burn_cost_2025 = c(113.20, 119.13, 111.80, 125.14)
)
add_table("Submission comparison", comparison, c(24, 14, 16, 16, 22, 25, 24))

saveWorkbook(wb, OUT_FILE, overwrite = TRUE)
message("Wrote ", OUT_FILE)
