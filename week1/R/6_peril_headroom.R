# 6_peril_headroom.R -------------------------------------------------------------------------------------
# Which peril is worth improving? Per peril, inside the 0.12965 pipeline (WENDY 9 + MOTOR 2 motor member at m 0.5,
# before credibility), all-line Tweedie D2 vs reported_raw on the 2023 / 2024 folds:
#   cost_share       share of all-line reported cost
#   peril_d2c        calibrated D2 of the peril component alone (ranking quality)
#   value_ranking    all-line D2 lost if the peril's component is flattened (exposure x mean rate) = what its ranking earns now
#   rate_per_0.01    all-line D2 change per +0.01 peril D2 (slope from a 10% blend toward flat) = exchange rate
#   gain_level       all-line D2 gain if the peril's level were set to the fold's actual total (level oracle)
#   gain_best_alt    all-line D2 gain from the best other component we already have (lad / c5 / MOTOR 4-5 versions)
# Output: week1/output/6_peril_headroom/peril_headroom.csv (+ by-year detail)

source("week1/R/0_setup.R")
HO <- file.path("week1", "handover", "w9_handover", "w9_handover")
OUT <- file.path(PATHS$output, "6_peril_headroom")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
YRS <- c(2023L, 2024L)
W <- list(motor = c(own_damage = 0, third_party_prop = 1, bodily_injury = 0, theft = 0, glass_hail = 1),
          buildings = c(storm = 1, flood = 0, escape_of_water = 0, subsidence = 0.5, fire = 0.25, accidental_damage = 0.25),
          contents = c(theft = 0, escape_of_water = 0.75, accidental_damage = 0, flood = 0.75))
LW <- c(motor = 0.9, buildings = 0.7, contents = 0.9)
A_CRED <- c(motor = 8, buildings = 5, contents = 5)
M_MEMBER <- 0.5

