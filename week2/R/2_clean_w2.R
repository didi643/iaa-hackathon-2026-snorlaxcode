# 2_clean_w2.R ---------------------------------------------------------------------------------------------------
# Week 2 step 2: cleaning with documented assumptions, for BOTH markets with the same rules, so the emerging market can be
# modelled on its own and compared with / borrow from the developed market (Part 1) on a common basis.
#   Emerging (Part 2, predict 2025)  data/week_2/raw data/emerging   training 2023-24
#   Developed (Part 1, reference)    data/week_2/raw data/developed  training 2021-24 (identical to data/week_1)
# Rules (each one is counted in the check register and explained in cleaning_report.md):
#   R1  exposure recomputed as (period_end - period_start + 1) / 365 (raw kept as exposure_raw)
#   R2  sum_insured above 5m (buildings) / 2m (contents) and divisible by 1000 divided by 1000 (unit error)
#   R3  construction_type harmonised to brick / stone / timber / non_standard (emerging codes BRK/STN/WOD/MIX;
#       developed casing variants and T / W = timber, as in week 1)
#   R4  occupation: free text normalised (lower case, trimmed) and "self-employed <job>" split into occupation + flag
#   R5  ages: the emerging market only has bands, so developed driver_age / policyholder_age are also banded
#       (the exact developed ages are kept in *_age_developed for Part 1 comparisons)
#   R6  developed only (week 1 traps): customer_id padded to 8 characters; years_licensed capped at driver_age - 16;
#       duplicate claim bookings (9-digit claim_id twin of another claim) dropped
#   R7  renewal_decision dropped (the row's own outcome: leakage)
#   R8  claims: net cost = incurred - recoveries, repudiated = 0; matched to the policy row covering the loss date;
#       claims matching no row (e.g. emerging losses before 2023) excluded from targets and listed
#   R9  categorical missing values -> level "missing"; numeric missing values left as NA for the models
# Feature roles (excluded from models, kept in the data): see features_w2.csv - written_premium / discount_applied
# (current pricing), customer_service_contacts (leakage: 3.4 contacts on rows with a claim vs 0.4 without), noise fields.
# Run:  Rscript week2/R/2_clean_w2.R
# Out:  data/week_2/clean/{emerging,developed}_{train,test}_<line>.parquet, {emerging,developed}_claims_matched.parquet
#       week2/output/2_clean/ (cleaning_report.md, data_checks.csv, features_w2.csv, experience_by_year.csv, unmatched_claims.csv)

source("week2/R/0_setup_w2.R")
STEP <- "2_clean"
reg <- new_checks()
MARKETS <- list(emerging = list(read = read_e, years = TRAIN_YEARS_E), developed = list(read = read_d, years = TRAIN_YEARS_D))
band_age <- function(a) as.character(cut(a, c(-Inf, 24, 34, 49, 64, Inf), labels = AGE_BANDS))

# Reference tables -------------------------------------------------------------------------------------------------
clean_reference <- function(mkt) {
  rd <- MARKETS[[mkt]]$read
  cu <- rd("customers"); ad <- rd("addresses"); wx <- rd("weather")
  cu[, customer_id := pad_id(customer_id)]
  occ <- clean_occupation(cu$occupation)
  add_check(reg, paste0(mkt, "/customers"), "R4 occupation spellings changed by normalising",
            sum(!is.na(cu$occupation) & cu$occupation != occ$occupation), nrow(cu), "lower case, trimmed", "fixed")
  add_check(reg, paste0(mkt, "/customers"), "R4 'self-employed <job>' split into occupation + self_employed",
            sum(occ$self_employed), nrow(cu), "self_employed = TRUE", if (any(occ$self_employed)) "fixed" else "info")
  cu[, `:=`(occupation = occ$occupation, self_employed = occ$self_employed, surname = NULL)]
  if ("date_of_birth" %in% names(cu)) setnames(cu, "date_of_birth", "date_of_birth_developed")
  if ("credit_band" %in% names(cu)) setnames(cu, "credit_band", "credit_band_developed")
  setnames(wx, "year", "policy_year")
  lr <- wx[policy_year %in% MARKETS[[mkt]]$years, lapply(.SD, mean, na.rm = TRUE), by = address_id, .SDcols = WEATHER_VARS]
  setnames(lr, WEATHER_VARS, paste0("wx_avg_", WEATHER_VARS))
  list(customers = cu, addresses = ad, weather = wx, weather_avg = lr)
}

