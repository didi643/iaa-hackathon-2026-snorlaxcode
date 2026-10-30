# 4_models_iterwendy05.R -----------------------------------------------------------------------------------------
# WENDY 5: WENDY 4's actuarial basis + tuned XGBoost per component + method choice on policy-grouped cross-validation.
#
#   1. Tuning      per peril and component (frequency Poisson GBM, severity Gamma GBM, Tweedie GBM), random search over
#                  the Tuning_Grid sheet on ONE policy-grouped fold of 2021-24 (fold `tune_fold`), scored by the
#                  component's own deviance. Config 1 = the Model_Spec default, so the tuning gain is measured.
#                  Severity: tuned GBM vs Gamma GLM, the lower holdout deviance wins (Model_Spec sev_model = auto).
#   2. Grouped CV  K folds by policy over all training years with the tuned settings -> out-of-fold row cost for both
#                  methods, scored (Tweedie D2) against developed actuals; method chosen per peril on this score.
#                  Component out-of-fold deviances are saved for the WENDY 6 (H2O AutoML) comparison - same folds.
#   3. Time check  fit 2021-23, score 2024 vs developed actuals (same fold as WENDY 4 - level / trend check).
#   4. Final       fit 2021-24, predict 2025 -> submission + per-peril test predictions for the comparison script.
#
# Run:   Rscript week1/R/4_models_iterwendy05.R            (long: hours; see the model card for timings)
#        FAST=1 Rscript week1/R/4_models_iterwendy05.R     (smoke test: 3 configs, 3 folds, 200 rounds)
# Needs: week1/R/0_setup.R, week1/R/wendy_core.R, week1/docs/assumptions_wendy05.xlsx, data/week_1/clean/* (week1/R/2_clean.R), xgboost >= 3.0, readxl.

source("week1/R/0_setup.R")
CFG_FILE <- Sys.getenv("ASSUMPTIONS_XLSX", "week1/docs/assumptions_wendy05.xlsx")
for (p in c("xgboost", "readxl")) if (!requireNamespace(p, quietly = TRUE)) stop("Install package '", p, "'")
suppressPackageStartupMessages(library(xgboost))

ITERATION <- "WENDY 5"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITER_DIR <- file.path("week1", "models", "wendy_iteration_05")
FAST <- Sys.getenv("FAST", "0") == "1"
T0 <- Sys.time()

# --- FUNCTIONS ---
# wendy_core.R ------------------------------------------------------------------------------------------------
# Shared building blocks for WENDY 5 and WENDY 6 (same actuarial basis as WENDY 4, made year-aware so one fitted
# model can be scored on any year: claims are trended to the last training year and predictions are scaled to the
# row's own policy year). Source AFTER week1/R/0_setup.R and after setting CFG_FILE.
#
#   wc_config()            read the assumption workbook -> settings, Model_Spec, feature map, structural zeros
#   wc_claims()            claim cost basis (net of recoveries, expected recoveries on open claims, outlier limit)
#   wc_report_share()      share of ultimate claims reported by the valuation date (per peril, by row mid-date)
#   wc_load_line()         clean table + prior-year history features (known at renewal)
#   wc_zero_mask()         structural zeros (applied only where training has no claims)
#   wc_peril_data()        rows, counts, IBNR volume, capped/trended claims, cap loading, severity trend
#   wc_policy_folds()      policy-grouped fold ids, identical in every iteration for the same policies
#   wc_* metrics           Tweedie D2 (Kaggle), Gini, Poisson / Gamma deviance
# Version 1 (WENDY 5/6). Freeze with the iterations that use it; copy to wendy_core_v2.R for material changes.

suppressPackageStartupMessages(library(readxl))

# Workbook ---------------------------------------------------------------------------------------------------------
wc_config <- function(cfg_file) {
  if (!file.exists(cfg_file)) stop("Assumption workbook not found: ", cfg_file)
  rd <- function(sheet) {
    x <- as.data.table(read_excel(cfg_file, sheet = sheet, col_types = "text"))
    x[!is.na(x[[1]])]
  }
  st <- rd("Settings")
  S <- setNames(st$value, st$key)
  spec <- rd("Model_Spec")[line %in% LINES]
  num_cols <- intersect(c("cap_quantile", "sev_exclude_recent_years", "freq_max_depth", "freq_eta",
                          "freq_min_child_weight", "sev_max_depth", "sev_eta", "sev_min_child_weight", "tweedie_p"),
                        names(spec))
  spec[, (num_cols) := lapply(.SD, as.numeric), .SDcols = num_cols]
  need <- unlist(lapply(LINES, function(ln) paste(ln, PERILS[[ln]])))
  miss <- setdiff(need, spec[, paste(line, peril)])
  if (length(miss)) stop("Model_Spec has no row for: ", paste(miss, collapse = ", "))
  fmap <- rbindlist(lapply(LINES, function(ln) {
    sh <- paste0("Features_", tools::toTitleCase(ln))
    x <- rd(sh)
    miss <- setdiff(c("column", "use", "mono_freq", "mono_sev", PERILS[[ln]]), names(x))
    if (length(miss)) stop(sh, " lacks columns: ", paste(miss, collapse = ", "))
    x <- x[toupper(trimws(use)) == "Y", c("column", "mono_freq", "mono_sev", PERILS[[ln]]), with = FALSE]
    long <- melt(x, id.vars = c("column", "mono_freq", "mono_sev"), variable.name = "peril", value.name = "code",
                 variable.factor = FALSE)
    long[, `:=`(line = ln, code = toupper(trimws(code)))][code %in% c("B", "F", "S")]
  }))
  fmap[, `:=`(mono_freq = as.integer(fifelse(is.na(mono_freq), "0", mono_freq)),
              mono_sev = as.integer(fifelse(is.na(mono_sev), "0", mono_sev)))]
  sheets <- excel_sheets(cfg_file)
  list(file = cfg_file, S = S, spec = spec, fmap = fmap,
       zero_rules = rd("Structural_Zeros")[line %in% LINES],
       tuning = if ("Tuning_Grid" %in% sheets) rd("Tuning_Grid") else NULL)
}
s_get <- function(k) {
  if (!k %in% names(CFG$S) || is.na(CFG$S[[k]])) stop("Setting '", k, "' missing in ", CFG$file)
  CFG$S[[k]]
}
s_num <- function(k) {
  v <- suppressWarnings(as.numeric(s_get(k)))
  if (is.na(v)) stop("Setting '", k, "' is not numeric")
  v
}
s_vec <- function(k) trimws(strsplit(s_get(k), ",", fixed = TRUE)[[1]])
s_yes <- function(k) toupper(s_get(k)) == "Y"
spec_row <- function(ln, pr) CFG$spec[line == ln & peril == pr][1]
feats_for <- function(ln, pr, part) {
  codes <- switch(part, freq = c("F", "B"), sev = c("S", "B"), all = c("F", "S", "B"))
  f <- unique(CFG$fmap[line == ln & peril == pr & code %in% codes, column])
  if (!s_yes("history_features")) f <- f[!startsWith(f, "hist_")]
  f
}
mono_for <- function(ln, pr, feats, part) {
  col <- if (part == "sev") "mono_sev" else "mono_freq"
  m <- CFG$fmap[line == ln & peril == pr][match(feats, column)][[col]]
  m[is.na(m)] <- 0L
  m
}

