# w89_core.R -------------------------------------------------------------------------------------------------------
# R port of Wendy's Python WENDY 8 / WENDY 9 code (notes/wendy_python_workspace/, notes/wendy09_exact_model_submitted/):
#   prep.py   claim rows matched to policy rows, training tables (net = incurred - recoveries; repudiated = 0)
#   fe.py     feature table per line (policies + customers + addresses + weather + long-run weather means)
#   prior.py  a-priori LightGBM Poisson claim count, 4 policy folds, out of fold
#   cred.py / cred3.py   own-policy claim history: N (prior reported claims) and E (their expected number)
#   core.py   ladder data, frequency / severity helpers
# The polars hash splits of the Python code come from inputs/polars_policy_hash.parquet (tools/make_polars_policy_hash.py).
# Sourced by R/5_history.R and R/6_ladder.R after R/0_setup.R.

VAL_DATE <- as.Date("2025-01-01")
W89_DIR <- file.path("data", "w89")
dir.create(W89_DIR, recursive = TRUE, showWarnings = FALSE)
FE_DROP <- c("row_id", "policy_id", "customer_id", "address_id", "period_start", "period_end", "renewal_decision", "y",
             "n_all", "n_pos", "surname", "date_of_birth")
BASE_EXCL <- c("customer_service_contacts", "written_premium", "discount_applied", "prem_rate", "compulsory_excess", "year",
               "is_test", "exposure", "email_domain", "marketing_consent", "document_preference", "campaign_code", "branch_id",
               "marketing_segment", "vehicle_colour", "customer_since_year", "start_month", "days_quote_to_inception")
POLICY_HASH <- local({
  h <- as.data.table(read_parquet(file.path("inputs", "polars_policy_hash.parquet")))
  setkey(h, policy_id); h
})
hash_fold <- function(pid) POLICY_HASH[J(pid), fold]
hash_hold3 <- function(pid) POLICY_HASH[J(pid), hold3]

zfill8 <- function(x) { x <- as.character(x); n <- nchar(x); k <- !is.na(x) & n < 8; x[k] <- paste0(strrep("0", 8 - n[k]), x[k]); x }
# polars divides by a constant as x * (1 / c); the ports do the same so values match to the last bit
# polars float sums / means are Kahan-compensated (in row order within each group); grouped version for the ports
kahan_by <- function(v, g) {
  o <- order(g, method = "radix"); v <- v[o]; g <- g[o]
  grp <- cumsum(c(TRUE, g[-1] != g[-length(g)])); pos <- seq_along(v) - match(grp, grp) + 1L
  ng <- max(grp); s <- numeric(ng); cc <- numeric(ng)
  for (k in seq_len(max(pos))) { i <- which(pos == k); gi <- grp[i]; y <- v[i] - cc[gi]; tt <- s[gi] + y; cc[gi] <- (tt - s[gi]) - y; s[gi] <- tt }
  list(key = g[!duplicated(grp)], sum = s, n = tabulate(grp, ng))
}
# float32 rounding (Python builds the ladder matrix as float32)
f32 <- function(x) { x <- as.double(x); k <- !is.na(x); x[k] <- readBin(writeBin(x[k], raw(), size = 4), "double", size = 4, n = sum(k)); x }

# prep.py ------------------------------------------------------------------------------------------------------------
w_prep <- function(line) {
  line_name <- line
  f_rows <- file.path(W89_DIR, paste0("claims_rows_", line, ".parquet")); f_tr <- file.path(W89_DIR, paste0("train_", line, ".parquet"))
  if (file.exists(f_rows) && file.exists(f_tr)) return(invisible())
  cl <- read_raw("claims"); cl <- cl[cl$line == line_name]
  cl[, net := fifelse(status == "repudiated", 0, incurred_to_date - recoveries)]
  p <- read_raw(paste0("policies_", line))
  c <- cl[, .(claim_id, policy_id, peril, loss_date, report_date, status, net)][, cpos := .I]
  pp <- p[, .(row_id, policy_id, period_start, period_end)][, ppos := .I]
  j <- merge(c, pp, by = "policy_id", allow.cartesian = TRUE, sort = FALSE)
  # polars' join returns the matches in policy-row order, then claim order
  j <- j[loss_date >= period_start & loss_date <= period_end][order(ppos, cpos)][, c("cpos", "ppos") := NULL]
  setcolorder(j, c("claim_id", "policy_id", "peril", "loss_date", "report_date", "status", "net", "row_id", "period_start", "period_end"))
  write_parquet(j, f_rows)
  agg <- j[, .(n_all = .N, n_pos = sum(net > 0)), by = row_id]
  ks <- kahan_by(j$net, j$row_id); agg[, y := ks$sum[match(row_id, ks$key)]]
  setcolorder(agg, c("row_id", "y", "n_all", "n_pos"))
  p <- merge(p, agg, by = "row_id", all.x = TRUE, sort = FALSE)[match(p$row_id, row_id)]
  p[is.na(y), `:=`(y = 0, n_all = 0L, n_pos = 0L)]
  p[, `:=`(exposure = (as.numeric(period_end - period_start) + 1) * (1 / 365), year = as.integer(format(period_start, "%Y")))]
  write_parquet(p, f_tr)
}
w_claims_rows <- function(line) as.data.table(read_parquet(file.path(W89_DIR, paste0("claims_rows_", line, ".parquet"))))