# Policy rows (train and test) -------------------------------------------------------------------------------------
clean_policy <- function(dt, line, mkt, dataset, ref) {
  dt <- copy(dt); n0 <- nrow(dt); ds <- paste0(mkt, "/", dataset)
  short <- sum(nchar(dt$customer_id) < 8)
  add_check(reg, ds, "R6 customer_id shorter than 8 characters", short, n0, "left-padded with zeros", if (short) "fixed" else "info")
  dt[, customer_id := pad_id(customer_id)]

  dt[, exposure_raw := exposure]
  dt[, exposure := row_days(dt) / DAYS_PER_YEAR]
  dt[, flag_exposure_fixed := abs(exposure_raw - round(exposure, 4)) > 1e-6 & abs(exposure_raw - exposure) > 1e-6]
  add_check(reg, ds, "R1 exposure inconsistent with dates", sum(dt$flag_exposure_fixed), n0, "recomputed (days / 365)",
            if (any(dt$flag_exposure_fixed)) "fixed" else "info")

  if (line %in% c("buildings", "contents")) {
    dt[, flag_si_fixed := !is.na(sum_insured) & sum_insured > SI_CAP[[line]] & sum_insured %% 1000 == 0]
    add_check(reg, ds, "R2 sum_insured unit error (> cap, divisible by 1000)", sum(dt$flag_si_fixed), n0, "divided by 1000",
              if (any(dt$flag_si_fixed)) "fixed" else "info")
    add_check(reg, ds, "R2 sum_insured > cap but not divisible by 1000", sum(dt$sum_insured > SI_CAP[[line]] & !dt$flag_si_fixed, na.rm = TRUE), n0,
              "none expected", "info")
    dt[flag_si_fixed == TRUE, sum_insured := sum_insured / 1000]
  }
  if (line == "buildings") {
    raw <- dt$construction_type
    ct <- toupper(trimws(raw))
    ct <- fifelse(ct %in% names(CONSTRUCTION_MAP), CONSTRUCTION_MAP[ct], ct)
    ct[ct %in% c("T", "W", "TIMBER")] <- "timber"
    ct <- tolower(ct)
    add_check(reg, ds, "R3 construction_type recoded", sum(raw != ct, na.rm = TRUE), n0, "-> brick / stone / timber / non_standard",
              if (any(raw != ct, na.rm = TRUE)) "fixed" else "info")
    add_check(reg, ds, "R3 construction_type outside the 4 harmonised levels", sum(!ct %in% c("brick", "stone", "timber", "non_standard")), n0, "none expected")
    dt[, construction_type := ct]
  }

  # ages: emerging has bands only
  if ("driver_age" %in% names(dt)) {
    lic <- !is.na(dt$years_licensed) & dt$years_licensed > pmax(dt$driver_age - 16L, 0L)
    add_check(reg, ds, "R6 years_licensed > driver_age - 16", sum(lic), n0, "capped at driver_age - 16", if (any(lic)) "fixed" else "info")
    dt[lic, years_licensed := pmax(driver_age - 16L, 0L)]
    dt[, driver_age_band := band_age(driver_age)]
    setnames(dt, "driver_age", "driver_age_developed")
  }
  if ("policyholder_age" %in% names(dt)) {
    dt[, policyholder_age_band := band_age(policyholder_age)]
    setnames(dt, "policyholder_age", "policyholder_age_developed")
  }
  if ("driver_age_band" %in% names(dt)) {
    hi <- c("17-24" = 24, "25-34" = 34, "35-49" = 49, "50-64" = 64, "65+" = 110)[dt$driver_age_band]
    add_check(reg, ds, "years_licensed > top of driver_age_band - 16", sum(dt$years_licensed > hi - 16, na.rm = TRUE), n0, "none expected")
  }
  for (cn in intersect(c("annual_mileage", "telematics_opt_in", "telematics_score"), names(dt))) setnames(dt, cn, paste0(cn, "_developed"))
  if ("renewal_decision" %in% names(dt)) dt[, renewal_decision := NULL]

  add_check(reg, ds, "duplicate row_id", sum(duplicated(dt$row_id)), n0, "none expected")
  add_check(reg, ds, "customer_id not in customers", sum(!dt$customer_id %in% ref$customers$customer_id), n0, "none expected")
  add_check(reg, ds, "address_id not in addresses", sum(!dt$address_id %in% ref$addresses$address_id), n0, "none expected")
  dt[, policy_year := year(period_start)]
  dt <- merge(dt, ref$customers, by = "customer_id", all.x = TRUE, sort = FALSE)
  dt <- merge(dt, ref$addresses, by = "address_id", all.x = TRUE, sort = FALSE)
  dt <- merge(dt, ref$weather, by = c("address_id", "policy_year"), all.x = TRUE, sort = FALSE)
  dt <- merge(dt, ref$weather_avg, by = "address_id", all.x = TRUE, sort = FALSE)
  if (nrow(dt) != n0) stop(ds, ": row count changed in joins (", n0, " -> ", nrow(dt), ")")
  add_check(reg, ds, "rows without weather for the policy year", sum(is.na(dt$rainfall_mm)), n0, "none expected")

  if ("date_of_birth_developed" %in% names(dt)) {
    dt[, customer_age_developed := as.integer(floor(as.numeric(period_start - date_of_birth_developed) / 365.25))]
    dt[, date_of_birth_developed := NULL]
  }
  dt[, `:=`(start_month = month(period_start), years_with_insurer = policy_year - customer_since_year)]
  add_check(reg, ds, "customer_since_year after the policy year", sum(dt$years_with_insurer < 0, na.rm = TRUE), n0, "none expected")
  dt[, premium_index := written_premium / weighted.mean(written_premium, exposure, na.rm = TRUE), by = policy_year]

  chr <- names(dt)[vapply(dt, is.character, logical(1))]
  chr <- setdiff(chr, c("row_id", "policy_id", "customer_id", "address_id"))
  for (cn in chr) { k <- which(is.na(dt[[cn]])); if (length(k)) set(dt, k, cn, "missing") }
  dt[, market := mkt]
  setcolorder(dt, c("market", "row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end", "policy_year", "exposure"))
  setorder(dt, row_id)
  dt
}

