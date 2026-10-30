# 22_nb_backtest.R ----------------------------------------------------------------------------------------------------
# Purpose : NB round (27 Oct 2026). Backtest of the step 8 new-business load on the 2024 fold: the load is fitted exactly as
#           step 8 does for 2025 (nb_load_fns.R, same NB_* options), but on the 2023 model's own 2023 rows
#           (insample23_peril) and with the developed residuals of the 2023 developed fold only, then applied to the 2024
#           validation predictions of ADJ_TAG (frequency x load on new-business rows where step 7 did not keep
#           new_business). The result is written as a normal run tag, so 09 -> 13 gate -> 21 scorecard read it unchanged.
# Inputs  : data/week_2/optionB/adjust/<ADJ_TAG>/{insample23_peril,valid_2024_peril}.parquet, week2/output/07_adjust/levels_<ADJ_TAG>.csv,
#           week2/output/05_baseline/row_preds.parquet (NB_PRIOR dev / dev_jan), emerging features and claims
# Outputs : data/week_2/optionB/adjust/<RUN_TAG>/valid_2024_peril.parquet, week2/output/07_adjust/levels_<RUN_TAG>.csv,
#           week2/output/22_nb_backtest/<RUN_TAG>_loads.csv
# Run     : RUN_TAG=<tag> ADJ_TAG=x20nb NB_K=300 NB_PRIOR=one NB_LEVEL=line Rscript week2/R/22_nb_backtest.R
# Time    : under 1 minute

source("week2/R/00_setup_week2.R")
source("week2/R/nb_load_fns.R")
start_script("22_nb_backtest.R")
TAG <- Sys.getenv("RUN_TAG"); ADJ <- Sys.getenv("ADJ_TAG", "x20nb")
stopifnot(nzchar(TAG), TAG != ADJ, TAG != "main")
o <- nb_opts()
FEAT_DIR <- file.path(W2$data, "features")
nbf_of <- rbindlist(lapply(LINES, function(ln) read_w2(file.path(FEAT_DIR, sprintf("emerging_train_%s.parquet", ln)))[, .(row_id, new_business)]))
lv_a <- file.path(W2$output, "07_adjust", paste0("levels_", ADJ, ".csv"))
levels_tab <- fread(lv_a); track_input(lv_a)
nb_in_model <- levels_tab[, .(nb_factor = grepl("new_business", freq_factors) | grepl("new_business", sev_factors)), by = .(line, peril)]

clp <- claim_basis("emerging")
i23 <- read_w2(file.path(W2$data, "adjust", ADJ, "insample23_peril.parquet"))
i23 <- merge(i23, nbf_of, by = "row_id")
i23 <- merge(i23, clp[, .(adj = sum(cost)), by = .(row_id, peril)], by = c("row_id", "peril"), all.x = TRUE)
i23[is.na(adj), adj := 0]
i23[, `:=`(dev = adj / share, pred = exposure * freq_B * sev_B)]
devp <- if (o$prior != "one" || (o$level == "peril" && o$pprior != "line")) dev_nb_resid(2023L) else NULL
nbp <- nb_load_table(i23, nb_in_model, o, devp)

v <- read_w2(file.path(W2$data, "adjust", ADJ, "valid_2024_peril.parquet"))
cols <- names(v)
v <- merge(v, nbf_of, by = "row_id")
v <- merge(v, nbp[, .(line, peril, nb_load, nb_factor)], by = c("line", "peril"))
v[, nbf := fifelse(new_business & !nb_factor, nb_load, 1)]
v[, freq_B := freq_B * nbf]
write_w2(v[, ..cols], file.path(W2$data, "adjust", TAG, "valid_2024_peril.parquet"))
file.copy(lv_a, file.path(W2$output, "07_adjust", paste0("levels_", TAG, ".csv")), overwrite = TRUE)
save_csv(nbp, "22_nb_backtest", paste0(TAG, "_loads.csv"))
log_msg(sprintf("%s: NB options K=%s prior=%s level=%s KP=%s pprior=%s; line loads %s", TAG, o$K, o$prior, o$level, o$KP, o$pprior,
                paste(unique(nbp[, sprintf("%s %.3f", line, nb_load_line)]), collapse = ", ")))
print(nbp[, .(line, peril, nb_claims, nb_ae_rel = round(nb_ae_rel, 3), prior = round(prior, 3), z = round(z, 3),
              nb_claims_p, rel_p = round(rel_p, 3), nb_factor, nb_load = round(nb_load, 3))])
end_script()
