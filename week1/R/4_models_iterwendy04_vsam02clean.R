# 4_models_iterwendy04_vsam02clean.R -------------------------------------------------------------------
# WENDY 4 VSAM02 CLEAN: WENDY 4's exact per-peril models, run on SAM02-style cleaned data.
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
#   Output      week1/output/submission/submission_provisional.csv + archived copy, week1/models/wendy_iteration_04_vsam02clean/ model card.
#
# Run:      Rscript week1/R/4_models_iterwendy04_vsam02clean.R
#           quick smoke test: FAST=1 Rscript week1/R/4_models_iterwendy04_vsam02clean.R
#           reuse cached data: SAM02_REUSE_DATA=1 Rscript week1/R/4_models_iterwendy04_vsam02clean.R
#           other workbook:   ASSUMPTIONS_XLSX=path/to.xlsx Rscript week1/R/4_models_iterwendy04_vsam02clean.R
# Needs:    week1/R/0_setup.R, raw data in data/week_1/raw data/*, packages xgboost (>= 3.0, as WENDY 3) and readxl.

source("week1/R/0_setup.R")
for (p in c("xgboost", "readxl")) if (!requireNamespace(p, quietly = TRUE)) stop("Install package '", p, "'")
suppressPackageStartupMessages({ library(xgboost); library(readxl) })

STEP <- "4_models"
ITERATION <- "WENDY 4 VSAM02 CLEAN"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITER_DIR <- file.path("week1", "models", "wendy_iteration_04_vsam02clean")
CFG_FILE <- Sys.getenv("ASSUMPTIONS_XLSX", "week1/docs/assumptions_wendy04.xlsx")
DATA_DIR <- Sys.getenv("SAM02_DATA_DIR", "data/week_1/sam02")
FAST <- Sys.getenv("FAST", "0") == "1"
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

spec <- rd("Model_Spec")[line %in% LINES]
num_cols <- c("cap_quantile", "sev_exclude_recent_years", "freq_max_depth", "freq_eta", "freq_min_child_weight",
              "sev_max_depth", "sev_eta", "sev_min_child_weight", "tweedie_p")
spec[, (num_cols) := lapply(.SD, as.numeric), .SDcols = num_cols]
need <- unlist(lapply(LINES, function(ln) paste(ln, PERILS[[ln]])))
miss <- setdiff(need, spec[, paste(line, peril)])
if (length(miss)) stop("Model_Spec has no row for: ", paste(miss, collapse = ", "))
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
feats_for <- function(ln, pr, part) {
  codes <- switch(part, freq = c("F", "B"), sev = c("S", "B"), all = c("F", "S", "B"))
  unique(fmap[line == ln & peril == pr & code %in% codes, column])
}

zero_rules <- rd("Structural_Zeros")[line %in% LINES]
log_msg("Workbook ", CFG_FILE, ": ", nrow(fmap), " feature-peril uses, ", nrow(spec), " perils, ",
        nrow(zero_rules), " structural-zero rules", if (FAST) " [FAST mode]" else "")

# 0b. SAM02-style clean data cache ---------------------------------------------------------------------------
dir.create(DATA_DIR, recursive = TRUE, showWarnings = FALSE)
prepared <- file.path(DATA_DIR, c(paste0(c("train_", "test_"), rep(LINES, each = 2), ".parquet"),
                                  "claims_pos.parquet", "checks.csv", "ibnr.csv"))
reuse <- Sys.getenv("SAM02_REUSE_DATA") == "1" && all(file.exists(prepared))
checks <- list()
add_check <- function(dataset, check, n, action, expected = NA_real_) {
  checks[[length(checks) + 1]] <<- data.table(dataset = dataset, check = check, n = n,
                                              expected_from_handover = expected, action = action)
}

