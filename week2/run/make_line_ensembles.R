library(data.table)
old <- fread("week2/output/submission/submission_20261027_1305_week2_optionB_x20_tblend.csv")
new <- fread(list.files("week2/week1_retune/output/var_b8_floor_corrected/submission", pattern = "\\.csv$", full.names = TRUE)[1])
setkey(old, row_id); setkey(new, row_id)
z <- old[new, on = "row_id"]
for (spec in list(
  list(tag = "line_ensemble", b = "new", c = "new"),
  list(tag = "line_ensemble_buildings_only", b = "new", c = "old"),
  list(tag = "line_ensemble_contents_only", b = "old", c = "new")
)) {
  z[, prediction_ensemble := prediction]
  z[substr(row_id, 1, 1) == "M", prediction_ensemble := prediction]
  if (spec$b == "new") z[substr(row_id, 1, 1) == "B", prediction_ensemble := i.prediction]
  if (spec$c == "new") z[substr(row_id, 1, 1) == "C", prediction_ensemble := i.prediction]
  out <- z[, .(row_id, prediction = prediction_ensemble)]
  f <- file.path("week2/output/submission", paste0("submission_20261028_week2_optionB_", spec$tag, ".csv"))
  fwrite(out, f, scipen = 50)
  writeLines(paste(unname(tools::md5sum(f)), basename(f)), paste0(f, ".md5"))
  cat(spec$tag, unname(tools::md5sum(f)), nrow(out), "\n")
}
