# 05_developed_baseline.R -------------------------------------------------------------------------------------
# Purpose : Developed baseline for Option B. Copied from week1/R/4_models_iterwendy07.R (WENDY 7 C5 engine) and adapted:
#             - data: the harmonised SHARED features of step 3 (data/week_2/optionB/features/developed_*), claims on the C5
#               basis (00_setup_week2.R claim_basis(): open-claim recoveries, 2m single-claim limit, positive claims);
#             - workbook: week2/inputs/assumptions_week2_baseline.xlsx, built here from a copy of
#               week1/docs/assumptions_wendy07_final2.xlsx with the Features_* sheets edited to the shared set
#               (driver_age -> driver_age_band, policyholder_age -> policyholder_age_band; region, credit_band,
#               annual_mileage, telematics_*, compulsory_excess -> use N) and Settings bags = 1, model_selection = freq_sev;
#             - IBNR: the step 4 developed chain-ladder shares (week2/output/04_ibnr_trend/report_share_quarter.csv),
#               same method as C5 (chain ladder, subsidence ECDF-days override); history features precomputed in step 3;
#             - method: frequency x severity for EVERY peril (C5 used Tweedie for motor BI and contents EoW), because
#               step 7 adjusts frequency and severity separately; 1 bag instead of 5 (run time);
#             - outputs: developed validation on the week 1 folds (2021-22 -> 2023, 2021-23 -> 2024) on reported_raw
#               and developed actuals; final fit 2021-24; per-row, per-peril baseline FREQUENCY (per exposure-year,
#               ultimate, trended to 2025) and SEVERITY (capped, trended to 2025, x large-loss load) for every emerging
#               training and test row, through the models' own predict path. The developed level is NOT the emerging
#               level (re-estimated in step 7): the baseline supplies relativities.
# Inputs  : data/week_2/optionB/features/developed_{train,test}_<line>.parquet, emerging_{train,test}_<line>.parquet,
#           data/week_2/optionB/clean/developed_claims_matched.parquet, week2/output/04_ibnr_trend/report_share_quarter.csv,
#           week1/docs/assumptions_wendy07_final2.xlsx (read only)
# Outputs : week2/inputs/assumptions_week2_baseline.xlsx, week2/models/baseline/ (model card, scores, diagnostics,
#           fitted/*.rds), week2/output/05_baseline/ (line_scores.csv, peril_scores.csv, row_preds.parquet),
#           data/week_2/optionB/baseline/baseline_emerging_{train,test}.parquet
# Run     : Rscript week2/R/05_developed_baseline.R           (FAST=1 smoke test; SKIP_VALID=1 final fit only)
# Time    : about 10-15 minutes on the Mac (1 bag)

source("week2/R/00_setup_week2.R")
start_script("05_developed_baseline.R")
for (p in c("xgboost", "readxl", "openxlsx")) if (!requireNamespace(p, quietly = TRUE)) stop("Missing package '", p, "'")
suppressPackageStartupMessages({ library(xgboost); library(readxl) })
STEP <- "05_baseline"
FAST <- Sys.getenv("FAST", "0") == "1"
SKIP_VALID <- Sys.getenv("SKIP_VALID", "0") == "1"
FEAT_DIR <- file.path(W2$data, "features")
ITER_DIR <- file.path(W2$models, Sys.getenv("RUN_TAG", "baseline"))
IS_MAIN <- basename(ITER_DIR) == "baseline"
if (!IS_MAIN) STEP <- paste0("05_", basename(ITER_DIR))             # experiment runs keep their own outputs
SRC_XLSX <- "week1/docs/assumptions_wendy07_final2.xlsx"
CFG_FILE <- file.path(W2$inputs, if (IS_MAIN) "assumptions_week2_baseline.xlsx" else paste0("assumptions_week2_", basename(ITER_DIR), ".xlsx"))
T0 <- Sys.time()

# 0a. Build the week 2 workbook from the C5 workbook (edits listed here, so the copy is reproducible) ------------------
track_input(SRC_XLSX)
FEATURE_RENAME <- c(driver_age = "driver_age_band", policyholder_age = "policyholder_age_band")
FEATURE_OFF <- c("region", "credit_band", "annual_mileage", "telematics_opt_in", "telematics_score", "compulsory_excess",
                 "customer_age", "written_premium", "customer_service_contacts", "gender")
