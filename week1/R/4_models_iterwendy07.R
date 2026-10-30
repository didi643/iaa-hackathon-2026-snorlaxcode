# 4_models_iterwendy07.R ------------------------------------------------------------------------------
# WENDY 7: WENDY 4 engine with a switchable IBNR treatment (experiment backlog A, week1/docs/HANDOFF_claude_code.md),
# validated on the local protocol (handoff section 3) instead of WENDY 4's developed-only validation.
#
#   ibnr_method   how the frequency volume (exposure x reported share) is built for each training row:
#     report_share       A0 = WENDY 4: ECDF of the peril's 2021-22 report lags at the row's mid-date
#     report_share_days  A1: same ECDF averaged over every day of the row's period (Code_Review CR18)
#     chain_ladder       A2: reported-count triangle per peril (loss quarter x development quarter, 2021-24 losses),
#                        volume-weighted age-to-age factors, tail 1 after the longest lag; share of each loss
#                        quarter = 1 / CDF to ultimate, row share = day-weighted mean over the quarters it covers
#   Validation    fit 2021-22 -> 2023 and 2021-23 -> 2024; the same predictions are scored on reported_raw (booked
#                 y_cost_<peril>), reported_adj (WENDY 4 claim basis) and developed (reported_adj / A0 report share,
#                 fixed for every method so variants are scored on the same actuals). Row predictions (line and
#                 peril) are written with week1/R/oof_io.R to week1/output/4_check_reported/wendy07_<tag>/.
#   Method mix    per peril freq_sev / tweedie taken from METHOD_MIX (default: WENDY 4's chosen_method.csv), so a
#                 run changes only the IBNR treatment; METHOD_MIX=auto picks on mean developed D2 as WENDY 4.
#   Final fit     only with FINAL_FIT=1: refit 2021-24, predict 2025, archive the submission file (not provisional,
#                 not submitted), reload the saved models and check they reproduce it.
#
# Run:      IBNR_METHOD=chain_ladder RUN_TAG=a2 Rscript week1/R/4_models_iterwendy07.R
#           (RUN_TAG defaults to the method; FAST=1 smoke test; FINAL_FIT=1 adds the 2025 fit)
# Outputs:  week1/models/wendy_iteration_07/<tag>/ (model card, scores, IBNR shares), week1/output/4_check_reported/wendy07_<tag>/
#
# --- WENDY 4 description (unchanged engine) ---
# WENDY 4: per-peril frequency x severity models driven by the assumption workbook
# (week1/docs/assumptions_wendy04.xlsx - sheets Features_<line>, Model_Spec, Structural_Zeros, Settings).
#
#   Target      claim cost = incurred - recoveries (repudiated = 0, nil claims dropped); expected recoveries
#               deducted from OPEN claims of perils that recover; single claims limited (outlier_claim_limit).
#   Frequency   Poisson GBM per peril on positive-claim counts; volume = exposure x reported share (IBNR offset,
#               from each peril's report-lag pattern) so the model learns ULTIMATE frequency.
#   Severity    Gamma GBM (data-rich perils) or Gamma GLM on few factors (sparse / heavy perils) on claims capped
#               at a per-peril quantile and trended to the prediction year; excess over the cap -> loading.
#   Challenger  Tweedie GBM per peril on the same capped, trended, IBNR-offset target.
#   Selection   per peril, the better of freq_sev / tweedie by mean Tweedie D2 over the out-of-time folds
#               (Settings model_selection = auto), scored against DEVELOPED actuals.
#   Guards      structural zeros (cover not bought -> 0) applied only if training shows no claims there.
#   History     prior-year claims (own policy, customer's other lines) known by the end of the prior year.
#   Output      week1/output/submission/submission_provisional.csv + archived copy, week1/models/wendy_iteration_04/ model card.
#
# Run:      Rscript week1/R/4_models_iterwendy04.R
#           quick smoke test: FAST=1 Rscript week1/R/4_models_iterwendy04.R   (fewer rounds, higher learning rate)
#           other workbook:   ASSUMPTIONS_XLSX=path/to.xlsx Rscript week1/R/4_models_iterwendy04.R
# Needs:    week1/R/0_setup.R, data/week_1/clean/* from week1/R/2_clean.R, packages xgboost (>= 3.0, as WENDY 3) and readxl.

source("week1/R/0_setup.R")
source("week1/R/oof_io.R")
for (p in c("xgboost", "readxl")) if (!requireNamespace(p, quietly = TRUE)) stop("Install package '", p, "'")
suppressPackageStartupMessages({ library(xgboost); library(readxl) })

STEP <- "4_models"
ITERATION <- "WENDY 7"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
CFG_FILE <- Sys.getenv("ASSUMPTIONS_XLSX", "week1/docs/assumptions_wendy07.xlsx")
FAST <- Sys.getenv("FAST", "0") == "1"
FINAL_FIT <- Sys.getenv("FINAL_FIT", "0") == "1"
FINAL_METHODS <- Sys.getenv("FINAL_METHODS", "chosen")   # chosen | all (every method of every peril, for blends)
IBNR_METHODS <- c("report_share", "report_share_days", "chain_ladder")
if (!file.exists(CFG_FILE)) stop("Assumption workbook not found: ", CFG_FILE)
T0 <- Sys.time()

# 0. Read the assumption workbook ---------------------------------------------------------------------------
rd <- function(sheet) {
  x <- as.data.table(read_excel(CFG_FILE, sheet = sheet, col_types = "text"))
  x[!is.na(x[[1]])]
}
settings <- rd("Settings")
S <- setNames(settings$value, settings$key)
s_get <- function(k) {
  if (!k %in% names(S) || is.na(S[[k]])) stop("Setting '", k, "' missing in ", CFG_FILE)
  S[[k]]
}
s_num <- function(k) {
  v <- suppressWarnings(as.numeric(s_get(k)))
  if (is.na(v)) stop("Setting '", k, "' is not numeric")
  v
}
s_vec <- function(k) trimws(strsplit(s_get(k), ",", fixed = TRUE)[[1]])
s_yes <- function(k) toupper(s_get(k)) == "Y"

VALID_YEARS <- as.integer(s_vec("valid_years"))
TARGET_YEAR <- as.integer(s_num("target_year"))
LAG_YEARS <- as.integer(s_vec("lag_loss_years"))
OUTLIER_LIMIT <- s_num("outlier_claim_limit")
SEV_TREND_LIM <- c(s_num("sev_trend_min"), s_num("sev_trend_max"))
FREQ_TREND_LIM <- c(s_num("freq_trend_min"), s_num("freq_trend_max"))
SELECTION <- tolower(s_get("model_selection"))
stopifnot(SELECTION %in% c("auto", "freq_sev", "tweedie"))
MAX_ROUNDS <- if (FAST) 300 else s_num("max_rounds")
ETA_MULT <- if (FAST) 2 else 1
ES_ROUNDS <- s_num("early_stopping_rounds")
HOLD_SHARE <- s_num("holdout_share")
SUBSAMPLE <- s_num("subsample")
COLSAMPLE <- s_num("colsample_bytree")
LAMBDA <- s_num("reg_lambda")
GLM_MIN_CLAIMS <- s_num("glm_min_level_claims")
GLM_LOG <- s_vec("glm_log_features")
SCORE_P <- s_num("score_tweedie_p")
NTHREAD <- as.integer(s_num("nthread"))
if (NTHREAD <= 0) NTHREAD <- max(1L, parallel::detectCores())
MIN_SEV_CLAIMS <- 200   # fewer claims than this in a training window -> severity = mean