# fe.py: feature table (train rows then test rows); string / logical columns -> integer codes ------------------------
w_fe <- function(line) {
  f_fe <- file.path(W89_DIR, paste0("fe_", line, ".parquet"))
  if (file.exists(f_fe)) {
    d <- as.data.table(read_parquet(f_fe)); attr(d, "cats") <- jsonlite::fromJSON(paste0(f_fe, ".cats.json")); return(d)
  }
  w_prep(line)
  tr <- as.data.table(read_parquet(file.path(W89_DIR, paste0("train_", line, ".parquet"))))[, is_test := 0L]
  te <- read_raw(paste0("test_", line))
  te[, `:=`(exposure = (as.numeric(period_end - period_start) + 1) * (1 / 365), year = as.integer(format(period_start, "%Y")),
            y = 0, n_all = 0L, n_pos = 0L, is_test = 1L)]
  cols <- intersect(names(tr), names(te))
  d <- rbind(tr[, ..cols], te[, ..cols])
  d[, customer_id := zfill8(customer_id)]
  cu <- read_raw("customers")[, customer_id := zfill8(customer_id)]
  ad <- read_raw("addresses"); wx <- read_raw("weather")
  wcols <- setdiff(names(wx), c("address_id", "year"))
  w24 <- wx[year <= 2024]; wxa <- data.table(address_id = unique(w24$address_id))
  for (cn in wcols) { v <- w24[[cn]]; k <- !is.na(v); ks <- kahan_by(v[k], w24$address_id[k])
    set(wxa, j = cn, value = (ks$sum / ks$n)[match(wxa$address_id, ks$key)]) }
  setnames(wxa, wcols, paste0("lr_", wcols))
  setnames(wx, "year", "year_wx")
  n0 <- nrow(d); d[, .ord := .I]
  d <- merge(d, cu, by = "customer_id", all.x = TRUE, sort = FALSE)
  d <- merge(d, ad, by = "address_id", all.x = TRUE, sort = FALSE)
  d <- merge(d, wx, by.x = c("address_id", "year"), by.y = c("address_id", "year_wx"), all.x = TRUE, sort = FALSE)
  d <- merge(d, wxa, by = "address_id", all.x = TRUE, sort = FALSE)
  setorder(d, .ord); stopifnot(nrow(d) == n0)
  setcolorder(d, c(cols, setdiff(names(cu), "customer_id"), setdiff(names(ad), "address_id"), wcols, paste0("lr_", wcols)))
  d[, .ord := NULL]
  d[, `:=`(cust_age = as.numeric(period_start - as.Date(date_of_birth)) * (1 / 365.25), tenure_yrs = year - customer_since_year,
           prem_rate = written_premium, start_month = as.integer(format(period_start, "%m")))]
  if (line == "buildings") {
    d[, construction_type := toupper(construction_type)]
    d[construction_type %in% c("T", "W"), construction_type := "TIMBER"]
    d[sum_insured > 1e7, sum_insured := sum_insured / 1000]
  }
  if (line == "contents") d[sum_insured > 2e6, sum_insured := sum_insured / 1000]
  keep <- c("row_id", "policy_id", "customer_id", "address_id", "surname")
  cats <- names(d)[vapply(d, function(v) is.character(v) || is.logical(v), logical(1)) & !names(d) %in% keep]
  # integer codes in order of first appearance (polars' codes are arbitrary; verified not to change the models)
  for (cn in cats) { v <- as.character(d[[cn]]); set(d, j = cn, value = match(v, unique(v[!is.na(v)])) - 1L) }
  write_parquet(d, f_fe); jsonlite::write_json(cats, paste0(f_fe, ".cats.json"))
  attr(d, "cats") <- cats
  d
}