SETTING_EDITS <- c(bags = Sys.getenv("BAGS", "5"), model_selection = "freq_sev", method_mix = "auto")   # 5 bags since experiment X8 (D028); BAGS=1 for quick runs
wb <- openxlsx::loadWorkbook(SRC_XLSX)
edit_log <- list()
for (sh in c("Features_Motor", "Features_Buildings", "Features_Contents")) {
  x <- as.data.table(read_excel(SRC_XLSX, sheet = sh, col_types = "text"))
  for (old in names(FEATURE_RENAME)) {
    i <- which(x$column == old)
    if (length(i)) { x[i, `:=`(column = FEATURE_RENAME[[old]], type = "cat", mono_freq = "0", mono_sev = "0")]
                     edit_log[[length(edit_log) + 1]] <- data.table(sheet = sh, column = old, edit = paste("renamed to", FEATURE_RENAME[[old]], "(category, no monotone constraint)")) }
  }
  i <- which(x$column %in% FEATURE_OFF & toupper(x$use) == "Y")
  if (length(i)) { edit_log[[length(edit_log) + 1]] <- data.table(sheet = sh, column = x$column[i], edit = "use Y -> N (not shared / excluded)")
                   x[i, `:=`(use = "N", decision = "Exclude", reason = paste0("Week 2: not shared by both markets or excluded. ", reason))] }
  openxlsx::writeData(wb, sh, x, startRow = 1, colNames = TRUE)
}
st <- as.data.table(read_excel(SRC_XLSX, sheet = "Settings", col_types = "text"))
for (k in names(SETTING_EDITS)) {
  i <- which(st$key == k)
  edit_log[[length(edit_log) + 1]] <- data.table(sheet = "Settings", column = k, edit = paste0(st$value[i], " -> ", SETTING_EDITS[[k]]))
  st[i, value := SETTING_EDITS[[k]]]
}
openxlsx::writeData(wb, "Settings", st, startRow = 1, colNames = TRUE)
edit_log <- rbindlist(edit_log)
if ("Week2_Edits" %in% names(wb)) openxlsx::removeWorksheet(wb, "Week2_Edits")
openxlsx::addWorksheet(wb, "Week2_Edits")
openxlsx::writeData(wb, "Week2_Edits", edit_log)
openxlsx::saveWorkbook(wb, CFG_FILE, overwrite = TRUE)
track_output(CFG_FILE)
log_msg("Workbook ", CFG_FILE, " built from ", SRC_XLSX, " with ", nrow(edit_log), " edits")

# 0b. Read the workbook (as C5) ---------------------------------------------------------------------------------------
rd <- function(sheet) { x <- as.data.table(read_excel(CFG_FILE, sheet = sheet, col_types = "text")); x[!is.na(x[[1]])] }
settings <- rd("Settings")
S <- setNames(settings$value, settings$key)
s_get <- function(k) { if (!k %in% names(S) || is.na(S[[k]])) stop("Setting '", k, "' missing"); S[[k]] }
s_num <- function(k) as.numeric(s_get(k))
s_vec <- function(k) trimws(strsplit(s_get(k), ",", fixed = TRUE)[[1]])
VALID_YEARS <- as.integer(s_vec("valid_years"))
TARGET_YEAR <- as.integer(s_num("target_year"))
SEV_TREND_LIM <- c(s_num("sev_trend_min"), s_num("sev_trend_max"))
FREQ_TREND_LIM <- c(s_num("freq_trend_min"), s_num("freq_trend_max"))
MAX_ROUNDS <- if (FAST) 300 else s_num("max_rounds")
ETA_MULT <- if (FAST) 2 else 1
ES_ROUNDS <- s_num("early_stopping_rounds")
HOLD_SHARE <- s_num("holdout_share")
SUBSAMPLE <- s_num("subsample"); COLSAMPLE <- s_num("colsample_bytree"); LAMBDA <- s_num("reg_lambda")
GLM_MIN_CLAIMS <- s_num("glm_min_level_claims")
GLM_LOG <- s_vec("glm_log_features")
NTHREAD <- as.integer(s_num("nthread")); if (NTHREAD <= 0) NTHREAD <- max(1L, parallel::detectCores())
BAGS <- as.integer(s_get("bags"))
MIN_SEV_CLAIMS <- 200

spec <- rd("Model_Spec")[line %in% LINES]
num_cols <- c("cap_quantile", "sev_exclude_recent_years", "freq_max_depth", "freq_eta", "freq_min_child_weight",
              "sev_max_depth", "sev_eta", "sev_min_child_weight", "tweedie_p")
