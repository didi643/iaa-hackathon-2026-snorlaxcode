# 8_render_report_w2.R -------------------------------------------------------------------------------------------
# Renders week2/reports/market_comparison_w2.Rmd -> week2/reports/market_comparison_w2.html (self-contained).
# rmarkdown is not in the project's renv library (CRAN is blocked by the proxy), so the personal R library is added;
# pandoc comes with RStudio.
# Run:  Rscript week2/R/8_render_report_w2.R

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", paste(R.version$major, sub("\\..*", "", R.version$minor), sep = "."))
.libPaths(unique(c(.libPaths(), user_lib)))
if (!nzchar(Sys.getenv("RSTUDIO_PANDOC"))) Sys.setenv(RSTUDIO_PANDOC = "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools")
stopifnot(requireNamespace("rmarkdown", quietly = TRUE), rmarkdown::pandoc_available())
rmarkdown::render("week2/reports/market_comparison_w2.Rmd", output_dir = "week2/reports", knit_root_dir = getwd(),
                  intermediates_dir = tempdir(), quiet = TRUE)
message("Report: week2/reports/market_comparison_w2.html")
