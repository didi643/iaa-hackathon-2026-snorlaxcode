# 4_peril_lab_wendy07.R -----------------------------------------------------------------------------------------
# Per-peril search lab for WENDY 7 (round 2): one change to ONE peril at a time, judged on the ALL-lines D2 it
# produces when its predictions are swapped into an otherwise unchanged baseline - the score Kaggle uses - not on
# the peril's own D2. Three out-of-time folds: 2022 (fit 2021), 2023 (fit 2021-22), 2024 (fit 2021-23).
# Selection rule (set in week1/R/4_peril_lab_select.R): mean gain over 2023-24 > 0 and no material loss on 2022.
#
# The engine is NOT copied: week1/R/4_models_iterwendy07.R is parsed and run up to its "# 7. Validation" section with the
# C4 settings (chain ladder, excess everywhere, BI no trend) and BAGS (default 1 for screening, so variants and
# baseline are compared at the same bag count). Variants edit the in-memory feature map / Model_Spec / method of
# one peril and are reverted afterwards.
#
# Variants per peril (generated): other method; drop a feature group (admin, finance, weather, history, geography,
# high-cardinality, customer); add long-run address weather (wx_avg_*), customer_age and line-specific extras;
# depth +-1; min_child_weight x0.5 / x2; cap quantile; Tweedie power; severity model; frequency trend on / off.
#
# Run:  LAB_LINES=motor Rscript week1/R/4_peril_lab_wendy07.R          (LAB_PERILS=bodily_injury,theft to restrict)
# Out:  week1/output/4_check_reported/peril_lab/ baseline.rds, results.csv (appended; finished ids are skipped on rerun)

Sys.setenv(IBNR_METHOD = "chain_ladder", IBNR_OVERRIDE = "buildings/subsidence=report_share_days",
           FEATURE_EDITS = "all:voluntary_excess=B", SPEC_EDITS = "motor/bodily_injury:freq_trend=none,sev_trend=none",
           BAGS = Sys.getenv("BAGS", "1"), FINAL_FIT = "0", RUN_TAG = "peril_lab")
W7 <- "week1/R/4_models_iterwendy07.R"
src <- readLines(W7, warn = FALSE)
stop_line <- grep("^# 7\\. Validation", src)[1]
exprs <- parse(W7, keep.source = TRUE)
starts <- vapply(attr(exprs, "srcref"), function(s) as.integer(s[1]), integer(1))
for (e in exprs[starts < stop_line]) eval(e, envir = globalenv())

LAB_DIR <- file.path(PATHS$output, "4_check_reported", "peril_lab")
dir.create(LAB_DIR, recursive = TRUE, showWarnings = FALSE)
LAB_FOLDS <- c(2022L, 2023L, 2024L)
LAB_LINES <- trimws(strsplit(Sys.getenv("LAB_LINES", paste(LINES, collapse = ",")), ",")[[1]])
LAB_PERILS <- trimws(strsplit(Sys.getenv("LAB_PERILS", ""), ",")[[1]])
RES_FILE <- file.path(LAB_DIR, "results.csv")
mix <- fread(METHOD_MIX)[, .(line, peril, method)]
method_of <- function(ln, pr) mix[line == ln & peril == pr, method]
fmap0 <- copy(fmap); spec0 <- copy(spec)

GROUPS <- list(
  admin = c("channel", "payment_method", "days_quote_to_inception", "new_business", "renewal_count", "start_month", "tenure"),
  finance = c("credit_band", "missed_payments_12m"),
  weather = c("hail_days", "wind_exposure_index", "freezing_days", "dry_summer_index", "wildfire_index", "rainfall_mm", "mean_temperature_c"),
  history = c("hist_policy_claims_prev", "hist_customer_claims_other_lines_prev", "prior_claims_5y"),
  geography = c("region", "urban_density"),
  hicard = c("make_model", "occupation"),
  customer = c("marital_status", "household_size", "years_at_address", "policyholder_age", "licence_points"))
ADD <- list(wx_avg = paste0("wx_avg_", WEATHER_VARS), customer_age = "customer_age",
            extra = list(motor = c("household_size", "flood_zone", "elevation_m"), buildings = c("mortgage", "occupation"),
                         contents = c("occupation", "hail_days", "wind_exposure_index")))