# WENDY 7 settings: environment overrides the workbook
IBNR_METHOD <- tolower(Sys.getenv("IBNR_METHOD", if ("ibnr_method" %in% names(S)) S[["ibnr_method"]] else "report_share"))
if (!IBNR_METHOD %in% IBNR_METHODS) stop("ibnr_method must be one of ", paste(IBNR_METHODS, collapse = ", "))
RUN_TAG <- Sys.getenv("RUN_TAG", IBNR_METHOD)
CHECK_TAG <- paste0("wendy07_", RUN_TAG)
ITER_DIR <- file.path("week1", "models", "wendy_iteration_07", RUN_TAG)
# Workbook-or-environment settings (environment wins): ibnr_override, bags, method_mix (= "sheet" reads sheet Method_Mix)
s_opt <- function(k, default) { e <- Sys.getenv(toupper(k), ""); if (nzchar(e)) e else if (k %in% names(S) && !is.na(S[[k]])) S[[k]] else default }
METHOD_MIX <- s_opt("method_mix", file.path(PATHS$output, "4_check_reported", "4_models_iterwendy04", "chosen_method.csv"))
if (!METHOD_MIX %in% c("auto", "sheet") && !file.exists(METHOD_MIX)) stop("METHOD_MIX file not found: ", METHOD_MIX, " (or set METHOD_MIX=auto)")

spec <- rd("Model_Spec")[line %in% LINES]
num_cols <- c("cap_quantile", "sev_exclude_recent_years", "freq_max_depth", "freq_eta", "freq_min_child_weight",
              "sev_max_depth", "sev_eta", "sev_min_child_weight", "tweedie_p")
spec[, (num_cols) := lapply(.SD, as.numeric), .SDcols = num_cols]
need <- unlist(lapply(LINES, function(ln) paste(ln, PERILS[[ln]])))
miss <- setdiff(need, spec[, paste(line, peril)])
if (length(miss)) stop("Model_Spec has no row for: ", paste(miss, collapse = ", "))
# WENDY 7: SPEC_EDITS="motor/bodily_injury:freq_trend=none,sev_trend=none" overrides Model_Spec cells per peril
for (ed in trimws(strsplit(Sys.getenv("SPEC_EDITS", ""), ";", fixed = TRUE)[[1]])) {
  if (!nzchar(ed)) next
  key <- strsplit(sub(":.*$", "", ed), "/", fixed = TRUE)[[1]]
  for (kv in strsplit(sub("^[^:]*:", "", ed), ",", fixed = TRUE)[[1]]) {
    k <- trimws(sub("=.*$", "", kv)); v <- trimws(sub("^[^=]*=", "", kv))
    if (!k %in% names(spec)) stop("SPEC_EDITS: unknown Model_Spec column ", k)
    i <- which(spec$line == key[1] & spec$peril == key[2])
    if (!length(i)) stop("SPEC_EDITS: no Model_Spec row ", ed)
    set(spec, i = i, j = k, value = if (is.numeric(spec[[k]])) as.numeric(v) else v)
  }
  log_msg("Model_Spec edit: ", ed)
}
spec_row <- function(ln, pr) spec[line == ln & peril == pr][1]

fmap <- rbindlist(lapply(LINES, function(ln) {
  x <- rd(paste0("Features_", tools::toTitleCase(ln)))
  miss <- setdiff(c("column", "use", "mono_freq", "mono_sev", PERILS[[ln]]), names(x))
  if (length(miss)) stop("Features_", tools::toTitleCase(ln), " lacks columns: ", paste(miss, collapse = ", "))
  x <- x[toupper(trimws(use)) == "Y", c("column", "mono_freq", "mono_sev", PERILS[[ln]]), with = FALSE]
  long <- melt(x, id.vars = c("column", "mono_freq", "mono_sev"), variable.name = "peril", value.name = "code",
               variable.factor = FALSE)
  long[, `:=`(line = ln, code = toupper(trimws(code)))][code %in% c("B", "F", "S")]
}))
fmap[, `:=`(mono_freq = as.integer(fifelse(is.na(mono_freq), "0", mono_freq)),
            mono_sev = as.integer(fifelse(is.na(mono_sev), "0", mono_sev)))]
if (!s_yes("history_features")) fmap <- fmap[!startsWith(column, "hist_")]

# WENDY 7 feature edits on top of the workbook, one experiment per string:
#   FEATURE_EDITS="all:voluntary_excess=B; motor/bodily_injury:licence_points=F; buildings:x=-" (code B/F/S, - = drop)
#   HIST_V2=1 adds SAM-style history (section 2b) to the perils it is meant for.
HIST_V2 <- Sys.getenv("HIST_V2", "0") == "1"
MONO_DEFAULT <- c(voluntary_excess = -1L)                         # monotone frequency sign when a column is new to a line
FEATURE_EDITS <- Sys.getenv("FEATURE_EDITS", "")
edit_list <- trimws(strsplit(FEATURE_EDITS, ";", fixed = TRUE)[[1]])
if (HIST_V2) {
  edit_list <- c(edit_list, "buildings/flood:hist_addr_flood=F", "contents/flood:hist_addr_flood=F",
                 "buildings/escape_of_water:hist_addr_water=F", "contents/escape_of_water:hist_addr_water=F",
                 "buildings/subsidence:hist_addr_subs=F", "buildings/storm:hist_addr_storm=F",
                 "all:hist_policy_rel=F")
}
for (ed in edit_list[nzchar(edit_list)]) {
  m <- regmatches(ed, regexec("^([a-z_/]+):([a-z0-9_]+)=([BFS-])$", ed))[[1]]
  if (!length(m)) stop("Bad FEATURE_EDITS entry: ", ed)
  scope <- strsplit(m[2], "/", fixed = TRUE)[[1]]
  targets <- rbindlist(lapply(LINES, function(ln) data.table(line = ln, peril = PERILS[[ln]])))
  if (scope[1] != "all") targets <- targets[line == scope[1]]
  if (length(scope) > 1) targets <- targets[peril == scope[2]]
  if (!nrow(targets)) stop("FEATURE_EDITS scope matches no peril: ", ed)
  for (i in seq_len(nrow(targets))) {
    ln <- targets$line[i]; pr <- targets$peril[i]
    fmap <- fmap[!(line == ln & peril == pr & column == m[3])]
    if (m[4] == "-") next
    mono <- fmap[line == ln & column == m[3]][1]
    mf <- if (nrow(mono) && !is.na(mono$mono_freq)) mono$mono_freq else if (m[3] %in% names(MONO_DEFAULT)) MONO_DEFAULT[[m[3]]] else 0L
    ms <- if (nrow(mono) && !is.na(mono$mono_sev)) mono$mono_sev else 0L
    fmap <- rbind(fmap, data.table(column = m[3], mono_freq = mf, mono_sev = ms, peril = pr, code = m[4], line = ln), use.names = TRUE)
  }
}
if (length(edit_list)) log_msg("Feature edits: ", paste(edit_list, collapse = "; "))
feats_for <- function(ln, pr, part) {
  codes <- switch(part, freq = c("F", "B"), sev = c("S", "B"), all = c("F", "S", "B"))
  unique(fmap[line == ln & peril == pr & code %in% codes, column])
}

