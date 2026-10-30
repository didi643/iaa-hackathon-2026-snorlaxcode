# 7_export_wendy07_register.R -----------------------------------------------------------------------------------
# Builds week1/docs/wendy07_experiment_register.xlsx: every try of WENDY 7 (rounds 1 and 2) with its exact settings, the
# one change against its parent, scores by line and fold on three actual bases, the change vs parent, bootstrap
# verdicts and the decision. Scores and feature maps are read from the run outputs (not typed), the purpose /
# reasoning / decision text comes from week1/docs/wendy07_experiment_log.md.
#
# Run:  Rscript week1/R/7_export_wendy07_register.R

source("week1/R/0_setup.R")
suppressPackageStartupMessages(library(openxlsx))
setDTthreads(2)
CHK <- file.path(PATHS$output, "4_check_reported")
RUNS_DIR <- file.path("week1", "models", "wendy_iteration_07")
OUT <- "week1/docs/wendy07_experiment_register.xlsx"
r5 <- function(x) round(x, 5)

# 1. Run definitions (step numbers = week1/docs/wendy07_experiment_log.md) -------------------------------------------
FE_EX <- "all:voluntary_excess=B"; SE_BI <- "motor/bodily_injury:freq_trend=none,sev_trend=none"
FE_LAB <- paste(FE_EX, "buildings/flood:days_quote_to_inception=-", "buildings/flood:start_month=-",
                "motor/third_party_prop:freezing_days=-", "motor/third_party_prop:rainfall_mm=-", sep = ";")
SE_LAB <- paste(SE_BI, "buildings/escape_of_water:sev_model=gamma_glm", "buildings/fire:freq_min_child_weight=15",
                "contents/theft:sev_model=gamma_glm", "motor/theft:sev_model=gamma_glm", sep = ";")
CL <- "chain_ladder"; OV <- "buildings/subsidence=report_share_days"
runs <- rbindlist(list(
  list("smoke_a2", 2, "1", "-", "FAST smoke test of chain ladder (fewer rounds, higher learning rate)", CL, "", "", "", 1, "W4 mix", "0", "0",
       "Catch code errors before full runs; first look at chain-ladder shares", "Not a model candidate (FAST mode)", "Superseded"),
  list("report_share", 4, "1", "-", "A0 before frozen-snapshot runs (script edited while running)", "report_share", "", "", "", 1, "W4 mix", "0", "0",
       "First A0 attempt", "Possibly mixed script versions - replaced by a0", "Superseded"),
  list("a0", 4, "1", "-", "Baseline: WENDY 4 engine re-run (mid-date ECDF IBNR)", "report_share", "", "", "", 1, "W4 mix", "0", "0",
       "WENDY 7 must equal WENDY 4 before any change can be attributed", "Actuals identical to WENDY 4 re-score; predictions corr 0.996-0.999 (xgboost 3.2.1); 0.1014 vs 0.1008 reference", "Baseline"),
  list("a1", 5, "1", "a0", "IBNR: lag ECDF averaged over every day of the row (A1)", "report_share_days", "", "", "", 1, "W4 mix", "0", "0",
       "A0 reads the ECDF at the row mid-date; averaging over the row's days removes the convexity bias", "Within noise on D2 (folds' training rows are mature); backtest 0.998 vs A0 0.971", "Used for subsidence only"),
  list("a2", 5, "1", "a0", "IBNR: reported-count chain ladder per peril (A2)", CL, "", "", "", 1, "W4 mix", "0", "0",
       "Uses all cohorts and lags up to 4 years; volume-weighted age-to-age factors", "Within noise on D2; backtest 0.999 (best) except subsidence 1.12", "Kept (all perils except subsidence)"),
  list("b6", 7, "1", "a0", "voluntary_excess in frequency and severity of every peril", "report_share", "", FE_EX, "", 1, "W4 mix", "0", "0",
       "Excess removes small claims and slices every claim; workbook lacked it for motor BI, flood/storm/subsidence severity, fire frequency",
       "ALL +0.00102 (2 SE 0.00107, 100% of draws); BI Tweedie +0.0055, fire +0.0053, flood +0.002", "Kept"),
  list("b4", 11, "1", "a0", "HIST_V2: address peril history + credibility-weighted policy claim relativity", "report_share", "", "", "", 1, "W4 mix", "0", "1",
       "Prior flood / water / subsidence / storm claims at the address and own-policy experience predict those perils",
       "ALL +0.0006 alone (noise); with excess (C1) no gain - does not stack", "Dropped"),
  list("c1", 11, "1", "b6", "vs B6: + chain ladder IBNR (subsidence A1) + HIST_V2", CL, OV, FE_EX, "", 1, "W4 mix", "1", "1",
       "Combine the round-1 candidates", "0.1020 < B6 0.1024: history does not add on top of excess", "Dropped"),
  list("c2", 11, "1", "b6", "vs B6: + chain ladder IBNR (subsidence A1)", CL, OV, FE_EX, "", 1, "W4 mix", "1", "0",
       "Excess plus the IBNR the backtest supports", "0.1018: inside the +-0.0006 noise band of B6", "Kept (as basis)"),
  list("c2bag5", 11, "1", "c2", "C2 with 5 seed bags per component", CL, OV, FE_EX, "", 5, "W4 mix", "0", "0",
       "Average away fit-to-fit noise (per-peril noise ~0.0005)", "0.1017; buildings +0.0007, contents +0.0004, motor -0.0009 (B6 motor was a lucky draw)", "Kept"),
  list("c3", 13, "1", "c2bag5", "C2 bag5 + final fit with both methods per peril", CL, OV, FE_EX, "", 5, "W4 mix", "1", "0",
       "First full candidate", "0.1017 (= c2bag5, deterministic); 2025 BI 177 below every year -> step 14", "Superseded by c4"),
  list("c4", 14, "1", "c3", "motor BI frequency and severity trend = none", CL, OV, FE_EX, SE_BI, 5, "W4 mix", "1", "0",
       "BI trend fitted on immature cost read IBNER as a decline; hold the recent level instead",
       "Local motor -0.0006 (noise; local actuals share the immaturity); 2025 BI 177 -> 200", "Kept - WENDY 7 part of submission #10"),
  list("c5", 18, "2", "c4", "C4 + 7 per-peril lab winners (see Feature_Changes)", CL, OV, FE_LAB, SE_LAB, 5, "W4 mix, own_damage freq_sev", "1", "0",
       "Confirm the actuarially screened lab winners together at 5 bags",
       "0.10255 vs C4 0.10143 (+0.0011): motor +0.0021, buildings +0.0004, contents +0.0004", "Kept - WENDY 7 part of final2")),
  use.names = FALSE)
