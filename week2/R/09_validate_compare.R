# 09_validate_compare.R ------------------------------------------------------------------------------------------
# Purpose : Validation protocol of handover section 4 on the single honest emerging fold (fit emerging 2023, score
#           emerging 2024; the baseline is fitted on developed only):
#             - candidates: B (full Option B), L (baseline x level), E (emerging only), BE (fixed 50/50 of B and E),
#               D (baseline at the developed level, no emerging information) as a floor;
#             - actuals: reported_raw (booked net cost at 31 Dec 2024) and developed (claim basis / reported share);
#             - D2 two ways: week 1 protocol (baseline = one cost rate per exposure-year, week1/R/oof_io.R) and plain
#               Tweedie D2 against the constant mean (sklearn / Kaggle formula);
#             - scored on the 2024 rows as they are and reweighted to the 2025 test mix (new business x channel cells
#               per line, exposure shares of the test file);
#             - paired policy bootstrap (200 draws) of the differences vs B;
#             - calibration: A/E of B by line, peril, new business, channel and age band (developed actuals).
# Inputs  : data/week_2/optionB/adjust/<tag>/valid_2024_peril.parquet, data/week_2/optionB/features/emerging_{train,test}_<line>.parquet,
#           emerging claims, week2/output/04_ibnr_trend/report_share_quarter.csv
# Outputs : week2/output/09_validate/<tag>/ scorecard.csv, bootstrap.csv, calibration.csv, validate_report.md
# Run     : Rscript week2/R/09_validate_compare.R           (RUN_TAG=<step 7 tag>, default main)
# Time    : about 1-2 minutes

source("week2/R/00_setup_week2.R")
start_script("09_validate_compare.R")
TAG <- Sys.getenv("RUN_TAG", "main")
STEP <- file.path("09_validate", TAG)
FEAT_DIR <- file.path(W2$data, "features")
NBOOT <- 200
shares <- load_report_shares()
clp <- claim_basis("emerging")

vp <- read_w2(file.path(W2$data, "adjust", TAG, "valid_2024_peril.parquet"))
CANDS <- c("B", "L", "E")
for (cn in CANDS) vp[, (paste0("pred_", cn)) := exposure * get(paste0("freq_", cn)) * get(paste0("sev_", cn))]
vp[, pred_BE := 0.5 * pred_B + 0.5 * pred_E]
# Actuals per row x peril
adj <- clp[, .(adj = sum(cost)), by = .(row_id, peril)]
vp <- merge(vp, adj, by = c("row_id", "peril"), all.x = TRUE); vp[is.na(adj), adj := 0]
raw <- rbindlist(lapply(LINES, function(ln) {
  f <- read_w2(file.path(FEAT_DIR, sprintf("emerging_train_%s.parquet", ln)))[policy_year == 2024]
  melt(f[, c("row_id", paste0("y_cost_", PERILS[[ln]])), with = FALSE], id.vars = "row_id", variable.name = "peril", value.name = "raw",
       variable.factor = FALSE)[, peril := sub("^y_cost_", "", peril)]
}))
vp <- merge(vp, raw, by = c("row_id", "peril"), all.x = TRUE)
vp[, dev := adj / share]
# Baseline at developed level (D): from step 5 components
bt <- read_w2(file.path(BASE_DIR, BASE_TAG, "baseline_emerging_train.parquet"))
bl <- rbindlist(lapply(LINES, function(ln) rbindlist(lapply(PERILS[[ln]], function(pr)
  bt[line == ln, .(row_id, peril = pr, pred_D = exposure * get(paste0("bfreq_", pr)) * get(paste0("bsev_", pr)))]))))
vp <- merge(vp, bl, by = c("row_id", "peril"), all.x = TRUE)
CANDS <- c("B", "L", "E", "BE", "D")

# Row level (line totals) ---------------------------------------------------------------------------------------------
pc <- paste0("pred_", CANDS)
rows <- vp[, c(lapply(.SD, sum), list(exposure = exposure[1])), by = .(row_id, line), .SDcols = c(pc, "raw", "dev")]
feat <- rbindlist(lapply(LINES, function(ln) {
  f <- read_w2(file.path(FEAT_DIR, sprintf("emerging_train_%s.parquet", ln)))[policy_year == 2024]
  f[, .(row_id, policy_id, new_business, channel, age_band = if (ln == "motor") driver_age_band else policyholder_age_band)]
}), fill = TRUE)
rows <- merge(rows, feat, by = "row_id")
# Diagnostic only (not a candidate, uses 2024 actuals): B rescaled so each line x peril total equals the 2024 developed
# actual = the D2 B would score with a perfect level; the gap to B shows how much of the score is level vs ranking.
vp[, pred_Bor := pred_B * fifelse(sum(pred_B) > 0, sum(dev) / sum(pred_B), 1), by = .(line, peril)]
rows <- merge(rows, vp[, .(pred_Bor = sum(pred_Bor)), by = row_id], by = "row_id")
CANDS <- c(CANDS, "Bor")
# Reweighting to the 2025 test mix: new business x channel cells per line (exposure shares)
test_mix <- rbindlist(lapply(LINES, function(ln) read_w2(file.path(FEAT_DIR, sprintf("emerging_test_%s.parquet", ln)))[
  , .(e = sum(exposure)), by = .(new_business, channel)][, `:=`(line = ln, s_test = e / sum(e))]))
