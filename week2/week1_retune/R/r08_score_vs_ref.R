# r08_score_vs_ref.R -------------------------------------------------------------------------------------------------
# Purpose : Stage A scoring of a re-tune run against a reference run (default b0_ref): developed D2 by fold and line,
#           paired bootstrap by policy (200 draws), overfitting checks 1-3 of retune_plan.md section 0.4, and the register row.
# Inputs  : week2/week1_retune/output/<tag>/{row_preds.parquet,line_scores.csv} and the same for the reference
# Outputs : week2/week1_retune/output/<tag>/score_vs_<ref>.csv, updates the row of <tag> in docs/retune_register.csv
# Run     : TAG=b1_depth_m1 REF=b0_ref Rscript week2/week1_retune/R/r08_score_vs_ref.R   (optional: BOOT=200, SEED_TAG=<second-seed tag>)
source("week2/R/00_setup_week2.R")
RTROOT <- "week2/week1_retune"; W2$output <- file.path(RTROOT, "output"); W2$docs <- file.path(RTROOT, "docs")
TAG <- Sys.getenv("TAG"); REF <- Sys.getenv("REF", "b0_ref"); BOOT <- as.integer(Sys.getenv("BOOT", "200"))
stopifnot(nzchar(TAG))
rd <- function(t) read_parquet(file.path(W2$output, t, "row_preds.parquet")) |> as.data.table()
a <- rd(TAG); b <- rd(REF)
x <- merge(a[, .(valid_year, line, row_id, policy_id, exposure, y = developed, mu_c = pred)],
           b[, .(valid_year, row_id, mu_r = pred)], by = c("valid_year", "row_id"))
if (nrow(x) != nrow(a) || nrow(x) != nrow(b)) warning("Rows differ between ", TAG, " and ", REF, ": ", nrow(a), " vs ", nrow(b), ", matched ", nrow(x))
d2w <- function(y, mu, e, w) { base <- e * sum(w * y) / sum(w * e); 1 - sum(w * tweedie_dev(y, mu)) / sum(w * tweedie_dev(y, base)) }
groups <- c("ALL", unique(x$line)); folds <- sort(unique(x$valid_year))
point <- rbindlist(lapply(folds, function(f) rbindlist(lapply(groups, function(g) {
  s <- if (g == "ALL") x[valid_year == f] else x[valid_year == f & line == g]
  w <- rep(1, nrow(s)); data.table(fold = f, group = g, d2_c = d2w(s$y, s$mu_c, s$exposure, w), d2_r = d2w(s$y, s$mu_r, s$exposure, w)) }))))
set.seed(SEED)
fold_idx <- lapply(folds, function(f) { s <- x[valid_year == f]; list(s = s, pid = match(s$policy_id, unique(s$policy_id)), n = uniqueN(s$policy_id)) })
draws <- rbindlist(lapply(seq_len(BOOT), function(bb) rbindlist(lapply(seq_along(folds), function(k) {
  fi <- fold_idx[[k]]; w <- tabulate(sample.int(fi$n, fi$n, replace = TRUE), fi$n)[fi$pid]; s <- fi$s
  rbindlist(lapply(groups, function(g) { m <- if (g == "ALL") rep(TRUE, nrow(s)) else s$line == g
    data.table(b = bb, fold = folds[k], group = g, diff = d2w(s$y[m], s$mu_c[m], s$exposure[m], w[m]) - d2w(s$y[m], s$mu_r[m], s$exposure[m], w[m])) })) }))))
mean_draw <- draws[, .(diff = mean(diff)), by = .(b, group)]
res <- merge(point[, .(d2_c = mean(d2_c), d2_r = mean(d2_r)), by = group][, diff := d2_c - d2_r],
             mean_draw[, .(se = sd(diff), win = mean(diff > 0)), by = group], by = "group")
res_f <- merge(point[, diff := d2_c - d2_r], draws[, .(se = sd(diff), win = mean(diff > 0)), by = .(fold, group)], by = c("fold", "group"))
save_csv(rbind(res[, .(fold = "mean", group, d2_c, d2_r, diff, se, win)], res_f[, .(fold = as.character(fold), group, d2_c, d2_r, diff, se, win)]), TAG, sprintf("score_vs_%s.csv", REF))
# peril view for chk2: how many perils gain
pc <- fread(file.path(W2$output, TAG, "peril_scores.csv"))[basis == "developed", .(d2 = mean(d2)), by = .(line, peril)]
pr <- fread(file.path(W2$output, REF, "peril_scores.csv"))[basis == "developed", .(d2r = mean(d2)), by = .(line, peril)]
pp <- merge(pc, pr, by = c("line", "peril"))[, diff := d2 - d2r]
save_csv(pp, TAG, sprintf("peril_diff_vs_%s.csv", REF))
all_ <- res[group == "ALL"]; lines_ <- res[group != "ALL"]
chk1 <- all(res_f[group == "ALL", diff] >= -0.0002)
chk2 <- all(lines_$diff >= -lines_$se) && (sum(pp$diff > 0) >= ceiling(nrow(pp) / 2))
chk3 <- all_$win >= 0.7
gate_a <- all_$diff > 0 && chk1 && chk2 && chk3
cat(sprintf("%s vs %s: ALL D2 %.4f vs %.4f, diff %+.5f (SE %.5f), bootstrap win %.0f%%; folds %s; lines %s; perils gaining %d of %d\n  chk1 %s chk2 %s chk3 %s -> gate A %s\n",
            TAG, REF, all_$d2_c, all_$d2_r, all_$diff, all_$se, 100 * all_$win,
            paste(sprintf("%s %+.5f", res_f[group == "ALL", fold], res_f[group == "ALL", diff]), collapse = ", "),
            paste(sprintf("%s %+.5f (SE %.5f)", lines_$group, lines_$diff, lines_$se), collapse = ", "), sum(pp$diff > 0), nrow(pp), chk1, chk2, chk3, gate_a))
# register row
regf <- file.path(W2$docs, "retune_register.csv")
if (file.exists(regf) && REF == "b0_ref") {   # register always holds the comparison with b0_ref
  reg <- fread(regf, colClasses = "character"); i <- which(reg$tag == TAG)
  if (length(i) == 1) {
    ls <- fread(file.path(W2$output, TAG, "line_scores.csv"))[basis == "developed"]
    g <- function(l, yr = NULL) { s <- ls[line == l]; if (is.null(yr)) mean(s$d2) else s[valid_year == yr, d2] }
    set(reg, i, c("run_date", "dev_d2_all", "dev_d2_all_2023", "dev_d2_all_2024", "dev_d2_motor", "dev_d2_buildings", "dev_d2_contents", "dev_diff_vs_ref", "dev_se", "dev_boot_win_share",
                  "chk1_folds_agree", "chk2_broad", "chk3_boot70", "gate_a"),
        as.list(c(format(Sys.Date()), sprintf("%.4f", c(g("ALL"), g("ALL", 2023), g("ALL", 2024), g("motor"), g("buildings"), g("contents"))), sprintf("%.5f", all_$diff), sprintf("%.5f", all_$se),
                  sprintf("%.2f", all_$win), chk1, chk2, chk3, if (reg$group[i] == "B0") "info" else if (gate_a) "pass" else "fail")))
    if (reg$group[i] == "B0") set(reg, i, "decision", "info") else set(reg, i, "decision", if (gate_a) "carry" else "reject")
    set(reg, i, "evidence", sprintf("week2/week1_retune/output/%s/score_vs_%s.csv", TAG, REF))
    fwrite(reg, regf)
  }
}
