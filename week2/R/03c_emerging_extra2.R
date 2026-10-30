# 03c_emerging_extra2.R -------------------------------------------------------------------------------------------------
# Purpose : X21 feature round (27 Oct 2026): new emerging-only candidate fields for the step 7 adjustments, kept apart from
#           the shared feature tables (the developed baseline never sees them). Offered to step 7 through X_NEW.
#   credit_tier  marketing_segment suffix (affluent / mainstream / budget) = developed credit_band A-B / C / D-E
#   region       E01-E06 (not used anywhere before X21)
#   n_lines      distinct lines held by the customer in the same policy year (1 / 2 / 3), multi-line holding
#   val_age_b    motor: vehicle_value_group / (vehicle_age + 1) quartiles (train edges); vehicle_age missing -> "missing"
#   bldg_age_b   buildings, contents: policy_year - year_built in bands <=20, 21-50, 51-80, >80 years
#   miss_n       number of missing fields in the line's partially-missing set (0 / 1 / 2 / 3+); data-quality proxy
#   va_missing   motor: vehicle_age missing (TRUE / FALSE)
# Inputs  : data/week_2/optionB/clean/emerging_{train,test}_<line>.parquet
# Outputs : data/week_2/optionB/features/emerging_extra2_{train,test}_<line>.parquet
# Run     : Rscript week2/R/03c_emerging_extra2.R
# Time    : seconds

source("week2/R/00_setup_week2.R")
start_script("03c_emerging_extra2.R")
MISS_FIELDS <- list(
  motor = c("vehicle_age", "engine_size_cc", "overnight_parking", "occupation", "marital_status", "household_size", "years_at_address",
            "distance_to_river_km", "soil_type", "roof_type", "energy_rating"),
  buildings = c("days_unoccupied", "smoke_alarms", "occupation", "marital_status", "household_size", "years_at_address",
                "distance_to_river_km", "soil_type", "roof_type", "energy_rating"),
  contents = c("security_level", "high_value_items", "occupation", "marital_status", "household_size", "years_at_address",
               "distance_to_river_km", "soil_type", "roof_type", "energy_rating"))
dat <- list()
for (ln in LINES) for (part in c("train", "test")) dat[[part]][[ln]] <- read_w2(file.path(W2$clean, sprintf("emerging_%s_%s.parquet", part, ln)))
for (part in c("train", "test")) {
  hold <- rbindlist(lapply(LINES, function(ln) unique(dat[[part]][[ln]][, .(customer_id, policy_year, line = ln)])))
  hold <- hold[, .(n_lines = as.character(uniqueN(line))), by = .(customer_id, policy_year)]
  for (ln in LINES) dat[[part]][[ln]] <- merge(dat[[part]][[ln]], hold, by = c("customer_id", "policy_year"), all.x = TRUE)
}
vr <- dat$train$motor[, as.numeric(vehicle_value_group) / (as.numeric(vehicle_age) + 1)]
VA_BR <- unique(quantile(vr, seq(0, 1, 0.25), na.rm = TRUE)); VA_BR[1] <- -Inf; VA_BR[length(VA_BR)] <- Inf
for (ln in LINES) for (part in c("train", "test")) {
  d <- dat[[part]][[ln]]
  is_miss <- function(x) is.na(x) | (is.character(x) & x %in% "missing")
  mn <- Reduce(`+`, lapply(MISS_FIELDS[[ln]], function(v) as.integer(is_miss(d[[v]]))))
  o <- d[, .(row_id, credit_tier = sub(".*_", "", marketing_segment), region = fifelse(is.na(region), "missing", region), n_lines,
             miss_n = fifelse(mn >= 3, "3+", as.character(mn)))]
  if (ln == "motor") {
    va <- as.character(cut(as.numeric(d$vehicle_value_group) / (as.numeric(d$vehicle_age) + 1), VA_BR, dig.lab = 4)); va[is.na(va)] <- "missing"
    o[, `:=`(val_age_b = va, va_missing = as.character(is.na(d$vehicle_age)))]
  } else {
    age <- d$policy_year - as.numeric(d$year_built)
    o[, bldg_age_b := as.character(cut(age, c(-Inf, 20, 50, 80, Inf), labels = c("le20", "21_50", "51_80", "gt80")))][is.na(bldg_age_b), bldg_age_b := "missing"]
  }
  write_w2(o, file.path(W2$data, "features", sprintf("emerging_extra2_%s_%s.parquet", part, ln)))
  log_msg(sprintf("%s %s: %d rows; credit_tier %s; n_lines %s; miss_n %s", ln, part, nrow(o), paste(names(table(o$credit_tier)), table(o$credit_tier), collapse = " "),
                  paste(names(table(o$n_lines)), table(o$n_lines), collapse = " "), paste(names(table(o$miss_n)), table(o$miss_n), collapse = " ")))
}
update_step_log("3c", "X21 emerging-only fields (credit_tier, region, n_lines, val_age_b, bldg_age_b, miss_n, va_missing)",
                "- Offered to step 7 only through X_NEW; developed baseline unchanged.")
end_script()