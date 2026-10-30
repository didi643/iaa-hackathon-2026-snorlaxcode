# 7_export_wendy07_workbook.R -----------------------------------------------------------------------------------
# Writes a WENDY 4-style assumption workbook for a WENDY 7 model, with every change of that model baked into the
# input sheets (Features_*, Model_Spec, Settings, new Method_Mix) and highlighted (orange fill), plus documentation
# sheets: Changes_vs_WENDY4, Final_Features, Method_Mix, IBNR_Chain_Ladder, Validation, Peril_Scores, SAM3_Blend,
# Forecast_2025. week1/R/4_models_iterwendy07.R run with ASSUMPTIONS_XLSX=<this workbook> and no edit environment
# variables reproduces the model (checked by week1/R/7_verify_wendy07_workbook.R).
#
# Run:  MODEL=sub10 Rscript week1/R/7_export_wendy07_workbook.R      (MODEL = sub10 | final2)
# Out:  week1/docs/assumptions_wendy07_<model>.xlsx

source("week1/R/0_setup.R")
suppressPackageStartupMessages(library(openxlsx))
MODEL <- Sys.getenv("MODEL", "sub10")
BASE_XLSX <- "week1/docs/assumptions_wendy07.xlsx"
W4_MIX <- file.path(PATHS$output, "4_check_reported", "4_models_iterwendy04", "chosen_method.csv")

# Model definitions: the exact edit strings of the runs (week1/docs/wendy07_experiment_log.md)
c4 <- list(run = "c4", fe = "all:voluntary_excess=B", se = "motor/bodily_injury:freq_trend=none,sev_trend=none",
           mix = fread(W4_MIX)[, .(line, peril, method)])
c5 <- c4
c5$run <- "c5"
c5$fe <- c(c4$fe, "buildings/flood:days_quote_to_inception=-", "buildings/flood:start_month=-",
           "motor/third_party_prop:freezing_days=-", "motor/third_party_prop:rainfall_mm=-")
c5$se <- c(c4$se, "buildings/escape_of_water:sev_model=gamma_glm", "buildings/fire:freq_min_child_weight=15",
           "contents/theft:sev_model=gamma_glm", "motor/theft:sev_model=gamma_glm")
c5$mix <- copy(c4$mix)[line == "motor" & peril == "own_damage", method := "freq_sev"]
models <- list(
  sub10 = c(c4, list(label = "submission #10 (public 0.12924)", blend_tag = "wendy07_sub10",
                     file = "submission_20261022_2135_wendy07_final.csv", md5 = "8535c6833aafd1299ad8d5cd9887448d")),
  final2 = c(c5, list(label = "final2 (on hold, not submitted)", blend_tag = "wendy07_final2",
                      file = "submission_20261022_2328_wendy07_final2.csv", md5 = "99135ba796a021c92c186e3e7bf71d3f")))
M <- models[[MODEL]]
if (is.null(M)) stop("MODEL must be one of ", paste(names(models), collapse = ", "))
RUN_DIR <- file.path("week1", "models", "wendy_iteration_07", M$run)
CHK <- function(tag) file.path(PATHS$output, "4_check_reported", tag)
OUT <- sprintf("week1/docs/assumptions_wendy07_%s.xlsx", MODEL)

# Why each change was made and what it gained (mean 2023-24 reported_raw ALL D2, from the log)
why <- c(
  "all:voluntary_excess=B" = "Excess removes small claims and slices every claim: frequency and severity of every peril (B6: ALL +0.0010, 100% of bootstrap draws; BI Tweedie +0.0055, fire +0.0053, flood +0.002).",
  "motor/bodily_injury:freq_trend=none,sev_trend=none" = "BI trend fitted on immature cost read IBNER as a decline (-2.7%/yr freq, -2%/yr sev) -> 2025 BI burn 177 below every year; held at recent level (200). Local -0.0006 (within noise), chosen on actuarial grounds.",
  "buildings/flood:days_quote_to_inception=-" = "Peril lab: admin fields have no flood mechanism; drop gained +0.00005 (2023 0.00000 / 2024 +0.00010 / 2022 -0.00008).",
  "buildings/flood:start_month=-" = "Dropped together with days_quote_to_inception (lab variant drop_admin).",
  "motor/third_party_prop:freezing_days=-" = "Peril lab: realised weather adds noise to third-party property; drop gained +0.00036 (2023 +0.00064 / 2024 +0.00008 / 2022 +0.00012).",
  "motor/third_party_prop:rainfall_mm=-" = "Dropped together with freezing_days (lab variant drop_weather).",
  "buildings/escape_of_water:sev_model=gamma_glm" = "Peril lab: GLM severity steadier than GBM; +0.00008 (2023 +0.00005 / 2024 +0.00012 / 2022 0.00000).",
  "buildings/fire:freq_min_child_weight=15" = "Peril lab: finer leaves for sparse fire frequency; +0.00007 (2023 -0.00004 / 2024 +0.00018 / 2022 -0.00003).",
  "contents/theft:sev_model=gamma_glm" = "Peril lab: GLM severity; +0.00007 (2023 +0.00007 / 2024 +0.00008 / 2022 +0.00014).",
  "motor/theft:sev_model=gamma_glm" = "Peril lab: GLM severity; +0.00008 (2023 +0.00015 / 2024 +0.00001 / 2022 +0.00001).")