# Claims -----------------------------------------------------------------------------------------------------------
clean_claims <- function(mkt) {
  cl <- MARKETS[[mkt]]$read("claims"); n0 <- nrow(cl); ds <- paste0(mkt, "/claims")
  cl[, n_same := .N, by = .(policy_id, line, peril, loss_date, report_date, status, incurred_to_date)]
  cl[, flag_duplicate := !grepl("^CL[0-9]{8}$", claim_id) & n_same > 1]
  add_check(reg, ds, "R6 duplicate booking (9-digit claim_id twin)", sum(cl$flag_duplicate), n0, "dropped", if (any(cl$flag_duplicate)) "fixed" else "info")
  dups <- cl[flag_duplicate == TRUE]
  cl <- cl[flag_duplicate == FALSE][, c("n_same", "flag_duplicate") := NULL]
  add_check(reg, ds, "report_date before loss_date", sum(cl$report_date < cl$loss_date), n0, "none expected")
  add_check(reg, ds, "paid > incurred or recoveries > incurred", sum(cl$paid_to_date > cl$incurred_to_date + 1e-6 | cl$recoveries > cl$incurred_to_date + 1e-6), n0, "none expected")
  add_check(reg, ds, "repudiated with incurred > 0", sum(cl$status == "repudiated" & cl$incurred_to_date > 0), n0, "none expected")
  cl[, counts := status != "repudiated"]
  cl[, net_cost := fifelse(counts, incurred_to_date - recoveries, 0)]
  cl[, report_lag_days := as.numeric(report_date - loss_date)]
  add_check(reg, ds, "negative net cost", sum(cl$net_cost < 0), n0, "none expected")
  add_check(reg, ds, "loss_date before the market's first training year", sum(year(cl$loss_date) < min(MARKETS[[mkt]]$years)), n0,
            "cannot match a policy row (R8)", if (any(year(cl$loss_date) < min(MARKETS[[mkt]]$years))) "issue" else "info")
  list(claims = cl, duplicates = dups)
}

