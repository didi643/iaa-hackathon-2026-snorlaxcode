# 6_w9_buildings_k.R -------------------------------------------------------------------------------------
# Buildings dispersion on top of the 0.12965 submission (WENDY 9 + MOTOR 2 line m 0.5 pre-credibility): buildings
# prediction q -> q^k rescaled to the line total (ranks and total unchanged). Scores k on 2023 / 2024 (all lines,
# reported_raw Tweedie D2), cross-checks the pick across folds, paired policy bootstrap SE vs k = 1, decile A/E.
# Run: Rscript week1/R/6_w9_buildings_k.R [k]   (with k, writes that submission)

source("week1/R/0_setup.R")
HO <- file.path("week1", "handover", "w9_handover", "w9_handover")
K_GRID <- c(1, 1.025, 1.05, 1.075, 1.1, 1.125, 1.15)
N_BOOT <- 200
W <- list(motor = c(own_damage = 0, third_party_prop = 1, bodily_injury = 0, theft = 0, glass_hail = 1),
          buildings = c(storm = 1, flood = 0, escape_of_water = 0, subsidence = 0.5, fire = 0.25, accidental_damage = 0.25),
          contents = c(theft = 0, escape_of_water = 0.75, accidental_damage = 0, flood = 0.75))
LW <- c(motor = 0.9, buildings = 0.7, contents = 0.9)
A_CRED <- c(motor = 8, buildings = 5, contents = 5)

