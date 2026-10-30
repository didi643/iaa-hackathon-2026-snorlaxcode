# r05_retune_baseline.R ----------------------------------------------------------------------------------------
# Purpose : Week 1 re-tune for week 2. COPY of week2/R/05_developed_baseline.R with every output redirected to
#           week2/week1_retune/ and data/week_2/week1_retune/, plus experiment switches (all default to the week 2 baseline
#           behaviour). Never reads or writes week1/ (the week 1 workbook was copied once into week1_retune/inputs/).
#           Plan: week2/week1_retune/docs/retune_plan.md. Register: week2/week1_retune/docs/retune_register.csv.
# Switches (env): RUN_TAG (required), BAGS, FAST, SKIP_VALID, LINES_ONLY=motor,buildings,contents, SEED_OFFSET,
#           FEATURE_ADD=col1,col2 (developed-only fields put back: info runs only), FEATURE_OFF_KEEP=all,
#           HP_DEPTH_ADD, HP_ETA_MULT, HP_MCW_MULT, HP_REG_LAMBDA, HP_COLSAMPLE, HP_SUBSAMPLE, MONO_OFF=1, AGE_BAND_ORD=1,
#           LOC_ALL=1, PROXY=mileage,credit,age, TRAIN_FROM=<year>, YEAR_WEIGHTS=w21,w22,w23,w24, DOMAIN_W=1,
#           SPEC_OVERRIDE=<csv: line,peril,param,value> (Model_Spec and per-peril xgboost params; used by B4 and the tuning)
# Hand-off: data/week_2/week1_retune/<tag>/baseline_emerging_{train,test}.parquet, read by week 2 steps 06-09 with
#           BASE_DIR=data/week_2/week1_retune BASE_TAG=<tag>.
# Run     : RUN_TAG=b0_ref BAGS=1 Rscript week2/week1_retune/R/r05_retune_baseline.R   (from the repo root)

source("week2/R/00_setup_week2.R")
RT <- list(root = "week2/week1_retune", data = "data/week_2/week1_retune")
W2$run <- file.path(RT$root, "run"); W2$docs <- file.path(RT$root, "docs")
dir.create(file.path(W2$run, "logs"), recursive = TRUE, showWarnings = FALSE)
RUN_TAG <- Sys.getenv("RUN_TAG"); if (!nzchar(RUN_TAG) || RUN_TAG %in% c("baseline", "main")) stop("Set RUN_TAG to a new retune tag (not baseline / main)")
start_script(paste0("r05_retune_baseline_", RUN_TAG, ".R"))
for (p in c("xgboost", "readxl", "openxlsx")) if (!requireNamespace(p, quietly = TRUE)) stop("Missing package '", p, "'")
suppressPackageStartupMessages({ library(xgboost); library(readxl) })
STEP <- RUN_TAG
FAST <- Sys.getenv("FAST", "0") == "1"
SKIP_VALID <- Sys.getenv("SKIP_VALID", "0") == "1"
SEED_OFFSET <- as.integer(Sys.getenv("SEED_OFFSET", "0"))
SEED <- SEED + SEED_OFFSET
FEAT_DIR <- file.path(W2$data, "features")      # read only
ITER_DIR <- file.path(RT$root, "models", RUN_TAG)
IS_MAIN <- FALSE
SRC_XLSX <- file.path(RT$root, "inputs", "assumptions_wendy07_final2_week1_copy.xlsx")
CFG_FILE <- file.path(RT$root, "inputs", paste0("assumptions_retune_", RUN_TAG, ".xlsx"))
T0 <- Sys.time()
env_num <- function(k, d) as.numeric(Sys.getenv(k, as.character(d)))
env_vec <- function(k) { v <- Sys.getenv(k, ""); if (nzchar(v)) trimws(strsplit(v, "[,;]")[[1]]) else character(0) }
HP <- list(depth_add = env_num("HP_DEPTH_ADD", 0), eta_mult = env_num("HP_ETA_MULT", 1), mcw_mult = env_num("HP_MCW_MULT", 1),
           reg_lambda = env_num("HP_REG_LAMBDA", NA), colsample = env_num("HP_COLSAMPLE", NA), subsample = env_num("HP_SUBSAMPLE", NA))
FEATURE_ADD <- env_vec("FEATURE_ADD"); FEATURE_OFF_KEEP_ALL <- Sys.getenv("FEATURE_OFF_KEEP", "") == "all"
MONO_OFF <- Sys.getenv("MONO_OFF", "0") == "1"; AGE_BAND_ORD <- Sys.getenv("AGE_BAND_ORD", "0") == "1"
LOC_ALL <- Sys.getenv("LOC_ALL", "0") == "1"; PROXY <- env_vec("PROXY")
TRAIN_FROM <- as.integer(Sys.getenv("TRAIN_FROM", "0")); YEAR_W <- as.numeric(env_vec("YEAR_WEIGHTS")); DOMAIN_W <- Sys.getenv("DOMAIN_W", "0") == "1"
LINES_ONLY <- env_vec("LINES_ONLY"); if (length(LINES_ONLY)) LINES <- intersect(LINES, LINES_ONLY)
SPEC_OV <- { f <- Sys.getenv("SPEC_OVERRIDE", ""); if (nzchar(f) && file.exists(f) && file.size(f) > 0) fread(f, colClasses = list(character = c("line", "peril", "param"))) else data.table(line = character(), peril = character(), param = character(), value = numeric()) }
log_msg("Retune run ", RUN_TAG, ": HP ", paste(names(HP), unlist(HP), sep = "=", collapse = " "), if (length(FEATURE_ADD)) paste("; FEATURE_ADD", paste(FEATURE_ADD, collapse = ",")) else "",
        if (nrow(SPEC_OV)) paste0("; SPEC_OVERRIDE ", nrow(SPEC_OV), " rows") else "")

# 0a. Build the workbook from the copied week 1 workbook (edits listed, so the copy is reproducible) ---------------------
track_input(SRC_XLSX)
FEATURE_RENAME <- c(driver_age = "driver_age_band", policyholder_age = "policyholder_age_band")
FEATURE_OFF <- c("region", "credit_band", "annual_mileage", "telematics_opt_in", "telematics_score", "compulsory_excess",
                 "customer_age", "written_premium", "customer_service_contacts", "gender")
