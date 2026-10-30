# verify_final_files.R ---------------------------------------------------------------------------------------------
# One-command check of the two final prediction files. Run from the repo root.
#   Rscript verify_final_files.R            # 1. fingerprint (MD5) and format check of final_files/ : seconds, no data needed
#   Rscript verify_final_files.R rebuild    # 2. also rebuild both final files from the saved model outputs and compare:
#                                           #    about a minute; no Kaggle data needed
# Needs the R packages data.table and arrow only.

suppressMessages({library(data.table); library(arrow)})
REBUILD <- "rebuild" %in% commandArgs(TRUE)
stopifnot("Run from the repo root" = dir.exists("final_files"))

expected <- data.table(
  file = c("final_files/week1_submission_20261023_1636_w9_motor2_pre_m0.5.csv",
           "final_files/week2_submission_20261030_0905_week2_motorlevel_l_full.csv",
           "final_files/week2_fallback_submission_20261028_week2_optionB_line_ensemble.csv"),
  what = c("Week 1 final (public 0.12965, private 0.13923)",
           "Week 2 final #31 motorlevel_l_full (public 0.16840)",
           "Week 2 fallback #12 line_ensemble, pre-probing model (public 0.16690)"),
  rows = c(626639L, 209063L, 209063L),
  md5 = c("148a9f430289965107f40175dd2953ca", "90120c605cee98bb3545e0b7b4b9a128", "bbd5ca2dbe6327161d93dad5dc36edbd"))

cat("\n1. Final files: fingerprint and format\n")
ok_all <- TRUE
for (i in seq_len(nrow(expected))) {
  e <- expected[i]
  x <- fread(e$file, colClasses = list(character = "row_id"))
  md5 <- unname(tools::md5sum(e$file))
  ok <- c(md5 = md5 == e$md5, header = identical(names(x), c("row_id", "prediction")), rows = nrow(x) == e$rows,
          unique = !anyDuplicated(x$row_id), not_negative = all(x$prediction >= 0), no_missing = !anyNA(x$prediction))
  ok_all <- ok_all && all(ok)
  cat(sprintf("   %-4s %s\n        %s | rows %s | MD5 %s%s\n", if (all(ok)) "OK" else "FAIL", e$what, basename(e$file),
              format(nrow(x), big.mark = ","), md5, if (all(ok)) "" else paste0(" | failed: ", paste(names(ok)[!ok], collapse = ", "))))
}
if (!ok_all) stop("A final file does not match its fingerprint or format. If git changed line endings, see README (Troubleshooting).")

if (!REBUILD) {
  cat("\nAll final files match. Add 'rebuild' to also rebuild them from the saved model outputs.\n")
  quit(save = "no")
}

rscript <- file.path(R.home("bin"), "Rscript")
# Run a script in a fresh R session with extra environment variables. The child uses the same packages as this
# session (R_LIBS) and skips .Rprofile (--vanilla), so renv cannot hide them.
run_child <- function(script, vars = character()) {
  vars <- c(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep), vars)
  old <- Sys.getenv(names(vars), unset = NA, names = TRUE)
  do.call(Sys.setenv, as.list(vars))
  on.exit(for (k in names(old)) if (is.na(old[[k]])) Sys.unsetenv(k) else do.call(Sys.setenv, setNames(list(old[[k]]), k)))
  system2(rscript, c("--vanilla", shQuote(script)))
}

cat("\n2a. Week 1: rebuild the final file from the frozen model components (week1/docs/handover_final/replicate)\n")
code <- run_child("week1/docs/handover_final/replicate/replicate_final_submission.R")
if (code != 0) stop("Week 1 rebuild failed")

cat("\n2b. Week 2: rebuild #12 and the final #31 from the two cached components (week2/R/30_final_from_components.R)\n")
code <- run_child("week2/R/30_final_from_components.R")
if (code != 0) stop("Week 2 rebuild failed")
for (k in list(c("line_ensemble_12", "line_ensemble"), c("motorlevel_l_full_31", "motorlevel_l_full"))) {
  out <- file.path("week2/output/final_rebuild", paste0("submission_week2_", k[1], ".csv"))
  md5 <- unname(tools::md5sum(out))
  want <- expected[grepl(k[2], file), md5]
  cat(sprintf("   %-4s %s, MD5 %s\n", if (md5 == want) "OK" else "FAIL", basename(out), md5))
  if (md5 != want) stop("Week 2 rebuild of ", k[2], " does not match the final file")
}
cat("\nAll rebuilds match the final files byte for byte.\n")
