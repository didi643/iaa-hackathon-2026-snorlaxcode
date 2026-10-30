# 6_telematics_study.R -----------------------------------------------------------------------------------
# Telematics feature engineering for motor, and where it adds signal beyond MOTOR 2.
#   Features (per row, from the row and the same policy's previous row - all known at the row start):
#     tele_prev_score, tele_delta (score - previous score), tele_years (years opted in so far), tele_new (opted in this
#     year, not last), tele_dropped (opted in last year, not now), tele_rel (score - mean score of the driver-age band x
#     young-driver group), tele_risk_miles ((100 - score) x mileage / 10k), mileage_missing, mileage_round (multiple
#     of 500), mileage_prev, mileage_delta, tele_band (score bands; 'none' = not opted in)
#   Residual check: actual / expected (A/E) by feature band, per peril, on the 2023 and 2024 folds, where expected =
#   MOTOR 2 frozen GLM peril cost (week1/models/motor_iteration_04/components.parquet) and actual = developed peril cost.
# Writes data/week_1/telematics/tele_features.parquet (row_id + features) and week1/output/6_telematics_study/*.csv

source("week1/R/0_setup.R")
OUT <- file.path(PATHS$output, "6_telematics_study")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("data", "week_1", "telematics"), recursive = TRUE, showWarnings = FALSE)
PRM <- PERILS$motor

tr <- read_raw("policies_motor"); te <- read_raw("test_motor")
d <- rbind(tr[, .(row_id, policy_id, period_start, driver_age, named_young_driver, telematics_opt_in, telematics_score, annual_mileage)],
           te[, .(row_id, policy_id, period_start, driver_age, named_young_driver, telematics_opt_in, telematics_score, annual_mileage)])
d[, `:=`(period_start = as.IDate(period_start), opt = telematics_opt_in %in% TRUE)]
setorder(d, policy_id, period_start)
d[, `:=`(prev_opt = shift(opt), prev_score = shift(telematics_score), prev_miles = shift(annual_mileage),
         has_prev = seq_len(.N) > 1), by = policy_id]
d[, tele_years := cumsum(opt), by = policy_id]
d[, age_band := cut(driver_age, c(-Inf, 25, 30, 40, 50, 60, 70, Inf))]
d[, grp_mean := mean(telematics_score, na.rm = TRUE), by = .(age_band, named_young_driver)]
f <- d[, .(row_id,
           tele_prev_score = prev_score,
           tele_delta = telematics_score - prev_score,
           tele_years = fifelse(opt, as.numeric(tele_years), 0),
           tele_new = as.integer(opt & has_prev & !(prev_opt %in% TRUE)),
           tele_dropped = as.integer(!opt & prev_opt %in% TRUE),
           tele_rel = telematics_score - grp_mean,
           tele_risk_miles = (100 - telematics_score) * annual_mileage / 1e4,
           mileage_missing = as.integer(is.na(annual_mileage)),
           mileage_round = as.integer(!is.na(annual_mileage) & annual_mileage %% 500 == 0),
           mileage_prev = prev_miles,
           mileage_delta = annual_mileage - prev_miles,
           tele_band = fifelse(!opt, "none", as.character(cut(telematics_score, c(0, 40, 50, 60, 70, 80, 100)))))]
write_parquet(f, file.path("data", "week_1", "telematics", "tele_features.parquet"))
print(f[, .(rows = .N, opt = mean(tele_band != "none"), new = mean(tele_new), dropped = mean(tele_dropped),
            delta_known = mean(!is.na(tele_delta)), mileage_round = mean(mileage_round), mileage_missing = mean(mileage_missing))])
print(d[, .(round_share = mean(annual_mileage %% 500 == 0, na.rm = TRUE), miss = mean(is.na(annual_mileage))), by = opt])

# Residual A/E against MOTOR 2 (developed actual / MOTOR 2 GLM cost), per peril and feature band ------------------
comp <- as.data.table(read_parquet(file.path("week1", "models", "motor_iteration_04", "components.parquet")))[valid_year %in% c(2023, 2024)]
x <- merge(comp[, c("valid_year", "row_id", "exposure", paste0("glm_", PRM), paste0("dev_", PRM)), with = FALSE], f, by = "row_id")
bands <- list(
  tele_band = x$tele_band,
  tele_delta = cut(x$tele_delta, c(-Inf, -10, -3, 3, 10, Inf)),
  tele_years = cut(x$tele_years, c(-Inf, 0, 1, 2, Inf)),
  tele_new = factor(x$tele_new), tele_dropped = factor(x$tele_dropped),
  tele_rel = cut(x$tele_rel, c(-Inf, -15, -5, 5, 15, Inf)),
  tele_risk_miles = cut(x$tele_risk_miles, c(-Inf, 2, 4, 6, 8, Inf)),
  mileage_missing = factor(x$mileage_missing), mileage_round = factor(x$mileage_round),
  mileage_delta = cut(x$mileage_delta, c(-Inf, -2000, -1, 0, 2000, Inf)))
ae <- rbindlist(lapply(names(bands), function(b) {
  g <- bands[[b]]
  rbindlist(lapply(PRM, function(p) {
    a <- x[[paste0("dev_", p)]]; e <- x[[paste0("glm_", p)]]
    # rescale expected to actual per year so A/E is about ranking, not level
    e <- e * ave(a, x$valid_year, FUN = sum) / ave(e, x$valid_year, FUN = sum)
    data.table(feature = b, band = as.character(g), peril = p, year = x$valid_year, a = a, e = e, expo = x$exposure)[
      , .(exposure = sum(expo), claims_cost = sum(a), ae = sum(a) / sum(e)), by = .(feature, band, peril, year)]
  }))
}))
aew <- dcast(ae, feature + band + peril ~ year, value.var = c("exposure", "ae"))
setorder(aew, feature, peril, band)
fwrite(aew, file.path(OUT, "ae_by_feature.csv"))
# signal summary: exposure-weighted absolute log A/E per feature and peril (both years agreeing = real)
sig <- aew[!is.na(band) & exposure_2023 > 2000, .(
  spread_2023 = weighted.mean(abs(log(pmax(ae_2023, 0.01))), exposure_2023),
  spread_2024 = weighted.mean(abs(log(pmax(ae_2024, 0.01))), exposure_2024),
  agree = cor(log(pmax(ae_2023, 0.01)), log(pmax(ae_2024, 0.01)), use = "complete.obs")), by = .(feature, peril)]
setorder(sig, -agree)
fwrite(sig, file.path(OUT, "signal_summary.csv"))
print(sig, digits = 3)
options(width = 200)
print(aew[feature %in% c("tele_band", "tele_delta", "tele_years", "tele_new", "tele_dropped", "mileage_round", "mileage_missing") &
            peril %in% c("bodily_injury", "third_party_prop", "own_damage")], digits = 3)
