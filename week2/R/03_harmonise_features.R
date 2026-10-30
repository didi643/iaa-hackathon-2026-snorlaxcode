# 03_harmonise_features.R ----------------------------------------------------------------
# Purpose : Build the SHARED feature set used by the developed baseline (step 5) and the emerging adjustments
#           (step 7), following the handover section 3 rules:
#             - age: developed exact ages -> the emerging bands 17-24 / 25-34 / 35-49 / 50-64 / 65+ (edges checked
#               against emerging years_licensed: 24 is in 17-24, 25 in 25-34), then the exact ages are dropped;
#             - dropped from developed: annual_mileage, telematics_*, credit_band, customer_age (date of birth), region;
#             - categorical levels compared between markets; emerging-only levels -> "other" (logged);
#             - claim history built the same way in both markets from that market's own claims, known at row start
#               (positive claims with loss in the prior policy year AND reported by 31 Dec of that year);
#             - gender excluded (D002); self_employed kept as an emerging-only column for step 7, never in the baseline.
# Inputs  : data/week_2/optionB/clean/{developed,emerging}_{train,test}_<line>.parquet, *_claims_matched.parquet
# Outputs : data/week_2/optionB/features/{developed,emerging}_{train,test}_<line>.parquet,
#           week2/output/03_features/feature_map.csv, level_map.csv, history_summary.csv, features_report.md
# Run     : Rscript week2/R/03_harmonise_features.R      (from the repo root)
# Time    : about 1 minute

source("week2/R/00_setup_week2.R")
start_script("03_harmonise_features.R")
STEP <- "03_features"
FEAT_DIR <- file.path(W2$data, "features")

band_age <- function(a) {
  b <- cut(a, c(-Inf, 24, 34, 49, 64, Inf), labels = AGE_BANDS, right = TRUE)
  out <- as.character(b); out[is.na(out)] <- "missing"; out
}

# Shared feature set per line (column -> role). Everything in the clean tables not listed is dropped (see map).
ID_COLS <- c("market", "row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end", "policy_year", "exposure")
SHARED <- list(
  policy_motor = c("driver_age_band", "years_licensed", "ncb_years", "vehicle_value_group", "vehicle_age", "make_model",
                   "engine_size_cc", "body_type", "transmission", "seats", "fuel_type", "driver_assist", "cover_type",
                   "overnight_parking", "vehicle_use", "named_young_driver"),
  policy_buildings = c("policyholder_age_band", "sum_insured", "construction_type", "occupancy", "days_unoccupied",
                       "smoke_alarms", "accidental_damage_cover", "mortgage"),
  policy_contents = c("policyholder_age_band", "sum_insured", "tenure", "security_level", "high_value_items",
                      "accidental_damage_cover", "works_from_home", "lodgers", "bicycle_cover"),
  policy_common = c("voluntary_excess", "channel", "payment_method", "missed_payments_12m", "new_business", "renewal_count",
                    "days_quote_to_inception", "discount_applied", "start_month"),
  customer = c("occupation", "marital_status", "household_size", "prior_claims_5y", "licence_points", "years_at_address",
               "previous_insurer"),
  address = c("urban_density", "flood_zone", "distance_to_river_km", "elevation_m", "soil_type", "year_built", "property_type",
              "roof_type", "basement", "trees_within_5m", "listed_building", "bedrooms", "energy_rating", "solar_panels"),
  weather = c(WEATHER_VARS, paste0("wx_avg_", WEATHER_VARS)),
  history = c("hist_policy_claims_prev", "hist_customer_claims_other_lines_prev")
)
EMERGING_ONLY_KEEP <- c("self_employed")      # for step 7 candidates only
DROP_REASON <- c(
  driver_age = "exact age not in emerging: replaced by driver_age_band", policyholder_age = "replaced by policyholder_age_band",
  annual_mileage = "not in emerging", telematics_opt_in = "not in emerging", telematics_score = "not in emerging",
  credit_band = "not in emerging", customer_age = "built from date_of_birth, not in emerging",
  region = "codes do not map (R01-R12 vs E01-E06); geography from address / weather fields",
  gender = "regulatory question, excluded until Wendy approves (D002)",
  compulsory_excess = "constant; week 1 guardrail", written_premium = "current price, circular (week 1 guardrail)",
  customer_service_contacts = "leakage: claim calls (re-checked in step 1)",
  email_domain = "marketing/noise", branch_id = "marketing/noise", campaign_code = "marketing/noise",
  marketing_segment = "marketing/noise", vehicle_colour = "noise", marketing_consent = "no causal path (week 1 Exclude)",
  document_preference = "no causal path (week 1 Exclude)", customer_since_year = "calendar cohort; duplicates renewal_count",
  years_with_insurer = "duplicates renewal_count", exposure_raw = "replaced by recomputed exposure",
  flag_exposure_fixed = "cleaning flag", flag_si_fixed = "cleaning flag", flag_licence_capped = "cleaning flag",
  self_employed = "emerging only (no developed relativity); kept as a step 7 candidate, not in the baseline")