# Build both markets -----------------------------------------------------------------------------------------------
experience <- list(); unmatched_all <- list(); feature_avail <- list()
for (mkt in names(MARKETS)) {
  log_msg("Cleaning ", mkt)
  ref <- clean_reference(mkt)
  cc <- clean_claims(mkt); claims <- cc$claims
  matched <- list()
  for (ln in LINES) {
    tr <- clean_policy(MARKETS[[mkt]]$read(paste0("policies_", ln)), ln, mkt, paste0("policies_", ln), ref)
    te <- clean_policy(MARKETS[[mkt]]$read(paste0("test_", ln)), ln, mkt, paste0("test_", ln), ref)
    cl <- claims[line == ln]
    m <- tr[cl, on = .(policy_id, period_start <= loss_date, period_end >= loss_date), .(claim_id = i.claim_id, row_id = x.row_id), allow.cartesian = TRUE]
    add_check(reg, paste0(mkt, "/claims_", ln), "claims matching more than one policy row", m[!is.na(row_id), .N, by = claim_id][N > 1, .N], nrow(cl), "none expected")
    cl <- merge(cl, unique(m, by = "claim_id"), by = "claim_id", all.x = TRUE)
    nm <- sum(is.na(cl$row_id))
    add_check(reg, paste0(mkt, "/claims_", ln), "R8 claims matching no policy row", nm, nrow(cl), "excluded from targets; in unmatched_claims.csv",
              if (nm) "fixed" else "info")
    matched[[ln]] <- cl
    mc <- cl[!is.na(row_id)]
    agg <- mc[, .(y_n_claims = sum(counts), y_cost = sum(net_cost), y_n_open = sum(status == "open" & counts),
                  y_max_claim = max(net_cost)), by = row_id]
    for (pr in PERILS[[ln]]) {
      pa <- mc[counts == TRUE & peril == pr, .(cost = sum(net_cost), n = .N), by = row_id]
      setnames(pa, c("cost", "n"), paste0(c("y_cost_", "y_n_"), pr))
      agg <- merge(agg, pa, by = "row_id", all.x = TRUE)
    }
    tr <- merge(tr, agg, by = "row_id", all.x = TRUE, sort = FALSE)
    for (cn in grep("^y_", names(tr), value = TRUE)) set(tr, which(is.na(tr[[cn]])), cn, 0)
    setorder(tr, row_id)
    stopifnot(abs(sum(tr$y_cost) - sum(cl$net_cost[!is.na(cl$row_id)])) < 1e-6 * max(1, sum(tr$y_cost)))
    write_clean_w2(tr, paste0(mkt, "_train_", ln))
    write_clean_w2(te, paste0(mkt, "_test_", ln))
    experience[[paste(mkt, ln)]] <- tr[, .(rows = .N, exposure = sum(exposure), claims = sum(y_n_claims), cost = sum(y_cost),
                                           open_claims = sum(y_n_open)), by = policy_year][, `:=`(market = mkt, line = ln)]
    feature_avail[[paste(mkt, ln)]] <- data.table(market = mkt, line = ln, column = names(te))
    log_msg(mkt, " ", ln, ": train ", nrow(tr), " rows, test ", nrow(te), " rows")
    rm(tr, te, m, mc, agg); gc(verbose = FALSE)
  }
  cm <- rbindlist(matched, use.names = TRUE)
  write_clean_w2(cm, paste0(mkt, "_claims_matched"))
  unmatched_all[[mkt]] <- cm[is.na(row_id), .(market = mkt, claim_id, policy_id, line, peril, loss_date, report_date, status, net_cost)]
  if (nrow(cc$duplicates)) save_csv_w2(cc$duplicates, STEP, paste0(mkt, "_duplicate_claims_removed.csv"))
}

# Feature roles: availability by market and whether a model may use it ---------------------------------------------
fa <- dcast(rbindlist(feature_avail), line + column ~ market, fun.aggregate = length, value.var = "column")
fa[, `:=`(emerging = emerging > 0, developed = developed > 0)]
ROLE_ID <- c("market", "row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end", "policy_year", "exposure")
EXCLUDED <- c(written_premium = "current pricing (project rule)", discount_applied = "current pricing (project rule)",
              premium_index = "current pricing (derived from written_premium)",
              customer_service_contacts = "leakage: contacts follow claims (emerging rows with a claim 3.4 vs 0.4)",
              compulsory_excess = "constant within line (project rule)", exposure_raw = "raw value before R1",
              email_domain = "noise field", vehicle_colour = "noise field", document_preference = "noise field",
              marketing_consent = "noise field", campaign_code = "noise field", branch_id = "noise field", marketing_segment = "noise field",
              flag_exposure_fixed = "cleaning flag", flag_si_fixed = "cleaning flag")
fa[, role := fifelse(column %in% ROLE_ID, "id / exposure", fifelse(column %in% names(EXCLUDED), "excluded",
                     fifelse(grepl("_developed$", column), "developed only (not in emerging)", "feature")))]