zero_rules <- rd("Structural_Zeros")[line %in% LINES]
log_msg("Workbook ", CFG_FILE, ": ", nrow(fmap), " feature-peril uses, ", nrow(spec), " perils, ",
        nrow(zero_rules), " structural-zero rules", if (FAST) " [FAST mode]" else "")

# 1. Claims: target basis -------------------------------------------------------------------------------------
cm <- read_clean("claims_matched")
cl <- cm[counts == TRUE & !is.na(row_id)]
rm(cm)
cl[, cost := net_cost]                                           # incurred - recoveries
recovery_tbl <- cl[status == "closed", .(closed_claims = .N, recovery_ratio = sum(recoveries) / sum(incurred_to_date)),
                   by = .(line, peril)][recovery_ratio > 0]
if (s_yes("open_claim_recovery_adjust") && nrow(recovery_tbl)) {
  cl[recovery_tbl, on = .(line, peril), rr := i.recovery_ratio]
  cl[status == "open" & !is.na(rr) & recoveries == 0, cost := incurred_to_date * (1 - rr)]
  cl[, rr := NULL]
}
n_outlier <- cl[cost > OUTLIER_LIMIT, .N]
cl[, cost := pmin(pmax(cost, 0), OUTLIER_LIMIT)]
clp <- cl[cost > 0, .(row_id, line, peril, status, cost, loss_date, report_date,
                      loss_year = year(loss_date), lag = as.numeric(report_date - loss_date))]
rm(cl); invisible(gc(verbose = FALSE))
log_msg("Positive claims: ", nrow(clp), " | claims limited at ", format(OUTLIER_LIMIT, big.mark = ",", scientific = FALSE), ": ", n_outlier)

# Reporting pattern per peril: ECDF of report lags (loss years LAG_YEARS); share reported at the valuation date
lag_cdf <- list()
for (ln in LINES) for (pr in PERILS[[ln]]) {
  lags <- clp[line == ln & peril == pr & loss_year %in% LAG_YEARS & lag >= 0, lag]
  lag_cdf[[paste(ln, pr)]] <- if (length(lags) >= 30) ecdf(lags) else function(x) rep(1, length(x))
}
MIN_SHARE <- 0.05
# A0 (WENDY 4): share at the row's mid-date. Also the fixed basis of the "developed" actuals in every variant.
report_share_mid <- function(ln, pr, dt) {
  mid <- as.numeric(dt$period_start) + as.numeric(dt$period_end - dt$period_start) / 2
  pmax(lag_cdf[[paste(ln, pr)]](as.numeric(VALUATION_DATE) - mid), MIN_SHARE)
}

# A1: the same ECDF averaged over every day of the row's period. G[t + 1] = sum of F(0..t), so the mean of
# F(V - d) over days d = start..end is (G(V - start) - G(V - end - 1)) / days.
V_NUM <- as.numeric(VALUATION_DATE)
cum_cdf <- lapply(lag_cdf, function(F) cumsum(F(0:(V_NUM - as.numeric(as.Date(paste0(min(TRAIN_YEARS), "-01-01")))))))
report_share_days <- function(ln, pr, dt) {
  G <- cum_cdf[[paste(ln, pr)]]
  gs <- function(t) ifelse(t < 0, 0, G[pmin(t, length(G) - 1) + 1])
  s <- as.numeric(dt$period_start)
  e <- pmin(as.numeric(dt$period_end), V_NUM)
  days <- pmax(e - s + 1, 1)
  pmax((gs(V_NUM - s) - gs(V_NUM - e - 1)) / days, MIN_SHARE)
}

# A2: chain ladder on reported claim counts per peril, loss quarter x development quarter (quarter 0 = 2021 Q1)
quarter_index <- function(d) (year(d) - min(TRAIN_YEARS)) * 4L + (month(d) - 1L) %/% 3L
N_Q <- length(TRAIN_YEARS) * 4L
q_start <- seq(as.Date(paste0(min(TRAIN_YEARS), "-01-01")), by = "quarter", length.out = N_Q)
q_end <- c(q_start[-1] - 1, VALUATION_DATE)
cl_tri <- list()
cl_share <- list()
for (ln in LINES) for (pr in PERILS[[ln]]) {
  k <- paste(ln, pr)
  x <- clp[line == ln & peril == pr & loss_year %in% TRAIN_YEARS & lag >= 0,
           .(i = quarter_index(loss_date), dev = quarter_index(report_date) - quarter_index(loss_date))]
  if (nrow(x) < 30) { cl_share[[k]] <- rep(1, N_Q); next }
  inc <- matrix(0, N_Q, N_Q)
  cnt <- x[, .N, by = .(i, dev)]
  inc[cbind(cnt$i + 1L, cnt$dev + 1L)] <- cnt$N
  cum <- t(apply(inc, 1, cumsum))
  f <- vapply(seq_len(N_Q - 1), function(j) {                     # factor from dev j-1 to dev j (0-based)
    r <- seq_len(N_Q - j)                                         # loss quarters observed at dev j
    den <- sum(cum[r, j]); if (den > 0) sum(cum[r, j + 1]) / den else 1
  }, numeric(1))
  cdf <- vapply(seq_len(N_Q), function(i) prod(f[seq_len(N_Q - 1) >= N_Q - i + 1]), numeric(1))
  cl_share[[k]] <- pmax(1 / cdf, MIN_SHARE)
  cl_tri[[k]] <- data.table(line = ln, peril = pr, loss_quarter = format(q_start), dev_quarter_latest = N_Q - seq_len(N_Q),
                            reported = cum[cbind(seq_len(N_Q), N_Q - seq_len(N_Q) + 1L)], cdf_to_ult = cdf,
                            share = 1 / cdf, dev_k = 0:(N_Q - 1), age_to_age_k_to_k1 = c(f, NA))
}
cl_tri <- rbindlist(cl_tri)
report_share_cl <- function(ln, pr, dt) {
  s <- as.numeric(dt$period_start); e <- pmin(as.numeric(dt$period_end), V_NUM)
  num <- den <- numeric(nrow(dt))
  sh <- cl_share[[paste(ln, pr)]]
  for (q in seq_len(N_Q)) {
    ov <- pmax(0, pmin(e, as.numeric(q_end[q])) - pmax(s, as.numeric(q_start[q])) + 1)
    num <- num + ov * sh[q]; den <- den + ov
  }
  pmax(fifelse(den > 0, num / den, 1), MIN_SHARE)
}

share_fun <- list(report_share = report_share_mid, report_share_days = report_share_days, chain_ladder = report_share_cl)
# IBNR_OVERRIDE="buildings/subsidence=report_share_days,..." sets the method of single perils (sparse triangles)
ov <- trimws(strsplit(s_opt("ibnr_override", ""), ",", fixed = TRUE)[[1]])
ov <- ov[nzchar(ov)]
IBNR_PERIL <- setNames(sub("^.*=", "", ov), sub("/", " ", sub("=.*$", "", ov)))
if (!all(IBNR_PERIL %in% IBNR_METHODS)) stop("IBNR_OVERRIDE methods must be one of ", paste(IBNR_METHODS, collapse = ", "))
report_share <- function(ln, pr, dt) {
  k <- paste(ln, pr)
  share_fun[[if (k %in% names(IBNR_PERIL)) IBNR_PERIL[[k]] else IBNR_METHOD]](ln, pr, dt)
}
log_msg("IBNR method: ", IBNR_METHOD, if (length(ov)) paste0(" (overrides: ", paste(ov, collapse = ", "), ")") else "")

