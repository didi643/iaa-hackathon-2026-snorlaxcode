# 11_docs_week2.R ----------------------------------------------------------------------------------------------------
# Purpose : Build the generated parts of the week 2 documentation pack from the step outputs, so the numbers in the docs
#           always match the last run:
#             - week2/docs/optionB/model_card_week2.md (structure, features, parameters, validation, 2025 burn, file MD5);
#             - week2/docs/optionB/uncertainty.md (low / central / high burn per line with the reasoning, bootstrap intervals,
#               ceiling, sensitivity grid);
#             - week2/docs/optionB/doc_manifest.csv (MD5 of every doc and the candidate file);
#           and check the hand-written docs exist (what_changed.md, what_we_carried_over.md, README_week2.md).
# Inputs  : week2/output/{05_baseline,07_adjust,08_loadings/main,09_validate/main,10_final}/*, week2/docs/optionB/*
# Outputs : week2/docs/optionB/model_card_week2.md, uncertainty.md, doc_manifest.csv
# Run     : Rscript week2/R/11_docs_week2.R
# Time    : seconds

source("week2/R/00_setup_week2.R")
start_script("11_docs_week2.R")
rd <- function(...) { p <- file.path(W2$output, ...); track_input(p); fread(p) }
ls_b <- rd("05_baseline", "line_scores.csv"); diag <- rd("05_baseline", "diagnostics_final.csv")
lv <- rd("07_adjust", "levels.csv"); fl <- rd("07_adjust", "factor_log.csv")
ld <- rd("08_loadings", "main", "loadings.csv"); sens <- rd("08_loadings", "main", "sensitivity.csv")
sc <- rd("09_validate", "main", "scorecard.csv"); bt <- rd("09_validate", "main", "bootstrap.csv"); ceil <- rd("09_validate", "main", "ceiling_simulation.csv")
cal <- rd("09_validate", "main", "calibration.csv")
bl <- rd("10_final", "burn_by_line.csv"); bp <- rd("10_final", "burn_by_peril.csv"); unc <- rd("10_final", "uncertainty_by_line.csv")
sub_file <- tail(sort(list.files(file.path(W2$output, "submission"), pattern = "week2_optionB\\.csv$", full.names = TRUE)), 1)
sub_md5 <- unname(tools::md5sum(sub_file))