fa[, note := fifelse(column %in% names(EXCLUDED), EXCLUDED[column], "")]
fa[column == "gender", note := "emerging only; the data notes allow it for emerging pricing"]
fa[column == "voluntary_excess", note := "always a feature (project rule)"]
fa[column %in% c("driver_age_band", "policyholder_age_band"), note := "developed banded from the exact age (R5)"]
setorder(fa, line, role, column)

# Reports ----------------------------------------------------------------------------------------------------------
checks <- checks_table(reg)
exp_dt <- rbindlist(experience)[, `:=`(frequency = claims / exposure, severity = cost / claims, burn_cost = cost / exposure,
                                        open_share = open_claims / claims)]
setcolorder(exp_dt, c("market", "line", "policy_year"))
setorder(exp_dt, line, market, policy_year)
unmatched <- rbindlist(unmatched_all)
save_csv_w2(checks, STEP, "data_checks.csv")
save_csv_w2(fa, STEP, "features_w2.csv")
save_csv_w2(exp_dt, STEP, "experience_by_year.csv")
save_csv_w2(unmatched, STEP, "unmatched_claims.csv")

pct <- function(x) ifelse(is.na(x), "", sprintf("%.2f%%", 100 * x))
write_md_w2(list(
  "# Week 2 - Step 2: cleaning (both markets, same rules)", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "by `week2/R/2_clean_w2.R`. Raw-data checks: `week2/output/1_checks/checks_report.md`;",
        "decisions and reasoning: `week2/docs/cleaning_decisions_w2.md`."), "",
  "## Outputs (data/week_2/clean/)", "",
  "- `emerging_train_<line>.parquet` (2023-24, with targets `y_*`), `emerging_test_<line>.parquet` (2025 rows to predict)",
  "- `developed_train_<line>.parquet`, `developed_test_<line>.parquet`: the Part 1 market cleaned with the same rules and the",
  "  same column names, so the two can be stacked (`rbind(..., fill = TRUE)`, column `market`)",
  "- `<market>_claims_matched.parquet`: every claim with its net cost, report lag and matched `row_id` (NA = unmatched)", "",
  "Targets: `y_cost` = sum of the row's claims (incurred - recoveries; repudiated = 0), `y_n_claims`, `y_n_open`, `y_max_claim`,",
  "and `y_cost_<peril>` / `y_n_<peril>`. As at 31 Dec 2024: not developed to ultimate (IBNR / IBNER are a modelling step).", "",
  "## Rules applied", "",
  "| Rule | What | Why |", "|---|---|---|",
  "| R1 | exposure = (period_end - period_start + 1) / 365 | raw exposure holds days or days/360 on some training rows |",
  "| R2 | sum_insured / 1000 when above 5m (buildings) / 2m (contents) and divisible by 1000 | unit error; same rule as week 1 |",
  "| R3 | construction_type -> brick / stone / timber / non_standard | emerging local codes BRK/STN/WOD/MIX; developed casing and T/W variants |",
  "| R4 | occupation lower-cased, trimmed; 'self-employed <job>' -> occupation + self_employed | emerging occupation is free text |",
  "| R5 | developed ages banded like the emerging market (17-24, 25-34, 35-49, 50-64, 65+) | emerging gives bands only |",
  "| R6 | developed only: customer_id padding, years_licensed cap, duplicate claim bookings | week 1 traps |",
  "| R7 | renewal_decision dropped | describes the row's own outcome (leakage) |",
  "| R8 | claims matched to the row covering the loss date; unmatched excluded | 34 emerging losses predate the market (2021-22) |",
  "| R9 | categorical NA -> 'missing'; numeric NA kept | missingness is informative and frequent (~12% in several emerging fields) |", "",
  "## Checks and fixes", "", md_table(checks[, .(dataset, check, n, share = pct(share), severity, action)]),
  "## Experience by policy year (as reported at 31 Dec 2024)", "", md_table(exp_dt, 4),
  "## Feature roles", "Columns ending `_developed` exist only in the Part 1 market. `excluded` columns stay in the data but are not model features.", "",
  md_table(fa[role != "feature", .(line, column, emerging, developed, role, note)]),
  "## Unmatched claims", "", md_table(unmatched[, .N, by = .(market, line, loss_year = year(loss_date))][order(market, line, loss_year)])
), STEP, "cleaning_report.md")
log_msg("Done: ", nrow(checks), " checks; clean data in ", PATHS_W2$clean)