if (!reuse) {
  log_msg("Phase 1: ingest and clean raw data [SAM02 basis]")
  customers <- read_raw("customers")
  addresses <- read_raw("addresses")
  weather <- read_raw("weather")
  claims <- read_raw("claims")
  add_check("customers", "duplicate customer_id", sum(duplicated(customers$customer_id)), "none expected")
  add_check("addresses", "duplicate address_id", sum(duplicated(addresses$address_id)), "none expected")
  add_check("weather", "duplicate address_id x year", sum(duplicated(weather, by = c("address_id", "year"))), "none expected")
  customers[, surname := NULL]
  setnames(weather, "year", "policy_year")

  expected <- list(policies_motor = list(short_id = 98110, exposure = 4719 + 934),
                   policies_buildings = list(exposure = 3472 + 656, si = 1395),
                   policies_contents = list(exposure = 3524 + 729, si = 1402),
                   test_motor = list(short_id = 25554, exposure = 0),
                   test_buildings = list(exposure = 0, si = 370),
                   test_contents = list(exposure = 0, si = 360))
  si_cap <- c(buildings = 5e6, contents = 2e6)
  si_normal <- list()

  sam_clean <- function(dt, ln, ds) {
    n0 <- nrow(dt)
    ex <- function(k) if (is.null(expected[[ds]][[k]])) NA_real_ else expected[[ds]][[k]]
    add_check(ds, "customer_id shorter than 8 chars", sum(nchar(dt$customer_id) < 8, na.rm = TRUE),
              "left-padded to 8", ex("short_id"))
    dt[, customer_id := pad_id(customer_id)]
    exp_new <- as.numeric(dt$period_end - dt$period_start + 1) / DAYS_PER_YEAR
    add_check(ds, "exposure inconsistent with period dates", sum(abs(dt$exposure - round(exp_new, 4)) > 1e-6),
              "recomputed as days / 365", ex("exposure"))
    dt[, exposure := exp_new]
    add_check(ds, "period_end before period_start", sum(exp_new <= 0), "none expected")
    if (ln %in% c("buildings", "contents")) {
      flag <- !is.na(dt$sum_insured) & dt$sum_insured > si_cap[[ln]] & dt$sum_insured %% 1000 == 0
      if (is.null(si_normal[[ln]])) si_normal[[ln]] <<- range(dt$sum_insured[!flag], na.rm = TRUE)
      ok <- flag & dt$sum_insured / 1000 >= si_normal[[ln]][1] & dt$sum_insured / 1000 <= si_normal[[ln]][2]
      add_check(ds, "sum_insured > cap and divisible by 1000", sum(flag), "candidates for the /1000 fix", ex("si"))
      add_check(ds, "  of which /1000 lands in the normal train range", sum(ok), "divided by 1000")
      dt[ok, sum_insured := sum_insured / 1000]
    }
    if (ln == "buildings") {
      dt[, flag_ct_raw := toupper(trimws(construction_type))]
      ct <- dt$flag_ct_raw
      ct[ct %in% c("T", "W")] <- "TIMBER"
      dt[, construction_type := tolower(ct)]
      add_check(ds, "construction_type codes T / W", sum(dt$flag_ct_raw %in% c("T", "W")),
                "mapped to timber (checked below)")
    }
    if (ln == "motor") {
      bad <- !is.na(dt$years_licensed) & !is.na(dt$driver_age) & dt$years_licensed > pmax(dt$driver_age - 16L, 0L)
      add_check(ds, "years_licensed > driver_age - 16", sum(bad), "capped at driver_age - 16")
      dt[bad, years_licensed := pmax(driver_age - 16L, 0L)]
    }
    if ("renewal_decision" %in% names(dt)) dt[, renewal_decision := NULL]
    add_check(ds, "duplicate row_id", sum(duplicated(dt$row_id)), "none expected")
    add_check(ds, "customer_id not in customers", sum(!dt$customer_id %in% customers$customer_id), "none expected after padding")
    add_check(ds, "address_id not in addresses", sum(!dt$address_id %in% addresses$address_id), "none expected")
    dt[, policy_year := year(period_start)]
    dt <- merge(dt, customers, by = "customer_id", all.x = TRUE, sort = FALSE)
    dt <- merge(dt, addresses, by = "address_id", all.x = TRUE, sort = FALSE)
    dt <- merge(dt, weather, by = c("address_id", "policy_year"), all.x = TRUE, sort = FALSE)
    if (nrow(dt) != n0) stop(ds, ": row count changed in joins")
    add_check(ds, "rows without weather", sum(is.na(dt$rainfall_mm)), "none expected")
    dt[, customer_age := as.integer(floor(as.numeric(period_start - date_of_birth) / 365.25))]
    dt[, date_of_birth := NULL]
    dt[, start_month := month(period_start)]
    dt[, years_with_insurer := policy_year - customer_since_year]
    for (cn in names(dt)[vapply(dt, is.character, logical(1))]) {
      if (!cn %in% c("row_id", "policy_id", "customer_id", "address_id")) set(dt, which(is.na(dt[[cn]])), cn, "missing")
    }
    setorder(dt, row_id)
    dt
  }

  claims[, n_same := .N, by = .(policy_id, line, peril, loss_date, report_date, status, incurred_to_date)]
  dup <- !grepl("^CL[0-9]{8}$", claims$claim_id) & claims$n_same > 1
  add_check("claims", "9-digit claim_id duplicating another claim", sum(dup), "dropped", 604)
  claims <- claims[!dup][, n_same := NULL]
  add_check("claims", "recoveries > incurred", claims[recoveries > incurred_to_date + 1e-6, .N], "none expected")
  add_check("claims", "report_date before loss_date", claims[report_date < loss_date, .N], "none expected")
  claims[, net := fifelse(status == "repudiated", 0, incurred_to_date - recoveries)]
  add_check("claims", "non-repudiated claims with net cost <= 0", claims[status != "repudiated" & net <= 0, .N],
            "not counted as claims (frequency x severity uses claims with cost > 0)")
  add_check("claims", "loss_date 2020-12-01 (spike)", claims[loss_date == as.Date("2020-12-01"), .N],
            "excluded (no policy row)", 252)

  rows_all <- list()
  cl_all <- list()
  for (ln in LINES) {
    tr <- sam_clean(read_raw(paste0("policies_", ln)), ln, paste0("policies_", ln))
    te <- sam_clean(read_raw(paste0("test_", ln)), ln, paste0("test_", ln))
    cl <- claims[line == ln]
    m <- tr[cl, on = .(policy_id, period_start <= loss_date, period_end >= loss_date),
            .(claim_id = i.claim_id, row_id = x.row_id), allow.cartesian = TRUE]
    add_check(paste0("claims_", ln), "claims matching more than one row",
              m[!is.na(row_id), .N, by = claim_id][N > 1, .N], "none expected")
    cl <- merge(cl, unique(m[!is.na(row_id)], by = "claim_id"), by = "claim_id", all.x = TRUE)
    add_check(paste0("claims_", ln), "claims matching no policy row", sum(is.na(cl$row_id)), "excluded",
              c(motor = 297, buildings = 67, contents = 50)[[ln]])
    cl <- cl[!is.na(row_id) & status != "repudiated" & net > 0]
    cl[tr, on = "row_id", `:=`(policy_year = i.policy_year, customer_id = i.customer_id, address_id = i.address_id)]
    agg <- cl[, .(y_cost = sum(net), y_n = .N), by = row_id]
    for (pr in PERILS[[ln]]) {
      pa <- cl[peril == pr, .(c = sum(net), n = .N), by = row_id]
      setnames(pa, c("c", "n"), paste0(c("y_cost_", "y_npos_"), pr))
      agg <- merge(agg, pa, by = "row_id", all.x = TRUE)
    }
    tr <- merge(tr, agg, by = "row_id", all.x = TRUE, sort = FALSE)
    for (cn in grep("^y_", names(tr), value = TRUE)) set(tr, which(is.na(tr[[cn]])), cn, 0)
    if (ln == "buildings") {
      tcheck <- tr[policy_year <= 2024, .(freq = sum(y_n) / sum(exposure), exposure = sum(exposure)),
                   by = .(code = fifelse(flag_ct_raw %in% c("T", "W"), flag_ct_raw, construction_type))]
      for (i in seq_len(nrow(tcheck))) {
        add_check("policies_buildings", paste0("claim frequency, construction code ", tcheck$code[i]),
                  round(tcheck$freq[i], 4), "T and W should match timber-like frequency")
      }
      tr[, flag_ct_raw := NULL]
      te[, flag_ct_raw := NULL]
    }
    tr[, is_test := FALSE]
    te[, is_test := TRUE]
    rows_all[[ln]] <- rbind(tr, te, fill = TRUE)
    cl_all[[ln]] <- cl[, .(claim_id, row_id, line, peril, policy_id, customer_id, address_id, policy_year,
                           loss_date, report_date, status, incurred_to_date, recoveries, net)]
    rm(tr, te, m, cl, agg)
    gc(verbose = FALSE)
  }
  cl_all <- rbindlist(cl_all)

  log_msg("Phase 2: IBNR and long-tail rules [SAM02 basis]")
  LONG_TAIL_OPEN_SHARE <- 0.25
  cl_all[, lag := as.numeric(report_date - loss_date)]
  ibnr <- rbindlist(lapply(split(cl_all, by = c("line", "peril")), function(d) {
    F <- ecdf(d[loss_date <= as.Date("2022-12-31"), lag])
    d[, .(claims = .N, ibnr_factor = sum(1 / pmax(F(as.numeric(VALUATION_DATE - loss_date)), 0.05)) / .N,
          open_share = mean(status == "open")), by = .(line, peril, policy_year)]
  }))
  long_tail <- ibnr[policy_year == 2023 & open_share > LONG_TAIL_OPEN_SHARE, .(line, peril)][, long_tail := TRUE]
  ibnr <- merge(ibnr, long_tail, by = c("line", "peril"), all.x = TRUE)[is.na(long_tail), long_tail := FALSE]

  log_msg("Phase 3: engineered features [SAM02 basis]")
  for (ln in LINES) {
    dt <- rows_all[[ln]]
    set.seed(SEED + match(ln, LINES))
    dt[, noise_probe := runif(.N)]
    if (ln == "motor") {
      dt[, `:=`(young_driver = as.integer(driver_age < 25),
                novice_driver = as.integer(years_licensed < 3),
                licence_ratio = years_licensed / pmax(driver_age - 16, 1),
                telematics_missing = as.integer(is.na(telematics_score)))]
    } else {
      dt[, `:=`(log_sum_insured = log1p(sum_insured),
                flood_score = flood_zone / (1 + pmax(elevation_m, 0) / 10))]
    }
    if (ln == "buildings") {
      dt[, `:=`(property_age = policy_year - year_built,
                si_per_bedroom = sum_insured / pmax(bedrooms, 1),
                subsidence_score = (soil_type == "clay") * as.numeric(trees_within_5m) * dry_summer_index)]
    }
    if (ln == "contents") {
      dt[, `:=`(si_per_person = sum_insured / pmax(household_size, 1),
                hvi_per_10k_si = high_value_items / (sum_insured / 1e4))]
    }
    setorder(dt, row_id)
    write_parquet(dt[is_test == FALSE][, is_test := NULL], file.path(DATA_DIR, paste0("train_", ln, ".parquet")))
    write_parquet(dt[is_test == TRUE][, is_test := NULL], file.path(DATA_DIR, paste0("test_", ln, ".parquet")))
    log_msg(ln, ": prepared ", dt[is_test == FALSE, .N], " train and ", dt[is_test == TRUE, .N], " test rows")
    rows_all[[ln]] <- NULL
    rm(dt)
    gc(verbose = FALSE)
  }
  write_parquet(cl_all[, .(claim_id, row_id, line, peril, policy_id, customer_id, address_id, policy_year,
                           loss_date, report_date, status, incurred_to_date, recoveries, net)],
                file.path(DATA_DIR, "claims_pos.parquet"))
  fwrite(rbindlist(checks), file.path(DATA_DIR, "checks.csv"))
  fwrite(ibnr, file.path(DATA_DIR, "ibnr.csv"))
  rm(customers, addresses, weather, claims, cl_all, rows_all)
  gc(verbose = FALSE)
}
read_clean <- function(name) {
  f <- file.path(DATA_DIR, paste0(name, ".parquet"))
  if (!file.exists(f)) stop("Missing ", f, " - run this script without SAM02_REUSE_DATA=1 first.")
  as.data.table(read_parquet(f))
}
sam02_checks <- fread(file.path(DATA_DIR, "checks.csv"))
sam02_ibnr <- fread(file.path(DATA_DIR, "ibnr.csv"))
LONG_TAIL <- sam02_ibnr[long_tail == TRUE, unique(paste(line, peril, sep = "."))]
log_msg("SAM02 clean data: ", DATA_DIR, " | long-tail perils: ", paste(LONG_TAIL, collapse = ", "))