spec[, (num_cols) := lapply(.SD, as.numeric), .SDcols = num_cols]
spec_row <- function(ln, pr) spec[line == ln & peril == pr][1]
fmap <- rbindlist(lapply(LINES, function(ln) {
  x <- rd(paste0("Features_", tools::toTitleCase(ln)))
  x <- x[toupper(trimws(use)) == "Y", c("column", "mono_freq", "mono_sev", PERILS[[ln]]), with = FALSE]
  long <- melt(x, id.vars = c("column", "mono_freq", "mono_sev"), variable.name = "peril", value.name = "code", variable.factor = FALSE)
  long[, `:=`(line = ln, code = toupper(trimws(code)))][code %in% c("B", "F", "S")]
}))
fmap[, `:=`(mono_freq = as.integer(fifelse(is.na(mono_freq), "0", mono_freq)), mono_sev = as.integer(fifelse(is.na(mono_sev), "0", mono_sev)))]
# Week 2 rule: voluntary_excess in every peril (handover; week 1 C4/C5 "excess in every peril")
# MOTOR_LOC=1 (experiment X9): location signal for motor in place of the dropped region - urban_density and the address
# weather averages as frequency features of every motor peril
if (Sys.getenv("MOTOR_LOC", "0") == "1") for (pr in PERILS$motor) for (cn in c("urban_density", "wx_avg_hail_days", "wx_avg_rainfall_mm", "wx_avg_freezing_days", "wx_avg_wind_exposure_index"))
  if (!nrow(fmap[line == "motor" & peril == pr & column == cn])) fmap <- rbind(fmap, data.table(column = cn, mono_freq = 0L, mono_sev = 0L, peril = pr, code = "F", line = "motor"), use.names = TRUE)
for (ln in LINES) for (pr in PERILS[[ln]]) if (!nrow(fmap[line == ln & peril == pr & column == "voluntary_excess"]))
  fmap <- rbind(fmap, data.table(column = "voluntary_excess", mono_freq = -1L, mono_sev = 0L, peril = pr, code = "F", line = ln), use.names = TRUE)
feats_for <- function(ln, pr, part) {
  codes <- switch(part, freq = c("F", "B"), sev = c("S", "B"), all = c("F", "S", "B"))
  unique(fmap[line == ln & peril == pr & code %in% codes, column])
}
zero_rules <- rd("Structural_Zeros")[line %in% LINES]
log_msg("Features: ", nrow(fmap), " feature-peril uses; bags ", BAGS, if (FAST) " [FAST]" else "")

# 1. Claims and IBNR shares -------------------------------------------------------------------------------------------
clp <- claim_basis("developed")
# POOLED_YEAR=2023|2024 (experiment X7): the final fit also uses the emerging training rows up to that year, with the
# `market` flag and gender as features, so the trees can learn emerging-specific shape. Emerging ids are prefixed "E_"
# in the fit (ids overlap between markets). 2023 = baseline for the 2024 validation, 2024 = baseline for 2025.
POOLED_YEAR <- as.integer(Sys.getenv("POOLED_YEAR", "0"))
add_extra <- function(d, part, ln) {
  if (!POOLED_YEAR) return(d)
  if (d$market[1] == "emerging") merge(d, read_w2(file.path(FEAT_DIR, sprintf("emerging_extra_%s_%s.parquet", part, ln)))[, .(row_id, gender)], by = "row_id")
  else d[, gender := "missing"]
}
if (POOLED_YEAR) {
  clp <- rbind(clp, claim_basis("emerging")[, row_id := paste0("E_", row_id)])
  for (ln in LINES) for (pr in PERILS[[ln]]) for (cn in c("market", "gender"))
    fmap <- rbind(fmap, data.table(column = cn, mono_freq = 0L, mono_sev = 0L, peril = pr, code = if (cn == "market") "B" else "F", line = ln), use.names = TRUE)
}
shares <- load_report_shares()
report_share <- function(ln, pr, dt) row_report_share(shares, ln, pr, dt$period_start, dt$period_end)
load_line <- function(market, part, ln) {
  dt <- read_w2(file.path(FEAT_DIR, sprintf("%s_%s_%s.parquet", market, part, ln)))
  miss <- setdiff(fmap[line == ln, unique(column)], c(names(dt), "gender"))   # gender is added by add_extra() in pooled runs
  if (length(miss)) stop(market, " ", part, " ", ln, ": workbook features not in data: ", paste(miss, collapse = ", "))
  dt
}