if (FEATURE_OFF_KEEP_ALL) { FEATURE_OFF <- c("compulsory_excess", "customer_age", "written_premium", "customer_service_contacts", "gender"); FEATURE_RENAME <- character(0)
} else { FEATURE_OFF <- setdiff(FEATURE_OFF, FEATURE_ADD); FEATURE_RENAME <- FEATURE_RENAME[!names(FEATURE_RENAME) %in% FEATURE_ADD] }
INFO_ONLY <- FEATURE_OFF_KEEP_ALL || length(FEATURE_ADD) > 0   # developed-only fields cannot be applied to emerging: no final fit, no hand-off
SETTING_EDITS <- c(bags = Sys.getenv("BAGS", "5"), model_selection = "freq_sev", method_mix = "auto")
wb <- openxlsx::loadWorkbook(SRC_XLSX)
edit_log <- list()
for (sh in c("Features_Motor", "Features_Buildings", "Features_Contents")) {
  x <- as.data.table(read_excel(SRC_XLSX, sheet = sh, col_types = "text"))
  for (old in names(FEATURE_RENAME)) {
    i <- which(x$column == old)
    if (length(i)) { x[i, `:=`(column = FEATURE_RENAME[[old]], type = "cat", mono_freq = "0", mono_sev = "0")]
                     edit_log[[length(edit_log) + 1]] <- data.table(sheet = sh, column = old, edit = paste("renamed to", FEATURE_RENAME[[old]], "(category, no monotone constraint)")) }
  }
  i <- which(x$column %in% FEATURE_OFF & toupper(x$use) == "Y")
  if (length(i)) { edit_log[[length(edit_log) + 1]] <- data.table(sheet = sh, column = x$column[i], edit = "use Y -> N (not shared / excluded)")
                   x[i, `:=`(use = "N", decision = "Exclude", reason = paste0("Week 2: not shared by both markets or excluded. ", reason))] }
  openxlsx::writeData(wb, sh, x, startRow = 1, colNames = TRUE)
}
st <- as.data.table(read_excel(SRC_XLSX, sheet = "Settings", col_types = "text"))
for (k in names(SETTING_EDITS)) {
  i <- which(st$key == k)
  edit_log[[length(edit_log) + 1]] <- data.table(sheet = "Settings", column = k, edit = paste0(st$value[i], " -> ", SETTING_EDITS[[k]]))
  st[i, value := SETTING_EDITS[[k]]]
}
openxlsx::writeData(wb, "Settings", st, startRow = 1, colNames = TRUE)
edit_log <- rbindlist(edit_log)
if ("Week2_Edits" %in% names(wb)) openxlsx::removeWorksheet(wb, "Week2_Edits")
openxlsx::addWorksheet(wb, "Week2_Edits")
openxlsx::writeData(wb, "Week2_Edits", edit_log)
openxlsx::saveWorkbook(wb, CFG_FILE, overwrite = TRUE)
track_output(CFG_FILE)
log_msg("Workbook ", CFG_FILE, " built from ", SRC_XLSX, " with ", nrow(edit_log), " edits")

# 0b. Read the workbook (as C5) ---------------------------------------------------------------------------------------
rd <- function(sheet) { x <- as.data.table(read_excel(CFG_FILE, sheet = sheet, col_types = "text")); x[!is.na(x[[1]])] }
settings <- rd("Settings")
S <- setNames(settings$value, settings$key)
s_get <- function(k) { if (!k %in% names(S) || is.na(S[[k]])) stop("Setting '", k, "' missing"); S[[k]] }
s_num <- function(k) as.numeric(s_get(k))
s_vec <- function(k) trimws(strsplit(s_get(k), ",", fixed = TRUE)[[1]])
VALID_YEARS <- as.integer(s_vec("valid_years"))
TARGET_YEAR <- as.integer(s_num("target_year"))
SEV_TREND_LIM <- c(s_num("sev_trend_min"), s_num("sev_trend_max"))
FREQ_TREND_LIM <- c(s_num("freq_trend_min"), s_num("freq_trend_max"))
MAX_ROUNDS <- if (FAST) 300 else s_num("max_rounds")
ETA_MULT <- if (FAST) 2 else 1
ES_ROUNDS <- s_num("early_stopping_rounds")
HOLD_SHARE <- s_num("holdout_share")
SUBSAMPLE <- s_num("subsample"); COLSAMPLE <- s_num("colsample_bytree"); LAMBDA <- s_num("reg_lambda")
if (!is.na(HP$subsample)) SUBSAMPLE <- HP$subsample; if (!is.na(HP$colsample)) COLSAMPLE <- HP$colsample; if (!is.na(HP$reg_lambda)) LAMBDA <- HP$reg_lambda
GLM_MIN_CLAIMS <- s_num("glm_min_level_claims")
GLM_LOG <- s_vec("glm_log_features")
NTHREAD <- as.integer(s_num("nthread")); if (NTHREAD <= 0) NTHREAD <- max(1L, parallel::detectCores())
BAGS <- as.integer(s_get("bags"))
MIN_SEV_CLAIMS <- 200

spec <- rd("Model_Spec")[line %in% LINES]
num_cols <- c("cap_quantile", "sev_exclude_recent_years", "freq_max_depth", "freq_eta", "freq_min_child_weight",
              "sev_max_depth", "sev_eta", "sev_min_child_weight", "tweedie_p")
spec[, (num_cols) := lapply(.SD, as.numeric), .SDcols = num_cols]
spec[, `:=`(freq_max_depth = pmax(2, freq_max_depth + HP$depth_add), sev_max_depth = pmax(2, sev_max_depth + HP$depth_add),
            freq_eta = freq_eta * HP$eta_mult, sev_eta = sev_eta * HP$eta_mult,
            freq_min_child_weight = freq_min_child_weight * HP$mcw_mult, sev_min_child_weight = sev_min_child_weight * HP$mcw_mult)]
XGB_EXTRA <- c("reg_lambda", "colsample_bytree", "subsample", "min_split_loss", "max_delta_step")   # per-peril overrides, prefixed freq_ / sev_
for (i in seq_len(nrow(SPEC_OV))) { o <- SPEC_OV[i]
  if (o$param %in% num_cols) spec[line == o$line & peril == o$peril, (o$param) := as.numeric(o$value)]
  else if (!sub("^(freq|sev)_", "", o$param) %in% XGB_EXTRA) stop("SPEC_OVERRIDE: unknown param ", o$param) }
xgb_extra <- function(ln, pr, part) { o <- SPEC_OV[line == ln & peril == pr & startsWith(param, paste0(part, "_"))]
  setNames(as.list(o$value), sub(paste0("^", part, "_"), "", o$param)) }
spec_row <- function(ln, pr) spec[line == ln & peril == pr][1]
fmap <- rbindlist(lapply(LINES, function(ln) {
  x <- rd(paste0("Features_", tools::toTitleCase(ln)))
  x <- x[toupper(trimws(use)) == "Y", c("column", "mono_freq", "mono_sev", PERILS[[ln]]), with = FALSE]
  long <- melt(x, id.vars = c("column", "mono_freq", "mono_sev"), variable.name = "peril", value.name = "code", variable.factor = FALSE)
  long[, `:=`(line = ln, code = toupper(trimws(code)))][code %in% c("B", "F", "S")]
}))
fmap[, `:=`(mono_freq = as.integer(fifelse(is.na(mono_freq), "0", mono_freq)), mono_sev = as.integer(fifelse(is.na(mono_sev), "0", mono_sev)))]
# Week 2 rule: voluntary_excess in every peril (handover; week 1 C4/C5 "excess in every peril")
# LOC_ALL=1 (B3): location signal in place of the dropped region - urban_density, flood_zone and the address weather averages
# as frequency features of every peril of every line (week 2 X6 tried motor only)
LOC_FEATS <- c("urban_density", "wx_avg_hail_days", "wx_avg_rainfall_mm", "wx_avg_freezing_days", "wx_avg_wind_exposure_index", "flood_zone")
add_feat <- function(ln, pr, cn, code = "F", mono = 0L) if (!nrow(fmap[line == ln & peril == pr & column == cn]))
  fmap <<- rbind(fmap, data.table(column = cn, mono_freq = mono, mono_sev = 0L, peril = pr, code = code, line = ln), use.names = TRUE)