# 1. Claims: target basis -------------------------------------------------------------------------------------
cl <- as.data.table(read_parquet(file.path(DATA_DIR, "claims_pos.parquet")))
cl[, cost := net]                                                # incurred - recoveries on the SAM02-matched basis
recovery_tbl <- cl[status == "closed", .(closed_claims = .N, recovery_ratio = sum(recoveries) / sum(incurred_to_date)),
                   by = .(line, peril)][is.finite(recovery_ratio) & recovery_ratio > 0]
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
report_share <- function(ln, pr, dt) {
  mid <- as.numeric(dt$period_start) + as.numeric(dt$period_end - dt$period_start) / 2
  pmax(lag_cdf[[paste(ln, pr)]](as.numeric(VALUATION_DATE) - mid), 0.05)
}

# 2. Prior-year claims history known at renewal -------------------------------------------------------------------
id_cols <- c("row_id", "policy_id", "customer_id", "policy_year")
rowmap <- rbindlist(lapply(LINES, function(ln) {
  f <- file.path(DATA_DIR, paste0("train_", ln, ".parquet"))
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
load_line <- function(name, ln) {
  dt <- read_clean(name)
  if (s_yes("history_features")) add_history(dt, ln)
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
xgb_fit <- function(X, label, w, hold, objective, depth, eta, mcw, mono = NULL, extra = list()) {
  dtr <- xgb.DMatrix(X[!hold, , drop = FALSE], label = label[!hold], weight = w[!hold], nthread = NTHREAD)
  dva <- xgb.DMatrix(X[hold, , drop = FALSE], label = label[hold], weight = w[hold], nthread = NTHREAD)
  params <- c(list(objective = objective, learning_rate = eta * ETA_MULT, max_depth = depth, min_child_weight = mcw,
                   subsample = SUBSAMPLE, colsample_bytree = COLSAMPLE, reg_lambda = LAMBDA,
                   tree_method = "hist", nthread = NTHREAD, seed = SEED), extra)
  if (!is.null(mono) && any(mono != 0)) params$monotone_constraints <- paste0("(", paste(mono, collapse = ","), ")")
  xgb.train(params = params, data = dtr, nrounds = MAX_ROUNDS, evals = list(holdout = dva),
            early_stopping_rounds = ES_ROUNDS, verbose = 0)
}
best_iter <- function(m) { b <- xgb.attr(m, "best_iteration"); if (is.null(b)) NA_integer_ else as.integer(b) }

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
                 sp$freq_max_depth, sp$freq_eta, sp$freq_min_child_weight, mono_vec(enc_f, ln, pr, "freq"))
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
                     sp$sev_max_depth, sp$sev_eta, sp$sev_min_child_weight, mono_vec(enc_s, ln, pr, "sev"))
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
               extra = list(tweedie_variance_power = sp$tweedie_p, eval_metric = paste0("tweedie-nloglik@", sp$tweedie_p)))
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

# 7. Validation: out-of-time folds, scored against developed actuals ----------------------------------------------
methods_for <- function(ln, pr) {
  if (SELECTION == "freq_sev") return("freq_sev")
  if (SELECTION == "tweedie") return("tweedie")
  if (toupper(spec_row(ln, pr)$challenger_tweedie) == "Y") c("freq_sev", "tweedie") else "freq_sev"
}
peril_val <- list(); diag_val <- list(); vpred <- list()
for (ln in LINES) {
  dt <- load_line(paste0("train_", ln), ln)
  clp_ln <- clp[line == ln]
  for (vy in VALID_YEARS) {
    tr <- dt[policy_year < vy]
    va <- dt[policy_year == vy]
    for (pr in PERILS[[ln]]) {
      act <- clp_ln[peril == pr, .(a = sum(cost)), by = row_id][va, on = "row_id", a]
      act[is.na(act)] <- 0
      dev <- act / report_share(ln, pr, va)
      for (mt in methods_for(ln, pr)) {
        t0 <- Sys.time()
        f <- fit_method(mt, tr, clp_ln, ln, pr, vy)
        p <- predict_art(f$art, va)
        k <- paste(vy, ln, pr, mt)
        vpred[[k]] <- p
        diag_val[[k]] <- f$diag[, valid_year := vy]
        peril_val[[k]] <- data.table(valid_year = vy, line = ln, peril = pr, method = mt,
                                     d2 = d2_tweedie(dev, p, va$exposure), gini = norm_gini(dev, p),
                                     pred_vs_developed = sum(p) / sum(dev), pred_vs_reported = sum(p) / sum(act),
                                     seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))
        log_msg(vy, " ", ln, "/", pr, " ", mt, ": D2 ", round(peril_val[[k]]$d2, 4), " (",
                peril_val[[k]]$seconds, "s)")
      }
      vpred[[paste(vy, ln, pr, "dev")]] <- dev
    }
    vpred[[paste(vy, ln, "exposure")]] <- va$exposure
    rm(tr, va); invisible(gc(verbose = FALSE))
  }
  rm(dt, clp_ln); invisible(gc(verbose = FALSE))
}
peril_val <- rbindlist(peril_val)
diag_val <- rbindlist(diag_val)

