# 4_models_itersam03.R ----------------------------------------------------------
# sam_iteration_03: SAM 2 rebuild with frequency-only IBNR for frequency x severity candidates. Uses only the helpers in week1/R/0_setup.R and
# week1/R/model_io.R; nothing from week1/R/2_clean.R, week1/R/3_incidence.R or earlier model runs feeds the models.
#   Phase 0  diagnose the old framework (levels of past submissions vs public D2, replay of iteration 1 / 2 methods)
#   Phase 1  ingest + clean (every data trap re-checked and logged)
#   Phase 2  per-peril targets: claim-level caps, report-lag IBNR, long-tail rules, fitted trend
#   Phase 3  features: engineered fields + claim history (policy, customer cross-line, address)
#   Phase 4  rolling validation 2022 / 2023 / 2024: ranking (calibrated D2) and level (A/E) judged separately
#   Phase 5  candidates: per-peril GLM, per-peril LightGBM / XGBoost frequency x GLM severity, line Tweedie bags, blend
#   Phase 6  final fit on 2021-24, submission, saved models, replication check, model card
# Outputs: data/week_1/sam03/ (prepared data, git-ignored), week1/models/sam_iteration_03/ (card, CSVs, fitted blend),
#          week1/output/submission/submission_<run id>.csv, week1/output/4_models/run_history.csv
# Env vars: SAM03_QUICK=1 (sampled training rows, fewer seeds, short tuning; writes to *_quick),
#           SAM03_REUSE_DATA=1 (skip phases 1-3 if data/week_1/sam03 exists), XGB_TUNE_SECONDS (tuning budget)

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
suppressPackageStartupMessages(library(xgboost))

QUICK <- Sys.getenv("SAM03_QUICK") == "1"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
ITERATION <- 3L
ITERATION_LABEL <- if (QUICK) "sam_iteration_03_quick" else "sam_iteration_03"
ITERATION_NOTE <- paste(
  "SAM 3 rebuild with per-peril frequency x severity (GLM, LightGBM, XGBoost) using report-share exposure offsets,",
  "observed capped claim severity, claim-history features, per-peril report-lag IBNR and a fitted trend to 2025 (capped at +/-10% a year);",
  "line Tweedie bags (LightGBM, XGBoost); greedy blend chosen on calibrated D2 over three rolling folds;",
  "written_premium and noise fields excluded.")
ITER_DIR <- file.path("week1", "models", ITERATION_LABEL)
FITTED_DIR <- file.path(ITER_DIR, "fitted")
DATA_DIR <- file.path("data", "week_1", "sam03")

VALID_YEARS <- c(2022, 2023, 2024)
IMMATURE_YEAR <- 2024
CLAIM_CAP_Q <- 0.995              # claim-level cap per line x peril
LONG_TAIL_OPEN_SHARE <- 0.15      # share of policy-year 2023 claims still open that makes a peril long-tail
LONG_TAIL_SEV_BEFORE <- 2023      # long-tail severity uses policy years before this
TREND_CAP <- log(1.10)
GLM_BINS <- 6
GLM_MIN_LEVEL_SHARE <- 0.005
GLM_ZERO_SAMPLE <- if (QUICK) 50000 else 300000
SEV_FEATURE_MIN_CLAIMS <- 1500
HIST_CRED_YEARS <- 2
HIST_MAX_N <- 3
N_SEEDS_PERIL <- if (QUICK) 1 else 3
N_SEEDS_LINE <- if (QUICK) 2 else 5
QUICK_ROWS <- 150000
N_THREADS <- 12
BLEND_STEPS <- 10
XGB_TUNE_SECONDS <- as.numeric(Sys.getenv("XGB_TUNE_SECONDS", if (QUICK) "30" else "900"))
XGB_TUNE_SHARE <- c(motor = 0.4, buildings = 0.3, contents = 0.3)
MAX_ROUNDS <- 3000

# Excluded on top of NON_FEATURES: current pricing (written_premium, discount_applied) and noise / sensitive-proxy fields
SAM02_DROP <- c("written_premium", "discount_applied", "email_domain", "vehicle_colour", "document_preference",
                "marketing_consent", "campaign_code", "branch_id", "marketing_segment")
ENGINEERED <- c("young_driver", "novice_driver", "licence_ratio", "telematics_missing", "property_age",
                "log_sum_insured", "si_per_bedroom", "flood_score", "subsidence_score", "si_per_person",
                "hvi_per_10k_si", "noise_probe")
HIST_COLS <- c("hist_pol_n", "hist_pol_cost", "hist_pol_exp", "hist_pol_rel", "hist_cust_other_n",
               "hist_addr_flood", "hist_addr_water", "hist_addr_subs", "hist_addr_storm")

GLM_FEATURES <- list(
  motor = c("driver_age", "ncb_years", "years_licensed", "vehicle_value_group", "vehicle_age", "cover_type",
            "annual_mileage", "overnight_parking", "vehicle_use", "named_young_driver", "fuel_type", "body_type",
            "telematics_opt_in", "prior_claims_5y", "licence_points", "credit_band", "region", "urban_density",
            "voluntary_excess", "new_business", "payment_method", "missed_payments_12m", "hail_days",
            "hist_pol_n", "hist_cust_other_n"),
  buildings = c("flood_zone", "elevation_m", "distance_to_river_km", "sum_insured", "bedrooms", "property_age",
                "property_type", "construction_type", "occupancy", "prior_claims_5y", "missed_payments_12m",
                "region", "urban_density", "soil_type", "trees_within_5m", "roof_type", "basement",
                "listed_building", "accidental_damage_cover", "days_unoccupied", "voluntary_excess",
                "wind_exposure_index", "hail_days", "dry_summer_index", "rainfall_mm", "freezing_days",
                "hist_pol_n", "hist_addr_flood", "hist_addr_water", "hist_addr_subs", "hist_addr_storm"),
  contents = c("flood_zone", "elevation_m", "distance_to_river_km", "sum_insured", "tenure", "region",
               "policyholder_age", "prior_claims_5y", "urban_density", "missed_payments_12m", "voluntary_excess",
               "security_level", "high_value_items", "accidental_damage_cover", "works_from_home", "lodgers",
               "bicycle_cover", "property_type", "household_size", "hist_pol_n", "hist_cust_other_n",
               "hist_addr_flood", "hist_addr_water")
)
# Rare perils get a short, physically motivated frequency list instead of the full line list
PERIL_GLM_FEATURES <- list(
  buildings.fire = c("sum_insured", "property_type", "construction_type", "occupancy", "smoke_alarms", "region",
                     "urban_density", "listed_building", "prior_claims_5y", "hist_pol_n"),
  buildings.flood = c("flood_zone", "elevation_m", "distance_to_river_km", "basement", "sum_insured", "region",
                      "rainfall_mm", "hist_addr_flood"),
  buildings.subsidence = c("soil_type", "trees_within_5m", "dry_summer_index", "property_age", "sum_insured",
                           "region", "hist_addr_subs"),
  contents.flood = c("flood_zone", "elevation_m", "distance_to_river_km", "property_type", "sum_insured", "region",
                     "rainfall_mm", "hist_addr_flood")
)
SEV_FEATURES <- list(
  motor = c("vehicle_value_group", "cover_type", "vehicle_age", "region", "driver_age", "voluntary_excess", "urban_density"),
  buildings = c("sum_insured", "property_type", "region", "flood_zone", "property_age", "accidental_damage_cover"),
  contents = c("sum_insured", "high_value_items", "region", "tenure", "accidental_damage_cover")
)
# Iteration 1 GLM factor lists, used only to replay iteration 1 in phase 0
LEGACY_GLM_FEATURES <- list(
  motor = c("driver_age", "ncb_years", "years_licensed", "vehicle_value_group", "vehicle_age", "cover_type",
            "annual_mileage", "overnight_parking", "vehicle_use", "named_young_driver", "fuel_type", "body_type",
            "telematics_opt_in", "prior_claims_5y", "licence_points", "credit_band", "region", "urban_density",
            "voluntary_excess", "occupation", "marital_status", "years_at_address", "renewal_count",
            "new_business", "payment_method", "missed_payments_12m"),
  buildings = c("flood_zone", "elevation_m", "distance_to_river_km", "sum_insured", "bedrooms", "energy_rating",
                "year_built", "property_type", "construction_type", "occupancy", "prior_claims_5y",
                "missed_payments_12m", "region", "urban_density", "soil_type", "trees_within_5m", "roof_type",
                "basement", "listed_building", "accidental_damage_cover", "days_unoccupied", "voluntary_excess",
                "wind_exposure_index", "hail_days", "dry_summer_index", "rainfall_mm", "freezing_days"),
  contents = c("flood_zone", "elevation_m", "distance_to_river_km", "sum_insured", "tenure", "region",
               "policyholder_age", "prior_claims_5y", "urban_density", "missed_payments_12m", "voluntary_excess",
               "security_level", "high_value_items", "accidental_damage_cover", "works_from_home", "lodgers",
               "bicycle_cover", "property_type", "household_size")
)
# Iteration 2 tuned XGBoost settings (week1/models/iteration_02/model_card.md), used only to replay iteration 2 in phase 0
LEGACY_XGB <- list(
  motor = list(max_depth = 4, learning_rate = 0.03, min_child_weight = 50, subsample = 0.9, colsample_bytree = 0.6,
               reg_lambda = 1, tweedie_variance_power = 1.7),
  buildings = list(max_depth = 3, learning_rate = 0.03, min_child_weight = 1, subsample = 0.9, colsample_bytree = 0.8,
                   reg_lambda = 1, tweedie_variance_power = 1.5),
  contents = list(max_depth = 4, learning_rate = 0.1, min_child_weight = 10, subsample = 0.9, colsample_bytree = 0.6,
                  reg_lambda = 10, tweedie_variance_power = 1.3)
)
# Public scores from the submission log in week1/docs/workflow.md
PUBLIC_LOG <- data.table(submission = c("#1 iteration_01", "#2 iteration_02", "#3 sam_iteration_01"),
                         dir = c("iteration_01", "iteration_02", "sam_iteration_01"),
                         public_d2 = c(0.11904, 0.12149, 0.11876), local_d2_2023 = c(0.1055, 0.0997, 0.1071),
                         local_d2_2024 = c(0.0944, 0.0973, 0.0959))

