# 6_export_model_spreadsheet_sam03.R -----------------------------------------
# Export the completed SAM 3 and SAM 4 results without refitting.

suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
})

MODEL_DIR <- file.path("week1", "models", "sam_iteration_03")
OUT_FILE <- file.path(MODEL_DIR, "sam_iteration_03_model_summary.xlsx")
SUBMISSION_FILE <- file.path("week1", "output", "submission", "submission_20261022_1159.csv")
SAM04_DIR <- file.path("week1", "models", "sam_iteration_04")
SAM04_SUBMISSION_FILE <- file.path("week1", "output", "submission", "submission_20261022_1734.csv")

read_model_csv <- function(name, dir = MODEL_DIR) {
  f <- file.path(dir, name)
  if (!file.exists(f)) stop("Missing model output: ", f)
  fread(f)
}

wb <- createWorkbook()
header_style <- createStyle(fontColour = "#FFFFFF", fgFill = "#1F4E78", textDecoration = "bold",
                            halign = "center", valign = "center")

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
  value = c("sam_iteration_03", "submission_20261022_1159.csv", "0.12818", "0.1145", "0.1043", "0.0986",
            "0.12796", "0.00022 (0.17%)", "passed", "2021-2024",
            "Rolling 2022, 2023 and 2024", "Greedy blend on calibrated D2", "Written premium and sensitive proxy fields excluded")
)
add_table("Summary", summary, c(32, 90), freeze = FALSE)

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
    "Frequency-only report-share-adjusted exposure from the 2021-22 report-lag distribution; observed capped severity.",
    "LightGBM and XGBoost frequency bags plus line-level Tweedie bags.",
    "Greedy 10-step blend selected using calibrated D2 across rolling time folds.",
    "No renewal-decision or customer-service leakage; predictions are non-negative.",
    "Saved artifacts reload and reproduce the submitted predictions exactly."
  )
)
add_table("Methodology", methodology, c(22, 125), freeze = FALSE)

add_table("Validation", read_model_csv("validation_metrics.csv"))
add_table("Validation combined", read_model_csv("validation_combined.csv"))
add_table("Blend weights", read_model_csv("blend_weights.csv"))
add_table("Line model totals", read_model_csv("test_prediction_summary.csv"))
add_table("IBNR by peril", read_model_csv("ibnr_by_peril.csv"))
add_table("Trend by peril", read_model_csv("trend_by_peril.csv"))
add_table("Claim caps", read_model_csv("claim_caps.csv"))
add_table("XGB tuning", read_model_csv("xgb_tuning.csv"))
add_table("Data checks", read_model_csv("data_checks.csv"))

read_submission <- function(f) {
  if (!file.exists(f)) stop("Missing submission file: ", f)
  s <- fread(f)
  s[, line := fcase(substr(row_id, 1L, 1L) == "M", "motor",
                    substr(row_id, 1L, 1L) == "B", "buildings",
                    substr(row_id, 1L, 1L) == "C", "contents",
                    default = NA_character_)]
  setcolorder(s, c("row_id", "line", "prediction"))
  stopifnot(nrow(s) == 626639L, !anyNA(s$line), all(s$prediction >= 0))
  s
}
add_table("Submission", read_submission(SUBMISSION_FILE), c(18, 14, 18))

# SAM 4 ---------------------------------------------------------------------
sam04_summary <- data.table(
  item = c("Model", "Submission file", "Public D2", "Local D2 2022", "Local D2 2023", "Local D2 2024",
           "Change vs SAM 3", "Replication check", "Training years", "Validation folds", "Blend selection",
           "Feature policy"),
  value = c("sam_iteration_04", "submission_20261022_1734.csv", "not submitted on its own",
            "0.1145", "0.1047", "0.0984",
            "IBNR only: chain-ladder report shares per line x peril (SAM 3 ECDF for motor bodily_injury), applied per row as exposure x mean reported share over the row's days. Models, features, tuning and blend unchanged.",
            "passed", "2021-2024", "Rolling 2022, 2023 and 2024", "Greedy blend on calibrated D2",
            "Written premium and sensitive proxy fields excluded")
)
add_table("SAM4 Summary", sam04_summary, c(32, 90), freeze = FALSE)
add_table("SAM4 Validation", read_model_csv("validation_metrics.csv", SAM04_DIR))
add_table("SAM4 Validation combined", read_model_csv("validation_combined.csv", SAM04_DIR))
add_table("SAM4 Blend weights", read_model_csv("blend_weights.csv", SAM04_DIR))
add_table("SAM4 Line model totals", read_model_csv("test_prediction_summary.csv", SAM04_DIR))
add_table("SAM4 IBNR by peril", read_model_csv("ibnr_by_peril.csv", SAM04_DIR))
add_table("SAM4 IBNR vs SAM3", read_model_csv("ibnr_vs_sam03.csv", SAM04_DIR))
add_table("SAM4 Trend by peril", read_model_csv("trend_by_peril.csv", SAM04_DIR))
add_table("SAM4 Claim caps", read_model_csv("claim_caps.csv", SAM04_DIR))
add_table("SAM4 XGB tuning", read_model_csv("xgb_tuning.csv", SAM04_DIR))
add_table("SAM4 Data checks", read_model_csv("data_checks.csv", SAM04_DIR))
add_table("SAM4 Submission", read_submission(SAM04_SUBMISSION_FILE), c(18, 14, 18))

comparison <- data.table(
  submission = c("Iteration 1 GLM", "Iteration 2 XGBoost", "sam_iteration_01", "sam_iteration_02", "sam_iteration_03",
                 "sam_iteration_04"),
  public_d2 = c(0.11904, 0.12149, 0.11876, 0.12796, 0.12818, NA),
  local_d2_2023 = c(0.1055, 0.0997, 0.1071, 0.1045, 0.1043, 0.1047),
  local_d2_2024 = c(0.0944, 0.0973, 0.0959, 0.0982, 0.0986, 0.0984),
  motor_burn_cost_2025 = c(518.12, 498.80, 518.12, 604.13, 603.26, 607.41),
  buildings_burn_cost_2025 = c(425.08, 434.25, 411.79, 487.37, 487.44, 489.24),
  contents_burn_cost_2025 = c(113.20, 119.13, 111.80, 125.14, 125.17, 125.83)
)
add_table("Submission comparison", comparison, c(24, 14, 16, 16, 22, 25, 24))

saveWorkbook(wb, OUT_FILE, overwrite = TRUE)
message("Wrote ", OUT_FILE)