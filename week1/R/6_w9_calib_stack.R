# 6_w9_calib_stack.R -------------------------------------------------------------------------------------
# On the WENDY 9 handover panel (no refits), tests
#   1. dispersion calibration per line: q^k rescaled to the line total (k > 1 = steeper risk spread)
#   2. MOTOR 2 blended per motor peril (weights on 0 / 0.25 / 0.5 / 0.75 / 1) instead of on the motor line
# Every choice is also cross-checked: picked on one fold, scored on the other. Wendy's protocol: Tweedie D2 (p 1.5)
# vs reported_raw, all lines, folds 2023 / 2024.
# Run: Rscript week1/R/6_w9_calib_stack.R ["<candidate name>" [bi=<BI cost per exposure-year>]]
#      (with a name, also writes that candidate's 2025 submission; bi= rescales only the motor bodily_injury component)

source("week1/R/0_setup.R")
HO <- file.path("week1", "handover", "w9_handover", "w9_handover")
GRID <- c(0, 0.25, 0.5, 0.75, 1)
K_GRID <- seq(0.85, 1.4, by = 0.05)
YEARS <- c(2023, 2024)

W <- list(motor = c(own_damage = 0, third_party_prop = 1, bodily_injury = 0, theft = 0, glass_hail = 1),
          buildings = c(storm = 1, flood = 0, escape_of_water = 0, subsidence = 0.5, fire = 0.25, accidental_damage = 0.25),
          contents = c(theft = 0, escape_of_water = 0.75, accidental_damage = 0, flood = 0.75))
LW <- c(motor = 0.9, buildings = 0.7, contents = 0.9)
A_CRED <- c(motor = 8, buildings = 5, contents = 5)