LGB_PARAMS <- list(learning_rate = 0.05, num_leaves = 15, min_data_in_leaf = 500, feature_fraction = 0.7,
                   bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = 10, cat_smooth = 50, cat_l2 = 10,
                   min_data_per_group = 500, max_cat_threshold = 32, verbosity = -1, deterministic = TRUE,
                   force_col_wise = TRUE, num_threads = N_THREADS)
XGB_DEFAULT <- data.table(max_depth = 4, learning_rate = 0.05, min_child_weight = 200, subsample = 0.8,
                          colsample_bytree = 0.7, reg_lambda = 5, tweedie_variance_power = 1.5)
XGB_GRID <- CJ(max_depth = 3:5, learning_rate = c(0.03, 0.05), min_child_weight = c(50, 200, 500),
               subsample = c(0.7, 0.8, 0.9), colsample_bytree = c(0.6, 0.7, 0.8), reg_lambda = c(1, 5, 10),
               tweedie_variance_power = c(1.3, 1.5, 1.7))
XGB_PERIL_MIN_CHILD_WEIGHT <- 10  # Poisson hessian = expected claims, so a leaf needs about 10 expected claims
MONO <- c(ncb_years = -1, prior_claims_5y = 1, licence_points = 1, missed_payments_12m = 1, hist_pol_n = 1,
          hist_pol_cost = 1, hist_pol_rel = 1, hist_cust_other_n = 1)

CANDIDATES <- c("peril_glm", "peril_lgb", "peril_xgb", "lgb_tweedie", "xgb_tweedie")
BASELINES <- c("burn_cost", "burn_trend", "legacy_glm", "legacy_xgb")
fit_seed <- function(ln, mn, year, k = 0) {
  SEED + 1000 * match(ln, LINES) + 100 * match(mn, c(CANDIDATES, BASELINES)) + 10 * (year - 2020) + k
}

dir.create(DATA_DIR, recursive = TRUE, showWarnings = FALSE)
checks <- list()
add_check <- function(dataset, check, n, action, expected = NA_real_) {
  checks[[length(checks) + 1]] <<- data.table(dataset = dataset, check = check, n = n, expected_from_handover = expected,
                                              action = action)
}

# ==========================================================================================================
# Phases 1-3: ingest, clean, targets and features (cached in data/week_1/sam03 when SAM03_REUSE_DATA=1)
# ==========================================================================================================
prepared <- file.path(DATA_DIR, c(paste0(c("train_", "test_"), rep(LINES, each = 2), ".parquet"),
                                  "claims_pos.parquet", "checks.csv", "ibnr.csv"))
reuse <- Sys.getenv("SAM03_REUSE_DATA") == "1" && all(file.exists(prepared))