# 1. Data and baseline (all lines, 3 folds) ----------------------------------------------------------------------
data_by_line <- lapply(setNames(LINES, LINES), function(ln) load_line(paste0("train_", ln), ln))
fit_pred <- function(ln, pr, mt, vy) {
  dt <- data_by_line[[ln]]
  f <- fit_method(mt, dt[policy_year < vy], clp[line == ln], ln, pr, vy)
  predict_art(f$art, dt[policy_year == vy])
}
base_file <- file.path(LAB_DIR, sprintf("baseline_bags%d.rds", BAGS))
if (file.exists(base_file)) base <- readRDS(base_file) else {
  base <- list()
  for (ln in LINES) for (vy in LAB_FOLDS) {
    va <- data_by_line[[ln]][policy_year == vy]
    k <- paste(ln, vy)
    base[[k]] <- list(e = va$exposure, y = list(), p = list())
    for (pr in PERILS[[ln]]) {
      base[[k]]$y[[pr]] <- va[[paste0("y_cost_", pr)]]
      base[[k]]$p[[pr]] <- fit_pred(ln, pr, method_of(ln, pr), vy)
      log_msg("baseline ", k, " ", pr)
    }
  }
  saveRDS(base, base_file)
}
all_d2 <- function(sub_line = NULL, sub_peril = NULL, sub_pred = NULL) {   # ALL-lines D2 per fold
  vapply(LAB_FOLDS, function(vy) {
    y <- p <- e <- NULL
    for (ln in LINES) {
      b <- base[[paste(ln, vy)]]
      pl <- b$p; if (identical(ln, sub_line)) pl[[sub_peril]] <- sub_pred[[as.character(vy)]]
      y <- c(y, Reduce(`+`, b$y)); p <- c(p, Reduce(`+`, pl)); e <- c(e, b$e)
    }
    oof_d2(y, p, e)
  }, numeric(1))
}
d2_base <- all_d2()
log_msg("Baseline ALL D2 by fold (", paste(LAB_FOLDS, collapse = "/"), "): ", paste(round(d2_base, 5), collapse = " / "))