# 2. Structural zeros (applied only where developed training has no positive claims) ------------------------------------
rule_mask <- function(dt, rules) {
  m <- rep(FALSE, nrow(dt))
  for (i in seq_len(nrow(rules))) {
    vals <- toupper(trimws(strsplit(rules$values[i], ",", fixed = TRUE)[[1]]))
    m <- m | toupper(as.character(dt[[rules$column[i]]])) %chin% vals
  }
  m
}
zr_check <- rbindlist(lapply(LINES, function(ln) {
  rules <- zero_rules[line == ln]; if (!nrow(rules)) return(NULL)
  dt <- load_line("developed", "train", ln)
  rbindlist(lapply(seq_len(nrow(rules)), function(i) {
    r <- rules[i]; m <- rule_mask(dt, r)
    n_cl <- clp[line == ln & peril == r$peril & row_id %chin% dt$row_id[m], .N]
    r[, .(line, peril, column, values, rows = sum(m), claims = n_cl, active = n_cl == 0 & sum(m) > 0)]
  }))
}))
zero_mask <- function(dt, ln, pr) {
  rules <- zr_check[line == ln & peril == pr & active == TRUE]
  if (!nrow(rules)) rep(FALSE, nrow(dt)) else rule_mask(dt, rules)
}

# 3. Helpers (copied from C5) ----------------------------------------------------------------------------------------------
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
mono_vec <- function(enc, ln, pr, part) {
  col <- if (part == "sev") "mono_sev" else "mono_freq"
  m <- fmap[line == ln & peril == pr][match(enc$feats, column)][[col]]
  m[is.na(m) | enc$feats %in% names(enc$lv)] <- 0L
  m
}
policy_holdout <- function(pid) { u <- unique(pid); pid %chin% sample(u, max(1L, round(HOLD_SHARE * length(u)))) }
xgb_fit <- function(X, label, w, hold, objective, depth, eta, mcw, mono = NULL, extra = list(), pid = NULL) {
  one <- function(hold, seed) {
    dtr <- xgb.DMatrix(X[!hold, , drop = FALSE], label = label[!hold], weight = w[!hold], nthread = NTHREAD)
    dva <- xgb.DMatrix(X[hold, , drop = FALSE], label = label[hold], weight = w[hold], nthread = NTHREAD)
    params <- c(list(objective = objective, learning_rate = eta * ETA_MULT, max_depth = depth, min_child_weight = mcw,
                     subsample = SUBSAMPLE, colsample_bytree = COLSAMPLE, reg_lambda = LAMBDA,
                     tree_method = "hist", nthread = NTHREAD, seed = seed), extra)
    if (!is.null(mono) && any(mono != 0)) params$monotone_constraints <- paste0("(", paste(mono, collapse = ","), ")")
    xgb.train(params = params, data = dtr, nrounds = MAX_ROUNDS, evals = list(holdout = dva), early_stopping_rounds = ES_ROUNDS, verbose = 0)
  }
  m1 <- one(hold, SEED)
  if (BAGS <= 1 || is.null(pid)) return(m1)
  structure(c(list(m1), lapply(2:BAGS, function(b) one(policy_holdout(pid), SEED + b))), class = "xgb_bag")
}
predict.xgb_bag <- function(object, newdata, ...) {
  p <- vapply(unclass(object), function(m) predict(m, newdata), numeric(nrow(newdata)))
  if (is.null(dim(p))) mean(p) else rowMeans(p)
}
best_iter <- function(m) { if (inherits(m, "xgb_bag")) m <- m[[1]]; b <- xgb.attr(m, "best_iteration"); if (is.null(b)) NA_integer_ else as.integer(b) }
raw_model <- function(m) if (inherits(m, "xgb_bag")) structure(lapply(unclass(m), xgb.save.raw), class = "xgb_bag_raw") else xgb.save.raw(m)
load_model <- function(r) if (inherits(r, "xgb_bag_raw")) structure(lapply(unclass(r), xgb.load.raw), class = "xgb_bag") else xgb.load.raw(r)
glm_prep <- function(sdat, feats) {
  out <- list()
  for (f in feats) {
    v <- sdat[[f]]
    if (is.character(v) || is.logical(v) || is.factor(v)) {
      v <- as.character(v); v[is.na(v)] <- "missing"
      tab <- sort(table(v), decreasing = TRUE); keep <- names(tab)[tab >= GLM_MIN_CLAIMS]
      if (!length(keep)) next
      levels <- c(keep, if (any(!v %in% keep)) "other")
      if (length(levels) >= 2) out[[f]] <- list(kind = "cat", keep = keep, levels = levels)
    } else {
      v <- as.numeric(v); med <- median(v, na.rm = TRUE); if (is.na(med)) next
      lg <- f %in% GLM_LOG
      x <- if (lg) log1p(pmax(fifelse(is.na(v), med, v), 0)) else fifelse(is.na(v), med, v)
      if (isTRUE(stats::sd(x) > 0)) out[[f]] <- list(kind = "num", med = med, log = lg)
    }
  }
  out
}
glm_frame <- function(prep, nd) {
  cols <- lapply(names(prep), function(f) {
    p <- prep[[f]]
    if (p$kind == "cat") {
      v <- as.character(nd[[f]]); v[is.na(v)] <- "missing"
      v[!v %in% p$keep] <- if ("other" %in% p$levels) "other" else p$keep[1]
      factor(v, levels = p$levels)
    } else { v <- as.numeric(nd[[f]]); v[is.na(v)] <- p$med; if (p$log) log1p(pmax(v, 0)) else v }
  })
  setNames(as.data.frame(cols), names(prep))
}
clamp <- function(x, lim) min(max(x, lim[1]), lim[2])
loglin_trend <- function(yr, value, w) {
  ok <- value > 0 & w > 0
  if (length(unique(yr[ok])) < 2) return(0)
  exp(unname(coef(lm(log(value[ok]) ~ yr[ok], weights = w[ok]))[2])) - 1
}
seed_of <- function(ln, pr, yr, part) SEED + 1000 * match(ln, LINES) + 50 * match(pr, PERILS[[ln]]) + 3 * (yr - 2020) + match(part, c("freq", "sev", "tw"))

