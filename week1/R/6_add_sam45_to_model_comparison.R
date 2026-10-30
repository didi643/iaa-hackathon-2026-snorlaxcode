# 6_add_sam45_to_model_comparison.R -----------------------------------------
# Add SAM 4 and SAM 5 to the team model comparison workbook (read-only use of saved outputs, no refits).

suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
})

IN_FILE <- file.path("week1", "output", "model_comparison_20261023_to_add_sam_4.xlsx")
OUT_FILE <- file.path("week1", "output", "model_comparison_20261023_sam4_sam5.xlsx")
SAM <- c(SAM3 = "sam_iteration_03", SAM4 = "sam_iteration_04", SAM5 = "sam_iteration_05")

rd <- function(it, f) fread(file.path("week1", "models", SAM[[it]], f))
wb <- loadWorkbook(IN_FILE)

sheet_style <- function(sheet, row, col) {
  for (o in rev(wb$styleObjects)) if (o$sheet == sheet && any(o$rows == row & o$cols == col)) return(o$style)
  stop("No style at ", sheet, " ", row, ",", col)
}
fmt <- function(x, d = 3) formatC(x, format = "f", digits = d)
pct <- function(x) sprintf("%+.1f%%", 100 * x)

# Line_Leaderboard -----------------------------------------------------------
vm <- function(it) rd(it, "validation_metrics.csv")[model == "blend"]
vc <- function(it) rd(it, "validation_combined.csv")[model == "blend"]
burn <- function(it) {
  b <- rd(it, "test_prediction_summary.csv")[model == "blend"]
  paste(round(b[match(c("motor", "buildings", "contents"), line), predicted_burn_cost]), collapse = " / ")
}
line_mean <- function(it, ln) vm(it)[line == ln & valid_year %in% 2023:2024, mean(d2)]
rr <- function(it, yr) vc(it)[valid_year == yr, d2]
sam3_basis <- (rr("SAM3", 2023) + rr("SAM3", 2024)) / 2

lb_old <- read.xlsx(wb, "Line_Leaderboard")
lb_new <- rbindlist(lapply(c("SAM4", "SAM5"), function(it) {
  m <- (rr(it, 2023) + rr(it, 2024)) / 2
  data.table(
    model = sub("SAM", "SAM ", it),
    status = if (it == "SAM4") "Not submitted alone (buildings/contents used in week1/docs/workflow #10 splice with WENDY 4 motor: 0.12716)" else "Not submitted",
    public_D2 = NA_real_,
    local_mean_2023_24_reported_raw_ALL = m,
    rr_2023_ALL = rr(it, 2023), rr_2024_ALL = rr(it, 2024),
    rr_mean_motor = line_mean(it, "motor"), rr_mean_buildings = line_mean(it, "buildings"),
    rr_mean_contents = line_mean(it, "contents"),
    dev_2024_ALL = NA_real_, dev_2024_motor = NA_real_, dev_2024_buildings = NA_real_, dev_2024_contents = NA_real_,
    rank_local_protocol = NA_real_, rank_dev_2024 = NA_real_,
    `2025 burn motor/bld/cont` = burn(it),
    method = paste0(
      if (it == "SAM4") "SAM 3 + chain-ladder IBNR per line x peril (motor BI keeps SAM 3 ECDF), applied per row as exposure x mean reported share over the row's days; models, features, tuning unchanged"
      else "SAM 4 + premium_index (written_premium / exposure-weighted mean of line x policy year) in XGB/LGB per-peril and line Tweedie only; GLMs, IBNR, trend, caps as SAM 4",
      "; greedy blend (", paste(rd(it, "blend_weights.csv")[weight > 0, paste0(line, " ", model, " ", weight)], collapse = ", "), ")",
      ". Scores from SAM model card (own scorer, reported actuals): SAM 3 on this basis = ", fmt(sam3_basis, 5),
      ", so ", sub("SAM", "SAM ", it), " is ", sprintf("%+.5f", m - sam3_basis), " vs SAM 3. dev_2024 not saved."),
    features = if (it == "SAM4") "As SAM 3" else "As SAM 3 + premium_index in tree models (raw written_premium / discount_applied still excluded)"
  )
}))
setnames(lb_new, names(lb_old))
r0 <- nrow(lb_old) + 2L
writeData(wb, "Line_Leaderboard", lb_new, startRow = r0, colNames = FALSE)
rows <- r0:(r0 + nrow(lb_new) - 1L)
addStyle(wb, "Line_Leaderboard", sheet_style("Line_Leaderboard", 2, 1), rows, 1:ncol(lb_old), gridExpand = TRUE)
addStyle(wb, "Line_Leaderboard", sheet_style("Line_Leaderboard", 2, 3), rows, 3, gridExpand = TRUE)
addStyle(wb, "Line_Leaderboard", sheet_style("Line_Leaderboard", 2, 4), rows, 4:13, gridExpand = TRUE)

# Peril_Freq_Sev_Spec ---------------------------------------------------------
tr <- rd("SAM4", "trend_by_peril.csv")
stopifnot(isTRUE(all.equal(tr, rd("SAM5", "trend_by_peril.csv"))),
          isTRUE(all.equal(rd("SAM4", "claim_caps.csv"), rd("SAM5", "claim_caps.csv"))))
