# 4_check_ceiling.R ---------------------------------------------------------------------------------------------
# How much D2 is there to win? Treats a run's per-peril row predictions as the TRUE expected cost, simulates claims
# around them (Poisson counts, Gamma severities with each peril's observed mean and CV) and scores the predictions on
# the simulated actuals. That is the D2 a perfect model would get if the real risk spread were what the model says.
# Then the spread is widened (log relativities x k around each peril's mean) to show how much more
# differentiation the data would need to hold for a perfect model to reach a given D2 (e.g. 0.25).
#
# Run:  RUN_TAG=wendy07_report_share Rscript week1/R/4_check_ceiling.R      (needs row_preds_peril.parquet from week1/R/oof_io.R)
# Out:  week1/output/4_check_reported/<tag>/ceiling.csv

source("week1/R/0_setup.R")
source("week1/R/oof_io.R")
TAG <- Sys.getenv("RUN_TAG", "wendy07_report_share")
NSIM <- as.integer(Sys.getenv("NSIM", "5"))
SPREAD <- as.numeric(strsplit(Sys.getenv("SPREAD", "1,1.5,2,3"), ",")[[1]])

pp <- read_row_preds(TAG, level = "peril")
cl <- read_clean("claims_matched")[counts == TRUE & !is.na(row_id) & net_cost > 0]
sev <- cl[, .(mu = mean(net_cost), cv = sd(net_cost) / mean(net_cost), n = .N), by = .(line, peril)]

set.seed(SEED)
res <- list()
for (k in SPREAD) for (s in seq_len(NSIM)) {
  sims <- rbindlist(lapply(LINES, function(ln) {
    d <- pp[line == ln]
    tot_p <- tot_y <- numeric(nrow(d))
    for (pr in PERILS[[ln]]) {
      p <- d[[paste0("pred_", pr)]]
      if (k != 1) {                                   # widen relativities, keep each fold's peril total
        lp <- log(pmax(p / d$exposure, 1e-9))
        for (vy in unique(d$valid_year)) {
          i <- d$valid_year == vy
          q <- exp(mean(lp[i]) + k * (lp[i] - mean(lp[i]))) * d$exposure[i]
          p[i] <- q * sum(p[i]) / sum(q)
        }
      }
      sv <- sev[line == ln & peril == pr]
      shape <- 1 / sv$cv^2
      n <- rpois(length(p), p / sv$mu)
      y <- numeric(length(p)); j <- which(n > 0)
      y[j] <- rgamma(length(j), shape = n[j] * shape, rate = shape / sv$mu)
      tot_p <- tot_p + p; tot_y <- tot_y + y
    }
    data.table(valid_year = d$valid_year, line = ln, exposure = d$exposure, pred = tot_p, y = tot_y)
  }))
  res[[paste(k, s)]] <- rbind(sims[, .(d2 = oof_d2(y, pred, exposure)), by = .(valid_year, line)],
                              sims[, .(line = "ALL", d2 = oof_d2(y, pred, exposure)), by = valid_year])[
    , `:=`(spread = k, sim = s)]
}
res <- rbindlist(res)
out <- res[, .(perfect_model_d2 = mean(d2), sd_over_sims = sd(d2)), by = .(spread, line)]
fwrite(out, file.path(oof_dir(TAG), "ceiling.csv"))
print(dcast(out, spread ~ line, value.var = "perfect_model_d2"))
log_msg("Done: ", file.path(oof_dir(TAG), "ceiling.csv"))