# 2. Variants ------------------------------------------------------------------------------------------------------
variants_for <- function(ln, pr) {
  mt <- method_of(ln, pr); sp <- spec0[line == ln & peril == pr]
  used <- fmap0[line == ln & peril == pr, unique(column)]
  have <- names(data_by_line[[ln]])
  v <- list(list(id = "method_other", desc = "other method", method = setdiff(c("freq_sev", "tweedie"), mt)))
  for (g in names(GROUPS)) { cols <- intersect(GROUPS[[g]], used)
    if (length(cols)) v[[length(v) + 1]] <- list(id = paste0("drop_", g), desc = paste("drop", paste(cols, collapse = ",")), drop = cols) }
  for (a in c("wx_avg", "customer_age")) { cols <- setdiff(intersect(ADD[[a]], have), used)
    if (length(cols)) v[[length(v) + 1]] <- list(id = paste0("add_", a), desc = paste("add", paste(cols, collapse = ",")), add = cols) }
  cols <- setdiff(intersect(ADD$extra[[ln]], have), used)
  if (length(cols)) v[[length(v) + 1]] <- list(id = "add_extra", desc = paste("add", paste(cols, collapse = ",")), add = cols)
  v <- c(v, list(list(id = "depth_m1", spec = list(freq_max_depth = sp$freq_max_depth - 1)),
                 list(id = "depth_p1", spec = list(freq_max_depth = sp$freq_max_depth + 1)),
                 list(id = "mcw_half", spec = list(freq_min_child_weight = sp$freq_min_child_weight / 2)),
                 list(id = "mcw_double", spec = list(freq_min_child_weight = sp$freq_min_child_weight * 2))))
  for (q in setdiff(c(0.99, 0.995, 0.999), sp$cap_quantile)) v[[length(v) + 1]] <- list(id = paste0("cap_", q), spec = list(cap_quantile = q))
  v[[length(v) + 1]] <- list(id = "freq_trend_flip", spec = list(freq_trend = if (tolower(sp$freq_trend) == "estimate") "none" else "estimate"))
  if (mt == "tweedie") for (tp in setdiff(c(1.3, 1.5, 1.7), sp$tweedie_p)) v[[length(v) + 1]] <- list(id = paste0("tw_p_", tp), spec = list(tweedie_p = tp))
  if (mt == "freq_sev") {
    alt <- if (sp$sev_model == "gamma_gbm") "gamma_glm" else "gamma_gbm"
    v[[length(v) + 1]] <- list(id = paste0("sev_", alt), spec = c(list(sev_model = alt),
      if (alt == "gamma_gbm" && sp$sev_max_depth == 0) list(sev_max_depth = 3, sev_eta = 0.05, sev_min_child_weight = 100)))
    if (sp$sev_model == "gamma_gbm") v[[length(v) + 1]] <- list(id = "sev_depth_p1", spec = list(sev_max_depth = sp$sev_max_depth + 1))
  }
  for (i in seq_along(v)) if (is.null(v[[i]]$desc)) v[[i]]$desc <- paste(names(v[[i]]$spec), unlist(v[[i]]$spec), sep = "=", collapse = ", ")
  v
}
apply_variant <- function(ln, pr, v) {
  fm <- copy(fmap0); sp <- copy(spec0)
  if (!is.null(v$drop)) fm <- fm[!(line == ln & peril == pr & column %in% v$drop)]
  if (!is.null(v$add)) fm <- rbind(fm, data.table(column = v$add, mono_freq = 0L, mono_sev = 0L, peril = pr,
                                                  code = if (method_of(ln, pr) == "tweedie") "B" else "F", line = ln), use.names = TRUE)
  for (k in names(v$spec)) set(sp, i = which(sp$line == ln & sp$peril == pr), j = k,
                               value = if (is.numeric(sp[[k]])) as.numeric(v$spec[[k]]) else as.character(v$spec[[k]]))
  assign("fmap", fm, envir = globalenv()); assign("spec", sp, envir = globalenv())
}
done <- if (file.exists(RES_FILE)) fread(RES_FILE)[, paste(line, peril, id)] else character()
for (ln in LAB_LINES) for (pr in PERILS[[ln]]) {
  if (length(LAB_PERILS) && nzchar(LAB_PERILS[1]) && !pr %in% LAB_PERILS) next
  for (v in variants_for(ln, pr)) {
    if (paste(ln, pr, v$id) %in% done) next
    t0 <- Sys.time()
    apply_variant(ln, pr, v)
    mt <- if (!is.null(v$method)) v$method else method_of(ln, pr)
    out <- tryCatch({
      sp <- setNames(lapply(LAB_FOLDS, function(vy) fit_pred(ln, pr, mt, vy)), LAB_FOLDS)
      d <- all_d2(ln, pr, sp)
      pd <- vapply(seq_along(LAB_FOLDS), function(i) { b <- base[[paste(ln, LAB_FOLDS[i])]]
        oof_d2(b$y[[pr]], sp[[i]], b$e) - oof_d2(b$y[[pr]], b$p[[pr]], b$e) }, numeric(1))
      data.table(line = ln, peril = pr, id = v$id, desc = v$desc, method = mt,
                 d_all_2022 = d[1] - d2_base[1], d_all_2023 = d[2] - d2_base[2], d_all_2024 = d[3] - d2_base[3],
                 d_peril_2022 = pd[1], d_peril_2023 = pd[2], d_peril_2024 = pd[3],
                 seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), error = "")
    }, error = function(e) data.table(line = ln, peril = pr, id = v$id, desc = v$desc, method = mt,
                                      d_all_2022 = NA_real_, d_all_2023 = NA_real_, d_all_2024 = NA_real_,
                                      d_peril_2022 = NA_real_, d_peril_2023 = NA_real_, d_peril_2024 = NA_real_,
                                      seconds = NA_real_, error = conditionMessage(e)))
    assign("fmap", fmap0, envir = globalenv()); assign("spec", spec0, envir = globalenv())
    fwrite(out, RES_FILE, append = file.exists(RES_FILE))
    log_msg(ln, "/", pr, " ", v$id, ": dALL 23-24 ", sprintf("%+.5f", mean(c(out$d_all_2023, out$d_all_2024))),
            ", 2022 ", sprintf("%+.5f", out$d_all_2022), " (", out$seconds, "s)", if (nzchar(out$error)) paste(" ERROR", out$error) else "")
  }
}
log_msg("Lab done: ", RES_FILE)
