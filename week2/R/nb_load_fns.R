# nb_load_fns.R -------------------------------------------------------------------------------------------------------
# Purpose : NB round (27 Oct 2026, 2025 broker take-on treatment). Shared new-business load logic, used by step 8 (2025,
#           fitted on the final model's 2023-24 in-sample rows) and by 22_nb_backtest.R (fitted on the 2023 model's 2023
#           rows, applied to the 2024 fold), so the 2025 treatment can be judged on 2024 before it is used.
#           Defaults (NB_K 300, NB_PRIOR one, NB_LEVEL line) are the D020 step 8 load exactly.
# Options (env):
#   NB_K      line credibility constant, Z = n_NB / (n_NB + K). "Inf" = no load.
#   NB_PRIOR  complement of credibility for the line load: one (D020: developed relativity holds) | dev (the developed
#             baseline's own residual NB A/E on developed data, out of fold) | dev_jan (same, January-start NB only =
#             full-year new business, the shape of the 2025 take-on)
#   NB_LEVEL  line (one load per line) | peril (per-peril A/E credibility-weighted towards the peril complement)
#   NB_KP     peril credibility constant for NB_LEVEL = peril
#   NB_PPRIOR peril complement: line (the line load) | dev (line load x developed peril / line NB residual) | dev_jan (same
#             with January-start NB residuals = full-year seasonal shape per peril)
# Used by : week2/R/08_loadings_2025.R, week2/R/22_nb_backtest.R

nb_opts <- function() list(K = as.numeric(Sys.getenv("NB_K", "300")), prior = Sys.getenv("NB_PRIOR", "one"),
                           level = Sys.getenv("NB_LEVEL", "line"), KP = as.numeric(Sys.getenv("NB_KP", "300")),
                           pprior = Sys.getenv("NB_PPRIOR", "line"))

# Developed baseline residual NB A/E (out of fold, step 5 row_preds, developed actuals), relative to the line / peril overall
dev_nb_resid <- function(years = c(2023L, 2024L)) {
  rp <- read_w2(file.path(W2$output, "05_baseline", "row_preds.parquet"))[valid_year %in% years]
  f <- rbindlist(lapply(LINES, function(l) read_w2(file.path(W2$data, "features", sprintf("developed_train_%s.parquet", l)))[
    , .(row_id, line = l, new_business, start_month)]))
  rp <- merge(rp, f, by = c("row_id", "line"))
  rbindlist(lapply(LINES, function(l) rbindlist(lapply(c(PERILS[[l]], "ALL"), function(pr) {
    pc <- if (pr == "ALL") "pred" else paste0("pred_", pr); ac <- if (pr == "ALL") "developed" else paste0("developed_", pr)
    x <- rp[line == l]; tot <- sum(x[[ac]]) / sum(x[[pc]])
    nb <- x[new_business == TRUE]; jn <- nb[start_month == 1]
    data.table(line = l, peril = pr, rel_all = sum(nb[[ac]]) / sum(nb[[pc]]) / tot, rel_jan = sum(jn[[ac]]) / sum(jn[[pc]]) / tot)
  }))))
}

# ins: line, peril, new_business, pred (expected cost), dev (developed-basis actual), n (claims); nb_in_model: line, peril, nb_factor
nb_load_table <- function(ins, nb_in_model, o = nb_opts(), devp = NULL) {
  if (o$prior != "one" || (o$level == "peril" && o$pprior != "line")) stopifnot(!is.null(devp))
  nb <- ins[, .(pred = sum(pred), actual = sum(dev), claims = sum(n)), by = .(line, new_business)]
  nb[, ae := actual / pred]
  nb[, rel := ae / (sum(actual) / sum(pred)), by = line]
  L <- nb[new_business == TRUE, .(line, nb_claims = claims, nb_ae_rel = rel)]
  dl <- if (!is.null(devp)) devp[peril == "ALL"] else NULL
  L[, prior := switch(o$prior, one = 1, dev = dl$rel_all[match(line, dl$line)], dev_jan = dl$rel_jan[match(line, dl$line)])]
  L[, z := nb_claims / (nb_claims + o$K)]
  L[, nb_load_line := prior + z * (nb_ae_rel - prior)]
  P <- ins[, .(pred = sum(pred), actual = sum(dev), claims = sum(n)), by = .(line, peril, new_business)]
  P[, rel_p := (actual / pred) / (sum(actual) / sum(pred)), by = .(line, peril)]
  P <- merge(P[new_business == TRUE, .(line, peril, nb_claims_p = claims, rel_p)], nb_in_model, by = c("line", "peril"), all.y = TRUE)
  P[is.na(nb_claims_p), `:=`(nb_claims_p = 0, rel_p = 1)]
  P <- merge(P, L, by = "line")
  if (o$level == "line") {
    P[, nb_load := nb_load_line]
  } else {
    P[, pp := nb_load_line]
    if (o$pprior == "dev") P[, pp := nb_load_line * devp$rel_all[match(paste(line, peril), paste(devp$line, devp$peril))] /
                                dl$rel_all[match(line, dl$line)]]
    if (o$pprior == "dev_jan") P[, pp := nb_load_line * devp$rel_jan[match(paste(line, peril), paste(devp$line, devp$peril))] /
                                    dl$rel_jan[match(line, dl$line)]]
    P[, zp := nb_claims_p / (nb_claims_p + o$KP)]
    P[, nb_load := pp + zp * (rel_p - pp)]
  }
  P[]
}
