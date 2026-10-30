# wendy_ladder_core.R ---------------------------------------------------------------------------------------------
# Shared engine for WENDY 8 (R/4_models_iterwendy08.R) and WENDY 9 (R/4_models_iterwendy09.R).
# R translation of the Python code in python/wendy08/ and python/wendy09/ (23 Oct 2026).
#
#   wl_rows(line)            policy rows (train 2021-24 + test 2025) from the RAW files with the WENDY 8/9 cleaning,
#                            joins (customers, addresses, same-year and 2021-24 long-run weather) and engineered fields;
#                            per row: y (net cost of non-repudiated claims), n_pos, and per peril c_<peril>, n_<peril>,
#                            s_<peril> (share of ultimate claims reported by 1 Jan 2025)
#   wl_features(rows)        model features (clean, no leakage / premium / noise fields)
#   wl_prior_lambda(line)    a-priori claim-count model (LightGBM Poisson, no history) out-of-fold per policy
#   wl_history(line, lam)    N = own-policy prior claims known at the row's cut-off, E = their expected number
#   wl_cred(pred, N, E, a)   credibility multiplier (a + N) / (a + E)
#   wl_fit_freq / wl_fit_sev per-peril LightGBM Poisson frequency and Gamma severity (WENDY 9 ladder)
#
# Differences from the Python run (expect small numerical differences, not different conclusions):
#   * policy folds / holdouts use the digits of policy_id (Python used a polars hash)
#   * categorical codes are factor levels (Python used polars physical codes); rate-ordered encoding is unaffected

VAL_CUT <- as.IDate("2025-01-01")
WL_DROP <- c("row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end", "renewal_decision",
             "y", "n_all", "n_pos", "surname", "date_of_birth", "is_test", "year", "exposure")
WL_EXCL <- c("customer_service_contacts", "written_premium", "discount_applied", "compulsory_excess",
             "email_domain", "marketing_consent", "document_preference", "campaign_code", "branch_id",
             "marketing_segment", "vehicle_colour", "customer_since_year", "start_month", "days_quote_to_inception")
WL_HC <- c("previous_insurer", "occupation")
WL_PROP <- c("soil_type", "year_built", "property_type", "roof_type", "basement", "trees_within_5m", "listed_building",
             "bedrooms", "energy_rating", "solar_panels", "flood_zone", "distance_to_river_km", "elevation_m")
WL_WX <- c(WEATHER_VARS, paste0("lr_", WEATHER_VARS))
wl_dir <- function(it) { d <- file.path("models", it); dir.create(d, recursive = TRUE, showWarnings = FALSE); d }
pol_digits <- function(pid) as.numeric(sub("^[A-Za-z]+", "", pid))

# Claims matched to policy rows (all statuses), net = incurred - recoveries, repudiated = 0 ---------------------------
wl_claims <- function(line, rows) {
  ln <- line
  cl <- read_raw("claims")[line == ln]
  cl[, `:=`(loss_date = as.IDate(loss_date), report_date = as.IDate(report_date))]
  cl[, net := fifelse(status == "repudiated", 0, incurred_to_date - recoveries)]
  r <- rows[is_test == 0L, .(row_id, policy_id, ps = period_start, pe = period_end)]
  m <- cl[r, on = .(policy_id, loss_date >= ps, loss_date <= pe), nomatch = 0L,
          .(claim_id, policy_id, row_id = i.row_id, peril, loss_date = x.loss_date, report_date, status, net)]
  m[]
}

# Report-lag ECDF and the share of a row's claims reported by a cut-off (16-point average over the row) ---------------
wl_share <- function(lag, s, e, cut) {
  lag <- sort(pmax(lag, 0)); s <- as.numeric(s); e <- as.numeric(e); cut <- as.numeric(cut)
  acc <- numeric(length(s))
  for (q in (seq_len(16) - 0.5) / 16) {
    d <- cut - (s + (e - s) * q)
    acc <- acc + ifelse(d < 0, 0, findInterval(d, lag) / length(lag))
  }
  acc / 16
}

