# 00_setup_week2.R -------------------------------------------------------------
# Purpose : Shared configuration for every week 2 (emerging market, Option B) script: paths, constants, seeds,
#           logging to week2/run/, MD5 helper, step-log / decision-register / assumptions helpers, Tweedie D2.
#           Separate from the week 1 week1/R/0_setup.R (not changed). md_table()/fmt_num() copied from week1/R/0_setup.R.
# Inputs  : none (sourced by every week 2 script)
# Outputs : week2/run/session_info.txt (rewritten at each step), week2/run/status.log (start/end lines),
#           week2/run/logs/<script>.log
# Run     : Rscript week2/R/00_setup_week2.R   (from the repo root; also sourced by every week 2 script)
# Time    : < 5 seconds

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
})
if (!all(dir.exists(c("week2", "data/week_1/raw data", "data/week_2/raw data/emerging")))) {
  stop("Run from the repo root (the folder containing week2/, data/week_1/raw data/ and data/week_2/raw data/emerging/).")
}

# Paths and constants ---------------------------------------------------------------
W2 <- list(
  dev_raw = "data/week_1/raw data",
  em_raw  = "data/week_2/raw data/emerging",
  data    = "data/week_2/optionB",
  clean   = "data/week_2/optionB/clean",
  output  = "week2/output",
  models  = "week2/models",
  run     = "week2/run",
  docs    = "week2/docs/optionB",
  inputs  = "week2/inputs"
)
# Optional redirects (week 1 re-tune chain runs): write outputs and docs elsewhere; unset = unchanged behaviour
if (nzchar(Sys.getenv("OUT_ROOT"))) W2$output <- Sys.getenv("OUT_ROOT")
if (nzchar(Sys.getenv("DOCS_ROOT"))) W2$docs <- Sys.getenv("DOCS_ROOT")
for (d in W2[c("data", "clean", "output", "models", "run", "docs", "inputs")]) dir.create(d, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(W2$run, "logs"), showWarnings = FALSE)

LINES <- c("motor", "buildings", "contents")
PERILS <- list(
  motor     = c("own_damage", "third_party_prop", "bodily_injury", "theft", "glass_hail"),
  buildings = c("storm", "flood", "escape_of_water", "subsidence", "fire", "accidental_damage"),
  contents  = c("theft", "escape_of_water", "accidental_damage", "flood")
)
BASE_TAG <- Sys.getenv("BASE_TAG", "baseline")   # which step 5 baseline run (data/week_2/optionB/<BASE_TAG>/) later steps read
BASE_DIR <- Sys.getenv("BASE_DIR", W2$data)      # folder holding <BASE_TAG>/; data/week_2/week1_retune for the week 1 re-tune baselines
BASE_DIAG_DIR <- Sys.getenv("BASE_DIAG_DIR", "")  # folder holding the baseline's diagnostics_final.csv (default: week2/output/05_<tag>)
VALUATION_DATE <- as.Date("2024-12-31")
DAYS_PER_YEAR <- 365
TWEEDIE_P <- 1.5
SEED <- 2026
AGE_BANDS <- c("17-24", "25-34", "35-49", "50-64", "65+")
WEATHER_VARS <- c("hail_days", "wind_exposure_index", "freezing_days", "dry_summer_index", "wildfire_index",
                  "rainfall_mm", "mean_temperature_c")
# Never features (week 1 guardrails + week 2 defaults). gender excluded until Wendy approves (decision D002).
EXCLUDED_ALWAYS <- c("compulsory_excess", "written_premium", "customer_service_contacts", "renewal_decision",
                     "email_domain", "branch_id", "campaign_code", "marketing_segment", "vehicle_colour",
                     "marketing_consent", "document_preference", "surname", "gender", "noise_probe")

set.seed(SEED)
setDTthreads(as.integer(Sys.getenv("DT_THREADS", "0")))   # DT_THREADS=1 when another fit is running (thread contention)

# Logging ------------------------------------------------------------------------------
.W2_STATE <- new.env()
ts_sgt <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S SGT", tz = "Asia/Singapore")