# Claims basis ---------------------------------------------------------------------------------------------------
wc_claims <- function() {
  cm <- read_clean("claims_matched")
  cl <- cm[counts == TRUE & !is.na(row_id)]
  rm(cm)
  cl[, cost := net_cost]                                   # incurred - recoveries
  rec <- cl[status == "closed", .(closed_claims = .N, recovery_ratio = sum(recoveries) / sum(incurred_to_date)),
            by = .(line, peril)][recovery_ratio > 0]
  if (s_yes("open_claim_recovery_adjust") && nrow(rec)) {
    cl[rec, on = .(line, peril), rr := i.recovery_ratio]
    cl[status == "open" & !is.na(rr) & recoveries == 0, cost := incurred_to_date * (1 - rr)]
    cl[, rr := NULL]
  }
  lim <- s_num("outlier_claim_limit")
  n_out <- cl[cost > lim, .N]
  cl[, cost := pmin(pmax(cost, 0), lim)]
  clp <- cl[cost > 0, .(row_id, line, peril, status, cost, loss_date, report_date,
                        loss_year = data.table::year(loss_date), lag = as.numeric(report_date - loss_date))]
  # reporting pattern per peril (ECDF of report lags of the lag_loss_years)
  lag_years <- as.integer(s_vec("lag_loss_years"))
  cdf <- list()
  for (ln in LINES) for (pr in PERILS[[ln]]) {
    lags <- clp[line == ln & peril == pr & loss_year %in% lag_years & lag >= 0, lag]
    cdf[[paste(ln, pr)]] <- if (length(lags) >= 30) ecdf(lags) else function(x) rep(1, length(x))
  }
  list(clp = clp, recovery = rec, n_outlier = n_out, lag_cdf = cdf)
}
wc_report_share <- function(ln, pr, dt) {
  mid <- as.numeric(dt$period_start) + as.numeric(dt$period_end - dt$period_start) / 2
  pmax(CLM$lag_cdf[[paste(ln, pr)]](as.numeric(VALUATION_DATE) - mid), 0.05)
}

# History features (prior-year claims reported by the end of that year) --------------------------------------------
wc_history_index <- function() {
  id_cols <- c("row_id", "policy_id", "customer_id", "policy_year")
  rowmap <- rbindlist(lapply(LINES, function(ln) {
    f <- file.path(PATHS$clean, paste0("train_", ln, ".parquet"))
    if (file.exists(f)) as.data.table(arrow::read_parquet(f, col_select = id_cols))
    else read_clean(paste0("train_", ln))[, ..id_cols]
  }))
  hc <- merge(CLM$clp[data.table::year(report_date) <= loss_year, .(row_id, line, hist_year = loss_year)],
              rowmap[, .(row_id, policy_id, customer_id)], by = "row_id")
  list(pol = hc[, .(n = .N), by = .(policy_id, hist_year)],
       cust = hc[, .(n = .N), by = .(customer_id, line, hist_year)],
       pol_year = unique(rowmap[, paste(policy_id, policy_year)]))
}
wc_add_history <- function(dt, ln) {
  dt[, hist_year := policy_year - 1L]
  dt[HIST$pol, on = .(policy_id, hist_year), hist_policy_claims_prev := as.numeric(i.n)]
  dt[is.na(hist_policy_claims_prev), hist_policy_claims_prev := 0]
  dt[!paste(policy_id, hist_year) %chin% HIST$pol_year | hist_year < min(TRAIN_YEARS), hist_policy_claims_prev := NA]
  oc <- HIST$cust[line != ln, .(n = sum(n)), by = .(customer_id, hist_year)]
  dt[oc, on = .(customer_id, hist_year), hist_customer_claims_other_lines_prev := as.numeric(i.n)]
  dt[is.na(hist_customer_claims_other_lines_prev), hist_customer_claims_other_lines_prev := 0]
  dt[hist_year < min(TRAIN_YEARS), hist_customer_claims_other_lines_prev := NA]
  dt[, hist_year := NULL]
  invisible(dt)
}
wc_load_line <- function(name, ln) {
  dt <- read_clean(name)
  if (s_yes("history_features")) wc_add_history(dt, ln)
  miss <- setdiff(CFG$fmap[line == ln, unique(column)], names(dt))
  if (s_yes("history_features") == FALSE) miss <- miss[!startsWith(miss, "hist_")]
  if (length(miss)) stop(name, ": workbook features not in data: ", paste(miss, collapse = ", "))
  dt
}

# Structural zeros --------------------------------------------------------------------------------------------------
wc_rule_mask <- function(dt, rules) {
  m <- rep(FALSE, nrow(dt))
  for (i in seq_len(nrow(rules))) {
    vals <- toupper(trimws(strsplit(rules$values[i], ",", fixed = TRUE)[[1]]))
    m <- m | toupper(as.character(dt[[rules$column[i]]])) %chin% vals
  }
  m
}
wc_zero_check <- function() {
  out <- rbindlist(lapply(LINES, function(ln) {
    rules <- CFG$zero_rules[line == ln]
    if (!nrow(rules)) return(NULL)
    dt <- read_clean(paste0("train_", ln))
    rbindlist(lapply(seq_len(nrow(rules)), function(i) {
      r <- rules[i]
      if (!r$column %in% names(dt)) return(r[, .(line, peril, column, values, rows = NA_integer_, claims = NA_integer_, active = FALSE)])
      m <- wc_rule_mask(dt, r)
      n_cl <- CLM$clp[line == ln & peril == r$peril & row_id %chin% dt$row_id[m], .N]
      r[, .(line, peril, column, values, rows = sum(m), claims = n_cl, active = n_cl == 0 & sum(m) > 0)]
    }))
  }))
  if (nrow(out) && nrow(out[active == FALSE]))
    warning("Structural-zero rules NOT applied (claims found): ", paste(out[active == FALSE, paste(line, peril, column)], collapse = "; "))
  out
}
wc_zero_mask <- function(dt, ln, pr) {
  rules <- ZERO[line == ln & peril == pr & active == TRUE]
  if (!nrow(rules)) rep(FALSE, nrow(dt)) else wc_rule_mask(dt, rules)
}

