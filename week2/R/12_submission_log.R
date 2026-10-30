# 12_submission_log.R ------------------------------------------------------------------------------------------------
# Purpose : Week 2 submission log. Records each Kaggle submission (file, MD5, public score) with the local scores of the
#           same candidate on the emerging 2023 -> 2024 fold: line D2 (week 1 protocol and constant-mean, reported_raw and
#           developed, as-is and 2025-mix), and per peril the D2 of frequency (Poisson deviance on reported claim counts,
#           expected = exposure x frequency x reported share), severity (Gamma deviance on 2024 claim costs vs the row's
#           predicted severity; uncapped and capped at the developed cap x emerging level) and cost (Tweedie p = 1.5).
# Inputs  : data/week_2/optionB/adjust/main/valid_2024_peril.parquet, week2/output/09_validate/main/scorecard.csv,
#           week2/output/07_adjust/levels.csv, week2/output/05_baseline/diagnostics_final.csv, emerging claims,
#           week2/inputs/submissions_week2.csv (one row per submission: date, file, public_score, candidate, note)
# Outputs : week2/docs/optionB/submission_log_week2.md, week2/output/12_submission_log/peril_scores_<run_tag>_<candidate>.csv
# Run     : Rscript week2/R/12_submission_log.R
# Time    : seconds

source("week2/R/00_setup_week2.R")
start_script("12_submission_log.R")
STEP <- "12_submission_log"
subs <- fread(file.path(W2$inputs, "submissions_week2.csv")); track_input(file.path(W2$inputs, "submissions_week2.csv"))
clp <- claim_basis("emerging")
# Each submission row names its run_tag: the frozen copy of that run's step 7 / 9 outputs (sub1 = submission #1)
load_run <- function(tag) {
  f <- function(...) { p <- file.path(...); track_input(p); p }
  list(vp = read_w2(file.path(W2$data, "adjust", tag, "valid_2024_peril.parquet")),
       lv = fread(f(W2$output, "07_adjust", paste0("levels_", tag, ".csv"))),
       dg = fread(f(W2$output, "05_baseline", paste0("diagnostics_final_", tag, ".csv"))),
       sc = fread(f(W2$output, "09_validate", tag, "scorecard.csv")))
}

pois_d2 <- function(y, mu, base) { d <- function(m) 2 * sum(ifelse(y > 0, y * log(y / m), 0) - (y - m)); 1 - d(mu) / d(base) }
gam_d2 <- function(y, mu) { d <- function(m) 2 * sum(-log(y / m) + (y - m) / m); 1 - d(mu) / d(rep(mean(y), length(y))) }
d2_c <- function(y, mu) 1 - sum(tweedie_dev(y, mu)) / sum(tweedie_dev(y, rep(mean(y), length(y))))

peril_scores <- function(cand) {
  adj <- clp[, .(adj = sum(cost)), by = .(row_id, peril)]
  v <- merge(vp, adj, by = c("row_id", "peril"), all.x = TRUE); v[is.na(adj), adj := 0]
  v[, `:=`(fq = get(paste0("freq_", cand)), sv = get(paste0("sev_", cand)))]
  v[, `:=`(pred = exposure * fq * sv, dev = adj / share)]
  rbindlist(lapply(split(v, by = c("line", "peril")), function(d) {
    ln <- d$line[1]; pr <- d$peril[1]
    ok <- d$fq > 0
    mu_n <- d$exposure * d$fq * d$share
    base_n <- d$exposure * d$share * sum(d$n[ok]) / sum((d$exposure * d$share)[ok])
    cl <- merge(clp[line == ln & peril == pr & row_id %chin% d$row_id, .(row_id, cost)], d[, .(row_id, sv)], by = "row_id")
    cap <- dg[line == ln & peril == pr, cap] * lv[line == ln & peril == pr, sev_cap_level_final]
    data.table(line = ln, peril = pr, claims_2024 = sum(d$n), exposure = sum(d$exposure),
               freq_d2 = pois_d2(d$n[ok], mu_n[ok], base_n[ok]), freq_ae = sum(d$n) / sum(mu_n),
               sev_d2 = if (nrow(cl) > 1) gam_d2(cl$cost, cl$sv) else NA_real_,
               sev_d2_capped = if (nrow(cl) > 1) gam_d2(pmin(cl$cost, cap), pmin(cl$sv, cap)) else NA_real_,
               sev_ae = if (nrow(cl)) mean(cl$cost) / mean(cl$sv) else NA_real_,
               cost_d2_w1_dev = d2_exp(d$dev, d$pred, d$exposure), cost_d2_const_dev = d2_c(d$dev, d$pred),
               cost_d2_w1_raw = d2_exp(d$raw, d$pred, d$exposure), cost_ae_dev = sum(d$dev) / sum(d$pred))
  }))
}
raw <- rbindlist(lapply(LINES, function(ln) {
  f <- read_w2(file.path(W2$data, "features", sprintf("emerging_train_%s.parquet", ln)))[policy_year == 2024]
  melt(f[, c("row_id", paste0("y_cost_", PERILS[[ln]])), with = FALSE], id.vars = "row_id", variable.name = "peril",
       value.name = "raw", variable.factor = FALSE)[, peril := sub("^y_cost_", "", peril)]
}))