wb <- loadWorkbook(BASE_XLSX)
hl <- createStyle(fgFill = "#F4B183", fontColour = "#1F3864", textDecoration = "bold")
changes <- list()
log_change <- function(area, ln, pr, item, old, new, edit) changes[[length(changes) + 1]] <<- data.table(
  area = area, line = ln, peril = pr, item = item, wendy04_value = as.character(old), this_model = as.character(new),
  reason_and_evidence = unname(why[edit]))
targets <- function(scope) {
  s <- strsplit(scope, "/", fixed = TRUE)[[1]]
  t <- rbindlist(lapply(LINES, function(ln) data.table(line = ln, peril = PERILS[[ln]])))
  if (s[1] != "all") t <- t[line == s[1]]
  if (length(s) > 1) t <- t[peril == s[2]]
  t
}

# 1. Features_<line>: peril codes
for (ed in M$fe) {
  m <- regmatches(ed, regexec("^([a-z_/]+):([a-z0-9_]+)=([BFS-])$", ed))[[1]]
  for (i in seq_len(nrow(tg <- targets(m[2])))) {
    ln <- tg$line[i]; pr <- tg$peril[i]; sh <- paste0("Features_", tools::toTitleCase(ln))
    x <- read.xlsx(wb, sh)
    r <- which(x$column == m[3]); cc <- which(names(x) == pr)
    if (length(r) != 1 || length(cc) != 1) stop("Feature ", m[3], " / peril ", pr, " not found in ", sh)
    if (toupper(x$use[r]) != "Y") stop(m[3], " has use != Y in ", sh, " - edit would not be active")
    old <- x[r, cc]; old <- if (is.na(old)) "-" else old
    if (identical(toupper(old), m[4])) next
    writeData(wb, sh, m[4], startCol = cc, startRow = r + 1)
    addStyle(wb, sh, hl, rows = r + 1, cols = cc, stack = TRUE)
    log_change("Features", ln, pr, m[3], old, m[4], ed)
  }
}
# 2. Model_Spec cells
sp <- read.xlsx(wb, "Model_Spec")
for (ed in M$se) {
  key <- strsplit(sub(":.*$", "", ed), "/", fixed = TRUE)[[1]]
  r <- which(sp$line == key[1] & sp$peril == key[2])
  for (kv in strsplit(sub("^[^:]*:", "", ed), ",", fixed = TRUE)[[1]]) {
    k <- sub("=.*$", "", kv); v <- sub("^[^=]*=", "", kv); cc <- which(names(sp) == k)
    old <- sp[r, cc]
    writeData(wb, "Model_Spec", if (is.numeric(sp[[k]])) as.numeric(v) else v, startCol = cc, startRow = r + 1)
    addStyle(wb, "Model_Spec", hl, rows = r + 1, cols = cc, stack = TRUE)
    log_change("Model_Spec", key[1], key[2], k, old, v, ed)
  }
}
# 3. Settings
st <- read.xlsx(wb, "Settings")
set_setting <- function(k, v, note, reason) {
  r <- which(st$key == k)
  old <- if (length(r)) st$value[r] else "(not set)"
  if (!length(r)) { r <- nrow(st) + 1; st[r, ] <<- NA; st$key[r] <<- k }
  st$value[r] <<- v; st$note[r] <<- note
  writeData(wb, "Settings", data.frame(k, v, note), startRow = r + 1, colNames = FALSE)
  addStyle(wb, "Settings", hl, rows = r + 1, cols = 1:3, gridExpand = TRUE, stack = TRUE)
  changes[[length(changes) + 1]] <<- data.table(area = "Settings", line = "all", peril = "all", item = k,
                                                wendy04_value = old, this_model = v, reason_and_evidence = reason)
}
set_setting("ibnr_method", "chain_ladder", "WENDY 7: reported-count chain ladder per peril (loss quarter x development quarter, 2021-24 losses).",
            "One-year-ahead backtest (value at 31 Dec 2023, compare with 31 Dec 2024): latest loss year projected/actual 0.999 vs 0.971 for the WENDY 4 mid-date ECDF.")