# prior.py -----------------------------------------------------------------------------------------------------------
PRIOR_PARAMS <- list(objective = "poisson", learning_rate = 0.05, num_leaves = 31, min_data_in_leaf = 300, feature_fraction = 0.7,
                     bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = 10, verbose = -1, num_threads = 2, seed = 11)
w_prior <- function(line, rounds = NULL) {
  f <- file.path(W89_DIR, paste0("prior_", line, ".parquet"))
  if (file.exists(f)) return(as.data.table(read_parquet(f)))
  d <- w_fe(line); cats <- attr(d, "cats")
  feats <- c(setdiff(names(d), c(FE_DROP, BASE_EXCL)), "year")
  tr <- d[is_test == 0L]
  fold <- hash_fold(tr$policy_id); stopifnot(!anyNA(fold))
  X <- as.matrix(tr[, lapply(.SD, as.double), .SDcols = feats])
  y <- tr$n_pos / tr$exposure; w <- tr$exposure
  ci <- which(feats %in% cats)
  ds <- function(k) lgb.Dataset(X[k, , drop = FALSE], label = y[k], weight = w[k], categorical_feature = ci)
  if (is.null(rounds)) {
    h <- fold == 0L; dt <- ds(!h)
    m <- lgb.train(PRIOR_PARAMS, dt, nrounds = 3000, valids = list(v = lgb.Dataset.create.valid(dt, X[h, , drop = FALSE], label = y[h], weight = w[h])),
                   early_stopping_rounds = 100, verbose = -1)
    rounds <- m$best_iter
  }
  oof <- numeric(length(y))
  for (k in 0:3) { h <- fold == k; m <- lgb.train(PRIOR_PARAMS, ds(!h), nrounds = rounds, verbose = -1); oof[h] <- predict(m, X[h, , drop = FALSE]) * w[h] }
  out <- tr[, .(row_id, policy_id, customer_id, address_id, period_start, period_end, year, exposure)][, `:=`(lam = oof, is_test = 0L)]
  log_msg(line, ": prior rounds ", rounds, " A/E ", round(sum(tr$n_pos) / sum(oof), 5))
  write_parquet(out, f); out
}

# cred.py / cred3.py -------------------------------------------------------------------------------------------------
w_lag_ecdf <- function(line) { c <- w_claims_rows(line); sort(pmax(as.numeric(c$report_date - c$loss_date), 0)) }
w_share <- function(lag, s, e, cut) {
  s <- as.numeric(s); e <- as.numeric(e); cut <- as.numeric(cut); acc <- numeric(length(s)); n <- length(lag)
  for (q in (0:15 + 0.5) / 16) { dd <- cut - (s + (e - s) * q); acc <- acc + ifelse(dd < 0, 0, findInterval(dd, lag) / n) }
  acc / 16
}
w_history <- function(line, sev_cap_q = 0.99) {
  f <- file.path("models", "wendy_iteration_08", paste0("history_", line, ".parquet"))
  lag <- w_lag_ecdf(line); pr <- w_prior(line)
  sv <- w_share(lag, pr$period_start, pr$period_end, rep(VAL_DATE, nrow(pr)))
  pr[, lam_ult := lam / pmax(sv, 0.05)]
  te <- read_raw(paste0("test_", line))[, .(row_id, policy_id, period_start, period_end)]
  cur <- rbind(pr[, .(row_id, policy_id, period_start, period_end)], te)
  cur[, cut := pmin(period_start, VAL_DATE)]
  j <- merge(cur[, .(row_id, policy_id, cut)], pr[, .(policy_id, ps = period_start, pe = period_end, lu = lam_ult)],
             by = "policy_id", allow.cartesian = TRUE, sort = FALSE)[pe < cut]
  j[, Ei := lu * w_share(lag, ps, pe, cut)]
  E <- j[, .(E = sum(Ei)), by = row_id]
  c <- w_claims_rows(line)[net > 0]
  jn <- merge(cur[, .(row_id, policy_id, cut, period_start)], c[, .(policy_id, loss_date, report_date)], by = "policy_id",
              allow.cartesian = TRUE, sort = FALSE)[loss_date < period_start & report_date < cut]
  N <- jn[, .(N = .N), by = row_id]
  out <- merge(merge(cur[, .(row_id)], E, by = "row_id", all.x = TRUE, sort = FALSE), N, by = "row_id", all.x = TRUE, sort = FALSE)
  out <- out[match(cur$row_id, row_id)][, `:=`(E = fifelse(is.na(E), 0, E), N = fifelse(is.na(N), 0L, N))]
  dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
  write_parquet(out[, .(row_id, N, E)], f)
  out
}

