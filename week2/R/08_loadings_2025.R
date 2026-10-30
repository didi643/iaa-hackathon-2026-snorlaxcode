# 08_loadings_2025.R ------------------------------------------------------------------------------------------------
# Purpose : 2025 loadings on the step 7 final fits, each with an emerging estimate, a developed prior, a credibility
#           weight and a rationale:
#             - trend to 2025: step 4 chosen trends (developed prior blended with emerging 2023->24), one year from the
#               2024 base year of the final fits;
#             - IBNR: inside the frequency (ultimate level, developed chain ladder - step 4), nothing added here;
#             - large-loss load: developed capped-excess load x emerging level (step 7 severity), nothing added here;
#             - new business: the baseline already carries the developed new-business relativity (new_business is a
#               feature). Residual emerging NB A/E of the final B model (2023-24 in sample, developed actuals) per line,
#               credibility Z = claims_NB / (claims_NB + K_NB) towards the prior 1.0 (= developed relativity holds);
#               applied to NB rows only if step 7 did not already keep new_business as a factor for that peril.
#           Sensitivity grid of 2025 burn per line for each loading.
# Inputs  : data/week_2/optionB/adjust/<tag>/{final_2025_peril,insample_peril}.parquet, week2/output/04_ibnr_trend/trend_table.csv,
#           week2/output/07_adjust/levels*.csv, data/week_2/optionB/features/emerging_{train,test}_<line>.parquet, emerging claims
# Outputs : data/week_2/optionB/final/<tag>/pred_2025_peril.parquet, week2/output/08_loadings/<tag>/ (loadings.csv,
#           sensitivity.csv, loadings_report.md)
# Run     : Rscript week2/R/08_loadings_2025.R      (RUN_TAG = step 7 tag, default main)
# Time    : under 1 minute

source("week2/R/00_setup_week2.R")
source("week2/R/nb_load_fns.R")
start_script("08_loadings_2025.R")
TAG <- Sys.getenv("RUN_TAG", "main")
ADJ <- Sys.getenv("ADJ_TAG", TAG)   # NB round: read the step 7/14 outputs of ADJ, write final/<TAG> (NB options only differ)
STEP <- file.path("08_loadings", TAG)
FEAT_DIR <- file.path(W2$data, "features")
NBO <- nb_opts()
K_NB <- NBO$K
shares <- load_report_shares()
trend <- fread(file.path(W2$output, "04_ibnr_trend", "trend_table.csv")); track_input(file.path(W2$output, "04_ibnr_trend", "trend_table.csv"))
trend <- trend_mode(trend)   # X20
TREND_FLOOR_FREQ <- Sys.getenv("TREND_FLOOR_FREQ", "")   # X18: lines whose chosen frequency trend is floored at 0 (e.g. "motor")
if (nzchar(TREND_FLOOR_FREQ)) trend[line %in% strsplit(TREND_FLOOR_FREQ, ",")[[1]], freq_trend_chosen := pmax(freq_trend_chosen, 0)]
lv_file <- file.path(W2$output, "07_adjust", if (TAG == "main") "levels.csv" else paste0("levels_", TAG, ".csv"))
levels_tab <- fread(lv_file); track_input(lv_file)
fin <- read_w2(file.path(W2$data, "adjust", ADJ, "final_2025_peril.parquet"))
ins <- read_w2(file.path(W2$data, "adjust", ADJ, "insample_peril.parquet"))
clp <- claim_basis("emerging")

nb_of <- function(part) rbindlist(lapply(LINES, function(ln) read_w2(file.path(FEAT_DIR, sprintf("emerging_%s_%s.parquet", part, ln)))[, .(row_id, new_business)]))
ins <- merge(ins, nb_of("train"), by = "row_id")
ins <- merge(ins, clp[, .(adj = sum(cost)), by = .(row_id, peril)], by = c("row_id", "peril"), all.x = TRUE)
ins[is.na(adj), adj := 0]
ins[, `:=`(dev = adj / share, pred = exposure * freq_B * sev_B, predE = exposure * freq_E * sev_E)]

# New business residual A/E (nb_load_fns.R; defaults = D020: per line, pooled perils, relative to the line's overall A/E)
nb <- ins[, .(pred = sum(pred), actual = sum(dev), claims = sum(n)), by = .(line, new_business)]
nb[, ae := actual / pred]
nb[, rel := ae / (sum(actual) / sum(pred)), by = line]
nb_in_model <- levels_tab[, .(nb_factor = grepl("new_business", freq_factors) | grepl("new_business", sev_factors)), by = .(line, peril)]
nbp <- nb_load_table(ins, nb_in_model, NBO, if (NBO$prior != "one" || (NBO$level == "peril" && NBO$pprior != "line")) dev_nb_resid(c(2023L, 2024L)))
nbl <- unique(nbp[, .(line, nb_claims, nb_ae_rel, prior, z, nb_load = nb_load_line)])

