# 6_w9_ab_motor3.R ---------------------------------------------------------------------------------------
# Submit gate for MOTOR 3: inside the 0.12965 blend (WENDY 9 with motor = 0.5 x W9 line blend + 0.5 x member,
# pre-credibility), swap MOTOR 2 for MOTOR 3 and compare all-line Tweedie D2 (p 1.5, reported_raw) on 2023 / 2024.
# Paired policy bootstrap (200 draws) gives the SE of the difference. Writes the MOTOR 3 submission when the gain is
# positive in both folds and the mean gain exceeds 2 x SE.
# Run: Rscript week1/R/6_w9_ab_motor3.R [force]   (force = write the file even if the gate fails)

source("week1/R/0_setup.R")
HO <- file.path("week1", "handover", "w9_handover", "w9_handover")
M <- 0.5
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
line_pred <- function(Q, ln, member = NULL) {
  pb <- Reduce(`+`, lapply(PERILS[[ln]], function(p) W[[ln]][[p]] * num(Q, paste0("lad_", p)) + (1 - W[[ln]][[p]]) * num(Q, paste0("c5_", p))))
  b <- LW[[ln]] * pb + (1 - LW[[ln]]) * num(Q, "sam3")
  if (!is.null(member)) b <- (1 - M) * b + M * member * sum(b) / sum(member)
  q <- b * (A_CRED[[ln]] + num(Q, "N")) / (A_CRED[[ln]] + num(Q, "E"))
  q * sum(b) / sum(q)
}

D <- lapply(setNames(LINES, LINES), function(ln) as.data.table(read_parquet(file.path(HO, "panel", paste0("panel_", ln, ".parquet")))))
m2f <- as.data.table(read_parquet(file.path("week1", "models", "motor_iteration_02", "fold_predictions.parquet")))[, .(row_id, valid_year, m2 = pred_final)]
m3f <- as.data.table(read_parquet(file.path("week1", "models", "motor_iteration_03", "fold_predictions.parquet")))[, .(row_id, valid_year, m3 = pred_final)]
m3_file <- tail(sort(Sys.glob(file.path(PATHS$output, "submission", "motor3_only_2*[0-9].csv"))), 1)
m2t <- fread(file.path(PATHS$output, "submission", "motor2_only_20261023_1359.csv"), colClasses = list(character = "row_id"))[, .(row_id, valid_year = 2025L, m2 = prediction)]
m3t <- fread(m3_file, colClasses = list(character = "row_id"))[, .(row_id, valid_year = 2025L, m3 = prediction)]
D$motor <- merge(D$motor, rbind(m2f, m2t), by = c("row_id", "valid_year"), all.x = TRUE, sort = FALSE)
D$motor <- merge(D$motor, rbind(m3f, m3t), by = c("row_id", "valid_year"), all.x = TRUE, sort = FALSE)
stopifnot(D$motor[, !anyNA(m2) && !anyNA(m3)])
log_msg("MOTOR 3 test file: ", basename(m3_file))

res <- list(); boot <- list()
set.seed(SEED)
for (vy in c(2023, 2024)) {
  rows <- rbindlist(lapply(LINES, function(ln) {
    Q <- D[[ln]][valid_year == vy]
    y <- Reduce(`+`, lapply(PERILS[[ln]], function(p) num(Q, paste0("act_", p))))
    data.table(policy_id = Q$policy_id, y = y, e = num(Q, "exposure"), w9 = line_pred(Q, ln),
               a = line_pred(Q, ln, if (ln == "motor") Q$m2), b = line_pred(Q, ln, if (ln == "motor") Q$m3))
  }))
  rows[, null := e * sum(y) / sum(e)]
  rows[, `:=`(d0 = udev(y, null), dw = udev(y, w9), da = udev(y, a), db = udev(y, b))]
  pol <- rows[, .(d0 = sum(d0), dw = sum(dw), da = sum(da), db = sum(db)), by = policy_id]
  d2 <- function(col, wt = rep(1, nrow(pol))) 1 - sum(wt * pol[[col]]) / sum(wt * pol$d0)
  res[[as.character(vy)]] <- data.table(valid_year = vy, w9 = d2("dw"), motor2_m05 = d2("da"), motor3_m05 = d2("db"))
  boot[[as.character(vy)]] <- replicate(N_BOOT, {
    wt <- tabulate(sample.int(nrow(pol), replace = TRUE), nrow(pol))
    d2("db", wt) - d2("da", wt)
  })
}
res <- rbindlist(res)[, gain := motor3_m05 - motor2_m05]
se <- sd((boot[["2023"]] + boot[["2024"]]) / 2)
gate <- all(res$gain > 0) && mean(res$gain) > 2 * se
print(res, digits = 6)
log_msg(sprintf("Mean gain MOTOR 3 vs MOTOR 2 (both at m 0.5): %+.5f; bootstrap SE of the mean %.5f; per-fold SE %.5f / %.5f; gate %s",
                mean(res$gain), se, sd(boot[["2023"]]), sd(boot[["2024"]]), if (gate) "PASSED" else "FAILED"))
out_dir <- file.path(PATHS$output, "6_w9_ab_motor3")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
fwrite(cbind(res, se_mean = se, gate = gate), file.path(out_dir, "ab_motor3_vs_motor2.csv"))

if (gate || identical(commandArgs(trailingOnly = TRUE), "force")) {
  out <- rbindlist(lapply(LINES, function(ln) {
    Q <- D[[ln]][valid_year == 2025]
    data.table(row_id = Q$row_id, prediction = line_pred(Q, ln, if (ln == "motor") Q$m3))
  }))
  sample_sub <- read_raw("sample_submission")
  stopifnot(nrow(out) == nrow(sample_sub), setequal(out$row_id, sample_sub$row_id), !anyNA(out$prediction), all(out$prediction >= 0))
  out <- out[match(sample_sub$row_id, row_id)]
  f <- out_file("submission", sprintf("submission_%s_w9_motor3_pre_m0.5.csv", format(Sys.time(), "%Y%m%d_%H%M")))
  fwrite(out, f, scipen = 50)
  log_msg("Wrote ", f, " (MD5 ", unname(tools::md5sum(f)), ")")
}
