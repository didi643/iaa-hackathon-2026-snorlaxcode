# ben/ben_helpers.R ----------------------------------------------------------
# Settings and helpers for BEN's own steps (week1/R/ben/ben_clean.R) and the BEN iterations that use them.
# Source after week1/R/0_setup.R. Nothing here changes the shared data/week_1/clean/ tables or week1/R/0_setup.R.

BEN_PATHS <- list(data = file.path("data", "week_1", "ben"), output = file.path(PATHS$output, "ben"))

# Data types that match each column's meaning for tree models (XGBoost splits on "less than / greater than"):
# ordered text -> integers in their natural order ("missing" and unknown values -> NA, which XGBoost routes itself)
BEN_ORDINAL <- list(
  credit_band    = c("A", "B", "C", "D", "E"),                                   # A best
  energy_rating  = c("A", "B", "C", "D", "E", "F", "G"),                         # A best
  urban_density  = c("rural", "suburban", "urban", "dense_urban"),
  security_level = c("standard", "locks", "alarm_and_locks"),
  cover_type     = c("third_party_only", "third_party_fire_theft", "comprehensive")
)
# labels stored as numbers -> text, so the model treats them as categories (branch 20 is not "more" than branch 3)
BEN_AS_CATEGORY <- c("branch_id", "start_month")

# Claims history known when the row starts (week1/R/ben/ben_clean.R section 2)
BEN_HISTORY_DAYS <- 365
BEN_HISTORY <- c("hist_policy_claims", "hist_policy_cost", "hist_customer_other_claims", "hist_address_property_claims")

read_ben <- function(name) {
  f <- file.path(BEN_PATHS$data, paste0(name, ".parquet"))
  if (!file.exists(f)) stop("Missing ", f, " - run week1/R/ben/ben_clean.R first.")
  as.data.table(read_parquet(f))
}

ben_out <- function(file) {
  path <- file.path(BEN_PATHS$output, file)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  path
}

# Chain-ladder IBNR (BEN 3: week1/R/ben/ben3_study.R, week1/R/ben/ben3_data.R) --------------------------------------------
MIN_DEV_CLAIMS <- 30             # fewer claims behind a peril's development factor -> use the line's factor
month_index <- function(x) (year(x) - 2021L) * 12L + month(x)   # Jan 2021 = 1
month_start <- function(a) as.Date(sprintf("%d-%02d-01", 2021L + (a - 1L) %/% 12L, (a - 1L) %% 12L + 1L))

# Monthly accident x report-delay triangle at valuation V; volume-weighted age-to-age factors per line x peril, the
# line's pooled factor where a peril has fewer than MIN_DEV_CLAIMS claims behind it; no tail beyond the oldest month.
# cc: non-repudiated claims with line, peril, loss_date, report_date, net_cost, cost_cap.
# Returns, per line x peril x accident month, the share of ultimate already reported at V (counts and cost).
dev_shares <- function(cc, V) {
  nV <- month_index(V)
  d <- cc[loss_date >= as.Date("2021-01-01") & loss_date <= V & report_date <= V,
          .(line, peril, a = month_index(loss_date), k = month_index(report_date) - month_index(loss_date),
            n = 1, w = pmin(net_cost, cost_cap))]
  grid_for <- function(keys) {
    g <- CJ(a = seq_len(nV), k = 0:(nV - 1))[k <= nV - a]
    keys[, as.list(g), by = names(keys)]
  }
  factors <- function(d, by) {
    keys <- unique(d[, ..by])
    g <- grid_for(keys)
    inc <- d[, .(n = sum(n), w = sum(w)), by = c(by, "a", "k")]
    g <- merge(g, inc, by = c(by, "a", "k"), all.x = TRUE)
    g[is.na(n), `:=`(n = 0, w = 0)]
    setorderv(g, c(by, "a", "k"))
    g[, `:=`(N = cumsum(n), W = cumsum(w)), by = c(by, "a")]
    nxt <- g[, c(by, "a", "k", "N", "W"), with = FALSE][, k := k - 1L]
    setnames(nxt, c("N", "W"), c("N1", "W1"))
    p <- merge(g, nxt, by = c(by, "a", "k"))          # pairs (k, k+1) observed for the same accident month
    p[, .(f_n = sum(N1) / sum(N), f_w = sum(W1) / sum(W), base_claims = sum(N)), by = c(by, "k")]
  }
  fp <- factors(d, c("line", "peril"))
  fl <- factors(d, "line")
  setnames(fl, c("f_n", "f_w", "base_claims"), c("fl_n", "fl_w", "line_claims"))
  f <- merge(fp, fl, by = c("line", "k"), all.x = TRUE)
  f[, `:=`(f_n = fifelse(base_claims >= MIN_DEV_CLAIMS & is.finite(f_n), f_n, fl_n),
           f_w = fifelse(base_claims >= MIN_DEV_CLAIMS & is.finite(f_w), f_w, fl_w))]
  f[!is.finite(f_n), f_n := 1]; f[!is.finite(f_w), f_w := 1]
  setorder(f, line, peril, -k)
  f[, `:=`(cdf_n = cumprod(f_n), cdf_w = cumprod(f_w)), by = .(line, peril)]   # development from age k+1 to the end
  # accident month a is observed to age nV - a; its share reported = 1 / product of factors from that age on
  s <- unique(d[, .(line, peril)])[, .(a = seq_len(nV)), by = .(line, peril)]
  s[, k := nV - a]
  s <- merge(s, f[, .(line, peril, k, cdf_n, cdf_w)], by = c("line", "peril", "k"), all.x = TRUE)
  s[is.na(cdf_n), `:=`(cdf_n = 1, cdf_w = 1)]
  s[, .(line, peril, a, share_n = 1 / cdf_n, share_w = 1 / cdf_w)]
}

# Share of a row's expected claims already reported at V: its exposure spread evenly over its days (how = "row"), or
# over the whole policy year (how = "year", as week1/R/3_incidence.R and SAM 3 do). r: row_id, line, policy_year, period_*.
row_share <- function(r, sh, V, how) {
  if (how == "year") r <- unique(r[, .(line, policy_year)])[
    , `:=`(period_start = as.Date(paste0(policy_year, "-01-01")), period_end = as.Date(paste0(policy_year, "-12-31")))]
  spans <- unique(r[, .(line, policy_year, period_start, period_end)])   # few distinct date spans, many rows
  spans[, `:=`(id = .I, last = pmin(period_end, V))]
  m <- spans[, .(a = month_index(period_start):month_index(last)), by = .(id, line, period_start, last)]
  m[, days := as.numeric(pmin(last, month_start(a + 1L) - 1) - pmax(period_start, month_start(a)) + 1)]
  m <- merge(m, sh, by = c("line", "a"), allow.cartesian = TRUE)
  s <- m[, .(share_n = sum(days * share_n) / sum(days), share_w = sum(days * share_w) / sum(days)), by = .(id, peril)]
  s <- merge(spans[, .(id, line, policy_year, period_start, period_end)], s, by = "id")
  if (how == "year") return(s[, .(line, policy_year, peril, share_n, share_w)])
  merge(r[, .(row_id, line, policy_year, period_start, period_end)], s, by = c("line", "policy_year", "period_start", "period_end"),
        allow.cartesian = TRUE)[, .(row_id, peril, share_n, share_w)]
}
