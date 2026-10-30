# 6_w9_motor04_eval.R ------------------------------------------------------------------------------------
# Selects and judges MOTOR 4 (week1/R/4_models_itermotor04.R) inside the 0.12965 pipeline (WENDY 9 + MOTOR 2 line member at
# m 0.5 before credibility). Each new motor peril enters as v x MOTOR 4 peril + (1 - v) x the WENDY 9 peril blend,
# rescaled to the WENDY 9 peril total, so only the ranking changes (W9 levels are kept).
#   Selection (2023 fold only, developed motor cost): frequency version per peril (glm / lgb / boost, calibrated peril
#   D2), v per peril on the grid 0 / .25 / .5 / .75 / 1 (others at 0), then one of
#     A = per-peril v, MOTOR 2 member;  B = no per-peril change, MOTOR 4 total as member;  C = A + B
#   Held-out decision (2024 fold, untouched by the selection): gain vs the 0.12965 pipeline on developed motor cost
#   with a policy-clustered SE; PASS = gain > 2 SE on developed, > 0 on reported motor and all-line, and > 0 on 2023.
# Writes week1/output/6_w9_motor04_eval/*.csv and week1/output/submission/submission_<time>_w9_m2_motor04_<cand>_<PASS|FAIL>.csv
# Env: MOTOR04_DIR (default week1/models/motor_iteration_04)

source("week1/R/0_setup.R")
HO <- file.path("week1", "handover", "w9_handover", "w9_handover")
M4_DIR <- Sys.getenv("MOTOR04_DIR", file.path("week1", "models", "motor_iteration_04"))
TAG <- Sys.getenv("EVAL_TAG", "motor04")
OUT <- file.path(PATHS$output, if (TAG == "motor04") "6_w9_motor04_eval" else paste0("6_w9_", TAG, "_eval"))
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
BASE_FILE <- file.path(PATHS$output, "submission", "submission_20261023_1636_w9_motor2_pre_m0.5.csv")
M2_FOLDS <- file.path("week1", "models", "motor_iteration_02", "fold_predictions.parquet")
M2_TEST <- file.path(PATHS$output, "submission", "motor2_only_20261023_1359.csv")
SEL <- 2023L
HOLD <- 2024L
V_GRID <- c(0, 0.25, 0.5, 0.75, 1)
M_MEMBER <- 0.5
VERS <- strsplit(Sys.getenv("M4_VERS", "glm,lgb,boost"), ",")[[1]]
PRM <- PERILS$motor
W <- list(motor = c(own_damage = 0, third_party_prop = 1, bodily_injury = 0, theft = 0, glass_hail = 1),
          buildings = c(storm = 1, flood = 0, escape_of_water = 0, subsidence = 0.5, fire = 0.25, accidental_damage = 0.25),
          contents = c(theft = 0, escape_of_water = 0.75, accidental_damage = 0, flood = 0.75))
LW <- c(motor = 0.9, buildings = 0.7, contents = 0.9)
A_CRED <- c(motor = 8, buildings = 5, contents = 5)