pos_claims <- function(market) {
  cm <- read_w2(file.path(W2$clean, sprintf("%s_claims_matched.parquet", market)))
  cm[counts == TRUE & !is.na(row_id) & net_cost > 0, .(row_id, line, loss_year = year(loss_date), report_date)]
}

fmap <- list(); lvl_map <- list(); hist_sum <- list()
dev_levels <- list()
for (ln in LINES) {
  shared <- c(SHARED[[paste0("policy_", ln)]], SHARED$policy_common, SHARED$customer, SHARED$address, SHARED$weather, SHARED$history)
  tabs <- list()
  for (mk in c("developed", "emerging")) for (part in c("train", "test")) {
    dt <- read_w2(file.path(W2$clean, sprintf("%s_%s_%s.parquet", mk, part, ln)))
    if (mk == "developed") {
      if (ln == "motor") dt[, driver_age_band := band_age(driver_age)] else dt[, policyholder_age_band := band_age(policyholder_age)]
    }
    tabs[[paste(mk, part)]] <- dt
  }
  # Claim history, same construction in both markets (from each market's own claims)
  for (mk in c("developed", "emerging")) {
    clp <- pos_claims(mk)
    rowmap <- rbindlist(lapply(LINES, function(l) read_w2(file.path(W2$clean, sprintf("%s_train_%s.parquet", mk, l)))[
      , .(row_id, policy_id, customer_id, policy_year, line = l)]))
    hc <- merge(clp[year(report_date) <= loss_year, .(row_id, hist_year = loss_year)], rowmap, by = "row_id")
    pol_cnt <- hc[, .(n = .N), by = .(policy_id, hist_year)]
    cust_cnt <- hc[line != ln, .(n = .N), by = .(customer_id, hist_year)]
    pol_year_key <- unique(rowmap[line == ln, paste(policy_id, policy_year)])
    first_year <- min(rowmap$policy_year)
    for (part in c("train", "test")) {
      dt <- tabs[[paste(mk, part)]]
      dt[, hist_year := policy_year - 1L]
      dt[pol_cnt, on = .(policy_id, hist_year), hist_policy_claims_prev := as.numeric(i.n)]
      dt[is.na(hist_policy_claims_prev), hist_policy_claims_prev := 0]
      dt[!paste(policy_id, hist_year) %chin% pol_year_key | hist_year < first_year, hist_policy_claims_prev := NA]
      dt[cust_cnt, on = .(customer_id, hist_year), hist_customer_claims_other_lines_prev := as.numeric(i.n)]
      dt[is.na(hist_customer_claims_other_lines_prev), hist_customer_claims_other_lines_prev := 0]
      dt[hist_year < first_year, hist_customer_claims_other_lines_prev := NA]
      dt[, hist_year := NULL]
      hist_sum[[paste(ln, mk, part)]] <- dt[, .(rows = .N, share_hist_na = mean(is.na(hist_policy_claims_prev)),
                                                mean_hist_policy = mean(hist_policy_claims_prev, na.rm = TRUE),
                                                mean_hist_other = mean(hist_customer_claims_other_lines_prev, na.rm = TRUE)),
                                            by = policy_year][, `:=`(line = ln, market = mk, part = part)]
    }
  }
  # Categorical levels: emerging-only levels -> "other"; developed levels kept (the baseline encodes them)
  for (cn in shared) {
    v <- tabs[["developed train"]][[cn]]
    if (!(is.character(v) || is.logical(v))) next
    dl <- unique(as.character(c(v, tabs[["developed test"]][[cn]])))
    for (part in c("train", "test")) {
      e <- tabs[[paste("emerging", part)]]
      ev <- as.character(e[[cn]])
      new <- !is.na(ev) & !ev %in% dl
      if (any(new)) {
        lvl_map[[paste(ln, cn, part)]] <- data.table(line = ln, column = cn, part = part, level = unique(ev[new]),
                                                     rows = as.vector(table(ev[new])[unique(ev[new])]), mapped_to = "other")
        if (is.character(e[[cn]])) set(e, which(new), cn, "other")
      }
    }
  }
  # Write the harmonised tables
  ycols <- grep("^y_", names(tabs[["developed train"]]), value = TRUE)
  for (k in names(tabs)) {
    dt <- tabs[[k]]
    keep <- c(ID_COLS, shared, if (startsWith(k, "emerging")) EMERGING_ONLY_KEEP, intersect(ycols, names(dt)))
    miss <- setdiff(keep, names(dt))
    if (length(miss)) stop(k, " ", ln, ": missing columns ", paste(miss, collapse = ", "))
    out <- dt[, ..keep]
    write_w2(out, file.path(FEAT_DIR, sprintf("%s_%s.parquet", sub(" ", "_", k), ln)))
  }
  # Feature map rows
  all_dev <- names(tabs[["developed train"]]); all_em <- names(tabs[["emerging train"]])
  cols <- union(union(all_dev, all_em), shared)
  cols <- setdiff(cols, c(ID_COLS, ycols, "driver_age_band", "policyholder_age_band")[!c(ID_COLS, ycols, "driver_age_band", "policyholder_age_band") %in% shared])
  cols <- cols[!startsWith(cols, "y_")]
  fmap[[ln]] <- rbindlist(lapply(cols, function(cn) {
    kept <- cn %in% shared
    data.table(line = ln, column = cn,
               developed_source = if (cn %in% c("driver_age_band", "policyholder_age_band")) sub("_band", "", cn) else if (cn %in% all_dev) cn else "-",
               emerging_source = if (cn %in% all_em) cn else "-",
               transform = fcase(cn %in% c("driver_age_band", "policyholder_age_band"), "developed: exact age cut at 24/34/49/64 (right-closed)",
                                 cn == "construction_type", "codes mapped to brick/stone/timber/non_standard (D006)",
                                 cn == "occupation", "trim + sentence case; 'Self-employed ' prefix removed (D007)",
                                 startsWith(cn, "hist_"), "built per market from its own claims, known by 31 Dec of the prior year",
                                 startsWith(cn, "wx_avg_"), "address mean over the market's training years",
                                 cn %in% WEATHER_VARS, "address x policy year",
                                 default = "as cleaned"),
               status = if (kept) "kept" else "dropped",
               reason = if (kept) "shared by both markets, built the same way" else if (cn %in% names(DROP_REASON)) DROP_REASON[[cn]] else "not a rating factor")
  }))
}
fmap <- unique(rbindlist(fmap))
save_csv(fmap, STEP, "feature_map.csv")
lvl_map <- rbindlist(lvl_map)
save_csv(if (nrow(lvl_map)) lvl_map else data.table(line = character(), column = character(), part = character(), level = character(),
                                                     rows = integer(), mapped_to = character()), STEP, "level_map.csv")