# Assemble 2025 per row x peril ------------------------------------------------------------------------------------------
fin <- merge(fin, nb_of("test"), by = "row_id")
fin <- merge(fin, trend[, .(line, peril, gf = freq_trend_chosen, gs = sev_trend_chosen, sens_low, sens_high)], by = c("line", "peril"))
fin <- merge(fin, nb_in_model, by = c("line", "peril"))
fin <- merge(fin, nbp[, .(line, peril, nb_load)], by = c("line", "peril"))
fin[, nbf := fifelse(new_business & !nb_factor, nb_load, 1)]
fin[, tr := (1 + gf) * (1 + gs)]
fin[, `:=`(pred_B = exposure * freq_B * sev_B * tr * nbf, pred_L = exposure * freq_L * sev_L * tr * nbf,
           pred_E = exposure * freq_E * sev_E * tr, pred_D = exposure * bfreq * bsev)]
fin[, pred_BE := 0.5 * pred_B + 0.5 * pred_E]
write_w2(fin, file.path(W2$data, "final", TAG, "pred_2025_peril.parquet"))

loadings <- merge(trend[, .(line, peril, freq_trend = freq_trend_chosen, sev_trend = sev_trend_chosen)],
                  levels_tab[, .(line, peril, freq_level = freq_level_final, sev_level = sev_level_final, developed_load,
                                 emerging_load = emerging_load_final, freq_factors, sev_factors)], by = c("line", "peril"))
loadings <- merge(loadings, nbl, by = "line")
loadings <- merge(loadings, nbp[, .(line, peril, nb_load_peril = nb_load)], by = c("line", "peril"))
loadings <- merge(loadings, nb_in_model, by = c("line", "peril"))
save_csv(loadings, STEP, "loadings.csv")

# Sensitivity grid: 2025 burn per line under each loading moved alone ----------------------------------------------------------
base_b <- fin[, .(central = sum(pred_B)), by = line]
expo <- fin[!duplicated(row_id), .(exposure = sum(exposure)), by = line]
fin <- merge(fin, nbl[, .(line, nb_ae_rel)], by = "line")
fin <- merge(fin, levels_tab[, .(line, peril, ll_ratio = fifelse(is.finite(emerging_load_final / developed_load), emerging_load_final / developed_load, 1))], by = c("line", "peril"))
sens <- list(
  trend_low = fin[, sum(pred_B / tr * (1 + pmin(gf, 0) - 0.02) * (1 + gs - 0.03)), by = line],
  trend_high = fin[, sum(pred_B / tr * (1 + gf + 0.02) * (1 + gs + 0.03)), by = line],
  nb_none = fin[, sum(pred_B / nbf), by = line],
  nb_full_emerging = fin[, sum(pred_B / nbf * fifelse(new_business & !nb_factor, nb_ae_rel, 1)), by = line],
  ibnr_plus5 = fin[, sum(pred_B * fifelse(peril %in% c("bodily_injury", "subsidence"), 1.05, 1.0)), by = line],
  large_loss_emerging_load = fin[, sum(pred_B * ll_ratio), by = line],
  level_only_L = fin[, sum(pred_L), by = line],
  emerging_only_E = fin[, sum(pred_E), by = line],
  developed_level_D = fin[, sum(pred_D), by = line])
sens <- rbindlist(lapply(names(sens), function(k) sens[[k]][, scenario := k]))
setnames(sens, "V1", "total")
sens <- merge(merge(sens, base_b, by = "line"), expo, by = "line")
sens[, `:=`(burn = total / exposure, vs_central = total / central - 1)]
save_csv(sens, STEP, "sensitivity.csv")

if (TAG == "main") {
  add_decision("D020", "8", sprintf("New business: residual emerging NB A/E of the final model per line, credibility Z = n/(n+%d) toward 1 (developed relativity already in the baseline); not applied where step 7 kept new_business", K_NB),
               "Flat developed 1.3-1.5x NB load on top (double counts the baseline's NB relativity); full emerging NB A/E", "week2/output/08_loadings/main/loadings.csv", "decided")
  add_decision("D021", "8", "Trend to 2025 = one year at the step 4 chosen rates from the 2024 base year; IBNR and large-loss load already inside frequency / severity",
               "Two-year trend from 2023-24 mid-point; separate IBNR uplift (double count)", "week2/output/08_loadings/main/sensitivity.csv", "decided")
  add_assumption("A008", "8", "NB credibility constant K_NB", K_NB, "judgement", "Z = n/(n+K)", "nb_none / nb_full_emerging scenarios")
}
kl <- c(sprintf("- NB residual A/E (relative) by line: %s; loads applied %s.", paste(nbl[, sprintf("%s %.3f (n %d)", line, nb_ae_rel, nb_claims)], collapse = ", "),
                paste(nbl[, sprintf("%s %.3f", line, nb_load)], collapse = ", ")),
        sprintf("- 2025 central burn (B): %s.", paste(merge(base_b, expo, by = "line")[, sprintf("%s %.1f", line, central / exposure)], collapse = ", ")))
write_md(list(paste0("# Step 8: 2025 loadings (run ", TAG, ")"), "", paste("Generated", ts_sgt(), "by `week2/R/08_loadings_2025.R`."), "", kl, "",
              "## New business check", "", md_table(nb, 3), "## Loadings per peril", "", md_table(loadings, 3),
              "## Sensitivity (2025 burn per line)", "", md_table(sens[order(line, scenario)], 3)), STEP, "loadings_report.md")
if (TAG == "main") update_step_log("8", "2025 loadings", kl)
end_script()
