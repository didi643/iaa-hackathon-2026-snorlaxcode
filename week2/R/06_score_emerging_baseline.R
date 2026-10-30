# 06_score_emerging_baseline.R -------------------------------------------------------------------------------
# Purpose : Score every emerging training row with the developed baseline (step 5) and measure what changed:
#           actual vs expected (A/E) by line, peril and year, then by every candidate factor (age band, cover type,
#           new business, channel, construction type (checks the MIX -> non_standard map), property type, urban density,
#           weather bands, occupation, self_employed, renewal count, sum insured band...). Expected = baseline
#           frequency x exposure x reported share (claims REPORTED by 31 Dec 2024, so A/E compares like with like);
#           cost A/E uses the baseline severity. Factor A/Es are divided by the peril's overall A/E, so a flat line
#           at 1 means the developed relativity holds in emerging.
# Inputs  : data/week_2/optionB/baseline/baseline_emerging_train.parquet, data/week_2/optionB/features/emerging_train_<line>.parquet,
#           data/week_2/optionB/clean/emerging_claims_matched.parquet, week2/output/04_ibnr_trend/report_share_quarter.csv
# Outputs : week2/output/06_ae/ ae_line_peril.csv, ae_factor.csv, ae_slopes.csv, ae_report.md, ae_<line>_<factor>.png
# Run     : Rscript week2/R/06_score_emerging_baseline.R      (from the repo root)
# Time    : under 1 minute

source("week2/R/00_setup_week2.R")
start_script("06_score_emerging_baseline.R")
suppressPackageStartupMessages(library(ggplot2))
STEP <- "06_ae"
FEAT_DIR <- file.path(W2$data, "features")
shares <- load_report_shares()
clp <- claim_basis("emerging")
base <- read_w2(file.path(BASE_DIR, BASE_TAG, "baseline_emerging_train.parquet"))
DIAG_F <- file.path(if (nzchar(BASE_DIAG_DIR)) BASE_DIAG_DIR else file.path(W2$output, "05_baseline"), "diagnostics_final.csv")
diag <- fread(DIAG_F); track_input(DIAG_F)

# Long table: one row per emerging training row x peril with actual and expected counts and cost
long <- list()
for (ln in LINES) {
  ft <- read_w2(file.path(FEAT_DIR, sprintf("emerging_train_%s.parquet", ln)))
  b <- base[line == ln]
  ft <- merge(ft, b[, !c("line", "exposure")], by = "row_id")
  for (pr in PERILS[[ln]]) {
    cap <- diag[line == ln & peril == pr, cap]
    cl <- clp[line == ln & peril == pr, .(n = .N, cost = sum(cost), capped = sum(pmin(cost, cap))), by = row_id]
    d <- ft[, .(row_id, policy_id, policy_year, exposure, bfreq = get(paste0("bfreq_", pr)), bsev = get(paste0("bsev_", pr)))]
    d[, share := row_report_share(shares, ln, pr, ft$period_start, ft$period_end)]
    d <- merge(d, cl, by = "row_id", all.x = TRUE)
    for (cn in c("n", "cost", "capped")) set(d, which(is.na(d[[cn]])), cn, 0)
    d[, `:=`(line = ln, peril = pr, exp_n = exposure * bfreq * share, exp_cost = exposure * bfreq * share * bsev,
             load = diag[line == ln & peril == pr, cap_load])]
    long[[paste(ln, pr)]] <- d
  }
}
long <- rbindlist(long)

ae_lp <- long[, .(exposure = sum(exposure), claims = sum(n), exp_claims = sum(exp_n), cost = sum(cost), exp_cost = sum(exp_cost),
                  capped = sum(capped), exp_capped = sum(exp_cost / load)), by = .(line, peril, policy_year)]
ae_lp <- rbind(ae_lp, ae_lp[, lapply(.SD, sum), by = .(line, peril), .SDcols = c("exposure", "claims", "exp_claims", "cost", "exp_cost", "capped", "exp_capped")][, policy_year := 0L])
ae_lp[, `:=`(ae_freq = claims / exp_claims, ae_sev_capped = (capped / pmax(claims, 1)) / (exp_capped / exp_claims), ae_cost = cost / exp_cost)]
ae_lp[, ae_freq_lo := qgamma(0.025, claims) / exp_claims][, ae_freq_hi := qgamma(0.975, claims + 1) / exp_claims]
setorder(ae_lp, line, peril, policy_year)
save_csv(ae_lp, STEP, "ae_line_peril.csv")

# Factor A/E: per line and factor level, frequency A/E pooled over the line's perils, relative to each peril's overall A/E
# (expected scaled so every peril's total A/E = 1 before pooling)
lvl <- ae_lp[policy_year == 0, .(line, peril, k = ae_freq, ks = ae_cost)]
long <- merge(long, lvl, by = c("line", "peril"))
long[, `:=`(exp_n_s = exp_n * k, exp_cost_s = exp_cost * ks)]
band <- function(x, br) { x <- as.numeric(x); cut(x, unique(quantile(x, br, na.rm = TRUE)), include.lowest = TRUE, dig.lab = 4) }
FACTORS <- list(
  motor = c("driver_age_band", "cover_type", "new_business", "channel", "vehicle_use", "overnight_parking", "urban_density",
            "named_young_driver", "fuel_type", "body_type", "occupation", "self_employed", "marital_status", "payment_method",
            "ncb_years_b", "renewal_count_b", "vehicle_value_group_b", "vehicle_age_b", "voluntary_excess", "hail_days_b", "freezing_days_b",
            "rainfall_mm_b", "years_licensed_b", "hist_policy_claims_prev", "licence_points_b", "policy_year"),
  buildings = c("policyholder_age_band", "construction_type", "new_business", "channel", "property_type", "urban_density", "occupancy",
                "flood_zone", "soil_type", "roof_type", "basement", "trees_within_5m", "occupation", "self_employed", "sum_insured_b",
                "voluntary_excess", "wind_exposure_index_b", "wildfire_index_b", "rainfall_mm_b", "dry_summer_index_b", "hail_days_b",
                "renewal_count_b", "policy_year"),
  contents = c("policyholder_age_band", "tenure", "new_business", "channel", "security_level", "property_type", "urban_density",
               "flood_zone", "occupation", "self_employed", "sum_insured_b", "high_value_items", "voluntary_excess", "works_from_home",
               "lodgers", "bicycle_cover", "rainfall_mm_b", "renewal_count_b", "policy_year"))