if (LOC_ALL) for (ln in LINES) for (pr in PERILS[[ln]]) for (cn in LOC_FEATS) add_feat(ln, pr, cn)
# PROXY (B3): features built only from fields both markets have, standing in for dropped developed-only fields
#   mileage -> use_cover (vehicle_use x cover_type), age_use (named_young_driver x vehicle_use x vehicle_age band)
#   credit  -> disc_flag (any discount), missed_any (any missed payment)
#   age     -> novice_band (age band x years_licensed band)
PROXY_COLS <- list(mileage = list(motor = c("use_cover", "age_use")), credit = list(motor = c("disc_flag", "missed_any"), buildings = c("disc_flag", "missed_any"), contents = c("disc_flag", "missed_any")),
                   age = list(motor = "novice_band"))
if (length(PROXY)) { bad <- setdiff(PROXY, names(PROXY_COLS)); if (length(bad)) stop("Unknown PROXY: ", paste(bad, collapse = ", ")) }
for (px in PROXY) for (ln in intersect(names(PROXY_COLS[[px]]), LINES)) for (pr in PERILS[[ln]]) for (cn in PROXY_COLS[[px]][[ln]]) add_feat(ln, pr, cn)
if (AGE_BAND_ORD) fmap[column %in% c("driver_age_band", "policyholder_age_band"), `:=`(mono_freq = 0L, mono_sev = 0L)]
if (MONO_OFF) fmap[, `:=`(mono_freq = 0L, mono_sev = 0L)]
for (ln in LINES) for (pr in PERILS[[ln]]) if (!nrow(fmap[line == ln & peril == pr & column == "voluntary_excess"]))
  fmap <- rbind(fmap, data.table(column = "voluntary_excess", mono_freq = if (MONO_OFF) 0L else -1L, mono_sev = 0L, peril = pr, code = "F", line = ln), use.names = TRUE)
feats_for <- function(ln, pr, part) {
  codes <- switch(part, freq = c("F", "B"), sev = c("S", "B"), all = c("F", "S", "B"))
  unique(fmap[line == ln & peril == pr & code %in% codes, column])
}
zero_rules <- rd("Structural_Zeros")[line %in% LINES]
log_msg("Features: ", nrow(fmap), " feature-peril uses; bags ", BAGS, if (FAST) " [FAST]" else "")

# 1. Claims and IBNR shares -------------------------------------------------------------------------------------------
clp <- claim_basis("developed")
# POOLED_YEAR=2023|2024 (experiment X7): the final fit also uses the emerging training rows up to that year, with the
# `market` flag and gender as features, so the trees can learn emerging-specific shape. Emerging ids are prefixed "E_"
# in the fit (ids overlap between markets). 2023 = baseline for the 2024 validation, 2024 = baseline for 2025.
POOLED_YEAR <- as.integer(Sys.getenv("POOLED_YEAR", "0"))
add_extra <- function(d, part, ln) {
  if (!POOLED_YEAR) return(d)
  if (d$market[1] == "emerging") merge(d, read_w2(file.path(FEAT_DIR, sprintf("emerging_extra_%s_%s.parquet", part, ln)))[, .(row_id, gender)], by = "row_id")
  else d[, gender := "missing"]
}
if (POOLED_YEAR) {
  clp <- rbind(clp, claim_basis("emerging")[, row_id := paste0("E_", row_id)])
  for (ln in LINES) for (pr in PERILS[[ln]]) for (cn in c("market", "gender"))
    fmap <- rbind(fmap, data.table(column = cn, mono_freq = 0L, mono_sev = 0L, peril = pr, code = if (cn == "market") "B" else "F", line = ln), use.names = TRUE)
}
shares <- load_report_shares()
W2$output <- file.path(RT$root, "output")     # every later save_csv / out_path goes to week2/week1_retune/output/<tag>/
dir.create(W2$output, recursive = TRUE, showWarnings = FALSE)
report_share <- function(ln, pr, dt) row_report_share(shares, ln, pr, dt$period_start, dt$period_end)
add_proxies <- function(dt, ln) {
  if ("mileage" %in% PROXY && ln == "motor") dt[, `:=`(use_cover = paste(vehicle_use, cover_type),
    age_use = paste(named_young_driver, vehicle_use, cut(vehicle_age, c(-Inf, 2, 5, 9, Inf), labels = FALSE)))]
  if ("credit" %in% PROXY) dt[, `:=`(disc_flag = as.character(discount_applied > 0), missed_any = as.character(missed_payments_12m > 0))]
  if ("age" %in% PROXY && ln == "motor") dt[, novice_band := paste(driver_age_band, cut(years_licensed, c(-Inf, 2, 5, 10, Inf), labels = FALSE))]
  dt
}
# DOMAIN_W=1 (B5): developed rows weighted by the odds of looking like an emerging row (logistic model on fields both markets
# have), odds corrected for the sample sizes, capped at 5, mean 1. Weights apply to the developed training rows only.
DW_FIELDS <- list(common = c("new_business", "channel", "renewal_count", "voluntary_excess", "payment_method", "missed_payments_12m"),
                  motor = c("driver_age_band", "vehicle_value_group", "vehicle_age", "years_licensed", "ncb_years", "cover_type", "vehicle_use"),
                  buildings = c("policyholder_age_band", "sum_insured", "construction_type", "occupancy"),
                  contents = c("policyholder_age_band", "sum_insured", "tenure", "security_level"))