if (!reuse) {
  log_msg("Phase 1: ingest and clean raw data")
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
                   test_buildings = list(exposure = 0, si = 370), test_contents = list(exposure = 0, si = 360))
  si_cap <- c(buildings = 5e6, contents = 2e6)
  si_normal <- list()  # range of unflagged train sum_insured, used to verify the /1000 fix

  sam_clean <- function(dt, ln, ds) {
    n0 <- nrow(dt)
    ex <- function(k) if (is.null(expected[[ds]][[k]])) NA_real_ else expected[[ds]][[k]]
    add_check(ds, "customer_id shorter than 8 chars", sum(nchar(dt$customer_id) < 8, na.rm = TRUE), "left-padded to 8", ex("short_id"))
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
      add_check(ds, "construction_type codes T / W", sum(dt$flag_ct_raw %in% c("T", "W")), "mapped to timber (checked below)")
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
  add_check("claims", "loss_date 2020-12-01 (spike)", claims[loss_date == as.Date("2020-12-01"), .N], "excluded (no policy row)", 252)

  rows_all <- list(); cl_all <- list()
  for (ln in LINES) {
    tr <- sam_clean(read_raw(paste0("policies_", ln)), ln, paste0("policies_", ln))
    te <- sam_clean(read_raw(paste0("test_", ln)), ln, paste0("test_", ln))
    cl <- claims[line == ln]
    m <- tr[cl, on = .(policy_id, period_start <= loss_date, period_end >= loss_date),
            .(claim_id = i.claim_id, row_id = x.row_id), allow.cartesian = TRUE]
    add_check(paste0("claims_", ln), "claims matching more than one row", m[!is.na(row_id), .N, by = claim_id][N > 1, .N], "none expected")
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
      tr[, flag_ct_raw := NULL]; te[, flag_ct_raw := NULL]
    }
    tr[, is_test := FALSE]; te[, is_test := TRUE]
    rows_all[[ln]] <- rbind(tr, te, fill = TRUE)
    cl_all[[ln]] <- cl[, .(claim_id, row_id, line, peril, policy_id, customer_id, address_id, policy_year,
                           loss_date, report_date, status, net)]
    rm(tr, te, m, cl, agg); gc(verbose = FALSE)
  }
  cl_all <- rbindlist(cl_all)

  # Phase 2: report-lag IBNR per line x peril x policy year ------------------------------------------
  log_msg("Phase 2: IBNR and long-tail rules")
  cl_all[, lag := as.numeric(report_date - loss_date)]
  ibnr <- rbindlist(lapply(split(cl_all, by = c("line", "peril")), function(d) {
    F <- ecdf(d[loss_date <= as.Date("2022-12-31"), lag])
    d[, .(claims = .N, ibnr_factor = sum(1 / pmax(F(as.numeric(VALUATION_DATE - loss_date)), 0.05)) / .N,
          open_share = mean(status == "open")), by = .(line, peril, policy_year)]
  }))
  long_tail <- ibnr[policy_year == 2023 & open_share > LONG_TAIL_OPEN_SHARE, .(line, peril)][, long_tail := TRUE]
  ibnr <- merge(ibnr, long_tail, by = c("line", "peril"), all.x = TRUE)[is.na(long_tail), long_tail := FALSE]

  # Phase 3: features ------------------------------------------------------------------------------
  log_msg("Phase 3: engineered and claim-history features")
  for (ln in LINES) {
    dt <- rows_all[[ln]]
    set.seed(fit_seed(ln, "peril_glm", 2020))
    dt[, noise_probe := runif(.N)]
    if (ln == "motor") {
      dt[, `:=`(young_driver = as.integer(driver_age < 25), novice_driver = as.integer(years_licensed < 3),
                licence_ratio = years_licensed / pmax(driver_age - 16, 1), telematics_missing = as.integer(is.na(telematics_score)))]
    } else {
      dt[, `:=`(log_sum_insured = log1p(sum_insured), flood_score = flood_zone / (1 + pmax(elevation_m, 0) / 10))]
    }
    if (ln == "buildings") {
      dt[, `:=`(property_age = policy_year - year_built, si_per_bedroom = sum_insured / pmax(bedrooms, 1),
                subsidence_score = (soil_type == "clay") * as.numeric(trees_within_5m) * dry_summer_index)]
    }
    if (ln == "contents") {
      dt[, `:=`(si_per_person = sum_insured / pmax(household_size, 1), hvi_per_10k_si = high_value_items / (sum_insured / 1e4))]
    }
    rows_all[[ln]] <- dt
  }
  # Only claims reported before 1 Jan of the row's policy year count, as at quote time for 2025 (cut-off 31 Dec 2024)
  f0 <- sapply(LINES, function(ln) rows_all[[ln]][is_test == FALSE, sum(y_n) / sum(exposure)])
  pol_exp <- rbindlist(lapply(LINES, function(ln) rows_all[[ln]][is_test == FALSE, .(e = sum(exposure)),
                                                                   by = .(policy_id, policy_year)][, line := ln]))
  addr_group <- c(flood = "flood", escape_of_water = "water", subsidence = "subs", storm = "storm")
  hist <- list()
  for (Y in 2021:2025) {
    known <- cl_all[report_date < as.Date(sprintf("%d-01-01", Y))]
    hp <- known[, .(hist_pol_n = .N, hist_pol_cost = log1p(sum(pmin(net, 50000)))), by = .(line, policy_id)]
    he <- pol_exp[policy_year < Y, .(hist_pol_exp = sum(e)), by = .(line, policy_id)]
    hc <- known[, .N, by = .(customer_id, line)]
    ka <- known[line %in% c("buildings", "contents") & peril %in% names(addr_group)]
    ha <- if (nrow(ka)) {
      dcast(ka[, .N, by = .(address_id, grp = paste0("hist_addr_", addr_group[peril]))], address_id ~ grp,
            value.var = "N", fill = 0)
    } else data.table(address_id = character())
    hist[[as.character(Y)]] <- list(hp = hp, he = he, hc = hc, ha = ha)
  }
  for (ln in LINES) {
    dt <- rows_all[[ln]]
    parts <- list()
    for (Y in 2021:2025) {
      h <- hist[[as.character(Y)]]
      d <- dt[policy_year == Y, .(row_id, policy_id, customer_id, address_id)]
      d <- merge(d, h$hp[line == ln, !"line"], by = "policy_id", all.x = TRUE)
      d <- merge(d, h$he[line == ln, !"line"], by = "policy_id", all.x = TRUE)
      oth <- h$hc[line != ln, .(hist_cust_other_n = sum(N)), by = customer_id]
      d <- merge(d, oth, by = "customer_id", all.x = TRUE)
      d <- merge(d, h$ha, by = "address_id", all.x = TRUE)
      parts[[as.character(Y)]] <- d
    }
    hd <- rbindlist(parts, fill = TRUE)
    hd <- hd[, c("row_id", intersect(HIST_COLS, names(hd))), with = FALSE]
    for (cn in setdiff(HIST_COLS, c(names(hd), "hist_pol_rel"))) hd[, (cn) := 0]
    for (cn in setdiff(names(hd), "row_id")) set(hd, which(is.na(hd[[cn]])), cn, 0)
    for (cn in c("hist_pol_n", "hist_cust_other_n", grep("^hist_addr_", names(hd), value = TRUE))) set(hd, j = cn, value = pmin(hd[[cn]], HIST_MAX_N))
    hd[, hist_pol_rel := (hist_pol_n + HIST_CRED_YEARS * f0[[ln]]) / (f0[[ln]] * (pmin(hist_pol_exp, 4) + HIST_CRED_YEARS))]
    dt <- merge(dt, hd, by = "row_id", all.x = TRUE, sort = FALSE)
    setorder(dt, row_id)
    write_parquet(dt[is_test == FALSE][, is_test := NULL], file.path(DATA_DIR, paste0("train_", ln, ".parquet")))
    write_parquet(dt[is_test == TRUE][, is_test := NULL], file.path(DATA_DIR, paste0("test_", ln, ".parquet")))
    log_msg(ln, ": prepared ", dt[is_test == FALSE, .N], " train and ", dt[is_test == TRUE, .N], " test rows")
    rows_all[[ln]] <- NULL; rm(dt, hd, parts); gc(verbose = FALSE)
  }
  write_parquet(cl_all[, .(claim_id, row_id, line, peril, policy_year, status, net)], file.path(DATA_DIR, "claims_pos.parquet"))
  fwrite(rbindlist(checks), file.path(DATA_DIR, "checks.csv"))
  fwrite(ibnr, file.path(DATA_DIR, "ibnr.csv"))
  rm(customers, addresses, weather, claims, cl_all, hist, pol_exp); gc(verbose = FALSE)
}
checks <- fread(file.path(DATA_DIR, "checks.csv"))
ibnr <- fread(file.path(DATA_DIR, "ibnr.csv"))
claims_pos <- as.data.table(read_parquet(file.path(DATA_DIR, "claims_pos.parquet")))
read_prep <- function(name) as.data.table(read_parquet(file.path(DATA_DIR, paste0(name, ".parquet"))))
LONG_TAIL <- ibnr[long_tail == TRUE, unique(paste(line, peril, sep = "."))]
log_msg("Long-tail perils: ", paste(LONG_TAIL, collapse = ", "))

tree_feats <- function(dt) setdiff(feature_cols(dt), SAM02_DROP)
legacy_feats <- function(dt) setdiff(feature_cols(dt), c(ENGINEERED, HIST_COLS))

# ==========================================================================================================
# Phase 2 (per fold): caps, IBNR-adjusted counts and the line target for tree models
# ==========================================================================================================
prepare_fold <- function(tr, ln) {
  cl <- claims_pos[line == ln & row_id %in% tr$row_id]
  caps <- cl[, .(cap = quantile(net, CLAIM_CAP_Q, names = FALSE)), by = peril]
  cl <- caps[cl, on = "peril"]
  cc <- dcast(cl[, .(capcost = sum(pmin(net, cap))), by = .(row_id, peril)], row_id ~ peril, value.var = "capcost", fill = 0)
  tr[, y_target := 0]
  for (pr in PERILS[[ln]]) {
    cap_col <- paste0("y_capcost_", pr)
    v <- if (pr %in% names(cc)) cc[[pr]][match(tr$row_id, cc$row_id)] else rep(NA_real_, nrow(tr))
    v[is.na(v)] <- 0
    set(tr, j = cap_col, value = v)
    f <- ibnr[line == ln & peril == pr][match(tr$policy_year, policy_year), ibnr_factor]
    f[is.na(f)] <- 1
    set(tr, j = paste0("y_effexp_", pr), value = tr$exposure / f)
    set(tr, j = paste0("y_nadj_", pr), value = tr[[paste0("y_npos_", pr)]] * f)
    tr[, y_target := y_target + v * f]
  }
  for (s in c("npos", "nadj", "capcost")) {
    set(tr, j = paste0("y_", s, "_all"), value = rowSums(tr[, paste0("y_", s, "_", PERILS[[ln]]), with = FALSE]))
  }
  caps
}

# ==========================================================================================================
# GLM machinery (scored by model_io.R: glm_link + sam02_glm_rate)
# ==========================================================================================================
glm_specs <- function(d, feats, w = d$exposure, n_bins = GLM_BINS, min_share = GLM_MIN_LEVEL_SHARE) {
  specs <- list()
  for (f in intersect(feats, names(d))) {
    x <- d[[f]]
    sp <- if (is.numeric(x) && uniqueN(x, na.rm = TRUE) > 10) {
      br <- unique(quantile(x, seq(0, 1, length.out = n_bins + 1), na.rm = TRUE, names = FALSE))
      list(type = "bin", breaks = c(-Inf, br[-c(1, length(br))], Inf))
    } else list(type = "cat")
    v <- encode_raw(x, sp)
    ex <- tapply(w, v, sum)
    sp$base <- names(which.max(ex))
    lv <- names(ex)[ex / sum(ex) >= min_share]
    lv <- if (sp$type == "bin") intersect(c(levels(cut(0, sp$breaks)), "missing"), lv)
          else lv[order(suppressWarnings(as.numeric(lv)), lv)]
    sp$levels <- lv
    if (length(lv) >= 2) specs[[f]] <- sp
  }
  specs
}