# Selection per peril: highest mean D2 over the folds
chosen <- peril_val[, .(mean_d2 = mean(d2)), by = .(line, peril, method)][order(line, peril, -mean_d2)]
chosen <- chosen[, .SD[1], by = .(line, peril)][, .(line, peril, method, mean_d2)]

# Line and portfolio scores per fold: chosen mix and all-freq_sev
combo_score <- function(pick) rbindlist(lapply(VALID_YEARS, function(vy) {
  parts <- rbindlist(lapply(LINES, function(ln) {
    pred <- Reduce(`+`, lapply(PERILS[[ln]], function(pr) vpred[[paste(vy, ln, pr, pick(ln, pr))]]))
    dev <- Reduce(`+`, lapply(PERILS[[ln]], function(pr) vpred[[paste(vy, ln, pr, "dev")]]))
    data.table(line = ln, pred = pred, dev = dev, exposure = vpred[[paste(vy, ln, "exposure")]])
  }))
  rbind(parts[, .(d2 = d2_tweedie(dev, pred, exposure), gini = norm_gini(dev, pred), pred_vs_developed = sum(pred) / sum(dev)), by = line],
        parts[, .(line = "ALL", d2 = d2_tweedie(dev, pred, exposure), gini = norm_gini(dev, pred), pred_vs_developed = sum(pred) / sum(dev))])[, valid_year := vy]
}))
line_val <- combo_score(function(ln, pr) chosen[line == ln & peril == pr, method])[, mix := "chosen"]
if (SELECTION != "tweedie") line_val <- rbind(line_val, combo_score(function(ln, pr) "freq_sev")[, mix := "all freq_sev"])
rm(vpred); invisible(gc(verbose = FALSE))
log_msg("Validation done: ALL D2 (chosen) ", paste(sprintf("%d %.4f", line_val[mix == "chosen" & line == "ALL", valid_year],
                                                         line_val[mix == "chosen" & line == "ALL", d2]), collapse = "; "))

