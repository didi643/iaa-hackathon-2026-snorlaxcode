# 6_w9_motor_peril_check.R -------------------------------------------------------------------------------
# Per motor peril: WENDY 9 component vs MOTOR 2 (rescaled to the W9 peril total) on the W9 panel folds, by
# reported_raw and by developed cost (reported / reported share, motor shares from week1/output/3b_ibnr), and all-line D2 of
# candidate per-peril MOTOR 2 weights without any dispersion change. Paired policy bootstrap SE vs the 0.12965 file.
# Run: Rscript week1/R/6_w9_motor_peril_check.R ["od,tpp,bi,theft,gh" weights]   (with weights, writes that submission)

source("week1/R/0_setup.R")
source("week1/R/model_io.R")
HO <- file.path("week1", "handover", "w9_handover", "w9_handover")
PR <- PERILS$motor
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
d2 <- function(y, mu, e) 1 - sum(udev(y, mu)) / sum(udev(y, e * sum(y) / sum(e)))
num <- function(Q, col) {
  v <- as.numeric(Q[[col]])
  v[is.na(v)] <- 0
  v
}
w9_peril <- function(Q, ln, p) W[[ln]][[p]] * num(Q, paste0("lad_", p)) + (1 - W[[ln]][[p]]) * num(Q, paste0("c5_", p))
# mp = per-peril MOTOR 2 weights (motor only); ml = line-level MOTOR 2 weight (the 0.12965 file uses ml 0.5)
pred <- function(Q, ln, mp = NULL, ml = 0) {
  parts <- lapply(PERILS[[ln]], function(p) {
    b <- w9_peril(Q, ln, p)
    w <- if (is.null(mp)) 0 else mp[[p]]
    if (w > 0) b <- (1 - w) * b + w * Q[[paste0("m2_", p)]] * sum(b) / sum(Q[[paste0("m2_", p)]])
    b
  })
  b <- LW[[ln]] * Reduce(`+`, parts) + (1 - LW[[ln]]) * num(Q, "sam3")
  if (ml > 0) b <- (1 - ml) * b + ml * Q$m2_total * sum(b) / sum(Q$m2_total)
  q <- b * (A_CRED[[ln]] + num(Q, "N")) / (A_CRED[[ln]] + num(Q, "E"))
  q * sum(b) / sum(q)
}

D <- lapply(setNames(LINES, LINES), function(ln) as.data.table(read_parquet(file.path(HO, "panel", paste0("panel_", ln, ".parquet")))))
m2 <- as.data.table(read_parquet(file.path("week1", "models", "motor_iteration_02", "fold_predictions.parquet")))
m2 <- m2[valid_year %in% 2023:2024, c("row_id", "valid_year", paste0("pred_", PR), "pred_final"), with = FALSE]
setnames(m2, c(paste0("pred_", PR), "pred_final"), c(paste0("m2_", PR), "m2_total"))
m2t <- fread(file.path(PATHS$output, "submission", "motor2_test_perils_20261023_1359.csv"), colClasses = list(character = "row_id"))
m2tt <- fread(file.path(PATHS$output, "submission", "motor2_only_20261023_1359.csv"), colClasses = list(character = "row_id"))
m2t <- merge(m2t, m2tt[, .(row_id, m2_total = prediction)], by = "row_id")[, valid_year := 2025L]
D$motor <- merge(D$motor, rbind(m2, m2t), by = c("row_id", "valid_year"), all.x = TRUE, sort = FALSE)
stopifnot(!anyNA(D$motor$m2_total))

# Reported share per row and peril (developed cost = reported / share)
ds <- fread(file.path(PATHS$output, "3b_ibnr", "recommended_daily_share.csv"))[line == "motor"][, date := as.Date(date)][order(peril, date)]
RS <- list(origin = min(ds$date), cumshare = lapply(split(ds, by = "peril"), function(x) cumsum(x$share)))
per_dt <- as.data.table(read_parquet(file.path(PATHS$raw, "policies_motor.parquet"), col_select = c("row_id", "period_start", "period_end")))

# 1. Peril-level comparison W9 vs MOTOR 2 (same total), reported and developed
peril_cmp <- rbindlist(lapply(2023:2024, function(vy) {
  Q <- D$motor[valid_year == vy]
  pd <- per_dt[match(Q$row_id, row_id)]
  rbindlist(lapply(PR, function(p) {
    y <- num(Q, paste0("act_", p)); e <- num(Q, "exposure")
    sh <- row_report_share(RS, p, as.Date(pd$period_start), as.Date(pd$period_end))
    a <- w9_peril(Q, "motor", p); b <- Q[[paste0("m2_", p)]] * sum(a) / sum(Q[[paste0("m2_", p)]])
    data.table(valid_year = vy, peril = p, w9_reported = d2(y, a, e), m2_reported = d2(y, b, e),
               w9_developed = d2(y / sh, a, e), m2_developed = d2(y / sh, b, e), mean_share = mean(sh))
  }))
}))
peril_cmp[, `:=`(m2_minus_w9_rep = m2_reported - w9_reported, m2_minus_w9_dev = m2_developed - w9_developed)]
print(peril_cmp, digits = 4)