# Log-link GLM on a rate; optional centred year trend (capped) and an immaturity dummy for the latest year
fit_glm <- function(d, y, w, specs, family, trend = TRUE, imm = FALSE) {
  X <- data.table(y = y)
  for (f in names(specs)) {
    sp <- specs[[f]]
    set(X, j = f, value = relevel(factor(encode_level(d[[f]], sp), levels = sp$levels), ref = sp$base))
  }
  use_imm <- imm && any(d$policy_year == IMMATURE_YEAR) && uniqueN(d$policy_year) > 2
  mature <- if (use_imm) d$policy_year != IMMATURE_YEAR else rep(TRUE, nrow(d))
  use_year <- trend && uniqueN(d$policy_year[mature]) >= 2
  year_ref <- weighted.mean(d$policy_year[mature], w[mature])
  if (use_year) X[, yc := d$policy_year - year_ref]
  if (use_imm) X[, imm := as.numeric(d$policy_year == IMMATURE_YEAR)]
  rhs <- setdiff(names(X), "y")
  fml <- as.formula(paste("y ~", if (length(rhs)) paste(rhs, collapse = " + ") else "1"))
  m <- tryCatch(suppressWarnings(glm(fml, family = family, data = X, weights = w, control = glm.control(maxit = 100),
                                     mustart = rep(weighted.mean(y, w), nrow(X)))),
                error = function(e) {
                  log_msg("GLM failed (", conditionMessage(e), "); falling back to intercept + trend")
                  NULL
                })
  if (is.null(m)) {
    X <- X[, intersect(c("y", "yc", "imm"), names(X)), with = FALSE]
    rhs <- setdiff(names(X), "y")
    fml <- as.formula(paste("y ~", if (length(rhs)) paste(rhs, collapse = " + ") else "1"))
    specs <- list()
    m <- suppressWarnings(glm(fml, family = family, data = X, weights = w, control = glm.control(maxit = 100),
                              mustart = rep(weighted.mean(y, w), nrow(X))))
  }
  cf <- coef(m)
  cf[is.na(cf)] <- 0
  raw <- if (use_year) cf[["yc"]] else 0
  list(specs = specs, coef = cf, year_ref = year_ref, year_coef_raw = raw,
       year_coef = max(-TREND_CAP, min(TREND_CAP, raw)), imm_coef = if (use_imm) cf[["imm"]] else NA_real_,
       n = nrow(X))
}

fit_freq_glm <- function(tr, ln, pr, feats, trend = TRUE) {
  # IBNR belongs in the frequency denominator; severity remains based on observed capped claims.
  eff <- tr[[paste0("y_effexp_", pr)]]
  y <- tr[[paste0("y_npos_", pr)]] / eff
  pos <- y > 0
  r <- min(1, GLM_ZERO_SAMPLE / max(1, sum(!pos)))
  keep <- pos | runif(nrow(tr)) < r
  d <- tr[keep]
  specs <- glm_specs(tr, feats)
  g <- fit_glm(d, y[keep], eff[keep] * ifelse(pos[keep], 1, 1 / r), specs, quasipoisson(link = "log"),
               trend = trend, imm = paste(ln, pr, sep = ".") %in% LONG_TAIL)
  g
}

fit_sev_glm <- function(tr, ln, pr, feats, trend = TRUE) {
  n <- tr[[paste0("y_npos_", pr)]]
  cc <- tr[[paste0("y_capcost_", pr)]]
  ok <- n > 0 & cc > 0
  if (paste(ln, pr, sep = ".") %in% LONG_TAIL && any(ok & tr$policy_year < LONG_TAIL_SEV_BEFORE)) {
    ok <- ok & tr$policy_year < LONG_TAIL_SEV_BEFORE
  }
  d <- tr[ok]
  if (sum(n[ok]) < SEV_FEATURE_MIN_CLAIMS) feats <- head(feats, 2)
  specs <- glm_specs(d, feats, w = n[ok])
  g <- fit_glm(d, cc[ok] / n[ok], n[ok], specs, Gamma(link = "log"), trend = trend)
  g$loading <- sum(tr[[paste0("y_cost_", pr)]][ok]) / sum(cc[ok])
  g$claims <- sum(n[ok])
  g
}

peril_freq_feats <- function(ln, pr) {
  k <- paste(ln, pr, sep = ".")
  if (!is.null(PERIL_GLM_FEATURES[[k]])) PERIL_GLM_FEATURES[[k]] else GLM_FEATURES[[ln]]
}

fit_peril_glm <- function(tr, ln, perils = PERILS[[ln]], features = TRUE, trend = TRUE) {
  parts <- lapply(perils, function(pr) {
    fg <- fit_freq_glm(tr, ln, pr, if (features) peril_freq_feats(ln, pr) else character(0), trend)
    sg <- fit_sev_glm(tr, ln, pr, if (features) SEV_FEATURES[[ln]] else character(0), trend)
    list(peril = pr, freq_glm = fg, sev_glm = sg, loading = sg$loading)
  })
  list(model = "sam02_peril", line = ln, perils = setNames(parts, perils))
}

trend_table <- function(art, ln) {
  rbindlist(lapply(art$perils, function(p) data.table(
    line = ln, peril = p$peril, long_tail = paste(ln, p$peril, sep = ".") %in% LONG_TAIL,
    freq_trend_fitted = exp(p$freq_glm$year_coef_raw) - 1, freq_trend_used = exp(p$freq_glm$year_coef) - 1,
    imm_2024_rel = exp(p$freq_glm$imm_coef), sev_trend_fitted = exp(p$sev_glm$year_coef_raw) - 1,
    sev_trend_used = exp(p$sev_glm$year_coef) - 1, sev_claims = p$sev_glm$claims, loading = p$loading)))
}

# ==========================================================================================================
# Tree machinery
# ==========================================================================================================
tree_encoder <- function(tr, feats, kind) {
  cats <- feats[vapply(feats, function(f) is.character(tr[[f]]), logical(1))]
  lv <- lapply(setNames(cats, cats), function(f) {
    if (kind == "lgb") return(sort(unique(tr[[f]])))
    r <- tr[, .(rate = sum(y_target) / sum(exposure)), by = f]  # XGBoost: codes ordered by training cost rate
    r[order(rate, get(f))][[f]]
  })
  list(features = feats, cat_levels = lv, cats = cats)
}

mono_for <- function(feats, ln, pr = NULL) {
  m <- MONO
  if (ln != "motor" && (is.null(pr) || pr == "flood")) m <- c(m, flood_zone = 1, hist_addr_flood = 1)
  v <- unname(m[feats])
  v[is.na(v)] <- 0
  as.integer(v)
}

xgb_cfg_params <- function(cfg, objective, mono, seed) {
  p <- list(objective = objective, learning_rate = cfg$learning_rate, max_depth = cfg$max_depth,
            min_child_weight = cfg$min_child_weight, subsample = cfg$subsample,
            colsample_bytree = cfg$colsample_bytree, reg_lambda = cfg$reg_lambda, tree_method = "hist",
            nthread = N_THREADS, seed = seed, monotone_constraints = paste0("(", paste(mono, collapse = ","), ")"))
  if (objective == "reg:tweedie") {
    p$tweedie_variance_power <- cfg$tweedie_variance_power
    p$eval_metric <- paste0("tweedie-nloglik@", cfg$tweedie_variance_power)
  }
  p
}

# One booster; with a holdout it early-stops, otherwise it trains `rounds` rounds on all rows
fit_booster <- function(kind, X, label, w, hold, objective, mono, cats, seed, rounds = MAX_ROUNDS, cfg = NULL) {
  wt <- if (is.null(hold)) w else w * !hold
  if (kind == "lgb") {
    params <- c(LGB_PARAMS, list(objective = objective, seed = seed, monotone_constraints = mono))
    if (objective == "tweedie") params$tweedie_variance_power <- TWEEDIE_P
    dtr <- lgb.Dataset(X, label = label, weight = wt, categorical_feature = cats)
    if (is.null(hold)) return(lgb.train(params = params, data = dtr, nrounds = rounds, verbose = -1))
    dva <- lgb.Dataset.create.valid(dtr, X[hold, , drop = FALSE], label = label[hold], weight = w[hold])
    return(lgb.train(params = params, data = dtr, nrounds = rounds, valids = list(holdout = dva),
                     early_stopping_rounds = 100, verbose = -1))
  }
  params <- xgb_cfg_params(cfg, objective, mono, seed)
  dtr <- xgb.DMatrix(X, label = label, weight = wt, nthread = N_THREADS)
  if (is.null(hold)) return(xgb.train(params = params, data = dtr, nrounds = rounds, verbose = 0))
  dva <- xgb.DMatrix(X[hold, , drop = FALSE], label = label[hold], weight = w[hold], nthread = N_THREADS)
  xgb.train(params = params, data = dtr, nrounds = rounds, evals = list(holdout = dva), early_stopping_rounds = 50, verbose = 0)
}

best_iter_of <- function(kind, b) {
  if (kind == "lgb") b$best_iter else as.integer(xgb.attr(b, "best_iteration")) + 1L
}

