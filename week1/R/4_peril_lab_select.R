# 4_peril_lab_select.R ------------------------------------------------------------------------------------------
# Picks at most one winning variant per peril from week1/R/4_peril_lab_wendy07.R results and writes the settings for a
# confirmation run of week1/R/4_models_iterwendy07.R (5 bags, 2023-24 folds) - winners must survive that run too.
# Rule: mean ALL-lines gain over 2023-24 > MIN_GAIN, gain on each of 2023 and 2024 > -MAX_LOSS, and gain on the
# untouched-by-selection 2022 fold > -MAX_LOSS. Among passing variants of a peril, the largest 2023-24 gain wins.
#
# Run:  Rscript week1/R/4_peril_lab_select.R
# Out:  week1/output/4_check_reported/peril_lab/ ranked.csv, winners.csv, method_mix.csv, run_settings.txt

source("week1/R/0_setup.R")
LAB_DIR <- file.path(PATHS$output, "4_check_reported", "peril_lab")
MIN_GAIN <- as.numeric(Sys.getenv("MIN_GAIN", "0.00005"))
MAX_LOSS <- as.numeric(Sys.getenv("MAX_LOSS", "0.0001"))
r <- fread(file.path(LAB_DIR, "results.csv"))[!is.na(d_all_2023)]
r[, gain_2324 := (d_all_2023 + d_all_2024) / 2]
r[, pass := gain_2324 > MIN_GAIN & d_all_2023 > -MAX_LOSS & d_all_2024 > -MAX_LOSS & d_all_2022 > -MAX_LOSS]
setorder(r, line, peril, -gain_2324)
fwrite(r, file.path(LAB_DIR, "ranked.csv"))
win <- r[pass == TRUE, .SD[1], by = .(line, peril)]
fwrite(win, file.path(LAB_DIR, "winners.csv"))
print(r[, .(variants = .N, passing = sum(pass), best = id[1], best_gain = round(gain_2324[1], 5),
            best_2022 = round(d_all_2022[1], 5)), by = .(line, peril)])
print(win[, .(line, peril, id, desc, g2022 = round(d_all_2022, 5), g2023 = round(d_all_2023, 5), g2024 = round(d_all_2024, 5))])
log_msg("Sum of winners' 2023-24 gains (upper bound if additive): ", round(sum(win$gain_2324), 5))

# Settings for the confirmation run
mix <- fread(file.path(PATHS$output, "4_check_reported", "4_models_iterwendy04", "chosen_method.csv"))[, .(line, peril, method)]
fe <- "all:voluntary_excess=B"; se <- "motor/bodily_injury:freq_trend=none,sev_trend=none"
for (i in seq_len(nrow(win))) {
  w <- win[i]; key <- paste0(w$line, "/", w$peril)
  if (w$id == "method_other") { mix[line == w$line & peril == w$peril, method := w$method]; next }
  if (startsWith(w$id, "drop_")) fe <- c(fe, paste0(key, ":", strsplit(sub("^drop ", "", w$desc), ",")[[1]], "=-"))
  if (startsWith(w$id, "add_")) fe <- c(fe, paste0(key, ":", strsplit(sub("^add ", "", w$desc), ",")[[1]],
                                                    if (w$method == "tweedie") "=B" else "=F"))
  if (grepl("=", w$desc) && !startsWith(w$id, "drop_") && !startsWith(w$id, "add_")) se <- c(se, paste0(key, ":", gsub(" ", "", w$desc)))
}
fwrite(mix, file.path(LAB_DIR, "method_mix.csv"))
settings <- c(paste0("FEATURE_EDITS=", paste(fe, collapse = ";")), paste0("SPEC_EDITS=", paste(se, collapse = ";")),
              paste0("METHOD_MIX=", file.path(LAB_DIR, "method_mix.csv")))
writeLines(settings, file.path(LAB_DIR, "run_settings.txt"))
cat(settings, sep = "\n")