tdev <- function(y, mu, p = 1.5) {
  mu <- pmax(mu, 1e-12)
  2 * sum(ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
d2 <- function(y, mu, e) 1 - tdev(y, mu) / tdev(y, e * sum(y) / sum(e))
num <- function(Q, col) {
  v <- as.numeric(Q[[col]])
  v[is.na(v)] <- 0
  v
}

D <- lapply(setNames(LINES, LINES), function(ln) as.data.table(read_parquet(file.path(HO, "panel", paste0("panel_", ln, ".parquet")))))
m2 <- as.data.table(read_parquet(file.path("week1", "models", "motor_iteration_02", "fold_predictions.parquet")))
m2 <- m2[valid_year %in% YEARS, c("row_id", "valid_year", paste0("pred_", PERILS$motor), "pred_final"), with = FALSE]
setnames(m2, c(paste0("pred_", PERILS$motor), "pred_final"), c(paste0("m2_", PERILS$motor), "m2_total"))
D$motor <- merge(D$motor, m2, by = c("row_id", "valid_year"), all.x = TRUE, sort = FALSE)
stopifnot(D$motor[valid_year %in% YEARS, !anyNA(m2_total)])

# Line prediction: W9 with optional per-peril MOTOR 2 weights (mp), line-level MOTOR 2 weight (ml) and dispersion k
BI_SCALE <- 1
line_pred <- function(Q, ln, mp = NULL, ml = 0, k = 1) {
  parts <- lapply(PERILS[[ln]], function(p) {
    b <- W[[ln]][[p]] * num(Q, paste0("lad_", p)) + (1 - W[[ln]][[p]]) * num(Q, paste0("c5_", p))
    w <- if (is.null(mp)) 0 else mp[[p]]
    if (w > 0) b <- (1 - w) * b + w * Q[[paste0("m2_", p)]] * sum(b) / sum(Q[[paste0("m2_", p)]])
    if (ln == "motor" && p == "bodily_injury") b <- b * BI_SCALE
    b
  })
  b <- LW[[ln]] * Reduce(`+`, parts) + (1 - LW[[ln]]) * num(Q, "sam3")
  if (ml > 0) b <- (1 - ml) * b + ml * Q$m2_total * sum(b) / sum(Q$m2_total)
  q <- b * (A_CRED[[ln]] + num(Q, "N")) / (A_CRED[[ln]] + num(Q, "E"))
  q <- q * sum(b) / sum(q)
  if (k != 1) q <- q^k * sum(q) / sum(q^k)
  q
}
fold <- lapply(setNames(as.character(YEARS), YEARS), function(vy) {
  lapply(setNames(LINES, LINES), function(ln) {
    Q <- D[[ln]][valid_year == as.integer(vy)]
    list(Q = Q, y = Reduce(`+`, lapply(PERILS[[ln]], function(p) num(Q, paste0("act_", p)))), e = num(Q, "exposure"))
  })
})
# All-line D2 per fold for a config: list(motor = list(mp, ml, k), buildings = list(k), contents = list(k))
score <- function(cfg) {
  sapply(fold, function(F) {
    y <- e <- p <- c()
    for (ln in LINES) {
      c <- cfg[[ln]]
      p <- c(p, line_pred(F[[ln]]$Q, ln, c$mp, if (is.null(c$ml)) 0 else c$ml, if (is.null(c$k)) 1 else c$k))
      y <- c(y, F[[ln]]$y); e <- c(e, F[[ln]]$e)
    }
    d2(y, p, e)
  })
}
base_cfg <- list(motor = list(), buildings = list(), contents = list())
w9 <- score(base_cfg)
log_msg("W9 reproduced: ", paste(round(w9, 5), collapse = " / "))

# Decile A/E of the final W9 prediction (is the spread too flat?)
decile_ae <- rbindlist(lapply(names(fold), function(vy) rbindlist(lapply(LINES, function(ln) {
  F <- fold[[vy]][[ln]]
  q <- line_pred(F$Q, ln)
  dt <- data.table(y = F$y, q = q, dec = cut(rank(q / F$e, ties.method = "first"), 10, labels = FALSE))
  dt[, .(ae = sum(y) / sum(q)), by = dec][order(dec)][, .(valid_year = vy, line = ln, dec, ae)]
}))))
print(dcast(decile_ae, line + valid_year ~ dec, value.var = "ae"), digits = 3)

# 1. Dispersion k per line -----------------------------------------------------------------------------
pick <- function(scores, years = YEARS) which.max(sapply(scores, function(s) mean(s[as.character(years)])))
k_res <- rbindlist(lapply(LINES, function(ln) {
  sc <- lapply(K_GRID, function(k) { cfg <- base_cfg; cfg[[ln]]$k <- k; score(cfg) })
  data.table(line = ln, k = K_GRID, d2_2023 = sapply(sc, `[`, 1), d2_2024 = sapply(sc, `[`, 2))
}))
k_res[, `:=`(gain_mean = (d2_2023 - w9[1] + d2_2024 - w9[2]) / 2, gain_2023 = d2_2023 - w9[1], gain_2024 = d2_2024 - w9[2])]
k_best <- k_res[, .(k_both = k[which.max(gain_mean)], k_on_2023 = k[which.max(gain_2023)], k_on_2024 = k[which.max(gain_2024)]), by = line]
k_best[, `:=`(cross_2024_from_2023 = mapply(function(l, kk) k_res[line == l & k == kk, gain_2024], line, k_on_2023),
              cross_2023_from_2024 = mapply(function(l, kk) k_res[line == l & k == kk, gain_2023], line, k_on_2024))]
print(k_best, digits = 4)

# 2. MOTOR 2 per peril (coordinate search on the grid, 2 passes) ----------------------------------------
search_mp <- function(years, start = setNames(rep(0, 5), PERILS$motor)) {
  mp <- start
  for (pass in 1:2) for (p in PERILS$motor) {
    sc <- sapply(GRID, function(g) { m <- mp; m[[p]] <- g; mean(score(list(motor = list(mp = m)))[as.character(years)]) })
    mp[[p]] <- GRID[which.max(sc)]
  }
  mp
}
mp_both <- search_mp(YEARS)
mp_23 <- search_mp(2023)
mp_24 <- search_mp(2024)
peril_res <- rbindlist(list(
  data.table(variant = "W9", t(w9)),
  data.table(variant = "W9 + MOTOR 2 line pre-cred m 0.5 (submitted, 0.12965)", t(score(list(motor = list(ml = 0.5))))),
  data.table(variant = "W9 + MOTOR 2 line m 1", t(score(list(motor = list(ml = 1))))),
  data.table(variant = paste("per peril, picked on both:", paste(mp_both, collapse = "/")), t(score(list(motor = list(mp = mp_both))))),
  data.table(variant = paste("per peril, picked on 2023:", paste(mp_23, collapse = "/")), t(score(list(motor = list(mp = mp_23))))),
  data.table(variant = paste("per peril, picked on 2024:", paste(mp_24, collapse = "/")), t(score(list(motor = list(mp = mp_24)))))))
setnames(peril_res, c("variant", "d2_2023", "d2_2024"))
peril_res[, `:=`(gain_2023 = d2_2023 - w9[1], gain_2024 = d2_2024 - w9[2])][, gain_mean := (gain_2023 + gain_2024) / 2]
print(peril_res, digits = 5)

# 3. Combined: per-peril MOTOR 2 + dispersion re-picked on top -----------------------------------------
comb <- list(motor = list(mp = mp_both), buildings = list(), contents = list())
for (ln in LINES) {
  sc <- sapply(K_GRID, function(k) { c2 <- comb; c2[[ln]]$k <- k; mean(score(c2)) })
  comb[[ln]]$k <- K_GRID[which.max(sc)]
}
comb_sc <- score(comb)
log_msg("Combined (per-peril M2 + k ", paste(sapply(comb, function(x) x$k), collapse = "/"), "): ",
        paste(round(comb_sc, 5), collapse = " / "), "; gain ", paste(round(comb_sc - w9, 5), collapse = " / "))

out_dir <- file.path(PATHS$output, "6_w9_calib_stack")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
fwrite(decile_ae, file.path(out_dir, "decile_ae.csv"))
fwrite(k_res, file.path(out_dir, "dispersion_grid.csv"))
fwrite(k_best, file.path(out_dir, "dispersion_best.csv"))
fwrite(peril_res, file.path(out_dir, "motor2_per_peril.csv"))
saveRDS(list(mp_both = mp_both, mp_23 = mp_23, mp_24 = mp_24, comb = comb, comb_sc = comb_sc, w9 = w9), file.path(out_dir, "choices.rds"))

# 4. Candidates buildable without new MOTOR 2 test predictions (line-level MOTOR 2 + buildings dispersion) --
cands <- list(
  "submitted: line m 0.5" = list(motor = list(ml = 0.5), buildings = list(), contents = list()),
  "line m 0.5 + buildings k 1.10" = list(motor = list(ml = 0.5), buildings = list(k = 1.1), contents = list()),
  "line m 0.75 + buildings k 1.10" = list(motor = list(ml = 0.75), buildings = list(k = 1.1), contents = list()),
  "line m 1 + buildings k 1.10" = list(motor = list(ml = 1), buildings = list(k = 1.1), contents = list()),
  "per-peril M2 + k" = comb)
cand_res <- rbindlist(lapply(names(cands), function(nm) {
  s <- score(cands[[nm]])
  data.table(candidate = nm, d2_2023 = s[1], d2_2024 = s[2], gain_2023 = s[1] - w9[1], gain_2024 = s[2] - w9[2],
             gain_vs_submitted = mean(s) - mean(score(cands[[1]])))
}))
print(cand_res, digits = 5)
fwrite(cand_res, file.path(out_dir, "candidates.csv"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) {
  cfg <- cands[[args[1]]]
  bi_target <- if (length(args) == 2) as.numeric(sub("^bi=", "", args[2])) else NA_real_
  m2t <- fread(file.path(PATHS$output, "submission", "motor2_only_20261023_1359.csv"), colClasses = list(character = "row_id"))
  m2p <- fread(file.path(PATHS$output, "submission", "motor2_test_perils_20261023_1359.csv"), colClasses = list(character = "row_id"))
  test_Q <- function(ln) {
    Q <- D[[ln]][valid_year == 2025]
    if (ln == "motor") {
      Q[m2t, on = "row_id", m2_total := i.prediction]
      for (p in PERILS$motor) set(Q, j = paste0("m2_", p), value = m2p[[paste0("m2_", p)]][match(Q$row_id, m2p$row_id)])
      stopifnot(!anyNA(Q$m2_total), !anyNA(Q$m2_own_damage))
    }
    Q
  }
  # bodily_injury level probe: scale the BI peril component so its 2025 cost per exposure-year hits bi_target
  Qm <- test_Q("motor")
  bi_part <- function(Q) {
    b <- num(Q, "c5_bodily_injury")
    w <- cfg$motor$mp[["bodily_injury"]]
    if (!is.null(w) && w > 0) b <- (1 - w) * b + w * Q$m2_bodily_injury * sum(b) / sum(Q$m2_bodily_injury)
    b
  }
  bi_level <- sum(bi_part(Qm)) / sum(Qm$exposure)
  motor_before <- sum(line_pred(Qm, "motor", cfg$motor$mp, if (is.null(cfg$motor$ml)) 0 else cfg$motor$ml,
                                if (is.null(cfg$motor$k)) 1 else cfg$motor$k)) / sum(Qm$exposure)
  if (!is.na(bi_target)) {
    BI_SCALE <- bi_target / bi_level
    s <- score(cfg)
    log_msg(sprintf("BI probe: BI component %.1f -> %.1f per exposure-year (x%.3f); local D2 %.5f / %.5f (gain vs W9 %+.5f / %+.5f; local is blind to BI level)",
                    bi_level, bi_target, BI_SCALE, s[1], s[2], s[1] - w9[1], s[2] - w9[2]))
  }
  out <- rbindlist(lapply(LINES, function(ln) {
    Q <- if (ln == "motor") Qm else test_Q(ln)
    c <- cfg[[ln]]
    data.table(row_id = Q$row_id, prediction = line_pred(Q, ln, c$mp, if (is.null(c$ml)) 0 else c$ml, if (is.null(c$k)) 1 else c$k))
  }))
  motor_after <- sum(out[match(Qm$row_id, row_id), prediction]) / sum(Qm$exposure)
  log_msg(sprintf("Motor cost per exposure-year %.1f -> %.1f", motor_before, motor_after))
  sample_sub <- read_raw("sample_submission")
  stopifnot(nrow(out) == nrow(sample_sub), setequal(out$row_id, sample_sub$row_id), !anyNA(out$prediction), all(out$prediction >= 0))
  out <- out[match(sample_sub$row_id, row_id)]
  f <- out_file("submission", sprintf("submission_%s_w9_%s%s.csv", format(Sys.time(), "%Y%m%d_%H%M"), gsub("[^a-z0-9.]+", "_", tolower(args[1])),
                                      if (is.na(bi_target)) "" else paste0("_bi", bi_target)))
  fwrite(out, f, scipen = 50)
  log_msg("Wrote ", f, " (MD5 ", unname(tools::md5sum(f)), ")")
}