# core.py: WENDY 9 ladder -------------------------------------------------------------------------------------------
HC <- c("previous_insurer", "occupation")
FREQ_BASE <- list(objective = "poisson", learning_rate = 0.05, num_leaves = 31, min_data_in_leaf = 500, feature_fraction = 0.7,
                  bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = 10, verbose = -1, num_threads = 2, seed = 5, max_bin = 127,
                  cat_smooth = 20, min_data_per_group = 200)
SEV_BASE <- list(objective = "gamma", learning_rate = 0.03, num_leaves = 7, min_data_in_leaf = 200, feature_fraction = 0.8,
                 bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = 10, verbose = -1, num_threads = 2, seed = 6, max_bin = 63,
                 cat_smooth = 50, min_data_per_group = 100)
P2A <- list(num_leaves = 8, max_depth = 3, min_data_in_leaf = 100, min_sum_hessian_in_leaf = 60)
FREQ_RECIPES <- list(   # run_freq.py VAR, the G recipes used by the submission (feats = BASE: all but HC; motor rate-encoded)
  G1 = list(num_leaves = 16, max_depth = 4), G2 = list(min_sum_hessian_in_leaf = 20), G3 = list(min_sum_hessian_in_leaf = 150),
  G4 = list(num_leaves = 4, max_depth = 2), G5 = list(num_leaves = 2, max_depth = 1, learning_rate = 0.1),
  G6 = list(num_leaves = 4, max_depth = 2, min_sum_hessian_in_leaf = 150), G7 = list(num_leaves = 3, max_depth = 2),
  G8 = list(min_sum_hessian_in_leaf = 6), G9 = list(num_leaves = 16, max_depth = 4, min_sum_hessian_in_leaf = 20))
upd <- function(base, kw) { for (k in names(kw)) base[[k]] <- kw[[k]]; base }
q_nearest <- function(v, q) { v <- sort(v); v[floor((length(v) - 1) * q + 0.5) + 1] }   # polars quantile, "nearest"

