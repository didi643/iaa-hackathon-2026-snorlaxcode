# 9_final_blend.R --------------------------------------------------------------------------------------------------
# Final stage: assembles the 2025 submission from the rebuilt components and compares it with the submitted file.
#   per peril  pb_p = w_p x ladder_p + (1 - w_p) x C5_p          w   = inputs/assemble_weights.json $W (submitted)
#   per line   b    = LW x sum_p pb_p + (1 - LW) x SAM 3          LW  = inputs/assemble_weights.json $LW
#   motor      b    = (1 - m) x b + m x MOTOR 2 x sum(b) / sum(MOTOR 2),  m = 0.5
#   all lines  q    = b x (A + N) / (A + E), rescaled to sum(b)   A   = motor 8, buildings 5, contents 5
# Inputs (rebuilt by run_all.R): models/wendy_iteration_07/c5/test_preds_peril.parquet, the SAM 3 and MOTOR 2 2025 files,
# models/wendy_iteration_08/history_<line>.parquet (N, E), models/wendy_iteration_09/ladder_2025.parquet (ladder).
# Check: every component and the final file vs the submitted ones (inputs/target_submission.csv and the frozen WENDY 9
# panel ../docs/handover_final/replicate/inputs, which holds the exact 2025 components of the submission).
# Out:  output/submission/submission_final_week1.csv, output/final_week1/component_check.csv, final_check.csv

source("R/0_setup.R")
OUT <- file.path(PATHS$output, "final_week1")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
FROZEN <- Sys.getenv("FROZEN_PANEL_DIR", file.path("..", "docs", "handover_final", "replicate", "inputs"))

wts <- jsonlite::fromJSON("inputs/assemble_weights.json")
A_CRED <- c(motor = 8, buildings = 5, contents = 5)
M_MOTOR2 <- 0.5

# Components ---------------------------------------------------------------------------------------------------------
c5 <- as.data.table(read_parquet(file.path("models", "wendy_iteration_07", "c5", "test_preds_peril.parquet")))
s3 <- read.csv("models/sam_iteration_03/summary.csv"); s3 <- s3[nrow(s3), , drop = FALSE]
sam3 <- fread(file.path("output", "submission", s3$file), colClasses = list(character = "row_id"))[, .(row_id, sam3 = prediction)]
m2s <- read.csv("models/motor_iteration_02/summary.csv"); m2s <- m2s[nrow(m2s), , drop = FALSE]
motor2 <- fread(file.path("output", "submission", paste0("motor2_only_", m2s$run_id, ".csv")),
                colClasses = list(character = "row_id"))[, .(row_id, m2 = prediction)]
hist <- rbindlist(lapply(LINES, function(ln)
  as.data.table(read_parquet(file.path("models", "wendy_iteration_08", paste0("history_", ln, ".parquet"))))[, .(row_id, N, E)]))
lad <- as.data.table(read_parquet(file.path("models", "wendy_iteration_09", "ladder_2025.parquet")))   # row_id, line, peril, lad

panel <- function(ln) {
  x <- c5[line == ln, c("row_id", paste0("pred_", PERILS[[ln]])), with = FALSE]
  setnames(x, paste0("pred_", PERILS[[ln]]), paste0("c5_", PERILS[[ln]]))
  for (p in PERILS[[ln]]) {
    l <- lad[line == ln & peril == p]
    set(x, j = paste0("lad_", p), value = if (nrow(l)) l$lad[match(x$row_id, l$row_id)] else NA_real_)
  }
  x <- merge(x, sam3, by = "row_id", all.x = TRUE, sort = FALSE)
  x <- merge(x, hist, by = "row_id", all.x = TRUE, sort = FALSE)
  if (ln == "motor") x <- merge(x, motor2, by = "row_id", all.x = TRUE, sort = FALSE)
  x
}
num <- function(Q, col) { v <- as.numeric(Q[[col]]); v[is.na(v)] <- 0; v }
line_pred <- function(Q, ln) {
  W <- wts$W[[ln]]
  pb <- Reduce(`+`, lapply(PERILS[[ln]], function(p) W[[p]] * num(Q, paste0("lad_", p)) + (1 - W[[p]]) * num(Q, paste0("c5_", p))))
  b <- wts$LW[[ln]] * pb + (1 - wts$LW[[ln]]) * num(Q, "sam3")
  if (ln == "motor") b <- (1 - M_MOTOR2) * b + M_MOTOR2 * Q$m2 * sum(b) / sum(Q$m2)
  q <- b * (A_CRED[[ln]] + num(Q, "N")) / (A_CRED[[ln]] + num(Q, "E"))
  q * sum(b) / sum(q)
}

