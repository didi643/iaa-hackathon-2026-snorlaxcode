# 02_clean_week2.R -----------------------------------------------------------------
# Purpose : Clean BOTH markets with one shared function and build the row targets as in week 1.
#           Adapted from week1/R/2_clean.R (copied, not edited; week1/final_week1_R_Script/R/2_clean.R is the same file).
#           Changes from week 1: one clean_policy() for both markets (market argument), emerging code maps for
#           construction_type (BRK/STN/WOD/MIX) and occupation (case, spaces, "Self-employed " prefix -> flag),
#           market column, emerging exposure fix logged row by row, the section 6 EDA plots dropped.
#           Target (as week 1): y_cost = sum of (incurred_to_date - recoveries) over the row's non-repudiated claims;
#           repudiated claims cost 0 and are not counted. Amounts are already net of the policy excess.
# Inputs  : data/week_1/raw data/*.parquet, data/week_2/raw data/emerging/*.parquet
# Outputs : data/week_2/optionB/clean/{developed,emerging}_{train,test}_<line>.parquet,
#           data/week_2/optionB/clean/{developed,emerging}_claims_matched.parquet,
#           week2/output/02_clean/ (cleaning_report.md, data_checks.csv, experience_by_year.csv,
#           unmatched_claims_<market>.csv, emerging_exposure_fixes.csv)
# Run     : Rscript week2/R/02_clean_week2.R      (from the repo root)
# Time    : about 2 minutes

source("week2/R/00_setup_week2.R")
start_script("02_clean_week2.R")
STEP <- "02_clean"

checks <- list()
add_check <- function(market, dataset, check, n, action) {
  checks[[length(checks) + 1]] <<- data.table(market = market, dataset = dataset, check = check, n = n, action = action)
}
pad_id <- function(x, width = 8) { s <- !is.na(x) & nchar(x) < width; x[s] <- paste0(strrep("0", width - nchar(x[s])), x[s]); x }

# Emerging codes -> developed canonical levels (decision D006); developed uses the week 1 rule
CONSTRUCTION_MAP <- c(BRK = "brick", STN = "stone", WOD = "timber", MIX = "non_standard",
                      BRICK = "brick", STONE = "stone", T = "timber", W = "timber", TIMBER = "timber",
                      NON_STANDARD = "non_standard")

clean_occupation <- function(x) {
  x <- trimws(x)
  se <- !is.na(x) & grepl("^self-employed ", x, ignore.case = TRUE)
  x <- sub("^self-employed ", "", x, ignore.case = TRUE)
  x <- ifelse(is.na(x), NA_character_, paste0(toupper(substr(x, 1, 1)), tolower(substr(x, 2, nchar(x)))))
  list(occupation = x, self_employed = se)
}