cell <- rows[, .(e = sum(exposure)), by = .(line, new_business, channel)][, s_2024 := e / sum(e), by = line]
cell <- merge(cell, test_mix[, .(line, new_business, channel, s_test)], by = c("line", "new_business", "channel"), all.x = TRUE)
cell[, w_mix := fifelse(is.na(s_test), 0, s_test / s_2024)]
rows <- merge(rows, cell[, .(line, new_business, channel, w_mix)], by = c("line", "new_business", "channel"))
save_csv(cell, STEP, "reweighting_cells.csv")

d2_const <- function(y, mu, w) { m <- sum(w * y) / sum(w); 1 - sum(w * tweedie_dev(y, mu)) / sum(w * tweedie_dev(y, rep(m, length(y)))) }
score <- function(d, w) {
  rbindlist(lapply(c("raw", "dev"), function(b) rbindlist(lapply(CANDS, function(cn) {
    y <- d[[b]]; p <- d[[paste0("pred_", cn)]]; ww <- d[[w]]
    data.table(basis = fifelse(b == "raw", "reported_raw", "developed"), candidate = cn,
               d2_w1 = d2_exp(y, p, d$exposure, ww), d2_const = d2_const(y, p, ww), pred_vs_actual = sum(ww * p) / sum(ww * y))
  }))))
}
rows[, w_none := 1]
write_w2(rows, file.path(W2$data, "valid_rows", paste0(TAG, ".parquet")))   # row-level 2024 predictions for 13_compare_runs.R
sc <- list()
for (w in c("w_none", "w_mix")) {
  sc[[w]] <- rbind(score(rows, w)[, line := "ALL"], rbindlist(lapply(LINES, function(ln) score(rows[line == ln], w)[, line := ln])))[, weighting := fifelse(w == "w_none", "as_is", "mix_2025")]
}
sc <- rbindlist(sc)
setcolorder(sc, c("weighting", "basis", "line", "candidate"))
save_csv(sc, STEP, "scorecard.csv")

# Paired policy bootstrap: difference vs B of each candidate (ALL lines), both weightings, both bases ---------------------
pol <- unique(rows$policy_id); rows[, pidx := match(policy_id, pol)]
set.seed(SEED)
W <- replicate(NBOOT, tabulate(sample.int(length(pol), length(pol), replace = TRUE), nbins = length(pol)))
boot <- list()
for (w in c("w_none", "w_mix")) for (b in c("raw", "dev")) {
  y <- rows[[b]]; e <- rows$exposure; w0 <- rows[[w]]
  stat <- function(bw) { ww <- w0 * bw[rows$pidx]; vapply(CANDS, function(cn) d2_exp(y, rows[[paste0("pred_", cn)]], e, ww), 1) }
  s0 <- stat(rep(1, length(pol)))
  draws <- apply(W, 2, stat)
  for (cn in setdiff(CANDS, c("B", "Bor"))) {
    dd <- draws["B", ] - draws[cn, ]
    boot[[paste(w, b, cn)]] <- data.table(weighting = fifelse(w == "w_none", "as_is", "mix_2025"), basis = fifelse(b == "raw", "reported_raw", "developed"),
      comparison = paste0("B - ", cn), d2_B = s0[["B"]], d2_other = s0[[cn]], diff = s0[["B"]] - s0[[cn]], boot_se = sd(dd),
      share_B_better = mean(dd > 0), verdict = fifelse(abs(s0[["B"]] - s0[[cn]]) < 2 * sd(dd), "within noise", fifelse(s0[["B"]] > s0[[cn]], "B better", paste(cn, "better"))))
  }
  boot[[paste(w, b, "B_ci")]] <- data.table(weighting = fifelse(w == "w_none", "as_is", "mix_2025"), basis = fifelse(b == "raw", "reported_raw", "developed"),
    comparison = "B (level, 90% interval)", d2_B = s0[["B"]], d2_other = quantile(draws["B", ], 0.05), diff = quantile(draws["B", ], 0.95),
    boot_se = sd(draws["B", ]), share_B_better = NA_real_, verdict = "d2_other = p5, diff = p95")
}
boot <- rbindlist(boot)
save_csv(boot, STEP, "bootstrap.csv")