# 2. Prior-year claims history known at renewal -------------------------------------------------------------------
id_cols <- c("row_id", "policy_id", "customer_id", "policy_year")
rowmap <- rbindlist(lapply(LINES, function(ln) {
  f <- file.path(PATHS$clean, paste0("train_", ln, ".parquet"))
  if (file.exists(f)) as.data.table(arrow::read_parquet(f, col_select = id_cols))
  else read_clean(paste0("train_", ln))[, ..id_cols]
}))
hc <- merge(clp[year(report_date) <= loss_year, .(row_id, line, hist_year = loss_year)],
            rowmap[, .(row_id, policy_id, customer_id)], by = "row_id")
pol_cnt <- hc[, .(n = .N), by = .(policy_id, hist_year)]
cust_cnt <- hc[, .(n = .N), by = .(customer_id, line, hist_year)]
pol_year_key <- unique(rowmap[, paste(policy_id, policy_year)])
rm(hc); invisible(gc(verbose = FALSE))

add_history <- function(dt, ln) {
  dt[, hist_year := policy_year - 1L]
  dt[pol_cnt, on = .(policy_id, hist_year), hist_policy_claims_prev := as.numeric(i.n)]
  dt[is.na(hist_policy_claims_prev), hist_policy_claims_prev := 0]
  dt[!paste(policy_id, hist_year) %chin% pol_year_key | hist_year < min(TRAIN_YEARS), hist_policy_claims_prev := NA]
  oc <- cust_cnt[line != ln, .(n = sum(n)), by = .(customer_id, hist_year)]
  dt[oc, on = .(customer_id, hist_year), hist_customer_claims_other_lines_prev := as.numeric(i.n)]
  dt[is.na(hist_customer_claims_other_lines_prev), hist_customer_claims_other_lines_prev := 0]
  dt[hist_year < min(TRAIN_YEARS), hist_customer_claims_other_lines_prev := NA]
  dt[, hist_year := NULL]
  invisible(dt)
}
# 2b. HIST_V2: SAM-style cumulative history, counting claims reported before 1 Jan of the row's policy year
# (what is known at quote time; 31 Dec 2024 for the 2025 test rows). Address counts by peril group over buildings
# and contents claims; own-policy claim relativity with credibility (HIST_CRED_YEARS of expected claims added).
HIST_CRED_YEARS <- 2
if (HIST_V2) {
  rowmap2 <- rbindlist(lapply(LINES, function(ln) {
    as.data.table(arrow::read_parquet(file.path(PATHS$clean, paste0("train_", ln, ".parquet")),
                                      col_select = c("row_id", "policy_id", "address_id", "policy_year", "exposure")))[, line := ln]
  }))
  hk <- merge(clp[, .(row_id, peril, report_date)], rowmap2[, .(row_id, line, policy_id, address_id)], by = "row_id")
  f0 <- sapply(LINES, function(ln) hk[line == ln, .N] / rowmap2[line == ln, sum(exposure)])
  addr_group <- c(flood = "flood", escape_of_water = "water", subsidence = "subs", storm = "storm")
  hist_tab <- lapply(setNames(2021:2025, 2021:2025), function(Y) {
    known <- hk[report_date < as.Date(sprintf("%d-01-01", Y))]
    ka <- known[line %in% c("buildings", "contents") & peril %in% names(addr_group), .(address_id, peril)]
    ka <- ka[, grp := paste0("hist_addr_", addr_group[peril])][, .N, by = .(address_id, grp)]
    list(pol = known[, .(n = .N), by = .(line, policy_id)],
         exp = rowmap2[policy_year < Y, .(e = sum(exposure)), by = .(line, policy_id)],
         addr = if (nrow(ka)) dcast(ka, address_id ~ grp, value.var = "N", fill = 0) else data.table(address_id = character()))
  })
}
add_history_v2 <- function(dt, ln) {
  parts <- lapply(names(hist_tab), function(Y) {
    h <- hist_tab[[Y]]
    d <- dt[policy_year == as.integer(Y), .(row_id, policy_id, address_id)]
    if (!nrow(d)) return(NULL)
    d <- merge(d, h$pol[line == ln, .(policy_id, n)], by = "policy_id", all.x = TRUE)
    d <- merge(d, h$exp[line == ln, .(policy_id, e)], by = "policy_id", all.x = TRUE)
    merge(d, h$addr, by = "address_id", all.x = TRUE)
  })
  hd <- rbindlist(parts, fill = TRUE)
  for (cn in paste0("hist_addr_", c("flood", "water", "subs", "storm"))) {
    if (!cn %in% names(hd)) hd[, (cn) := 0]
    set(hd, which(is.na(hd[[cn]])), cn, 0); set(hd, j = cn, value = pmin(hd[[cn]], 3))
  }
  hd[is.na(n), n := 0][is.na(e), e := 0]
  hd[, hist_policy_rel := (pmin(n, 5) + HIST_CRED_YEARS * f0[[ln]]) / (f0[[ln]] * (pmin(e, 4) + HIST_CRED_YEARS))]
  cols <- c("hist_addr_flood", "hist_addr_water", "hist_addr_subs", "hist_addr_storm", "hist_policy_rel")
  dt[hd, on = "row_id", (cols) := mget(paste0("i.", cols))]
  invisible(dt)
}
load_line <- function(name, ln) {
  dt <- read_clean(name)
  if (s_yes("history_features")) add_history(dt, ln)
  if (HIST_V2) add_history_v2(dt, ln)
  miss <- setdiff(fmap[line == ln, unique(column)], names(dt))
  if (length(miss)) stop(name, ": workbook features not in data: ", paste(miss, collapse = ", "))
  dt
}

# 3. Structural zeros: applied only where training has no positive claims ----------------------------------------
rule_mask <- function(dt, rules) {
  m <- rep(FALSE, nrow(dt))
  for (i in seq_len(nrow(rules))) {
    vals <- toupper(trimws(strsplit(rules$values[i], ",", fixed = TRUE)[[1]]))
    m <- m | toupper(as.character(dt[[rules$column[i]]])) %chin% vals
  }
  m
}
zr_check <- rbindlist(lapply(LINES, function(ln) {
  rules <- zero_rules[line == ln]
  if (!nrow(rules)) return(NULL)
  dt <- read_clean(paste0("train_", ln))
  rbindlist(lapply(seq_len(nrow(rules)), function(i) {
    r <- rules[i]
    if (!r$column %in% names(dt)) return(r[, .(line, peril, column, values, rows = NA_integer_, claims = NA_integer_, active = FALSE)])
    m <- rule_mask(dt, r)
    n_cl <- clp[line == ln & peril == r$peril & row_id %chin% dt$row_id[m], .N]
    r[, .(line, peril, column, values, rows = sum(m), claims = n_cl, active = n_cl == 0 & sum(m) > 0)]
  }))
}))
if (nrow(zr_check[active == FALSE])) warning("Structural-zero rules NOT applied (claims found): ",
                                             paste(zr_check[active == FALSE, paste(line, peril, column)], collapse = "; "))