start_script <- function(script) {
  .W2_STATE$script <- script
  .W2_STATE$t0 <- Sys.time()
  .W2_STATE$log <- file.path(W2$run, "logs", paste0(sub("\\.R$", "", script), ".log"))
  .W2_STATE$inputs <- character(0)
  .W2_STATE$outputs <- character(0)
  writeLines(paste(ts_sgt(), "| start", script), .W2_STATE$log)
  cat(paste(ts_sgt(), "| START", script), "\n", file = file.path(W2$run, "status.log"), append = TRUE)
  write_session_info()
  set.seed(SEED)
  invisible(NULL)
}

log_msg <- function(...) {
  line <- paste0(format(Sys.time(), "%H:%M:%S"), " | ", ...)
  message(line)
  if (!is.null(.W2_STATE$log)) cat(line, "\n", file = .W2_STATE$log, append = TRUE)
}

end_script <- function() {
  mins <- as.numeric(difftime(Sys.time(), .W2_STATE$t0, units = "mins"))
  log_msg(sprintf("end %s, run time %.1f min", .W2_STATE$script, mins))
  cat(paste(ts_sgt(), "| END  ", .W2_STATE$script, sprintf("(%.1f min)", mins)), "\n",
      file = file.path(W2$run, "status.log"), append = TRUE)
  invisible(mins)
}

write_session_info <- function() {
  si <- capture.output(sessionInfo())
  pk <- c("data.table", "arrow", "xgboost", "lightgbm", "readxl", "openxlsx", "mgcv")
  ver <- vapply(pk, function(p) if (requireNamespace(p, quietly = TRUE)) as.character(packageVersion(p)) else "missing", "")
  writeLines(c(paste("Written", ts_sgt(), "by", if (is.null(.W2_STATE$script)) "00_setup_week2.R" else .W2_STATE$script),
               "", "Package versions:", paste0("  ", pk, " ", ver), "", si), file.path(W2$run, "session_info.txt"))
}

# MD5 ----------------------------------------------------------------------------------------
md5_table <- function(paths) {
  paths <- unique(paths[file.exists(paths)])
  if (!length(paths)) return(data.table(file = character(), bytes = numeric(), md5 = character()))
  data.table(file = paths, bytes = file.size(paths), md5 = unname(tools::md5sum(paths)))
}
track_input <- function(path) { .W2_STATE$inputs <- c(.W2_STATE$inputs, path); invisible(path) }
track_output <- function(path) { .W2_STATE$outputs <- c(.W2_STATE$outputs, path); invisible(path) }

# IO ------------------------------------------------------------------------------------------
read_dev <- function(name) { f <- file.path(W2$dev_raw, paste0(name, ".parquet")); track_input(f); as.data.table(read_parquet(f)) }
read_em  <- function(name) { f <- file.path(W2$em_raw, paste0(name, ".parquet")); track_input(f); as.data.table(read_parquet(f)) }
read_w2 <- function(path) { track_input(path); as.data.table(read_parquet(path)) }
write_w2 <- function(dt, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write_parquet(dt, path); track_output(path); invisible(path)
}
out_path <- function(step, file) {
  p <- file.path(W2$output, step, file); dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE); p
}
save_csv <- function(dt, step, file) { p <- out_path(step, file); fwrite(dt, p); track_output(p); invisible(p) }
write_md <- function(lines, step, file) { p <- out_path(step, file); writeLines(unlist(lines), p); track_output(p); invisible(p) }

# Markdown helpers (copied from week1/R/0_setup.R) ----------------------------------------------------
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