# Ceiling simulation (as week 1 week1/R/4_check_ceiling.R): if B were the TRUE expected cost, what D2 would a perfect model score?
# Per row x peril: N ~ Poisson(exposure x freq_B), each claim ~ Gamma(mean sev_B, CV of that peril's emerging claim costs).
NSIM <- 20
cv <- clp[, .(cv = sd(cost) / mean(cost)), by = .(line, peril)]
vs <- merge(vp[, .(row_id, line, peril, lam = exposure * freq_B, sev_B, pred_B)], cv, by = c("line", "peril"))
set.seed(SEED)
ceil <- rbindlist(lapply(seq_len(NSIM), function(i) {
  vs[, nn := rpois(.N, lam)]
  vs[, ysim := fifelse(nn > 0, rgamma(.N, shape = nn / cv^2, scale = sev_B * cv^2), 0)]
  r <- vs[, .(y = sum(ysim), p = sum(pred_B)), by = row_id][rows[, .(row_id, exposure, w_mix)], on = "row_id"]
  data.table(sim = i, d2_w1_as_is = d2_exp(r$y, r$p, r$exposure), d2_const_as_is = d2_const(r$y, r$p, rep(1, nrow(r))),
             d2_w1_mix = d2_exp(r$y, r$p, r$exposure, r$w_mix), d2_const_mix = d2_const(r$y, r$p, r$w_mix))
}))
ceil_sum <- ceil[, lapply(.SD, function(x) sprintf("%.4f (p5 %.4f, p95 %.4f)", mean(x), quantile(x, 0.05), quantile(x, 0.95))), .SDcols = !"sim"]
save_csv(ceil, STEP, "ceiling_simulation.csv")

# Calibration of B (developed actuals): A/E by line, peril, new business, channel, age band ----------------------------------
cal <- rbind(
  vp[, .(group = "line x peril", level = paste(line, peril), pred = sum(pred_B), actual = sum(dev), claims = sum(n)), by = .(line, peril)][, .(group, level, pred, actual, claims)],
  rows[, .(group = "line x new_business", pred = sum(pred_B), actual = sum(dev)), by = .(level = paste(line, new_business))],
  rows[, .(group = "line x channel", pred = sum(pred_B), actual = sum(dev)), by = .(level = paste(line, channel))],
  rows[, .(group = "line x age_band", pred = sum(pred_B), actual = sum(dev)), by = .(level = paste(line, age_band))], fill = TRUE)
cal[, ae := actual / pred]
save_csv(cal, STEP, "calibration.csv")

w1 <- sc[basis == "developed" & line == "ALL", .(weighting, candidate, d2_w1, d2_const)]
kl <- c(sprintf("- %s ALL D2 (week 1 protocol / constant-mean), developed actuals: %s.", c("As-is 2024", "2024 reweighted to the 2025 mix"),
                c(paste(w1[weighting == "as_is", sprintf("%s %.4f/%.4f", candidate, d2_w1, d2_const)], collapse = ", "),
                  paste(w1[weighting == "mix_2025", sprintf("%s %.4f/%.4f", candidate, d2_w1, d2_const)], collapse = ", "))),
        sprintf("- Ceiling (perfect model, B as truth, simulated claims): W1 D2 as-is %s; constant-mean as-is %s.", ceil_sum$d2_w1_as_is, ceil_sum$d2_const_as_is),
        sprintf("- Bootstrap (developed, as-is): %s.", paste(boot[weighting == "as_is" & basis == "developed" & startsWith(comparison, "B -"), sprintf("%s %+.4f (2se %.4f) %s", comparison, diff, 2 * boot_se, verdict)], collapse = "; ")))
write_md(list(paste0("# Step 9: validation, emerging 2023 -> 2024 (run ", TAG, ")"), "", paste("Generated", ts_sgt(), "by `week2/R/09_validate_compare.R`."), "", kl, "",
              "## Scorecard", "", "Bor = diagnostic only: B with each line x peril level set to the 2024 actual (uses the answers; not a candidate).", "",
              md_table(sc, 4),
              "## Ceiling: D2 of a perfect model if B were the true risk (20 simulations of claims)", "", md_table(ceil_sum),  "## Bootstrap (ALL, week 1 D2)", "", md_table(boot, 4),
              "## Calibration of B (developed actuals, 2024)", "", md_table(cal, 3), "## Reweighting cells", "", md_table(cell, 3)), STEP, "validate_report.md")
if (TAG == "main") update_step_log("9", "Validation and comparison", kl)
end_script()