# 4. Claim preparation, frequency x severity fit (C5) -------------------------------------------------------------------
prep_claims <- function(cp, sp, train_years, target_year) {
  ex <- sp$sev_exclude_recent_years; ty <- sort(train_years)
  sev_years <- if (ex > 0 && length(ty) > ex) head(ty, length(ty) - ex) else ty
  cp <- copy(cp)[, in_sev := loss_year %in% sev_years]
  if (cp[in_sev == TRUE, .N] < 10) cp[, in_sev := TRUE]
  base <- cp[in_sev == TRUE]
  cap0 <- quantile(base$cost, sp$cap_quantile, names = FALSE)
  g <- 0
  if (tolower(sp$sev_trend) == "estimate") {
    a <- base[, .(m = mean(pmin(cost, cap0)), n = .N), by = loss_year]
    g <- clamp(loglin_trend(a$loss_year, a$m, a$n), SEV_TREND_LIM)
  }
  cp[, cost_t := cost * (1 + g)^(target_year - loss_year)]
  cap <- quantile(cp[in_sev == TRUE, cost_t], sp$cap_quantile, names = FALSE)
  cp[, capped := pmin(cost_t, cap)]
  list(cp = cp, sev_trend = g, cap = cap, load = cp[in_sev == TRUE, sum(cost_t) / sum(capped)], sev_years = sev_years)
}
freq_trend_factor <- function(sp, y, e, yr, w, target_year) {
  if (tolower(sp$freq_trend) != "estimate") return(list(g = 0, f = 1))
  a <- data.table(y, e, yr)[, .(ae = sum(y) / sum(e), n = sum(y)), by = yr]
  g <- clamp(loglin_trend(a$yr, a$ae, a$n), FREQ_TREND_LIM)
  list(g = g, f = (1 + g)^(target_year - weighted.mean(yr, w)))
}
fit_freq_sev <- function(tr, clp_ln, ln, pr, target_year) {
  sp <- spec_row(ln, pr)
  d <- tr[!zero_mask(tr, ln, pr)]
  pc <- prep_claims(clp_ln[peril == pr & row_id %chin% d$row_id], sp, unique(tr$policy_year), target_year)
  n <- pc$cp[, .N, by = row_id][d, on = "row_id", N]; n[is.na(n)] <- 0
  eff <- d$exposure * report_share(ln, pr, d)
  ff <- feats_for(ln, pr, "freq")
  enc_f <- make_enc(d, ff, n, eff)
  X <- to_mat(enc_f, d)
  set.seed(seed_of(ln, pr, target_year, "freq"))
  m_f <- xgb_fit(X, n / eff, eff, policy_holdout(d$policy_id), "count:poisson", sp$freq_max_depth, sp$freq_eta,
                 sp$freq_min_child_weight, mono_vec(enc_f, ln, pr, "freq"), pid = d$policy_id)
  p_in <- predict(m_f, X)
  bal_f <- sum(n) / sum(p_in * eff)
  ft <- freq_trend_factor(sp, n, p_in * eff * bal_f, d$policy_year, eff, target_year)
  rm(X); invisible(gc(verbose = FALSE))
  sv <- pc$cp[in_sev == TRUE]
  sd <- d[sv[, .(row_id, capped)], on = "row_id"]
  fs <- feats_for(ln, pr, "sev")
  sev <- list(type = "mean", mu = if (nrow(sd)) mean(sd$capped) else mean(pc$cp$capped), bal = 1)
  if (nrow(sd) >= MIN_SEV_CLAIMS && length(fs)) {
    if (sp$sev_model == "gamma_gbm") {
      enc_s <- make_enc(sd, fs, sd$capped, rep(1, nrow(sd)))
      Xs <- to_mat(enc_s, sd)
      set.seed(seed_of(ln, pr, target_year, "sev"))
      m_s <- xgb_fit(Xs, sd$capped, rep(1, nrow(sd)), policy_holdout(sd$policy_id), "reg:gamma", sp$sev_max_depth, sp$sev_eta,
                     sp$sev_min_child_weight, mono_vec(enc_s, ln, pr, "sev"), pid = sd$policy_id)
      sev <- list(type = "gbm", enc = enc_s, model = m_s, bal = sum(sd$capped) / sum(predict(m_s, Xs)))
    } else if (sp$sev_model == "gamma_glm") {
      prep <- glm_prep(sd, fs)
      if (length(prep)) {
        fr <- glm_frame(prep, sd); fr$y__ <- sd$capped
        g <- tryCatch(glm(y__ ~ ., data = fr, family = Gamma(link = "log"), mustart = rep(mean(fr$y__), nrow(fr)),
                          control = glm.control(maxit = 100)), error = function(e) NULL)
        if (!is.null(g) && g$converged) { g$data <- NULL; g$model <- NULL
          sev <- list(type = "glm", prep = prep, model = g, bal = sum(fr$y__) / sum(fitted(g)))
        } else log_msg("  ", ln, "/", pr, ": severity GLM failed - mean severity")
      }
    }
  }
  art <- list(type = "freq_sev", line = ln, peril = pr, target_year = target_year, enc_f = enc_f, m_f = m_f,
              bal_f = bal_f, f_trend = ft$f, sev = sev, load = pc$load)
  diag <- data.table(line = ln, peril = pr, rounds_freq = best_iter(m_f), rounds_sev = if (sev$type == "gbm") best_iter(sev$model) else NA_integer_,
                     sev_type = sev$type, claims_freq = sum(n), claims_sev = nrow(sd), bal_freq = bal_f, bal_sev = sev$bal,
                     freq_trend = ft$g, sev_trend = pc$sev_trend, cap = pc$cap, cap_load = pc$load, sev_years = paste(range(pc$sev_years), collapse = "-"))
  list(art = art, diag = diag)
}
sev_predict <- function(sev, nd) switch(sev$type, mean = rep(sev$mu, nrow(nd)),
  gbm = predict(sev$model, to_mat(sev$enc, nd)) * sev$bal,
  glm = unname(predict(sev$model, newdata = glm_frame(sev$prep, nd), type = "response")) * sev$bal)