# 8. Final fit on all training years, predict the target year ------------------------------------------------------
dir.create(file.path(ITER_DIR, "fitted"), recursive = TRUE, showWarnings = FALSE)
save_art <- function(art, file) {
  for (nm in c("m_f", "m_t")) if (!is.null(art[[nm]])) art[[nm]] <- xgb.save.raw(art[[nm]])
  if (identical(art$sev$type, "gbm")) art$sev$model <- xgb.save.raw(art$sev$model)
  saveRDS(art, file)
}
sub_parts <- list(); diag_final <- list(); test_peril <- list(); test_line <- list()
for (ln in LINES) {
  tr <- load_line(paste0("train_", ln), ln)
  te <- load_line(paste0("test_", ln), ln)
  clp_ln <- clp[line == ln]
  total <- numeric(nrow(te))
  for (pr in PERILS[[ln]]) {
    mt <- chosen[line == ln & peril == pr, method]
    f <- fit_method(mt, tr, clp_ln, ln, pr, TARGET_YEAR)
    p <- predict_art(f$art, te)
    total <- total + p
    save_art(f$art, file.path(ITER_DIR, "fitted", paste0(ln, "_", pr, ".rds")))
    diag_final[[paste(ln, pr)]] <- f$diag
    burn_hist <- clp_ln[peril == pr & row_id %chin% tr[policy_year < max(TRAIN_YEARS), row_id], sum(cost)] /
      tr[policy_year < max(TRAIN_YEARS), sum(exposure)]
    test_peril[[paste(ln, pr)]] <- data.table(line = ln, peril = pr, method = mt, predicted_total = sum(p),
                                              predicted_burn = sum(p) / sum(te$exposure), reported_burn_train_ex_latest = burn_hist)
    log_msg("Final ", ln, "/", pr, " (", mt, "): burn ", round(sum(p) / sum(te$exposure), 2))
  }
  total <- pmax(total, 0)
  q <- quantile(total, c(0.5, 0.9, 0.99), names = FALSE)
  test_line[[ln]] <- data.table(line = ln, rows = nrow(te), exposure = sum(te$exposure), predicted_total = sum(total),
                                predicted_burn = sum(total) / sum(te$exposure), p50 = q[1], p90 = q[2], p99 = q[3], max = max(total))
  sub_parts[[ln]] <- data.table(row_id = te$row_id, prediction = total)
  rm(tr, te, clp_ln); invisible(gc(verbose = FALSE))
}
diag_final <- rbindlist(diag_final); test_peril <- rbindlist(test_peril); test_line <- rbindlist(test_line)

