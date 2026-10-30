# 0_setup_w2.R ---------------------------------------------------------------------------------------------------
# Week 2 (Part 2, the emerging market): shared paths, constants and helpers. Sourced by every week 2 script.
# Kept separate from week 1 (week1/R/0_setup.R): week 2 reads data/week_2/, writes data/week_2/clean/ and week2/output/.
# Run every week 2 script from the project root, e.g.  Rscript week2/R/1_checks_w2.R

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
})
if (!dir.exists("week2") || !dir.exists("data")) stop("Run from the project root (the folder containing week2/ and data/).")

PATHS_W2 <- list(
  raw_e  = file.path("data", "week_2", "raw data", "emerging"),    # Part 2 market: predict its 2025 test rows
  raw_d  = file.path("data", "week_2", "raw data", "developed"),   # Part 1 market, for reference (= data/week_1/raw data)
  week1  = file.path("data", "week_1", "raw data"),
  clean  = file.path("data", "week_2", "clean"),
  output = file.path("week2", "output")
)
LINES <- c("motor", "buildings", "contents")
PERILS <- list(
  motor     = c("own_damage", "third_party_prop", "bodily_injury", "theft", "glass_hail"),
  buildings = c("storm", "flood", "escape_of_water", "subsidence", "fire", "accidental_damage"),
  contents  = c("theft", "escape_of_water", "accidental_damage", "flood")
)
TRAIN_YEARS_E <- 2023:2024            # emerging-market training policy years
TRAIN_YEARS_D <- 2021:2024            # developed-market training policy years
VALUATION_DATE <- as.Date("2024-12-31")
DAYS_PER_YEAR <- 365
SI_CAP <- c(buildings = 5e6, contents = 2e6)   # sum insured above this and divisible by 1000 = unit error (week 1 rule)
WEATHER_VARS <- c("hail_days", "wind_exposure_index", "freezing_days", "dry_summer_index", "wildfire_index",
                  "rainfall_mm", "mean_temperature_c")
CONSTRUCTION_MAP <- c(BRK = "brick", STN = "stone", WOD = "timber", MIX = "non_standard")   # emerging local codes
AGE_BANDS <- c("17-24", "25-34", "35-49", "50-64", "65+")
SEED <- 2026
set.seed(SEED)
setDTthreads(0)

# IO -------------------------------------------------------------------------------------------------------------
read_e <- function(name) as.data.table(read_parquet(file.path(PATHS_W2$raw_e, paste0(name, ".parquet"))))
read_d <- function(name) as.data.table(read_parquet(file.path(PATHS_W2$raw_d, paste0(name, ".parquet"))))
read_clean_w2 <- function(name) {
  f <- file.path(PATHS_W2$clean, paste0(name, ".parquet"))
  if (!file.exists(f)) stop("Missing ", f, " - run week2/R/2_clean_w2.R first.")
  as.data.table(read_parquet(f))
}
write_clean_w2 <- function(dt, name) {
  dir.create(PATHS_W2$clean, recursive = TRUE, showWarnings = FALSE)
  write_parquet(dt, file.path(PATHS_W2$clean, paste0(name, ".parquet")))
}
out_w2 <- function(step, file) {
  path <- file.path(PATHS_W2$output, step, file)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  path
}
save_csv_w2 <- function(dt, step, file) fwrite(dt, out_w2(step, file))
write_md_w2 <- function(lines, step, file) writeLines(unlist(lines), out_w2(step, file))
log_msg <- function(...) message(format(Sys.time(), "%H:%M:%S"), " | ", ...)

# Check register: every check is one row (dataset, check, n, share, severity, action) ------------------------------
new_checks <- function() { env <- new.env(); env$rows <- list(); env }
add_check <- function(reg, dataset, check, n, total = NA_real_, action = "", severity = c("info", "fixed", "issue")) {
  severity <- match.arg(severity)
  reg$rows[[length(reg$rows) + 1]] <- data.table(dataset = dataset, check = check, n = as.numeric(n),
                                                 share = if (is.na(total) || total == 0) NA_real_ else n / total,
                                                 severity = severity, action = action)
  invisible(n)
}
checks_table <- function(reg) rbindlist(reg$rows)

# Data helpers ---------------------------------------------------------------------------------------------------
pad_id <- function(x, width = 8) {
  short <- !is.na(x) & nchar(x) < width
  x[short] <- paste0(strrep("0", width - nchar(x[short])), x[short])
  x
}
row_days <- function(dt) as.numeric(dt$period_end - dt$period_start) + 1
# occupation is free text in the emerging market: lower-case, trimmed, single spaces; "self-employed <job>" split off
clean_occupation <- function(x) {
  x <- tolower(gsub("\\s+", " ", trimws(x)))
  se <- !is.na(x) & grepl("^self[- ]?employed", x)
  base <- trimws(sub("^self[- ]?employed[ :,-]*", "", x))
  base[se & base == ""] <- NA_character_
  list(occupation = base, self_employed = se)
}

# Reported share of a row's claims at the valuation date: mean over 16 points of the row of F(valuation - t), floored.
# F = P(report lag <= x days), x = 0..length(F)-1 (report_lag_curves.parquet from 3_ibnr_w2.R)
SHARE_FLOOR <- 0.05
row_share <- function(F, ps, pe, val = VALUATION_DATE, floor = SHARE_FLOOR) {
  s <- as.numeric(ps); e <- as.numeric(pe); v <- as.numeric(val); acc <- numeric(length(s))
  for (q in (0:15 + 0.5) / 16) { d <- as.integer(floor(v - (s + (e - s) * q))); acc <- acc + ifelse(d < 0, 0, F[pmin(d, length(F) - 1L) + 1L]) }
  pmax(acc / 16, floor)
}
# Tweedie D2 (p = 1.5), the Kaggle metric; null model = exposure-proportional
tweedie_dev <- function(y, mu, p = 1.5) { mu <- pmax(mu, 1e-9); 2 * sum(ifelse(y > 0, y^(2 - p) / ((1 - p) * (2 - p)), 0) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p)) }
d2_tweedie <- function(y, mu, e) 1 - tweedie_dev(y, mu) / tweedie_dev(y, e * sum(y) / sum(e))

# Markdown helpers -----------------------------------------------------------------------------------------------
fmt_num <- function(x, digits = 3) {
  out <- ifelse(abs(x - round(x)) < 1e-9 & abs(x) < 1e15, formatC(round(x), format = "d", big.mark = ","),
                formatC(x, format = "f", digits = digits, big.mark = ","))
  out[is.na(x)] <- ""
  out
}
md_table <- function(df, digits = 3) {
  df <- as.data.frame(df)
  if (!nrow(df)) return(c("(none)", ""))
  cols <- Map(function(x, nm) if (is.numeric(x) && !grepl("year", nm)) fmt_num(x, digits) else as.character(x), df, names(df))
  rows <- do.call(paste, c(cols, sep = " | "))
  c(paste0("| ", paste(names(df), collapse = " | "), " |"), paste0("|", strrep("---|", ncol(df))), paste0("| ", rows, " |"), "")
}
