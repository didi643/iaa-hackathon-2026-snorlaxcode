# 07_emerging_adjust.R --------------------------------------------------------------------------------------------
# Purpose : Emerging adjustments on top of the developed baseline, per peril (Option B), plus the two benchmarks.
#   Frequency  Poisson GLM, offset log(baseline frequency x exposure x reported share x frequency trend to the base year).
#              Intercept only first (= the emerging level). Candidate factors are then added ONE AT A TIME (greedy
#              forward, at most MAX_FACTORS), only factors whose step 6 A/E shows a slope for the line, each as banded
#              categories with a ridge penalty (credibility in GLM form: a level with m expected claims keeps about
#              m / (m + LAMBDA) of its own A/E, the rest stays at the developed relativity). A factor is kept only if
#              it lowers the Poisson deviance on 2024 when fitted on 2023 (validation fold).
#   Severity   Gamma level on claims capped at the developed cap x emerging level (iterated), offset log(baseline
#              capped severity x severity trend); factors (same ridge rule) only for perils with >= SEV_FACTOR_MIN claims;
#              sparse heavy perils (buildings fire / flood / subsidence, motor BI, contents flood) level only.
#              Large-loss load = developed load (developed shape x emerging level).
#   Benchmarks E: emerging-only GLMs per peril (ridge Poisson on a fixed factor list, offset exposure x share;
#              severity = emerging mean capped claim x emerging load). L: baseline x per-peril levels, no factors.
#   Fits       (a) validation: fit on emerging 2023, predict 2024 (x 1 year of trend); (b) final: fit on 2023-24,
#              predict the 2025 test rows (trend to 2025 is applied in step 8).
# Inputs  : data/week_2/optionB/features/emerging_{train,test}_<line>.parquet, data/week_2/optionB/baseline/baseline_emerging_{train,test}.parquet,
#           week2/output/04_ibnr_trend/{report_share_quarter,trend_table}.csv, week2/output/05_baseline/diagnostics_final.csv,
#           week2/output/06_ae/ae_slopes.csv, emerging claims
# Outputs : week2/output/07_adjust/ (factor_log.csv, coefficients.csv, levels.csv, adjust_report.md),
#           data/week_2/optionB/adjust/valid_2024_peril.parquet, final_2025_peril.parquet (per row x peril: freq and sev
#           for B, L and E before 2025 loadings)
# Run     : Rscript week2/R/07_emerging_adjust.R      (LAMBDA=..., MAX_FACTORS=... to override)
# Time    : about 2-5 minutes

source("week2/R/00_setup_week2.R")
start_script("07_emerging_adjust.R")
STEP <- "07_adjust"
FEAT_DIR <- file.path(W2$data, "features")
LAMBDA <- as.numeric(Sys.getenv("LAMBDA", "30"))     # 30 since experiment X10 (D029); was 100          # ridge penalty ~ expected claims for 50% credibility
LAMBDA_SEV <- as.numeric(Sys.getenv("LAMBDA_SEV", "30"))  # same for severity (claims)
L1_FACTOR_FREQ <- as.numeric(Sys.getenv("L1_FACTOR_FREQ", "0"))
L1_FACTOR_SEV <- as.numeric(Sys.getenv("L1_FACTOR_SEV", "0"))
MAX_FACTORS <- as.integer(Sys.getenv("MAX_FACTORS", "4"))
K_FREQ_LEVEL <- as.numeric(Sys.getenv("K_FREQ_LEVEL", "200"))   # 200 / 400 since experiment X10 (D029); was 100 / 200   # level credibility: claims for Z = 0.5 (frequency)
K_SEV_LEVEL <- as.numeric(Sys.getenv("K_SEV_LEVEL", "400"))     # severity; x3 for the sparse heavy perils
SEV_FACTOR_MIN <- 1000
LEVEL_ONLY_SEV <- c("buildings fire", "buildings flood", "buildings subsidence", "motor bodily_injury", "contents flood")
TAG <- Sys.getenv("RUN_TAG", "main")
# Experiment switches (improvement round, 25 Oct 2026; each one is gated by 13_compare_runs.R):
X_EXTRA <- Sys.getenv("X_EXTRA", "1") == "1"        # on by default since X1 (D027)        # X1: gender + self_employed offered as candidate factors
X_NEW <- setdiff(strsplit(Sys.getenv("X_NEW", ""), ",")[[1]], "")   # X21: emerging_extra2 fields (03c) offered as candidates, e.g. "credit_tier,region"
X_NEW_SEV <- Sys.getenv("X_NEW_SEV", "1") == "1"    # X21h: 0 = X_NEW fields offered to the frequency selection only (not severity)
X_MIXW <- Sys.getenv("X_MIXW", "0") == "1"          # X2: fit weights = 2025 new-business x channel mix / row-year mix
MIXW_MODE <- Sys.getenv("MIXW_MODE", "mix")         # NB6: "clf" = domain-classifier odds instead of the cell mix (with X_MIXW=1)
K_FREQ_RICH <- as.numeric(Sys.getenv("K_FREQ_RICH", "NA"))   # X3: level credibility K for perils with >= 1000 claims
K_SEV_RICH <- as.numeric(Sys.getenv("K_SEV_RICH", "NA"))
SEV_MODE <- Sys.getenv("SEV_MODE", "offset")        # X4: offset (baseline x level) | emerging (emerging-only GLM) | range (multiplier by baseline-severity band) | power (level x baseline^beta)
# X11 emerging-only severity (no developed severity at all): em_flat (one emerging mean per peril) | em_select (emerging Gamma GLM, factors chosen
# greedily 2023 -> 2024 as for frequency) | em_rich (em_select for perils with >= SEV_FACTOR_MIN claims, flat otherwise)
EM_SEV_STEPS <- as.integer(Sys.getenv("EM_SEV_STEPS", "3"))
SEV_LINES <- strsplit(Sys.getenv("SEV_LINES", "motor,buildings,contents"), ",")[[1]]   # X12: lines where SEV_MODE applies (others keep offset)
SEV_MODE_ALL <- SEV_MODE
SEV_CV <- Sys.getenv("SEV_CV", "0") == "1"           # X14: 5-fold CV (by policy) of severity shape per peril on all 2023-24 claims
SEV_CV_EM <- Sys.getenv("SEV_CV_EM", "x11e_ssel")      # run whose emerging-only severity factors are used in the CV
sev_cv_out <- list()
FREQ_POWER <- Sys.getenv("FREQ_POWER", "0")          # X15: frequency range multiplier, level x baseline^beta: 0 | force (slope always in) | cand (offered to the greedy step)
FREQ_POWER_PERILS <- Sys.getenv("FREQ_POWER_PERILS", "")   # "line/peril,..." to restrict; empty = all perils
K_SEV_PERIL <- Sys.getenv("K_SEV_PERIL", "")         # X16: per-peril severity level credibility, "line/peril=K,..."
# X19 credibility models for the peril level (26 Oct 2026). Every model is expressed as a per-peril, per-window K for the
# intercept penalty, so the peril keeps Z = n / (n + K) of its own log level and 1 - Z of the line pool:
#   ridge   fixed K (K_FREQ_LEVEL / K_SEV_LEVEL, x3 for LEVEL_ONLY_SEV) - the current model
#   lf      limited fluctuation (classical): Z = min(1, sqrt(n / n_full)), n_full = lambda0 x phi (frequency) or lambda0 x CV^2
#           (severity), lambda0 = (z_(1+LF_P)/2 / LF_K)^2 (1082 at 90% / 5%); K = n (1 - Z) / Z
#   bs      empirical Buhlmann-Straub per peril on the log level: K_i = (EPV_i + n_i x BS_TAU2) / VHM, EPV_i = Pearson dispersion
#           phi_i (frequency, per expected claim) or CV_i^2 (severity, per claim); VHM = between-peril variance of the log
#           level around the line pool (unbiased estimator, net of process variance and of BS_TAU2), estimated per line
#   bs_pool as bs, VHM pooled over the 15 perils (deviations from each line's pool)
# All parameters are estimated on the fitting window only (2023 for the validation fit, 2023-24 for the final fit).
CRED_MODEL <- Sys.getenv("CRED_MODEL", "ridge")
LF_P <- as.numeric(Sys.getenv("LF_P", "0.90")); LF_K <- as.numeric(Sys.getenv("LF_K", "0.05"))
BS_TAU2 <- Sys.getenv("BS_TAU2", "0")                # year-to-year drift variance of the true log level: one value or "motor=..,buildings=..,contents=.."
BS_TAU2_SEV <- Sys.getenv("BS_TAU2_SEV", BS_TAU2)     # the same for the severity level (default = frequency value)
tau_of <- function(spec, ln) { if (!grepl("=", spec)) return(rep(as.numeric(spec), length(ln))); kv <- strsplit(strsplit(spec, ",")[[1]], "=")
  m <- setNames(as.numeric(sapply(kv, `[`, 2)), sapply(kv, `[`, 1)); unname(m[ln]) }