# Trend and peril data ------------------------------------------------------------------------------------------
clamp <- function(x, lim) min(max(x, lim[1]), lim[2])
loglin_trend <- function(yr, value, w) {
  ok <- value > 0 & w > 0
  if (length(unique(yr[ok])) < 2) return(0)
  exp(unname(coef(lm(log(value[ok]) ~ yr[ok], weights = w[ok]))[2])) - 1
}
# All modelling inputs of one peril for training rows tr. Claims are trended to base_year (last training year);
# predictions are scaled by (1 + sev_trend)^(year - base_year) at scoring time.
wc_peril_data <- function(tr, ln, pr) {
  sp <- spec_row(ln, pr)
  d <- tr[!wc_zero_mask(tr, ln, pr)]
  cp <- CLM$clp[line == ln & peril == pr & row_id %chin% d$row_id]
  ty <- sort(unique(d$policy_year))
  base_year <- max(ty)
  ex <- sp$sev_exclude_recent_years
  sev_years <- if (ex > 0 && length(ty) > ex) head(ty, length(ty) - ex) else ty
  cp[, in_sev := loss_year %in% sev_years]
  if (cp[in_sev == TRUE, .N] < 10) cp[, in_sev := TRUE]
  if (!nrow(cp)) stop("No positive claims for ", ln, "/", pr, " in the training window")
  base <- cp[in_sev == TRUE]
  cap0 <- quantile(base$cost, sp$cap_quantile, names = FALSE)
  g <- 0
  if (tolower(sp$sev_trend) == "estimate") {
    a <- base[, .(m = mean(pmin(cost, cap0)), n = .N), by = loss_year]
    g <- clamp(loglin_trend(a$loss_year, a$m, a$n), c(s_num("sev_trend_min"), s_num("sev_trend_max")))
  }
  cp[, cost_t := cost * (1 + g)^(base_year - loss_year)]
  cap <- quantile(cp[in_sev == TRUE, cost_t], sp$cap_quantile, names = FALSE)
  cp[, capped := pmin(cost_t, cap)]
  n <- cp[, .N, by = row_id][d, on = "row_id", N]; n[is.na(n)] <- 0
  y <- cp[, .(y = sum(capped)), by = row_id][d, on = "row_id", y]; y[is.na(y)] <- 0
  sv <- d[cp[in_sev == TRUE, .(row_id, capped)], on = "row_id"]
  list(spec = sp, d = d, n = n, y = y, eff = d$exposure * wc_report_share(ln, pr, d), sv = sv,
       base_year = base_year, sev_trend = g, cap = cap, load = cp[in_sev == TRUE, sum(cost_t) / sum(capped)],
       sev_years = sev_years)
}
# Residual frequency trend after a model: log(actual / expected) by policy year, clamped; 0 when the spec says none.
# actual / expected are row vectors aligned with pd$d (counts for frequency, capped cost for Tweedie).
wc_freq_trend <- function(pd, actual, expected) {
  mid <- weighted.mean(pd$d$policy_year, pd$eff)
  if (tolower(pd$spec$freq_trend) != "estimate") return(list(g = 0, mid = mid))
  a <- data.table(y = actual, mu = expected, yr = pd$d$policy_year)[, .(ae = sum(y) / sum(mu), n = sum(y > 0)), by = yr]
  list(g = clamp(loglin_trend(a$yr, a$ae, a$n), c(s_num("freq_trend_min"), s_num("freq_trend_max"))), mid = mid)
}
# Targets of other rows (holdout / out-of-fold) on the SAME basis as a training peril_data (its cap and trend)
wc_targets_for <- function(pd, rows, ln, pr) {
  d <- rows[!wc_zero_mask(rows, ln, pr)]
  cp <- CLM$clp[line == ln & peril == pr & row_id %chin% d$row_id]
  cp[, capped := pmin(cost * (1 + pd$sev_trend)^(pd$base_year - loss_year), pd$cap)]
  n <- cp[, .N, by = row_id][d, on = "row_id", N]; n[is.na(n)] <- 0
  y <- cp[, .(y = sum(capped)), by = row_id][d, on = "row_id", y]; y[is.na(y)] <- 0
  list(d = d, n = n, y = y, eff = d$exposure * wc_report_share(ln, pr, d), sv = d[cp[, .(row_id, capped, loss_year)], on = "row_id"])
}
# Developed actual cost of rows (uncapped, after the outlier limit) / reported share: the validation target
wc_developed <- function(rows, ln, pr) {
  a <- CLM$clp[line == ln & peril == pr, .(a = sum(cost)), by = row_id][rows, on = "row_id", a]
  a[is.na(a)] <- 0
  list(act = a, dev = a / wc_report_share(ln, pr, rows))
}
year_factor <- function(g, years, ref) (1 + g)^(years - ref)

# Folds grouped by policy: same assignment for the same policy universe in every iteration -------------------------
wc_policy_folds <- function(policy_id, k, seed = SEED) {
  u <- sort(unique(policy_id))
  set.seed(seed)
  f <- sample(rep_len(seq_len(k), length(u)))
  f[match(policy_id, u)]
}