# Policy rows with targets and features ---------------------------------------------------------------------------
wl_rows <- function(line) {
  tr <- read_raw(paste0("policies_", line)); te <- read_raw(paste0("test_", line))
  te[, renewal_decision := NA_character_]
  d <- rbind(tr[, is_test := 0L], te[, is_test := 1L], use.names = TRUE, fill = TRUE)
  d[, `:=`(period_start = as.IDate(period_start), period_end = as.IDate(period_end))]
  d[, exposure := as.numeric(period_end - period_start + 1) / DAYS_PER_YEAR]
  d[, year := as.integer(format(period_start, "%Y"))]
  d[, customer_id := pad_id(as.character(customer_id))]
  cu <- read_raw("customers")[, customer_id := pad_id(as.character(customer_id))]
  ad <- read_raw("addresses"); wx <- read_raw("weather")
  lr <- wx[year <= 2024, lapply(.SD, mean, na.rm = TRUE), by = address_id, .SDcols = WEATHER_VARS]
  setnames(lr, WEATHER_VARS, paste0("lr_", WEATHER_VARS))
  d <- merge(d, cu, by = "customer_id", all.x = TRUE, sort = FALSE)
  d <- merge(d, ad, by = "address_id", all.x = TRUE, sort = FALSE)
  d <- merge(d, wx, by = c("address_id", "year"), all.x = TRUE, sort = FALSE)
  d <- merge(d, lr, by = "address_id", all.x = TRUE, sort = FALSE)
  d[, cust_age := as.numeric(period_start - as.IDate(date_of_birth)) / 365.25]
  d[, tenure_yrs := year - customer_since_year]
  if (line == "buildings") {
    d[, construction_type := toupper(construction_type)]
    d[construction_type %in% c("T", "W"), construction_type := "TIMBER"]
    d[sum_insured > 1e7, sum_insured := sum_insured / 1000]
  }
  if (line == "contents") d[sum_insured > 2e6, sum_insured := sum_insured / 1000]
  # targets
  cl <- wl_claims(line, d)
  nr <- cl[status != "repudiated"]
  agg <- nr[, .(y = sum(net), n_pos = sum(net > 0)), by = row_id]
  d[agg, on = "row_id", `:=`(y = i.y, n_pos = i.n_pos)]
  d[is.na(y), y := 0]; d[is.na(n_pos), n_pos := 0L]
  for (p in PERILS[[line]]) {
    cp <- nr[peril == p]
    a <- cp[, .(c = sum(net), n = sum(net > 0)), by = row_id]
    d[, (paste0("c_", p)) := a$c[match(row_id, a$row_id)]]
    d[, (paste0("n_", p)) := a$n[match(row_id, a$row_id)]]
    set(d, which(is.na(d[[paste0("c_", p)]])), paste0("c_", p), 0)
    set(d, which(is.na(d[[paste0("n_", p)]])), paste0("n_", p), 0L)
    lag <- cp[year(loss_date) <= 2022, as.numeric(report_date - loss_date)]
    d[, (paste0("s_", p)) := pmax(wl_share(lag, period_start, period_end, VAL_CUT), 0.03)]
  }
  # categorical: character / logical -> integer codes (factor levels); NA kept as NA
  cats <- names(d)[vapply(d, function(x) is.character(x) || is.logical(x), logical(1))]
  cats <- setdiff(cats, c("row_id", "policy_id", "customer_id", "address_id", "surname", "date_of_birth",
                          "renewal_decision"))
  for (cc in cats) set(d, j = cc, value = as.integer(factor(as.character(d[[cc]]))))
  setattr(d, "wl_cats", cats)
  setorder(d, is_test, row_id)
  attr(d, "wl_claims") <- cl
  d[]
}
wl_features <- function(d) setdiff(names(d), c(WL_DROP, WL_EXCL, grep("^(c_|n_|s_)", names(d), value = TRUE),
                                               "N", "E", "M", "lam", "fold", "hold"))
wl_matrix <- function(d, feats) as.matrix(d[, ..feats])

# A-priori claim-count model: LightGBM Poisson on n_pos, all clean features + year, 4 policy folds out-of-fold ------
PRIOR_PARAMS <- list(objective = "poisson", learning_rate = 0.05, num_leaves = 31, min_data_in_leaf = 300,
                     feature_fraction = 0.7, bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = 10,
                     verbose = -1, num_threads = 0, seed = 11)
