# 17_peril_headroom.R --------------------------------------------------------------------------------------------------
# Purpose : Which peril is weakest? Per line x peril on the emerging 2024 fold (run RUN_TAG, default sub4): achieved cost D2
#           (Tweedie p 1.5 vs constant mean, developed actuals) against a per-peril ceiling (the model taken as the truth:
#           Poisson counts, Gamma claim sizes with the peril's emerging claim CV, 100 simulations, perfect model scored),
#           plus A/E and the peril's share of 2024 cost and of the line's 2025 burn. Headroom = ceiling - achieved.
# Inputs  : data/week_2/optionB/adjust/<tag>/valid_2024_peril.parquet, emerging claims, week2/output/10_final/burn_by_peril.csv
# Outputs : week2/output/17_headroom/peril_headroom_<tag>.csv
# Run     : RUN_TAG=sub4 Rscript week2/R/17_peril_headroom.R
# Time    : under a minute

source("week2/R/00_setup_week2.R")
start_script("17_peril_headroom.R")
TAG <- Sys.getenv("RUN_TAG", "sub4")
clp <- claim_basis("emerging")
v <- merge(read_w2(file.path(W2$data, "adjust", TAG, "valid_2024_peril.parquet")), clp[, .(adj = sum(cost)), by = .(row_id, peril)],
           by = c("row_id", "peril"), all.x = TRUE)
v[is.na(adj), adj := 0][, `:=`(pred = exposure * freq_B * sev_B, dev = adj / share)]
d2c <- function(y, mu) 1 - sum(tweedie_dev(y, mu)) / sum(tweedie_dev(y, rep(mean(y), length(y))))
cv <- clp[, .(cv = sd(cost) / mean(cost)), by = .(line, peril)]
set.seed(SEED)
res <- rbindlist(lapply(split(v[freq_B > 0], by = c("line", "peril")), function(d) {
  ln <- d$line[1]; pr <- d$peril[1]; k <- 1 / cv[line == ln & peril == pr, cv]^2
  mu_n <- d$exposure * d$freq_B * d$share
  sim <- replicate(100, { n <- rpois(nrow(d), mu_n); c <- ifelse(n > 0, rgamma(nrow(d), shape = pmax(n, 1) * k, scale = d$sev_B / k), 0)
                          d2c(c / d$share, d$pred) })
  data.table(line = ln, peril = pr, claims_2024 = sum(d$n), cost_share_2024 = sum(d$dev), achieved = d2c(d$dev, d$pred),
             ceiling = mean(sim), ceiling_p5 = quantile(sim, 0.05), ceiling_p95 = quantile(sim, 0.95), ae = sum(d$dev) / sum(d$pred), claim_cv = 1 / sqrt(k))
}))
res[, cost_share_2024 := cost_share_2024 / sum(cost_share_2024), by = line]
res[, `:=`(headroom = ceiling - achieved, pct_of_ceiling = achieved / ceiling)]
bp <- fread(file.path(W2$output, "10_final", "burn_by_peril.csv"))[, .(line, peril, burn_2025, burn_share_2025 = burn_2025 / sum(burn_2025)), by = line]
res <- merge(res, bp[, .(line, peril, burn_2025, burn_share_2025)], by = c("line", "peril"))
res[, weighted_headroom := headroom * burn_share_2025]
save_csv(res[order(-weighted_headroom)], "17_headroom", sprintf("peril_headroom_%s.csv", TAG))
print(res[order(-weighted_headroom), .(line, peril, claims_2024, achieved = round(achieved, 3), ceiling = round(ceiling, 3), p5 = round(ceiling_p5, 3),
          pct = round(pct_of_ceiling, 2), ae = round(ae, 2), burn_share = round(burn_share_2025, 2), w_headroom = round(weighted_headroom, 4))])
end_script()