setnames(runs, c("run", "log_step", "round", "parent", "change_vs_parent", "IBNR_METHOD", "IBNR_OVERRIDE", "FEATURE_EDITS", "SPEC_EDITS",
                 "BAGS", "method_mix", "FINAL_FIT", "HIST_V2", "purpose_and_hypothesis", "result_and_evidence", "decision"))
blends <- data.table(
  run = c("report_share_blend", "c2bag5_blend", "sub10", "final2", "stack"),
  log_step = c(9, 12, 15, 19, 17), round = c("1", "1", "1", "2", "2"),
  parent = c("report_share", "c2bag5", "c4 + SAM 3", "c5 + SAM 3", "c4 + SAM 3 candidates"),
  change_vs_parent = c("per-peril freq_sev / Tweedie weights (grid 0.25)", "same on the bagged run",
                       "per-line 0.5 x WENDY 7 C4 + 0.5 x SAM 3 = SUBMISSION #10", "per-line WENDY 7 C5 x SAM 3 (motor 0.8, buildings 0.5, contents 0.6)",
                       "greedy stack per line over WENDY 7 + 5 SAM 3 candidates"),
  purpose_and_hypothesis = c("The two methods make partly independent errors", "Re-check on stronger components",
                             "WENDY and SAM tie locally but are built differently (corr ~0.95)", "Same blend on the improved WENDY 7",
                             "SAM's peril GLM is most different from WENDY 7 in motor (corr 0.90)"),
  result_and_evidence = c("Cross-fold +0.0011 / +0.0011 (single fit)", "Cross-fold -0.0025 / +0.0004: weights do not transfer across years",
                          "+0.00093 vs SAM 3 (2 SE 0.00047, 100% of draws); PUBLIC 0.12924 (+0.00106 vs SAM 3)",
                          "+0.00074 vs #10 (2 SE 0.00051, 100% of draws); on hold", "In-sample +0.0003 vs 50/50 but cross-fold motor -0.0012 / -0.0014"),
  decision = c("Superseded", "Dropped", "SUBMITTED #10 (public 0.12924)", "Candidate - ON HOLD", "Dropped"))