dw_cache <- new.env()
domain_weights <- function(ln, dev) {
  if (!is.null(dw_cache[[ln]])) return(dw_cache[[ln]][dev, on = "row_id", dw])
  fl <- c(DW_FIELDS$common, DW_FIELDS[[ln]])
  em <- rbind(read_w2(file.path(FEAT_DIR, sprintf("emerging_train_%s.parquet", ln))), read_w2(file.path(FEAT_DIR, sprintf("emerging_test_%s.parquet", ln))), fill = TRUE)
  dv <- read_w2(file.path(FEAT_DIR, sprintf("developed_train_%s.parquet", ln)))
  set.seed(SEED); dvs <- dv[sample.int(nrow(dv), min(nrow(dv), 200000L))]
  z <- rbind(dvs[, c("row_id", fl), with = FALSE][, y := 0L], em[, c("row_id", fl), with = FALSE][, y := 1L])
  for (f in fl) if (is.character(z[[f]]) || is.logical(z[[f]])) { v <- as.character(z[[f]]); v[is.na(v)] <- "missing"; set(z, j = f, value = factor(v)) } else set(z, j = f, value = { v <- as.numeric(z[[f]]); v[is.na(v)] <- median(v, na.rm = TRUE); v })
  g <- glm(reformulate(fl, "y"), data = as.data.frame(z), family = binomial(), control = glm.control(maxit = 50))
  zd <- as.data.frame(dv[, fl, with = FALSE])
  for (f in fl) if (is.factor(z[[f]])) { v <- as.character(zd[[f]]); v[is.na(v)] <- "missing"; v[!v %in% levels(z[[f]])] <- levels(z[[f]])[1]; zd[[f]] <- factor(v, levels = levels(z[[f]])) } else { v <- as.numeric(zd[[f]]); v[is.na(v)] <- median(z[[f]], na.rm = TRUE); zd[[f]] <- v }
  p <- predict(g, newdata = zd, type = "response")
  w <- pmin(p / (1 - p) * (nrow(dvs) / nrow(em)), 5); w <- w / mean(w)
  dw_cache[[ln]] <- data.table(row_id = dv$row_id, dw = w)
  log_msg("Domain weights ", ln, ": p1 / p50 / p99 = ", paste(round(quantile(w, c(0.01, 0.5, 0.99)), 2), collapse = " / "), "; effective sample share ", round(sum(w)^2 / sum(w^2) / length(w), 3))
  dw_cache[[ln]][dev, on = "row_id", dw]
}
load_line <- function(market, part, ln) {
  dt <- read_w2(file.path(FEAT_DIR, sprintf("%s_%s_%s.parquet", market, part, ln)))
  if (length(FEATURE_ADD) || FEATURE_OFF_KEEP_ALL) if (market == "developed") {   # developed-only fields, from the week 2 clean tables
    cl <- read_w2(file.path(W2$clean, sprintf("%s_%s_%s.parquet", market, part, ln)))
    want <- if (FEATURE_OFF_KEEP_ALL) c("driver_age", "policyholder_age", "region", "credit_band", "annual_mileage", "telematics_opt_in", "telematics_score") else FEATURE_ADD
    want <- setdiff(intersect(want, names(cl)), names(dt))
    if (length(want)) dt <- cbind(dt, cl[match(dt$row_id, cl$row_id), ..want])
  }
  dt <- add_proxies(dt, ln)
  if (AGE_BAND_ORD) for (b in intersect(c("driver_age_band", "policyholder_age_band"), names(dt))) set(dt, j = b, value = as.numeric(match(dt[[b]], AGE_BANDS)))
  miss <- setdiff(fmap[line == ln, unique(column)], c(names(dt), "gender"))   # gender is added by add_extra() in pooled runs
  if (length(miss)) stop(market, " ", part, " ", ln, ": workbook features not in data: ", paste(miss, collapse = ", "))
  if (market == "developed" && part == "train") {
    if (TRAIN_FROM > 0) dt <- dt[policy_year >= TRAIN_FROM]
    dt[, rw := 1]
    if (length(YEAR_W)) dt[, rw := rw * YEAR_W[pmin(pmax(policy_year - 2020L, 1L), length(YEAR_W))]]
    if (DOMAIN_W) dt[, rw := rw * domain_weights(ln, dt)]
  }
  dt
}

# 2. Structural zeros (applied only where developed training has no positive claims) ------------------------------------
rule_mask <- function(dt, rules) {
  m <- rep(FALSE, nrow(dt))
  for (i in seq_len(nrow(rules))) {
    vals <- toupper(trimws(strsplit(rules$values[i], ",", fixed = TRUE)[[1]]))
    m <- m | toupper(as.character(dt[[rules$column[i]]])) %chin% vals
  }
  m
}
zr_check <- rbindlist(lapply(LINES, function(ln) {
  rules <- zero_rules[line == ln]; if (!nrow(rules)) return(NULL)
  dt <- load_line("developed", "train", ln)
  rbindlist(lapply(seq_len(nrow(rules)), function(i) {
    r <- rules[i]; m <- rule_mask(dt, r)
    n_cl <- clp[line == ln & peril == r$peril & row_id %chin% dt$row_id[m], .N]
    r[, .(line, peril, column, values, rows = sum(m), claims = n_cl, active = n_cl == 0 & sum(m) > 0)]
  }))
}))
zero_mask <- function(dt, ln, pr) {
  rules <- zr_check[line == ln & peril == pr & active == TRUE]
  if (!nrow(rules)) rep(FALSE, nrow(dt)) else rule_mask(dt, rules)
}

# 3. Helpers (copied from C5) ----------------------------------------------------------------------------------------------
make_enc <- function(dt, feats, y, w) {
  is_cat <- vapply(feats, function(f) is.character(dt[[f]]) || is.factor(dt[[f]]), logical(1))
  lv <- lapply(setNames(feats[is_cat], feats[is_cat]), function(f) {
    tb <- data.table(x = as.character(dt[[f]]), y = y, w = w)[, .(rate = sum(y) / sum(w)), by = x]
    tb[order(rate, x), x]
  })
  list(feats = feats, lv = lv)
}
to_mat <- function(enc, d) {
  m <- matrix(NA_real_, nrow(d), length(enc$feats), dimnames = list(NULL, enc$feats))
  for (j in seq_along(enc$feats)) {
    f <- enc$feats[j]
    m[, j] <- if (!is.null(enc$lv[[f]])) match(as.character(d[[f]]), enc$lv[[f]]) else as.numeric(d[[f]])
  }
  m
}
mono_vec <- function(enc, ln, pr, part) {
  col <- if (part == "sev") "mono_sev" else "mono_freq"
  m <- fmap[line == ln & peril == pr][match(enc$feats, column)][[col]]
  m[is.na(m) | enc$feats %in% names(enc$lv)] <- 0L
  m
}
policy_holdout <- function(pid) { u <- unique(pid); pid %chin% sample(u, max(1L, round(HOLD_SHARE * length(u)))) }
xgb_fit <- function(X, label, w, hold, objective, depth, eta, mcw, mono = NULL, extra = list(), pid = NULL, hpx = list()) {
  one <- function(hold, seed) {
    dtr <- xgb.DMatrix(X[!hold, , drop = FALSE], label = label[!hold], weight = w[!hold], nthread = NTHREAD)
    dva <- xgb.DMatrix(X[hold, , drop = FALSE], label = label[hold], weight = w[hold], nthread = NTHREAD)
    params <- c(list(objective = objective, learning_rate = eta * ETA_MULT, max_depth = depth, min_child_weight = mcw,
                     subsample = SUBSAMPLE, colsample_bytree = COLSAMPLE, reg_lambda = LAMBDA,
                     tree_method = "hist", nthread = NTHREAD, seed = seed), extra)
    for (k in names(hpx)) params[[k]] <- hpx[[k]]
    if (!is.null(mono) && any(mono != 0)) params$monotone_constraints <- paste0("(", paste(mono, collapse = ","), ")")
    xgb.train(params = params, data = dtr, nrounds = MAX_ROUNDS, evals = list(holdout = dva), early_stopping_rounds = ES_ROUNDS, verbose = 0)
  }
  m1 <- one(hold, SEED)
  if (BAGS <= 1 || is.null(pid)) return(m1)
  structure(c(list(m1), lapply(2:BAGS, function(b) one(policy_holdout(pid), SEED + b))), class = "xgb_bag")
}
predict.xgb_bag <- function(object, newdata, ...) {
  p <- vapply(unclass(object), function(m) predict(m, newdata), numeric(nrow(newdata)))
  if (is.null(dim(p))) mean(p) else rowMeans(p)
}
best_iter <- function(m) { if (inherits(m, "xgb_bag")) m <- m[[1]]; b <- xgb.attr(m, "best_iteration"); if (is.null(b)) NA_integer_ else as.integer(b) }
raw_model <- function(m) if (inherits(m, "xgb_bag")) structure(lapply(unclass(m), xgb.save.raw), class = "xgb_bag_raw") else xgb.save.raw(m)
load_model <- function(r) if (inherits(r, "xgb_bag_raw")) structure(lapply(unclass(r), xgb.load.raw), class = "xgb_bag") else xgb.load.raw(r)
glm_prep <- function(sdat, feats) {
  out <- list()
  for (f in feats) {
    v <- sdat[[f]]
    if (is.character(v) || is.logical(v) || is.factor(v)) {
      v <- as.character(v); v[is.na(v)] <- "missing"
      tab <- sort(table(v), decreasing = TRUE); keep <- names(tab)[tab >= GLM_MIN_CLAIMS]
      if (!length(keep)) next
      levels <- c(keep, if (any(!v %in% keep)) "other")
      if (length(levels) >= 2) out[[f]] <- list(kind = "cat", keep = keep, levels = levels)
    } else {
      v <- as.numeric(v); med <- median(v, na.rm = TRUE); if (is.na(med)) next
      lg <- f %in% GLM_LOG
      x <- if (lg) log1p(pmax(fifelse(is.na(v), med, v), 0)) else fifelse(is.na(v), med, v)
      if (isTRUE(stats::sd(x) > 0)) out[[f]] <- list(kind = "num", med = med, log = lg)
    }
  }
  out
}
glm_frame <- function(prep, nd) {
  cols <- lapply(names(prep), function(f) {
    p <- prep[[f]]
    if (p$kind == "cat") {
      v <- as.character(nd[[f]]); v[is.na(v)] <- "missing"
      v[!v %in% p$keep] <- if ("other" %in% p$levels) "other" else p$keep[1]
      factor(v, levels = p$levels)
    } else { v <- as.numeric(nd[[f]]); v[is.na(v)] <- p$med; if (p$log) log1p(pmax(v, 0)) else v }
  })
  setNames(as.data.frame(cols), names(prep))
}
clamp <- function(x, lim) min(max(x, lim[1]), lim[2])
loglin_trend <- function(yr, value, w) {
  ok <- value > 0 & w > 0
  if (length(unique(yr[ok])) < 2) return(0)
  exp(unname(coef(lm(log(value[ok]) ~ yr[ok], weights = w[ok]))[2])) - 1
}
seed_of <- function(ln, pr, yr, part) SEED + 1000 * match(ln, LINES) + 50 * match(pr, PERILS[[ln]]) + 3 * (yr - 2020) + match(part, c("freq", "sev", "tw"))

