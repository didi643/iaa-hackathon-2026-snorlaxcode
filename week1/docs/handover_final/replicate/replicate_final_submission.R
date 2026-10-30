# replicate_final_submission.R -----------------------------------------------------------------------------
# Rebuilds the final chosen submission (submission_20261023_1636_w9_motor2_pre_m0.5.csv, public 0.12965, private 0.13923)
# from the frozen inputs in ./inputs, in seconds, and checks it against the committed file.
#   per line   b = LW x sum_p [w_p x ladder_p + (1 - w_p) x C5_p] + (1 - LW) x SAM 3          (WENDY 9)
#   motor      b = 0.5 x b + 0.5 x MOTOR 2 x sum(b) / sum(MOTOR 2)                             (MOTOR 2 member, pre-credibility)
#   all lines  q = b x (A + N) / (A + E), rescaled to sum(b)                                   (WENDY 8 credibility)
# Same arithmetic as R/6_blend_w9_motor2.R ("pre", m = 0.5).
# Run from anywhere:  Rscript <path>/docs/handover_final/replicate/replicate_final_submission.R
# Needs R packages data.table and arrow only. Writes <this folder>/output/submission_final_replicated.csv.
# Rebuilt inputs (scripts/rebuild_all.ps1): PANEL_DIR=<dir with panel_<line>_2025.parquet> M2_TEST=<MOTOR 2 csv>
# OUT_DIR=<dir> - the result is then compared with the submitted file instead of required to match it.

self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
HERE <- if (length(self)) dirname(normalizePath(self)) else file.path("docs", "handover_final", "replicate")
# Outside the repo root renv is not active: borrow the repo's renv library if the packages are not installed
if (!all(vapply(c("data.table", "arrow"), requireNamespace, logical(1), quietly = TRUE))) {
  rl <- file.path(HERE, "..", "..", "..", "renv", "library")
  libs <- unique(dirname(grep("[/\\\\]data\\.table$", list.dirs(rl, recursive = TRUE), value = TRUE)))
  .libPaths(c(libs, .libPaths()))
}
if (!all(vapply(c("data.table", "arrow"), requireNamespace, logical(1), quietly = TRUE))) {
  stop("Install the R packages first: install.packages(c('data.table', 'arrow'))")
}
suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
})
IN <- file.path(HERE, "inputs")
PANEL_DIR <- Sys.getenv("PANEL_DIR", IN)
M2_TEST <- Sys.getenv("M2_TEST", file.path(IN, "motor2_only_20261023_1359.csv"))
STRICT <- PANEL_DIR == IN && M2_TEST == file.path(IN, "motor2_only_20261023_1359.csv")
OUT <- Sys.getenv("OUT_DIR", file.path(HERE, "output"))
REF <- file.path(dirname(HERE), "submissions", "submission_20261023_1636_w9_motor2_pre_m0.5.csv")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

PERILS <- list(motor = c("own_damage", "third_party_prop", "bodily_injury", "theft", "glass_hail"),
               buildings = c("storm", "flood", "escape_of_water", "subsidence", "fire", "accidental_damage"),
               contents = c("theft", "escape_of_water", "accidental_damage", "flood"))
W <- list(motor = c(own_damage = 0, third_party_prop = 1, bodily_injury = 0, theft = 0, glass_hail = 1),
          buildings = c(storm = 1, flood = 0, escape_of_water = 0, subsidence = 0.5, fire = 0.25, accidental_damage = 0.25),
          contents = c(theft = 0, escape_of_water = 0.75, accidental_damage = 0, flood = 0.75))
LW <- c(motor = 0.9, buildings = 0.7, contents = 0.9)
A_CRED <- c(motor = 8, buildings = 5, contents = 5)
M_MOTOR2 <- 0.5

num <- function(Q, col) {
  v <- as.numeric(Q[[col]])
  v[is.na(v)] <- 0
  v
}
cred <- function(Q, ln, b) {
  q <- b * (A_CRED[[ln]] + num(Q, "N")) / (A_CRED[[ln]] + num(Q, "E"))
  q * sum(b) / sum(q)
}
line_pred <- function(Q, ln) {
  pb <- Reduce(`+`, lapply(PERILS[[ln]], function(p) W[[ln]][[p]] * num(Q, paste0("lad_", p)) + (1 - W[[ln]][[p]]) * num(Q, paste0("c5_", p))))
  b <- LW[[ln]] * pb + (1 - LW[[ln]]) * num(Q, "sam3")
  if (ln == "motor") b <- (1 - M_MOTOR2) * b + M_MOTOR2 * Q$m2 * sum(b) / sum(Q$m2)
  cred(Q, ln, b)
}

D <- lapply(setNames(names(PERILS), names(PERILS)), function(ln) as.data.table(read_parquet(file.path(PANEL_DIR, sprintf("panel_%s_2025.parquet", ln)))))
m2 <- fread(M2_TEST, colClasses = list(character = "row_id"))[, .(row_id, m2 = prediction)]
D$motor <- merge(D$motor, m2, by = "row_id", all.x = TRUE, sort = FALSE)
stopifnot(!anyNA(D$motor$m2))
sub <- rbindlist(lapply(names(D), function(ln) data.table(row_id = D[[ln]]$row_id, prediction = line_pred(D[[ln]], ln))))
ord <- fread(file.path(IN, "row_order.csv"), colClasses = list(character = "row_id"))
stopifnot(nrow(sub) == nrow(ord), setequal(sub$row_id, ord$row_id), !anyNA(sub$prediction), all(sub$prediction >= 0))
sub <- sub[match(ord$row_id, row_id)]
f <- file.path(OUT, if (STRICT) "submission_final_replicated.csv" else "submission_final_rebuilt.csv")
fwrite(sub, f, scipen = 50)

ref <- fread(REF, colClasses = list(character = "row_id"))
stopifnot(identical(ref$row_id, sub$row_id))
rel <- max(abs(sub$prediction / ref$prediction - 1))
md5 <- unname(tools::md5sum(f))
cat(sprintf("Wrote %s (%d rows)\nMax relative difference vs committed file: %.2e\nMD5 %s (committed file 148a9f430289965107f40175dd2953ca)\n",
            f, nrow(sub), rel, md5))
if (!STRICT) {
  ln_of <- substr(sub$row_id, 1, 1)
  cmp <- data.table(line = ln_of, new = sub$prediction, old = ref$prediction)[
    , .(rows = .N, total_ratio = sum(new) / sum(old), pearson = cor(new, old), spearman = cor(new, old, method = "spearman"),
        median_abs_rel_diff = median(abs(new / old - 1)), p99_abs_rel_diff = quantile(abs(new / old - 1), 0.99)), by = line]
  print(cmp)
  fwrite(cmp, file.path(OUT, "comparison_vs_submitted.csv"))
  quit(save = "no")
}
stopifnot(rel < 1e-9)
cat("Replication OK\n")