set_setting("ibnr_override", "buildings/subsidence=report_share_days", "Per-peril IBNR method: subsidence uses the lag ECDF averaged over the row's days (sparse triangle).",
            "Backtest subsidence: chain ladder 1.12 (sparse, volatile), ECDF over days 1.06.")
set_setting("bags", "5", "WENDY 7: each xgboost component = mean of 5 boosters (own policy holdout, seed SEED + b); bag 1 = WENDY 4 fit.",
            "Averages away fit-to-fit noise (single-fit per-peril noise ~0.0005); buildings +0.0007, contents +0.0004.")
set_setting("method_mix", "sheet", "WENDY 7: freq_sev / tweedie per peril read from sheet Method_Mix (environment METHOD_MIX overrides).",
            "Fixed mix (no per-run re-selection) so a run changes only what it is meant to change.")
# 4. Method_Mix sheet
mixd <- merge(M$mix, fread(W4_MIX)[, .(line, peril, wendy04_method = method)], by = c("line", "peril"))
mixd[, reason := fifelse(method == wendy04_method, "WENDY 4 pick (mean developed D2 over 2023-24)",
                         "Peril lab: freq_sev beats Tweedie by +0.0005 ALL (2023 +0.00059 / 2024 +0.00043 / 2022 +0.00001)")]
for (i in which(mixd$method != mixd$wendy04_method)) changes[[length(changes) + 1]] <- data.table(area = "Method_Mix",
  line = mixd$line[i], peril = mixd$peril[i], item = "method", wendy04_value = mixd$wendy04_method[i], this_model = mixd$method[i],
  reason_and_evidence = mixd$reason[i])
addWorksheet(wb, "Method_Mix")
writeData(wb, "Method_Mix", mixd[, .(line, peril, method, wendy04_method, reason)])

# 5. README
rd_rows <- data.frame(X1 = c(sprintf("WENDY 7 - %s: actuarial assumptions and feature map", M$label),
  "This version", "How to run", "Changes vs WENDY 4", "Orange cells", "Line blend", "Submission file"),
  X2 = c(NA, sprintf("Model run '%s' of week1/R/4_models_iterwendy07.R (week1/models/wendy_iteration_07/%s/). All its changes are baked into the input sheets; sheet Changes_vs_WENDY4 lists each one with its reason and measured effect.", M$run, M$run),
  sprintf("ASSUMPTIONS_XLSX=%s FINAL_FIT=1 FINAL_METHODS=all RUN_TAG=<tag> Rscript week1/R/4_models_iterwendy07.R (no FEATURE_EDITS / SPEC_EDITS / IBNR_* / BAGS / METHOD_MIX needed). Then week1/R/4_final_wendy07.R blends with SAM 3.", OUT),
  "See sheet Changes_vs_WENDY4. Full reasoning per step: week1/docs/wendy07_experiment_log.md; every try: week1/docs/wendy07_experiment_register.xlsx.",
  "Cells changed from the WENDY 4 workbook (feature codes, Model_Spec, Settings).",
  "The submitted prediction is a per-line blend with SAM 3 (sheet SAM3_Blend); this workbook drives the WENDY 7 part.",
  sprintf("week1/output/submission/%s (MD5 %s)", M$file, M$md5)))
writeData(wb, "README", rd_rows, startRow = 1, colNames = FALSE)
addStyle(wb, "README", hl, rows = 1:7, cols = 1:2, gridExpand = TRUE, stack = TRUE)
old_readme <- read.xlsx(BASE_XLSX, "README", colNames = FALSE)
writeData(wb, "README", data.frame(X1 = c("--- WENDY 4 notes (still valid unless changed above) ---", old_readme$X1[-1]),
                                   X2 = c(NA, old_readme$X2[-1])), startRow = 9, colNames = FALSE)