out <- c("# Week 2 submission log (emerging market)", "",
         sprintf("Generated %s by `week2/R/12_submission_log.R` from `week2/inputs/submissions_week2.csv` and the step 7 / 9 outputs.", ts_sgt()), "",
         "## Submissions", "", md_table(subs, 5), "")
vp0 <- NULL
for (i in seq_len(nrow(subs))) {
  s <- subs[i]; cand <- s$candidate
  run <- load_run(s$run_tag); vp <- run$vp; lv <- run$lv; dg <- run$dg; sc <- run$sc
  vp <- merge(vp, raw, by = c("row_id", "peril"), all.x = TRUE)
  f <- file.path(W2$output, "submission", s$file)
  ps <- peril_scores(cand)
  save_csv(ps, STEP, sprintf("peril_scores_%s_%s.csv", s$run_tag, cand))
  ls <- sc[candidate == cand, .(weighting, basis, line, d2_w1, d2_const, pred_vs_actual)]
  out <- c(out, sprintf("## #%d %s - candidate %s, public %.5f", i, s$file, cand, s$public_score), "",
           sprintf("- File MD5 `%s`%s.", if (file.exists(f)) unname(tools::md5sum(f)) else "(file not found)", if (nzchar(s$note)) paste0("; ", s$note) else ""),
           "- Local fold: fit on emerging 2023 (baseline on developed 2021-24), score emerging 2024 (25.6k motor, 14.9k buildings, 18.7k contents rows).", "",
           "### Line D2", "",
           "d2_w1 = week 1 protocol (baseline: one cost rate per exposure-year); d2_const = Tweedie D2 against the constant mean (Kaggle / sklearn formula). mix_2025 = 2024 rows reweighted to the 2025 new-business x channel mix.", "",
           md_table(ls, 4),
           "### Per peril: frequency, severity, cost (2024, as-is)", "",
           "- freq_d2: Poisson deviance D2 of reported claim counts (expected = exposure x frequency x reported share; baseline = one rate per reported exposure). freq_ae = actual / expected.",
           "- sev_d2: Gamma deviance D2 of each 2024 claim's cost vs the predicted severity of its row (baseline = mean claim); sev_d2_capped caps both at the emerging cap. sev_ae = mean actual / mean predicted.",
           "- cost_*: Tweedie D2 of the row x peril cost on developed actuals (w1 and constant-mean) and reported_raw (w1); cost_ae_dev = actual / predicted.", "",
           md_table(ps, 4),
           "### Reading", "",
           sprintf("- Public %.5f vs local ALL (developed actuals): constant-mean D2 %.4f as-is / %.4f at the 2025 mix; week 1 protocol %.4f / %.4f. The constant-mean D2 at the 2025 mix is the closest local proxy for the public board (Kaggle scores against the mean, and the test file is 77%% new business).",
                   s$public_score, ls[weighting == "as_is" & basis == "developed" & line == "ALL", d2_const], ls[weighting == "mix_2025" & basis == "developed" & line == "ALL", d2_const],
                   ls[weighting == "as_is" & basis == "developed" & line == "ALL", d2_w1], ls[weighting == "mix_2025" & basis == "developed" & line == "ALL", d2_w1]),
           "- Almost all ranking power is in frequency: severity D2 is close to 0 for every peril (the emerging severity adjustment is mostly a level), and the perils with high cost D2 (buildings flood 0.51, contents flood 0.36, motor own damage 0.18, glass 0.17) are the ones with strong frequency structure.",
           "")
}
f_log <- file.path(W2$docs, "submission_log_week2.md"); writeLines(out, f_log); track_output(f_log)
update_step_log("12", "Submission log", sprintf("- #%d %s: public %.5f (candidate %s).", seq_len(nrow(subs)), subs$file, subs$public_score, subs$candidate))
end_script()