# 4. Claim preparation, frequency x severity fit (C5) -------------------------------------------------------------------
prep_claims <- function(cp, sp, train_years, target_year) {
  ex <- sp$sev_exclude_recent_years; ty <- sort(train_years)
  sev_years <- if (ex > 0 && length(ty) > ex) head(ty, length(ty) - ex) else ty
  cp <- copy(cp)[, in_sev := loss_year %in% sev_years]
  if (cp[in_sev == TRUE, .N] < 10) cp[, in_sev := TRUE]
  base <- cp[in_sev == TRUE]
  cap0 <- quantile(base$cost, sp$cap_quantile, names = FALSE)
  g <- 0
  if (tolower(sp$sev_trend) == "estimate") {
    a <- base[, .(m = mean(pmin(cost, cap0)), n = .N), by = loss_year]
    g <- clamp(loglin_trend(a$loss_year, a$m, a$n), SEV_TREND_LIM)
  }
  cp[, cost_t := cost * (1 + g)^(target_year - loss_year)]
  cap <- quantile(cp[in_sev == TRUE, cost_t], sp$cap_quantile, names = FALSE)
  cp[, capped := pmin(cost_t, cap)]
  list(cp = cp, sev_trend = g, cap = cap, load = cp[in_sev == TRUE, sum(cost_t) / sum(capped)], sev_years = sev_years)
}
freq_trend_factor <- function(sp, y, e, yr, w, target_year) {
  if (tolower(sp$freq_trend) != "estimate") return(list(g = 0, f = 1))
  a <- data.table(y, e, yr)[, .(ae = sum(y) / sum(e), n = sum(y)), by = yr]
  g <- clamp(loglin_trend(a$yr, a$ae, a$n), FREQ_TREND_LIM)
  list(g = g, f = (1 + g)^(target_year - weighted.mean(yr, w)))
}
fit_freq_sev <- function(tr, clp_ln, ln, pr, target_year) {
  sp <- spec_row(ln, pr)
  d <- tr[!zero_mask(tr, ln, pr)]
  pc <- prep_claims(clp_ln[peril == pr & row_id %chin% d$row_id], sp, unique(tr$policy_year), target_year)
  n <- pc$cp[, .N, by = row_id][d, on = "row_id", N]; n[is.na(n)] <- 0
  eff <- d$exposure * report_share(ln, pr, d)
  rw <- if ("rw" %in% names(d)) d$rw else rep(1, nrow(d))
  ff <- feats_for(ln, pr, "freq")
  enc_f <- make_enc(d, ff, n, eff)
  X <- to_mat(enc_f, d)
  set.seed(seed_of(ln, pr, target_year, "freq"))
  m_f <- xgb_fit(X, n / eff, eff * rw, policy_holdout(d$policy_id), "count:poisson", sp$freq_max_depth, sp$freq_eta,
                 sp$freq_min_child_weight, mono_vec(enc_f, ln, pr, "freq"), pid = d$policy_id, hpx = xgb_extra(ln, pr, "freq"))
  p_in <- predict(m_f, X)
  bal_f <- sum(n) / sum(p_in * eff)
  ft <- freq_trend_factor(sp, n, p_in * eff * bal_f, d$policy_year, eff, target_year)
  rm(X); invisible(gc(verbose = FALSE))
  sv <- pc$cp[in_sev == TRUE]
  sd <- d[sv[, .(row_id, capped)], on = "row_id"]
  fs <- feats_for(ln, pr, "sev")
  sev <- list(type = "mean", mu = if (nrow(sd)) mean(sd$capped) else mean(pc$cp$capped), bal = 1)
  if (nrow(sd) >= MIN_SEV_CLAIMS && length(fs)) {
    if (sp$sev_model == "gamma_gbm") {
      enc_s <- make_enc(sd, fs, sd$capped, rep(1, nrow(sd)))
      Xs <- to_mat(enc_s, sd)
      set.seed(seed_of(ln, pr, target_year, "sev"))
      m_s <- xgb_fit(Xs, sd$capped, if ("rw" %in% names(sd)) sd$rw else rep(1, nrow(sd)), policy_holdout(sd$policy_id), "reg:gamma", sp$sev_max_depth, sp$sev_eta,
                     sp$sev_min_child_weight, mono_vec(enc_s, ln, pr, "sev"), pid = sd$policy_id, hpx = xgb_extra(ln, pr, "sev"))
      sev <- list(type = "gbm", enc = enc_s, model = m_s, bal = sum(sd$capped) / sum(predict(m_s, Xs)))
    } else if (sp$sev_model == "gamma_glm") {
      prep <- glm_prep(sd, fs)
      if (length(prep)) {
        fr <- glm_frame(prep, sd); fr$y__ <- sd$capped
        g <- tryCatch(glm(y__ ~ ., data = fr, family = Gamma(link = "log"), mustart = rep(mean(fr$y__), nrow(fr)),
                          control = glm.control(maxit = 100)), error = function(e) NULL)
        if (!is.null(g) && g$converged) { g$data <- NULL; g$model <- NULL
          sev <- list(type = "glm", prep = prep, model = g, bal = sum(fr$y__) / sum(fitted(g)))
        } else log_msg("  ", ln, "/", pr, ": severity GLM failed - mean severity")
      }
    }
  }
  art <- list(type = "freq_sev", line = ln, peril = pr, target_year = target_year, enc_f = enc_f, m_f = m_f,
              bal_f = bal_f, f_trend = ft$f, sev = sev, load = pc$load)
  diag <- data.table(line = ln, peril = pr, rounds_freq = best_iter(m_f), rounds_sev = if (sev$type == "gbm") best_iter(sev$model) else NA_integer_,
                     sev_type = sev$type, claims_freq = sum(n), claims_sev = nrow(sd), bal_freq = bal_f, bal_sev = sev$bal,
                     freq_trend = ft$g, sev_trend = pc$sev_trend, cap = pc$cap, cap_load = pc$load, sev_years = paste(range(pc$sev_years), collapse = "-"))
  list(art = art, diag = diag)
}
sev_predict <- function(sev, nd) switch(sev$type, mean = rep(sev$mu, nrow(nd)),
  gbm = predict(sev$model, to_mat(sev$enc, nd)) * sev$bal,
  glm = unname(predict(sev$model, newdata = glm_frame(sev$prep, nd), type = "response")) * sev$bal)