# Components per row: frequency per exposure-year (ultimate, trended) and severity per claim (x large-loss load)
predict_parts <- function(art, nd) {
  fq <- sv <- numeric(nrow(nd))
  idx <- which(!zero_mask(nd, art$line, art$peril))
  if (length(idx)) {
    sub <- nd[idx]
    fq[idx] <- predict(art$m_f, to_mat(art$enc_f, sub)) * art$bal_f * art$f_trend
    sv[idx] <- sev_predict(art$sev, sub) * art$load
  }
  list(freq = fq, sev = sv, pred = nd$exposure * fq * sv)
}

# 5. Validation on developed (week 1 folds) -------------------------------------------------------------------------------
peril_scores <- list(); diag_val <- list(); rows <- list()
if (!SKIP_VALID) for (ln in LINES) {
  dt <- load_line("developed", "train", ln)
  clp_ln <- clp[line == ln]
  for (vy in VALID_YEARS) {
    tr <- dt[policy_year < vy]; va <- dt[policy_year == vy]
    rp <- data.table(valid_year = vy, line = ln, row_id = va$row_id, policy_id = va$policy_id, exposure = va$exposure)
    for (pr in PERILS[[ln]]) {
      adj <- clp_ln[peril == pr, .(a = sum(cost)), by = row_id][va, on = "row_id", a]; adj[is.na(adj)] <- 0
      act <- list(reported_raw = va[[paste0("y_cost_", pr)]], developed = adj / report_share(ln, pr, va))
      t0 <- Sys.time()
      f <- fit_freq_sev(tr, clp_ln, ln, pr, vy)
      p <- predict_parts(f$art, va)$pred
      set(rp, j = paste0("pred_", pr), value = p)
      for (b in names(act)) set(rp, j = paste0(b, "_", pr), value = act[[b]])
      k <- paste(vy, ln, pr)
      diag_val[[k]] <- f$diag[, `:=`(valid_year = vy, seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))]
      peril_scores[[k]] <- rbindlist(lapply(names(act), function(b) data.table(basis = b, d2 = d2_exp(act[[b]], p, va$exposure),
                                                                                pred_vs_actual = sum(p) / sum(act[[b]]))))[, `:=`(valid_year = vy, line = ln, peril = pr)]
      log_msg(vy, " ", ln, "/", pr, ": D2 raw ", round(peril_scores[[k]][basis == "reported_raw", d2], 4),
              ", developed ", round(peril_scores[[k]][basis == "developed", d2], 4))
    }
    for (b in c("pred", "reported_raw", "developed")) set(rp, j = b, value = Reduce(`+`, lapply(PERILS[[ln]], function(pr) rp[[paste0(b, "_", pr)]])))
    rows[[paste(vy, ln)]] <- rp
    rm(tr, va); invisible(gc(verbose = FALSE))
  }
  rm(dt); invisible(gc(verbose = FALSE))
}
line_scores <- mean_scores <- data.table()
if (!SKIP_VALID) {
  peril_scores <- rbindlist(peril_scores); diag_val <- rbindlist(diag_val)
  rp_all <- rbindlist(rows, fill = TRUE)
  write_w2(rp_all, out_path(STEP, "row_preds.parquet"))
  line_scores <- rbindlist(lapply(c("reported_raw", "developed"), function(b) rbind(
    rp_all[, .(d2 = d2_exp(get(b), pred, exposure), pred_vs_actual = sum(pred) / sum(get(b))), by = .(valid_year, line)],
    rp_all[, .(line = "ALL", d2 = d2_exp(get(b), pred, exposure), pred_vs_actual = sum(pred) / sum(get(b))), by = valid_year])[, basis := b]))
  mean_scores <- line_scores[, .(mean_d2 = mean(d2), d2_2023 = d2[valid_year == 2023], d2_2024 = d2[valid_year == 2024]), by = .(basis, line)]
  save_csv(line_scores, STEP, "line_scores.csv"); save_csv(peril_scores, STEP, "peril_scores.csv"); save_csv(diag_val, STEP, "diagnostics_validation.csv")
  log_msg("Developed validation, mean 2023-24 reported_raw D2: ", paste(mean_scores[basis == "reported_raw", sprintf("%s %.4f", line, mean_d2)], collapse = "; "))
}