BS_VHM_MULT <- as.numeric(Sys.getenv("BS_VHM_MULT", "1"))   # sensitivity: VHM x this (K / this)
JEWELL_K <- Sys.getenv("JEWELL_K", "0")              # hierarchical (Jewell): line pool credibility-weighted towards the developed level (log 0): 0 off | est | K
K_ALL <- as.numeric(Sys.getenv("K_ALL", "NA"))       # grid: one K for frequency and severity level, every peril (no x3)
K_ALL_F <- as.numeric(Sys.getenv("K_ALL_F", "NA")); K_ALL_S <- as.numeric(Sys.getenv("K_ALL_S", "NA"))   # grid: frequency / severity only
K_FREQ_PERIL <- Sys.getenv("K_FREQ_PERIL", "")       # "line/peril=K,..." frequency level K per peril (overrides the model)
K_MAX <- 1e6                                         # K for "no own credibility" (VHM <= 0)
CENTER <- Sys.getenv("CENTER", "0") == "1"           # X19: factor dummies centred (weighted mean 0) so the level sits only in the credibility-weighted intercept
# X20 cat perils: frequency level complement = developed long-run level (CAT_PRIOR=dev, log 0) or the line's attritional
# (non-cat) emerging pool (CAT_PRIOR=attr) instead of the whole line pool, with frequency level K = CAT_K
CAT_PERILS <- strsplit(Sys.getenv("CAT_PERILS", ""), ",")[[1]]; CAT_PRIOR <- Sys.getenv("CAT_PRIOR", "dev"); CAT_K <- as.numeric(Sys.getenv("CAT_K", "NA"))
cred_out <- list()
FREQ_MODE <- Sys.getenv("FREQ_MODE", "adjust")      # X11: adjust (baseline x emerging level x factors) | developed (baseline only, no emerging data) | level (baseline x level, no factors)
X_BOOST <- Sys.getenv("X_BOOST", "0") == "1"        # X5: shallow xgboost on the emerging frequency residual (base margin = B)
SEV_E_FACTORS <- list(motor = c("vehicle_value_group_b", "driver_age_band", "cover_type", "vehicle_age_b", "voluntary_excess"),
                      buildings = c("sum_insured_b", "property_type", "construction_type", "voluntary_excess"),
                      contents = c("sum_insured_b", "high_value_items", "voluntary_excess", "tenure"))

shares <- load_report_shares()
trend <- fread(file.path(W2$output, "04_ibnr_trend", "trend_table.csv")); track_input(file.path(W2$output, "04_ibnr_trend", "trend_table.csv"))
trend <- trend_mode(trend)   # X20
TREND_FLOOR_FREQ <- Sys.getenv("TREND_FLOOR_FREQ", "")   # X18: lines whose chosen frequency trend is floored at 0 (e.g. "motor")
if (nzchar(TREND_FLOOR_FREQ)) trend[line %in% strsplit(TREND_FLOOR_FREQ, ",")[[1]], freq_trend_chosen := pmax(freq_trend_chosen, 0)]
DIAG_F <- if (nzchar(BASE_DIAG_DIR)) file.path(BASE_DIAG_DIR, "diagnostics_final.csv") else file.path(W2$output, if (BASE_TAG == "baseline") "05_baseline" else paste0("05_", BASE_TAG), "diagnostics_final.csv")
diag <- fread(DIAG_F); track_input(DIAG_F)
slopes <- fread(file.path(W2$output, "06_ae", "ae_slopes.csv")); track_input(file.path(W2$output, "06_ae", "ae_slopes.csv"))
clp <- claim_basis("emerging")
base <- list(train = read_w2(file.path(BASE_DIR, BASE_TAG, "baseline_emerging_train.parquet")),
             test = read_w2(file.path(BASE_DIR, BASE_TAG, "baseline_emerging_test.parquet")))

# Candidate factors per line (banded); E benchmark factor lists ---------------------------------------------------------
CANDIDATES <- list(
  motor = c("driver_age_band", "cover_type", "new_business", "channel", "vehicle_use", "overnight_parking", "urban_density",
            "named_young_driver", "fuel_type", "body_type", "occupation", "self_employed", "marital_status", "payment_method",
            "ncb_years_b", "renewal_count_b", "vehicle_value_group_b", "vehicle_age_b", "voluntary_excess", "hail_days_b",
            "freezing_days_b", "rainfall_mm_b", "years_licensed_b", "hist_policy_claims_prev", "licence_points_b"),
  buildings = c("policyholder_age_band", "construction_type", "new_business", "channel", "property_type", "urban_density", "occupancy",
                "flood_zone", "soil_type", "roof_type", "basement", "trees_within_5m", "occupation", "self_employed", "sum_insured_b",
                "voluntary_excess", "wind_exposure_index_b", "wildfire_index_b", "rainfall_mm_b", "dry_summer_index_b", "hail_days_b", "renewal_count_b"),
  contents = c("policyholder_age_band", "tenure", "new_business", "channel", "security_level", "property_type", "urban_density",
               "flood_zone", "occupation", "self_employed", "sum_insured_b", "high_value_items", "voluntary_excess", "works_from_home",
               "lodgers", "bicycle_cover", "rainfall_mm_b", "renewal_count_b"))
E_FACTORS <- list(
  motor = c("driver_age_band", "cover_type", "new_business", "ncb_years_b", "vehicle_value_group_b", "urban_density", "voluntary_excess",
            "vehicle_use", "named_young_driver", "hail_days_b"),
  buildings = c("policyholder_age_band", "construction_type", "new_business", "property_type", "flood_zone", "soil_type",
                "sum_insured_b", "voluntary_excess", "wind_exposure_index_b", "accidental_damage_cover"),
  contents = c("policyholder_age_band", "tenure", "new_business", "security_level", "sum_insured_b", "voluntary_excess",
               "accidental_damage_cover", "urban_density", "flood_zone"))
