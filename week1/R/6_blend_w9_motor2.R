# 6_blend_w9_motor2.R ------------------------------------------------------------------------------------
# Tests MOTOR 2 (run 20261023_1359) as an extra motor member on top of WENDY 9, using Wendy's handover panel and
# her scoring (Tweedie D2 vs reported_raw, folds 2023 / 2024, all lines). No refits.
#   post: motor = (1 - m) x W9 final + m x MOTOR 2 (rescaled to the W9 motor total)
#   pre:  MOTOR 2 enters before W9's credibility step: b = (1 - m) x W9 line blend + m x MOTOR 2, then M = (A+N)/(A+E)
# Writes week1/output/submission/submission_<time>_w9_motor2_<variant>_m<m>.csv for the best variant, or the one given.
# Run: Rscript week1/R/6_blend_w9_motor2.R [variant m]   e.g. Rscript week1/R/6_blend_w9_motor2.R pre 0.5

source("week1/R/0_setup.R")
HO <- file.path("week1", "handover", "w9_handover", "w9_handover")
M2_FOLDS <- file.path("week1", "models", "motor_iteration_02", "fold_predictions.parquet")
M2_TEST <- file.path(PATHS$output, "submission", "motor2_only_20261023_1359.csv")
M_GRID <- c(0, 0.25, 0.5, 0.75, 1)

# WENDY 9 settings, from week1/handover/.../scripts/w9_blend.R
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
cred <- function(Q, ln, b) {
  q <- b * (A_CRED[[ln]] + num(Q, "N")) / (A_CRED[[ln]] + num(Q, "E"))
  q * sum(b) / sum(q)
}
w9 <- function(Q, ln, m2 = NULL, m = 0, variant = "post") {
  pb <- Reduce(`+`, lapply(PERILS[[ln]], function(p) W[[ln]][[p]] * num(Q, paste0("lad_", p)) + (1 - W[[ln]][[p]]) * num(Q, paste0("c5_", p))))
  b <- LW[[ln]] * pb + (1 - LW[[ln]]) * num(Q, "sam3")
  if (m == 0 || is.null(m2)) return(cred(Q, ln, b))
  if (variant == "pre") return(cred(Q, ln, (1 - m) * b + m * m2 * sum(b) / sum(m2)))
  q <- cred(Q, ln, b)
  (1 - m) * q + m * m2 * sum(q) / sum(m2)
}

D <- lapply(setNames(LINES, LINES), function(ln) as.data.table(read_parquet(file.path(HO, "panel", paste0("panel_", ln, ".parquet")))))
m2f <- as.data.table(read_parquet(M2_FOLDS))[, .(row_id, valid_year, m2 = pred_final)]
m2t <- fread(M2_TEST, colClasses = list(character = "row_id"))[, .(row_id, valid_year = 2025L, m2 = prediction)]
m2 <- rbind(m2f, m2t)
D$motor <- merge(D$motor, m2, by = c("row_id", "valid_year"), all.x = TRUE, sort = FALSE)
cov <- D$motor[, .(rows = .N, missing_m2 = sum(is.na(m2))), by = valid_year]
print(cov)
stopifnot(cov$missing_m2 == 0)

score <- function(m, variant) {
  rbindlist(lapply(c(2023, 2024), function(vy) {
    y <- e <- p <- c(); motor <- NA_real_
    for (ln in LINES) {
      Q <- D[[ln]][valid_year == vy]
      yl <- Reduce(`+`, lapply(PERILS[[ln]], function(pr) num(Q, paste0("act_", pr))))
      pl <- w9(Q, ln, if (ln == "motor") Q$m2, if (ln == "motor") m else 0, variant)
      if (ln == "motor") motor <- d2(yl, pl, num(Q, "exposure"))
      y <- c(y, yl); e <- c(e, num(Q, "exposure")); p <- c(p, pl)
    }
    data.table(variant = variant, m = m, valid_year = vy, motor_d2 = motor, all_d2 = d2(y, p, e))
  }))
}
res <- rbindlist(lapply(c("post", "pre"), function(v) rbindlist(lapply(M_GRID, score, variant = v))))
base <- res[m == 0, .(valid_year, base_all = all_d2, base_motor = motor_d2)][, .SD[1], by = valid_year]
res <- merge(res, base, by = "valid_year")[, `:=`(gain_all = all_d2 - base_all, gain_motor = motor_d2 - base_motor)]
summ <- res[, .(motor_2023 = motor_d2[valid_year == 2023], motor_2024 = motor_d2[valid_year == 2024],
                all_2023 = all_d2[valid_year == 2023], all_2024 = all_d2[valid_year == 2024],
                gain_all_mean = mean(gain_all), gain_all_min = min(gain_all)), by = .(variant, m)]
summ[, passes_rule := gain_all_mean >= 0.001 & gain_all_min > 0]
print(summ, digits = 5)
fwrite(summ, out_file("6_blend_w9_motor2", "w9_motor2_grid.csv"))

best <- summ[m > 0][order(-gain_all_mean)][1]
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 2) best <- summ[variant == args[1] & m == as.numeric(args[2])]
out <- rbindlist(lapply(LINES, function(ln) {
  Q <- D[[ln]][valid_year == 2025]
  data.table(row_id = Q$row_id, prediction = w9(Q, ln, if (ln == "motor") Q$m2, if (ln == "motor") best$m else 0, best$variant))
}))
sample_sub <- read_raw("sample_submission")
stopifnot(nrow(out) == nrow(sample_sub), setequal(out$row_id, sample_sub$row_id), !anyNA(out$prediction), all(out$prediction >= 0))
out <- out[match(sample_sub$row_id, row_id)]
f <- out_file("submission", sprintf("submission_%s_w9_motor2_%s_m%s.csv", format(Sys.time(), "%Y%m%d_%H%M"), best$variant, best$m))
fwrite(out, f, scipen = 50)
log_msg("Best: ", best$variant, " m=", best$m, " mean all-line gain ", round(best$gain_all_mean, 5),
        if (best$passes_rule) " (passes +0.001 rule)" else " (does NOT pass the +0.001 / both-folds rule)", "; wrote ", f)
