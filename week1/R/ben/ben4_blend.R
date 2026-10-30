# ben/ben4_blend.R -------------------------------------------------------------
# BEN 4 follow-up: per-line blend of all five BEN 4 variants (v0-v4) instead of the script's two-model blend (v5).
# Weights on a 0.1 grid, non-negative, summing to 1, chosen per line on the mean D2 against developed actuals over the
# 2023 and 2024 folds (the same basis as week1/R/4_models_iterben04.R). A candidate file is written only if the blend beats
# the iteration's selection on the combined D2 of both folds, reported and developed.
# Run:     Rscript week1/R/ben/ben4_blend.R [run id]   (after week1/R/4_models_iterben04.R; default = latest predictions file)
# Outputs: week1/output/ben/ben4/blend_weights.csv, blend_report.md; week1/output/submission/submission_<run id>_ben04_blend.csv

source("week1/R/0_setup.R")
source("week1/R/ben/ben_helpers.R")
args <- commandArgs(trailingOnly = TRUE)
files <- sort(list.files(ben_out("ben4"), "^predictions_.*\\.parquet$", full.names = TRUE))
f <- if (length(args)) ben_out(file.path("ben4", paste0("predictions_", args[1], ".parquet"))) else tail(files, 1)
run_id <- sub("^predictions_(.*)\\.parquet$", "\\1", basename(f))
P <- as.data.table(read_parquet(f))
V <- c("v0", "v1", "v2", "v3", "v4")
# the predictions file is written before the iteration's blend and selection; rebuild both from its CSVs
it_dir <- file.path("week1", "models", "ben_iteration_04")
bp <- unique(fread(file.path(it_dir, "blend_grid.csv"))[order(line, -d2_dev, -w_line)], by = "line")
sel <- fread(file.path(it_dir, "selection.csv"))
for (ln in LINES) {
  b <- bp[line == ln]
  P[line == ln, v5 := b$w_line * get(b$line_model) + (1 - b$w_line) * v4]
  P[line == ln, selected := get(sel[line == ln, variant])]
}

tweedie_dev <- function(y, mu, p = TWEEDIE_P) {
  mu <- pmax(mu, 1e-9)
  mean(2 * (ifelse(y > 0, y^(2 - p), 0) / ((1 - p) * (2 - p)) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p)))
}
d2_tweedie <- function(y, pred, exposure) 1 - tweedie_dev(y, pred) / tweedie_dev(y, exposure * sum(y) / sum(exposure))

# all weight vectors on a 0.1 grid over five variants summing to 1 (1,001 of them)
g <- CJ(a = 0:10, b = 0:10, c = 0:10, d = 0:10)[a + b + c + d <= 10][, e := 10 - a - b - c - d]
W <- as.matrix(g) / 10
colnames(W) <- V
VAL <- P[year %in% c(2023, 2024)]
best <- rbindlist(lapply(LINES, function(ln) {
  d <- VAL[line == ln]
  M <- as.matrix(d[, ..V])
  sc <- vapply(seq_len(nrow(W)), function(i) {
    pr <- drop(M %*% W[i, ])
    mean(vapply(c(2023, 2024), function(y) { k <- d$year == y; d2_tweedie(d$actual_dev[k], pr[k], d$exposure[k]) }, 0))
  }, 0)
  i <- which.max(sc)
  data.table(line = ln, t(W[i, ]), d2_dev_mean = sc[i])
}))
for (ln in LINES) {
  w <- unlist(best[line == ln, ..V])
  P[line == ln, blend := drop(as.matrix(.SD) %*% w), .SDcols = V]
}
VAL <- P[year %in% c(2023, 2024)]
cmp <- rbindlist(lapply(c("selected", "blend"), function(col) VAL[, .(model = col, d2 = d2_tweedie(actual, get(col), exposure),
                                                                       d2_dev = d2_tweedie(actual_dev, get(col), exposure)), by = year]))
by_line <- VAL[, .(d2_selected = d2_tweedie(actual, selected, exposure), d2_blend = d2_tweedie(actual, blend, exposure)), by = .(line, year)]
wins <- all(cmp[model == "blend", d2] > cmp[model == "selected", d2]) && all(cmp[model == "blend", d2_dev] > cmp[model == "selected", d2_dev])
fwrite(best, ben_out(file.path("ben4", "blend_weights.csv")))
out <- NA_character_
if (wins) {
  sub <- P[year == 2025, .(row_id, prediction = pmax(blend, 0))]
  ids <- read_raw("sample_submission")$row_id
  stopifnot(nrow(sub) == 626639, setequal(sub$row_id, ids), !anyNA(sub$prediction))
  out <- out_file("submission", paste0("submission_", run_id, "_ben04_blend.csv"))
  fwrite(sub[match(ids, row_id)], out)
}
level <- P[year == 2025, .(selected = sum(selected) / sum(exposure), blend = sum(blend) / sum(exposure)), by = line]
write_md(list(
  "# BEN 4 blend of all variants", "",
  paste0("Generated ", format(Sys.time(), "%Y-%m-%d %H:%M"), " from `week1/R/ben/ben4_blend.R` on `", basename(f), "`."), "",
  "## Weights per line (0.1 grid, mean developed D2 over 2023 and 2024)", md_table(best, 4),
  "## Combined D2: iteration selection vs this blend", md_table(cmp, 4),
  "## By line (reported actuals)", md_table(by_line, 4),
  "## 2025 cost per exposure-year", md_table(level, 1),
  if (wins) paste0("Blend beats the selection on both folds and both bases: candidate `", basename(out), "`, MD5 `",
                   unname(tools::md5sum(out)), "`.") else "Blend does not beat the selection on both folds and bases: no file written."
), file.path("ben", "ben4"), "blend_report.md")
print(best); print(cmp)
log_msg("Done: ", if (wins) out else "no candidate")