caps <- rd("SAM4", "claim_caps.csv")
ibnr <- rd("SAM4", "ibnr_vs_sam03.csv")[policy_year == 2024]
spec_old <- read.xlsx(wb, "Peril_Freq_Sev_Spec")
key <- spec_old[, c("line", "peril")]
t4 <- tr[key, on = c("line", "peril")]
c4 <- caps[key, on = c("line", "peril")]
i4 <- ibnr[key, on = c("line", "peril")]
stopifnot(nrow(t4) == nrow(key), !anyNA(t4$loading), !anyNA(c4$cap), !anyNA(i4$sam04_factor), !anyNA(i4$sam03_factor))
sam4_spec <- paste0(
  "As SAM 3 with chain-ladder row-level IBNR", ifelse(key$line == "motor" & key$peril == "bodily_injury", " (BI keeps SAM 3 ECDF)", ""),
  "; 2024 IBNR factor ", fmt(i4$sam04_factor), " (SAM 3 ", fmt(i4$sam03_factor), ")",
  "; claim cap ", format(round(c4$cap), big.mark = ",", trim = TRUE),
  "; trend freq ", pct(t4$freq_trend_used), " / sev ", pct(t4$sev_trend_used),
  "; loading ", fmt(t4$loading), ifelse(t4$long_tail, "; long-tail (2024 dummy)", ""))
sam5_spec <- "As SAM 4 (GLM freq x sev, IBNR, trend, caps identical); premium_index added to XGB/LGB Poisson freq bags and line Tweedie"
at <- match("SAM3_freq_sev", names(spec_old))
spec_new <- cbind(spec_old[, 1:at], SAM4_freq_sev = sam4_spec, SAM5_freq_sev = sam5_spec,
                  spec_old[, (at + 1):ncol(spec_old)])
num_cols <- match(c("C5_freq_trend", "C5_sev_trend"), names(spec_new))
body_style <- sheet_style("Peril_Freq_Sev_Spec", 2, 1)
num_style <- sheet_style("Peril_Freq_Sev_Spec", 2, num_cols[1] - 2L)
head_style <- sheet_style("Peril_Freq_Sev_Spec", 1, 1)
old_w <- wb$colWidths[[match("Peril_Freq_Sev_Spec", names(wb))]]
writeData(wb, "Peril_Freq_Sev_Spec", spec_new)
addStyle(wb, "Peril_Freq_Sev_Spec", head_style, 1, seq_along(spec_new), gridExpand = TRUE)
addStyle(wb, "Peril_Freq_Sev_Spec", body_style, 2:(nrow(spec_new) + 1L), seq_along(spec_new), gridExpand = TRUE)
addStyle(wb, "Peril_Freq_Sev_Spec", num_style, 2:(nrow(spec_new) + 1L), num_cols, gridExpand = TRUE)
w <- as.numeric(old_w)
setColWidths(wb, "Peril_Freq_Sev_Spec", seq_along(spec_new), c(w[1:at], 59.29, 40.665, w[(at + 1):length(w)]))

# Peril_Features --------------------------------------------------------------
fu4 <- rd("SAM4", "features_used.csv")
fu5 <- rd("SAM5", "features_used.csv")
tree_n <- function(fu, ln) length(strsplit(fu[line == ln & model == "tree models", features], ", ")[[1]])
stopifnot(all(sapply(c("motor", "buildings", "contents"), function(ln)
  grepl("premium_index", fu5[line == ln & model == "tree models", features]))))
feat_old <- read.xlsx(wb, "Peril_Features")
glm_f <- fu4[data.table(line = feat_old$line, model = paste0("glm_freq.", feat_old$peril)), on = c("line", "model"), features]
glm_s <- fu4[data.table(line = feat_old$line, model = "glm_sev"), on = c("line", "model"), features]
stopifnot(!anyNA(glm_f), !anyNA(glm_s))
tree_f <- sapply(feat_old$line, function(ln)
  sprintf("Line-level set of %d features (SAM 5: %d, + premium_index); see week1/models/sam_iteration_04/features_used.csv",
          tree_n(fu4, ln), tree_n(fu5, ln)))
feat_new <- cbind(feat_old, SAM4_SAM5_glm_freq_features = glm_f, SAM4_SAM5_glm_sev_features = glm_s,
                  SAM4_SAM5_tree_features = unname(tree_f))
nc <- ncol(feat_old)
writeData(wb, "Peril_Features", feat_new[, (nc + 1):ncol(feat_new)], startCol = nc + 1L)
addStyle(wb, "Peril_Features", sheet_style("Peril_Features", 1, 1), 1, (nc + 1):ncol(feat_new), gridExpand = TRUE)
addStyle(wb, "Peril_Features", sheet_style("Peril_Features", 2, 1), 2:(nrow(feat_new) + 1L), (nc + 1):ncol(feat_new), gridExpand = TRUE)
setColWidths(wb, "Peril_Features", (nc + 1):ncol(feat_new), c(59.29, 40.665, 40.665))

# README ----------------------------------------------------------------------
rm_old <- read.xlsx(wb, "README")
upd <- function(item, text) rm_old$value[rm_old$item == item] <<- text
upd("Purpose", paste0(rm_old$value[rm_old$item == "Purpose"], "; SAM 4 and SAM 5 added 23 Oct 2026"))
upd("Sources", paste0(rm_old$value[rm_old$item == "Sources"],
                      "; SAM 4/5: week1/models/sam_iteration_04|05/validation_*.csv, trend_by_peril.csv, claim_caps.csv, ibnr_vs_sam03.csv, features_used.csv"))
upd("Not available", paste0(rm_old$value[rm_old$item == "Not available"],
                            " SAM 4/5: per-peril and dev_2024 scores (only line-level blend metrics saved); their reported_raw columns come from the SAM model card scorer, which puts SAM 3 at ",
                            fmt(sam3_basis, 5), " vs ", fmt(lb_old$local_mean_2023_24_reported_raw_ALL[lb_old$model == "SAM 3"], 5),
                            " here - compare SAM 4/5 to SAM 3 via the delta in their method column."))
writeData(wb, "README", rm_old)

saveWorkbook(wb, OUT_FILE, overwrite = TRUE)
message("Wrote ", OUT_FILE)
