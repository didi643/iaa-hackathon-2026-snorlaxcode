# 4_check_reported_w4.R -----------------------------------------------------------------------------------------
# Re-runs the out-of-time validation of a WENDY 4-style script (no final fit, no submission) and scores the SAME
# predictions on three actual bases, so the result can be compared with SAM 2 / SAM 3 (reported) and WENDY 4 (developed):
#   reported_raw  row cost as booked at 31 Dec 2024: incurred - recoveries of non-repudiated claims (y_cost_<peril>),
#                 no outlier limit, no open-claim recovery adjustment  -> same basis as SAM 2 / SAM 3 local D2
#   reported_adj  WENDY 4's claim cost basis (expected recoveries on open claims, single claims limited)
#   developed     reported_adj / report share -> WENDY 4's own validation basis (reproduces its card)
#
# The model code is NOT copied. The source script is parsed and every top-level expression BEFORE its
# "# 7. Validation" section is run, so data, features, settings, seeds and fitting functions are exactly that script's.
# The per-peril method (freq_sev / tweedie) is chosen as in the source script (mean D2 vs developed actuals over the
# folds), so the scored mix is the one that was submitted. Picks on the reported basis are reported alongside.
#
# Run one source script per R session (from the project root):
#   Windows PowerShell:
#     $env:W4_SCRIPT="week1/R/4_models_iterwendy04.R"; $env:CHECK_TAG="wendy04"; Rscript week1/R/4_check_reported_w4.R
#     $env:W4_SCRIPT="week1/R/4_models_iterwendy04_vsam02clean.R"; $env:CHECK_TAG="wendy04_sam02clean"
#     $env:SAM02_REUSE_DATA="1"; $env:SAM02_DATA_DIR="data/week_1/sam02"; Rscript week1/R/4_check_reported_w4.R
#   (SAM02_DATA_DIR = the folder the SAM 2-clean run wrote its cached data to; if the files are missing the source
#    script rebuilds them there. FAST=1 = smoke test with fewer rounds.)
# Outputs: week1/output/4_check_reported/<tag>/ line_scores.csv, peril_scores.csv, chosen_method.csv, row_preds.parquet
# Compare two runs (with a bootstrap noise threshold): week1/R/4_check_reported_compare.R

W4_SCRIPT <- Sys.getenv("W4_SCRIPT", "week1/R/4_models_iterwendy04.R")
CHECK_TAG <- Sys.getenv("CHECK_TAG", tools::file_path_sans_ext(basename(W4_SCRIPT)))
if (!file.exists(W4_SCRIPT)) stop("Script not found: ", W4_SCRIPT)

# 1. Run the source script up to its validation section ---------------------------------------------------------
src <- readLines(W4_SCRIPT, warn = FALSE)
stop_line <- grep("^# 7\\. Validation", src)[1]
if (is.na(stop_line)) stop("Section marker '# 7. Validation' not found in ", W4_SCRIPT)
exprs <- parse(W4_SCRIPT, keep.source = TRUE)
starts <- vapply(attr(exprs, "srcref"), function(s) as.integer(s[1]), integer(1))
pre <- exprs[starts < stop_line]
message("Running ", length(pre), " top-level expressions of ", W4_SCRIPT, " (lines 1-", stop_line - 1, ")")
for (e in pre) eval(e, envir = globalenv())

need <- c("LINES", "PERILS", "VALID_YEARS", "SELECTION", "spec_row", "load_line", "clp", "fit_method", "predict_art",
          "report_share", "d2_tweedie", "norm_gini", "log_msg", "PATHS")
miss <- need[!vapply(need, exists, logical(1))]
if (length(miss)) stop("Not defined by the source script before section 7: ", paste(miss, collapse = ", "))

# Same rule as the source script's section 7
methods_for <- function(ln, pr) {
  if (SELECTION == "freq_sev") return("freq_sev")
  if (SELECTION == "tweedie") return("tweedie")
  if (toupper(spec_row(ln, pr)$challenger_tweedie) == "Y") c("freq_sev", "tweedie") else "freq_sev"
}
BASES <- c("reported_raw", "reported_adj", "developed")
score_bases <- function(p, act, e) {
  rbindlist(lapply(BASES, function(b) {
    y <- act[[b]]
    data.table(basis = b, d2 = d2_tweedie(y, p, e), gini = norm_gini(y, p), pred_vs_actual = sum(p) / sum(y))
  }))
}