# 6. Documentation sheets
add_sheet <- function(name, dt) { addWorksheet(wb, name); writeData(wb, name, dt, headerStyle = createStyle(textDecoration = "bold", fgFill = "#D9E1F2"))
  setColWidths(wb, name, cols = seq_len(ncol(dt)), widths = "auto"); freezePane(wb, name, firstRow = TRUE) }
add_sheet("Changes_vs_WENDY4", rbindlist(changes, fill = TRUE))
fu <- fread(file.path(RUN_DIR, "features_used.csv"))
fu[, part := fcase(code == "B", "frequency + severity", code == "F", "frequency only", code == "S", "severity only")]
fu[M$mix, on = c("line", "peril"), method := i.method]
fu[, used_by_method := fifelse(method == "tweedie", "Tweedie GBM: uses every code (F, S, B) in one model", "freq x sev: F/B in frequency, S/B in severity")]
add_sheet("Final_Features", fu[order(line, peril, -code, column), .(line, peril, method, feature = column, code, part, mono_freq, mono_sev, used_by_method)])
fcount <- fu[, .(freq_features = sum(code %in% c("F", "B")), sev_features = sum(code %in% c("S", "B")), all_features = .N), by = .(line, peril)]
add_sheet("Feature_Matrix", dcast(fu[, .(line, feature = column, peril = paste(line, peril), code)], line + feature ~ peril, value.var = "code", fill = "-"))
ib <- fread(file.path(RUN_DIR, "ibnr_shares_by_year.csv"))
cl <- if (file.exists(f <- file.path(RUN_DIR, "chain_ladder_counts.csv"))) fread(f) else data.table()
add_sheet("IBNR_Chain_Ladder", ib[, .(line, peril, policy_year, exposure, reported_share_wendy4 = share_a0, reported_share_this_model = share,
                                      ibnr_factor, ratio_to_wendy4 = ratio_to_a0)])
if (nrow(cl)) add_sheet("CL_Triangle_Factors", cl)
ls <- fread(file.path(CHK(paste0("wendy07_", M$run)), "line_scores.csv"))
lb <- fread(file.path(CHK(M$blend_tag), "line_scores.csv"))
val <- rbind(ls[, .(model = paste("WENDY 7", M$run, "alone"), basis, valid_year, line, d2, gini, pred_vs_actual)],
             lb[, .(model = "blend with SAM 3 (submitted form)", basis, valid_year, line, d2, gini, pred_vs_actual)],
             fread(file.path(CHK("sam03"), "line_scores.csv"))[, .(model = "SAM 3 (rerun)", basis, valid_year, line, d2, gini, pred_vs_actual)])
add_sheet("Validation", dcast(val, model + basis + line ~ valid_year, value.var = "d2")[, mean_2023_24 := (`2023` + `2024`) / 2][])
add_sheet("Peril_Scores", dcast(fread(file.path(CHK(paste0("wendy07_", M$run)), "peril_scores.csv")),
                                line + peril + method ~ basis + valid_year, value.var = "d2"))
bw <- fread(file.path(CHK(M$blend_tag), "line_weights.csv"))
add_sheet("SAM3_Blend", bw[, .(line, weight_wendy07 = a_wendy07, weight_sam03 = 1 - a_wendy07, d2_wendy07, d2_sam03, d2_blend,
                               crossfold_gain_vs_wendy07, rule = "weight on grid 0.1 maximising mean 2023-24 reported_raw D2; cross-fold = chosen on one fold, scored on the other")])
tl <- fread(file.path(RUN_DIR, "test_by_line.csv")); tp <- fread(file.path(RUN_DIR, "test_by_peril.csv"))
add_sheet("Forecast_2025", rbind(tp[, .(level = "peril (WENDY 7 part)", line, peril, method, predicted_total, predicted_burn)],
                                 tl[, .(level = "line (WENDY 7 part)", line, peril = "all", method = "-", predicted_total, predicted_burn)], fill = TRUE))
add_sheet("Feature_Counts", fcount)
saveWorkbook(wb, OUT, overwrite = TRUE)
log_msg("Workbook: ", OUT, " (", length(changes), " changes vs WENDY 4)")
