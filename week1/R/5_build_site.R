# 5_build_site.R -------------------------------------------------------------
# Collects every markdown file (README, docs, handover, step reports) into a Quarto website
# so all steps and their outputs can be browsed in one place.
# Run after the step scripts. Output: week1/output/site/index.html (staging files in week1/output/site_src/).
# Needs Quarto: on PATH, in env var QUARTO_PATH, or bundled with RStudio.

source("week1/R/0_setup.R")
SRC <- file.path(PATHS$output, "site_src")
SITE <- file.path(PATHS$output, "site")

find_quarto <- function() {
  candidates <- c(Sys.getenv("QUARTO_PATH"), Sys.which("quarto"),
                  "C:/Program Files/Quarto/bin/quarto.exe",
                  "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe",
                  "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto",
                  "/usr/local/bin/quarto", "/usr/lib/rstudio/resources/app/bin/quarto/bin/quarto")
  hit <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (length(hit) == 0) stop("Quarto not found. Install it from https://quarto.org or set QUARTO_PATH.")
  hit[1]
}

# Links between source files, rewritten to their location inside the site
LINK_MAP <- c("week1/docs/workflow.md" = "workflow.md", "../kaggle_iaa_2026_handover.md" = "handover.md",
              "week1/kaggle_iaa_2026_handover.md" = "handover.md", "../../README.md" = "index.md")

# Copy a markdown file, turning its first "# " heading into the Quarto page title
add_page <- function(from, to, title = NULL) {
  lines <- readLines(from, warn = FALSE, encoding = "UTF-8")
  h1 <- which(startsWith(lines, "# "))[1]
  if (!is.na(h1)) {
    if (is.null(title)) title <- sub("^# ", "", lines[h1])
    lines <- lines[-h1]
  }
  for (k in names(LINK_MAP)) lines <- gsub(paste0("](", k), paste0("](", LINK_MAP[[k]]), lines, fixed = TRUE)
  dest <- file.path(SRC, to)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  writeLines(c("---", paste0('title: "', gsub('"', "'", title), '"'), "---", "", lines), dest, useBytes = TRUE)
  to
}

copy_pngs <- function(step, sub) {
  from <- file.path(PATHS$output, step, sub)
  if (!dir.exists(from)) return(invisible())
  dir.create(file.path(SRC, step), recursive = TRUE, showWarnings = FALSE)
  file.copy(from, file.path(SRC, step), recursive = TRUE)
}

# Gallery page for the ranked one-way plots of one line (step 5)
add_oneway_gallery <- function(ln) {
  pngs <- sort(list.files(file.path(PATHS$output, "3_incidence", paste0("oneway_", ln)), pattern = "\\.png$"))
  if (length(pngs) == 0) return(NULL)
  copy_pngs("3_incidence", paste0("oneway_", ln))
  body <- unlist(lapply(pngs, function(f) {
    c(paste0("## ", sub("\\.png$", "", f)), "", paste0("![](oneway_", ln, "/", f, "){width=90%}"), "")
  }))
  to <- file.path("3_incidence", paste0("oneway_", ln, ".md"))
  writeLines(c("---", paste0('title: "One-way plots - ', ln, '"'), "toc: true", "---", "",
               "Ranked by burn-cost spread (see the factor ranking in the incidence report).", "", body),
             file.path(SRC, to))
  to
}

# Extra pages listed in a step's pages.csv (column EDA: bottom of week1/R/1_eda.R and week1/R/2_clean.R), in the order the
# script wrote them, each with its plot folder of the same name
add_listed_pages <- function(step) {
  idx <- file.path(PATHS$output, step, "pages.csv")
  if (!file.exists(idx)) return(NULL)
  unlist(lapply(fread(idx)$page, function(pg) {
    src_md <- file.path(PATHS$output, step, paste0(pg, ".md"))
    if (!file.exists(src_md)) return(NULL)
    copy_pngs(step, pg)
    add_page(src_md, file.path(step, paste0(pg, ".md")))
  }))
}

# Submission log table from week1/docs/workflow.md (first table after the "## Submission log" heading)
read_submission_log <- function() {
  l <- readLines("week1/docs/workflow.md", warn = FALSE, encoding = "UTF-8")
  start <- which(l == "## Submission log")
  if (length(start) == 0) return(NULL)
  l <- l[(start + 1):length(l)]
  first <- which(startsWith(l, "|"))[1]
  if (is.na(first)) return(NULL)
  end <- which(!startsWith(l[first:length(l)], "|"))[1]
  tbl <- l[first:(if (is.na(end)) length(l) else first + end - 2)]
  cells <- lapply(tbl, function(r) trimws(strsplit(r, "|", fixed = TRUE)[[1]])[-1])
  log <- as.data.table(do.call(rbind, cells[-(1:2)]))
  setnames(log, cells[[1]][seq_len(ncol(log))])
  log
}