# 2. Scores of every run ---------------------------------------------------------------------------------------
tag_of <- function(r) paste0("wendy07_", r)
read_ls <- function(r) { f <- file.path(CHK, tag_of(r), "line_scores.csv"); if (file.exists(f)) fread(f)[, run := r] else NULL }
all_runs <- c(runs$run, blends$run, "sam03")
ls_all <- rbindlist(lapply(setdiff(all_runs, "sam03"), read_ls), fill = TRUE)
ls_all <- rbind(ls_all, fread(file.path(CHK, "sam03", "line_scores.csv"))[, run := "sam03"], fill = TRUE)
ls_all <- ls_all[, .(run, basis, valid_year, line, d2, gini, pred_vs_actual)]
wide <- dcast(ls_all[basis == "reported_raw"], run ~ line + valid_year, value.var = "d2")
for (ln in c("ALL", LINES)) wide[, (paste0(ln, "_mean")) := (get(paste0(ln, "_2023")) + get(paste0(ln, "_2024"))) / 2]
dev <- dcast(ls_all[basis == "developed", .(d2 = mean(d2)), by = .(run, line)], run ~ line, value.var = "d2")
setnames(dev, setdiff(names(dev), "run"), paste0("developed_mean_", setdiff(names(dev), "run")))
score_cols <- c(paste0(c("ALL", LINES), "_mean"), "ALL_2023", "ALL_2024")
add_scores <- function(d) {
  d <- merge(d, wide[, c("run", score_cols), with = FALSE], by = "run", all.x = TRUE, sort = FALSE)
  d <- merge(d, dev[, .(run, developed_mean_ALL)], by = "run", all.x = TRUE, sort = FALSE)
  p <- wide[match(d$parent, run)]
  for (cc in paste0(c("ALL", LINES), "_mean")) set(d, j = paste0("delta_vs_parent_", sub("_mean", "", cc)), value = d[[cc]] - p[[cc]])
  num <- names(d)[vapply(d, is.numeric, logical(1)) & !names(d) %in% c("log_step", "BAGS")]
  d[, (num) := lapply(.SD, r5), .SDcols = num][]
}
run_log <- add_scores(runs)
blend_log <- add_scores(blends)

# 2025 level per run
lvl <- rbindlist(lapply(runs$run, function(r) { f <- file.path(RUNS_DIR, r, "test_by_line.csv")
  if (file.exists(f)) fread(f)[, .(run = r, line, burn_2025 = round(predicted_burn, 1))] else NULL }))
if (nrow(lvl)) run_log <- merge(run_log, dcast(lvl, run ~ line, value.var = "burn_2025")[, setnames(.SD, LINES, paste0("burn_2025_", LINES))],
                               by = "run", all.x = TRUE, sort = FALSE)

# 3. Peril scores of every run ---------------------------------------------------------------------------------
ps_all <- rbindlist(lapply(runs$run, function(r) { f <- file.path(CHK, tag_of(r), "peril_scores.csv")
  if (file.exists(f)) fread(f)[, run := r] else NULL }), fill = TRUE)
ps_mean <- ps_all[basis == "reported_raw", .(d2_2023 = d2[valid_year == 2023], d2_2024 = d2[valid_year == 2024], mean_2023_24 = mean(d2),
                                             pred_vs_actual_2024 = pred_vs_actual[valid_year == 2024]), by = .(run, line, peril, method)]
ps_wide <- dcast(ps_mean, line + peril + method ~ run, value.var = "mean_2023_24")
setcolorder(ps_wide, c("line", "peril", "method", intersect(runs$run, names(ps_wide))))

# 4. Feature map of every run vs A0 (what exactly changed, peril by peril) ---------------------------------------
fm <- rbindlist(lapply(runs$run, function(r) { f <- file.path(RUNS_DIR, r, "features_used.csv")
  if (file.exists(f)) fread(f)[, .(run = r, line, peril, column, code)] else NULL }))