BAND_VARS <- c("ncb_years", "renewal_count", "vehicle_value_group", "vehicle_age", "years_licensed", "licence_points", "sum_insured",
               "hail_days", "freezing_days", "rainfall_mm", "wind_exposure_index", "wildfire_index", "dry_summer_index")

# Load and band (band edges from emerging training quintiles, applied to test) -----------------------------------------
load_em <- function(ln) {
  tr <- read_w2(file.path(FEAT_DIR, sprintf("emerging_train_%s.parquet", ln)))
  te <- read_w2(file.path(FEAT_DIR, sprintf("emerging_test_%s.parquet", ln)))
  bandit <- function(x, br) { x <- as.character(cut(as.numeric(x), br, dig.lab = 5)); x[is.na(x)] <- "missing"; x }
  for (v in intersect(BAND_VARS, names(tr))) {
    br <- unique(quantile(as.numeric(tr[[v]]), seq(0, 1, 0.2), na.rm = TRUE)); br[1] <- -Inf; br[length(br)] <- Inf
    set(tr, j = paste0(v, "_b"), value = bandit(tr[[v]], br))
    set(te, j = paste0(v, "_b"), value = bandit(te[[v]], br))
  }
  hist_cat <- function(x) { x <- as.character(pmin(x, 2)); x[is.na(x)] <- "none"; x }
  set(tr, j = "hist_policy_claims_prev", value = hist_cat(tr$hist_policy_claims_prev))
  set(te, j = "hist_policy_claims_prev", value = hist_cat(te$hist_policy_claims_prev))
  tr <- merge(tr, base$train[line == ln, !c("line", "exposure")], by = "row_id")
  te <- merge(te, base$test[line == ln, !c("line", "exposure")], by = "row_id")
  if (X_EXTRA) {
    tr <- merge(tr, read_w2(file.path(FEAT_DIR, sprintf("emerging_extra_train_%s.parquet", ln)))[, .(row_id, gender)], by = "row_id")
    te <- merge(te, read_w2(file.path(FEAT_DIR, sprintf("emerging_extra_test_%s.parquet", ln)))[, .(row_id, gender)], by = "row_id")
  }
  if (length(X_NEW)) {
    x2 <- lapply(c(train = "train", test = "test"), function(p) read_w2(file.path(FEAT_DIR, sprintf("emerging_extra2_%s_%s.parquet", p, ln))))
    keep <- intersect(X_NEW, names(x2$train))
    if (length(keep)) {
      tr <- merge(tr, x2$train[, c("row_id", keep), with = FALSE], by = "row_id")
      te <- merge(te, x2$test[, c("row_id", keep), with = FALSE], by = "row_id")
    }
  }
  # 2025-mix weight per row: test exposure share of its new-business x channel cell / that cell's share in the row's year
  mix <- te[, .(e = sum(exposure)), by = .(new_business, channel)][, s_test := e / sum(e)]
  cy <- tr[, .(e = sum(exposure)), by = .(policy_year, new_business, channel)][, s := e / sum(e), by = policy_year]
  cy <- merge(cy, mix[, .(new_business, channel, s_test)], by = c("new_business", "channel"))[, wm := s_test / s]
  tr <- merge(tr, cy[, .(policy_year, new_business, channel, wm)], by = c("policy_year", "new_business", "channel"), all.x = TRUE)
  tr[is.na(wm), wm := 1]
  if (MIXW_MODE == "clf") {   # NB6: covariate-shift weights = odds of an exposure-weighted logistic domain classifier (2025 test vs training)
    cf <- intersect(c(CANDIDATES[[ln]], "start_month"), names(te))
    st <- rbind(tr[, c(cf, "exposure"), with = FALSE][, y__ := 0], te[, c(cf, "exposure"), with = FALSE][, y__ := 1])
    for (f in cf) set(st, j = f, value = factor(fifelse(is.na(st[[f]]), "missing", as.character(st[[f]]))))
    g <- suppressWarnings(glm(y__ ~ . - exposure, data = st, family = binomial(), weights = exposure))
    p <- predict(g, st[y__ == 0], type = "response")
    tr[, wc := pmin(pmax(p / (1 - p), 0.05), 20)]
    tr[, wm := wc / weighted.mean(wc, exposure), by = policy_year][, wc := NULL]
    log_msg(sprintf("%s: classifier weights - range %.2f-%.2f, ESS share %.2f", ln, min(tr$wm), max(tr$wm), sum(tr$wm)^2 / sum(tr$wm^2) / nrow(tr)))
  }
  list(train = tr, test = te)
}

# Penalised GLM by IRLS (log link). Columns of X: intercept (unpenalised) + penalised dummies -------------------------------
design <- function(d, factors, ref = NULL) {
  cols <- list(); map <- list()
  for (f in factors) {
    if (startsWith(f, "num:")) { cols[[f]] <- as.numeric(d[[sub("^num:", "", f)]]); map[[f]] <- "num"; next }   # numeric slope (X4c)
    v <- as.character(d[[f]]); v[is.na(v)] <- "missing"
    lv <- if (is.null(ref)) sort(unique(v)) else ref[[f]]
    for (l in lv) { cols[[paste0(f, "=", l)]] <- as.numeric(v == l) }
    map[[f]] <- lv
  }
  X <- if (length(cols)) cbind(`(Intercept)` = 1, do.call(cbind, cols)) else matrix(1, nrow(d), 1, dimnames = list(NULL, "(Intercept)"))
  list(X = X, levels = map)
}
# b0 / pen0: credibility on the level - the intercept is pulled towards b0 (the line's pooled log level) with weight
# pen0 (expected claims), so the level keeps Z = n / (n + pen0) of its own estimate.
pglm <- function(X, y, offset, family = c("poisson", "gamma"), lambda = 0, w = rep(1, length(y)), maxit = 50, b0 = 0, pen0 = 0) {
  family <- match.arg(family)
  p <- ncol(X); pen <- c(pen0, rep(lambda, p - 1)); beta <- numeric(p); prior <- c(b0, rep(0, p - 1))
  beta[1] <- log(sum(w * y) / sum(w * exp(offset)))
  for (it in seq_len(maxit)) {
    eta <- drop(X %*% beta) + offset; mu <- exp(eta)
    if (family == "poisson") { W <- w * mu; z <- eta - offset + (y - mu) / mu }
    else { W <- w; z <- eta - offset + (y - mu) / mu }
    XtW <- t(X * W)
    A <- XtW %*% X + diag(pen, p); rhs <- XtW %*% z + pen * prior
    if (CENTER && pen0 > 0) for (g in split(seq_len(p)[-1], sub("=.*$", "", colnames(X)[-1]))) {   # X19: weighted mean of a factor's dummies = 0
      v <- numeric(p); v[g] <- colSums(X[, g, drop = FALSE] * W) / sum(W); A <- A + 1e6 * tcrossprod(v)
    }
    nb <- tryCatch(solve(A, rhs), error = function(e) MASS_ginv(A) %*% rhs)
    nb <- drop(nb)
    if (max(abs(nb - beta)) < 1e-8) { beta <- nb; break }
    beta <- nb
  }
  l1 <- if (family == "poisson") L1_FACTOR_FREQ else L1_FACTOR_SEV
  if (l1 > 0 && p > 1) beta[-1] <- sign(beta[-1]) * pmax(abs(beta[-1]) - l1, 0)
  setNames(beta, colnames(X))
}
MASS_ginv <- function(A) { s <- svd(A); d <- ifelse(s$d > 1e-10 * max(s$d), 1 / s$d, 0); s$v %*% (d * t(s$u)) }
pois_dev <- function(y, mu) 2 * sum(ifelse(y > 0, y * log(y / mu), 0) - (y - mu))
gamma_dev <- function(y, mu) 2 * sum(-log(y / mu) + (y - mu) / mu)