# Overview of all model iterations with local scores and the public scores logged for them
add_iterations <- function() {
  dirs <- sort(list.dirs("week1/models", recursive = FALSE))
  dirs <- dirs[file.exists(file.path(dirs, "model_card.md"))]
  if (length(dirs) == 0) return(NULL)
  cards <- vapply(dirs, function(d) {
    for (png in list.files(d, pattern = "\\.png$", full.names = TRUE)) {
      dir.create(file.path(SRC, "4_models", basename(d)), recursive = TRUE, showWarnings = FALSE)
      file.copy(png, file.path(SRC, "4_models", basename(d)))
    }
    add_page(file.path(d, "model_card.md"), file.path("4_models", basename(d), "model_card.md"))
  }, character(1))
  # iteration is a label: a number (1, 2) or a named iteration such as "WENDY 3"
  summ <- rbindlist(lapply(dirs, function(d) {
    fread(file.path(d, "summary.csv"), colClasses = list(character = c("iteration", "run_id")))
  }), fill = TRUE)
  summ[, card := sprintf("[%s](%s/model_card.md)",
                         ifelse(grepl("^[0-9]+$", iteration), paste("Iteration", iteration), iteration), basename(dirs))]
  log <- read_submission_log()
  if (!is.null(log) && "Iteration" %in% names(log)) {
    pub <- log[, .(submissions = paste0("#", `#`, collapse = ", "),
                   public_d2 = paste(`Public D²`, collapse = ", ")), by = .(iteration = toupper(trimws(Iteration)))]
    summ[, iteration := toupper(trimws(iteration))]
    summ <- merge(summ, pub, by = "iteration", all.x = TRUE)
  }
  cols <- intersect(c("card", "run_id", "git_commit", "models", "local_d2_2023", "local_d2_2024", "by_line_2023_2024",
                      "submissions", "public_d2"), names(summ))
  writeLines(c("---", 'title: "Model iterations"', "---", "",
               "One model card per iteration (`week1/models/<iteration>/`, written by `week1/R/4_models_iterXX.R`). Local D² is the",
               "Kaggle metric on our own validation years; public D² comes from the submission log in the workflow page.",
               "Higher is better for both.", "",
               md_table(summ[order(run_id, decreasing = TRUE), ..cols], 4)),
             file.path(SRC, "4_models", "iterations.md"))
  c("4_models/iterations.md", cards)
}

# 1. Stage pages --------------------------------------------------------------------------
unlink(SRC, recursive = TRUE)
dir.create(SRC, recursive = TRUE)

home <- add_page("README.md", "index.md")
general <- c(add_page("week1/docs/workflow.md", "workflow.md"),
             add_page("week1/kaggle_iaa_2026_handover.md", "handover.md"))

steps <- list(
  list(section = "Step 3 - Quick EDA", dir = "1_eda", report = "eda_report.md", script = "week1/R/1_eda.R"),
  list(section = "Step 3 - Column EDA (raw)", dir = "1_1_eda", report = "column_eda_report.md", script = "week1/R/1_eda.R"),
  list(section = "Step 4 - Cleaning", dir = "2_clean", report = "cleaning_report.md", script = "week1/R/2_clean.R"),
  list(section = "Step 4 - Column plots after cleaning", dir = "2_1_clean_eda", report = "clean_eda_report.md",
       script = "week1/R/2_clean.R"),
  list(section = "Step 5 - Incidence", dir = "3_incidence", report = "incidence_report.md", script = "week1/R/3_incidence.R"),
  list(section = "Step 6 - Model iterations", dir = "4_models", report = "model_report.md", script = "week1/R/4_models_iterXX.R")
)
sidebar <- c("    - section: \"Overview\"", "      contents:",
             paste0("        - ", c(home, general)))
skipped <- character(0)
for (s in steps) {
  src_md <- file.path(PATHS$output, s$dir, s$report)
  # Model cards are tracked in git (week1/models/), so they are shown even without a local run of week1/R/4_models_iterXX.R
  pages <- if (s$dir == "4_models") add_iterations() else NULL
  if (file.exists(src_md)) {
    pages <- c(add_page(src_md, file.path(s$dir, s$report)), pages)
    copy_pngs(s$dir, "plots")
    pages <- c(pages, add_listed_pages(s$dir))
    if (s$dir == "3_incidence") pages <- c(pages, unlist(lapply(LINES, add_oneway_gallery)))
  } else {
    skipped <- c(skipped, sprintf("%s - %s not found, run %s", s$section, src_md, s$script))
  }
  if (length(pages) == 0) next
  sidebar <- c(sidebar, paste0("    - section: \"", s$section, "\""), "      contents:",
               paste0("        - ", gsub("\\\\", "/", pages)))
}

writeLines(c(
  "project:", "  type: website", "  output-dir: ../site", "",
  "website:",
  "  title: \"IAA Hackathon 2026\"",
  paste0("  page-footer: \"Built ", format(Sys.time(), "%Y-%m-%d %H:%M"), " by week1/R/5_build_site.R\""),
  "  sidebar:", "    style: docked", "    search: true", "    contents:", sidebar, "",
  "format:", "  html:", "    theme: cosmo", "    css: styles.css", "    toc: true", "    toc-depth: 3",
  "    fig-align: center", "    page-layout: full"
), file.path(SRC, "_quarto.yml"))

# Wide or long tables scroll inside their own box instead of overflowing the page
writeLines(c(
  "main table {",
  "  display: block; width: max-content; max-width: 100%; max-height: 70vh;",
  "  overflow: auto; font-size: 0.85rem; border: 1px solid #dee2e6;",
  "}",
  "main table th, main table td { padding: 0.25rem 0.6rem; vertical-align: top; }",
  "main table td { max-width: 45ch; overflow-wrap: break-word; }",
  "main table thead th { position: sticky; top: 0; z-index: 1; background: #f8f9fa; white-space: nowrap; }",
  "main img { max-width: 100%; height: auto; }"
), file.path(SRC, "styles.css"))
log_msg("Staged site sources in ", SRC)

# 2. Render ------------------------------------------------------------------------------------
quarto <- find_quarto()
log_msg("Rendering with ", quarto)
old_wd <- setwd(SRC)
status <- system2(quarto, c("render", "--quiet"))
setwd(old_wd)
if (status != 0) stop("Quarto render failed (exit code ", status, ").")
log_msg("Done. Open ", normalizePath(file.path(SITE, "index.html")))
if (length(skipped) > 0) {
  warning("The site is missing ", length(skipped), " step report(s); run the scripts in order, then rebuild:\n  ",
          paste(skipped, collapse = "\n  "), call. = FALSE)
}