clean_market <- function(market) {
  rd <- if (market == "developed") read_dev else read_em
  customers <- rd("customers"); addresses <- rd("addresses"); weather <- rd("weather"); claims <- rd("claims")
  train_years <- if (market == "developed") 2021:2024 else 2023:2024

  # 1. Reference tables
  add_check(market, "customers", "duplicate customer_id", sum(duplicated(customers$customer_id)), "none expected")
  add_check(market, "addresses", "duplicate address_id", sum(duplicated(addresses$address_id)), "none expected")
  add_check(market, "weather", "duplicate address_id x year", sum(duplicated(weather, by = c("address_id", "year"))), "none expected")
  customers[, surname := NULL]
  oc <- clean_occupation(customers$occupation)
  add_check(market, "customers", "occupation changed by normalisation (case / spaces / prefix)",
            sum(oc$occupation != customers$occupation, na.rm = TRUE), "trimmed, sentence case, 'Self-employed ' prefix -> self_employed flag")
  customers[, `:=`(occupation = oc$occupation, self_employed = oc$self_employed)]
  setnames(weather, "year", "policy_year")
  weather_avg <- weather[policy_year %in% train_years, lapply(.SD, mean, na.rm = TRUE), by = address_id, .SDcols = WEATHER_VARS]
  setnames(weather_avg, WEATHER_VARS, paste0("wx_avg_", WEATHER_VARS))

  # 2. Policy cleaning (same function for train and test, both markets)
  clean_policy <- function(dt, line, dataset) {
    dt <- copy(dt); n0 <- nrow(dt)
    add_check(market, dataset, "customer_id shorter than 8 chars", sum(nchar(dt$customer_id) < 8, na.rm = TRUE), "left-padded to 8")
    dt[, customer_id := pad_id(customer_id)]

    dt[, exposure_raw := exposure]
    dt[, exposure := as.numeric(period_end - period_start + 1) / DAYS_PER_YEAR]
    dt[, flag_exposure_fixed := abs(exposure_raw - round(exposure, 4)) > 1e-6 & abs(exposure_raw - exposure) > 1e-6]
    add_check(market, dataset, "exposure inconsistent with period dates", sum(dt$flag_exposure_fixed),
              "recomputed as (period_end - period_start + 1) / 365")
    if (market == "emerging" && any(dt$flag_exposure_fixed))
      expo_fix[[dataset]] <<- dt[flag_exposure_fixed == TRUE, .(dataset, row_id, period_start, period_end, exposure_raw, exposure)]
    add_check(market, dataset, "period_end before period_start", sum(dt$period_end < dt$period_start), "none expected")

    if (line %in% c("buildings", "contents")) {
      si_cap <- c(buildings = 5e6, contents = 2e6)[[line]]
      dt[, flag_si_fixed := !is.na(sum_insured) & sum_insured > si_cap & sum_insured %% 1000 == 0]
      add_check(market, dataset, paste0("sum_insured > ", si_cap, " and divisible by 1000"), sum(dt$flag_si_fixed),
                "divided by 1000 (unit error, as week 1)")
      add_check(market, dataset, "sum_insured > cap and NOT divisible by 1000",
                sum(dt$sum_insured > si_cap & !dt$flag_si_fixed, na.rm = TRUE), "none expected")
      dt[flag_si_fixed == TRUE, sum_insured := sum_insured / 1000]
    }
    if (line == "buildings") {
      raw_ct <- dt$construction_type
      ct <- unname(CONSTRUCTION_MAP[toupper(trimws(raw_ct))])
      add_check(market, dataset, "construction_type code not in map", sum(is.na(ct) & !is.na(raw_ct)), "none expected")
      add_check(market, dataset, "construction_type recoded", sum(ct != raw_ct, na.rm = TRUE),
                "mapped to brick / stone / timber / non_standard")
      dt[, construction_type := ct]
    }
    if (line == "motor" && "driver_age" %in% names(dt)) {
      dt[, flag_licence_capped := !is.na(years_licensed) & !is.na(driver_age) & years_licensed > pmax(driver_age - 16L, 0L)]
      add_check(market, dataset, "years_licensed > driver_age - 16", sum(dt$flag_licence_capped), "capped at driver_age - 16")
      dt[flag_licence_capped == TRUE, years_licensed := pmax(driver_age - 16L, 0L)]
    }
    if (line == "motor" && "driver_age_band" %in% names(dt)) {
      upper <- c("17-24" = 24L, "25-34" = 34L, "35-49" = 49L, "50-64" = 64L, "65+" = 120L)[dt$driver_age_band]
      add_check(market, dataset, "years_licensed > band upper age - 16", sum(dt$years_licensed > upper - 16L, na.rm = TRUE),
                "none expected (no exact age to cap with)")
    }
    if ("renewal_decision" %in% names(dt)) dt[, renewal_decision := NULL]

    add_check(market, dataset, "duplicate row_id", sum(duplicated(dt$row_id)), "none expected")
    setorder(dt, policy_id, period_start)
    dt[, prev_end := shift(period_end), by = policy_id]
    add_check(market, dataset, "overlapping rows within a policy", sum(dt$period_start <= dt$prev_end, na.rm = TRUE), "none expected")
    dt[, prev_end := NULL]

    add_check(market, dataset, "customer_id not in customers", sum(!dt$customer_id %in% customers$customer_id), "none expected")
    add_check(market, dataset, "address_id not in addresses", sum(!dt$address_id %in% addresses$address_id), "none expected")
    dt[, policy_year := year(period_start)]
    dt <- merge(dt, customers, by = "customer_id", all.x = TRUE, sort = FALSE)
    dt <- merge(dt, addresses, by = "address_id", all.x = TRUE, sort = FALSE)
    dt <- merge(dt, weather, by = c("address_id", "policy_year"), all.x = TRUE, sort = FALSE)
    add_check(market, dataset, "rows without weather after join", sum(is.na(dt$hail_days) & is.na(dt$rainfall_mm)), "none expected")
    if (nrow(dt) != n0) stop(dataset, ": row count changed during joins")

    if ("date_of_birth" %in% names(dt)) {
      dt[, customer_age := as.integer(floor(as.numeric(period_start - date_of_birth) / 365.25))]
      dt[, date_of_birth := NULL]
    }
    dt[, start_month := month(period_start)]
    dt[, years_with_insurer := policy_year - customer_since_year]
    dt <- merge(dt, weather_avg, by = "address_id", all.x = TRUE, sort = FALSE)
    dt[, market := market]

    chr_cols <- names(dt)[vapply(dt, is.character, logical(1))]
    for (cn in setdiff(chr_cols, c("row_id", "policy_id", "customer_id", "address_id", "market")))
      set(dt, which(is.na(dt[[cn]])), cn, "missing")
    setcolorder(dt, c("market", "row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end",
                      "policy_year", "exposure"))
    setorder(dt, row_id)
    dt
  }

  # 3. Claims checks and net cost
  add_check(market, "claims", "duplicate claim_id", sum(duplicated(claims$claim_id)), "none expected")
  claims[, n_same := .N, by = .(policy_id, line, peril, loss_date, report_date, status, incurred_to_date)]
  claims[, flag_duplicate := !grepl("^CL[0-9]{8}$", claim_id) & n_same > 1]
  add_check(market, "claims", "non-standard claim_id duplicating another claim", sum(claims$flag_duplicate), "dropped (week 1 trap 10)")
  add_check(market, "claims", "paid > incurred", claims[paid_to_date > incurred_to_date + 1e-6, .N], "none expected")
  add_check(market, "claims", "recoveries > incurred", claims[recoveries > incurred_to_date + 1e-6, .N], "none expected")
  add_check(market, "claims", "report_date before loss_date", claims[report_date < loss_date, .N], "none expected")
  add_check(market, "claims", "repudiated with incurred > 0", claims[status == "repudiated" & incurred_to_date > 0, .N], "none expected")
  claims <- claims[flag_duplicate == FALSE][, c("flag_duplicate", "n_same") := NULL]
  claims[, counts := status != "repudiated"]
  claims[, net_cost := fifelse(counts, incurred_to_date - recoveries, 0)]
  claims[, report_lag := as.numeric(report_date - loss_date)]
  add_check(market, "claims", "negative net cost", claims[net_cost < 0, .N], "none expected")

  # 4. Lines: clean, match claims, targets
  matched <- list(); exper <- list()
  for (ln in LINES) {
    log_msg(market, ": cleaning ", ln)
    tr <- clean_policy(rd(paste0("policies_", ln)), ln, paste0("policies_", ln))
    te <- clean_policy(rd(paste0("test_", ln)), ln, paste0("test_", ln))
    cl <- claims[line == ln]
    m <- tr[cl, on = .(policy_id, period_start <= loss_date, period_end >= loss_date),
            .(claim_id = i.claim_id, row_id = x.row_id), allow.cartesian = TRUE]
    add_check(market, paste0("claims_", ln), "claims matching more than one row", m[!is.na(row_id), .N, by = claim_id][N > 1, .N], "none expected")
    cl <- merge(cl, unique(m, by = "claim_id"), by = "claim_id", all.x = TRUE)
    add_check(market, paste0("claims_", ln), "claims matching no policy row", sum(is.na(cl$row_id)), "excluded from targets; listed")
    add_check(market, paste0("claims_", ln), "unmatched with loss_date before first training year",
              sum(is.na(cl$row_id) & year(cl$loss_date) < min(train_years)), "book did not exist yet: dropped")
    matched[[ln]] <- cl
    mc <- cl[!is.na(row_id)]
    agg <- mc[, .(y_n_claims = sum(counts), y_cost = sum(net_cost), y_n_open = sum(status == "open"),
                  y_max_claim = max(net_cost)), by = row_id]
    for (pr in PERILS[[ln]]) {
      pa <- mc[counts == TRUE & peril == pr, .(cost = sum(net_cost), n = .N), by = row_id]
      setnames(pa, c("cost", "n"), paste0(c("y_cost_", "y_n_"), pr))
      agg <- merge(agg, pa, by = "row_id", all.x = TRUE)
    }
    tr <- merge(tr, agg, by = "row_id", all.x = TRUE, sort = FALSE)
    for (cn in grep("^y_", names(tr), value = TRUE)) set(tr, which(is.na(tr[[cn]])), cn, 0)
    add_check(market, paste0("policies_", ln), "negative row target", sum(tr$y_cost < 0), "none expected")
    for (cn in names(te)) if (is.character(te[[cn]]) && !cn %in% c("row_id", "policy_id", "customer_id", "address_id")) {
      unseen <- setdiff(unique(te[[cn]]), unique(tr[[cn]]))
      if (length(unseen)) add_check(market, paste0("test_", ln), paste0("levels unseen in train: ", cn), sum(te[[cn]] %in% unseen),
                                    paste(head(unseen, 5), collapse = ", "))
    }
    exper[[ln]] <- tr[, .(rows = .N, exposure = sum(exposure), claims = sum(y_n_claims), cost = sum(y_cost)), by = policy_year][
      , `:=`(market = market, line = ln, frequency = claims / exposure, severity = cost / claims, burn = cost / exposure)]
    write_w2(tr, file.path(W2$clean, sprintf("%s_train_%s.parquet", market, ln)))
    write_w2(te, file.path(W2$clean, sprintf("%s_test_%s.parquet", market, ln)))
    rm(tr, te); gc(verbose = FALSE)
  }
  cm <- rbindlist(matched, use.names = TRUE)
  write_w2(cm, file.path(W2$clean, sprintf("%s_claims_matched.parquet", market)))
  save_csv(cm[is.na(row_id), .(claim_id, policy_id, line, peril, loss_date, report_date, status, net_cost)],
           STEP, sprintf("unmatched_claims_%s.csv", market))
  rbindlist(exper)
}

