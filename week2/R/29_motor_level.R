# 29_motor_level.R ---------------------------------------------------------------------------------------------------
# Purpose : Motor LEVEL candidates on #12 line_ensemble (Wendy, 30 Oct 2026), no probing. #12's motor ranking is kept;
#           only actuarial level levers judged under-stated are applied (buildings / contents unchanged):
#             BI  bodily injury severity x (trend x trend-to-base x development x large-loss)
#                 trend      : +4.5% a year to 2025 (mature developed loss years 2021-23 ~ +4%, emerging +4.9%) instead of 0
#                 to base    : the 2023 emerging BI claims were trended at 0 to the 2024 base, so the fitted level gains
#                              1 + g x share of 2023 claims (266 of 449 claims)
#                 development: late-reported BI claims are larger; mature-year factors at the emerging claim ages
#                              (2023 1.007, 2024 1.031), claim-weighted
#                 large-loss : developed capped-excess load / emerging load = 1.048 / 1.024 (benchmark ILF complement)
#             NB  new-business rows x full emerging NB A/E (1.237) / applied NB load (credibility-weighted 1.165)
#           Variants: L_BI (BI only), L_NB (NB only), L_FULL (both).
#           2024 check: the same factors on the validation fold (directional only: the NB load is a 2025 step 8 load).
# Inputs  : data/week_2/optionB/{adjust,final}/x20_tblend, week2/output/08_loadings/x20_tblend/loadings.csv, #12 csv
# Outputs : week2/output/29_motor_level/{results,burn_by_peril}.csv, MLV_* rows in week2/output/scores/model_scores.csv,
#           week2/output/submission/submission_<runid>_week2_motorlevel_<name>.csv (+ .md5)
# Run     : Rscript week2/R/29_motor_level.R

source("week2/R/0_setup_w2.R"); source("week2/R/score_w2.R")
suppressMessages(library(arrow))
AD <- "data/week_2/optionB"; OUT <- "week2/output/29_motor_level"; dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
SUB12 <- "week2/output/submission/submission_20261028_week2_optionB_line_ensemble.csv"
REF <- "x20_tblend"; RT_V <- "rt_var_b8_chosen"

# Factors ---------------------------------------------------------------------------------------------------------------
G_BI <- 0.045; SH23 <- 266 / 449
F_TREND <- 1 + G_BI; F_BASE <- 1 + G_BI * SH23
F_DEV <- (266 * 1.007 + 183 * 1.031) / 449
ld <- fread(file.path("week2/output/08_loadings", REF, "loadings.csv"))[line == "motor"]
F_LL <- ld[peril == "bodily_injury", developed_load / emerging_load]
F_BI <- F_TREND * F_BASE * F_DEV * F_LL
NB_AE <- ld$nb_ae_rel[1]; NB_APPLIED <- ld$nb_load[1]; F_NB <- NB_AE / NB_APPLIED
fac <- data.table(factor = c("bi_trend_2025", "bi_trend_to_base", "bi_development", "bi_large_loss", "bi_total", "nb_full_emerging"),
                  value = c(F_TREND, F_BASE, F_DEV, F_LL, F_BI, F_NB))
print(fac[, value := round(value, 4)][])
fwrite(fac, file.path(OUT, "factors.csv"))

V <- list(L_BI = c(bi = TRUE, nb = FALSE), L_NB = c(bi = FALSE, nb = TRUE), L_FULL = c(bi = TRUE, nb = TRUE))
DESC <- c(L_BI = sprintf("#12 with motor BI severity x %.4f (trend, trend-to-base, development, large-loss)", F_BI),
          L_NB = sprintf("#12 with motor new-business rows x %.4f (full emerging NB A/E %.3f / applied %.3f)", F_NB, NB_AE, NB_APPLIED),
          L_FULL = sprintf("#12 with motor BI severity x %.4f and NB rows x %.4f", F_BI, F_NB))

# Data ------------------------------------------------------------------------------------------------------------------
f0 <- as.data.table(read_parquet(file.path(AD, "final", REF, "pred_2025_peril.parquet")))[line == "motor", .(row_id, peril, exposure, nb = new_business & !nb_factor, pred_B)]
v0 <- as.data.table(read_parquet(file.path(AD, "adjust", REF, "valid_2024_peril.parquet")))[line == "motor", .(row_id, peril, exposure, freq_B, sev_B)]
nb24 <- read_clean_w2("emerging_train_motor")[policy_year == 2024L, .(row_id, nb = as.logical(new_business))]
v0 <- merge(v0, nb24, by = "row_id")
prop_v <- as.data.table(read_parquet(file.path(AD, "adjust", RT_V, "valid_2024_peril.parquet")))[line != "motor", .(row_id, line, peril, exposure, freq = exposure * freq_B, sev = sev_B)]
as_pred <- function(mv) rbind(mv[, .(row_id, line = "motor", peril, exposure, freq = exposure * freq_B, sev = sev_B)], prop_v)
act <- actuals_w2()
y24 <- act$rows[line == "motor", .(y = sum(y_dev)), by = row_id]