base_fm <- fm[run == "a0", .(line, peril, column, code_a0 = code)]
fm_diff <- rbindlist(lapply(setdiff(unique(fm$run), "a0"), function(r) {
  x <- merge(base_fm, fm[run == r, .(line, peril, column, code_run = code)], by = c("line", "peril", "column"), all = TRUE)
  x[is.na(code_a0), code_a0 := "-"][is.na(code_run), code_run := "-"][code_a0 != code_run][, run := r]
}))
fm_diff[, change := fcase(code_a0 == "-", "added", code_run == "-", "dropped", default = paste0("code ", code_a0, " -> ", code_run))]
setcolorder(fm_diff, c("run", "line", "peril", "column", "code_a0", "code_run", "change"))

# 5. Feature / setting changes tried, with effect and decision ----------------------------------------------------
ps_b6 <- merge(ps_mean[run == "a0", .(line, peril, method, a0 = mean_2023_24)], ps_mean[run == "b6", .(line, peril, method, b6 = mean_2023_24)])
ex_rows <- merge(fm_diff[run == "b6", .(line, peril, column, change)], ps_b6, by = c("line", "peril"), allow.cartesian = TRUE)
ex_rows <- ex_rows[, .(source = "run b6 (step 7)", line, peril, change = paste(column, change), method,
                       effect_peril_mean_2023_24 = r5(b6 - a0), effect_ALL_mean_2023_24 = NA_real_, effect_ALL_2022 = NA_real_,
                       decision = "Kept", reason = "Excess applies to every claim: belongs in frequency and severity of every peril")]
hist_rows <- fm_diff[run == "b4", .(source = "run b4 (step 11)", line, peril, change = paste(column, change), method = "both",
                                    effect_peril_mean_2023_24 = NA_real_, effect_ALL_mean_2023_24 = r5(run_log[run == "b4", delta_vs_parent_ALL]),
                                    effect_ALL_2022 = NA_real_, decision = "Dropped", reason = "No gain on top of excess (run c1)")]
lab <- fread(file.path(CHK, "peril_lab", "ranked.csv"))
accepted <- c("motor own_damage method_other", "motor third_party_prop drop_weather", "buildings escape_of_water sev_gamma_glm",
              "motor theft sev_gamma_glm", "contents theft sev_gamma_glm", "buildings fire mcw_half", "buildings flood drop_admin")
rejected <- c("motor bodily_injury freq_trend_flip" = "Rejected actuarially: wins only because local actuals share the IBNER the trend picks up",
              "buildings storm drop_weather" = "Rejected actuarially: a storm model without wind / hail / rainfall is not credible; tiny gain",
              "contents escape_of_water drop_weather" = "Rejected actuarially: frost bursts pipes; 2022 fold disagrees")
lab[, key := paste(line, peril, id)]
lab[, decision := fcase(key %in% accepted, "Accepted (in C5 / final2)", key %in% names(rejected), "Passed rule, rejected actuarially",
                        pass == TRUE, "Passed rule, not best for its peril", default = "Failed rule")]
lab[, reason := fcase(key %in% names(rejected), rejected[key], key %in% accepted, "Best passing variant for its peril; actuarially plausible",
                      pass == TRUE, "Another variant of the same peril gained more (one change per peril)",
                      default = "Mean 2023-24 gain <= 0.00005 or a fold lost > 0.0001")]
lab_rows <- lab[, .(source = "peril lab (step 18)", line, peril, change = paste0(id, ": ", desc), method,
                    effect_peril_mean_2023_24 = r5((d_peril_2023 + d_peril_2024) / 2), effect_ALL_mean_2023_24 = r5(gain_2324),
                    effect_ALL_2022 = r5(d_all_2022), decision, reason)]