wl_prior_lambda <- function(d) {
  tr <- d[is_test == 0L]
  feats <- c(wl_features(d), "year"); cats <- intersect(attr(d, "wl_cats"), feats)
  X <- wl_matrix(tr, feats); y <- tr$n_pos / tr$exposure; w <- tr$exposure
  fold <- pol_digits(tr$policy_id) %% 4
  h <- fold == 0
  dt <- lgb.Dataset(X[!h, ], label = y[!h], weight = w[!h], categorical_feature = cats)
  dv <- lgb.Dataset.create.valid(dt, X[h, ], label = y[h], weight = w[h])
  m <- lgb.train(PRIOR_PARAMS, dt, nrounds = 3000, valids = list(v = dv), early_stopping_rounds = 100, verbose = -1)
  rounds <- m$best_iter
  lam <- numeric(nrow(tr))
  for (k in 0:3) {
    h <- fold == k
    mk <- lgb.train(PRIOR_PARAMS, lgb.Dataset(X[!h, ], label = y[!h], weight = w[!h], categorical_feature = cats),
                    nrounds = rounds, verbose = -1)
    lam[h] <- predict(mk, X[h, ]) * w[h]
  }
  log_msg("prior lambda: rounds ", rounds, ", A/E ", round(sum(tr$n_pos) / sum(lam), 4))
  tr[, .(row_id, policy_id, period_start, period_end, year, exposure, lam = lam)]
}

# Own-policy claim history: N (claims, net > 0, loss before the row start, reported before the cut-off) and E -------
wl_history <- function(d, lam) {
  cl <- attr(d, "wl_claims")
  lag <- cl[, as.numeric(report_date - loss_date)]
  lam <- copy(lam)
  lam[, lam_ult := lam / pmax(wl_share(lag, period_start, period_end, VAL_CUT), 0.05)]
  cur <- d[, .(row_id, policy_id, period_start, cut = pmin(period_start, VAL_CUT))]
  j <- lam[, .(policy_id, ps = period_start, pe = period_end, lu = lam_ult)][cur, on = .(policy_id), allow.cartesian = TRUE,
        nomatch = 0L][pe < cut]
  j[, Ei := lu * wl_share(lag, ps, pe, cut)]
  E <- j[, .(E = sum(Ei)), by = row_id]
  pos <- cl[net > 0, .(policy_id, loss_date, report_date)]
  jn <- pos[cur, on = .(policy_id), allow.cartesian = TRUE, nomatch = 0L][loss_date < period_start & report_date < cut]
  N <- jn[, .(N = .N), by = row_id]
  out <- d[, .(row_id)]
  out[E, on = "row_id", E := i.E][N, on = "row_id", N := i.N]
  out[is.na(E), E := 0][is.na(N), N := 0L]
  out[]
}
wl_cred <- function(N, E, a) (a + N) / (a + E)
# rescale so the group total is unchanged
wl_rescale <- function(new, old) new * sum(old) / sum(new)

# Rate-ordered categorical encoding (credibility-weighted rate per level, ~20 expected claims) ---------------------
wl_rate_encode <- function(X, feats, cats, tr, n, w) {
  base <- sum(n[tr]) / sum(w[tr])
  for (i in which(feats %in% cats)) {
    code <- X[, i]; code[is.na(code)] <- 0; code <- as.integer(code) + 1L
    m <- max(code)
    nn <- vapply(split(n[tr], factor(code[tr], levels = seq_len(m))), sum, numeric(1))
    ww <- vapply(split(w[tr], factor(code[tr], levels = seq_len(m))), sum, numeric(1))
    rate <- (nn + 20) / (ww + 20 / base)
    X[, i] <- rank(rate, ties.method = "first")[code] - 1
  }
  X
}

# Per-peril frequency (LightGBM Poisson on claims / (exposure x reported share)) ------------------------------------
FREQ_BASE <- list(objective = "poisson", learning_rate = 0.05, num_leaves = 31, min_data_in_leaf = 500,
                  feature_fraction = 0.7, bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = 10, verbose = -1,
                  num_threads = 0, seed = 5, max_bin = 127, cat_smooth = 20, min_data_per_group = 200)
SEV_BASE <- list(objective = "gamma", learning_rate = 0.03, num_leaves = 7, min_data_in_leaf = 200,
                 feature_fraction = 0.8, bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = 10, verbose = -1,
                 num_threads = 0, seed = 6, max_bin = 63, cat_smooth = 50, min_data_per_group = 100)
wl_masks <- function(d, vy, fy) list(tr = d$is_test == 0L & d$year %in% fy,
                                     sc = if (vy < 2025) d$is_test == 0L & d$year == vy else d$is_test == 1L)