# 2. Validation folds: one fit per fold x peril x method, three actual bases -------------------------------------
OUT_DIR <- file.path(PATHS$output, "4_check_reported", CHECK_TAG)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
peril_scores <- list(); rows <- list()
for (ln in LINES) {
  dt <- load_line(paste0("train_", ln), ln)
  clp_ln <- clp[line == ln]
  for (vy in VALID_YEARS) {
    tr <- dt[policy_year < vy]
    va <- dt[policy_year == vy]
    rp <- data.table(valid_year = vy, line = ln, row_id = va$row_id, policy_id = va$policy_id, exposure = va$exposure)
    for (pr in PERILS[[ln]]) {
      raw_col <- paste0("y_cost_", pr)
      if (!raw_col %in% names(va)) stop("Column ", raw_col, " missing in train_", ln)
      adj <- clp_ln[peril == pr, .(a = sum(cost)), by = row_id][va, on = "row_id", a]
      adj[is.na(adj)] <- 0
      act <- list(reported_raw = va[[raw_col]], reported_adj = adj, developed = adj / report_share(ln, pr, va))
      for (b in BASES) set(rp, j = paste0(b, ".", pr), value = act[[b]])
      for (mt in methods_for(ln, pr)) {
        t0 <- Sys.time()
        f <- fit_method(mt, tr, clp_ln, ln, pr, vy)
        p <- predict_art(f$art, va)
        set(rp, j = paste0("pred.", pr, ".", mt), value = p)
        peril_scores[[paste(vy, ln, pr, mt)]] <- score_bases(p, act, va$exposure)[
          , `:=`(valid_year = vy, line = ln, peril = pr, method = mt)]
        log_msg(vy, " ", ln, "/", pr, " ", mt, ": D2 raw ",
                round(peril_scores[[paste(vy, ln, pr, mt)]][basis == "reported_raw", d2], 4), ", developed ",
                round(peril_scores[[paste(vy, ln, pr, mt)]][basis == "developed", d2], 4),
                " (", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s)")
      }
    }
    rows[[paste(vy, ln)]] <- rp
    rm(tr, va); invisible(gc(verbose = FALSE))
  }
  rm(dt, clp_ln); invisible(gc(verbose = FALSE))
}
peril_scores <- rbindlist(peril_scores)
setcolorder(peril_scores, c("valid_year", "line", "peril", "method", "basis"))

# 3. Method per peril: as the source script (developed basis) and, for information, on the reported basis ---------
pick <- function(b) peril_scores[basis == b, .(mean_d2 = mean(d2)), by = .(line, peril, method)][
  order(line, peril, -mean_d2)][, .SD[1], by = .(line, peril)]
chosen <- pick("developed")[, .(line, peril, method, mean_d2_developed = mean_d2)]
chosen_rep <- pick("reported_raw")[, .(line, peril, method_if_picked_on_reported = method)]
chosen <- merge(chosen, chosen_rep, by = c("line", "peril"))
log_msg("Perils whose pick would change on the reported basis: ",
        chosen[method != method_if_picked_on_reported, .N], " of ", nrow(chosen))

# 4. Line and portfolio scores of the chosen mix on every basis -------------------------------------------------------
line_rows <- rbindlist(lapply(rows, function(rp) {
  ln <- rp$line[1]
  out <- rp[, .(valid_year, line, row_id, policy_id, exposure)]
  pred <- 0
  for (pr in PERILS[[ln]]) pred <- pred + rp[[paste0("pred.", pr, ".", chosen[line == ln & peril == pr, method])]]
  out[, pred := pred]
  for (b in BASES) set(out, j = b, value = Reduce(`+`, lapply(PERILS[[ln]], function(pr) rp[[paste0(b, ".", pr)]])))
  out
}))
line_scores <- rbindlist(lapply(BASES, function(b) {
  rbind(line_rows[, .(d2 = d2_tweedie(get(b), pred, exposure), gini = norm_gini(get(b), pred),
                      pred_vs_actual = sum(pred) / sum(get(b))), by = .(valid_year, line)],
        line_rows[, .(line = "ALL", d2 = d2_tweedie(get(b), pred, exposure), gini = norm_gini(get(b), pred),
                      pred_vs_actual = sum(pred) / sum(get(b))), by = valid_year])[, basis := b]
}))
line_scores[, `:=`(iteration = CHECK_TAG, script = W4_SCRIPT)]
setcolorder(line_scores, c("iteration", "basis", "valid_year", "line"))
setorder(line_scores, basis, valid_year, line)

# 5. Outputs ------------------------------------------------------------------------------------------------------------
fwrite(line_scores, file.path(OUT_DIR, "line_scores.csv"))
fwrite(peril_scores, file.path(OUT_DIR, "peril_scores.csv"))
fwrite(chosen, file.path(OUT_DIR, "chosen_method.csv"))
arrow::write_parquet(line_rows, file.path(OUT_DIR, "row_preds.parquet"))   # for week1/R/4_check_reported_compare.R

wide <- dcast(line_scores, basis + valid_year ~ line, value.var = "d2")
setcolorder(wide, c("basis", "valid_year", intersect(c(LINES, "ALL"), names(wide))))
num <- names(wide)[vapply(wide, is.numeric, logical(1)) & names(wide) != "valid_year"]
print(wide[, (num) := lapply(.SD, round, 4), .SDcols = num])
log_msg("Done. ", CHECK_TAG, ": ", OUT_DIR, " (line_scores.csv, peril_scores.csv, chosen_method.csv, row_preds.parquet)")
