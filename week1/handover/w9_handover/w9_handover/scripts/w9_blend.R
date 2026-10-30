# WENDY 9 blend from the handover panel only (no model refits). R port of scripts/w9_blend.py.
# Usage: Rscript scripts/w9_blend.R [out.csv]   (run from the handover folder; needs arrow, data.table)
# Edit W / LW / A_CRED (or swap lad_<peril> columns) and rerun: prints fold D2 by stage, writes the 2025 submission.
suppressPackageStartupMessages({ library(data.table); library(arrow) })
PERILS <- list(motor = c("own_damage", "third_party_prop", "bodily_injury", "theft", "glass_hail"),
               buildings = c("storm", "flood", "escape_of_water", "subsidence", "fire", "accidental_damage"),
               contents = c("theft", "escape_of_water", "accidental_damage", "flood"))
W <- list(motor = c(own_damage = 0, third_party_prop = 1, bodily_injury = 0, theft = 0, glass_hail = 1),   # weight on ladder vs C5
          buildings = c(storm = 1, flood = 0, escape_of_water = 0, subsidence = 0.5, fire = 0.25, accidental_damage = 0.25),
          contents = c(theft = 0, escape_of_water = 0.75, accidental_damage = 0, flood = 0.75))
LW <- c(motor = 0.9, buildings = 0.7, contents = 0.9)       # weight on peril blend vs SAM 3
A_CRED <- c(motor = 8, buildings = 5, contents = 5)         # M = (A+N)/(A+E), rescaled to keep line total
tdev <- function(y, mu, p = 1.5) { mu <- pmax(mu, 1e-12)
  2 * sum(ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p)) }
d2 <- function(y, mu, e) 1 - tdev(y, mu) / tdev(y, e * sum(y) / sum(e))
num <- function(Q, col) { v <- as.numeric(Q[[col]]); v[is.na(v)] <- 0; v }
preds <- function(Q, ln) {
  pb <- Reduce(`+`, lapply(PERILS[[ln]], function(p) W[[ln]][[p]] * num(Q, paste0("lad_", p)) + (1 - W[[ln]][[p]]) * num(Q, paste0("c5_", p))))
  b <- LW[[ln]] * pb + (1 - LW[[ln]]) * num(Q, "sam3")
  M <- (A_CRED[[ln]] + num(Q, "N")) / (A_CRED[[ln]] + num(Q, "E")); q <- b * M; q <- q * sum(b) / sum(q)
  list(c5 = Reduce(`+`, lapply(PERILS[[ln]], function(p) num(Q, paste0("c5_", p)))), peril_blend = pb, line_blend = b, final = q)
}
D <- lapply(setNames(names(PERILS), names(PERILS)), function(ln) as.data.table(read_parquet(file.path("panel", paste0("panel_", ln, ".parquet")))))
for (ln in names(D)) for (p in PERILS[[ln]]) if (W[[ln]][[p]] > 0)
  stopifnot("2025 ladder pred missing: refit needed" = !anyNA(D[[ln]][valid_year == 2025][[paste0("lad_", p)]]))
for (vy in c(2023, 2024)) {
  y <- e <- f2 <- c(); P <- list()
  for (ln in names(D)) {
    Q <- D[[ln]][valid_year == vy]
    yl <- Reduce(`+`, lapply(PERILS[[ln]], function(p) num(Q, paste0("act_", p))))
    pr <- preds(Q, ln); y <- c(y, yl); e <- c(e, num(Q, "exposure")); f2 <- c(f2, num(Q, "final2"))
    for (k in names(pr)) P[[k]] <- c(P[[k]], pr[[k]])
    cat(sprintf("  %s %d line D2 final %.5f\n", ln, vy, d2(yl, pr$final, num(Q, "exposure"))))
  }
  cat(vy, sprintf("all lines D2 | final2 %.5f", d2(y, f2, e)), sprintf("| %s %.5f", names(P), sapply(P, function(p) d2(y, p, e))), "\n")
}
out <- rbindlist(lapply(names(D), function(ln) { Q <- D[[ln]][valid_year == 2025]; data.table(row_id = Q$row_id, prediction = preds(Q, ln)$final) }))
stopifnot(nrow(out) == 626639, min(out$prediction) >= 0)
args <- commandArgs(TRUE); fwrite(out, if (length(args)) args[1] else "submission_w9_rebuilt.csv"); cat("written", nrow(out), "\n")