run_rows <- rbind(
  data.table(source = "run a1 / a2 (step 5)", line = "all", peril = "all", change = c("IBNR ECDF over row days (A1)", "IBNR chain ladder (A2)"),
             method = "both", effect_peril_mean_2023_24 = NA_real_, effect_ALL_mean_2023_24 = run_log[match(c("a1", "a2"), run), delta_vs_parent_ALL],
             effect_ALL_2022 = NA_real_, decision = c("Used for subsidence", "Kept"), reason = "Judged on the one-year backtest (sheet IBNR_Backtest), not D2"),
  data.table(source = "run c2bag5 (step 11)", line = "all", peril = "all", change = "5 seed bags per component", method = "both",
             effect_peril_mean_2023_24 = NA_real_, effect_ALL_mean_2023_24 = run_log[run == "c2bag5", delta_vs_parent_ALL], effect_ALL_2022 = NA_real_,
             decision = "Kept", reason = "Lower variance on unseen 2025 rows; buildings / contents improve"),
  data.table(source = "run c4 (step 14)", line = "motor", peril = "bodily_injury", change = "freq_trend = none, sev_trend = none", method = "tweedie",
             effect_peril_mean_2023_24 = NA_real_, effect_ALL_mean_2023_24 = run_log[run == "c4", delta_vs_parent_ALL], effect_ALL_2022 = NA_real_,
             decision = "Kept", reason = "Do not extrapolate a decline that may be IBNER; 2025 BI 177 -> 200"))
changes <- rbind(run_rows, ex_rows, hist_rows, lab_rows)

# 6. Other checks --------------------------------------------------------------------------------------------------
cmp <- rbindlist(lapply(list.files(CHK, "^compare_wendy07_vs_.*\\.csv$", full.names = TRUE), fread), fill = TRUE)
num <- names(cmp)[vapply(cmp, is.numeric, logical(1))]
cmp[, (num) := lapply(.SD, r5), .SDcols = num]
bt <- fread(file.path(CHK, "ibnr_backtest_summary.csv"))
bt_w <- dcast(bt[loss_year == 2023], line + peril ~ method, value.var = "projected_over_actual")
ceil <- fread(file.path(CHK, "wendy07_smoke_a2", "ceiling.csv"))
blend_detail <- rbind(
  fread(file.path(CHK, "wendy07_sub10", "line_weights.csv"))[, model := "sub10 (C4 x SAM 3) - SUBMITTED #10"],
  fread(file.path(CHK, "wendy07_final2", "line_weights.csv"))[, model := "final2 (C5 x SAM 3) - on hold"])
stack_w <- fread(file.path(CHK, "wendy07_stack", "stack_weights.csv")); stack_x <- fread(file.path(CHK, "wendy07_stack", "stack_crossfold.csv"))
fixed_mix <- data.table(mix = c("WENDY 4 per-peril pick", "75/25 towards the pick", "50/50 every peril", "all freq_sev", "all Tweedie"),
                        ALL_2023 = c(0.10462, 0.10476, 0.10448, 0.10592, 0.10092), ALL_2024 = c(0.09872, 0.09826, 0.09751, 0.09602, 0.09766),
                        ALL_mean = c(0.10167, 0.10151, 0.10100, 0.10097, 0.09929),
                        motor_2023 = c(0.04244, 0.04289, 0.04321, 0.04537, 0.03998), motor_2024 = c(0.04828, 0.04679, 0.04508, 0.04200, 0.04716))
bi_years <- data.table(policy_year = 2021:2024, mean_severity = c(21451, 22163, 18479, 17829), median_severity = c(13410, 13178, 9812, 9881),
                       open_share = c(0.150, 0.278, 0.493, 0.798), freq_per_1000_reported = c(11.405, 10.721, 10.261, 5.896),
                       freq_per_1000_ult_wendy4_ibnr = c(11.408, 10.764, 10.760, 9.426), freq_per_1000_ult_chain_ladder = c(11.426, 10.819, 10.912, 10.487),
                       burn_developed_chain_ladder = c(245.1, 239.8, 201.7, 187.0))
motor_blend_w <- data.table(weight_wendy07 = c(0.5, 0.6, 0.7, 0.8), motor_2023 = c(0.04469, 0.04488, 0.04500, 0.04506),
                            motor_2024 = c(0.04842, 0.04865, 0.04881, 0.04889), motor_mean = c(0.04656, 0.04677, 0.04691, 0.04698))

