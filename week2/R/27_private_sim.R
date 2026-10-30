# 27_private_sim.R ------------------------------------------------------------------------------------------------------
# Purpose : Expected private score of the public-probe level calibration (lvl_half). Emerging 2024 validation rows (line
#           ensemble components: x20_tblend motor, rt_var_b8_chosen home) are split at random 33% public / 67% private
#           (disjoint, 59k rows), and the full procedure is re-run on the public part:
#             stage 1 line levels -> lvl_cal1; stage 2 levels for the 11 probe segments -> theta;
#             halfway rule C = clamp(sqrt(C_cal1 x theta), 0.6, 1.8) -> lvl_half; full theta (bounded 0.01-3) -> full.
#           Levels are the probe-solver estimating equation (weighted LS, weights mu0^-1.5), which is what the probes
#           measure. Records public and private Tweedie D2 (p = 1.5, null = mean) per candidate, then rescales to the
#           2025 test size (optimism ~ 1/n_public, split-noise SD ~ 1/sqrt(n)).
#           SHIFT=cal1 multiplies 2024 actuals by line levels (motor 1.14, buildings 1.35, contents 0.93) so the fold
#           carries a real 2025-like level shift; SHIFT=none keeps 2024 as is.
# Inputs  : data/week_2/optionB/adjust/{x20_tblend,rt_var_b8_chosen}/valid_2024_peril.parquet, emerging claims and shares
# Outputs : week2/output/25_level/private_sim_<SHIFT>.csv (one row per simulation x candidate)
# Run     : SHIFT=cal1 NSIM=300 Rscript week2/R/27_private_sim.R
# Time    : about 1-3 minutes

source("week2/R/00_setup_week2.R")
suppressMessages(library(arrow))
SHIFT <- Sys.getenv("SHIFT", "cal1"); NSIM <- as.integer(Sys.getenv("NSIM", "300"))
N_PUB <- 69688L; N_PRI <- 139375L
clp <- claim_basis("emerging")
rd <- function(tag) as.data.table(read_parquet(file.path(W2$data, "adjust", tag, "valid_2024_peril.parquet")))
vp <- rbind(rd("x20_tblend")[line == "motor"], rd("rt_var_b8_chosen")[line != "motor"], fill = TRUE)
vp[, mu := exposure * freq_B * sev_B]
vp <- merge(vp, clp[, .(adj = sum(cost)), by = .(row_id, peril)], by = c("row_id", "peril"), all.x = TRUE)
vp[is.na(adj), adj := 0][, y := adj / share]
SEG <- c("motor/bodily_injury" = "bodily_injury", "motor/third_party_prop" = "third_party_prop", "motor/own_damage" = "own_damage",
         "buildings/fire" = "fire", "buildings/flood" = "flood", "buildings/storm" = "storm", "buildings/escape_of_water" = "escape_of_water",
         "buildings/subsidence+accidental_damage" = c("subsidence", "accidental_damage"), "contents/theft" = "theft")
vp[, seg := line]
for (s in names(SEG)) { k <- strsplit(s, "/")[[1]][1]; vp[line == k & peril %in% strsplit(sub(".*/", "", s), "\\+")[[1]], seg := s] }
if (SHIFT == "cal1") vp[, y := y * c(motor = 1.14, buildings = 1.35, contents = 0.93)[line]]
S <- sort(unique(vp$seg)); LN <- c("motor", "buildings", "contents")
M <- as.matrix(dcast(vp, row_id ~ seg, value.var = "mu", fun.aggregate = sum, fill = 0)[, ..S])
Y <- vp[, .(y = sum(y)), by = row_id][match(dcast(vp, row_id ~ seg, value.var = "mu", fun.aggregate = sum)$row_id, row_id), y]
line_of <- sub("/.*", "", S)
d2 <- function(y, mu) d2_tweedie(y, mu)
solve_lv <- function(Mx, y, groups) {   # levels per group of columns: E[y] = sum_g th_g * sum(M[, g]); weights mu0^-1.5
  G <- sapply(unique(groups), function(g) rowSums(Mx[, groups == g, drop = FALSE]))
  w <- rowSums(Mx)^-1.5
  setNames(solve(crossprod(G * w, G), crossprod(G * w, y))[, 1], unique(groups))
}
set.seed(2026); out <- vector("list", NSIM)
NR <- nrow(M); n_pub <- round(NR * as.numeric(N_PUB) / (N_PUB + N_PRI))
for (i in seq_len(NSIM)) {
  idx <- sample(NR); pub <- idx[1:n_pub]; pri <- idx[-(1:n_pub)]
  c1 <- solve_lv(M[pub, ], Y[pub], line_of)[line_of]
  th <- solve_lv(M[pub, ], Y[pub], S)
  cand <- list(base = rep(1, length(S)), cal1 = c1, half = pmin(pmax(sqrt(c1 * pmax(th, 1e-6)), 0.6), 1.8), full = pmin(pmax(th, 0.01), 3))
  out[[i]] <- rbindlist(lapply(names(cand), function(nm) {
    mu <- as.vector(M %*% cand[[nm]])
    data.table(sim = i, cand = nm, pub = d2(Y[pub], mu[pub]), pri = d2(Y[pri], mu[pri]))
  }))
}
res <- rbindlist(out)
res <- merge(res, res[cand == "base", .(sim, pub0 = pub, pri0 = pri)], by = "sim")
res[, `:=`(gain_pub = pub - pub0, gain_pri = pri - pri0, gap = pri - pub)]
dir.create("week2/output/25_level", showWarnings = FALSE)
fwrite(res, sprintf("week2/output/25_level/private_sim_%s.csv", SHIFT))
q <- function(x) sprintf("%+.5f [%+.5f, %+.5f]", mean(x), quantile(x, 0.1), quantile(x, 0.9))
cat(sprintf("SHIFT=%s  NSIM=%d  fold rows %d (public %d)  (mean [10%%, 90%%])\n", SHIFT, NSIM, NR, n_pub))
print(res[, .(gain_public = q(gain_pub), gain_private = q(gain_pri), optimism = q(gain_pub - gain_pri),
              private_minus_public = q(gap), sd_gap = round(sd(gap), 5)), by = cand])
# Scale to the 2025 test size: optimism (fitted-parameter bias in deviance) ~ 1/n_public, split noise SD ~ 1/sqrt(n)
f1 <- n_pub / N_PUB; f2 <- sqrt(NR / (N_PUB + N_PRI))
cat(sprintf("Scaled to 2025 test size (optimism x %.3f, SD x %.3f):\n", f1, f2))
print(res[, .(optimism = round(mean(gain_pub - gain_pri) * f1, 5), private_gain = round(mean(gain_pri) + (1 - f1) * mean(gain_pub - gain_pri), 5),
              sd_gap = round(sd(gap) * f2, 5), sd_gain_diff = round(sd(gain_pri - gain_pub) * f2, 5)), by = cand])
