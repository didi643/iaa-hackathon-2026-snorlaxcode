# 16_peril_review.R ----------------------------------------------------------------------------------------------------
# Purpose : Actuarial review per line x peril of the current best runs after submission #3 (Wendy, 26 Oct 2026): every
#           component of the 2025 rate (frequency level, severity level, factors, trend, large-loss load, new-business load,
#           2025 burn vs 2023-24 history) next to the 2024 fold scores (frequency, claim-level severity, cost D2, A/E) for
#           the developed-shape severity (main = #2) and the emerging-only severity GLM (x11e_ssel, all lines).
#           Peril scoring copied from 12_submission_log.R (peril_scores), without the reported_raw column.
# Inputs  : data/week_2/optionB/adjust/<tag>/valid_2024_peril.parquet, week2/output/{05_baseline,07_adjust,08_loadings/main,10_final}/*
# Outputs : week2/output/16_review/peril_review.csv, peril_scores_<tag>.csv
# Run     : Rscript week2/R/16_peril_review.R
# Time    : seconds

source("week2/R/00_setup_week2.R")
start_script("16_peril_review.R")
STEP <- "16_review"
TAGS <- strsplit(Sys.getenv("REVIEW_TAGS", "main,x11e_ssel"), ",")[[1]]
clp <- claim_basis("emerging")
dg <- fread(file.path(W2$output, "05_baseline", "diagnostics_final.csv"))
pois_d2 <- function(y, mu, base) { d <- function(m) 2 * sum(ifelse(y > 0, y * log(y / m), 0) - (y - m)); 1 - d(mu) / d(base) }
gam_d2 <- function(y, mu) { d <- function(m) 2 * sum(-log(y / m) + (y - m) / m); 1 - d(mu) / d(rep(mean(y), length(y))) }
d2_c <- function(y, mu) 1 - sum(tweedie_dev(y, mu)) / sum(tweedie_dev(y, rep(mean(y), length(y))))
adj <- clp[, .(adj = sum(cost)), by = .(row_id, peril)]

score_tag <- function(tag) {
  lv <- fread(file.path(W2$output, "07_adjust", if (tag == "main") "levels.csv" else paste0("levels_", tag, ".csv")))
  v <- merge(read_w2(file.path(W2$data, "adjust", tag, "valid_2024_peril.parquet")), adj, by = c("row_id", "peril"), all.x = TRUE)
  v[is.na(adj), adj := 0][, `:=`(pred = exposure * freq_B * sev_B, dev = adj / share)]
  rbindlist(lapply(split(v, by = c("line", "peril")), function(d) {
    ln <- d$line[1]; pr <- d$peril[1]; ok <- d$freq_B > 0
    mu_n <- d$exposure * d$freq_B * d$share
    base_n <- d$exposure * d$share * sum(d$n[ok]) / sum((d$exposure * d$share)[ok])
    cl <- merge(clp[line == ln & peril == pr & row_id %chin% d$row_id, .(row_id, cost)], d[, .(row_id, sv = sev_B)], by = "row_id")
    cap <- dg[line == ln & peril == pr, cap] * lv[line == ln & peril == pr, sev_cap_level_final]
    data.table(tag = tag, line = ln, peril = pr, claims_2024 = sum(d$n), freq_d2 = pois_d2(d$n[ok], mu_n[ok], base_n[ok]), freq_ae = sum(d$n) / sum(mu_n),
               sev_d2_capped = if (nrow(cl) > 1) gam_d2(pmin(cl$cost, cap), pmin(cl$sv, cap)) else NA_real_,
               sev_ae = mean(cl$cost) / mean(cl$sv), cost_d2 = d2_c(d$dev, d$pred), cost_ae = sum(d$dev) / sum(d$pred),
               sev_factors = lv[line == ln & peril == pr, sev_factors])
  }))
}
sc <- rbindlist(lapply(TAGS, score_tag))
for (t in TAGS) save_csv(sc[tag == t], STEP, sprintf("peril_scores_%s.csv", t))
w <- dcast(sc, line + peril + claims_2024 ~ tag, value.var = c("sev_d2_capped", "cost_d2", "sev_ae", "cost_ae"))

lv <- fread(file.path(W2$output, "07_adjust", "levels.csv"))
ld <- fread(file.path(W2$output, "08_loadings", "main", "loadings.csv"))
bp <- fread(file.path(W2$output, "10_final", "burn_by_peril.csv"))
rev <- Reduce(function(a, b) merge(a, b, by = c("line", "peril")), list(
  lv[, .(line, peril, claims_all, freq_level = freq_level_final, sev_level = sev_level_final, freq_factors, sev_factors_main = sev_factors)],
  ld[, .(line, peril, freq_trend, sev_trend, nb_load, nb_factor)], dg[, .(line, peril, dev_claims = claims_sev, sev_type, cap, cap_load)],
  bp[, .(line, peril, burn_2023, burn_2024, burn_mix_2023, burn_mix_2024, burn_2025)],
  sc[tag == "main", .(line, peril, freq_d2, freq_ae)], w[, !"claims_2024"]))
save_csv(rev, STEP, "peril_review.csv")
print(rev[, .(line, peril, n = claims_all, fl = round(freq_level, 2), sl = round(sev_level, 2), ft = round(freq_trend, 3), st = round(sev_trend, 3),
              b23 = round(burn_mix_2023), b24 = round(burn_mix_2024), b25 = round(burn_2025), f_ae = round(freq_ae, 2),
              sev_dev = round(sev_d2_capped_main, 3), sev_em = round(get(paste0("sev_d2_capped_", TAGS[2])), 3),
              cost_dev = round(cost_d2_main, 4), cost_em = round(get(paste0("cost_d2_", TAGS[2])), 4),
              ae_dev = round(cost_ae_main, 2), ae_em = round(get(paste0("cost_ae_", TAGS[2])), 2))])
end_script()
