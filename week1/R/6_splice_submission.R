# 6_splice_submission.R -------------------------------------------------------------------------------
# Builds a submission by taking each line's rows from a chosen source submission (e.g. motor from WENDY 4, buildings
# and contents from SAM 4) and reports per-line levels and how far the sources disagree.
# Usage: Rscript week1/R/6_splice_submission.R motor=<file> buildings=<file> contents=<file> [label=<text>]
#        files are names in week1/output/submission/; defaults below.

source("week1/R/0_setup.R")

args <- commandArgs(trailingOnly = TRUE)
opt <- setNames(sub("^[^=]+=", "", args), sub("=.*$", "", args))
src <- c(motor = "submission_20261022_0715_wendy04.csv", buildings = "submission_20261022_1734.csv",
         contents = "submission_20261022_1734.csv")
for (ln in intersect(names(opt), LINES)) src[[ln]] <- opt[[ln]]
label <- if (!is.na(opt["label"])) opt[["label"]] else "splice"

sample_sub <- read_raw("sample_submission")
row_line <- rbindlist(lapply(LINES, function(ln) {
  data.table(row_id = as.character(read_parquet(file.path(PATHS$raw, paste0("test_", ln, ".parquet")),
                                                col_select = "row_id")$row_id), line = ln)
}))
stopifnot(nrow(row_line) == nrow(sample_sub), setequal(row_line$row_id, sample_sub$row_id))
expo <- rbindlist(lapply(LINES, function(ln) read_clean(paste0("test_", ln))[, .(row_id, exposure)]))

read_sub <- function(f) {
  s <- fread(file.path(PATHS$output, "submission", f), colClasses = list(character = "row_id"))
  stopifnot(nrow(s) == nrow(sample_sub), setequal(s$row_id, sample_sub$row_id), !anyNA(s$prediction), all(s$prediction >= 0))
  s
}
subs <- lapply(unique(src), read_sub)
names(subs) <- unique(src)

out <- rbindlist(lapply(LINES, function(ln) {
  ids <- row_line[line == ln, row_id]
  s <- subs[[src[[ln]]]]
  s[match(ids, row_id), .(row_id, prediction)]
}))
out <- out[match(sample_sub$row_id, row_id)]
stopifnot(nrow(out) == nrow(sample_sub), !anyNA(out$prediction))

# Level per line and source, and agreement between sources on the same rows
cmp <- rbindlist(lapply(LINES, function(ln) rbindlist(lapply(unique(src), function(f) {
  d <- merge(row_line[line == ln], subs[[f]], by = "row_id")[expo, on = "row_id", nomatch = 0]
  data.table(line = ln, source = f, used = src[[ln]] == f, burn_cost = sum(d$prediction) / sum(d$exposure))
}))))
if (length(unique(src)) > 1) {
  a <- subs[[1]]; b <- subs[[2]]
  agree <- rbindlist(lapply(LINES, function(ln) {
    d <- merge(merge(row_line[line == ln], a, by = "row_id"), b, by = "row_id", suffixes = c("_a", "_b"))
    data.table(line = ln, a = names(subs)[1], b = names(subs)[2], ratio_b_to_a = sum(d$prediction_b) / sum(d$prediction_a),
               spearman = cor(d$prediction_a, d$prediction_b, method = "spearman"))
  }))
  print(agree)
}
print(dcast(cmp, line ~ source, value.var = "burn_cost"))

run_file <- out_file("submission", paste0("submission_", format(Sys.time(), "%Y%m%d_%H%M"), "_", label, ".csv"))
fwrite(out, run_file, scipen = 50)
log_msg("Wrote ", run_file, " (MD5 ", unname(tools::md5sum(run_file)), ") from: ",
        paste(sprintf("%s=%s", names(src), src), collapse = "; "))