mean_b <- ls_b[, .(mean_d2 = mean(d2)), by = .(basis, line)]
card <- c("# Model card: week 2 emerging market, Option B", "",
  sprintf("Generated %s by `week2/R/11_docs_week2.R` from the step outputs.", ts_sgt()), "",
  "## Candidate file", "",
  sprintf("`%s`, MD5 `%s`, 209,063 rows, header `row_id,prediction`, all predictions >= 0. **Not submitted** (waiting for Wendy).", sub_file, sub_md5), "",
  "## Structure", "",
  "Per row and peril, the 2025 expected ultimate cost is:", "",
  "`exposure x f_dev(x) x L_f x adj_f(x) x (1 + g_f) x s_dev(x) x L_s x adj_s(x) x load_dev x (1 + g_s) x NB`", "",
  "where:", "",
  "- `f_dev(x)`, `s_dev(x)`: developed baseline frequency (Poisson XGBoost, ultimate, from IBNR shares) and capped severity (Gamma XGBoost or GLM), WENDY 7 C5 engine refitted on developed 2021-24 with shared features only (step 5). Relativities only.",
  "- `L_f`, `L_s`: emerging level per peril (2023-24), with credibility toward the line's pooled level (K = 100 claims for frequency; 200 for severity; 600 for sparse heavy perils).",
  "- `adj_f`, `adj_s`: ridge-penalised emerging factor adjustments (lambda 100), kept only if they improve the 2023 -> 2024 deviance.",
  "- `g_f`, `g_s`: one year of trend from 2024 to 2025 (developed prior blended with emerging).",
  "- `load_dev`: developed large-loss load.",
  "- `NB`: residual new-business load with credibility, only where `adj` lacks `new_business`.",
  "- IBNR sits inside `f_dev` (developed chain ladder, verified on emerging lags).", "",
  "The row prediction is the sum over the line's perils. Structural zeros (no cover) give 0.", "",
  "## Developed baseline (step 5)", "", md_table(dcast(mean_b, basis ~ line, value.var = "mean_d2"), 4),
  "Mean of the 2023 and 2024 folds; week 1 C5 (all fields, 5 bags) scored 0.1026 on reported_raw ALL.", "",
  md_table(diag[, .(line, peril, sev_type, claims_freq, rounds_freq, rounds_sev, freq_trend, sev_trend, cap, cap_load)], 3),
  "## Emerging levels and factors (step 7)", "", md_table(lv[, .(line, peril, claims_all, freq_level_final, sev_level_final, freq_factors, sev_factors)], 3),
  sprintf("Factors tried: %d; kept: %d (full log in `week2/output/07_adjust/factor_log.csv`).", nrow(fl[step > 0]), nrow(fl[decision == "kept" & step > 0])), "",
  "## 2025 loadings (step 8)", "", md_table(ld[, .(line, peril, freq_trend, sev_trend, nb_ae_rel, z, nb_load, nb_factor)], 3),
  "## Validation (step 9): emerging 2023 -> 2024, ALL lines", "",
  md_table(sc[line == "ALL", .(weighting, basis, candidate, d2_w1, d2_const, pred_vs_actual)], 4),
  "d2_w1 is the week 1 protocol (baseline: one cost rate per exposure-year); d2_const is Tweedie D2 against the constant mean (sklearn formula). Bor is a diagnostic that uses the answers.", "",
  md_table(bt, 4),
  "## 2025 burn per exposure-year (step 10)", "", md_table(bl, 1), md_table(bp, 2))
f_card <- file.path(W2$docs, "model_card_week2.md"); writeLines(card, f_card); track_output(f_card)