# 2. Candidates (all-line D2, paired bootstrap vs the 0.12965 file = ml 0.5)
cands <- list("0.12965 file (line m 0.5)" = list(ml = 0.5),
              "OD/theft/GH 0.5, TPP/BI 0" = list(mp = c(own_damage = 0.5, third_party_prop = 0, bodily_injury = 0, theft = 0.5, glass_hail = 0.5)),
              "OD/GH 0.5 only" = list(mp = c(own_damage = 0.5, third_party_prop = 0, bodily_injury = 0, theft = 0, glass_hail = 0.5)),
              "all perils 0.5 except BI 0" = list(mp = c(own_damage = 0.5, third_party_prop = 0.5, bodily_injury = 0, theft = 0.5, glass_hail = 0.5)),
              "all perils 0.5" = list(mp = c(own_damage = 0.5, third_party_prop = 0.5, bodily_injury = 0.5, theft = 0.5, glass_hail = 0.5)))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 1) cands[["custom"]] <- list(mp = setNames(as.numeric(strsplit(args[1], ",")[[1]]), PR))
set.seed(SEED)
res <- rbindlist(lapply(2023:2024, function(vy) {
  pols <- NULL
  dv <- list()
  for (nm in names(cands)) {
    rows <- rbindlist(lapply(LINES, function(ln) {
      Q <- D[[ln]][valid_year == vy]
      c <- cands[[nm]]
      p <- if (ln == "motor") pred(Q, ln, c$mp, if (is.null(c$ml)) 0 else c$ml) else pred(Q, ln)
      y <- Reduce(`+`, lapply(PERILS[[ln]], function(pp) num(Q, paste0("act_", pp))))
      data.table(policy_id = Q$policy_id, y = y, e = num(Q, "exposure"), p = p, line = ln)
    }))
    rows[, `:=`(d = udev(y, p), d0 = udev(y, e * sum(y) / sum(e)))]
    dv[[nm]] <- rows[, .(d = sum(d), d0 = sum(d0), dm = sum(d[line == "motor"]), dm0 = sum(d0[line == "motor"])), by = policy_id]
  }
  base <- dv[[1]]
  rbindlist(lapply(names(cands), function(nm) {
    x <- dv[[nm]]
    g <- (1 - sum(x$d) / sum(x$d0)) - (1 - sum(base$d) / sum(base$d0))
    bs <- replicate(N_BOOT, {
      wt <- tabulate(sample.int(nrow(x), replace = TRUE), nrow(x))
      (1 - sum(wt * x$d) / sum(wt * x$d0)) - (1 - sum(wt * base$d) / sum(wt * base$d0))
    })
    data.table(valid_year = vy, candidate = nm, all_d2 = 1 - sum(x$d) / sum(x$d0), motor_d2 = 1 - sum(x$dm) / sum(x$dm0),
               gain_vs_12965 = g, se = sd(bs))
  }))
}))
print(dcast(res, candidate ~ valid_year, value.var = c("gain_vs_12965", "se")), digits = 4)
out_dir <- file.path(PATHS$output, "6_w9_motor_peril_check")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
fwrite(peril_cmp, file.path(out_dir, "peril_w9_vs_motor2.csv"))
fwrite(res, file.path(out_dir, "candidates.csv"))

if (length(args) == 1) {
  mp <- cands[["custom"]]$mp
  out <- rbindlist(lapply(LINES, function(ln) {
    Q <- D[[ln]][valid_year == 2025]
    data.table(row_id = Q$row_id, prediction = if (ln == "motor") pred(Q, ln, mp) else pred(Q, ln))
  }))
  sample_sub <- read_raw("sample_submission")
  stopifnot(nrow(out) == nrow(sample_sub), setequal(out$row_id, sample_sub$row_id), !anyNA(out$prediction), all(out$prediction >= 0))
  out <- out[match(sample_sub$row_id, row_id)]
  f <- out_file("submission", sprintf("submission_%s_w9_m2peril_%s.csv", format(Sys.time(), "%Y%m%d_%H%M"), gsub(",", "_", args[1])))
  fwrite(out, f, scipen = 50)
  log_msg("Wrote ", f, " (MD5 ", unname(tools::md5sum(f)), ")")
}