# Per peril ----------------------------------------------------------------------------------------------------------------
factor_log <- list(); coefs <- list(); levels_tab <- list(); valid_out <- list(); final_out <- list(); insample_out <- list(); insample23_out <- list()
# Level statistics per peril and fitting window: claims n, baseline expected e, capped claims sc vs baseline sb, and (X19)
# the process variance per claim - Pearson dispersion phi of the claim counts and CV^2 of capped claims / level x baseline
line_pri <- function(ln, tr_all) rbindlist(lapply(PERILS[[ln]], function(pr) {
  tt <- trend[line == ln & peril == pr]; ld <- diag[line == ln & peril == pr]
  x <- tr_all[, .(row_id, policy_year, exposure, bf = get(paste0("bfreq_", pr)), bsc = get(paste0("bsev_", pr)) / ld$cap_load)]
  x[, share := row_report_share(shares, ln, pr, tr_all$period_start, tr_all$period_end)]
  c1 <- merge(clp[line == ln & peril == pr, .(row_id, cost, loss_year)], x[, .(row_id, bsc)], by = "row_id")
  rbindlist(lapply(c(2023L, 2024L), function(by) {
    yrs <- if (by == 2023L) 2023L else 2023:2024
    xx <- x[policy_year %in% yrs & bf > 0]; cc <- c1[loss_year %in% yrs]
    e <- xx[, sum(bf * exposure * share * (1 + tt$freq_trend_chosen)^(policy_year - by))]
    nr <- c1[row_id %chin% xx$row_id, .N, by = row_id]; xx[nr, on = "row_id", nn := i.N]; xx[is.na(nn), nn := 0]
    xx[, mu := bf * exposure * share * (1 + tt$freq_trend_chosen)^(policy_year - by) * sum(nn) / e]
    y <- cc[, pmin(cost * (1 + tt$sev_trend_chosen)^(by - loss_year), ld$cap)]
    L <- sum(y) / sum(cc$bsc)
    data.table(line = ln, peril = pr, window = by, n = cc[, .N], e = e, sc = sum(y), sb = sum(cc$bsc),
               phi = xx[, sum((nn - mu)^2 / mu) / (.N - 1)], cv2 = if (length(y) > 1) sum((y / (L * cc$bsc) - 1)^2) / (length(y) - 1) else NA_real_)
  }))
}))
# Between-peril variance (VHM) of the log level around the line pool, Buhlmann-Straub unbiased form with claim weights:
#   E[sum n_i (l_i - lbar)^2] = VHM (N - sum n_i^2 / N) + sum EPV_i (1 - n_i / N)
bs_parts <- function(p, l, epv) p[, {
  N <- sum(n); lb <- sum(n * get(l)) / N
  .(num = sum(n * (get(l) - lb)^2) - sum(get(epv) * (1 - n / N)), den = N - sum(n^2) / N)
}, by = .(line, window)]
cred_K <- function(p, l, epv, pool, tau_spec) {   # K per peril and window for CRED_MODEL bs / bs_pool / lf
  if (CRED_MODEL == "lf") {
    lam0 <- (qnorm((1 + LF_P) / 2) / LF_K)^2
    return(p[, .(line, peril, window, K = { z <- pmin(1, sqrt(n / (lam0 * get(epv)))); fifelse(z >= 1, 0, n * (1 - z) / pmax(z, 1e-9)) })])
  }
  pt <- bs_parts(p, l, epv)
  vhm <- if (pool) pt[, .(vhm = sum(num) / sum(den)), by = window] else pt[, .(line, window, vhm = num / den)]
  q <- merge(p, vhm, by = intersect(names(vhm), c("line", "window")))
  q[, tau2 := tau_of(tau_spec, line)]
  if (pool) q[, vhm_net := (vhm - sum(n * tau2) / sum(n)) * BS_VHM_MULT, by = window] else q[, vhm_net := (vhm - tau2) * BS_VHM_MULT]
  q[, .(line, peril, window, vhm = vhm_net, K = fifelse(vhm_net > 0, pmin(K_MAX, (get(epv) + n * tau2) / vhm_net), K_MAX))]
}
dd_all <- setNames(lapply(LINES, load_em), LINES)
pri_all <- rbindlist(lapply(LINES, function(ln) line_pri(ln, dd_all[[ln]]$train)))
pri_all[, `:=`(lf = log(n / e), ls = fifelse(n > 0, log(sc / sb), NA_real_))]
kmod <- NULL
if (CRED_MODEL %in% c("lf", "bs", "bs_pool")) {
  kmod <- merge(cred_K(pri_all, "lf", "phi", CRED_MODEL == "bs_pool", BS_TAU2)[, .(line, peril, window, vhm_f = if (CRED_MODEL == "lf") NA_real_ else vhm, K_f = K)],
                cred_K(pri_all[n > 1], "ls", "cv2", CRED_MODEL == "bs_pool", BS_TAU2_SEV)[, .(line, peril, window, vhm_s = if (CRED_MODEL == "lf") NA_real_ else vhm, K_s = K)],
                by = c("line", "peril", "window"), all.x = TRUE)
  kmod[is.na(K_s), K_s := K_MAX]
}
# Jewell: the line pool itself gets Z_L = N_L / (N_L + K_L) towards the developed level (log 0); "est": K_L = mean EPV / VHM
# between lines (known mean 0: E[N_L b_L^2] = N_L VHM + EPV)
jw <- pri_all[, .(N = sum(n), bf = log(sum(n) / sum(e)), bs = sum(n * ls, na.rm = TRUE) / sum(n), phi = sum(n * phi) / sum(n), cv2 = sum(n * cv2, na.rm = TRUE) / sum(n)), by = .(line, window)]
if (JEWELL_K != "0") {
  if (JEWELL_K == "est") {
    jw[, `:=`(vf = (sum(N * bf^2) - sum(phi)) / sum(N), vs = (sum(N * bs^2) - sum(cv2)) / sum(N)), by = window]
    jw[, `:=`(KLf = fifelse(vf > 0, phi / vf, K_MAX), KLs = fifelse(vs > 0, cv2 / vs, K_MAX))]
  } else jw[, `:=`(KLf = as.numeric(JEWELL_K), KLs = as.numeric(JEWELL_K))]
  jw[, `:=`(ZLf = N / (N + KLf), ZLs = N / (N + KLs))]
}

