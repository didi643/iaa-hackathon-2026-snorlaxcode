# 0_setup.R ------------------------------------------------------------------
# Shared configuration and helpers. Sourced at the top of every numbered script.
# Run all scripts from the project root, e.g. Rscript week1/R/1_eda.R

required_pkgs <- c("arrow", "data.table", "ggplot2", "scales", "lightgbm")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop("Missing R packages: ", paste(missing_pkgs, collapse = ", "),
       "\nInstall with: install.packages(c(", paste0('"', missing_pkgs, '"', collapse = ", "), "))")
}
suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(ggplot2)
  library(lightgbm)
})

if (!all(dir.exists(c("week1", "data")))) {
  stop("Set the working directory to the project root (the folder containing week1/ and data/).")
}

# Paths and constants ----------------------------------------------------------
PATHS <- list(raw = "data/week_1/raw data", clean = "data/week_1/clean", output = "week1/output")
LINES <- c("motor", "buildings", "contents")
PERILS <- list(
  motor     = c("own_damage", "third_party_prop", "bodily_injury", "theft", "glass_hail"),
  buildings = c("storm", "flood", "escape_of_water", "subsidence", "fire", "accidental_damage"),
  contents  = c("theft", "escape_of_water", "accidental_damage", "flood")
)
VALUATION_DATE <- as.Date("2024-12-31")
DAYS_PER_YEAR <- 365
TRAIN_YEARS <- 2021:2024
LARGE_LOSS_QUANTILE <- 0.999   # row-level cap applied to positive row costs per line
TWEEDIE_P <- 1.5
SEED <- 2026

set.seed(SEED)
setDTthreads(0)
theme_set(theme_minimal(base_size = 11))

# Never used as model features: identifiers, raw dates, leakage, anonymised names.
# customer_service_contacts: ~3 per row with a claim vs ~0.4 without, and test matches no-claim rows (leakage).
NON_FEATURES <- c("row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end",
                  "exposure", "exposure_raw", "renewal_decision", "surname", "date_of_birth",
                  "policy_year", "customer_service_contacts")

# Derived in week1/R/2_clean.R from BEN 1 on. Only returned when asked for, so iterations 1-2 keep their features.
WEATHER_VARS <- c("hail_days", "wind_exposure_index", "freezing_days", "dry_summer_index", "wildfire_index",
                  "rainfall_mm", "mean_temperature_c")
NEW_FEATURES <- c("premium_index", paste0("wx_avg_", WEATHER_VARS))

feature_cols <- function(dt, include_new = FALSE) {
  nm <- names(dt)
  nm[!nm %in% NON_FEATURES & !startsWith(nm, "y_") & !startsWith(nm, "flag_") &
       (include_new | !nm %in% NEW_FEATURES)]
}

# IO helpers -----------------------------------------------------------------------
read_raw <- function(name) as.data.table(read_parquet(file.path(PATHS$raw, paste0(name, ".parquet"))))

read_clean <- function(name) {
  f <- file.path(PATHS$clean, paste0(name, ".parquet"))
  if (!file.exists(f)) stop("Missing ", f, " - run week1/R/2_clean.R first.")
  as.data.table(read_parquet(f))
}

write_clean <- function(dt, name) {
  dir.create(PATHS$clean, recursive = TRUE, showWarnings = FALSE)
  write_parquet(dt, file.path(PATHS$clean, paste0(name, ".parquet")))
}

out_file <- function(step, file) {
  path <- file.path(PATHS$output, step, file)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  path
}

save_csv <- function(dt, step, file) fwrite(dt, out_file(step, file))

save_plot <- function(p, step, file, width = 9, height = 5.5) {
  ggsave(out_file(step, file), p, width = width, height = height, dpi = 110, bg = "white")
}

log_msg <- function(...) message(format(Sys.time(), "%H:%M:%S"), " | ", ...)

# Data helpers --------------------------------------------------------------------
pad_id <- function(x, width = 8) {
  short <- !is.na(x) & nchar(x) < width
  x[short] <- paste0(strrep("0", width - nchar(x[short])), x[short])
  x
}

# Markdown report helpers -----------------------------------------------------------
fmt_num <- function(x, digits = 3) {
  out <- ifelse(abs(x - round(x)) < 1e-9 & abs(x) < 1e15,
                formatC(round(x), format = "d", big.mark = ","),
                formatC(x, format = "f", digits = digits, big.mark = ","))
  out[is.na(x)] <- ""
  out
}

md_table <- function(df, digits = 3) {
  df <- as.data.frame(df)
  cols <- Map(function(x, nm) if (is.numeric(x) && !grepl("year", nm)) fmt_num(x, digits) else as.character(x),
              df, names(df))
  rows <- do.call(paste, c(cols, sep = " | "))
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", strrep("---|", ncol(df))),
    paste0("| ", rows, " |"), "")
}

write_md <- function(lines, step, file) writeLines(unlist(lines), out_file(step, file))