# 6. Final fit on developed 2021-24; baseline components for every emerging row ------------------------------------------
dir.create(file.path(ITER_DIR, "fitted"), recursive = TRUE, showWarnings = FALSE)
save_art <- function(art, file) { art$m_f <- raw_model(art$m_f); if (identical(art$sev$type, "gbm")) art$sev$model <- raw_model(art$sev$model); saveRDS(art, file) }
load_art <- function(file) { art <- readRDS(file); art$m_f <- load_model(art$m_f); if (identical(art$sev$type, "gbm")) art$sev$model <- load_model(art$sev$model); art }
diag_final <- list(); base_out <- list(train = list(), test = list()); burn <- list(); replication <- list()
for (ln in LINES) {
  tr <- add_extra(load_line("developed", "train", ln), "train", ln)
  em <- list(train = add_extra(load_line("emerging", "train", ln), "train", ln), test = add_extra(load_line("emerging", "test", ln), "test", ln))
  if (POOLED_YEAR) tr <- rbind(tr, copy(em$train)[policy_year <= POOLED_YEAR][, `:=`(row_id = paste0("E_", row_id), policy_id = paste0("E_", policy_id))], fill = TRUE)
  dte <- add_extra(load_line("developed", "test", ln), "test", ln)
  clp_ln <- clp[line == ln]
  outs <- lapply(em, function(d) data.table(row_id = d$row_id, line = ln, exposure = d$exposure))
  for (pr in PERILS[[ln]]) {
    f <- fit_freq_sev(tr, clp_ln, ln, pr, TARGET_YEAR)
    fa <- file.path(ITER_DIR, "fitted", paste0(ln, "_", pr, ".rds"))
    save_art(f$art, fa)
    for (part in names(em)) {
      pp <- predict_parts(f$art, em[[part]])
      set(outs[[part]], j = paste0("bfreq_", pr), value = pp$freq)
      set(outs[[part]], j = paste0("bsev_", pr), value = pp$sev)
      if (part == "test") replication[[paste(ln, pr)]] <- data.table(line = ln, peril = pr,
        max_abs_diff = max(abs(predict_parts(load_art(fa), em$test)$pred - pp$pred)))
    }
    pd <- predict_parts(f$art, dte)$pred
    eb <- function(part) sum(em[[part]]$exposure * outs[[part]][[paste0("bfreq_", pr)]] * outs[[part]][[paste0("bsev_", pr)]]) / sum(em[[part]]$exposure)
    burn[[paste(ln, pr)]] <- data.table(line = ln, peril = pr, developed_test_burn = sum(pd) / sum(dte$exposure),
                                        emerging_train_burn = eb("train"), emerging_test_burn = eb("test"))
    diag_final[[paste(ln, pr)]] <- f$diag
    log_msg("Final ", ln, "/", pr, ": developed 2025 burn ", round(burn[[paste(ln, pr)]]$developed_test_burn, 2),
            ", emerging test burn at developed level ", round(burn[[paste(ln, pr)]]$emerging_test_burn, 2))
  }
  for (part in names(em)) base_out[[part]][[ln]] <- outs[[part]]
  rm(tr, em, dte); invisible(gc(verbose = FALSE))
}
for (part in c("train", "test")) write_w2(rbindlist(base_out[[part]], fill = TRUE), file.path(W2$data, basename(ITER_DIR), sprintf("baseline_emerging_%s.parquet", part)))
diag_final <- rbindlist(diag_final); burn <- rbindlist(burn); replication <- rbindlist(replication)
save_csv(diag_final, STEP, "diagnostics_final.csv"); save_csv(burn, STEP, "baseline_burn.csv"); save_csv(replication, STEP, "replication_check.csv")
save_csv(fmap, STEP, "features_used.csv"); save_csv(zr_check, STEP, "structural_zero_check.csv"); save_csv(edit_log, STEP, "workbook_edits.csv")
if (any(replication$max_abs_diff > 1e-6)) warning("Reloaded models do not reproduce the predictions")