apply_v <- function(d, s) { d <- copy(d); m <- rep(1, nrow(d))
  if (s[["bi"]]) m <- m * fifelse(d$peril == "bodily_injury", F_BI, 1)
  if (s[["nb"]]) m <- m * fifelse(d$nb, F_NB, 1)
  if ("pred_B" %in% names(d)) d[, pred_B := pred_B * m] else d[, sev_B := sev_B * m]; d[] }

# Score, burn, A/E --------------------------------------------------------------------------------------------------------
get_d2 <- function(sc, comp, ln, lv) sc[component == comp & line == ln & level == lv, d2]
ae <- function(v) { c <- v[, .(cost = sum(exposure * freq_B * sev_B)), by = row_id][y24, on = "row_id"]; sum(c$y) / sum(c$cost, na.rm = TRUE) }
ref <- score_model_w2(as_pred(v0), "tmp", "", "")
res <- list(data.table(model = "#12 line_ensemble", motor_cost_d2 = get_d2(ref, "cost", "motor", "line"), all_cost_d2 = get_d2(ref, "cost", "ALL", "all"),
                       ae_motor_2024 = ae(v0), burn_motor_2025 = sum(f0$pred_B) / sum(f0[!duplicated(row_id), exposure])))
burn <- list(f0[, .(model = "#12", burn = sum(pred_B) / sum(f0[!duplicated(row_id), exposure])), by = peril])
FIN <- list()
for (nm in names(V)) {
  vv <- apply_v(v0, V[[nm]]); ff <- apply_v(f0, V[[nm]]); FIN[[nm]] <- ff
  sc <- score_model_w2(as_pred(vv), paste0("MLV_", nm), DESC[[nm]], "week2/R/29_motor_level.R"); record_scores_w2(sc)
  res[[nm]] <- data.table(model = paste0("MLV_", nm), motor_cost_d2 = get_d2(sc, "cost", "motor", "line"), all_cost_d2 = get_d2(sc, "cost", "ALL", "all"),
                          ae_motor_2024 = ae(vv), burn_motor_2025 = sum(ff$pred_B) / sum(ff[!duplicated(row_id), exposure]))
  burn[[nm]] <- ff[, .(model = nm, burn = sum(pred_B) / sum(ff[!duplicated(row_id), exposure])), by = peril]
}
res <- rbindlist(res)[, motor_vs_12 := burn_motor_2025 / burn_motor_2025[1]][, description := c("reference", DESC)]
burn <- dcast(rbindlist(burn), peril ~ model, value.var = "burn")
fwrite(res, file.path(OUT, "results.csv")); fwrite(burn, file.path(OUT, "burn_by_peril.csv"))
print(res[, !"description"][, lapply(.SD, function(z) if (is.numeric(z)) round(z, 5) else z)])
print(burn[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 1) else z)])

# Submission files: #12 with the motor rows replaced ----------------------------------------------------------------------
s12 <- fread(SUB12); RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M", tz = "Asia/Singapore")
chk <- f0[, .(p = sum(pred_B)), by = row_id][s12, on = "row_id", nomatch = 0]
stopifnot(max(abs(chk$p / chk$prediction - 1)) < 1e-9)   # #12 motor rows = x20_tblend pred_B
for (nm in names(V)) {
  m <- FIN[[nm]][, .(p = sum(pred_B)), by = row_id]
  s <- copy(s12)[m, prediction := i.p, on = "row_id"]
  ok <- c(nrow(s) == 209063L, !anyDuplicated(s$row_id), !anyNA(s$prediction), all(is.finite(s$prediction)), all(s$prediction >= 0),
          nrow(m) == sum(startsWith(s$row_id, "M")))
  if (!all(ok)) stop(nm, ": submission checks failed ", paste(which(!ok), collapse = ","))
  f <- sprintf("week2/output/submission/submission_%s_week2_motorlevel_%s.csv", RUN_ID, tolower(nm))
  fwrite(s, f, scipen = 50); md5 <- unname(tools::md5sum(f)); writeLines(paste(md5, basename(f)), paste0(f, ".md5"))
  im <- startsWith(s$row_id, "M")
  cat(sprintf("%s -> %s MD5 %s | total vs #12 %.4f | motor vs #12 %.4f | non-motor unchanged %s\n", nm, basename(f), md5,
              sum(s$prediction) / sum(s12$prediction), sum(s$prediction[im]) / sum(s12$prediction[im]), isTRUE(all.equal(s$prediction[!im], s12$prediction[!im]))))
}