# Components per row: frequency per exposure-year (ultimate, trended) and severity per claim (x large-loss load)
predict_parts <- function(art, nd) {
  fq <- sv <- numeric(nrow(nd))
  idx <- which(!zero_mask(nd, art$line, art$peril))
  if (length(idx)) {
    sub <- nd[idx]
    fq[idx] <- predict(art$m_f, to_mat(art$enc_f, sub)) * art$bal_f * art$f_trend
    sv[idx] <- sev_predict(art$sev, sub) * art$load
  }
  list(freq = fq, sev = sv, pred = nd$exposure * fq * sv)
}

# 4b. TUNE=1: per-peril hyperparameter search on developed folds (see retune_plan.md section 3, B7) ---------------------------
# Selection uses fold 2023 only (fit on 2021-22), two seeds. Fold 2024 (fit on 2021-23) is the untouched holdout: a tuned
# config is adopted only if it beats the default on 2023 (seed B) and on 2024 (both seeds). Score = developed-actuals cost D2.
if (Sys.getenv("TUNE", "0") == "1") {
  N_F <- env_num("TUNE_N_FREQ", 24); N_S <- env_num("TUNE_N_SEV", 16); SEED_A <- SEED; SEED_B <- SEED + 101
  tlog_f <- out_path(STEP, "tune_log.csv"); tsum_f <- out_path(STEP, "tune_summary.csv")
  tlog <- if (file.exists(tlog_f)) fread(tlog_f) else data.table(); tsum <- if (file.exists(tsum_f)) fread(tsum_f) else data.table()
  spec0 <- copy(spec); ov0 <- copy(SPEC_OV)
  set_cfg <- function(ln, pr, cfg) {            # cfg: named list of freq_* / sev_* params; NULL = default
    spec <<- copy(spec0); SPEC_OV <<- copy(ov0)
    for (nm in names(cfg)) {
      if (nm %in% num_cols) spec[line == ln & peril == pr, (nm) := as.numeric(cfg[[nm]])]
      else SPEC_OV <<- rbind(SPEC_OV[!(line == ln & peril == pr & param == nm)], data.table(line = ln, peril = pr, param = nm, value = as.numeric(cfg[[nm]])))
    }
  }
  space <- function(base, part) {
    d <- base[[paste0(part, "_max_depth")]]; m <- base[[paste0(part, "_min_child_weight")]]
    setNames(list(sort(unique(pmax(2, d + c(-2, -1, 0, 1, 2)))), base[[paste0(part, "_eta")]] * c(0.5, 1, 2),
                  if (m > 0) sort(unique(m * c(0.5, 1, 2, 4))) else c(0, 20, 50, 100), c(1, 5, 20, 50), c(0.5, 0.7, 0.8, 1), c(0.6, 0.8, 1), c(0, 0.5, 2)),
             paste0(part, c("_max_depth", "_eta", "_min_child_weight", "_reg_lambda", "_colsample_bytree", "_subsample", "_min_split_loss")))
  }
  draw_cfg <- function(sp) lapply(sp, function(v) v[sample.int(length(v), 1)])
  cfg_str <- function(cfg) if (!length(cfg)) "default" else paste(sprintf("%s=%g", names(cfg), unlist(cfg)), collapse = ";")
  for (ln in LINES) {
    dt <- load_line("developed", "train", ln); clp_ln <- clp[line == ln]
    fold <- lapply(c(`2023` = 2023L, `2024` = 2024L), function(vy) list(vy = vy, tr = dt[policy_year < vy], va = dt[policy_year == vy]))
    score <- function(pr, cfg, fk, seed) {
      SEED <<- seed; set_cfg(ln, pr, cfg); fo <- fold[[fk]]
      f <- fit_freq_sev(fo$tr, clp_ln, ln, pr, fo$vy)
      p <- predict_parts(f$art, fo$va)$pred
      a <- clp_ln[peril == pr, .(a = sum(cost)), by = row_id][fo$va, on = "row_id", a]; a[is.na(a)] <- 0
      d2_exp(a / report_share(ln, pr, fo$va), p, fo$va$exposure)
    }
    for (pr in PERILS[[ln]]) {
      if (nrow(tsum) && nrow(tsum[line == ln & peril == pr])) { log_msg("Tune ", ln, "/", pr, ": already done"); next }
      t0 <- Sys.time(); base <- spec_row(ln, pr); rec <- list(); set.seed(SEED_A + 7 * match(pr, PERILS[[ln]]) + 13 * match(ln, LINES))
      ev <- function(phase, id, cfg, fk, seed) { s <- score(pr, cfg, fk, seed)
        rec[[length(rec) + 1]] <<- data.table(line = ln, peril = pr, phase = phase, cfg_id = id, params = cfg_str(cfg), fold = fk, seed = seed, d2 = s); s }
      s0 <- ev("default", 0, NULL, "2023", SEED_A)
      has_sev <- identical(base$sev_model, "gamma_gbm")
      best <- list(); best_s <- s0
      for (i in seq_len(N_F)) { cfg <- draw_cfg(space(base, "freq")); s <- ev("freq", i, cfg, "2023", SEED_A); if (s > best_s) { best <- cfg; best_s <- s } }
      cF <- best; sF <- best_s
      if (has_sev) for (i in seq_len(N_S)) { cfg <- c(cF, draw_cfg(space(base, "sev"))); s <- ev("sev", 1000 + i, cfg, "2023", SEED_A); if (s > best_s) { best <- cfg; best_s <- s } }
      cands <- list(F = cF, FS = best)
      if (length(best) == length(cF)) cands$FS <- NULL
      cands <- cands[vapply(cands, length, 1L) > 0]
      conf <- list(); ref_ <- c(`2023B` = ev("confirm", 0, NULL, "2023", SEED_B), `2024A` = ev("confirm", 0, NULL, "2024", SEED_A), `2024B` = ev("confirm", 0, NULL, "2024", SEED_B))
      chosen <- "default"; chosen_cfg <- list(); chosen_gain <- 0
      for (nm in names(cands)) {
        cc <- c(`2023B` = ev("confirm", nm, cands[[nm]], "2023", SEED_B), `2024A` = ev("confirm", nm, cands[[nm]], "2024", SEED_A), `2024B` = ev("confirm", nm, cands[[nm]], "2024", SEED_B))
        gain <- cc - ref_
        if (all(gain > 0) && mean(gain) > chosen_gain) { chosen <- nm; chosen_cfg <- cands[[nm]]; chosen_gain <- mean(gain) }
        conf[[nm]] <- gain
      }
      tlog <- rbind(tlog, rbindlist(rec), fill = TRUE); fwrite(tlog, tlog_f)
      tsum <- rbind(tsum, data.table(line = ln, peril = pr, chosen = chosen, params = cfg_str(chosen_cfg), d2_default_2023 = s0, d2_best_screen_2023 = best_s,
                                     gain_confirm_mean = chosen_gain, gain_F = if (!is.null(conf$F)) paste(sprintf("%.5f", conf$F), collapse = "/") else "",
                                     gain_FS = if (!is.null(conf$FS)) paste(sprintf("%.5f", conf$FS), collapse = "/") else "", minutes = round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)), fill = TRUE)
      fwrite(tsum, tsum_f)
      log_msg("Tune ", ln, "/", pr, ": ", chosen, " ", cfg_str(chosen_cfg), "; screen 2023 ", sprintf("%.4f -> %.4f", s0, best_s), "; confirm gain ", sprintf("%.5f", chosen_gain))
    }
    rm(dt, fold); invisible(gc(verbose = FALSE))
  }
  # tuned spec for SPEC_OVERRIDE: only the chosen, non-default parameters
  ts <- rbindlist(lapply(seq_len(nrow(tsum)), function(i) { if (tsum$chosen[i] == "default") return(NULL)
    kv <- strsplit(strsplit(tsum$params[i], ";", fixed = TRUE)[[1]], "=", fixed = TRUE)
    data.table(line = tsum$line[i], peril = tsum$peril[i], param = vapply(kv, `[`, "", 1), value = as.numeric(vapply(kv, `[`, "", 2))) }))
  fwrite(ts, file.path(RT$root, "inputs", paste0("tuned_spec_", RUN_TAG, ".csv")))
  log_msg("Tuning done: ", nrow(tsum[chosen != "default"]), " of ", nrow(tsum), " perils changed; spec written to week2/week1_retune/inputs/tuned_spec_", RUN_TAG, ".csv")
  update_step_log(paste0("rt-", RUN_TAG), paste("Retune tuning", RUN_TAG), sprintf("- Tuned perils: %d of %d.", nrow(tsum[chosen != "default"]), nrow(tsum)))
  end_script(); quit(save = "no", status = 0)
}