udev <- function(y, mu, p = 1.5) {
  mu <- pmax(mu, 1e-12)
  2 * (ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
num <- function(Q, col) {
  v <- as.numeric(Q[[col]])
  v[is.na(v)] <- 0
  v
}
base_pred <- function(Q, ln) {
  pb <- Reduce(`+`, lapply(PERILS[[ln]], function(p) W[[ln]][[p]] * num(Q, paste0("lad_", p)) + (1 - W[[ln]][[p]]) * num(Q, paste0("c5_", p))))
  b <- LW[[ln]] * pb + (1 - LW[[ln]]) * num(Q, "sam3")
  if (ln == "motor") b <- 0.5 * b + 0.5 * Q$m2 * sum(b) / sum(Q$m2)
  q <- b * (A_CRED[[ln]] + num(Q, "N")) / (A_CRED[[ln]] + num(Q, "E"))
  q * sum(b) / sum(q)
}
disp <- function(q, k) if (k == 1) q else q^k * sum(q) / sum(q^k)

D <- lapply(setNames(LINES, LINES), function(ln) as.data.table(read_parquet(file.path(HO, "panel", paste0("panel_", ln, ".parquet")))))
m2f <- as.data.table(read_parquet(file.path("week1", "models", "motor_iteration_02", "fold_predictions.parquet")))[, .(row_id, valid_year, m2 = pred_final)]
m2t <- fread(file.path(PATHS$output, "submission", "motor2_only_20261023_1359.csv"), colClasses = list(character = "row_id"))[, .(row_id, valid_year = 2025L, m2 = prediction)]
D$motor <- merge(D$motor, rbind(m2f, m2t), by = c("row_id", "valid_year"), all.x = TRUE, sort = FALSE)
stopifnot(!anyNA(D$motor$m2))

set.seed(SEED)
res <- list(); boot <- list(); dec <- list()
for (vy in c(2023, 2024)) {
  rows <- rbindlist(lapply(LINES, function(ln) {
    Q <- D[[ln]][valid_year == vy]
    data.table(line = ln, policy_id = Q$policy_id, e = num(Q, "exposure"),
               y = Reduce(`+`, lapply(PERILS[[ln]], function(p) num(Q, paste0("act_", p)))), q = base_pred(Q, ln))
  }))
  rows[, d0 := udev(y, e * sum(y) / sum(e))]
  for (k in K_GRID) {
    qk <- rows$q
    b <- rows$line == "buildings"
    qk[b] <- disp(rows$q[b], k)
    set(rows, j = paste0("dk_", k), value = udev(rows$y, qk))
  }
  pol <- rows[, lapply(.SD, sum), by = policy_id, .SDcols = c("d0", paste0("dk_", K_GRID))]
  d2 <- function(k, wt = rep(1, nrow(pol))) 1 - sum(wt * pol[[paste0("dk_", k)]]) / sum(wt * pol$d0)
  res[[as.character(vy)]] <- data.table(valid_year = vy, k = K_GRID, d2 = sapply(K_GRID, d2))
  boot[[as.character(vy)]] <- t(replicate(N_BOOT, {
    wt <- tabulate(sample.int(nrow(pol), replace = TRUE), nrow(pol))
    sapply(K_GRID, function(k) d2(k, wt) - d2(1, wt))
  }))
  bq <- rows[line == "buildings"]
  for (k in c(1, 1.1)) {
    qk <- disp(bq$q, k)
    dd <- data.table(y = bq$y, q = qk, dec = cut(rank(qk / bq$e, ties.method = "first"), 10, labels = FALSE))
    dec[[paste(vy, k)]] <- dd[, .(ae = sum(y) / sum(q)), by = dec][order(dec)][, `:=`(valid_year = vy, k = k)]
  }
}
res <- rbindlist(res)
res[, gain := d2 - d2[k == 1], by = valid_year]
w <- dcast(res, k ~ valid_year, value.var = "gain")
setnames(w, c("k", "gain_2023", "gain_2024"))
se_mean <- sapply(seq_along(K_GRID), function(i) sd((boot[["2023"]][, i] + boot[["2024"]][, i]) / 2))
w[, `:=`(gain_mean = (gain_2023 + gain_2024) / 2, se_mean = se_mean)][, z := gain_mean / se_mean]
w[, k_best_2023 := k == K_GRID[which.max(gain_2023)]][, k_best_2024 := k == K_GRID[which.max(gain_2024)]]
print(w, digits = 5)
print(dcast(rbindlist(dec), valid_year + k ~ dec, value.var = "ae"), digits = 3)
out_dir <- file.path(PATHS$output, "6_w9_buildings_k")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
fwrite(w, file.path(out_dir, "buildings_k_grid.csv"))
fwrite(rbindlist(dec), file.path(out_dir, "buildings_decile_ae.csv"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 1) {
  k <- as.numeric(args[1])
  out <- rbindlist(lapply(LINES, function(ln) {
    Q <- D[[ln]][valid_year == 2025]
    q <- base_pred(Q, ln)
    data.table(row_id = Q$row_id, prediction = if (ln == "buildings") disp(q, k) else q)
  }))
  sample_sub <- read_raw("sample_submission")
  stopifnot(nrow(out) == nrow(sample_sub), setequal(out$row_id, sample_sub$row_id), !anyNA(out$prediction), all(out$prediction >= 0))
  out <- out[match(sample_sub$row_id, row_id)]
  ref <- fread(file.path(PATHS$output, "submission", "submission_20261023_1636_w9_motor2_pre_m0.5.csv"), colClasses = list(character = "row_id"))
  x <- merge(ref, out, by = "row_id", suffixes = c("_ref", "_new"))[, line := substr(row_id, 1, 1)]
  print(x[, .(total_ratio = sum(prediction_new) / sum(prediction_ref), max_abs_diff = max(abs(prediction_new - prediction_ref)),
              spearman = cor(prediction_ref, prediction_new, method = "spearman")), by = line])
  f <- out_file("submission", sprintf("submission_%s_w9_motor2_m0.5_bk%s.csv", format(Sys.time(), "%Y%m%d_%H%M"), k))
  fwrite(out, f, scipen = 50)
  log_msg("Wrote ", f, " (MD5 ", unname(tools::md5sum(f)), ")")
}