sub <- rbindlist(sub_parts)
sample_sub <- read_raw("sample_submission")
stopifnot(nrow(sub) == nrow(sample_sub), setequal(sub$row_id, sample_sub$row_id), !anyDuplicated(sub$row_id),
          !anyNA(sub$prediction), all(is.finite(sub$prediction)), all(sub$prediction >= 0))
sub <- sub[match(sample_sub$row_id, row_id)]
sub_file <- out_file("submission", "submission_provisional.csv")
fwrite(sub, sub_file, scipen = 50)
run_file <- out_file("submission", paste0("submission_", RUN_ID, "_wendy04_vsam02clean.csv"))
invisible(file.copy(sub_file, run_file, overwrite = TRUE))

# 9. Outputs and model card -------------------------------------------------------------------------------------
fwrite(peril_val, file.path(ITER_DIR, "validation_by_peril.csv"))
fwrite(line_val, file.path(ITER_DIR, "validation_by_line.csv"))
fwrite(chosen, file.path(ITER_DIR, "chosen_method.csv"))
fwrite(diag_val, file.path(ITER_DIR, "diagnostics_validation.csv"))
fwrite(diag_final, file.path(ITER_DIR, "diagnostics_final.csv"))
fwrite(test_peril, file.path(ITER_DIR, "test_by_peril.csv"))
fwrite(test_line, file.path(ITER_DIR, "test_by_line.csv"))
fwrite(zr_check, file.path(ITER_DIR, "structural_zero_check.csv"))
fwrite(recovery_tbl, file.path(ITER_DIR, "open_claim_recovery_ratios.csv"))
fwrite(fmap, file.path(ITER_DIR, "features_used.csv"))
invisible(file.copy(CFG_FILE, file.path(ITER_DIR, basename(CFG_FILE)), overwrite = TRUE))