# Step log: an auto block per script between markers (replaced on re-run). Decision text is written by hand
# outside the markers.
update_step_log <- function(step, title, key_lines = character(0)) {
  f <- file.path(W2$docs, "step_log.md")
  if (!file.exists(f)) writeLines(c("# Week 2 step log (emerging market, Option B)", "",
                                    "One section per step. The `auto` blocks are written by the scripts (inputs and outputs with MD5,",
                                    "run time, key numbers); the decision text around them is written by hand.", ""), f)
  txt <- readLines(f)
  mins <- as.numeric(difftime(Sys.time(), .W2_STATE$t0, units = "mins"))
  io <- function(paths) { m <- md5_table(paths); if (!nrow(m)) return("(none)"); md_table(m[, .(file, bytes, md5)]) }
  block <- c(sprintf("<!-- auto:%s start -->", step),
             sprintf("**Script** `week2/R/%s` · **run** %s · **run time** %.1f min", .W2_STATE$script, ts_sgt(), mins), "",
             "**Inputs**", "", io(.W2_STATE$inputs), "**Outputs**", "", io(.W2_STATE$outputs),
             if (length(key_lines)) c("**Key numbers (from the script)**", "", key_lines, "") else character(0),
             sprintf("<!-- auto:%s end -->", step))
  s <- grep(sprintf("<!-- auto:%s start -->", step), txt, fixed = TRUE)
  e <- grep(sprintf("<!-- auto:%s end -->", step), txt, fixed = TRUE)
  if (length(s) && length(e)) {
    txt <- c(txt[seq_len(s - 1)], block, txt[-seq_len(e)])
  } else {
    txt <- c(txt, sprintf("## Step %s: %s", step, title), "", block, "")
  }
  writeLines(txt, f)
}

# Decision register (CSV, upsert by id) -------------------------------------------------------------
add_decision <- function(id, step, decision, alternatives, evidence, status = "decided") {
  f <- file.path(W2$docs, "decision_register.csv")
  new <- data.table(id = id, date = format(Sys.Date()), step = as.character(step), decision = decision,
                    alternatives_considered = alternatives, evidence = evidence, status = status)
  old <- if (file.exists(f)) fread(f, colClasses = "character") else new[0]
  fwrite(rbind(old[id != new$id], new)[order(id)], f)
}

# Assumptions (CSV store + xlsx, upsert by id) ---------------------------------------------------------
add_assumption <- function(id, step, item, value, source, credibility = "", sensitivity = "", note = "") {
  f <- file.path(W2$docs, "assumptions_week2.csv")
  new <- data.table(id = id, step = as.character(step), item = item, value = as.character(value), source = source,
                    credibility_weight = as.character(credibility), sensitivity = sensitivity, note = note)
  old <- if (file.exists(f)) fread(f, colClasses = "character") else new[0]
  all <- rbind(old[id != new$id], new)[order(id)]
  fwrite(all, f)
  openxlsx::write.xlsx(list(Assumptions = all), file.path(W2$docs, "assumptions_week2.xlsx"), overwrite = TRUE)
}

# Claim basis as week 1 C5 (week1/R/4_models_iterwendy07.R section 1): cost = incurred - recoveries; open claims of perils
# with recoveries get the closed recovery ratio deducted; single claims limited at 2m; positive claims only.
OUTLIER_LIMIT <- 2e6
claim_basis <- function(market) {
  cm <- read_w2(file.path(W2$clean, sprintf("%s_claims_matched.parquet", market)))
  cl <- cm[counts == TRUE & !is.na(row_id)]
  cl[, cost := net_cost]
  rr <- cl[status == "closed", .(rr = sum(recoveries) / sum(incurred_to_date)), by = .(line, peril)][rr > 0]
  cl[rr, on = .(line, peril), rr := i.rr]
  cl[status == "open" & !is.na(rr) & recoveries == 0, cost := incurred_to_date * (1 - rr)]
  cl[, cost := pmin(pmax(cost, 0), OUTLIER_LIMIT)]
  cl[cost > 0, .(claim_id, row_id, line, peril, status, cost, loss_date, report_date,
                 loss_year = year(loss_date), lag = as.numeric(report_date - loss_date))]
}