tdev <- function(y, mu, p = 1.5) {
  mu <- pmax(mu, 1e-12)
  2 * sum(ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
d2 <- function(y, mu, e) 1 - tdev(y, mu) / tdev(y, e * sum(y) / sum(e))
d2c <- function(y, mu, e) d2(y, mu * sum(y) / sum(mu), e)
num <- function(Q, col) {
  v <- as.numeric(Q[[col]])
  v[is.na(v)] <- 0
  v
}
comp_w9 <- function(Q, ln, p) W[[ln]][[p]] * num(Q, paste0("lad_", p)) + (1 - W[[ln]][[p]]) * num(Q, paste0("c5_", p))
line_pred <- function(Q, ln, comps) {
  b <- LW[[ln]] * Reduce(`+`, comps) + (1 - LW[[ln]]) * num(Q, "sam3")
  if (ln == "motor") b <- (1 - M_MEMBER) * b + M_MEMBER * Q$m2 * sum(b) / sum(Q$m2)
  q <- b * (A_CRED[[ln]] + num(Q, "N")) / (A_CRED[[ln]] + num(Q, "E"))
  q * sum(b) / sum(q)
}

D <- lapply(setNames(LINES, LINES), function(ln) as.data.table(read_parquet(file.path(HO, "panel", paste0("panel_", ln, ".parquet"))))[valid_year %in% YRS])
m2 <- as.data.table(read_parquet(file.path("week1", "models", "motor_iteration_02", "fold_predictions.parquet")))[valid_year %in% YRS, .(row_id, valid_year, m2 = pred_final)]
D$motor <- merge(D$motor, m2, by = c("row_id", "valid_year"), sort = FALSE)
alt_f <- file.path("week1", "models", "motor_iteration_05", "components.parquet")
ALT_M <- c("glm", "lgb", "boost", "gam_own", "gam_pool", "gam_mix")
if (file.exists(alt_f)) {
  a <- as.data.table(read_parquet(alt_f))[valid_year %in% YRS]
  keep <- c("row_id", "valid_year", intersect(names(a), as.vector(outer(ALT_M, PERILS$motor, paste, sep = "_"))))
  D$motor <- merge(D$motor, a[, ..keep], by = c("row_id", "valid_year"), sort = FALSE)
}

res <- list()
for (vy in YRS) {
  Y <- lapply(D, function(x) x[valid_year == vy])
  base_comps <- lapply(setNames(LINES, LINES), function(ln) lapply(setNames(PERILS[[ln]], PERILS[[ln]]), function(p) comp_w9(Y[[ln]], ln, p)))
  act <- lapply(setNames(LINES, LINES), function(ln) Reduce(`+`, lapply(PERILS[[ln]], function(p) num(Y[[ln]], paste0("act_", p)))))
  yall <- unlist(act, use.names = FALSE)
  eall <- unlist(lapply(Y, function(x) num(x, "exposure")), use.names = FALSE)
  all_d2 <- function(over_ln = NULL, over_p = NULL, new = NULL) {
    pr <- unlist(lapply(LINES, function(ln) {
      cc <- base_comps[[ln]]
      if (identical(ln, over_ln)) cc[[over_p]] <- new
      line_pred(Y[[ln]], ln, cc)
    }), use.names = FALSE)
    d2(yall, pr, eall)
  }
  base <- all_d2()
  tot_cost <- sum(yall)
  for (ln in LINES) for (p in PERILS[[ln]]) {
    Q <- Y[[ln]]; e <- num(Q, "exposure"); y <- num(Q, paste0("act_", p)); cp <- base_comps[[ln]][[p]]
    flat <- e * sum(cp) / sum(e)
    pd <- d2c(y, cp, e)
    b90 <- 0.9 * cp + 0.1 * flat
    slope <- (base - all_d2(ln, p, b90)) / (pd - d2c(y, b90, e)) * 0.01
    alts <- list(lad = num(Q, paste0("lad_", p)), c5 = num(Q, paste0("c5_", p)))
    if (ln == "motor") for (v in ALT_M) if (paste0(v, "_", p) %in% names(Q)) alts[[v]] <- Q[[paste0(v, "_", p)]]
    ag <- vapply(alts, function(x) all_d2(ln, p, x * sum(cp) / sum(x)) - base, numeric(1))
    ad <- vapply(alts, function(x) d2c(y, x, e), numeric(1))
    res[[length(res) + 1]] <- data.table(
      valid_year = vy, line = ln, peril = p, cost_share = sum(y) / tot_cost, claim_rows = sum(y > 0),
      ae = sum(y) / sum(cp), peril_d2c = pd, value_ranking = base - all_d2(ln, p, flat), rate_per_0.01 = slope,
      gain_level = all_d2(ln, p, cp * sum(y) / sum(cp)) - base,
      alt_name = names(alts), alt_peril_d2c = ad, alt_gain = ag)
  }
  log_msg(vy, " base all-line D2 ", round(base, 5))
}
det <- rbindlist(res)
fwrite(det, file.path(OUT, "peril_headroom_detail.csv"))
# one row per peril: mean over years; best alternative = highest mean alt_gain
alt <- det[, .(alt_gain = mean(alt_gain), alt_gain_min = min(alt_gain), alt_peril_d2c = mean(alt_peril_d2c)), by = .(line, peril, alt_name)]
best <- alt[order(-alt_gain), .SD[1], by = .(line, peril)]
summ <- det[alt_name == "lad", .(cost_share = mean(cost_share), claim_rows = mean(claim_rows), ae_2023 = ae[valid_year == 2023],
                                 ae_2024 = ae[valid_year == 2024], peril_d2c = mean(peril_d2c), value_ranking = mean(value_ranking),
                                 rate_per_0.01 = mean(rate_per_0.01), gain_level = mean(gain_level)), by = .(line, peril)]
summ <- merge(summ, best[, .(line, peril, best_alt = alt_name, best_alt_peril_d2c = alt_peril_d2c, gain_best_alt = alt_gain,
                             gain_best_alt_min_year = alt_gain_min)], by = c("line", "peril"))
setorder(summ, -rate_per_0.01)
fwrite(summ, file.path(OUT, "peril_headroom.csv"))
print(summ, digits = 3)