p <- ggplot(peril_val, aes(reorder(paste(line, peril), d2), d2, fill = method)) +
  geom_col(position = "dodge") + coord_flip() + facet_wrap(~valid_year) +
  labs(title = "Tweedie D2 per peril vs developed actuals", x = NULL, y = "D2 (own baseline)", fill = NULL)
ggsave(file.path(ITER_DIR, "d2_by_peril.png"), p, width = 12, height = 7, dpi = 110, bg = "white")

w3 <- file.path("week1", "models", "wendy_iteration_03", "local_d2_by_line.csv")
w3_note <- if (file.exists(w3)) c("WENDY 3 (scored vs REPORTED actuals, so not like-for-like):", "",
                                  md_table(fread(w3)[, .(line, valid_year, d2)], 4)) else character()
card <- c(
  paste0("# ", ITERATION, " - per-peril frequency x severity from the assumption workbook"), "",
  paste0("**Run id** `", RUN_ID, "` | **Workbook** `", CFG_FILE, "` (MD5 `", unname(tools::md5sum(CFG_FILE)), "`)",
         " | **Submission** `", basename(run_file), "` (MD5 `", unname(tools::md5sum(run_file)), "`)",
         if (FAST) " | **FAST mode - not for submission**" else ""), "",
  paste0("WENDY 4 model code run against SAM02-style cleaned data cached in `", DATA_DIR, "`."),
  "Target, data and feature decisions are documented in the workbook (sheets Target_Assumptions, Features_*, Model_Spec).", "",
  "## Validation (developed actuals, Tweedie D2 p = 1.5)",
  md_table(dcast(line_val, mix + line ~ valid_year, value.var = "d2"), 4),
  w3_note,
  "### By peril and method", "![](d2_by_peril.png)", "",
  md_table(dcast(peril_val, line + peril ~ method + valid_year, value.var = "d2"), 4),
  "### Chosen method per peril", md_table(chosen, 4),
  "## Final fit diagnostics (2021-2024 -> 2025)",
  md_table(diag_final[, .(line, peril, method, sev_type, rounds_freq, rounds_sev, claims_freq, claims_sev,
                          freq_trend, sev_trend, cap, cap_load, bal_freq, bal_sev, sev_years)], 3),
  "## Structural zeros (applied only if training has no claims in those rows)", md_table(zr_check, 0),
  "## Expected recoveries deducted from open claims", md_table(recovery_tbl, 4),
  paste0("Claims limited at ", format(OUTLIER_LIMIT, big.mark = ",", scientific = FALSE), ": ", n_outlier), "",
  "## 2025 predictions", md_table(test_line, 2), md_table(test_peril, 2),
  "## Known limitations",
  "- Case reserves assumed adequate (no IBNER); long-tail perils exclude the latest year from severity only.",
  "- Severity trend is a raw log-linear fit on capped claims, so mix change is partly counted as trend (clamped).",
  "- Weather features use the realised weather of the row's year (supplied for 2025 in the test data).",
  "- Prior-year history for 2025 test rows uses 2024 claims reported by 31 Dec 2024 - same basis as training.",
  paste0("- Run time ", round(as.numeric(difftime(Sys.time(), T0, units = "mins")), 1), " minutes.")
)
writeLines(card, file.path(ITER_DIR, "model_card.md"))
log_msg("Done. Submission: ", sub_file, " | Model card: ", file.path(ITER_DIR, "model_card.md"))