# 7. Workbook ----------------------------------------------------------------------------------------------------
readme <- data.table(item = c("What this is", "Primary score", "Noise threshold", "Folds", "Bases", "How to read Run_Log",
                              "Feature changes", "Peril lab", "Submission status", "Goal", "Sources"),
  detail = c("Every try of WENDY 7 (22-23 Oct 2026, rounds 1 and 2): settings, the one change vs its parent, scores, decision.",
             "Mean of the 2023 and 2024 folds, Tweedie D2 (p = 1.5) on reported_raw actuals (booked cost at 31 Dec 2024), all lines together (ALL_mean).",
             "Paired policy bootstrap, 200 draws: 2 x SE of the ALL difference is 0.0005-0.0011 by pair. Gains below ~0.001 are noise unless the bootstrap says otherwise (sheet Bootstrap).",
             "Fit 2021-22 -> score 2023; fit 2021-23 -> score 2024. The peril lab adds fit 2021 -> score 2022 as a check fold that is never used to choose.",
             "reported_raw (primary), reported_adj (WENDY 4 claim basis), developed (reported_adj / WENDY 4 report share) - sheet Line_Scores_All.",
             "One row per run; delta_vs_parent_* = change in mean 2023-24 D2 against the parent run; settings columns are the exact environment variables of week1/R/4_models_iterwendy07.R.",
             "Sheet Feature_Changes: every feature / setting change tried, per line and peril, its effect and the decision. Sheet Feature_Map_Diff: the exact feature codes of each run vs A0.",
             "269 single-peril variants scored by swapping them into the full prediction (ALL-lines D2). Rule: mean 2023-24 gain > 0.00005 and no fold (incl. 2022) losing > 0.0001; then an actuarial screen.",
             "#10 = sub10 (public 0.12924, best). final2 passes the gate vs #10 (+0.00074) - on hold (Wendy, 23 Oct).",
             "Local 0.25 then 0.135 requested; not reached. Ceiling simulation (sheet Ceiling): a perfect model scores ~0.10 unless true risk spread is ~2.2x wider than any pipeline finds.",
             "week1/docs/wendy07_experiment_log.md (reasoning per step); week1/output/4_check_reported/*; week1/models/wendy_iteration_07/*; week1/R/7_export_wendy07_register.R builds this file."))
wb <- createWorkbook()
hs <- createStyle(textDecoration = "bold", fgFill = "#D9E1F2", wrapText = TRUE, valign = "top")
add <- function(name, dt, widths = NULL) {
  addWorksheet(wb, name); writeData(wb, name, dt, headerStyle = hs); freezePane(wb, name, firstRow = TRUE)
  setColWidths(wb, name, cols = seq_len(ncol(dt)), widths = if (is.null(widths)) "auto" else widths)
  if (nrow(dt) > 0) addFilter(wb, name, rows = 1, cols = seq_len(ncol(dt)))
}
add("README", readme, c(22, 160))
add("Run_Log", run_log)
add("Blends_and_Stacks", blend_log)
add("Feature_Changes", changes)
add("Feature_Map_Diff", fm_diff)
add("Peril_Lab", lab[, .(line, peril, variant = id, desc, method, d_all_2022 = r5(d_all_2022), d_all_2023 = r5(d_all_2023), d_all_2024 = r5(d_all_2024),
                         gain_2023_24 = r5(gain_2324), d_peril_2022 = r5(d_peril_2022), d_peril_2023 = r5(d_peril_2023), d_peril_2024 = r5(d_peril_2024),
                         pass_rule = pass, decision, reason, seconds)])
add("Peril_Scores_by_Run", ps_wide[, lapply(.SD, function(v) if (is.numeric(v)) r5(v) else v)])
add("Peril_Scores_Detail", ps_mean[, lapply(.SD, function(v) if (is.numeric(v)) r5(v) else v)])
add("Line_Scores_All", ls_all[, lapply(.SD, function(v) if (is.numeric(v)) r5(v) else v)])
add("Bootstrap", cmp)
add("IBNR_Backtest", bt_w[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 3) else v)])
add("IBNR_Backtest_Detail", bt)
add("Ceiling", dcast(ceil, spread ~ line, value.var = "perfect_model_d2"))
add("Line_Blends", blend_detail)
add("Stack_Weights", merge(dcast(stack_w, candidate ~ line, value.var = "weight"), data.table(candidate = character()), all.x = TRUE))
add("Stack_Crossfold", stack_x)
add("Method_Blend_Fixed", fixed_mix)
add("Motor_BI_Level", bi_years)
add("Motor_Blend_Weight", motor_blend_w)
saveWorkbook(wb, OUT, overwrite = TRUE)
log_msg("Register: ", OUT, " | runs ", nrow(run_log), ", blends ", nrow(blend_log), ", change rows ", nrow(changes), ", lab ", nrow(lab))