fac_rows <- list()
for (ln in LINES) {
  ft <- read_w2(file.path(FEAT_DIR, sprintf("emerging_train_%s.parquet", ln)))
  for (v in c("ncb_years", "renewal_count", "vehicle_value_group", "vehicle_age", "years_licensed", "licence_points", "sum_insured",
              "hail_days", "freezing_days", "rainfall_mm", "wind_exposure_index", "wildfire_index", "dry_summer_index"))
    if (v %in% names(ft)) ft[, (paste0(v, "_b")) := as.character(band(get(v), seq(0, 1, 0.2)))]
  for (f in FACTORS[[ln]]) {
    x <- merge(long[line == ln, .(row_id, peril, exposure, n, exp_n_s, cost, exp_cost_s)], ft[, .(row_id, lvl = as.character(get(f)))], by = "row_id")
    a <- x[, .(exposure = sum(exposure) / uniqueN(peril), claims = sum(n), exp_claims = sum(exp_n_s), cost = sum(cost), exp_cost = sum(exp_cost_s)), by = lvl]
    a[, `:=`(line = ln, factor = f, rel_ae_freq = claims / exp_claims, rel_ae_cost = cost / exp_cost,
             se_log = 1 / sqrt(pmax(claims, 1)))]
    fac_rows[[paste(ln, f)]] <- a
  }
}
fac <- rbindlist(fac_rows)
setcolorder(fac, c("line", "factor", "lvl"))
save_csv(fac, STEP, "ae_factor.csv")
# Evidence of slope: chi-square of claims vs scaled expected across levels (frequency), with df = levels - 1
slopes <- fac[exp_claims > 0, .(levels = .N, claims = sum(claims), chi2 = sum((claims - exp_claims)^2 / exp_claims),
                                 max_rel = max(rel_ae_freq[claims >= 20]), min_rel = min(rel_ae_freq[claims >= 20])), by = .(line, factor)]
slopes[, p_value := pchisq(chi2, pmax(levels - 1, 1), lower.tail = FALSE)]
slopes[, slope := fifelse(p_value < 0.01, "yes", fifelse(p_value < 0.05, "weak", "no"))]
setorder(slopes, line, p_value)
save_csv(slopes, STEP, "ae_slopes.csv")

for (ln in LINES) {
  top <- slopes[line == ln & slope != "no", factor]
  if (!length(top)) next
  p <- ggplot(fac[line == ln & factor %in% top & claims >= 10], aes(lvl, rel_ae_freq)) +
    geom_hline(yintercept = 1, colour = "grey50") +
    geom_pointrange(aes(ymin = rel_ae_freq * exp(-1.96 * se_log), ymax = rel_ae_freq * exp(1.96 * se_log)), size = 0.2) +
    facet_wrap(~factor, scales = "free_x") + theme_minimal(base_size = 9) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    labs(title = paste0("Emerging ", ln, ": frequency A/E vs developed baseline, relative to the peril level"), x = NULL, y = "relative A/E")
  f <- out_path(STEP, sprintf("ae_%s_factors.png", ln)); ggsave(f, p, width = 11, height = 7, dpi = 100, bg = "white"); track_output(f)
}

kl <- c(sprintf("- Frequency A/E (2023-24, reported basis) by peril: %s.", paste(ae_lp[policy_year == 0, sprintf("%s/%s %.2f", substr(line, 1, 1), peril, ae_freq)], collapse = ", ")),
        sprintf("- Capped severity A/E by peril: %s.", paste(ae_lp[policy_year == 0, sprintf("%s/%s %.2f", substr(line, 1, 1), peril, ae_sev_capped)], collapse = ", ")),
        sprintf("- Factors with a significant A/E slope (p < 0.01): %s.", paste(slopes[slope == "yes", paste0(line, ":", factor)], collapse = ", ")))
write_md(list("# Step 6: emerging rows scored with the developed baseline", "", paste("Generated", ts_sgt(), "by `week2/R/06_score_emerging_baseline.R`."), "", kl, "",
              "A/E = actual reported / baseline expected reported (baseline at developed level, trended to 2025: the level difference is expected; the factor shape is the question).", "",
              "## By line, peril and year (0 = 2023-24)", "", md_table(ae_lp[, .(line, peril, policy_year, claims, exp_claims, ae_freq, ae_freq_lo, ae_freq_hi, ae_sev_capped, ae_cost)], 3),
              "## Factor slopes (frequency, all perils of the line pooled, relative to each peril's level)", "", md_table(slopes, 3),
              "## Factor A/E tables", "", md_table(fac[, .(line, factor, lvl, exposure, claims, exp_claims, rel_ae_freq, rel_ae_cost)], 3)), STEP, "ae_report.md")
update_step_log("6", "Score emerging with the baseline (A/E)", kl)
end_script()