zero_mask <- function(dt, ln, pr) {
  rules <- zr_check[line == ln & peril == pr & active == TRUE]
  if (!nrow(rules)) rep(FALSE, nrow(dt)) else rule_mask(dt, rules)
}

# 4. Helpers: encoding, xgboost, GLM, trend, metrics -------------------------------------------------------------
make_enc <- function(dt, feats, y, w) {
  is_cat <- vapply(feats, function(f) is.character(dt[[f]]) || is.factor(dt[[f]]), logical(1))
  lv <- lapply(setNames(feats[is_cat], feats[is_cat]), function(f) {
    tb <- data.table(x = as.character(dt[[f]]), y = y, w = w)[, .(rate = sum(y) / sum(w)), by = x]
    tb[order(rate, x), x]                                        # levels ordered by training rate
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
  m[is.na(m) | enc$feats %in% names(enc$lv)] <- 0L              # no constraints on text categories
  m
}
policy_holdout <- function(pid) {
  u <- unique(pid)
  pid %chin% sample(u, max(1L, round(HOLD_SHARE * length(u))))
}
# BAGS > 1 (WENDY 7): average BAGS boosters, each with its own policy holdout and xgboost seed. Bag 1 is the WENDY 4
# fit (same holdout and seed), so BAGS = 1 reproduces it exactly. A bag predicts through predict.xgb_bag().
BAGS <- as.integer(s_opt("bags", "1"))
xgb_fit <- function(X, label, w, hold, objective, depth, eta, mcw, mono = NULL, extra = list(), pid = NULL) {
  one <- function(hold, seed) {
    dtr <- xgb.DMatrix(X[!hold, , drop = FALSE], label = label[!hold], weight = w[!hold], nthread = NTHREAD)
    dva <- xgb.DMatrix(X[hold, , drop = FALSE], label = label[hold], weight = w[hold], nthread = NTHREAD)
    params <- c(list(objective = objective, learning_rate = eta * ETA_MULT, max_depth = depth, min_child_weight = mcw,
                     subsample = SUBSAMPLE, colsample_bytree = COLSAMPLE, reg_lambda = LAMBDA,
                     tree_method = "hist", nthread = NTHREAD, seed = seed), extra)
    if (!is.null(mono) && any(mono != 0)) params$monotone_constraints <- paste0("(", paste(mono, collapse = ","), ")")
    xgb.train(params = params, data = dtr, nrounds = MAX_ROUNDS, evals = list(holdout = dva),
              early_stopping_rounds = ES_ROUNDS, verbose = 0)
  }
  m1 <- one(hold, SEED)
  if (BAGS <= 1 || is.null(pid)) return(m1)
  structure(c(list(m1), lapply(2:BAGS, function(b) one(policy_holdout(pid), SEED + b))), class = "xgb_bag")
}
predict.xgb_bag <- function(object, newdata, ...) {
  p <- vapply(unclass(object), function(m) predict(m, newdata), numeric(nrow(newdata)))
  if (is.null(dim(p))) mean(p) else rowMeans(p)
}
best_iter <- function(m) {
  if (inherits(m, "xgb_bag")) m <- m[[1]]
  b <- xgb.attr(m, "best_iteration"); if (is.null(b)) NA_integer_ else as.integer(b)
}
raw_model <- function(m) if (inherits(m, "xgb_bag")) structure(lapply(unclass(m), xgb.save.raw), class = "xgb_bag_raw") else xgb.save.raw(m)
load_model <- function(r) if (inherits(r, "xgb_bag_raw")) structure(lapply(unclass(r), xgb.load.raw), class = "xgb_bag") else xgb.load.raw(r)

glm_prep <- function(sdat, feats) {
  out <- list()
  for (f in feats) {
    v <- sdat[[f]]
    if (is.character(v) || is.logical(v) || is.factor(v)) {
      v <- as.character(v); v[is.na(v)] <- "missing"
      tab <- sort(table(v), decreasing = TRUE)
      keep <- names(tab)[tab >= GLM_MIN_CLAIMS]
      if (!length(keep)) next
      levels <- c(keep, if (any(!v %in% keep)) "other")
      if (length(levels) >= 2) out[[f]] <- list(kind = "cat", keep = keep, levels = levels)
    } else {
      v <- as.numeric(v)
      med <- median(v, na.rm = TRUE); if (is.na(med)) next
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
    } else {
      v <- as.numeric(nd[[f]]); v[is.na(v)] <- p$med
      if (p$log) log1p(pmax(v, 0)) else v
    }
  })
  setNames(as.data.frame(cols), names(prep))
}
clamp <- function(x, lim) min(max(x, lim[1]), lim[2])
loglin_trend <- function(yr, value, w) {          # annual rate of change from a weighted log-linear fit
  ok <- value > 0 & w > 0
  if (length(unique(yr[ok])) < 2) return(0)
  exp(unname(coef(lm(log(value[ok]) ~ yr[ok], weights = w[ok]))[2])) - 1
}
tweedie_dev <- function(y, mu, p = SCORE_P) {
  mu <- pmax(mu, 1e-6)
  2 * mean(ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
d2_tweedie <- function(y, pred, exposure) 1 - tweedie_dev(y, pred) / tweedie_dev(y, exposure * sum(y) / sum(exposure))
norm_gini <- function(y, s) {
  g <- function(a, s) { a <- a[order(s, decreasing = TRUE)]; n <- length(a); sum(cumsum(a) / sum(a) - seq_len(n) / n) / n }
  g(y, s) / g(y, y)
}
seed_of <- function(ln, pr, yr, part) SEED + 1000 * match(ln, LINES) + 50 * match(pr, PERILS[[ln]]) + 3 * (yr - 2020) +
  match(part, c("freq", "sev", "tw"))

# 5. Claim preparation shared by both methods: severity trend, cap, loading -----------------------------------------
prep_claims <- function(cp, sp, train_years, target_year) {
  ex <- sp$sev_exclude_recent_years
  ty <- sort(train_years)
  sev_years <- if (ex > 0 && length(ty) > ex) head(ty, length(ty) - ex) else ty
  cp <- copy(cp)[, in_sev := loss_year %in% sev_years]
  if (cp[in_sev == TRUE, .N] < 10) cp[, in_sev := TRUE]          # too few claims in the severity years
  base <- cp[in_sev == TRUE]
  if (!nrow(base)) stop("No positive claims for ", sp$line, "/", sp$peril, " in the training window")
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

# 6. Fit one peril: frequency x severity ------------------------------------------------------------------------
fit_freq_sev <- function(tr, clp_ln, ln, pr, target_year) {
  sp <- spec_row(ln, pr)
  d <- tr[!zero_mask(tr, ln, pr)]
  pc <- prep_claims(clp_ln[peril == pr & row_id %chin% d$row_id], sp, unique(tr$policy_year), target_year)
  # frequency: positive-claim counts, volume = exposure x reported share
  n <- pc$cp[, .N, by = row_id][d, on = "row_id", N]
  n[is.na(n)] <- 0
  eff <- d$exposure * report_share(ln, pr, d)
  ff <- feats_for(ln, pr, "freq")
  enc_f <- make_enc(d, ff, n, eff)
  X <- to_mat(enc_f, d)
  set.seed(seed_of(ln, pr, target_year, "freq"))
  m_f <- xgb_fit(X, n / eff, eff, policy_holdout(d$policy_id), "count:poisson",
                 sp$freq_max_depth, sp$freq_eta, sp$freq_min_child_weight, mono_vec(enc_f, ln, pr, "freq"), pid = d$policy_id)
  p_in <- predict(m_f, X)
  bal_f <- sum(n) / sum(p_in * eff)
  ft <- freq_trend_factor(sp, n, p_in * eff * bal_f, d$policy_year, eff, target_year)
  rm(X); invisible(gc(verbose = FALSE))
  # severity on capped, trended claims of the severity years
  sv <- pc$cp[in_sev == TRUE]
  sd <- d[sv[, .(row_id, capped)], on = "row_id"]
  fs <- feats_for(ln, pr, "sev")
  sev <- list(type = "mean", mu = if (nrow(sd)) mean(sd$capped) else mean(pc$cp$capped), bal = 1)
  if (nrow(sd) >= MIN_SEV_CLAIMS && length(fs)) {
    if (sp$sev_model == "gamma_gbm") {
      enc_s <- make_enc(sd, fs, sd$capped, rep(1, nrow(sd)))
      Xs <- to_mat(enc_s, sd)
      set.seed(seed_of(ln, pr, target_year, "sev"))
      m_s <- xgb_fit(Xs, sd$capped, rep(1, nrow(sd)), policy_holdout(sd$policy_id), "reg:gamma",
                     sp$sev_max_depth, sp$sev_eta, sp$sev_min_child_weight, mono_vec(enc_s, ln, pr, "sev"), pid = sd$policy_id)
      sev <- list(type = "gbm", enc = enc_s, model = m_s, bal = sum(sd$capped) / sum(predict(m_s, Xs)))
    } else if (sp$sev_model == "gamma_glm") {
      prep <- glm_prep(sd, fs)
      if (length(prep)) {
        fr <- glm_frame(prep, sd); fr$y__ <- sd$capped
        g <- tryCatch(glm(y__ ~ ., data = fr, family = Gamma(link = "log"), mustart = rep(mean(fr$y__), nrow(fr)),
                          control = glm.control(maxit = 100)), error = function(e) NULL)
        if (!is.null(g) && g$converged) {
          g$data <- NULL; g$model <- NULL                       # keep the fit small (prediction needs terms/xlevels)
          sev <- list(type = "glm", prep = prep, model = g, bal = sum(fr$y__) / sum(fitted(g)))
        } else log_msg("  ", ln, "/", pr, ": severity GLM failed - using mean severity")
      }
    }
  }
  art <- list(type = "freq_sev", line = ln, peril = pr, target_year = target_year, enc_f = enc_f, m_f = m_f,
              bal_f = bal_f, f_trend = ft$f, sev = sev, load = pc$load)
  diag <- data.table(line = ln, peril = pr, method = "freq_sev", rounds_freq = best_iter(m_f),
                     rounds_sev = if (sev$type == "gbm") best_iter(sev$model) else NA_integer_, sev_type = sev$type,
                     claims_freq = sum(n), claims_sev = nrow(sd), bal_freq = bal_f, bal_sev = sev$bal,
                     freq_trend = ft$g, sev_trend = pc$sev_trend, cap = pc$cap, cap_load = pc$load,
                     sev_years = paste(range(pc$sev_years), collapse = "-"))
  list(art = art, diag = diag)
}

# Challenger: Tweedie GBM on the capped, trended row cost with the same IBNR volume
fit_tweedie <- function(tr, clp_ln, ln, pr, target_year) {
  sp <- spec_row(ln, pr)
  d <- tr[!zero_mask(tr, ln, pr)]
  pc <- prep_claims(clp_ln[peril == pr & row_id %chin% d$row_id], sp, unique(tr$policy_year), target_year)
  y <- pc$cp[, .(y = sum(capped)), by = row_id][d, on = "row_id", y]
  y[is.na(y)] <- 0
  eff <- d$exposure * report_share(ln, pr, d)
  fa <- feats_for(ln, pr, "all")
  enc <- make_enc(d, fa, y, eff)
  X <- to_mat(enc, d)
  set.seed(seed_of(ln, pr, target_year, "tw"))
  m <- xgb_fit(X, y / eff, eff, policy_holdout(d$policy_id), "reg:tweedie", sp$freq_max_depth, sp$freq_eta,
               sp$freq_min_child_weight, mono_vec(enc, ln, pr, "freq"),
               extra = list(tweedie_variance_power = sp$tweedie_p, eval_metric = paste0("tweedie-nloglik@", sp$tweedie_p)), pid = d$policy_id)
  p_in <- predict(m, X)
  bal <- sum(y) / sum(p_in * eff)
  ft <- freq_trend_factor(sp, y, p_in * eff * bal, d$policy_year, eff, target_year)
  rm(X); invisible(gc(verbose = FALSE))
  art <- list(type = "tweedie", line = ln, peril = pr, target_year = target_year, enc_t = enc, m_t = m,
              bal_t = bal, f_trend = ft$f, load = pc$load)
  diag <- data.table(line = ln, peril = pr, method = "tweedie", rounds_freq = best_iter(m), rounds_sev = NA_integer_,
                     sev_type = "-", claims_freq = nrow(pc$cp), claims_sev = NA_integer_, bal_freq = bal, bal_sev = NA_real_,
                     freq_trend = ft$g, sev_trend = pc$sev_trend, cap = pc$cap, cap_load = pc$load,
                     sev_years = paste(range(pc$sev_years), collapse = "-"))
  list(art = art, diag = diag)
}

sev_predict <- function(sev, nd) {
  switch(sev$type,
         mean = rep(sev$mu, nrow(nd)),
         gbm = predict(sev$model, to_mat(sev$enc, nd)) * sev$bal,
         glm = unname(predict(sev$model, newdata = glm_frame(sev$prep, nd), type = "response")) * sev$bal)
}
predict_art <- function(art, nd) {
  out <- numeric(nrow(nd))
  idx <- which(!zero_mask(nd, art$line, art$peril))
  if (!length(idx)) return(out)
  sub <- nd[idx]
  out[idx] <- if (art$type == "freq_sev") {
    sub$exposure * predict(art$m_f, to_mat(art$enc_f, sub)) * art$bal_f * art$f_trend * sev_predict(art$sev, sub) * art$load
  } else {
    sub$exposure * predict(art$m_t, to_mat(art$enc_t, sub)) * art$bal_t * art$f_trend * art$load
  }
  out
}
fit_method <- function(method, ...) if (method == "freq_sev") fit_freq_sev(...) else fit_tweedie(...)


# 7. Validation: local protocol (two out-of-time folds, three actual bases, row predictions) ------------------------
methods_for <- function(ln, pr) {
  if (SELECTION == "freq_sev") return("freq_sev")
  if (SELECTION == "tweedie") return("tweedie")
  if (toupper(spec_row(ln, pr)$challenger_tweedie) == "Y") c("freq_sev", "tweedie") else "freq_sev"
}
score_bases <- function(p, act, e) {
  rbindlist(lapply(OOF_BASES, function(b) {
    y <- act[[b]]
    data.table(basis = b, d2 = d2_tweedie(y, p, e), gini = norm_gini(y, p), pred_vs_actual = sum(p) / sum(y))
  }))
}
peril_scores <- list(); diag_val <- list(); rows <- list(); ibnr_tab <- list()
for (ln in LINES) {
  dt <- load_line(paste0("train_", ln), ln)
  clp_ln <- clp[line == ln]
  for (pr in PERILS[[ln]]) {                       # reported share by policy year: this run's method vs A0
    ibnr_tab[[paste(ln, pr)]] <- data.table(policy_year = dt$policy_year, e = dt$exposure, s0 = report_share_mid(ln, pr, dt),
                                            s = report_share(ln, pr, dt))[
      , .(exposure = sum(e), share_a0 = sum(e * s0) / sum(e), share = sum(e * s) / sum(e)), by = policy_year][
      , `:=`(line = ln, peril = pr, ibnr_factor = 1 / share, ratio_to_a0 = share / share_a0)]
  }
  for (vy in VALID_YEARS) {
    tr <- dt[policy_year < vy]
    va <- dt[policy_year == vy]
    rp <- data.table(valid_year = vy, line = ln, row_id = va$row_id, policy_id = va$policy_id, exposure = va$exposure)
    for (pr in PERILS[[ln]]) {
      raw_col <- paste0("y_cost_", pr)
      if (!raw_col %in% names(va)) stop("Column ", raw_col, " missing in train_", ln)
      adj <- clp_ln[peril == pr, .(a = sum(cost)), by = row_id][va, on = "row_id", a]
      adj[is.na(adj)] <- 0
      act <- list(reported_raw = va[[raw_col]], reported_adj = adj, developed = adj / report_share_mid(ln, pr, va))
      for (b in OOF_BASES) set(rp, j = paste0(b, "_", pr), value = act[[b]])
      for (mt in methods_for(ln, pr)) {
        t0 <- Sys.time()
        f <- fit_method(mt, tr, clp_ln, ln, pr, vy)
        p <- predict_art(f$art, va)
        set(rp, j = paste0("pred_", pr, "_", mt), value = p)
        k <- paste(vy, ln, pr, mt)
        sec <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")))
        diag_val[[k]] <- f$diag[, `:=`(valid_year = vy, seconds = sec)]
        peril_scores[[k]] <- score_bases(p, act, va$exposure)[, `:=`(valid_year = vy, line = ln, peril = pr, method = mt)]
        log_msg(vy, " ", ln, "/", pr, " ", mt, ": D2 raw ", round(peril_scores[[k]][basis == "reported_raw", d2], 4),
                ", developed ", round(peril_scores[[k]][basis == "developed", d2], 4), " (", sec, "s)")
      }
    }
    rows[[paste(vy, ln)]] <- rp
    rm(tr, va); invisible(gc(verbose = FALSE))
  }
  rm(dt, clp_ln); invisible(gc(verbose = FALSE))
}
peril_scores <- rbindlist(peril_scores)
setcolorder(peril_scores, c("valid_year", "line", "peril", "method", "basis"))
diag_val <- rbindlist(diag_val)
ibnr_tab <- rbindlist(ibnr_tab)
setcolorder(ibnr_tab, c("line", "peril", "policy_year"))

# Method per peril: fixed mix (default WENDY 4's) or own pick on mean developed D2; both picks recorded
pick <- function(b) peril_scores[basis == b, .(mean_d2 = mean(d2)), by = .(line, peril, method)][
  order(line, peril, -mean_d2)][, .SD[1], by = .(line, peril)]
own <- merge(pick("developed")[, .(line, peril, own_pick_developed = method)],
             pick("reported_raw")[, .(line, peril, own_pick_reported_raw = method)], by = c("line", "peril"))
chosen <- if (METHOD_MIX == "auto") own[, .(line, peril, method = own_pick_developed)] else
  (if (METHOD_MIX == "sheet") rd("Method_Mix") else fread(METHOD_MIX))[, .(line, peril, method)]
chosen <- merge(chosen, own, by = c("line", "peril"))
miss <- setdiff(unlist(lapply(LINES, function(ln) paste(ln, PERILS[[ln]]))), chosen[, paste(line, peril)])
if (length(miss)) stop("Method mix has no row for: ", paste(miss, collapse = ", "))
bad <- chosen[!mapply(function(ln, pr, mt) mt %in% methods_for(ln, pr), line, peril, method)]
if (nrow(bad)) stop("Method mix asks for methods not fitted: ", bad[, paste(line, peril, method, collapse = "; ")])
log_msg("Method mix: ", if (METHOD_MIX == "auto") "own pick (developed)" else METHOD_MIX, "; own pick differs for ",
        chosen[method != own_pick_developed, .N], " of ", nrow(chosen), " perils")

# Line rows and peril rows in the week1/R/oof_io.R format
peril_rows <- rbindlist(lapply(rows, function(rp) {
  ln <- rp$line[1]
  for (pr in PERILS[[ln]]) set(rp, j = paste0("pred_", pr), value = rp[[paste0("pred_", pr, "_", chosen[line == ln & peril == pr, method])]])
  rp
}), fill = TRUE)
line_rows <- rbindlist(lapply(rows, function(rp) {
  ln <- rp$line[1]
  out <- rp[, ..OOF_KEYS]
  for (v in c("pred", OOF_BASES)) set(out, j = v, value = Reduce(`+`, lapply(PERILS[[ln]], function(pr) rp[[paste0(v, "_", pr)]])))
  out
}))
rm(rows); invisible(gc(verbose = FALSE))
OUT_DIR <- write_row_preds(line_rows, peril_rows, CHECK_TAG)
line_scores <- score_row_preds(line_rows)[, `:=`(iteration = CHECK_TAG, script = "week1/R/4_models_iterwendy07.R")]
setcolorder(line_scores, c("iteration", "basis", "valid_year", "line"))
fwrite(line_scores, file.path(OUT_DIR, "line_scores.csv"))
fwrite(peril_scores, file.path(OUT_DIR, "peril_scores.csv"))
fwrite(chosen, file.path(OUT_DIR, "chosen_method.csv"))
mean_scores <- line_scores[, .(mean_d2 = mean(d2), d2_2023 = d2[valid_year == 2023], d2_2024 = d2[valid_year == 2024],
                               pred_vs_actual_2024 = pred_vs_actual[valid_year == 2024]), by = .(basis, line)]
log_msg("Validation done (", CHECK_TAG, "): mean 2023-24 reported_raw D2 ",
        paste(mean_scores[basis == "reported_raw", sprintf("%s %.4f", line, mean_d2)], collapse = "; "))

# 8. Final fit on all training years, predict the target year (FINAL_FIT=1 only) ----------------------------------
dir.create(ITER_DIR, recursive = TRUE, showWarnings = FALSE)
save_art <- function(art, file) {
  for (nm in c("m_f", "m_t")) if (!is.null(art[[nm]])) art[[nm]] <- raw_model(art[[nm]])
  if (identical(art$sev$type, "gbm")) art$sev$model <- raw_model(art$sev$model)
  saveRDS(art, file)
}
load_art <- function(file) {
  art <- readRDS(file)
  for (nm in c("m_f", "m_t")) if (!is.null(art[[nm]])) art[[nm]] <- load_model(art[[nm]])
  if (identical(art$sev$type, "gbm")) art$sev$model <- load_model(art$sev$model)
  art
}
diag_final <- test_peril <- test_line <- replication <- data.table()
run_file <- NA_character_
if (FINAL_FIT) {
  dir.create(file.path(ITER_DIR, "fitted"), recursive = TRUE, showWarnings = FALSE)
  sub_parts <- list(); diag_final <- list(); test_peril <- list(); test_line <- list(); replication <- list()
  test_preds <- list()
  for (ln in LINES) {
    tr <- load_line(paste0("train_", ln), ln)
    te <- load_line(paste0("test_", ln), ln)
    clp_ln <- clp[line == ln]
    total <- reload <- numeric(nrow(te))
    tp <- data.table(row_id = te$row_id, line = ln, exposure = te$exposure)
    for (pr in PERILS[[ln]]) {
      mt <- chosen[line == ln & peril == pr, method]
      # FINAL_METHODS=all also fits the other methods, so blends chosen on the folds can be applied to 2025
      for (m2 in if (FINAL_METHODS == "all") methods_for(ln, pr) else mt) {
        f <- fit_method(m2, tr, clp_ln, ln, pr, TARGET_YEAR)
        p <- predict_art(f$art, te)
        set(tp, j = paste0("pred_", pr, "_", m2), value = p)
        fa <- file.path(ITER_DIR, "fitted", paste0(ln, "_", pr, if (m2 != mt) paste0("_", m2), ".rds"))
        save_art(f$art, fa)
        if (m2 != mt) next
        total <- total + p
        reload <- reload + predict_art(load_art(fa), te)
        diag_final[[paste(ln, pr)]] <- f$diag
        test_peril[[paste(ln, pr)]] <- data.table(line = ln, peril = pr, method = mt, predicted_total = sum(p),
                                                  predicted_burn = sum(p) / sum(te$exposure))
        log_msg("Final ", ln, "/", pr, " (", mt, "): burn ", round(sum(p) / sum(te$exposure), 2))
      }
      set(tp, j = paste0("pred_", pr), value = tp[[paste0("pred_", pr, "_", mt)]])
    }
    test_preds[[ln]] <- tp
    total <- pmax(total, 0)
    replication[[ln]] <- data.table(line = ln, rows = nrow(te), max_abs_diff = max(abs(pmax(reload, 0) - total)))
    q <- quantile(total, c(0.5, 0.9, 0.99), names = FALSE)
    test_line[[ln]] <- data.table(line = ln, rows = nrow(te), exposure = sum(te$exposure), predicted_total = sum(total),
                                  predicted_burn = sum(total) / sum(te$exposure), p50 = q[1], p90 = q[2], p99 = q[3], max = max(total))
    sub_parts[[ln]] <- data.table(row_id = te$row_id, prediction = total)
    rm(tr, te, clp_ln); invisible(gc(verbose = FALSE))
  }
  diag_final <- rbindlist(diag_final); test_peril <- rbindlist(test_peril); test_line <- rbindlist(test_line)
  arrow::write_parquet(rbindlist(test_preds, fill = TRUE), file.path(ITER_DIR, "test_preds_peril.parquet"))
  replication <- rbindlist(replication)
  if (any(replication$max_abs_diff > 1e-6)) warning("Reloaded models do not reproduce the 2025 predictions")
  sub <- rbindlist(sub_parts)
  sample_sub <- read_raw("sample_submission")
  stopifnot(nrow(sub) == nrow(sample_sub), setequal(sub$row_id, sample_sub$row_id), !anyDuplicated(sub$row_id),
            !anyNA(sub$prediction), all(is.finite(sub$prediction)), all(sub$prediction >= 0))
  sub <- sub[match(sample_sub$row_id, row_id)]
  run_file <- out_file("submission", paste0("submission_", RUN_ID, "_wendy07_", RUN_TAG, ".csv"))   # not provisional
  fwrite(sub, run_file, scipen = 50)
}

# 9. Outputs and model card -------------------------------------------------------------------------------------
fwrite(line_scores, file.path(ITER_DIR, "line_scores.csv"))
fwrite(peril_scores, file.path(ITER_DIR, "peril_scores.csv"))
fwrite(chosen, file.path(ITER_DIR, "chosen_method.csv"))
fwrite(diag_val, file.path(ITER_DIR, "diagnostics_validation.csv"))
fwrite(ibnr_tab, file.path(ITER_DIR, "ibnr_shares_by_year.csv"))
if (nrow(cl_tri)) fwrite(cl_tri, file.path(ITER_DIR, "chain_ladder_counts.csv"))
fwrite(zr_check, file.path(ITER_DIR, "structural_zero_check.csv"))
fwrite(fmap, file.path(ITER_DIR, "features_used.csv"))
if (FINAL_FIT) {
  fwrite(diag_final, file.path(ITER_DIR, "diagnostics_final.csv"))
  fwrite(test_peril, file.path(ITER_DIR, "test_by_peril.csv"))
  fwrite(test_line, file.path(ITER_DIR, "test_by_line.csv"))
  fwrite(replication, file.path(ITER_DIR, "replication_check.csv"))
}
invisible(file.copy(CFG_FILE, file.path(ITER_DIR, basename(CFG_FILE)), overwrite = TRUE))

wide <- dcast(line_scores, basis + valid_year ~ line, value.var = "d2")
setcolorder(wide, c("basis", "valid_year", intersect(c(LINES, "ALL"), names(wide))))
card <- c(
  paste0("# ", ITERATION, " (", RUN_TAG, ") - WENDY 4 engine, IBNR method `", IBNR_METHOD, "`"), "",
  paste0("**Run id** `", RUN_ID, "` | **Workbook** `", CFG_FILE, "` (MD5 `", unname(tools::md5sum(CFG_FILE)), "`)",
         " | **Method mix** `", METHOD_MIX, "`", if (FAST) " | **FAST mode - not for submission**" else "",
         if (FINAL_FIT) paste0(" | **2025 file** `", basename(run_file), "` (MD5 `", unname(tools::md5sum(run_file)), "`, not submitted)")
         else " | validation only (FINAL_FIT=0)"), "",
  "## Local protocol: line D2 (Tweedie p = 1.5) on three actual bases",
  md_table(wide, 4),
  "Mean of 2023 and 2024 (primary score = reported_raw, ALL):", "",
  md_table(mean_scores, 4),
  "## Reported share by policy year (exposure-weighted; A0 = WENDY 4 mid-date ECDF)",
  md_table(dcast(ibnr_tab, line + peril ~ policy_year, value.var = "ratio_to_a0"), 3),
  md_table(ibnr_tab[policy_year == max(TRAIN_YEARS), .(line, peril, share_a0, share, ibnr_factor)], 3),
  "## By peril (mean 2023-24 D2, methods fitted)",
  md_table(dcast(peril_scores, line + peril + method ~ basis, value.var = "d2", fun.aggregate = mean), 4),
  "### Method mix", md_table(chosen, 0),
  if (FINAL_FIT) c("## 2025 predictions", md_table(test_line, 2), md_table(test_peril, 2),
                   "## Replication check (saved models reloaded)", md_table(replication, 10)) else character(),
  "## Notes",
  "- Developed actuals use the A0 report share for every variant, so the three bases are identical across WENDY 7 runs.",
  "- In the 2023 fold the training rows (2021-22) are almost fully reported under every method, so IBNR variants move",
  "  mostly the 2024 fold and the final 2025 fit.",
  paste0("- Run time ", round(as.numeric(difftime(Sys.time(), T0, units = "mins")), 1), " minutes.")
)
writeLines(card, file.path(ITER_DIR, "model_card.md"))
log_msg("Done. ", CHECK_TAG, ": ", OUT_DIR, " | card ", file.path(ITER_DIR, "model_card.md"))