expo_fix <- list()
experience <- rbindlist(lapply(c("developed", "emerging"), clean_market))
setcolorder(experience, c("market", "line", "policy_year"))
checks_dt <- rbindlist(checks)
save_csv(checks_dt, STEP, "data_checks.csv")
save_csv(experience, STEP, "experience_by_year.csv")
save_csv(rbindlist(expo_fix), STEP, "emerging_exposure_fixes.csv")

add_decision("D006", "2", "construction_type: emerging BRK->brick, STN->stone, WOD->timber, MIX->non_standard (developed: week 1 rule, T/W->timber)",
             "Keep emerging codes as their own levels (no developed relativity); MIX->own level",
             "week2/output/01_profile/categorical_levels.csv (shares 70/7/12/10% vs developed 72/8/12/10%)", "decided; MIX mapping checked by A/E in step 6")
add_decision("D007", "2", "occupation: trim, sentence case, 'Self-employed ' prefix removed and kept as flag self_employed (emerging only)",
             "Treat the 81 raw levels as distinct; drop occupation", "week2/output/02_clean/data_checks.csv", "decided")
add_decision("D008", "2", "Emerging claims with loss date before 2023 (34) and the 2 other unmatched 2023-24 claims are excluded from targets",
             "Attach to the nearest row", "week2/output/02_clean/unmatched_claims_emerging.csv", "decided")
