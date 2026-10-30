# 5c_portfolio_w2.R ----------------------------------------------------------------------------------------------
# Week 2 step 5c: what is different about the 2025 test portfolio (the broker take-on), and does the model's
# new-business uplift apply to it? Descriptive only (no model fit).
#   1. Mix by policy year: new business, January starts, exposure, channel, region, key risk features
#   2. Groups: renewal / new business starting in January (the broker book in 2025) / new business starting later
#   3. Developed market 2021-23 (fully developed): frequency and burn per group and by exposure band - is the
#      new-business uplift real for full-year January starts, or an artefact of short mid-year policies?
#   4. Emerging 2023-24 (reported): the same groups
# Run:  Rscript week2/R/5c_portfolio_w2.R
# Out:  week2/output/5c_portfolio/ (portfolio_report.md, mix_by_year.csv, group_profile.csv, group_experience.csv)

source("week2/R/0_setup_w2.R")
STEP <- "5c_portfolio"
grp_of <- function(d) fifelse(!d$new_business, "renewal", fifelse(d$start_month == 1L, "nb_january", "nb_later"))
PROFILE <- c("days_quote_to_inception", "prior_claims_5y", "licence_points", "missed_payments_12m", "ncb_years", "voluntary_excess",
             "vehicle_age", "year_built")

mix <- list(); prof <- list(); expv <- list(); band <- list()
for (ln in LINES) {
  e <- read_clean_w2(paste0("emerging_train_", ln)); t <- read_clean_w2(paste0("emerging_test_", ln))[, policy_year := 2025L]
  a <- rbind(e, t, fill = TRUE); a[, group := grp_of(a)]
  mix[[ln]] <- a[, .(line = ln, rows = .N, mean_exposure = mean(exposure), pct_new_business = 100 * mean(new_business),
                     pct_january_start = 100 * mean(start_month == 1L), pct_broker = 100 * mean(channel == "broker"),
                     mean_renewal_count = mean(renewal_count)), by = policy_year]
  pc <- intersect(PROFILE, names(a))
  prof[[ln]] <- a[, c(list(line = ln, rows = .N, mean_exposure = mean(exposure)), lapply(.SD, function(v) mean(as.numeric(v), na.rm = TRUE))),
                  by = .(policy_year, group), .SDcols = pc]
  ex_e <- e[, .(line = ln, market = "emerging (reported)", rows = .N, mean_exposure = mean(exposure),
                freq = sum(y_n_claims) / sum(exposure), burn = sum(y_cost) / sum(exposure)), by = .(policy_year, group = grp_of(e))]
  d <- read_clean_w2(paste0("developed_train_", ln))[policy_year <= 2023L]
  d[, group := grp_of(d)]
  ex_d <- d[, .(line = ln, market = "developed 2021-23", policy_year = NA_integer_, rows = .N, mean_exposure = mean(exposure),
                freq = sum(y_n_claims) / sum(exposure), burn = sum(y_cost) / sum(exposure)), by = group]
  expv[[ln]] <- rbind(ex_d, ex_e, use.names = TRUE)
  d[, exposure_band := cut(exposure, c(0, 0.25, 0.5, 0.75, 0.95, 1.01))]
  band[[ln]] <- dcast(d[, .(freq = sum(y_n_claims) / sum(exposure)), by = .(group, exposure_band)], exposure_band ~ group, value.var = "freq")[, line := ln]
}
mix <- rbindlist(mix); prof <- rbindlist(prof, fill = TRUE)[order(line, group, policy_year)]; expv <- rbindlist(expv)[order(line, market, group, policy_year)]
band <- rbindlist(band, fill = TRUE)
rel <- expv[market == "developed 2021-23", .(group, freq_vs_renewal = freq / freq[group == "renewal"], burn_vs_renewal = burn / burn[group == "renewal"]), by = line]

save_csv_w2(mix, STEP, "mix_by_year.csv"); save_csv_w2(prof, STEP, "group_profile.csv")
save_csv_w2(expv, STEP, "group_experience.csv"); save_csv_w2(band, STEP, "developed_freq_by_exposure_band.csv")
write_md_w2(list(
  "# Week 2 - Step 5c: the 2025 portfolio (broker take-on)", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "by `week2/R/5c_portfolio_w2.R`. Groups: renewal; new business starting in January",
        "(`nb_january`, the broker book in 2025); new business starting later in the year (`nb_later`)."), "",
  "## Mix by policy year", "", md_table(mix, 2),
  "## Risk profile by group", "", md_table(prof, 2),
  "## Experience by group", "", "Developed is fully developed; emerging is reported at 31 Dec 2024 (2024 not yet developed).", "",
  md_table(expv, 4),
  "Developed relativities to renewals:", "", md_table(rel, 3),
  "## Developed frequency by exposure band (is the uplift a short-policy artefact?)", "", md_table(band, 4)
), STEP, "portfolio_report.md")
print(mix); print(rel)
log_msg("Step 5c done")