# 5. Validation on developed (week 1 folds) -------------------------------------------------------------------------------
peril_scores <- list(); diag_val <- list(); rows <- list()
if (!SKIP_VALID) for (ln in LINES) {
  dt <- load_line("developed", "train", ln)
  clp_ln <- clp[line == ln]
  for (vy in VALID_YEARS) {
    tr <- dt[policy_year < vy]; va <- dt[policy_year == vy]
    rp <- data.table(valid_year = vy, line = ln, row_id = va$row_id, policy_id = va$policy_id, exposure = va$exposure)
    for (pr in PERILS[[ln]]) {
      adj <- clp_ln[peril == pr, .(a = sum(cost)), by = row_id][va, on = "row_id", a]; adj[is.na(adj)] <- 0
      act <- list(reported_raw = va[[paste0("y_cost_", pr)]], developed = adj / report_share(ln, pr, va))
      t0 <- Sys.time()
      f <- fit_freq_sev(tr, clp_ln, ln, pr, vy)
      p <- predict_parts(f$art, va)$pred
      set(rp, j = paste0("pred_", pr), value = p)
      for (b in names(act)) set(rp, j = paste0(b, "_", pr), value = act[[b]])
      k <- paste(vy, ln, pr)
      diag_val[[k]] <- f$diag[, `:=`(valid_year = vy, seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))]
      peril_scores[[k]] <- rbindlist(lapply(names(act), function(b) data.table(basis = b, d2 = d2_exp(act[[b]], p, va$exposure),
                                                                                pred_vs_actual = sum(p) / sum(act[[b]]))))[, `:=`(valid_year = vy, line = ln, peril = pr)]
      log_msg(vy, " ", ln, "/", pr, ": D2 raw ", round(peril_scores[[k]][basis == "reported_raw", d2], 4),
              ", developed ", round(peril_scores[[k]][basis == "developed", d2], 4))
    }
    for (b in c("pred", "reported_raw", "developed")) set(rp, j = b, value = Reduce(`+`, lapply(PERILS[[ln]], function(pr) rp[[paste0(b, "_", pr)]])))
    rows[[paste(vy, ln)]] <- rp
    rm(tr, va); invisible(gc(verbose = FALSE))
  }
  rm(dt); invisible(gc(verbose = FALSE))
}
line_scores <- mean_scores <- data.table()
if (!SKIP_VALID) {
  peril_scores <- rbindlist(peril_scores); diag_val <- rbindlist(diag_val)
  rp_all <- rbindlist(rows, fill = TRUE)
  write_w2(rp_all, out_path(STEP, "row_preds.parquet"))
  line_scores <- rbindlist(lapply(c("reported_raw", "developed"), function(b) rbind(
    rp_all[, .(d2 = d2_exp(get(b), pred, exposure), pred_vs_actual = sum(pred) / sum(get(b))), by = .(valid_year, line)],
    rp_all[, .(line = "ALL", d2 = d2_exp(get(b), pred, exposure), pred_vs_actual = sum(pred) / sum(get(b))), by = valid_year])[, basis := b]))
  mean_scores <- line_scores[, .(mean_d2 = mean(d2), d2_2023 = d2[valid_year == 2023], d2_2024 = d2[valid_year == 2024]), by = .(basis, line)]
  save_csv(line_scores, STEP, "line_scores.csv"); save_csv(peril_scores, STEP, "peril_scores.csv"); save_csv(diag_val, STEP, "diagnostics_validation.csv")
  log_msg("Developed validation, mean 2023-24 reported_raw D2: ", paste(mean_scores[basis == "reported_raw", sprintf("%s %.4f", line, mean_d2)], collapse = "; "))
}