# Reported share per row (IBNR), from the step 4 table week2/output/04_ibnr_trend/report_share_quarter.csv
# (one share per peril x loss quarter at the 31 Dec 2024 valuation). Row share = day-weighted mean over the
# quarters its period covers (up to the valuation date), as the week 1 C5 chain ladder (week1/R/4_models_iterwendy07.R).
MIN_SHARE <- 0.05
load_report_shares <- function(path = file.path(W2$output, "04_ibnr_trend", "report_share_quarter.csv")) {
  if (!file.exists(path)) stop("Missing ", path, " - run week2/R/04_ibnr_trend_week2.R first")
  track_input(path); fread(path)
}
row_report_share <- function(shares, ln, pr, period_start, period_end, col = "share") {
  sq <- shares[line == ln & peril == pr][order(q_start)]
  s <- as.numeric(as.Date(period_start)); e <- pmin(as.numeric(as.Date(period_end)), as.numeric(VALUATION_DATE))
  num <- den <- numeric(length(s))
  qs <- as.numeric(as.Date(sq$q_start)); qe <- as.numeric(as.Date(sq$q_end))
  for (q in seq_len(nrow(sq))) {
    ov <- pmax(0, pmin(e, qe[q]) - pmax(s, qs[q]) + 1)
    num <- num + ov * sq[[col]][q]; den <- den + ov
  }
  pmax(fifelse(den > 0, num / den, 1), MIN_SHARE)
}

# Scoring ----------------------------------------------------------------------------------------------
# Week 1 local protocol D2 (week1/R/oof_io.R oof_d2): baseline = one cost rate per exposure-year
d2_exp <- function(y, mu, e, w = rep(1, length(y))) {
  base <- e * sum(w * y) / sum(w * e)
  1 - sum(w * tweedie_dev(y, mu)) / sum(w * tweedie_dev(y, base))
}
tweedie_dev <- function(y, mu, p = TWEEDIE_P) {
  mu <- pmax(mu, 1e-10)
  2 * (pmax(y, 0)^(2 - p) / ((1 - p) * (2 - p)) - y * mu^(1 - p) / (1 - p) + mu^(2 - p) / (2 - p))
}
d2_tweedie <- function(y, mu, w = NULL, p = TWEEDIE_P) {
  if (is.null(w)) w <- rep(1, length(y))
  1 - sum(w * tweedie_dev(y, mu, p)) / sum(w * tweedie_dev(y, rep(weighted.mean(y, w), length(y)), p))
}

if (sys.nframe() == 0L) {
  start_script("00_setup_week2.R")
  # Step 0 decisions (methods and defaults fixed before any data work)
  add_decision("D001","0","Method = Option B: developed baseline on shared fields + credibility-shrunk emerging adjustments + 2025 loadings","Score emerging with week 1 models as-is (needs fields emerging lacks); emerging-only models (thin data)","week2/HANDOVER_week2_optionB.md section 3")
  add_decision("D002","0","gender excluded from all models (default until Wendy approves; regulatory question)","Use gender as a rating factor","handover section 6 Q1","open question for Wendy")
  add_decision("D003","0","reference_policies.parquet and expenses.parquet not used for modelling; at most an illustrative premium build-up","Use as extra training rows / loadings in the risk premium","handover section 2 (purpose not stated)","open question for Wendy")
  add_decision("D004","0","Ridge credibility in step 7 done by manual shrinkage (glmnet not installed; no installs allowed)","Install glmnet","week2/run/session_info.txt")
  add_decision("D005","0","Kaggle: no submission; candidate files only in week2/output/submission/","Submit","handover rule 5","open question for Wendy")
  update_step_log("0", "Setup (paths, logging, seeds, MD5, session info)", c("- R 4.6.1; data.table 1.18.6.1, arrow 25.0.1, xgboost 3.2.1.1, lightgbm 4.7.0, readxl 1.6.0, openxlsx 4.2.9, mgcv 1.9.4; glmnet and writexl not installed.", "- Seed 2026; valuation date 2024-12-31 (latest emerging report date is 2024-12-30)."))
  log_msg("setup OK; session info written to ", file.path(W2$run, "session_info.txt"))
  end_script()
}

# X20 trend variants (26 Oct 2026), applied in steps 7 and 8 before the X18 motor floor. TREND_MODE:
#   chosen (default, step 4 judgement) | blend_freq (frequency = step 4 credibility blend of developed and emerging, every peril)
#   | line_sev (one severity trend per line: developed-claim-weighted mean of the chosen severity trends)
trend_mode <- function(trend, mode = Sys.getenv("TREND_MODE", "chosen")) {
  if (mode == "blend_freq") trend[, freq_trend_chosen := freq_trend_blend]
  if (mode == "line_sev") trend[, sev_trend_chosen := sum(dev_claims * sev_trend_chosen) / sum(dev_claims), by = line]
  trend
}