# Metrics ------------------------------------------------------------------------------------------------------------
wc_tweedie_dev <- function(y, mu, p) {
  mu <- pmax(mu, 1e-6)
  2 * mean(base::ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
wc_d2 <- function(y, pred, exposure, p) 1 - wc_tweedie_dev(y, pred, p) / wc_tweedie_dev(y, exposure * sum(y) / sum(exposure), p)
wc_gini <- function(y, s) {
  g <- function(a, s) { a <- a[order(s, decreasing = TRUE)]; n <- length(a); sum(cumsum(a) / sum(a) - seq_len(n) / n) / n }
  g(y, s) / g(y, y)
}
wc_poisson_dev <- function(n, mu) { mu <- pmax(mu, 1e-10); 2 * mean(base::ifelse(n > 0, n * log(n / mu), 0) - (n - mu)) }
wc_gamma_dev <- function(y, mu) { mu <- pmax(mu, 1e-6); 2 * mean(-log(y / mu) + (y - mu) / mu) }

# GLM severity helpers ------------------------------------------------------------------------------------------------
wc_glm_prep <- function(sdat, feats) {
  min_claims <- s_num("glm_min_level_claims"); glm_log <- s_vec("glm_log_features")
  out <- list()
  for (f in feats) {
    v <- sdat[[f]]
    if (is.character(v) || is.logical(v) || is.factor(v)) {
      v <- as.character(v); v[is.na(v)] <- "missing"
      tab <- sort(table(v), decreasing = TRUE)
      keep <- names(tab)[tab >= min_claims]
      if (!length(keep)) next
      levels <- c(keep, if (any(!v %in% keep)) "other")
      if (length(levels) >= 2) out[[f]] <- list(kind = "cat", keep = keep, levels = levels)
    } else {
      v <- as.numeric(v)
      med <- median(v, na.rm = TRUE); if (is.na(med)) next
      lg <- f %in% glm_log
      x <- if (lg) log1p(pmax(fifelse(is.na(v), med, v), 0)) else fifelse(is.na(v), med, v)
      if (isTRUE(stats::sd(x) > 0)) out[[f]] <- list(kind = "num", med = med, log = lg)
    }
  }
  out
}
wc_glm_frame <- function(prep, nd) {
  cols <- lapply(names(prep), function(f) {
    p <- prep[[f]]
    if (p$kind == "cat") {
      v <- as.character(nd[[f]]); v[is.na(v)] <- "missing"
      v[!v %in% p$keep] <- if ("other" %in% p$levels) "other" else p$keep[1]
      factor(v, levels = p$levels)
    } else {
      v <- as.numeric(nd[[f]]); v[is.na(v)] <- p$med
      if (p$log) log1p(pmax(v, 0)) else v
    }
  })
  setNames(as.data.frame(cols), names(prep))
}
wc_glm_fit <- function(sv, feats) {
  prep <- wc_glm_prep(sv, feats)
  if (!length(prep)) return(NULL)
  fr <- wc_glm_frame(prep, sv); fr$y__ <- sv$capped
  g <- tryCatch(glm(y__ ~ ., data = fr, family = Gamma(link = "log"), mustart = rep(mean(fr$y__), nrow(fr)),
                    control = glm.control(maxit = 100)), error = function(e) NULL)
  if (is.null(g) || !g$converged) return(NULL)
  tv <- summary(g)$coefficients
  imp <- data.table(term = rownames(tv), t = abs(tv[, 3]))[term != "(Intercept)"]
  imp[, feature := vapply(term, function(t) names(prep)[which(startsWith(t, names(prep)))[1]], character(1))]
  imp <- imp[, .(importance = sum(t)), by = feature]
  g$data <- NULL; g$model <- NULL
  list(prep = prep, model = g, bal = sum(fr$y__) / sum(fitted(g)), importance = imp)
}
wc_glm_predict <- function(gf, nd) unname(predict(gf$model, newdata = wc_glm_frame(gf$prep, nd), type = "response")) * gf$bal

# Standard comparison outputs (read by week1/R/5_compare_iterations.R) ----------------------------------------------------
# peril_scores: iteration, scheme, line, peril, method, d2, gini, pred_vs_developed
# component_cv: iteration, line, peril, part, metric, value, n, model
# importance:   iteration, line, peril, part, feature, share
wc_write_comparison <- function(dir, peril_scores = NULL, line_scores = NULL, component_cv = NULL, importance = NULL,
                                changes = NULL) {
  cd <- file.path(dir, "comparison")
  dir.create(cd, recursive = TRUE, showWarnings = FALSE)
  if (!is.null(peril_scores)) fwrite(peril_scores, file.path(cd, "peril_scores.csv"))
  if (!is.null(line_scores)) fwrite(line_scores, file.path(cd, "line_scores.csv"))
  if (!is.null(component_cv)) fwrite(component_cv, file.path(cd, "component_cv.csv"))
  if (!is.null(importance)) fwrite(importance, file.path(cd, "importance.csv"))
  if (!is.null(changes)) writeLines(changes, file.path(cd, "changes.txt"))
}
# Line and portfolio D2 from per-peril predictions and developed actuals (list of data.tables with line, pred, dev, exposure)
wc_line_scores <- function(parts, iteration, scheme) {
  p <- rbindlist(parts)
  rbind(p[, .(d2 = wc_d2(dev, pred, exposure, SCORE_P), gini = wc_gini(dev, pred), pred_vs_developed = sum(pred) / sum(dev)), by = line],
        p[, .(line = "ALL", d2 = wc_d2(dev, pred, exposure, SCORE_P), gini = wc_gini(dev, pred), pred_vs_developed = sum(pred) / sum(dev))]
  )[, `:=`(iteration = iteration, scheme = scheme)]
}

# ------

CFG <- wc_config(CFG_FILE)
SCORE_P <- s_num("score_tweedie_p")
MODE <- tolower(s_get("validation_mode")); stopifnot(MODE %in% c("group_cv", "time", "both"))
K <- if (FAST) 3L else as.integer(s_num("cv_folds"))
TUNE_FOLD <- as.integer(s_num("tune_fold"))
TUNE_N <- if (FAST) 3L else as.integer(s_num("tune_configs"))
TIME_YEAR <- as.integer(s_num("time_check_year"))
MAX_ROUNDS <- if (FAST) 200 else s_num("max_rounds")
ETA_MULT <- if (FAST) 2 else 1
ES_ROUNDS <- s_num("early_stopping_rounds")
HOLD_SHARE <- s_num("holdout_share")
NTHREAD <- as.integer(s_num("nthread")); if (NTHREAD <= 0) NTHREAD <- max(1L, parallel::detectCores())
MIN_SEV_CLAIMS <- 200
stopifnot(TUNE_FOLD >= 1, TUNE_FOLD <= K)

CLM <- wc_claims()
HIST <- wc_history_index()
ZERO <- wc_zero_check()
log_msg(ITERATION, " | workbook ", CFG_FILE, " | mode ", MODE, " | ", K, " folds | ", TUNE_N, " configs",
        if (FAST) " [FAST]" else "")

# Tuning grid ------------------------------------------------------------------------------------------------------
grid <- CFG$tuning
if (is.null(grid)) stop("Sheet Tuning_Grid missing in ", CFG_FILE)
grid_vals <- function(pt, pm) {
  v <- grid[tolower(part) == pt & param == pm, values]
  if (!length(v)) return(NULL)
  as.numeric(trimws(strsplit(v[1], ",", fixed = TRUE)[[1]]))
}
default_cfg <- function(sp, part) {
  pre <- if (part == "sev") "sev" else "freq"
  list(max_depth = sp[[paste0(pre, "_max_depth")]], eta = sp[[paste0(pre, "_eta")]],
       min_child_weight = sp[[paste0(pre, "_min_child_weight")]], subsample = s_num("subsample"),
       colsample_bytree = s_num("colsample_bytree"), reg_lambda = s_num("reg_lambda"),
       tweedie_p = sp$tweedie_p)
}
config_list <- function(sp, part, seed) {
  def <- default_cfg(sp, part)
  if (part == "sev" && (is.na(def$max_depth) || def$max_depth <= 0)) def <- modifyList(def, list(max_depth = 3, eta = 0.05, min_child_weight = 100))
  out <- list(def)
  set.seed(seed)
  params <- c("max_depth", "eta", "min_child_weight", "subsample", "colsample_bytree", "reg_lambda",
              if (part == "tweedie") "tweedie_p")
  for (i in seq_len(max(0, TUNE_N - 1))) {
    cfg <- def
    for (p in params) { v <- grid_vals(part, p); if (length(v)) cfg[[p]] <- v[sample.int(length(v), 1)] }
    out[[length(out) + 1]] <- cfg
  }
  unique(out)
}

# XGBoost helpers -------------------------------------------------------------------------------------------------
make_enc <- function(dt, feats, y, w) {
  is_cat <- vapply(feats, function(f) is.character(dt[[f]]) || is.factor(dt[[f]]), logical(1))
  lv <- lapply(setNames(feats[is_cat], feats[is_cat]), function(f) {
    tb <- data.table(x = as.character(dt[[f]]), y = y, w = w)[, .(rate = sum(y) / sum(w)), by = x]
    tb[order(rate, x), x]
  })
  list(feats = feats, lv = lv)
}
to_mat <- function(enc, d) {
  m <- matrix(NA_real_, nrow(d), length(enc$feats), dimnames = list(NULL, enc$feats))
  for (j in seq_along(enc$feats)) {
    f <- enc$feats[j]
    m[, j] <- if (!is.null(enc$lv[[f]])) match(as.character(d[[f]]), enc$lv[[f]]) else as.numeric(d[[f]])
  }
  m
}
xgb_fit <- function(X, label, w, pid, objective, cfg, mono, seed, extra = list()) {
  set.seed(seed)
  u <- unique(pid); hold <- pid %chin% sample(u, max(1L, round(HOLD_SHARE * length(u))))
  dtr <- xgb.DMatrix(X[!hold, , drop = FALSE], label = label[!hold], weight = w[!hold], nthread = NTHREAD)
  dva <- xgb.DMatrix(X[hold, , drop = FALSE], label = label[hold], weight = w[hold], nthread = NTHREAD)
  params <- c(list(objective = objective, learning_rate = cfg$eta * ETA_MULT, max_depth = cfg$max_depth,
                   min_child_weight = cfg$min_child_weight, subsample = cfg$subsample,
                   colsample_bytree = cfg$colsample_bytree, reg_lambda = cfg$reg_lambda,
                   tree_method = "hist", nthread = NTHREAD, seed = seed), extra)
  if (any(mono != 0)) params$monotone_constraints <- paste0("(", paste(mono, collapse = ","), ")")
  xgb.train(params = params, data = dtr, nrounds = MAX_ROUNDS, evals = list(holdout = dva),
            early_stopping_rounds = ES_ROUNDS, verbose = 0)
}
rounds_of <- function(m) { b <- xgb.attr(m, "best_iteration"); if (is.null(b)) NA_integer_ else as.integer(b) }
mono_enc <- function(enc, ln, pr, part) { m <- mono_for(ln, pr, enc$feats, part); m[enc$feats %in% names(enc$lv)] <- 0L; m }
gain_of <- function(m) { im <- as.data.table(xgb.importance(model = m)); im[, .(feature = Feature, importance = Gain)] }

# Components (each returns an object that predicts on any rows) -----------------------------------------------------
fit_freq <- function(pd, cfg, ln, pr, seed) {
  enc <- make_enc(pd$d, feats_for(ln, pr, "freq"), pd$n, pd$eff)
  X <- to_mat(enc, pd$d)
  m <- xgb_fit(X, pd$n / pd$eff, pd$eff, pd$d$policy_id, "count:poisson", cfg, mono_enc(enc, ln, pr, "freq"), seed)
  mu <- predict(m, X) * pd$eff
  bal <- sum(pd$n) / sum(mu)
  list(enc = enc, model = m, bal = bal, trend = wc_freq_trend(pd, pd$n, mu * bal), rounds = rounds_of(m))
}
freq_rate <- function(fq, nd, trend = TRUE) {
  r <- predict(fq$model, to_mat(fq$enc, nd)) * fq$bal
  if (trend) r * year_factor(fq$trend$g, nd$policy_year, fq$trend$mid) else r
}
fit_sev <- function(pd, cfg, type, ln, pr, seed) {
  sv <- pd$sv
  if (nrow(sv) < MIN_SEV_CLAIMS || type == "mean") return(list(type = "mean", mu = mean(sv$capped)))
  if (type == "glm") {
    g <- wc_glm_fit(sv, feats_for(ln, pr, "sev"))
    return(if (is.null(g)) list(type = "mean", mu = mean(sv$capped)) else c(list(type = "glm"), g))
  }
  enc <- make_enc(sv, feats_for(ln, pr, "sev"), sv$capped, rep(1, nrow(sv)))
  X <- to_mat(enc, sv)
  m <- xgb_fit(X, sv$capped, rep(1, nrow(sv)), sv$policy_id, "reg:gamma", cfg, mono_enc(enc, ln, pr, "sev"), seed)
  list(type = "gbm", enc = enc, model = m, bal = sum(sv$capped) / sum(predict(m, X)), rounds = rounds_of(m))
}
sev_pred <- function(sf, nd) switch(sf$type, mean = rep(sf$mu, nrow(nd)),
                                    gbm = predict(sf$model, to_mat(sf$enc, nd)) * sf$bal,
                                    glm = wc_glm_predict(sf, nd))
fit_tw <- function(pd, cfg, ln, pr, seed) {
  enc <- make_enc(pd$d, feats_for(ln, pr, "all"), pd$y, pd$eff)
  X <- to_mat(enc, pd$d)
  m <- xgb_fit(X, pd$y / pd$eff, pd$eff, pd$d$policy_id, "reg:tweedie", cfg, mono_enc(enc, ln, pr, "freq"), seed,
               extra = list(tweedie_variance_power = cfg$tweedie_p, eval_metric = paste0("tweedie-nloglik@", cfg$tweedie_p)))
  mu <- predict(m, X) * pd$eff
  bal <- sum(pd$y) / sum(mu)
  list(enc = enc, model = m, bal = bal, trend = wc_freq_trend(pd, pd$y, mu * bal), rounds = rounds_of(m))
}
# Row cost of a fitted peril (either method) on any rows; structurally zero rows -> 0
predict_peril <- function(art, nd) {
  out <- numeric(nrow(nd))
  idx <- which(!wc_zero_mask(nd, art$line, art$peril))
  if (!length(idx)) return(out)
  sub <- nd[idx]
  sev_year <- year_factor(art$sev_trend, sub$policy_year, art$base_year)
  out[idx] <- if (art$method == "freq_sev") {
    sub$exposure * freq_rate(art$freq, sub) * sev_pred(art$sev, sub) * sev_year * art$load
  } else {
    sub$exposure * predict(art$tw$model, to_mat(art$tw$enc, sub)) * art$tw$bal *
      year_factor(art$tw$trend$g, sub$policy_year, art$tw$trend$mid) * sev_year * art$load
  }
  out
}
fit_peril <- function(tr, ln, pr, method, best, seed) {
  pd <- wc_peril_data(tr, ln, pr)
  art <- list(line = ln, peril = pr, method = method, base_year = pd$base_year, sev_trend = pd$sev_trend,
              load = pd$load, cap = pd$cap)
  if (method == "freq_sev") {
    art$freq <- fit_freq(pd, best$freq, ln, pr, seed + 1)
    art$sev <- fit_sev(pd, best$sev, best$sev_type, ln, pr, seed + 2)
  } else art$tw <- fit_tw(pd, best$tweedie, ln, pr, seed + 3)
  art$pd_info <- list(n_claims = sum(pd$n), n_sev = nrow(pd$sv), freq_trend = if (method == "freq_sev") art$freq$trend$g else art$tw$trend$g)
  art
}
seed_of <- function(ln, pr, k) SEED + 5000 + 1000 * match(ln, LINES) + 40 * match(pr, PERILS[[ln]]) + 7 * k

# Run per line ---------------------------------------------------------------------------------------------------------
tuning_log <- list(); best_cfgs <- list(); oof_scores <- list(); comp_cv <- list(); oof_line <- list()
time_scores <- list(); time_line <- list(); chosen <- list(); fit_log <- list()
for (ln in LINES) {
  dt <- wc_load_line(paste0("train_", ln), ln)
  dt[, fold__ := wc_policy_folds(policy_id, K)]
  cv_parts_pred <- list(); cv_parts_dev <- 0
  for (pr in PERILS[[ln]]) {
    sp <- spec_row(ln, pr)
    t_pr <- Sys.time()
    # 1. Tuning on fold TUNE_FOLD -----------------------------------------------------------------------------
    tr <- dt[fold__ != TUNE_FOLD]; ho <- dt[fold__ == TUNE_FOLD]
    pd <- wc_peril_data(tr, ln, pr)
    ht <- wc_targets_for(pd, ho, ln, pr)
    best <- list()
    for (part in c("freq", "sev", "tweedie")) {
      if (part == "sev" && (nrow(pd$sv) < MIN_SEV_CLAIMS || tolower(sp$sev_model) %in% c("mean", "gamma_glm"))) next
      cfgs <- config_list(sp, part, seed_of(ln, pr, 0) + match(part, c("freq", "sev", "tweedie")))
      res <- rbindlist(lapply(seq_along(cfgs), function(i) {
        cfg <- cfgs[[i]]; s <- Sys.time()
        dev <- switch(part,
          freq = { f <- fit_freq(pd, cfg, ln, pr, seed_of(ln, pr, i)); r <- f$rounds
                   wc_poisson_dev(ht$n, freq_rate(f, ht$d, trend = FALSE) * ht$eff) },
          sev = { f <- fit_sev(pd, cfg, "gbm", ln, pr, seed_of(ln, pr, i)); r <- f$rounds
                  wc_gamma_dev(ht$sv$capped, sev_pred(f, ht$sv)) },
          tweedie = { f <- fit_tw(pd, cfg, ln, pr, seed_of(ln, pr, i)); r <- f$rounds
                      wc_tweedie_dev(ht$y, predict(f$model, to_mat(f$enc, ht$d)) * f$bal * ht$eff, SCORE_P) })
        cbind(data.table(line = ln, peril = pr, part = part, config = i, default = i == 1, holdout_deviance = dev,
                         rounds = r, seconds = round(as.numeric(difftime(Sys.time(), s, units = "secs")))),
              as.data.table(cfg))
      }))
      tuning_log[[paste(ln, pr, part)]] <- res
      best[[part]] <- cfgs[[res[which.min(holdout_deviance), config]]]
      log_msg(ln, "/", pr, " ", part, ": best of ", nrow(res), " configs dev ", signif(min(res$holdout_deviance), 5),
              " (default ", signif(res[default == TRUE, holdout_deviance], 5), ")")
    }
    # severity type: tuned GBM vs GLM
    best$sev_type <- "mean"
    if (nrow(pd$sv) >= MIN_SEV_CLAIMS && tolower(sp$sev_model) != "mean") {
      cand <- c(if (tolower(sp$sev_model) %in% c("auto", "gamma_gbm")) "gbm", if (tolower(sp$sev_model) %in% c("auto", "gamma_glm")) "glm")
      devs <- sapply(cand, function(tp) {
        if (tp == "gbm") return(tuning_log[[paste(ln, pr, "sev")]][, min(holdout_deviance)])
        g <- fit_sev(pd, NULL, "glm", ln, pr, 0)
        d <- if (g$type == "glm") wc_gamma_dev(ht$sv$capped, sev_pred(g, ht$sv)) else Inf
        tuning_log[[paste(ln, pr, "sev_glm")]] <<- data.table(line = ln, peril = pr, part = "sev_glm", config = 1L,
                                                                default = TRUE, holdout_deviance = d)
        d
      })
      best$sev_type <- names(devs)[which.min(devs)]
    }
    best_cfgs[[paste(ln, pr)]] <- best
    rm(tr, ho, pd, ht); invisible(gc(verbose = FALSE))

    # 2. Grouped CV -----------------------------------------------------------------------------------------------
    methods <- if (toupper(sp$challenger_tweedie) == "Y") c("freq_sev", "tweedie") else "freq_sev"
    if (MODE %in% c("group_cv", "both")) {
      oof <- setNames(lapply(methods, function(m) numeric(nrow(dt))), methods)
      cdev <- list()
      for (k in seq_len(K)) {
        tr <- dt[fold__ != k]; idx <- which(dt$fold__ == k); va <- dt[idx]
        for (m in methods) {
          art <- fit_peril(tr, ln, pr, m, best, seed_of(ln, pr, 100 + k))
          oof[[m]][idx] <- predict_peril(art, va)
          if (m == "freq_sev") {
            pd_k <- wc_peril_data(tr, ln, pr); vt <- wc_targets_for(pd_k, va, ln, pr)
            cdev[[k]] <- data.table(fold = k,
              freq_dev = wc_poisson_dev(vt$n, freq_rate(art$freq, vt$d, trend = FALSE) * vt$eff), n_rows = nrow(vt$d),
              sev_dev = if (nrow(vt$sv)) wc_gamma_dev(vt$sv$capped, sev_pred(art$sev, vt$sv)) else NA_real_, n_claims = nrow(vt$sv))
          }
        }
        rm(tr, va); invisible(gc(verbose = FALSE))
      }
      dv <- wc_developed(dt, ln, pr)
      for (m in methods) {
        oof_scores[[paste(ln, pr, m)]] <- data.table(line = ln, peril = pr, method = m,
          d2 = wc_d2(dv$dev, oof[[m]], dt$exposure, SCORE_P), gini = wc_gini(dv$dev, oof[[m]]),
          pred_vs_developed = sum(oof[[m]]) / sum(dv$dev))
      }
      cd <- rbindlist(cdev)
      comp_cv[[paste(ln, pr)]] <- rbind(
        data.table(line = ln, peril = pr, part = "freq", metric = "poisson_deviance", value = weighted.mean(cd$freq_dev, cd$n_rows), n = sum(cd$n_rows)),
        data.table(line = ln, peril = pr, part = "sev", metric = "gamma_deviance", value = weighted.mean(cd$sev_dev, cd$n_claims, na.rm = TRUE), n = sum(cd$n_claims)))
      ch <- oof_scores[paste(ln, pr, methods)]
      ch <- rbindlist(ch)[which.max(d2), method]
      cv_parts_pred[[pr]] <- oof[[ch]]
      cv_parts_dev <- cv_parts_dev + dv$dev
    }
    # 3. Time check -----------------------------------------------------------------------------------------------
    tr <- dt[policy_year < TIME_YEAR]; va <- dt[policy_year == TIME_YEAR]
    dv <- wc_developed(va, ln, pr)
    for (m in methods) {
      art <- fit_peril(tr, ln, pr, m, best, seed_of(ln, pr, 200))
      p <- predict_peril(art, va)
      time_scores[[paste(ln, pr, m)]] <- data.table(line = ln, peril = pr, method = m,
        d2 = wc_d2(dv$dev, p, va$exposure, SCORE_P), gini = wc_gini(dv$dev, p), pred_vs_developed = sum(p) / sum(dv$dev),
        pred = list(p), dev = list(dv$dev))
    }
    rm(tr, va); invisible(gc(verbose = FALSE))
    # Choice
    pick <- if (MODE %in% c("group_cv", "both")) rbindlist(oof_scores[paste(ln, pr, methods)])[which.max(d2), method]
            else rbindlist(time_scores[paste(ln, pr, methods)])[which.max(d2), method]
    chosen[[paste(ln, pr)]] <- data.table(line = ln, peril = pr, method = pick, sev_type = best$sev_type,
                                          basis = if (MODE == "time") paste0("time_", TIME_YEAR) else "group_cv")
    log_msg(ln, "/", pr, " -> ", pick, " (sev ", best$sev_type, ") in ",
            round(as.numeric(difftime(Sys.time(), t_pr, units = "mins")), 1), " min")
  }
  if (length(cv_parts_pred)) oof_line[[ln]] <- data.table(line = ln, pred = Reduce(`+`, cv_parts_pred), dev = cv_parts_dev, exposure = dt$exposure)
  ts <- rbindlist(time_scores[paste(ln, PERILS[[ln]], rbindlist(chosen)[line == ln, method])])
  time_line[[ln]] <- data.table(line = ln, pred = Reduce(`+`, ts$pred), dev = Reduce(`+`, ts$dev),
                                exposure = dt[policy_year == TIME_YEAR, exposure])
  rm(dt); invisible(gc(verbose = FALSE))
}
chosen <- rbindlist(chosen)
tuning_log <- rbindlist(tuning_log, fill = TRUE)
oof_scores <- rbindlist(oof_scores)
time_scores <- rbindlist(time_scores)[, !c("pred", "dev")]
comp_cv <- rbindlist(comp_cv)

# 4. Final fit, 2025 predictions ----------------------------------------------------------------------------------------
dir.create(file.path(ITER_DIR, "fitted"), recursive = TRUE, showWarnings = FALSE)
save_art <- function(art, file) {
  for (nm in c("freq", "tw")) if (!is.null(art[[nm]][["model"]])) art[[nm]]$model <- xgb.save.raw(art[[nm]]$model)
  if (identical(art[["sev"]]$type, "gbm")) art$sev$model <- xgb.save.raw(art$sev$model)
  saveRDS(art, file)
}
sub_parts <- list(); peril_preds <- list(); imp <- list(); final_diag <- list(); test_line <- list()
for (ln in LINES) {
  tr <- wc_load_line(paste0("train_", ln), ln)
  te <- wc_load_line(paste0("test_", ln), ln)
  pp <- data.table(row_id = te$row_id)
  for (pr in PERILS[[ln]]) {
    ch <- chosen[line == ln & peril == pr]
    art <- fit_peril(tr, ln, pr, ch$method, best_cfgs[[paste(ln, pr)]], seed_of(ln, pr, 300))
    set(pp, j = pr, value = predict_peril(art, te))
    save_art(art, file.path(ITER_DIR, "fitted", paste0(ln, "_", pr, ".rds")))
    parts <- if (ch$method == "freq_sev") {
      rbind(gain_of(art$freq$model)[, part := "freq"],
            switch(art$sev$type, gbm = gain_of(art$sev$model)[, part := "sev"],
                   glm = art$sev$importance[, part := "sev"], NULL))
    } else gain_of(art$tw$model)[, part := "tweedie"]
    imp[[paste(ln, pr)]] <- parts[, share := importance / sum(importance), by = part][, `:=`(line = ln, peril = pr)]
    final_diag[[paste(ln, pr)]] <- data.table(line = ln, peril = pr, method = ch$method, sev_type = ch$sev_type,
      rounds_freq = if (ch$method == "freq_sev") art$freq$rounds else art$tw$rounds,
      rounds_sev = if (identical(art[["sev"]]$type, "gbm")) art$sev$rounds else NA_integer_,
      claims = art$pd_info$n_claims, sev_claims = art$pd_info$n_sev, freq_trend = art$pd_info$freq_trend,
      sev_trend = art$sev_trend, cap = art$cap, cap_load = art$load, predicted_burn = sum(pp[[pr]]) / sum(te$exposure))
    log_msg("Final ", ln, "/", pr, " (", ch$method, "): burn ", round(sum(pp[[pr]]) / sum(te$exposure), 2))
  }
  tot <- pmax(rowSums(as.matrix(pp[, PERILS[[ln]], with = FALSE])), 0)
  test_line[[ln]] <- data.table(line = ln, rows = nrow(te), predicted_total = sum(tot), predicted_burn = sum(tot) / sum(te$exposure))
  sub_parts[[ln]] <- data.table(row_id = te$row_id, prediction = tot)
  peril_preds[[ln]] <- melt(pp, id.vars = "row_id", variable.name = "peril", value.name = "prediction",
                            variable.factor = FALSE)[, line := ln]
  rm(tr, te); invisible(gc(verbose = FALSE))
}
sub <- rbindlist(sub_parts)
ss <- read_raw("sample_submission")
stopifnot(nrow(sub) == nrow(ss), setequal(sub$row_id, ss$row_id), !anyDuplicated(sub$row_id),
          all(is.finite(sub$prediction)), all(sub$prediction >= 0))
sub <- sub[match(ss$row_id, row_id)]
sub_file <- out_file("submission", "submission_provisional.csv")
fwrite(sub, sub_file, scipen = 50)
run_file <- out_file("submission", paste0("submission_", RUN_ID, "_wendy05.csv"))
invisible(file.copy(sub_file, run_file, overwrite = TRUE))

# Replication check: reload the saved peril models from disk, re-score the test rows, compare with the submission
load_art <- function(file) {
  art <- readRDS(file)
  for (nm in c("freq", "tw")) if (!is.null(art[[nm]][["model"]])) art[[nm]]$model <- xgb.load.raw(art[[nm]]$model)
  if (identical(art[["sev"]]$type, "gbm")) art$sev$model <- xgb.load.raw(art$sev$model)
  art
}
replication <- rbindlist(lapply(LINES, function(ln) {
  te <- wc_load_line(paste0("test_", ln), ln)
  re <- Reduce(`+`, lapply(PERILS[[ln]], function(pr)
    predict_peril(load_art(file.path(ITER_DIR, "fitted", paste0(ln, "_", pr, ".rds"))), te)))
  data.table(line = ln, rows = nrow(te), max_abs_diff = max(abs(pmax(re, 0) - sub[match(te$row_id, row_id), prediction])))
}))
replication_ok <- all(replication$max_abs_diff < 1e-6)
if (!replication_ok) warning("Reloaded models do not reproduce the submission - see the model card.")
log_msg("Replication check ", if (replication_ok) "passed" else "FAILED", " (max abs diff ",
        signif(max(replication$max_abs_diff), 3), ")")

# 5. Outputs ---------------------------------------------------------------------------------------------------------
fwrite(tuning_log, file.path(ITER_DIR, "tuning_log.csv"))
fwrite(chosen, file.path(ITER_DIR, "chosen_method.csv"))
fwrite(oof_scores, file.path(ITER_DIR, "cv_by_peril.csv"))
fwrite(time_scores, file.path(ITER_DIR, "time_check_by_peril.csv"))
fwrite(rbindlist(final_diag), file.path(ITER_DIR, "diagnostics_final.csv"))
fwrite(rbindlist(test_line), file.path(ITER_DIR, "test_by_line.csv"))
fwrite(ZERO, file.path(ITER_DIR, "structural_zero_check.csv"))
fwrite(replication, file.path(ITER_DIR, "replication_check.csv"))
fwrite(rbindlist(peril_preds), file.path(ITER_DIR, "test_preds_by_peril.csv.gz"))
invisible(file.copy(CFG_FILE, file.path(ITER_DIR, basename(CFG_FILE)), overwrite = TRUE))

ch_scores <- function(sc, scheme) merge(sc, chosen[, .(line, peril, method)], by = c("line", "peril", "method"))[
  , .(iteration = ITERATION, scheme = scheme, line, peril, method, d2, gini, pred_vs_developed)]
peril_scores <- rbind(if (nrow(oof_scores)) ch_scores(oof_scores, "group_cv"), ch_scores(time_scores, paste0("time_", TIME_YEAR)))
line_scores <- rbind(if (length(oof_line)) wc_line_scores(oof_line, ITERATION, "group_cv"),
                     wc_line_scores(time_line, ITERATION, paste0("time_", TIME_YEAR)))
tg <- tuning_log[part %in% c("freq", "sev", "tweedie"), .(default_dev = holdout_deviance[default][1], best_dev = min(holdout_deviance)),
                 by = .(line, peril, part)][, tuning_gain_pct := 100 * (default_dev - best_dev) / abs(default_dev)]
wc_write_comparison(ITER_DIR, peril_scores = peril_scores, line_scores = line_scores,
  component_cv = if (nrow(comp_cv)) comp_cv[, `:=`(iteration = ITERATION, model = "xgboost")] else NULL,
  importance = rbindlist(imp)[, .(iteration = ITERATION, line, peril, part, feature, share)],
  changes = c("WENDY 5 vs WENDY 4:", paste0("- random search (", TUNE_N, " configs) per component on a policy-grouped fold"),
              "- severity GBM vs GLM chosen per peril on holdout Gamma deviance",
              paste0("- method (freq x sev / Tweedie) chosen on ", K, "-fold policy-grouped CV over all years"),
              "- trends year-aware (fit to last training year, scaled to each row's year)"))
fwrite(tg, file.path(ITER_DIR, "tuning_gain.csv"))

card <- c(
  paste0("# ", ITERATION, " - tuned per-peril models, method chosen on grouped CV"), "",
  paste0("**Run id** `", RUN_ID, "` | **Workbook** `", CFG_FILE, "` (MD5 `", unname(tools::md5sum(CFG_FILE)), "`) | **Submission** `",
         basename(run_file), "` (MD5 `", unname(tools::md5sum(run_file)), "`)", if (FAST) " | **FAST - not for submission**" else ""), "",
  paste0("Replication check (saved models in `", file.path(ITER_DIR, "fitted"), "/` reloaded and re-scored vs the submission): **",
         if (replication_ok) "passed" else "FAILED", "**"), "",
  md_table(replication, 10),
  paste0("Validation mode `", MODE, "`, ", K, " policy-grouped folds, ", TUNE_N, " configs per component, tuning fold ", TUNE_FOLD, "."), "",
  "## Line and portfolio scores (Tweedie D2 vs developed actuals)", md_table(dcast(line_scores, line ~ scheme, value.var = "d2"), 4),
  "## Chosen method per peril", md_table(chosen),
  if (nrow(oof_scores)) c("## Grouped CV by peril and method", md_table(dcast(oof_scores, line + peril ~ method, value.var = "d2"), 4)),
  paste0("## Time check ", TIME_YEAR), md_table(dcast(time_scores, line + peril ~ method, value.var = "d2"), 4),
  "## Tuning gain (holdout deviance, default -> best config)", md_table(tg, 4),
  if (nrow(comp_cv)) c("## Component out-of-fold deviance (compare with WENDY 6)", md_table(comp_cv[, .(line, peril, part, metric, value, n)], 5)),
  "## Final fit", md_table(rbindlist(final_diag), 3), md_table(rbindlist(test_line), 2),
  paste0("Run time ", round(as.numeric(difftime(Sys.time(), T0, units = "hours")), 2), " hours.")
)
writeLines(card, file.path(ITER_DIR, "model_card.md"))
log_msg("Done. Submission: ", sub_file, " | card: ", file.path(ITER_DIR, "model_card.md"))