D <- setNames(lapply(LINES, panel), LINES)
for (ln in LINES) {
  need <- c(paste0("c5_", PERILS[[ln]]), "sam3", "N", "E", if (ln == "motor") "m2",
            paste0("lad_", names(Filter(function(w) w > 0, wts$W[[ln]]))))
  miss <- need[vapply(need, function(cn) anyNA(D[[ln]][[cn]]), logical(1))]
  if (length(miss)) stop(ln, ": missing component values in ", paste(miss, collapse = ", "))
}
sample_sub <- read_raw("sample_submission")
sub <- rbindlist(lapply(LINES, function(ln) data.table(row_id = D[[ln]]$row_id, prediction = line_pred(D[[ln]], ln))))
sub <- sub[match(sample_sub$row_id, row_id)]
stopifnot(nrow(sub) == nrow(sample_sub), !anyNA(sub$prediction), all(sub$prediction >= 0))
f_out <- out_file("submission", "submission_final_week1.csv")
fwrite(sub, f_out, scipen = 50)

# Comparison with the submission -------------------------------------------------------------------------------------
cmp <- function(a, b) { k <- is.finite(a) & is.finite(b) & b != 0; r <- a[k] / b[k] - 1
  data.table(rows = sum(k), total_ratio = sum(a[k]) / sum(b[k]), max_abs_rel = max(abs(r)), median_abs_rel = median(abs(r)),
             p99_abs_rel = quantile(abs(r), 0.99, names = FALSE), spearman = cor(a[k], b[k], method = "spearman")) }
comp <- rbindlist(lapply(LINES, function(ln) {
  fz <- as.data.table(read_parquet(file.path(FROZEN, sprintf("panel_%s_2025.parquet", ln))))
  x <- D[[ln]][fz, on = "row_id", nomatch = 0]
  cols <- c(grep("^(c5_|lad_)", names(fz), value = TRUE), "sam3", "N", "E")
  rbindlist(lapply(cols, function(cn) { a <- x[[cn]]; b <- x[[paste0("i.", cn)]]
    if (is.null(a) || all(is.na(b))) return(NULL); cbind(data.table(line = ln, component = cn), cmp(as.numeric(a), as.numeric(b))) }))
}))
fm2 <- fread(file.path(FROZEN, "motor2_only_20261023_1359.csv"), colClasses = list(character = "row_id"))
comp <- rbind(comp, cbind(data.table(line = "motor", component = "motor2"),
                          cmp(motor2$m2[match(fm2$row_id, motor2$row_id)], fm2$prediction)))
tgt <- fread("inputs/target_submission.csv", colClasses = list(character = "row_id"))
fin <- rbindlist(lapply(c("M", "B", "C"), function(l) { k <- startsWith(tgt$row_id, l)
  cbind(data.table(line = l), cmp(sub$prediction[match(tgt$row_id[k], sub$row_id)], tgt$prediction[k])) }))
fwrite(comp, file.path(OUT, "component_check.csv")); fwrite(fin, file.path(OUT, "final_check.csv"))
options(width = 200)
print(comp[, lapply(.SD, function(v) if (is.numeric(v)) signif(v, 4) else v)])
print(fin[, lapply(.SD, function(v) if (is.numeric(v)) signif(v, 4) else v)])
log_msg("Final file ", f_out, " MD5 ", unname(tools::md5sum(f_out)), " (submitted 148a9f430289965107f40175dd2953ca); max row ",
        "difference vs submitted ", signif(max(fin$max_abs_rel), 3), if (max(fin$max_abs_rel) < 1e-6) " - IDENTICAL to 1e-6" else "")