# 6. Final fit on developed 2021-24; baseline components for every emerging row (SKIP_FINAL=1 for stage A screening) -------
SKIP_FINAL <- Sys.getenv("SKIP_FINAL", "0") == "1" || INFO_ONLY
dir.create(file.path(ITER_DIR, "fitted"), recursive = TRUE, showWarnings = FALSE)
save_art <- function(art, file) { art$m_f <- raw_model(art$m_f); if (identical(art$sev$type, "gbm")) art$sev$model <- raw_model(art$sev$model); saveRDS(art, file) }
load_art <- function(file) { art <- readRDS(file); art$m_f <- load_model(art$m_f); if (identical(art$sev$type, "gbm")) art$sev$model <- load_model(art$sev$model); art }
diag_final <- list(); base_out <- list(train = list(), test = list()); burn <- list(); replication <- list()
if (!SKIP_FINAL) {
for (ln in LINES) {
  tr <- add_extra(load_line("developed", "train", ln), "train", ln)
  em <- list(train = add_extra(load_line("emerging", "train", ln), "train", ln), test = add_extra(load_line("emerging", "test", ln), "test", ln))
  if (POOLED_YEAR) tr <- rbind(tr, copy(em$train)[policy_year <= POOLED_YEAR][, `:=`(row_id = paste0("E_", row_id), policy_id = paste0("E_", policy_id))], fill = TRUE)
  dte <- add_extra(load_line("developed", "test", ln), "test", ln)
  clp_ln <- clp[line == ln]
  outs <- lapply(em, function(d) data.table(row_id = d$row_id, line = ln, exposure = d$exposure))
  for (pr in PERILS[[ln]]) {
    f <- fit_freq_sev(tr, clp_ln, ln, pr, TARGET_YEAR)
    fa <- file.path(ITER_DIR, "fitted", paste0(ln, "_", pr, ".rds"))
    save_art(f$art, fa)
    for (part in names(em)) {
      pp <- predict_parts(f$art, em[[part]])
      set(outs[[part]], j = paste0("bfreq_", pr), value = pp$freq)
      set(outs[[part]], j = paste0("bsev_", pr), value = pp$sev)
      if (part == "test") replication[[paste(ln, pr)]] <- data.table(line = ln, peril = pr,
        max_abs_diff = max(abs(predict_parts(load_art(fa), em$test)$pred - pp$pred)))
    }
    pd <- predict_parts(f$art, dte)$pred
    eb <- function(part) sum(em[[part]]$exposure * outs[[part]][[paste0("bfreq_", pr)]] * outs[[part]][[paste0("bsev_", pr)]]) / sum(em[[part]]$exposure)
    burn[[paste(ln, pr)]] <- data.table(line = ln, peril = pr, developed_test_burn = sum(pd) / sum(dte$exposure),
                                        emerging_train_burn = eb("train"), emerging_test_burn = eb("test"))
    diag_final[[paste(ln, pr)]] <- f$diag
    log_msg("Final ", ln, "/", pr, ": developed 2025 burn ", round(burn[[paste(ln, pr)]]$developed_test_burn, 2),
            ", emerging test burn at developed level ", round(burn[[paste(ln, pr)]]$emerging_test_burn, 2))
  }
  for (part in names(em)) base_out[[part]][[ln]] <- outs[[part]]
  rm(tr, em, dte); invisible(gc(verbose = FALSE))
}
for (part in c("train", "test")) write_w2(rbindlist(base_out[[part]], fill = TRUE), file.path(RT$data, RUN_TAG, sprintf("baseline_emerging_%s.parquet", part)))
diag_final <- rbindlist(diag_final); burn <- rbindlist(burn); replication <- rbindlist(replication)
save_csv(diag_final, STEP, "diagnostics_final.csv"); save_csv(burn, STEP, "baseline_burn.csv"); save_csv(replication, STEP, "replication_check.csv")
if (any(replication$max_abs_diff > 1e-6)) warning("Reloaded models do not reproduce the predictions")
} else { diag_final <- burn <- replication <- data.table(); log_msg("Final fit skipped (", if (INFO_ONLY) "info-only run with developed-only fields" else "SKIP_FINAL=1", ")") }
save_csv(fmap, STEP, "features_used.csv"); save_csv(zr_check, STEP, "structural_zero_check.csv"); save_csv(edit_log, STEP, "workbook_edits.csv")

# 7. Model card and logs -----------------------------------------------------------------------------------------------
card <- c(sprintf("# Week 1 re-tune run `%s` (week 1 C5 engine on emerging-available fields)", RUN_TAG), "",
          sprintf("Run %s, %s bag(s), seed offset %d, workbook `%s` (MD5 `%s`, source copy MD5 `%s`). Run time %.1f min.", ts_sgt(), BAGS, SEED_OFFSET, CFG_FILE,
                  unname(tools::md5sum(CFG_FILE)), unname(tools::md5sum(SRC_XLSX)), as.numeric(difftime(Sys.time(), T0, units = "mins"))), "",
          "## Switches", "", sprintf("- HP: %s", paste(names(HP), unlist(HP), sep = "=", collapse = ", ")),
          sprintf("- FEATURE_ADD: %s; FEATURE_OFF_KEEP=all: %s; MONO_OFF: %s; AGE_BAND_ORD: %s; LOC_ALL: %s; PROXY: %s; TRAIN_FROM: %d; YEAR_WEIGHTS: %s; DOMAIN_W: %s; LINES: %s",
                  paste(FEATURE_ADD, collapse = ","), FEATURE_OFF_KEEP_ALL, MONO_OFF, AGE_BAND_ORD, LOC_ALL, paste(PROXY, collapse = ","), TRAIN_FROM, paste(YEAR_W, collapse = ","), DOMAIN_W, paste(LINES, collapse = ",")),
          sprintf("- SPEC_OVERRIDE rows: %d", nrow(SPEC_OV)), "",
          if (nrow(mean_scores)) c("## Developed validation (week 1 folds; D2 vs one rate per exposure-year)", "",
                                   md_table(dcast(line_scores, basis + valid_year ~ line, value.var = "d2"), 4),
                                   md_table(mean_scores, 4),
                                   "Reference scores: week 1 C5 (all fields, 5 bags, Tweedie for BI / contents EoW) ALL reported_raw 0.1026; week 2 baseline (shared fields, 5 bags) 0.0978.", "",
                                   "## Peril scores (mean 2023-24)", "", md_table(dcast(peril_scores, line + peril ~ basis, value.var = "d2", fun.aggregate = mean), 4)) else "Validation skipped.",
          if (nrow(diag_final)) c("## Final fit diagnostics", "", md_table(diag_final, 3), "## Baseline burn (developed level)", "", md_table(burn, 2)) else character(0),
          "## Workbook edits", "", md_table(edit_log))
writeLines(card, file.path(ITER_DIR, "model_card.md")); track_output(file.path(ITER_DIR, "model_card.md"))

kl <- c(if (nrow(mean_scores)) sprintf("- Developed validation mean 2023-24 D2, reported_raw: %s; developed: %s (week 1 C5 ALL reported_raw 0.1026).",
                                      paste(mean_scores[basis == "reported_raw", sprintf("%s %.4f", line, mean_d2)], collapse = ", "),
                                      paste(mean_scores[basis == "developed", sprintf("%s %.4f", line, mean_d2)], collapse = ", ")),
        if (nrow(replication)) sprintf("- Replication of saved models: max abs diff %.2e.", max(replication$max_abs_diff)),
        if (nrow(burn)) sprintf("- Emerging test burn at developed level, by line: %s.", paste(burn[, .(b = sum(emerging_test_burn)), by = line][, sprintf("%s %.1f", line, b)], collapse = ", ")))
update_step_log(paste0("rt-", RUN_TAG), paste("Retune run", RUN_TAG), kl)
end_script()