for (ln in LINES) {
  SEV_MODE <- if (ln %in% SEV_LINES) SEV_MODE_ALL else "offset"
  dd <- dd_all[[ln]]
  tr_all <- dd$train; te <- dd$test
  cand_line <- intersect(CANDIDATES[[ln]], slopes[line == ln & slope %in% c("yes", "weak"), factor])
  cand_line <- union("new_business", cand_line)
  if (X_EXTRA) cand_line <- union(cand_line, c("gender", "self_employed"))
  if (length(X_NEW)) cand_line <- union(cand_line, intersect(X_NEW, names(tr_all)))   # X21
  # Level priors: the line's pooled frequency and severity level vs the baseline (all perils), per fitting window
  pri <- pri_all[line == ln]
  prior_f <- pri[, .(b = log(sum(n) / sum(e))), by = window]; # severity prior = claim-weighted mean of the perils' log levels (a cost-weighted pool would let one heavy peril, e.g.
  # buildings fire, set the prior for all the others)
  prior_s <- pri[n > 0, .(b = sum(n * log(sc / sb)) / sum(n)), by = window]
  if (JEWELL_K != "0") {
    prior_f[jw[line == ln], on = "window", b := b * i.ZLf]; prior_s[jw[line == ln], on = "window", b := b * i.ZLs]
  }
  for (pr in PERILS[[ln]]) {
    key <- paste(ln, pr)
    pf <- copy(prior_f); is_cat <- paste(ln, pr, sep = "/") %in% CAT_PERILS   # X20
    if (is_cat) pf[, b := if (CAT_PRIOR == "dev") 0 else pri[!paste(ln, peril, sep = "/") %in% CAT_PERILS][, .(b = log(sum(n) / sum(e))), by = window][pf, on = "window", b]]
    tt <- trend[line == ln & peril == pr]; gf <- tt$freq_trend_chosen; gs <- tt$sev_trend_chosen
    capd <- diag[line == ln & peril == pr, cap]; load <- diag[line == ln & peril == pr, cap_load]
    bf <- paste0("bfreq_", pr); bs <- paste0("bsev_", pr)
    cl <- clp[line == ln & peril == pr]
    mk <- function(d, with_share = TRUE) {
      x <- d[, .(row_id, policy_id, policy_year, exposure, bfreq = get(bf), bsev_c = get(bs) / load)]
      x[, share := if (with_share) row_report_share(shares, ln, pr, d$period_start, d$period_end) else 1]
      x
    }
    # rows with a zero baseline (structural zero) are excluded from fitting and predicted 0
    trr <- mk(tr_all); ok_tr <- trr$bfreq > 0
    trr[, wfit := if (X_MIXW) tr_all$wm else 1]
    n_all_claims <- cl[row_id %chin% trr$row_id, .N]
    kf <- if (!is.na(K_FREQ_RICH) && n_all_claims >= 1000) K_FREQ_RICH else K_FREQ_LEVEL
    ks <- if (!is.na(K_SEV_RICH) && n_all_claims >= 1000) K_SEV_RICH else K_SEV_LEVEL * if (key %in% LEVEL_ONLY_SEV) 3 else 1
    kf <- c(`2023` = kf, `2024` = kf); ks <- c(`2023` = ks, `2024` = ks)   # X19: K per fitting window
    if (!is.null(kmod)) { km <- kmod[line == ln & peril == pr][order(window)]; kf[] <- km$K_f; ks[] <- km$K_s }
    if (!is.na(K_ALL)) { kf[] <- K_ALL; ks[] <- K_ALL }
    if (!is.na(K_ALL_F)) kf[] <- K_ALL_F; if (!is.na(K_ALL_S)) ks[] <- K_ALL_S
    if (nzchar(K_SEV_PERIL)) for (kv in strsplit(K_SEV_PERIL, ",")[[1]]) { kk <- strsplit(kv, "=")[[1]]; if (kk[1] == paste(ln, pr, sep = "/")) ks[] <- as.numeric(kk[2]) }
    if (is_cat && !is.na(CAT_K)) kf[] <- CAT_K
    if (nzchar(K_FREQ_PERIL)) for (kv in strsplit(K_FREQ_PERIL, ",")[[1]]) { kk <- strsplit(kv, "=")[[1]]; if (kk[1] == paste(ln, pr, sep = "/")) kf[] <- as.numeric(kk[2]) }
    pp <- pri[peril == pr][order(window)]
    cred_out[[key]] <- data.table(line = ln, peril = pr, window = pp$window, claims = pp$n, phi = pp$phi, cv2 = pp$cv2,
                                  own_freq_level = pp$n / pp$e, own_sev_level = pp$sc / pp$sb, K_freq = kf, K_sev = ks,
                                  Z_freq = pp$n / (pp$n + kf), Z_sev = pp$n / (pp$n + ks))
    fp_on <- FREQ_POWER != "0" && (!nzchar(FREQ_POWER_PERILS) || paste(ln, pr, sep = "/") %in% strsplit(FREQ_POWER_PERILS, ",")[[1]])
    if (fp_on) {                          # X15: log baseline frequency relative to its exposure-weighted mean -> slope (beta - 1), ridge-shrunk to 0
      okb <- tr_all[[bf]] > 0
      mlf <- sum(log(tr_all[[bf]][okb]) * tr_all$exposure[okb]) / sum(tr_all$exposure[okb])
      set(tr_all, j = "lbfreq", value = log(pmax(tr_all[[bf]], 1e-12)) - mlf)
      set(te, j = "lbfreq", value = log(pmax(te[[bf]], 1e-12)) - mlf)
    }
    cand_p <- if (fp_on && FREQ_POWER == "cand") c(cand_line, "num:lbfreq") else cand_line
    if (SEV_MODE == "power") {            # X4c: log of the baseline severity relative to its claim mean -> slope beta
      mlog <- mean(log(trr[cl[, .(row_id)], on = "row_id", bsev_c]), na.rm = TRUE)
      set(tr_all, j = "lbsev", value = log(pmax(trr$bsev_c, 1e-9)) - mlog)
      set(te, j = "lbsev", value = log(pmax(te[[bs]] / load, 1e-9)) - mlog)
    }
    if (SEV_MODE == "range") {            # band of the baseline severity (quintiles over this peril's emerging claims)
      bsc_cl <- trr[cl[, .(row_id)], on = "row_id", bsev_c]
      br <- unique(quantile(bsc_cl, seq(0, 1, 0.2), na.rm = TRUE)); br[1] <- -Inf; br[length(br)] <- Inf
      set(tr_all, j = "sevband", value = as.character(cut(trr$bsev_c, br)))
      set(te, j = "sevband", value = as.character(cut(te[[bs]] / load, br)))
    }
    n_by <- cl[, .N, by = row_id]; trr[n_by, on = "row_id", n := i.N]; trr[is.na(n), n := 0]
    # ---- frequency ----
    fit_freq <- function(rows, factors, base_year, lambda = LAMBDA) {
      d <- trr[rows]; feat <- tr_all[rows]
      off <- log(d$bfreq * d$exposure * d$share * (1 + gf)^(d$policy_year - base_year))
      ds <- design(feat, factors)
      list(beta = pglm(ds$X, d$n, off, "poisson", lambda, w = d$wfit, b0 = pf[window == base_year, b], pen0 = kf[[as.character(base_year)]]),
           levels = ds$levels, factors = factors, base_year = base_year)
    }
    pred_freq <- function(fit, d, feat, year) {   # ultimate frequency per exposure-year at `year`
      ds <- design(feat, fit$factors, fit$levels)
      d$bfreq * exp(drop(ds$X %*% fit$beta[colnames(ds$X)])) * (1 + gf)^(year - fit$base_year)
    }
    r23 <- which(ok_tr & trr$policy_year == 2023); r24 <- which(ok_tr & trr$policy_year == 2024); rall <- which(ok_tr)
    vdev <- function(fit) { mu <- pred_freq(fit, trr[r24], tr_all[r24], 2024) * trr$exposure[r24] * trr$share[r24]
                            w <- trr$wfit[r24]; 2 * sum(w * (ifelse(trr$n[r24] > 0, trr$n[r24] * log(trr$n[r24] / mu), 0) - (trr$n[r24] - mu))) }
    f0 <- fit_freq(r23, character(0), 2023); dev0 <- vdev(f0)
    chosen <- character(0); cur_dev <- dev0
    factor_log[[paste(key, "level")]] <- data.table(line = ln, peril = pr, part = "freq", step = 0, factor = "(level)", valid_dev = dev0,
                                                    gain = NA_real_, decision = "kept", claims_2023 = sum(trr$n[r23]), claims_2024 = sum(trr$n[r24]))
    if (sum(trr$n[r23]) >= 30) for (s in seq_len(MAX_FACTORS)) {
      tries <- rbindlist(lapply(setdiff(cand_p, chosen), function(f) {
        fi <- fit_freq(r23, c(chosen, f), 2023); data.table(factor = f, dev = vdev(fi))
      }))
      if (!nrow(tries)) break
      best <- tries[which.min(dev)]
      for (i in seq_len(nrow(tries))) factor_log[[paste(key, "f", s, tries$factor[i])]] <- data.table(line = ln, peril = pr, part = "freq", step = s,
        factor = tries$factor[i], valid_dev = tries$dev[i], gain = cur_dev - tries$dev[i],
        decision = fifelse(tries$factor[i] == best$factor & best$dev < cur_dev - 1, "kept", "rejected"),
        claims_2023 = sum(trr$n[r23]), claims_2024 = sum(trr$n[r24]))
      if (best$dev < cur_dev - 1) { chosen <- c(chosen, best$factor); cur_dev <- best$dev } else break
    }
    if (fp_on && FREQ_POWER == "force") chosen <- union("num:lbfreq", chosen)
    fv_B <- fit_freq(r23, chosen, 2023); fv_L <- f0
    ff_B <- fit_freq(rall, chosen, 2024); ff_L <- fit_freq(rall, character(0), 2024)
    # Benchmark E frequency: emerging only, offset exposure x share
    fit_E <- function(rows, base_year) {
      d <- trr[rows]; feat <- tr_all[rows]
      fac <- intersect(E_FACTORS[[ln]], names(feat))
      off <- log(d$exposure * d$share * (1 + gf)^(d$policy_year - base_year))
      ds <- design(feat, fac)
      list(beta = pglm(ds$X, d$n, off, "poisson", 30), levels = ds$levels, factors = fac, base_year = base_year)
    }
    pred_E <- function(fit, d, feat, year) { ds <- design(feat, fit$factors, fit$levels); exp(drop(ds$X %*% fit$beta[colnames(ds$X)])) * (1 + gf)^(year - fit$base_year) }
    fvE <- fit_E(which(trr$policy_year == 2023 & ok_tr), 2023); ffE <- fit_E(rall, 2024)
    # ---- severity ----
    sc <- merge(cl[, .(row_id, cost, loss_year)], trr[, .(row_id, bsev_c, wfit)], by = "row_id")
    sc <- merge(sc, tr_all[, unique(intersect(c("row_id", cand_line, SEV_E_FACTORS[[ln]], "sevband", "lbsev"), names(tr_all))), with = FALSE], by = "row_id")
    sev_factors_ok <- !(key %in% LEVEL_ONLY_SEV) && nrow(sc) >= SEV_FACTOR_MIN
    fit_sev <- function(rows, factors, base_year) {
      d <- sc[rows]
      L <- sum(d$cost) / sum(d$bsev_c * (1 + gs)^(base_year - d$loss_year))   # start level
      for (it in 1:5) {                                                         # cap = developed cap x level
        y <- pmin(d$cost * (1 + gs)^(base_year - d$loss_year), capd * L)
        L <- sum(y) / sum(d$bsev_c)
      }
      ds <- design(d, factors)
      if (isTRUE(emerging_only)) {         # X4 emerging: no baseline offset, own factors, unpenalised intercept
        beta <- pglm(ds$X, y, rep(0, nrow(d)), "gamma", LAMBDA_SEV, w = d$wfit)
      } else {
        beta <- pglm(ds$X, y, log(d$bsev_c), "gamma", LAMBDA_SEV, w = d$wfit, b0 = prior_s[window == base_year, b], pen0 = ks[[as.character(base_year)]])
      }
      list(beta = beta, levels = ds$levels, factors = factors, base_year = base_year, level_cap = L, emerging_only = isTRUE(emerging_only),
           emerging_load = sum(d$cost * (1 + gs)^(base_year - d$loss_year)) / sum(y))
    }
    pred_sev <- function(fit, d, feat, year) { ds <- design(feat, fit$factors, fit$levels)
      (if (fit$emerging_only) 1 else d$bsev_c) * exp(drop(ds$X %*% fit$beta[colnames(ds$X)])) * load * (1 + gs)^(year - fit$base_year) }
    emerging_only <- FALSE
    s23 <- which(sc$loss_year == 2023); sall <- seq_len(nrow(sc))
    sv_L <- fit_sev(s23, character(0), 2023); sf_L <- fit_sev(sall, character(0), 2024)
    sev_chosen <- character(0)
    em_sel <- SEV_MODE %in% c("em_select", "em_rich")
    if (em_sel) { emerging_only <- TRUE; sev_factors_ok <- nrow(sc) >= (if (SEV_MODE == "em_rich") SEV_FACTOR_MIN else 30) }
    if (sev_factors_ok) {
      s24 <- which(sc$loss_year == 2024)
      sdev <- function(fit) { mu <- pred_sev(fit, sc[s24], sc[s24], 2024) / load; gamma_dev(pmin(sc$cost[s24], capd * fit$level_cap), mu) }
      cur <- sdev(if (em_sel) fit_sev(s23, character(0), 2023) else sv_L)
      for (s in seq_len(if (em_sel) EM_SEV_STEPS else 2)) {
        cand_s <- if (X_NEW_SEV) cand_line else setdiff(cand_line, X_NEW)   # X21h: new fields offered to frequency only
        tries <- rbindlist(lapply(setdiff(if (em_sel) union(cand_s, intersect(SEV_E_FACTORS[[ln]], names(sc))) else cand_s, sev_chosen), function(f) data.table(factor = f, dev = sdev(fit_sev(s23, c(sev_chosen, f), 2023)))))
        best <- tries[which.min(dev)]
        for (i in seq_len(nrow(tries))) factor_log[[paste(key, "s", s, tries$factor[i])]] <- data.table(line = ln, peril = pr, part = "sev", step = s,
          factor = tries$factor[i], valid_dev = tries$dev[i], gain = cur - tries$dev[i],
          decision = fifelse(tries$factor[i] == best$factor & best$dev < cur - 1, "kept", "rejected"), claims_2023 = length(s23), claims_2024 = length(s24))
        if (best$dev < cur - 1) { sev_chosen <- c(sev_chosen, best$factor); cur <- best$dev } else break
      }
    }
    if (SEV_MODE == "range") sev_chosen <- union("sevband", sev_chosen)
    if (SEV_MODE == "power") sev_chosen <- union("num:lbsev", sev_chosen)
    if (SEV_MODE == "emerging") { emerging_only <- TRUE; sev_chosen <- intersect(SEV_E_FACTORS[[ln]], names(sc)) }
    if (SEV_MODE %in% c("em_flat", "em_select", "em_rich")) emerging_only <- TRUE   # em_flat: no factors -> one emerging mean
    sv_B <- fit_sev(s23, sev_chosen, 2023); sf_B <- fit_sev(sall, sev_chosen, 2024)
    emerging_only <- FALSE
    if (SEV_CV && nrow(sc) >= 30) {     # X14: out-of-fold claim-level Gamma deviance, developed shape vs emerging GLM vs 50/50 blend
      emf <- fread(file.path(W2$output, "07_adjust", paste0("levels_", SEV_CV_EM, ".csv")))[line == ln & peril == pr, sev_factors]
      emf <- if (length(emf) && nzchar(emf)) strsplit(emf, " \\+ ")[[1]] else character(0)
      pid <- trr[sc[, .(row_id)], on = "row_id", policy_id]; up <- unique(pid)
      set.seed(SEED); fold <- sample(rep_len(1:5, length(up)))[match(pid, up)]
      capc <- capd * sf_L$level_cap
      res <- rbindlist(lapply(1:5, function(k) {
        i_tr <- which(fold != k); i_te <- which(fold == k)
        emerging_only <<- FALSE; fa <- fit_sev(i_tr, sev_chosen, 2024)
        emerging_only <<- TRUE; fb <- fit_sev(i_tr, emf, 2024); emerging_only <<- FALSE
        d <- sc[i_te]; y <- pmin(d$cost * (1 + gs)^(2024 - d$loss_year), capc)
        pa <- pmin(pred_sev(fa, d, d, 2024) / load, capc); pb <- pmin(pred_sev(fb, d, d, 2024) / load, capc)
        # relevelled emerging shape: emerging GLM rescaled to the developed-shape model's mean on the training claims
        tr_d <- sc[i_tr]; kb <- mean(pred_sev(fa, tr_d, tr_d, 2024)) / mean(pred_sev(fb, tr_d, tr_d, 2024))
        pr_ <- pmin(pb * kb, capc)
        ud <- function(mu) 2 * (-log(y / mu) + (y - mu) / mu)
        data.table(fold = k, y = y, d_dev = ud(pa), d_em = ud(pb), d_mix = ud(sqrt(pa * pb)), d_emrl = ud(pr_), d_mixrl = ud(sqrt(pa * pr_)),
                   d_null = ud(rep(mean(pmin(tr_d$cost * (1 + gs)^(2024 - tr_d$loss_year), capc)), length(y))))
      }))
      sev_cv_out[[key]] <- res[, .(line = ln, peril = pr, claims = .N, em_factors = paste(emf, collapse = " + "), dev_factors = paste(sev_chosen, collapse = " + "),
        d2_dev = 1 - sum(d_dev) / sum(d_null), d2_em = 1 - sum(d_em) / sum(d_null), d2_mix = 1 - sum(d_mix) / sum(d_null),
        d2_emrl = 1 - sum(d_emrl) / sum(d_null), d2_mixrl = 1 - sum(d_mixrl) / sum(d_null),
        z_em = sum(d_dev - d_em) / (sd(d_dev - d_em) * sqrt(.N)), z_mix = sum(d_dev - d_mix) / (sd(d_dev - d_mix) * sqrt(.N)),
        z_emrl = sum(d_dev - d_emrl) / (sd(d_dev - d_emrl) * sqrt(.N)), z_mixrl = sum(d_dev - d_mixrl) / (sd(d_dev - d_mixrl) * sqrt(.N)))]
    }
    # X5: boosted frequency residual on emerging data (shallow trees, base margin = log of the B expected count)
    boost_v <- boost_f <- NULL
    if (X_BOOST) {
      bfe <- unique(intersect(c(CANDIDATES[[ln]], E_FACTORS[[ln]], if (X_EXTRA) "gender"), names(tr_all)))
      enc <- lapply(setNames(bfe, bfe), function(f) sort(unique(as.character(tr_all[[f]]))))
      tomat <- function(feat) sapply(bfe, function(f) match(as.character(feat[[f]]), enc[[f]]))
      fit_boost <- function(rows, fitB, base_year) {
        d <- trr[rows]; feat <- tr_all[rows]
        if (sum(d$n) < 300) return(NULL)
        mu <- pred_freq(fitB, d, feat, d$policy_year) * d$exposure * d$share
        X <- tomat(feat); set.seed(SEED + base_year)
        pid <- unique(d$policy_id); hold <- d$policy_id %chin% sample(pid, round(0.25 * length(pid)))
        dtr <- xgboost::xgb.DMatrix(X[!hold, , drop = FALSE], label = d$n[!hold], base_margin = log(mu[!hold]), weight = d$wfit[!hold])
        dva <- xgboost::xgb.DMatrix(X[hold, , drop = FALSE], label = d$n[hold], base_margin = log(mu[hold]), weight = d$wfit[hold])
        xgboost::xgb.train(params = list(objective = "count:poisson", learning_rate = 0.03, max_depth = 2, min_child_weight = 30,
                                         subsample = 0.8, colsample_bytree = 0.8, reg_lambda = 5, nthread = 2, seed = SEED),
                           data = dtr, nrounds = 500, evals = list(hold = dva), early_stopping_rounds = 30, verbose = 0)
      }
      boost_mult <- function(m, feat) if (is.null(m)) rep(1, nrow(feat)) else
        exp(predict(m, xgboost::xgb.DMatrix(tomat(feat), base_margin = rep(0, nrow(feat))), outputmargin = TRUE))
      boost_v <- fit_boost(r23, fv_B, 2023); boost_f <- fit_boost(rall, ff_B, 2024)
    }
    bm <- function(m, feat) if (X_BOOST) boost_mult(m, feat) else rep(1, nrow(feat))
    # E severity: emerging mean capped claim (cap at the developed cap x level) x emerging load, trended
    sevE <- function(fit) mean(pmin(sc$cost * (1 + gs)^(fit$base_year - sc$loss_year), capd * fit$level_cap)[if (fit$base_year == 2023) s23 else sall]) * fit$emerging_load

    # ---- predictions ----
    v <- trr[r24]; vf <- tr_all[r24]
    vo <- data.table(row_id = v$row_id, line = ln, peril = pr, exposure = v$exposure, share = v$share, n = v$n,
                     freq_B = pred_freq(fv_B, v, vf, 2024) * bm(boost_v, vf), sev_B = pred_sev(sv_B, v, vf, 2024),
                     freq_L = pred_freq(fv_L, v, vf, 2024), sev_L = pred_sev(sv_L, v, vf, 2024),
                     freq_E = pred_E(fvE, v, vf, 2024), sev_E = sevE(sv_L) * (1 + gs))
    vz <- trr[policy_year == 2024 & !ok_tr]
    if (nrow(vz)) vo <- rbind(vo, data.table(row_id = vz$row_id, line = ln, peril = pr, exposure = vz$exposure, share = vz$share, n = vz$n,
                                             freq_B = 0, sev_B = 0, freq_L = 0, sev_L = 0, freq_E = 0, sev_E = 0))
    if (FREQ_MODE == "developed") vo[seq_len(nrow(v)), freq_B := v$bfreq]
    if (FREQ_MODE == "level") vo[, freq_B := freq_L]
    valid_out[[key]] <- vo
    tz <- te[, .(row_id, exposure, bfreq = get(bf), bsev_c = get(bs) / load)]
    ok_te <- tz$bfreq > 0
    fo <- data.table(row_id = tz$row_id, line = ln, peril = pr, exposure = tz$exposure,
                     freq_B = 0, sev_B = 0, freq_L = 0, sev_L = 0, freq_E = 0, sev_E = 0, bfreq = tz$bfreq, bsev = tz$bsev_c * load)
    if (any(ok_te)) {
      t1 <- tz[ok_te]; t1f <- te[ok_te]
      fo[ok_te, `:=`(freq_B = pred_freq(ff_B, t1, t1f, 2024) * bm(boost_f, t1f), sev_B = pred_sev(sf_B, t1, t1f, 2024),
                     freq_L = pred_freq(ff_L, t1, t1f, 2024), sev_L = pred_sev(sf_L, t1, t1f, 2024),
                     freq_E = pred_E(ffE, t1, t1f, 2024), sev_E = sevE(sf_L))]
    }
    if (FREQ_MODE == "developed") fo[, freq_B := bfreq]
    if (FREQ_MODE == "level") fo[, freq_B := freq_L]
    final_out[[key]] <- fo
    # in-sample (final fit, 2023-24 rows at their own year) for the step 8 new-business check
    ins <- trr[ok_tr]; insf <- tr_all[ok_tr]
    insample_out[[key]] <- data.table(row_id = ins$row_id, line = ln, peril = pr, policy_year = ins$policy_year, exposure = ins$exposure,
      share = ins$share, n = ins$n, freq_B = pred_freq(ff_B, ins, insf, ins$policy_year) * bm(boost_f, insf), sev_B = pred_sev(sf_B, ins, insf, ins$policy_year),
      freq_E = pred_E(ffE, ins, insf, ins$policy_year), sev_E = sevE(sf_L) * (1 + gs)^(ins$policy_year - 2024))
    if (FREQ_MODE == "developed") insample_out[[key]][, freq_B := ins$bfreq]
    if (FREQ_MODE == "level") insample_out[[key]][, freq_B := pred_freq(ff_L, ins, insf, ins$policy_year)]
    # NB round: 2023 fit on its own 2023 rows, so step 8 loadings can be backtested on the 2024 fold (22_nb_backtest.R)
    i23 <- trr[r23]; i23f <- tr_all[r23]
    insample23_out[[key]] <- data.table(row_id = i23$row_id, line = ln, peril = pr, policy_year = i23$policy_year, exposure = i23$exposure,
      share = i23$share, n = i23$n, freq_B = pred_freq(fv_B, i23, i23f, 2023) * bm(boost_v, i23f), sev_B = pred_sev(sv_B, i23, i23f, 2023))
    if (FREQ_MODE == "developed") insample23_out[[key]][, freq_B := i23$bfreq]
    if (FREQ_MODE == "level") insample23_out[[key]][, freq_B := pred_freq(fv_L, i23, i23f, 2023)]
    lv <- function(fit) exp(fit$beta[["(Intercept)"]])
    levels_tab[[key]] <- data.table(line = ln, peril = pr, claims_2023 = sum(trr$n[r23]), claims_all = sum(trr$n[rall]),
      freq_level_2023 = lv(fv_L), freq_level_final = lv(ff_L), sev_level_2023 = exp(sv_L$beta[["(Intercept)"]]), sev_level_final = exp(sf_L$beta[["(Intercept)"]]),
      sev_cap_level_final = sf_L$level_cap, emerging_load_final = sf_L$emerging_load, developed_load = load,
      freq_factors = paste(chosen, collapse = " + "), sev_factors = paste(sev_chosen, collapse = " + "),
      valid_dev_level = dev0, valid_dev_B = cur_dev)
    for (nm in c("ff_B", "sf_B")) { fit <- get(nm); coefs[[paste(key, nm)]] <- data.table(line = ln, peril = pr, model = nm, term = names(fit$beta), coef = fit$beta, relativity = exp(fit$beta)) }
    log_msg(sprintf("%s/%s: freq level %.3f, sev level %.3f; freq factors [%s]; sev factors [%s]", ln, pr, lv(ff_L), exp(sf_L$beta[["(Intercept)"]]),
                    paste(chosen, collapse = ", "), paste(sev_chosen, collapse = ", ")))
  }
}
if (SEV_CV) save_csv(rbindlist(sev_cv_out), STEP, paste0("sev_cv_", TAG, ".csv"))
cred_tab <- rbindlist(cred_out)
if (!is.null(kmod)) cred_tab <- merge(cred_tab, kmod[, .(line, peril, window, vhm_f, vhm_s)], by = c("line", "peril", "window"), all.x = TRUE)
if (JEWELL_K != "0") cred_tab <- merge(cred_tab, jw[, .(line, window, Z_line_freq = ZLf, Z_line_sev = ZLs)], by = c("line", "window"), all.x = TRUE)
save_csv(cred_tab, STEP, paste0("cred_", TAG, ".csv"))
factor_log <- rbindlist(factor_log); coefs <- rbindlist(coefs); levels_tab <- rbindlist(levels_tab)
OUT <- file.path(W2$data, "adjust", TAG)
write_w2(rbindlist(valid_out), file.path(OUT, "valid_2024_peril.parquet"))
write_w2(rbindlist(final_out), file.path(OUT, "final_2025_peril.parquet"))
write_w2(rbindlist(insample_out), file.path(OUT, "insample_peril.parquet"))
write_w2(rbindlist(insample23_out), file.path(OUT, "insample23_peril.parquet"))
sfx <- if (TAG == "main") "" else paste0("_", TAG)
save_csv(factor_log, STEP, paste0("factor_log", sfx, ".csv")); save_csv(coefs, STEP, paste0("coefficients", sfx, ".csv")); save_csv(levels_tab, STEP, paste0("levels", sfx, ".csv"))