wl_fit_freq <- function(d, peril, feats, vy, fy, params, enc = "native") {
  mk <- wl_masks(d, vy, fy); tr <- mk$tr; sc <- mk$sc
  X <- wl_matrix(d, feats); cats <- intersect(attr(d, "wl_cats"), feats)
  n <- d[[paste0("n_", peril)]]; w <- d$exposure * d[[paste0("s_", peril)]]; y <- n / w
  if (enc == "rate") { X <- wl_rate_encode(X, feats, cats, tr, n, w); cats <- character(0) }
  itr <- which(tr); h <- pol_digits(d$policy_id[itr]) %% 10 == 0
  dt <- lgb.Dataset(X[itr[!h], , drop = FALSE], label = y[itr[!h]], weight = w[itr[!h]], categorical_feature = cats)
  dv <- lgb.Dataset.create.valid(dt, X[itr[h], , drop = FALSE], label = y[itr[h]], weight = w[itr[h]])
  m <- lgb.train(params, dt, nrounds = 3000, valids = list(v = dv), early_stopping_rounds = 100, verbose = -1)
  rounds <- max(m$best_iter, 10)
  m <- lgb.train(params, lgb.Dataset(X[itr, , drop = FALSE], label = y[itr], weight = w[itr], categorical_feature = cats),
                 nrounds = rounds, verbose = -1)
  bal <- sum(n[itr]) / sum(predict(m, X[itr, , drop = FALSE]) * w[itr])
  list(pred = predict(m, X[sc, , drop = FALSE]) * d$exposure[sc] * bal, rounds = rounds, bal = bal)
}

# Claim cap: 'nearest' quantile (as polars Series.quantile in the Python run)
wl_qnear <- function(x, q) { x <- sort(x); x[floor(q * (length(x) - 1) + 0.5) + 1] }
# Severity trend: weighted log-linear fit of the yearly mean capped claim (weights = claim counts), clamped ---------
wl_sev_claims <- function(d, peril, fy) {
  cl <- attr(d, "wl_claims")
  pp <- peril
  cl[peril == pp & status != "repudiated" & net > 0 & year(loss_date) %in% fy][, ly := year(loss_date)][]
}
wl_sev_trend <- function(d, peril, fy, cap_q = 0.995, lo = -0.02, hi = 0.10) {
  c <- wl_sev_claims(d, peril, fy); cap <- wl_qnear(c$net, cap_q)
  s <- c[, .(s = mean(pmin(net, cap)), k = .N), by = ly][order(ly)]
  if (nrow(s) < 2) return(0)
  b <- unname(coef(lm(log(s) ~ ly, data = s, weights = k))[2])
  min(max(b, lo), hi)
}
# Per-peril severity (LightGBM Gamma on capped claims trended to the scored year; loading for the excess over cap)
wl_fit_sev <- function(d, peril, feats, vy, fy, params = SEV_BASE, cap_q = 0.995, lo = -0.02, hi = 0.10,
                       fixed_trend = NULL) {
  g <- if (is.null(fixed_trend)) wl_sev_trend(d, peril, fy, cap_q, lo, hi) else fixed_trend
  c <- wl_sev_claims(d, peril, fy); cap <- wl_qnear(c$net, cap_q)
  load <- sum(c$net) / sum(pmin(c$net, cap))
  amt <- pmin(c$net, cap) * exp(g * (vy - c$ly))
  X <- wl_matrix(d, feats); cats <- intersect(attr(d, "wl_cats"), feats)
  rows <- match(c$row_id, d$row_id); Xc <- X[rows, , drop = FALSE]
  h <- pol_digits(c$policy_id) %% 10 == 0
  dt <- lgb.Dataset(Xc[!h, , drop = FALSE], label = amt[!h], categorical_feature = cats)
  dv <- lgb.Dataset.create.valid(dt, Xc[h, , drop = FALSE], label = amt[h])
  m <- lgb.train(params, dt, nrounds = 3000, valids = list(v = dv), early_stopping_rounds = 100, verbose = -1)
  rounds <- max(m$best_iter, 5)
  m <- lgb.train(params, lgb.Dataset(Xc, label = amt, categorical_feature = cats), nrounds = rounds, verbose = -1)
  bal <- mean(amt) / mean(predict(m, Xc))
  sc <- wl_masks(d, vy, fy)$sc
  list(pred = predict(m, X[sc, , drop = FALSE]) * bal * load, rounds = rounds, trend = g, cap = cap, load = load)
}
