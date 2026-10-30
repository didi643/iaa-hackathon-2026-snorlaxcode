# 6_ladder.R -------------------------------------------------------------------------------------------------------
# WENDY 9 ladder, 2025 fit (R port of Wendy's Python core.py / run_freq.py / run_sev.py; code in R/w89_core.R), for the
# perils with ladder weight > 0 in inputs/assemble_weights.json, with the recipes of inputs/assemble_combo.json:
#   frequency  LightGBM Poisson, label = claims (net > 0) / (exposure x reported share), weight = exposure x share,
#              features = all but previous_insurer / occupation (motor: categoricals as rank of credibility-weighted rate),
#              early stopping on the 10% policy holdout (polars hash), refit on all 2021-24 rows, balanced to the claim count
#   severity   LightGBM gamma on claims capped at p99.5 ("nearest"), trended to 2025 (SA / S4: fitted log-linear trend
#              clamped to [0%, 10%]; S6: 5%), early stopping on the same holdout, refit, x balance x cap loading
#   ladder     freq x sev per 2025 row
# Check: rounds, trend, cap and loading vs inputs/w9_final_details.json (the submitted run).
# Out: models/wendy_iteration_09/ladder_2025.parquet (row_id, line, peril, freq, sev, lad), fitted/<line>_<peril>_<freq|sev>.txt,
#      ladder_details.csv

source("R/0_setup.R")
source("R/w89_core.R")
OUT <- file.path("models", "wendy_iteration_09")
dir.create(file.path(OUT, "fitted"), recursive = TRUE, showWarnings = FALSE)
combo <- jsonlite::fromJSON("inputs/assemble_combo.json")
wts <- jsonlite::fromJSON("inputs/assemble_weights.json")
ref <- rbindlist(lapply(jsonlite::fromJSON("inputs/w9_final_details.json", simplifyVector = FALSE), function(r)
  if (is.null(r$freq_rounds_final)) NULL else data.table(line = r$line, peril = r$peril, freq_rounds_ref = r$freq_rounds_final,
    sev_rounds_ref = r$sev_rounds_final, trend_ref = as.numeric(r$sev_trend_final), cap_ref = as.numeric(r$sev_cap_final),
    load_ref = as.numeric(r$sev_cap_loading))))

preds <- list(); info <- list()
for (ln in LINES) {
  L <- w_ladder_data(ln); rid <- L$d$row_id[L$is_test]
  for (p in PERILS[[ln]]) {
    if (wts$W[[ln]][[p]] <= 0) next
    t0 <- Sys.time(); rc <- combo[[ln]][[p]]
    f <- w_fit_freq(L, p, rc[1]); s <- w_fit_sev(L, p, rc[2])
    lgb.save(f$model, file.path(OUT, "fitted", sprintf("%s_%s_freq_%s.txt", ln, p, rc[1])))
    lgb.save(s$model, file.path(OUT, "fitted", sprintf("%s_%s_sev_%s.txt", ln, p, rc[2])))
    preds[[paste(ln, p)]] <- data.table(row_id = rid, line = ln, peril = p, freq = f$pred, sev = s$pred, lad = f$pred * s$pred)
    info[[paste(ln, p)]] <- data.table(line = ln, peril = p, w_ladder = wts$W[[ln]][[p]], freq_recipe = rc[1], sev_recipe = rc[2],
                                       freq_rounds = f$rounds, sev_rounds = s$rounds, trend = s$trend, cap = s$cap, load = s$load,
                                       burn_ladder = sum(f$pred * s$pred) / sum(L$expo[L$is_test]))
    log_msg(ln, " ", p, " ", rc[1], "/", rc[2], ": rounds ", f$rounds, " / ", s$rounds, ", trend ", round(s$trend, 5), " (",
            round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min)")
  }
}
write_parquet(rbindlist(preds), file.path(OUT, "ladder_2025.parquet"))
info <- merge(rbindlist(info), ref, by = c("line", "peril"), all.x = TRUE, sort = FALSE)
info[, matches_submitted := freq_rounds == freq_rounds_ref & sev_rounds == sev_rounds_ref & abs(trend - trend_ref) < 1e-9 &
       abs(cap - cap_ref) < 1e-9 & abs(load / load_ref - 1) < 1e-9]
fwrite(info, file.path(OUT, "ladder_details.csv"))
print(info[, .(line, peril, freq_recipe, sev_recipe, freq_rounds, sev_rounds, trend = round(trend, 5), matches_submitted)])
if (!all(info$matches_submitted)) warning("Some ladder fits differ from the submitted run - see ladder_details.csv")