# Bag: member 1 early-stops on a 10% policy holdout; the others train on all rows for 1.1 x its best rounds
fit_bag <- function(kind, X, enc, label, w, pol, objective, mono, n_seeds, seed, cfg = NULL) {
  set.seed(seed)
  up <- unique(pol)
  hold <- pol %in% sample(up, round(0.1 * length(up)))
  b1 <- fit_booster(kind, X, label, w, hold, objective, mono, enc$cats, seed, cfg = cfg)
  best <- max(10L, best_iter_of(kind, b1))
  boosters <- list(b1)
  for (s in seq_len(n_seeds - 1)) {
    boosters[[s + 1]] <- fit_booster(kind, X, label, w, NULL, objective, mono, enc$cats, seed + s,
                                     rounds = ceiling(1.1 * best), cfg = cfg)
  }
  list(kind = kind, boosters = boosters, features = enc$features, cat_levels = enc$cat_levels, best_iter = best)
}

tree_importance <- function(tm) {
  b <- tm$boosters[[1]]
  imp <- if (tm$kind == "lgb") as.data.table(lgb.importance(b))[, .(Feature, Gain)]
         else as.data.table(xgb.importance(model = b))[, .(Feature, Gain)]
  imp[, Feature := as.character(Feature)]
  imp[order(-Gain)][, rank := .I][]
}

