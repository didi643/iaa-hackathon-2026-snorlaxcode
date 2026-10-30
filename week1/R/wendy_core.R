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
