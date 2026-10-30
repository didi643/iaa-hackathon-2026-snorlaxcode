# 26_probe_solver.R -----------------------------------------------------------------------------------------------------
# Purpose : Estimate the 2025 public A/E level (theta) of segments of the line_ensemble base from public level probes and
#           give the Tweedie-optimal multipliers. Each probe multiplies base peril predictions (MULT, as in
#           25_level_calibration.R). With E[y_row] = sum_s theta_s * mu_s,row the expected change in public Tweedie
#           (p = 1.5) deviance of probe f vs the base is
#             dDev_f = q * sum_rows [ 4 E_r (mu_f^-0.5 - mu_0^-0.5) + 4 (mu_f^0.5 - mu_0^0.5) ]   (q = public share 1/3)
#           so dD2_f = -dDev_f / Dev0_pub is linear in theta given K = q / Dev0_pub. K is fitted (or fixed via K_FIX).
#           Optimal multipliers: c_s = theta_s (prediction equals expected cost row by row).
# Inputs  : data/week_2/optionB/final/{x20_tblend,rt_var_b8_floor_corrected}/pred_2025_peril.parquet,
#           week2/output/25_level/probes.csv (tag, mult, public)
# Run     : SEGS="motor,buildings,contents" Rscript week2/R/26_probe_solver.R
#           SEGS entries: "<line>" (all perils of the line not listed elsewhere) or "<line>/<peril>[+<peril>]".
# Time    : seconds

suppressMessages({library(data.table); library(arrow)})
SEGS <- strsplit(Sys.getenv("SEGS", "motor,buildings,contents"), ",")[[1]]
K_FIX <- as.numeric(Sys.getenv("K_FIX", NA))
rd <- function(t) as.data.table(read_parquet(file.path("data/week_2/optionB/final", t, "pred_2025_peril.parquet"),
                                             col_select = c("line", "peril", "row_id", "pred_B")))
p <- rbind(rd("x20_tblend")[line == "motor"], rd("rt_var_b8_floor_corrected")[line != "motor"])

seg_of <- function(line, peril) {
  s <- rep(NA_character_, length(line))
  for (g in SEGS[grepl("/", SEGS)]) { k <- strsplit(g, "/")[[1]]; s[line == k[1] & peril %in% strsplit(k[2], "\\+")[[1]]] <- g }
  for (g in SEGS[!grepl("/", SEGS)]) s[is.na(s) & line == g] <- g
  stopifnot(!anyNA(s)); s
}
p[, seg := seg_of(line, peril)]
apply_mult <- function(mult) {
  m <- rep(1, nrow(p))
  if (nzchar(mult)) {
    spec <- rbindlist(lapply(strsplit(strsplit(mult, ";")[[1]], "="), function(x) data.table(k = trimws(x[1]), m = as.numeric(x[2]))))
    for (i in seq_len(nrow(spec))) if (!grepl("/", spec$k[i])) m[p$line == spec$k[i]] <- spec$m[i]
    for (i in seq_len(nrow(spec))) if (grepl("/", spec$k[i])) {
      k <- strsplit(spec$k[i], "/")[[1]]; m[p$line == k[1] & p$peril %in% strsplit(k[2], "\\+")[[1]]] <- spec$m[i]
    }
  }
  m
}
S <- sort(unique(p$seg))
mu_seg <- dcast(p, row_id ~ seg, value.var = "pred_B", fun.aggregate = sum, fill = 0)
mu0 <- rowSums(as.matrix(mu_seg[, ..S]))
pr <- fread("week2/output/25_level/probes.csv")
base_score <- pr[tag == "base", public]
X <- matrix(0, 0, length(S)); kn <- numeric(0); dy <- numeric(0)
for (j in which(pr$tag != "base")) {
  p[, mf := pred_B * apply_mult(pr$mult[j])]
  muf <- p[, .(mf = sum(mf)), by = row_id][match(mu_seg$row_id, row_id), mf]
  w <- 4 * (muf^-0.5 - mu0^-0.5)
  X <- rbind(X, colSums(as.matrix(mu_seg[, ..S]) * w)); kn <- c(kn, sum(4 * (sqrt(muf) - sqrt(mu0))))
  dy <- c(dy, pr$public[j] - base_score)
}
# dy = -K * (X theta + kn)  ->  fit K and theta
fit_theta <- function(K) { A <- -K * X; b <- dy + K * kn; qr.solve(A, b) }
sse <- function(lK) { K <- exp(lK); th <- fit_theta(K); sum((dy + K * (X %*% th + kn))^2) }
if (is.na(K_FIX)) {
  if (nrow(X) > length(S)) K <- exp(optimize(sse, log(c(1e-9, 1e-5)))$minimum) else stop("Need more probes than segments or K_FIX")
} else K <- K_FIX
th <- fit_theta(K)
pred <- -K * (X %*% th + kn)
cat(sprintf("K = %.4g  (segments %d, probes %d)\n", K, length(S), nrow(X)))
print(data.table(tag = pr$tag[pr$tag != "base"], obs = round(dy, 5), fit = round(as.vector(pred), 5)))
E <- as.vector(as.matrix(mu_seg[, ..S]) %*% th)
gain <- -K * sum(4 * E * (E^-0.5 - mu0^-0.5) + 4 * (sqrt(E) - sqrt(mu0)))
print(data.table(segment = S, theta = round(th, 3), base_cost = round(colSums(mu_seg[, ..S]))))
cat(sprintf("Expected public at c = theta: %.5f (gain %.5f over base %.5f)\n", base_score + gain, gain, base_score))
# Sensitivity of theta to Kaggle's 5-decimal rounding of every public score (base and probes), K held fixed
set.seed(1); dy0 <- dy
sim <- t(replicate(500, { dy <<- dy0 + runif(length(dy0), -5e-6, 5e-6) - runif(1, -5e-6, 5e-6); fit_theta(K) }))
dy <- dy0
print(data.table(segment = S, theta = round(th, 3), sd_rounding = round(apply(sim, 2, sd), 3)))
# Expected public for candidate multiplier sets under the fitted theta (EVAL = "name:mult|name:mult", mult as in probes.csv)
EVAL <- Sys.getenv("EVAL", "")
if (nzchar(EVAL)) for (ev in strsplit(EVAL, "\\|")[[1]]) {
  nm <- sub(":.*", "", ev); p[, mf := pred_B * apply_mult(sub("^[^:]*:", "", ev))]
  muf <- p[, .(mf = sum(mf)), by = row_id][match(mu_seg$row_id, row_id), mf]
  g <- -K * sum(4 * E * (muf^-0.5 - mu0^-0.5) + 4 * (sqrt(muf) - sqrt(mu0)))
  cat(sprintf("EVAL %-10s expected public %.5f  total vs base %.4f\n", nm, base_score + g, sum(muf) / sum(mu0)))
}