# ==========================================================================================================
# Metrics
# ==========================================================================================================
tweedie_dev <- function(y, mu, p = TWEEDIE_P) {
  mu <- pmax(mu, 1e-6)
  2 * mean(ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
norm_gini <- function(y, s) {
  g <- function(a, s) {
    a <- a[order(s, decreasing = TRUE)]
    n <- length(a)
    sum(cumsum(a) / sum(a) - seq_len(n) / n) / n
  }
  g(y, s) / g(y, y)
}
# Kaggle metric: Tweedie D2 (p = 1.5); baseline = one cost per exposure-year (or a flat mean per row)
d2_tweedie <- function(y, pred, exposure, flat = FALSE) {
  baseline <- if (flat) rep(mean(y), length(y)) else exposure * sum(y) / sum(exposure)
  1 - tweedie_dev(y, pred) / tweedie_dev(y, baseline)
}
d2_cal <- function(y, pred, exposure) d2_tweedie(y, pred * sum(y) / sum(pred), exposure)
metrics <- function(y, pred, exposure, y_dev) {
  data.table(d2 = d2_tweedie(y, pred, exposure), d2_flat = d2_tweedie(y, pred, exposure, flat = TRUE),
             d2_cal = d2_cal(y, pred, exposure), gini = norm_gini(y, pred), ae_reported = sum(pred) / sum(y),
             ae_developed = sum(pred) / y_dev)
}

# ==========================================================================================================
# Phase 5: candidate fits for one line (train tr, score te)
# ==========================================================================================================
tune_xgb <- function(ln, budget) {
  dt <- read_prep(paste0("train_", ln))[policy_year %in% 2021:2022]
  if (QUICK) dt <- dt[policy_id %in% sample(unique(policy_id), min(uniqueN(policy_id), QUICK_ROWS / 2))]
  prepare_fold(dt, ln)
  enc <- tree_encoder(dt, tree_feats(dt), "xgb")
  X <- lgb_matrix(dt, enc$features, enc$cat_levels)
  mono <- mono_for(enc$features, ln)
  set.seed(SEED + 1000 * match(ln, LINES))
  up <- unique(dt$policy_id)
  hold_pol <- sample(up, round(0.2 * length(up)))
  # half of the holdout policies drive early stopping, the other half score the configuration
  inner <- dt$policy_id %in% hold_pol[seq_along(hold_pol) %% 2 == 0]
  score_rows <- dt$policy_id %in% hold_pol[seq_along(hold_pol) %% 2 == 1]
  grid <- unique(rbind(XGB_DEFAULT, XGB_GRID[sample(.N)]))
  t0 <- Sys.time(); out <- list(); secs <- numeric()
  for (i in seq_len(nrow(grid))) {
    if (i > 1 && as.numeric(difftime(Sys.time(), t0, units = "secs")) + median(secs) > budget) break
    s <- Sys.time()
    w <- dt$exposure * !score_rows
    m <- fit_booster("xgb", X, dt$y_target / dt$exposure, w, inner, "reg:tweedie", mono, enc$cats, SEED, cfg = grid[i])
    pred <- predict(m, X[score_rows, , drop = FALSE]) * dt$exposure[score_rows]
    secs <- c(secs, as.numeric(difftime(Sys.time(), s, units = "secs")))
    out[[i]] <- cbind(data.table(line = ln, config = i), grid[i],
                      data.table(holdout_d2 = d2_tweedie(dt$y_target[score_rows], pred, dt$exposure[score_rows]),
                                 rounds = best_iter_of("xgb", m), seconds = round(secs[i])))
  }
  res <- rbindlist(out)[order(-holdout_d2)][, rank := .I]
  log_msg(ln, ": XGBoost tuning tried ", nrow(res), " configurations, best holdout D2 ", round(res$holdout_d2[1], 4))
  res
}

fit_line <- function(tr, te, ln, year, legacy = FALSE, keep_info = FALSE) {
  caps <- prepare_fold(tr, ln)
  arts <- list(); preds <- list(); info <- list(caps = caps[, line := ln], importance = list(), rounds = list())
  t0 <- Sys.time()
  set.seed(fit_seed(ln, "peril_glm", year))
  arts$peril_glm <- fit_peril_glm(tr, ln)
  arts$peril_glm$effective_exposure <- TRUE
  arts$peril_glm$ibnr <- ibnr[line == ln, .(peril, policy_year, ibnr_factor)]
  info$trend <- trend_table(arts$peril_glm, ln)
  set.seed(fit_seed(ln, "burn_trend", year))
  arts$burn_trend <- fit_peril_glm(tr, ln, features = FALSE)
  arts$burn_trend$effective_exposure <- TRUE
  arts$burn_trend$ibnr <- arts$peril_glm$ibnr
  arts$burn_cost <- list(model = "burn_cost", line = ln, loading = 1, rate = sum(tr$y_cost) / sum(tr$exposure))
  log_msg(ln, " ", year, ": GLMs fitted in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s")

  feats <- tree_feats(tr)
  for (kind in c("lgb", "xgb")) {
    t0 <- Sys.time()
    enc <- tree_encoder(tr, feats, kind)
    X <- lgb_matrix(tr, enc$features, enc$cat_levels)
    cfg <- XGB_TUNED[[ln]]
    peril_art <- arts$peril_glm
    peril_art$perils <- lapply(peril_art$perils, function(p) {
      k <- match(p$peril, PERILS[[ln]])
      eff <- tr[[paste0("y_effexp_", p$peril)]]
      p$freq_tree <- fit_bag(kind, X, enc, tr[[paste0("y_npos_", p$peril)]] / eff, eff, tr$policy_id,
                             if (kind == "lgb") "poisson" else "count:poisson", mono_for(enc$features, ln, p$peril),
                             N_SEEDS_PERIL, fit_seed(ln, paste0("peril_", kind), year, k),
                             cfg = modifyList(cfg, list(min_child_weight = XGB_PERIL_MIN_CHILD_WEIGHT)))
      p
    })
    arts[[paste0("peril_", kind)]] <- peril_art
    line_tree <- fit_bag(kind, X, enc, tr$y_target / tr$exposure, tr$exposure, tr$policy_id,
                         if (kind == "lgb") "tweedie" else "reg:tweedie", mono_for(enc$features, ln),
                         N_SEEDS_LINE, fit_seed(ln, paste0(kind, "_tweedie"), year), cfg = cfg)
    arts[[paste0(kind, "_tweedie")]] <- list(model = "sam02_line_tree", line = ln, tree = line_tree,
                                             level_artifact = arts$peril_glm)
    if (keep_info) {
      info$importance[[kind]] <- tree_importance(line_tree)[, `:=`(line = ln, model = paste0(kind, "_tweedie"))]
      info$rounds[[kind]] <- data.table(line = ln, model = c(paste0("peril_", kind, ".", PERILS[[ln]]), paste0(kind, "_tweedie")),
                                        rounds = c(sapply(peril_art$perils, function(p) p$freq_tree$best_iter), line_tree$best_iter))
    }
    rm(X); gc(verbose = FALSE)
    log_msg(ln, " ", year, ": ", kind, " per-peril + Tweedie bags fitted in ",
            round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s")
  }

  if (legacy) {
    lg <- legacy_fit(tr, te, ln, year)
    preds$legacy_glm <- lg$glm
    preds$legacy_xgb <- lg$xgb
  }
  for (mn in names(arts)) preds[[mn]] <- score_model(arts[[mn]], te)
  list(arts = arts, preds = preds, info = info)
}

# Approximate replays of iteration 1 (line GLM freq x sev, no trend, no history) and iteration 2 (XGBoost Tweedie
# with its tuned settings and its feature set incl. written_premium); level = training average x cap loading
legacy_fit <- function(tr, te, ln, year) {
  set.seed(fit_seed(ln, "legacy_glm", year))
  s <- tr[sample(.N, min(.N, 250000))]
  specs <- glm_specs(tr, LEGACY_GLM_FEATURES[[ln]], n_bins = 8, min_share = 0.002)
  fg <- fit_glm(s, s$y_nadj_all / s$exposure, s$exposure, specs, quasipoisson(link = "log"), trend = FALSE)
  sv <- tr[y_npos_all > 0 & y_capcost_all > 0]
  sg <- fit_glm(sv, sv$y_capcost_all / sv$y_npos_all, sv$y_npos_all, specs, Gamma(link = "log"), trend = FALSE)
  loading <- sum(tr$y_cost) / sum(tr$y_capcost_all)
  glm_pred <- sam02_glm_rate(fg, te) * sam02_glm_rate(sg, te) * te$exposure * loading
  set.seed(fit_seed(ln, "legacy_xgb", year))
  enc <- tree_encoder(tr, legacy_feats(tr), "xgb")
  X <- lgb_matrix(tr, enc$features, enc$cat_levels)
  up <- unique(tr$policy_id)
  hold <- tr$policy_id %in% sample(up, round(0.1 * length(up)))
  m <- fit_booster("xgb", X, tr$y_target / tr$exposure, tr$exposure, hold, "reg:tweedie",
                   rep(0L, length(enc$features)), enc$cats, SEED, cfg = LEGACY_XGB[[ln]])
  xgb_pred <- predict(m, lgb_matrix(te, enc$features, enc$cat_levels)) * te$exposure * loading
  list(glm = glm_pred, xgb = xgb_pred)
}

sample_train <- function(tr, ln) {
  if (!QUICK) return(tr)
  set.seed(SEED + match(ln, LINES))
  tr[policy_id %in% sample(unique(policy_id), min(uniqueN(policy_id), QUICK_ROWS / 3))]
}

# ==========================================================================================================
# XGBoost tuning on 2021-22 only (validation years untouched)
# ==========================================================================================================
log_msg("XGBoost tuning: ", XGB_TUNE_SECONDS, "s budget")
xgb_tuning <- rbindlist(lapply(LINES, function(ln) tune_xgb(ln, XGB_TUNE_SECONDS * XGB_TUNE_SHARE[[ln]])))
XGB_TUNED <- lapply(setNames(LINES, LINES), function(ln) as.list(xgb_tuning[line == ln][rank == 1, names(XGB_DEFAULT), with = FALSE]))

# ==========================================================================================================
# Phase 4: rolling validation
# ==========================================================================================================
valid_preds <- list(); trend_valid <- list(); train_fit <- list()
for (vy in VALID_YEARS) {
  for (ln in LINES) {
    dt <- read_prep(paste0("train_", ln))
    tr <- sample_train(dt[policy_year < vy], ln)
    va <- dt[policy_year == vy]
    rm(dt); gc(verbose = FALSE)
    fit <- fit_line(tr, va, ln, vy, legacy = TRUE)
    y_dev_f <- ibnr[line == ln & policy_year == vy][match(PERILS[[ln]], peril), ibnr_factor]
    y_dev_f[is.na(y_dev_f)] <- 1
    vp <- va[, .(valid_year = vy, line = ln, row_id, exposure, actual = y_cost, new_business,
                 hist_pol_n, driver_age = if (ln == "motor") driver_age else NA_integer_,
                 vehicle_age = if (ln == "motor") vehicle_age else NA_real_,
                 ncb_years = if (ln == "motor") ncb_years else NA_integer_)]
    vp[, developed := as.vector(as.matrix(va[, paste0("y_cost_", PERILS[[ln]]), with = FALSE]) %*% y_dev_f)]
    for (mn in names(fit$preds)) set(vp, j = mn, value = fit$preds[[mn]])
    notrend <- fit$arts$peril_glm
    notrend$perils <- lapply(notrend$perils, function(p) { p$freq_glm$year_coef <- 0; p$sev_glm$year_coef <- 0; p })
    vp[, peril_glm_notrend := score_model(notrend, va)]
    valid_preds[[paste(vy, ln)]] <- vp
    trend_valid[[paste(vy, ln)]] <- fit$info$trend[, valid_year := vy]
    # Overfitting check: calibrated D2 on the training rows vs on the validation year
    trs <- tr[sample(.N, min(.N, 200000))]
    train_fit[[paste(vy, ln)]] <- rbindlist(lapply(CANDIDATES, function(mn) data.table(
      valid_year = vy, line = ln, model = mn, d2_cal_train = d2_cal(trs$y_cost, score_model(fit$arts[[mn]], trs), trs$exposure))))
    log_msg("Validation ", vy, " / ", ln, " done")
    rm(tr, va, trs, fit); gc(verbose = FALSE)
  }
}
vp_all <- rbindlist(valid_preds)
all_models <- c(CANDIDATES, BASELINES, "peril_glm_notrend")

# Greedy forward blend per line (10 steps of 0.1, with replacement) on mean calibrated D2 over the folds
greedy_blend <- function(v) {
  counts <- setNames(rep(0, length(CANDIDATES)), CANDIDATES)
  folds <- split(v, by = "valid_year")
  for (step in seq_len(BLEND_STEPS)) {
    sc <- sapply(CANDIDATES, function(cand) {
      w <- counts; w[cand] <- w[cand] + 1; w <- w / sum(w)
      mean(sapply(folds, function(z) d2_cal(z$actual, as.vector(as.matrix(z[, ..CANDIDATES]) %*% w), z$exposure)))
    })
    counts[which.max(sc)] <- counts[which.max(sc)] + 1
  }
  counts / sum(counts)
}
blend_w <- lapply(setNames(LINES, LINES), function(ln) greedy_blend(vp_all[line == ln]))
blend_weights <- rbindlist(lapply(LINES, function(ln) data.table(line = ln, model = CANDIDATES, weight = blend_w[[ln]])))
for (ln in LINES) vp_all[line == ln, blend := as.vector(as.matrix(.SD) %*% blend_w[[ln]]), .SDcols = CANDIDATES]
all_models <- c("blend", all_models)

res <- vp_all[, rbindlist(lapply(all_models, function(mn) cbind(data.table(model = mn),
                                                                 metrics(actual, get(mn), exposure, sum(developed))))),
              by = .(valid_year, line)]
combined <- vp_all[, rbindlist(lapply(all_models, function(mn) data.table(
  model = mn, d2 = d2_tweedie(actual, get(mn), exposure), d2_flat = d2_tweedie(actual, get(mn), exposure, flat = TRUE),
  gini = norm_gini(actual, get(mn)), ae_developed = sum(get(mn)) / sum(developed)))), by = valid_year]
res_mean <- res[, .(d2 = mean(d2), d2_cal = mean(d2_cal), d2_flat = mean(d2_flat), ae_developed = mean(ae_developed)),
                by = .(line, model)]

# Phase 0 diagnostics ---------------------------------------------------------------------------------
replay <- combined[model %in% c("legacy_glm", "legacy_xgb"), .(valid_year, model, d2, d2_flat)]
replay_w <- dcast(replay, valid_year ~ model, value.var = c("d2", "d2_flat"))
replay_w[, xgb_beats_glm := d2_legacy_xgb > d2_legacy_glm]
replay_ok <- all(replay_w$xgb_beats_glm)
prev_levels <- rbindlist(lapply(seq_len(nrow(PUBLIC_LOG)), function(i) {
  f <- file.path("week1", "models", PUBLIC_LOG$dir[i], "test_prediction_summary.csv")
  if (!file.exists(f)) return(NULL)
  s <- fread(f)
  if ("submitted" %in% names(s)) s <- s[submitted == TRUE]
  s[, .(submission = PUBLIC_LOG$submission[i], line, predicted_burn_cost)]
}))
prev_levels <- dcast(prev_levels, submission ~ line, value.var = "predicted_burn_cost")
prev_levels <- merge(prev_levels, PUBLIC_LOG[, .(submission, public_d2, local_d2_2023, local_d2_2024)], by = "submission")
level_sens <- vp_all[valid_year == 2023, rbindlist(lapply(seq(0.85, 1.15, by = 0.05), function(k) data.table(
  scale = k, d2_combined = d2_tweedie(actual, k * blend, exposure), d2_combined_flat = d2_tweedie(actual, k * blend, exposure, flat = TRUE))))]

trend_check <- res[model %in% c("peril_glm", "peril_glm_notrend"), .(valid_year, line, model, d2, ae_reported, ae_developed)]
segment_ae <- rbindlist(lapply(c(2023, 2024), function(vy) {
  v <- vp_all[valid_year == vy]
  v[, blend_cal := blend * sum(actual) / sum(blend), by = line]
  seg <- list(new_business = as.character(v$new_business), hist_pol_n = as.character(v$hist_pol_n),
              driver_age = as.character(cut(v$driver_age, c(0, 25, 35, 50, 65, Inf), right = FALSE)),
              vehicle_age = as.character(cut(v$vehicle_age, c(-Inf, 3, 7, 12, Inf))),
              ncb_years = as.character(cut(v$ncb_years, c(-Inf, 0, 3, 6, 9, Inf))))
  rbindlist(lapply(names(seg), function(sname) {
    v[, .(exposure = sum(exposure), actual = sum(actual), expected = sum(blend_cal)),
      by = .(line, level = seg[[sname]])][!is.na(level) & level != "NA"][, `:=`(valid_year = vy, segment = sname, ae = actual / expected)]
  }))
}))
segment_ae <- segment_ae[, .(exposure = sum(exposure), ae_2023 = sum(actual * (valid_year == 2023)) / sum(expected * (valid_year == 2023)),
                             ae_2024 = sum(actual * (valid_year == 2024)) / sum(expected * (valid_year == 2024))),
                         by = .(line, segment, level)][order(line, segment, level)]
overfit <- merge(rbindlist(train_fit), res[, .(valid_year, line, model, d2_cal_valid = d2_cal)],
                 by = c("valid_year", "line", "model"))[, gap := d2_cal_train - d2_cal_valid]

# ==========================================================================================================
# Phase 6: final fit on 2021-24, submission and saved models
# ==========================================================================================================
unlink(ITER_DIR, recursive = TRUE)
dir.create(FITTED_DIR, recursive = TRUE)
sub_parts <- list(); test_summary <- list(); final_trend <- list(); importance <- list(); rounds <- list()
final_caps <- list(); features_used <- list()
for (ln in LINES) {
  tr <- sample_train(read_prep(paste0("train_", ln)), ln)
  te <- read_prep(paste0("test_", ln))
  fit <- fit_line(tr, te, ln, 2025, keep_info = TRUE)
  w <- blend_w[[ln]]
  sel <- names(w)[w > 0]
  blend_art <- list(model = "sam02_blend", line = ln, components = fit$arts[sel], weights = unname(w[sel]))
  save_model(blend_art, FITTED_DIR, paste0(ln, "_blend"))
  pred <- pmax(score_model(blend_art, te), 0)
  sub_parts[[ln]] <- data.table(row_id = te$row_id, prediction = pred)
  for (mn in c(CANDIDATES, "burn_trend", "burn_cost", "blend")) {
    p <- if (mn == "blend") pred else pmax(fit$preds[[mn]], 0)
    q <- quantile(p, c(0.5, 0.9, 0.99), names = FALSE)
    test_summary[[paste(ln, mn)]] <- data.table(line = ln, model = mn, weight = if (mn == "blend") 1 else w[mn],
                                                predicted_total = sum(p), predicted_burn_cost = sum(p) / sum(te$exposure),
                                                p50_row = q[1], p90_row = q[2], p99_row = q[3], max_row = max(p))
  }
  final_trend[[ln]] <- fit$info$trend
  final_caps[[ln]] <- fit$info$caps
  importance[[ln]] <- rbindlist(fit$info$importance)
  rounds[[ln]] <- rbindlist(fit$info$rounds)
  features_used[[ln]] <- data.table(line = ln, model = c("tree models", paste0("glm_freq.", PERILS[[ln]]), "glm_sev"),
                                    features = c(paste(tree_feats(tr), collapse = ", "),
                                                 sapply(PERILS[[ln]], function(pr) paste(names(fit$arts$peril_glm$perils[[pr]]$freq_glm$specs), collapse = ", ")),
                                                 paste(SEV_FEATURES[[ln]], collapse = ", ")))
  log_msg(ln, ": final blend scored on test, cost per exposure-year ", round(sum(pred) / sum(te$exposure), 2))
  rm(tr, te, fit); gc(verbose = FALSE)
}
test_summary <- rbindlist(test_summary)
final_trend <- rbindlist(final_trend)
final_caps <- rbindlist(final_caps)
importance <- rbindlist(importance)
rounds <- rbindlist(rounds)
features_used <- rbindlist(features_used)

sub <- rbindlist(sub_parts)
sample_sub <- read_raw("sample_submission")
stopifnot(nrow(sub) == nrow(sample_sub), setequal(sub$row_id, sample_sub$row_id), !anyDuplicated(sub$row_id),
          !anyNA(sub$prediction), all(sub$prediction >= 0))
sub <- sub[match(sample_sub$row_id, row_id)]
run_file <- out_file("submission", paste0("submission_", RUN_ID, if (QUICK) "_quick", ".csv"))
fwrite(sub, run_file, scipen = 50)
if (!QUICK) file.copy(run_file, out_file("submission", "submission_provisional.csv"), overwrite = TRUE)
sub_md5 <- unname(tools::md5sum(run_file))

replication <- rbindlist(lapply(LINES, function(ln) {
  te <- read_prep(paste0("test_", ln))
  re <- pmax(score_model(load_model(FITTED_DIR, paste0(ln, "_blend")), te), 0)
  data.table(line = ln, model = "blend", rows = nrow(te), max_abs_diff = max(abs(re - sub[match(te$row_id, row_id), prediction])))
}))
replication_ok <- all(replication$max_abs_diff < 1e-6)
log_msg("Replication check ", if (replication_ok) "passed" else "FAILED")

# Run history row -----------------------------------------------------------------------------------
d2_of <- function(vy, ln = NULL) {
  if (is.null(ln)) combined[valid_year == vy & model == "blend", d2] else res[valid_year == vy & line == ln & model == "blend", d2]
}
git_commit <- tryCatch({
  h <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)
  dirty <- length(system2("git", c("status", "--porcelain", "--", "week1/R"), stdout = TRUE, stderr = FALSE)) > 0
  paste0(h, if (dirty) " + uncommitted changes in week1/R/" else "")
}, error = function(e) "unknown")
run_row <- data.table(iteration = ITERATION, iteration_label = ITERATION_LABEL, run_id = RUN_ID, git_commit = git_commit,
                      file = basename(run_file), file_md5 = sub_md5,
                      replication_check = if (replication_ok) "passed" else "FAILED",
                      models = paste(paste0(LINES, "=blend"), collapse = "; "),
                      local_d2_2022 = d2_of(2022), local_d2_2023 = d2_of(2023), local_d2_2024 = d2_of(2024),
                      by_line_2023_2024 = paste(sprintf("%s %.3f / %.3f", LINES, sapply(LINES, d2_of, vy = 2023),
                                                        sapply(LINES, d2_of, vy = 2024)), collapse = "; "))
for (ln in LINES) for (vy in VALID_YEARS) set(run_row, j = paste0("d2_", ln, "_", vy), value = d2_of(vy, ln))
if (!QUICK) {
  hist_file <- out_file("4_models", "run_history.csv")
  history <- if (file.exists(hist_file)) rbind(fread(hist_file, colClasses = list(character = "run_id")), run_row, fill = TRUE) else run_row
  fwrite(history, hist_file)
}

# ==========================================================================================================
# Model card
# ==========================================================================================================
fwrite(run_row, file.path(ITER_DIR, "summary.csv"))
fwrite(checks, file.path(ITER_DIR, "data_checks.csv"))
fwrite(ibnr, file.path(ITER_DIR, "ibnr_by_peril.csv"))
fwrite(final_caps, file.path(ITER_DIR, "claim_caps.csv"))
fwrite(final_trend, file.path(ITER_DIR, "trend_by_peril.csv"))
fwrite(rbindlist(trend_valid), file.path(ITER_DIR, "trend_by_fold.csv"))
fwrite(xgb_tuning, file.path(ITER_DIR, "xgb_tuning.csv"))
fwrite(res, file.path(ITER_DIR, "validation_metrics.csv"))
fwrite(combined, file.path(ITER_DIR, "validation_combined.csv"))
fwrite(blend_weights, file.path(ITER_DIR, "blend_weights.csv"))
fwrite(segment_ae, file.path(ITER_DIR, "segment_ae.csv"))
fwrite(overfit, file.path(ITER_DIR, "overfit_check.csv"))
fwrite(test_summary, file.path(ITER_DIR, "test_prediction_summary.csv"))
fwrite(importance, file.path(ITER_DIR, "tree_importance.csv"))
fwrite(rounds, file.path(ITER_DIR, "tree_rounds.csv"))
fwrite(features_used, file.path(ITER_DIR, "features_used.csv"))
fwrite(replay_w, file.path(ITER_DIR, "phase0_replay.csv"))
fwrite(level_sens, file.path(ITER_DIR, "phase0_level_sensitivity.csv"))

imp_top <- importance[rank <= 20]
noise_rank <- importance[Feature == "noise_probe", .(line, model, noise_rank = rank)]
p <- ggplot(imp_top, aes(reorder(paste(Feature, line, model, sep = "___"), Gain), Gain,
                         fill = Feature == "noise_probe")) +
  geom_col() + coord_flip() + facet_wrap(~ line + model, scales = "free") +
  scale_x_discrete(labels = function(x) sub("___.*$", "", x)) + scale_fill_manual(values = c("steelblue", "red"), guide = "none") +
  labs(title = "Line Tweedie bags: gain importance (top 20; red = random noise feature)", x = NULL)
ggsave(file.path(ITER_DIR, "tree_importance.png"), p, width = 14, height = 10, dpi = 110, bg = "white")

ours <- test_summary[model == "blend", .(submission = "this run (sam_iteration_03)", line, predicted_burn_cost)]
level_cmp <- rbind(melt(prev_levels[, c("submission", LINES), with = FALSE], id.vars = "submission",
                        variable.name = "line", value.name = "predicted_burn_cost"), ours)
level_cmp <- dcast(level_cmp, submission ~ line, value.var = "predicted_burn_cost")[, c("submission", LINES), with = FALSE]
level_cmp <- merge(level_cmp, PUBLIC_LOG[, .(submission, public_d2)], by = "submission", all.x = TRUE)

wide <- function(d, val) dcast(d, line + model ~ valid_year, value.var = val)
settings <- data.table(setting = c("Training years (final fit)", "Validation folds", "Selection", "Large losses",
                                   "IBNR", "Long-tail perils", "Trend", "GLM", "LightGBM", "XGBoost line Tweedie",
                                   "XGBoost per-peril", "Bagging", "Excluded features", "Quick mode", "Seed"),
                       value = c("2021-2024", "fit < 2022 / 2023 / 2024, score that year",
                                 "greedy forward blend (10 x 0.1) per line on mean calibrated D2 over the three folds",
                                 sprintf("claim-level cap at p%.1f per line x peril; per-peril loading = cost / capped cost", 100 * CLAIM_CAP_Q),
                                 "frequency-only per line x peril x policy year from the 2021-22 report-lag distribution; effective exposure = exposure / IBNR factor; severity uses observed capped claims",
                                 paste0(paste(LONG_TAIL, collapse = ", "), sprintf(" (2023 open share > %.0f%%): severity on policy years < %d, frequency with a %d dummy", 100 * LONG_TAIL_OPEN_SHARE, LONG_TAIL_SEV_BEFORE, IMMATURE_YEAR)),
                                 sprintf("policy_year term in each per-peril frequency and severity GLM, capped at +/-%.0f%% a year; tree models take the GLM level", 100 * (exp(TREND_CAP) - 1)),
                                 sprintf("%d quantile bins, levels < %.1f%% exposure merged to base; frequency on all claim rows + %s sampled zero rows (reweighted)", GLM_BINS, 100 * GLM_MIN_LEVEL_SHARE, format(GLM_ZERO_SAMPLE, big.mark = ",")),
                                 paste(names(LGB_PARAMS), unlist(LGB_PARAMS), sep = "=", collapse = ", "),
                                 paste(sprintf("%s: %s", LINES, sapply(LINES, function(ln) paste(names(XGB_TUNED[[ln]]), unlist(XGB_TUNED[[ln]]), sep = "=", collapse = ", "))), collapse = "; "),
                                 paste0("line settings with count:poisson and min_child_weight=", XGB_PERIL_MIN_CHILD_WEIGHT),
                                 sprintf("%d seeds per-peril, %d seeds line Tweedie; member 1 early-stops on a 10%% policy holdout", N_SEEDS_PERIL, N_SEEDS_LINE),
                                 paste(c(NON_FEATURES, SAM02_DROP), collapse = ", "), as.character(QUICK),
                                 paste0(SEED, " + offsets by line, model, year and peril (fit_seed())")))

card <- c(
  paste0("# Iteration SAM 3 (`", ITERATION_LABEL, "`)"), "",
  paste0("**Run id** `", RUN_ID, "` | **Generated** ", format(Sys.time(), "%Y-%m-%d %H:%M"), " | **Git commit** `", git_commit,
         "` | **Submission file** `", basename(run_file), "`"), "",
  paste0("**Change in this iteration:** ", ITERATION_NOTE), "",
  if (grepl("uncommitted", git_commit)) c("> **Warning:** generated from uncommitted code.", ""),
  if (QUICK) c("> **Quick mode:** sampled training rows, fewer seeds and short tuning - not for submission.", ""),
  "## Phase 0 - is the old framework off track?",
  "### Predicted 2025 cost per exposure-year of past submissions vs their public D2", "",
  md_table(level_cmp, 4),
  "### Replay of iteration 1 (GLM) and iteration 2 (XGBoost) in the new validation (combined D2, all lines)",
  paste0("Public order is iteration 2 > iteration 1. Replay ranks XGBoost above GLM in every fold: **", replay_ok, "**."), "",
  md_table(replay_w, 4),
  "### Level sensitivity (2023 fold, blend scaled by a constant, combined D2)", "",
  md_table(level_sens, 4),
  "## Reproducibility",
  paste0("Submission MD5 `", sub_md5, "`. The submitted blend per line is saved in `", FITTED_DIR,
         "/<line>_blend.rds` (boosters embedded). Prepared data: `data/week_1/sam03/` (rebuild with this script)."), "",
  "```r", "source(\"week1/R/0_setup.R\"); source(\"week1/R/model_io.R\")",
  paste0("art  <- load_model(\"", FITTED_DIR, "\", \"motor_blend\")"),
  "pred <- pmax(score_model(art, arrow::read_parquet(\"data/week_1/sam03/test_motor.parquet\")), 0)", "```", "",
  paste0("Replication check: **", if (replication_ok) "passed" else "FAILED", "**"), "",
  md_table(replication, 10),
  "## Settings", md_table(settings),
  "## Data checks (rebuilt from raw)", md_table(checks),
  "## Per-peril IBNR, caps, trend and loading",
  "IBNR factor by policy year (inverse reporting probability from the 2021-22 report-lag distribution):", "",
  md_table(dcast(ibnr, line + peril + long_tail ~ policy_year, value.var = "ibnr_factor"), 3),
  "Final fit (2021-24): fitted vs used (capped) annual trend, 2024 immaturity relativity for long-tail perils, severity claims and loading:", "",
  md_table(final_trend, 3),
  md_table(final_caps, 0),
  "## XGBoost tuning (2021-22, 20% policy holdout; top 5 per line)", "",
  md_table(xgb_tuning[rank <= 5], 4),
  "## Validation - local Kaggle metric (Tweedie D2, p = 1.5)",
  paste("`d2` = raw (exposure-rate baseline, as Kaggle is believed to score), `d2_flat` = flat-mean baseline,",
        "`d2_cal` = after rescaling predictions to the actual total (ranking only), `ae_developed` = predicted /",
        "IBNR-developed actual (level). 2024 actuals are immature."), "",
  "### Combined, all lines", md_table(dcast(combined, model ~ valid_year, value.var = c("d2", "d2_flat", "ae_developed"))[order(-d2_2023)], 4),
  "### Mean over folds by line", md_table(res_mean[order(line, -d2_cal)], 4),
  "### Raw D2 by fold", md_table(wide(res, "d2")[order(line, model)], 4),
  "### Calibrated D2 by fold", md_table(wide(res, "d2_cal")[order(line, model)], 4),
  "### Level: predicted / developed actual by fold", md_table(wide(res, "ae_developed")[order(line, model)], 3),
  "### Trend vs no trend (per-peril GLM)", md_table(dcast(trend_check, line + model ~ valid_year, value.var = c("d2", "ae_developed")), 4),
  "### Overfitting check: calibrated D2 on training rows vs validation year", md_table(overfit[order(line, model, valid_year)], 4),
  "### Segment A/E of the blend (level removed per line; 1 = right relative price)", md_table(segment_ae, 3),
  "## Blend weights", md_table(dcast(blend_weights, line ~ model, value.var = "weight"), 2),
  "## 2025 test predictions (final fit on 2021-24)", md_table(test_summary, 2),
  "### Level vs previous submissions", md_table(level_cmp, 2),
  "## Variable importance (line Tweedie bags)", "![](tree_importance.png)", "",
  "Rank of the random noise feature:", "", md_table(noise_rank),
  md_table(importance[rank <= 15][order(line, model, rank)], 4),
  "## Boosting rounds (final fit, early-stopping member)", md_table(rounds, 0),
  "## Features used", md_table(features_used)
)
writeLines(card, file.path(ITER_DIR, "model_card.md"))
log_msg("Done. Card: ", file.path(ITER_DIR, "model_card.md"), " | Submission: ", run_file)