if (TAG == "main") {
  add_decision("D018", "7", sprintf("Emerging adjustment: per-peril Poisson / Gamma GLMs with offset log(baseline), ridge lambda %g (freq) / %g (sev) as credibility, greedy forward factors (max %d) kept only if 2024 deviance improves when fitted on 2023",
                                    LAMBDA, LAMBDA_SEV, MAX_FACTORS),
               "glmnet (not installed); unpenalised GLM; factors chosen on in-sample fit", "week2/output/07_adjust/factor_log.csv", "decided")
  add_decision("D019", "7", "Severity: level only for fire, flood, subsidence, motor BI, contents flood; factors only for perils with >= 1000 claims; cap = developed cap x emerging level; load = developed",
               "Emerging severity models per peril", "week2/output/07_adjust/levels.csv", "decided")
  add_assumption("A007", "7", "Ridge credibility lambda (frequency)", LAMBDA, "judgement", "m/(m+lambda) per factor level", "LAMBDA 30 / 300 runs in step 9")
}
kl <- c(sprintf("- Frequency level (emerging / developed baseline), final fit: %s.", paste(levels_tab[, sprintf("%s/%s %.2f", substr(line, 1, 1), peril, freq_level_final)], collapse = ", ")),
        sprintf("- Severity level, final fit: %s.", paste(levels_tab[, sprintf("%s/%s %.2f", substr(line, 1, 1), peril, sev_level_final)], collapse = ", ")),
        sprintf("- Factors kept (frequency): %s.", paste(levels_tab[nzchar(freq_factors), sprintf("%s/%s: %s", line, peril, freq_factors)], collapse = "; ")),
        sprintf("- Factors kept (severity): %s.", paste(levels_tab[nzchar(sev_factors), sprintf("%s/%s: %s", line, peril, sev_factors)], collapse = "; ")))
write_md(list(paste0("# Step 7: emerging adjustments (run ", TAG, ")"), "", paste("Generated", ts_sgt(), "by `week2/R/07_emerging_adjust.R`."), "", kl, "",
              "## Levels", "", md_table(levels_tab, 3), "## Factor log (every factor tried)", "", md_table(factor_log, 2),
              "## Coefficients (final fit, log scale; relativity = exp)", "", md_table(coefs, 3)), STEP, paste0("adjust_report", sfx, ".md"))
if (TAG == "main") update_step_log("7", "Emerging adjustments", kl)
end_script()