hist_sum <- rbindlist(hist_sum)
save_csv(hist_sum, STEP, "history_summary.csv")

# Band check in developed: claims frequency by band (sanity only)
add_decision("D010", "3", "Age: developed exact ages cut into the emerging bands 17-24/25-34/35-49/50-64/65+ (right-closed: 24 in 17-24); exact ages dropped",
             "Midpoints imputed into emerging (biases non-linear models)", "week2/output/03_features/feature_map.csv; emerging years_licensed max per band = upper age - 17", "decided")
add_decision("D011", "3", "Shared feature set only in the baseline; region, credit_band, annual_mileage, telematics, customer_age dropped; premium-based fields excluded",
             "Impute missing developed-only fields for emerging", "week2/output/03_features/feature_map.csv", "decided")
add_decision("D012", "3", "Claim history features kept (prior-year own policy, customer's other lines), built per market from its own claims, known at row start",
             "Drop history (emerging has at most 1 prior year; 77% of test rows are new business -> NA)", "week2/output/03_features/history_summary.csv", "decided")
add_decision("D013", "3", "self_employed (emerging-only occupation prefix) not in the baseline; candidate factor in step 7",
             "Drop it", "week2/output/02_clean/data_checks.csv", "decided")
add_assumption("A004", "3", "Age band edges", "17-24, 25-34, 35-49, 50-64, 65+ (inclusive)", "emerging (band labels) + developed (exact ages)", "",
               "none: emerging years_licensed max 7/17/32/47 per band = upper age - 17")

kl <- c(sprintf("- Features kept per line: %s.", paste(fmap[status == "kept", .N, by = line][, paste(line, N)], collapse = ", ")),
        sprintf("- Emerging-only levels sent to 'other': %d level(s), %d rows.", nrow(lvl_map), if (nrow(lvl_map)) sum(lvl_map$rows) else 0L),
        sprintf("- History NA share: emerging test %s; developed test %s.",
                paste(hist_sum[market == "emerging" & part == "test", sprintf("%s %.2f", line, share_hist_na)], collapse = ", "),
                paste(hist_sum[market == "developed" & part == "test", sprintf("%s %.2f", line, share_hist_na)], collapse = ", ")))
write_md(list("# Step 3: harmonised features", "", paste("Generated", ts_sgt(), "by `week2/R/03_harmonise_features.R`."), "", kl, "",
              "## Feature map", "", md_table(fmap), "## Emerging-only levels", "", if (nrow(lvl_map)) md_table(lvl_map) else "None.", "",
              "## History features", "", md_table(hist_sum, 3)), STEP, "features_report.md")
update_step_log("3", "Harmonise features", kl)
end_script()