# 7. Model card and logs -----------------------------------------------------------------------------------------------
W1_C5 <- 0.1026
card <- c("# Week 2 developed baseline (C5 engine on shared features)", "",
          sprintf("Run %s, %s bag(s), workbook `%s` (MD5 `%s`). Run time %.1f min.", ts_sgt(), BAGS, CFG_FILE, unname(tools::md5sum(CFG_FILE)),
                  as.numeric(difftime(Sys.time(), T0, units = "mins"))), "",
          if (nrow(mean_scores)) c("## Developed validation (week 1 folds; D2 vs one rate per exposure-year)", "",
                                   md_table(dcast(line_scores, basis + valid_year ~ line, value.var = "d2"), 4),
                                   md_table(mean_scores, 4),
                                   sprintf("Week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW): ALL reported_raw mean 0.1026. Shared features, 1 bag, freq x sev: %.4f.",
                                           mean_scores[basis == "reported_raw" & line == "ALL", mean_d2]), "",
                                   "## Peril scores (mean 2023-24)", "", md_table(dcast(peril_scores, line + peril ~ basis, value.var = "d2", fun.aggregate = mean), 4)) else "Validation skipped.",
          "## Final fit diagnostics", "", md_table(diag_final, 3), "## Baseline burn (developed level)", "", md_table(burn, 2),
          "## Workbook edits", "", md_table(edit_log))
writeLines(card, file.path(ITER_DIR, "model_card.md")); track_output(file.path(ITER_DIR, "model_card.md"))

if (IS_MAIN) add_decision("D016", "5", "Baseline = C5 engine refit on shared features, 1 bag, frequency x severity for every peril (no Tweedie), voluntary_excess in every peril",
             "C5 as-is with 5 bags and Tweedie for BI/contents EoW (no separate frequency/severity to adjust); simpler GLM baseline",
             "week2/models/baseline/model_card.md", "decided")
if (IS_MAIN) add_decision("D017", "5", "Developed validation 'developed' actuals divided by the step 4 chain-ladder share (C5 used the A0 ECDF share for that basis)",
             "A0 ECDF share", "week2/output/05_baseline/line_scores.csv", "decided")
kl <- c(if (nrow(mean_scores)) sprintf("- Developed validation mean 2023-24 D2, reported_raw: %s; developed: %s (week 1 C5 ALL reported_raw 0.1026).",
                                      paste(mean_scores[basis == "reported_raw", sprintf("%s %.4f", line, mean_d2)], collapse = ", "),
                                      paste(mean_scores[basis == "developed", sprintf("%s %.4f", line, mean_d2)], collapse = ", ")),
        sprintf("- Replication of saved models: max abs diff %.2e.", max(replication$max_abs_diff)),
        sprintf("- Emerging test burn at developed level, by line: %s.", paste(burn[, .(b = sum(emerging_test_burn)), by = line][, sprintf("%s %.1f", line, b)], collapse = ", ")))
if (IS_MAIN) update_step_log("5", "Developed baseline", kl) else update_step_log(paste0("5-", basename(ITER_DIR)), paste("Baseline variant", basename(ITER_DIR)), kl)
end_script()