w_ladder_data <- function(line) {
  d <- w_fe(line); cats <- attr(d, "cats"); allfeats <- setdiff(names(d), c(FE_DROP, BASE_EXCL))
  c <- w_claims_rows(line)[status != "repudiated"]
  ps <- as.numeric(d$period_start); pe <- as.numeric(d$period_end); cut <- as.numeric(VAL_DATE)
  for (p in PERILS[[line]]) {
    cp <- c[c$peril == p]
    n <- cp[, .(n = sum(net > 0)), by = row_id]
    set(d, j = paste0("n_", p), value = fifelse(is.na(m <- n$n[match(d$row_id, n$row_id)]), 0, as.double(m)))
    cl <- cp[as.integer(format(loss_date, "%Y")) <= 2022]
    lag <- sort(pmax(as.numeric(cl$report_date - cl$loss_date), 0)); acc <- numeric(nrow(d))
    for (q in (0:15 + 0.5) / 16) acc <- acc + findInterval(cut - (ps + (pe - ps) * q), lag) / length(lag)
    set(d, j = paste0("s_", p), value = pmax(acc / 16, 0.03))
  }
  L <- list(line = line, d = d, cats = cats, allfeats = allfeats,
            claims = c[net > 0], year = d$year, is_test = d$is_test == 1L, expo = d$exposure,
            hold = hash_hold3(d$policy_id) == 0L)
  L
}
w_X <- function(L, feats) {
  X <- matrix(0, nrow(L$d), length(feats), dimnames = list(NULL, feats))
  for (i in seq_along(feats)) X[, i] <- f32(L$d[[feats[i]]])
  X
}
w_rate_encode <- function(L, X, feats, tr, n, w) {   # categorical -> rank of credibility-weighted training rate
  base <- sum(n[tr]) / sum(w[tr]); kk <- 1 / base * 20
  for (i in which(feats %in% L$cats)) {
    codes <- X[, i]; codes[is.na(codes)] <- -1; codes <- as.integer(codes) + 1L; m <- max(codes) + 1L
    nn <- vapply(split(n[tr], factor(codes[tr], levels = 0:(m - 1))), sum, 0)
    ww <- vapply(split(w[tr], factor(codes[tr], levels = 0:(m - 1))), sum, 0)
    rate <- (nn + 20) / (ww + kk)
    X[, i] <- f32((order(order(rate)) - 1)[codes + 1L])
  }
  X
}
w_fit_freq <- function(L, peril, recipe, vy = 2025L, fy = 2021:2024) {
  feats <- setdiff(L$allfeats, HC); enc_rate <- L$line == "motor"
  prm <- upd(upd(FREQ_BASE, P2A), FREQ_RECIPES[[recipe]])
  tr <- L$year %in% fy & !L$is_test; sc <- if (vy < 2025) L$year == vy & !L$is_test else L$is_test
  X <- w_X(L, feats); n <- L$d[[paste0("n_", peril)]]; w <- L$expo * L$d[[paste0("s_", peril)]]; y <- n / w
  ci <- which(feats %in% L$cats); if (!length(ci)) ci <- NULL
  if (enc_rate) { X <- w_rate_encode(L, X, feats, tr, n, w); ci <- NULL }
  itr <- which(tr); h <- L$hold[itr]
  dt <- lgb.Dataset(X[itr[!h], , drop = FALSE], label = y[itr[!h]], weight = w[itr[!h]], categorical_feature = ci, free_raw_data = FALSE)
  dv <- lgb.Dataset.create.valid(dt, X[itr[h], , drop = FALSE], label = y[itr[h]], weight = w[itr[h]])
  m <- lgb.train(prm, dt, nrounds = 3000, valids = list(v = dv), early_stopping_rounds = 100, verbose = -1)
  rounds <- max(m$best_iter, 10L)
  m <- lgb.train(prm, lgb.Dataset(X[itr, , drop = FALSE], label = y[itr], weight = w[itr], categorical_feature = ci), nrounds = rounds, verbose = -1)
  bal <- sum(n[itr]) / sum(predict(m, X[itr, , drop = FALSE]) * w[itr])
  list(pred = predict(m, X[sc, , drop = FALSE]) * L$expo[sc] * bal, rounds = rounds, model = m)
}
w_sev_claims <- function(L, peril, fy) { pp <- peril; c <- L$claims[L$claims$peril == pp & as.integer(format(L$claims$loss_date, "%Y")) %in% fy]; c[, ly := as.integer(format(loss_date, "%Y"))]; c }
w_sev_trend <- function(L, peril, fy, cap_q = 0.995, lo = -0.02, hi = 0.10) {
  c <- w_sev_claims(L, peril, fy); cap <- q_nearest(c$net, cap_q)
  ks <- kahan_by(pmin(pmax(c$net, 0), cap), c$ly); s <- ks$sum / ks$n
  if (length(s) < 2) return(0)
  b <- lm.wfit(cbind(1, ks$key), log(s), ks$n)$coefficients[2]
  min(max(unname(b), lo), hi)
}
w_fit_sev <- function(L, peril, recipe, vy = 2025L, fy = 2021:2024, cap_q = 0.995) {
  feats <- if (recipe == "SA") setdiff(L$allfeats, HC) else L$allfeats
  g <- switch(recipe, SA = , S4 = w_sev_trend(L, peril, fy, cap_q, lo = 0), S6 = 0.05)
  c <- w_sev_claims(L, peril, fy); cap <- q_nearest(c$net, cap_q)
  capped <- pmin(pmax(c$net, 0), cap)
  load <- kahan_by(c$net, rep(1L, nrow(c)))$sum / kahan_by(capped, rep(1L, nrow(c)))$sum
  amt <- capped * exp(g * (vy - c$ly))
  rows <- match(c$row_id, L$d$row_id); X <- w_X(L, feats); ci <- which(feats %in% L$cats); Xc <- X[rows, , drop = FALSE]
  h <- hash_hold3(c$policy_id) == 0L
  dt <- lgb.Dataset(Xc[!h, , drop = FALSE], label = amt[!h], categorical_feature = ci, free_raw_data = FALSE)
  dv <- lgb.Dataset.create.valid(dt, Xc[h, , drop = FALSE], label = amt[h])
  m <- lgb.train(SEV_BASE, dt, nrounds = 3000, valids = list(v = dv), early_stopping_rounds = 100, verbose = -1)
  r <- max(m$best_iter, 5L)
  m <- lgb.train(SEV_BASE, lgb.Dataset(Xc, label = amt, categorical_feature = ci), nrounds = r, verbose = -1)
  bal <- mean(amt) / mean(predict(m, Xc))
  sc <- if (vy < 2025) L$year == vy & !L$is_test else L$is_test
  list(pred = predict(m, X[sc, , drop = FALSE]) * bal * load, rounds = r, trend = g, cap = cap, load = load, model = m)
}