add_decision("D009", "2", "Target as week 1: incurred - recoveries, repudiated = 0, not capped at cleaning; exposure recomputed from dates for every row",
             "Use raw exposure", "week2/output/02_clean/data_checks.csv", "decided")
add_assumption("A001", "2", "Exposure", "(period_end - period_start + 1) / 365 for every row", "developed (week 1 rule)", "", "none: 609 emerging rows fixed")
add_assumption("A002", "2", "sum_insured unit error", "> 5m buildings / > 2m contents and divisible by 1000 -> / 1000", "developed (week 1 rule)", "", "low")
add_assumption("A003", "2", "construction_type map", "BRK brick, STN stone, WOD timber, MIX non_standard", "judgement", "", "MIX mapping checked in step 6")

kl <- c(sprintf("- %s", checks_dt[market == "emerging" & n > 0, paste0(dataset, ": ", check, " = ", n)]),
        sprintf("- Emerging experience: %s", paste(experience[market == "emerging", sprintf("%s %d freq %.4f burn %.1f", line, policy_year, frequency, burn)], collapse = "; ")))
write_md(list("# Step 2: cleaning report (both markets)", "", paste("Generated", ts_sgt(), "by `week2/R/02_clean_week2.R`."), "",
              "## Checks", "", md_table(checks_dt), "## Experience after cleaning (reported at 31 Dec 2024, uncapped)", "",
              md_table(experience[, .(market, line, policy_year, rows, exposure, claims, frequency, severity, burn)], 4)), STEP, "cleaning_report.md")
update_step_log("2", "Clean both markets", kl)
end_script()