cs <- ceil[, .(mean = sapply(.SD, mean), p5 = sapply(.SD, quantile, 0.05), p95 = sapply(.SD, quantile, 0.95)), .SDcols = !"sim"][, metric := setdiff(names(ceil), "sim")]
ci <- bt[comparison %like% "interval", .(weighting, basis, d2_B, p5 = d2_other, p95 = diff)]
u <- c("# Uncertainty in the week 2 (emerging) prediction", "",
  sprintf("Generated %s by `week2/R/11_docs_week2.R`. Numbers come from steps 8-10; the reasoning is below each table.", ts_sgt()), "",
  "## 1. 2025 burn per exposure-year: low / central / high", "",
  md_table(unc[, .(line, low, central = burn_2025, high, sd_down_loadings = sd_dn, sd_up_loadings = sd_up, level_sd = lvl_sd)], 3),
  "How the range is built:", "",
  "- **Loadings:** the step 8 scenarios moved one at a time:",
  "  - trend +/-2-3% a year;",
  "  - new business: no load vs full emerging residual;",
  "  - BI / subsidence IBNR +5%;",
  "  - emerging vs developed large-loss load.",
  "  Downward and upward moves are each combined in quadrature.",
  "- **Level:** the one-year A/E miss of the model in 2024, combined with the 2023 -> 2024 swing of the emerging burn and the Poisson noise 1/claims. This is the dominant term for buildings, where 2023 (fire 284 per exposure-year) and 2024 (95) differ by a factor of three.",
  "- **Low / high:** central x exp(-/+ sqrt(loadings^2 + level^2)). Roughly a 1-sigma band, not a hard bound.", "",
  "## 2. 2025 vs history (developed actuals, reweighted to the 2025 new-business x channel mix)", "", md_table(bl, 1),
  "- Motor 2025 (595) sits between 2024 (519) and 2023 (821) at the 2025 mix. The 2023 figure is inflated by few, heavy 2023 new-business claims (1.2k vehicle-years).",
  "- Buildings 2025 (366) sits between the two years.",
  "- Contents is stable.",
  sprintf("- By peril, buildings EoW (%.0f vs %.0f-%.0f history) is the largest upward lean: the level credibility pulls it toward the buildings average, plus a 7.3%% severity trend. It is a known judgement to revisit if Wendy prefers less shrinkage.",
          bp[line == "buildings" & peril == "escape_of_water", burn_2025], bp[line == "buildings" & peril == "escape_of_water", burn_2023], bp[line == "buildings" & peril == "escape_of_water", burn_2024]), "",
  "## 3. Sensitivity grid (2025 burn per line, each loading alone)", "", md_table(sens[order(line, scenario), .(line, scenario, burn, vs_central)], 3),
  "## 4. Validation noise", "", "Bootstrap of the 2024 D2 of B (200 paired policy draws):", "", md_table(ci, 4),
  "One fold of about 4k claims: the 90% interval of B's D2 is about 0.03 wide, ten times week 1's noise. Differences under about 0.001-0.002 (2 SE of B - L) cannot be called.", "",
  "## 5. How good can D2 get? (the 0.25 goal)", "",
  "Ceiling simulation: B taken as the TRUE risk, claims simulated (Poisson counts, Gamma sizes with the emerging per-peril CV), then the perfect model scored:", "",
  md_table(cs[, .(metric, mean, p5, p95)], 4),
  sprintf("B scores %.4f (d2_w1) / %.4f (d2_const) on the as-is 2024 developed actuals, close to that ceiling. Even with every line x peril level set to the actual (Bor, uses the answers), D2 is %.4f / %.4f. A local D2 of 0.25 would need the true risk spread to be far wider than any model of this data finds; week 1 reached the same conclusion (week1/R/4_check_ceiling.R).",
          sc[weighting == "as_is" & basis == "developed" & line == "ALL" & candidate == "B", d2_w1], sc[weighting == "as_is" & basis == "developed" & line == "ALL" & candidate == "B", d2_const],
          sc[weighting == "as_is" & basis == "developed" & line == "ALL" & candidate == "Bor", d2_w1], sc[weighting == "as_is" & basis == "developed" & line == "ALL" & candidate == "Bor", d2_const]), "",
  "## 6. Main uncertainties, in order", "",
  "1. **Emerging level per peril.** Only two years exist, and buildings swings by a factor of 1.8 between them.",
  "2. **New-business loading.** 77% of 2025 is new business. Motor moves -11% to +5% between no residual NB load and the full emerging residual.",
  "3. **Trend:** +/-5% per line for +/-2-3% a year.",
  "4. **Dropped developed fields.** About 0.006 of developed D2 (0.0965 vs 0.1026), mostly motor (region, mileage). Unknown how much of that signal exists in emerging.",
  "5. **IBNR and large losses:** small (< 2%), because emerging reporting matches developed.",
  "6. **Takeover selection.** The broker portfolio may differ from the 2023-24 new business in ways the fields do not show. Not measurable from the data.")
f_unc <- file.path(W2$docs, "uncertainty.md"); writeLines(u, f_unc); track_output(f_unc)

need <- file.path(W2$docs, c("what_changed.md", "what_we_carried_over.md", "README_week2.md", "step_log.md", "decision_register.csv", "assumptions_week2.xlsx"))
miss <- need[!file.exists(need)]
if (length(miss)) warning("Docs missing: ", paste(miss, collapse = ", "))
man <- md5_table(c(list.files(W2$docs, full.names = TRUE), sub_file))
man <- man[!grepl("doc_manifest", file)]
fwrite(man, file.path(W2$docs, "doc_manifest.csv")); track_output(file.path(W2$docs, "doc_manifest.csv"))
update_step_log("11", "Documentation pack", c(sprintf("- Docs: %s.", paste(basename(man$file), collapse = ", ")), if (length(miss)) sprintf("- MISSING: %s", paste(basename(miss), collapse = ", "))))
end_script()