tdev_rows <- function(y, mu, p = 1.5) {
  mu <- pmax(mu, 1e-12)
  2 * (ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
null_dev <- function(y, e) sum(tdev_rows(y, e * sum(y) / sum(e)))
d2 <- function(y, mu, e) 1 - sum(tdev_rows(y, mu)) / null_dev(y, e)
d2c <- function(y, mu, e) d2(y, mu * sum(y) / sum(mu), e)
num <- function(Q, col) {
  v <- as.numeric(Q[[col]])
  v[is.na(v)] <- 0
  v
}
cred <- function(Q, ln, b) {
  q <- b * (A_CRED[[ln]] + num(Q, "N")) / (A_CRED[[ln]] + num(Q, "E"))
  q * sum(b) / sum(q)
}
peril_w9 <- function(Q, ln, p) W[[ln]][[p]] * num(Q, paste0("lad_", p)) + (1 - W[[ln]][[p]]) * num(Q, paste0("c5_", p))
line_w9 <- function(Q, ln) {
  pb <- Reduce(`+`, lapply(PERILS[[ln]], function(p) peril_w9(Q, ln, p)))
  cred(Q, ln, LW[[ln]] * pb + (1 - LW[[ln]]) * num(Q, "sam3"))
}
# Motor pipeline for one year's rows: v = per-peril weight on MOTOR 4, ver = version per peril, member = line member
motor_pred <- function(Q, v, ver, member) {
  pb <- 0
  for (p in PRM) {
    a <- peril_w9(Q, "motor", p)
    if (v[[p]] > 0) {
      n <- Q[[paste0(ver[[p]], "_", p)]]
      a <- (1 - v[[p]]) * a + v[[p]] * n * sum(a) / sum(n)
    }
    pb <- pb + a
  }
  b <- LW[["motor"]] * pb + (1 - LW[["motor"]]) * num(Q, "sam3")
  b <- (1 - M_MEMBER) * b + M_MEMBER * member * sum(b) / sum(member)
  cred(Q, "motor", b)
}
m4_total <- function(Q, ver) Reduce(`+`, lapply(PRM, function(p) Q[[paste0(ver[[p]], "_", p)]]))

# Data ----------------------------------------------------------------------------------------------------
comp <- as.data.table(read_parquet(file.path(M4_DIR, "components.parquet")))
pan <- lapply(setNames(LINES, LINES), function(ln) as.data.table(read_parquet(file.path(HO, "panel", paste0("panel_", ln, ".parquet")))))
m2 <- rbind(as.data.table(read_parquet(M2_FOLDS))[valid_year %in% c(SEL, HOLD), .(row_id, valid_year, m2 = pred_final)],
            fread(M2_TEST, colClasses = list(character = "row_id"))[, .(row_id, valid_year = 2025L, m2 = prediction)])
Q <- merge(pan$motor, comp[, !c("policy_id", "exposure")], by = c("row_id", "valid_year"))
Q <- merge(Q, m2, by = c("row_id", "valid_year"))
cov <- Q[, .N, by = valid_year][pan$motor[, .(panel = .N), by = valid_year], on = "valid_year"]
print(cov)
stopifnot(cov[valid_year == 2025, N == panel])
Q[, `:=`(y_rep = Reduce(`+`, lapply(PRM, function(p) num(.SD, paste0("act_", p)))),
         y_dev = Reduce(`+`, lapply(PRM, function(p) num(.SD, paste0("dev_", p)))))]
chk <- Q[valid_year != 2025, c(list(panel_act = sum(y_rep), motor4_rep = sum(Reduce(`+`, lapply(PRM, function(p) num(.SD, paste0("rep_", p)))))),
                                list(developed = sum(y_dev))), by = valid_year]
print(chk)
# Other lines' deviance and null parts (unchanged by any motor candidate), per year
oth <- rbindlist(lapply(c(SEL, HOLD), function(vy) {
  rbindlist(lapply(setdiff(LINES, "motor"), function(ln) {
    x <- pan[[ln]][valid_year == vy]
    y <- Reduce(`+`, lapply(PERILS[[ln]], function(p) num(x, paste0("act_", p))))
    data.table(valid_year = vy, y = list(y), e = list(num(x, "exposure")), dev = sum(tdev_rows(y, line_w9(x, ln))))
  }))[, .(y = list(unlist(y)), e = list(unlist(e)), dev = sum(dev)), by = valid_year]
}))
all_d2 <- function(vy, ym, em, pm) {
  o <- oth[valid_year == vy]
  y <- c(ym, o$y[[1]]); e <- c(em, o$e[[1]])
  1 - (sum(tdev_rows(ym, pm)) + o$dev) / null_dev(y, e)
}
QY <- split(Q, by = "valid_year", keep.by = TRUE)
yrs <- as.character(c(SEL, HOLD))

# 1. Peril versions (calibrated peril D2 vs developed and reported cost) ---------------------------------
pt <- rbindlist(lapply(yrs, function(k) {
  x <- QY[[k]]
  rbindlist(lapply(PRM, function(p) {
    rbindlist(lapply(c("w9", VERS[paste0(VERS, "_", p) %in% names(x)]), function(v) {
      pr <- if (v == "w9") peril_w9(x, "motor", p) else x[[paste0(v, "_", p)]]
      data.table(valid_year = as.integer(k), peril = p, version = v,
                 d2c_dev = d2c(num(x, paste0("dev_", p)), pr, x$exposure), d2c_rep = d2c(num(x, paste0("act_", p)), pr, x$exposure))
    }))
  }))
}))
ptw <- dcast(pt, peril + version ~ valid_year, value.var = c("d2c_dev", "d2c_rep"))
print(ptw, digits = 4)
fwrite(ptw, file.path(OUT, "peril_versions.csv"))
VER <- sapply(PRM, function(p) pt[valid_year == SEL & peril == p & version %in% VERS][which.max(d2c_dev), version], simplify = FALSE)
log_msg("Chosen versions (2023): ", paste(PRM, unlist(VER), sep = "=", collapse = ", "))

# 2. Per-peril v on 2023 developed motor D2 (others at 0, MOTOR 2 member) -----------------------------------
V0 <- setNames(as.list(rep(0, length(PRM))), PRM)
sel_score <- function(v, member_fun) {
  x <- QY[[as.character(SEL)]]
  d2(x$y_dev, motor_pred(x, v, VER, member_fun(x)), x$exposure)
}
mem_m2 <- function(x) x$m2
mem_m4 <- function(x) m4_total(x, VER)
vg <- rbindlist(lapply(PRM, function(p) {
  data.table(peril = p, v = V_GRID, d2_dev_2023 = sapply(V_GRID, function(a) { v <- V0; v[[p]] <- a; sel_score(v, mem_m2) }))
}))
print(dcast(vg, peril ~ v, value.var = "d2_dev_2023"), digits = 6)
fwrite(vg, file.path(OUT, "v_grid_2023.csv"))
V <- sapply(PRM, function(p) vg[peril == p][which.max(d2_dev_2023), v], simplify = FALSE)
log_msg("Chosen v (2023): ", paste(PRM, unlist(V), sep = "=", collapse = ", "))

# 3. Candidates; pick one on 2023 ----------------------------------------------------------------------
CANDS <- list(base = list(v = V0, mem = mem_m2), A = list(v = V, mem = mem_m2), B = list(v = V0, mem = mem_m4),
              C = list(v = V, mem = mem_m4))
gain_stats <- function(x, yv, pb, pc) {
  dd <- tdev_rows(x[[yv]], pb) - tdev_rows(x[[yv]], pc)
  nd <- null_dev(x[[yv]], x$exposure)
  s <- rowsum(dd, x$policy_id)[, 1]
  c(gain = sum(dd) / nd, se = sd(s) * sqrt(length(s)) / nd)
}
ev <- rbindlist(lapply(yrs, function(k) {
  x <- QY[[k]]
  pb <- motor_pred(x, V0, VER, mem_m2(x))
  rbindlist(lapply(names(CANDS), function(cn) {
    cd <- CANDS[[cn]]
    pc <- motor_pred(x, cd$v, VER, cd$mem(x))
    gd <- gain_stats(x, "y_dev", pb, pc); gr <- gain_stats(x, "y_rep", pb, pc)
    data.table(valid_year = as.integer(k), cand = cn, motor_d2_dev = d2(x$y_dev, pc, x$exposure),
               motor_d2_rep = d2(x$y_rep, pc, x$exposure), all_d2_rep = all_d2(as.integer(k), x$y_rep, x$exposure, pc),
               gain_dev = gd[["gain"]], se_dev = gd[["se"]], gain_rep = gr[["gain"]], se_rep = gr[["se"]],
               gain_all_rep = all_d2(as.integer(k), x$y_rep, x$exposure, pc) - all_d2(as.integer(k), x$y_rep, x$exposure, pb))
  }))
}))
print(ev, digits = 5)
fwrite(ev, file.path(OUT, "candidates.csv"))
s1 <- ev[valid_year == SEL & cand != "base"][order(-gain_dev)]
CH <- if (s1$gain_dev[1] > 0) s1$cand[1] else "base"
h <- ev[valid_year == HOLD & cand == CH]
s <- ev[valid_year == SEL & cand == CH]
PASS <- CH != "base" && h$gain_dev > 2 * h$se_dev && h$gain_rep > 0 && h$gain_all_rep > 0 && s$gain_dev > 0
log_msg("Chosen on 2023: ", CH, " | held-out 2024 gain dev ", signif(h$gain_dev, 3), " (SE ", signif(h$se_dev, 2),
        "), rep ", signif(h$gain_rep, 3), ", all-line rep ", signif(h$gain_all_rep, 3), " -> ", if (PASS) "PASS" else "FAIL")
fwrite(data.table(chosen = CH, versions = paste(PRM, unlist(VER), sep = "=", collapse = ", "),
                  v = paste(PRM, unlist(V), sep = "=", collapse = ", "), sel_gain_dev = s$gain_dev, hold_gain_dev = h$gain_dev,
                  hold_se_dev = h$se_dev, hold_gain_rep = h$gain_rep, hold_gain_all_rep = h$gain_all_rep, pass = PASS),
       file.path(OUT, "decision.csv"))

# 4. 2025 file (other lines and the baseline motor reproduce the 0.12965 file) -----------------------------
x <- QY[["2025"]]
base_sub <- fread(BASE_FILE, colClasses = list(character = "row_id"))
bm <- base_sub[match(x$row_id, row_id), prediction]
rep_diff <- max(abs(motor_pred(x, V0, VER, mem_m2(x)) / bm - 1))
log_msg("Baseline motor reproduces the 0.12965 file: max rel diff ", signif(rep_diff, 3))
stopifnot(rep_diff < 1e-4)
if (CH != "base") {
  cd <- CANDS[[CH]]
  pc <- motor_pred(x, cd$v, VER, cd$mem(x))
  sub <- copy(base_sub)
  sub[match(x$row_id, row_id), prediction := pc]
  stopifnot(!anyNA(sub$prediction), all(sub$prediction >= 0), abs(sum(sub$prediction) / sum(base_sub$prediction) - 1) < 1e-6)
  f <- out_file("submission", sprintf("submission_%s_w9_m2_%s_%s_%s.csv", format(Sys.time(), "%Y%m%d_%H%M"), TAG, CH,
                                      if (PASS) "PASS" else "FAIL"))
  fwrite(sub, f, scipen = 50)
  log_msg("Wrote ", f, "; motor Spearman vs 0.12965 file ", round(cor(pc, bm, method = "spearman"), 5))
}
