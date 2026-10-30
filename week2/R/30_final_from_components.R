# 30_final_from_components.R ---------------------------------------------------------------------------------------------
# Purpose : Rebuild the week 2 FINAL file (#31 motorlevel_l_full, public 0.16840) and its pre-probing base / fallback
#           (#12 line_ensemble, public 0.16690) from the two cached component predictions only. No Kaggle data, no model
#           fitting: seconds. Same arithmetic as week2/R/29_motor_level.R (factors, order of multiplication), which also
#           scores the factors on the 2024 fold and needs the full week 2 data.
#             #12   : motor rows = x20_tblend pred_B summed over perils; buildings / contents rows =
#                     rt_var_b8_floor_corrected pred_B summed over perils; sorted by row_id
#             #31   : #12 with motor bodily-injury severity x F_BI and motor new-business rows x F_NB
#                     (rows where new_business & !nb_factor; glass / hail already has new business as a model factor)
# Inputs  : data/week_2/optionB/final/{x20_tblend,rt_var_b8_floor_corrected}/pred_2025_peril.parquet,
#           week2/output/08_loadings/x20_tblend/loadings.csv (large-loss and new-business loads from step 8)
# Outputs : week2/output/final_rebuild/{submission_week2_line_ensemble_12.csv, submission_week2_motorlevel_l_full_31.csv}
#           Stops with an error if either MD5 differs from the submitted file.
# Run     : Rscript week2/R/30_final_from_components.R      (from the repo root)

suppressMessages({library(data.table); library(arrow)})
FIN <- "data/week_2/optionB/final"; OUT <- "week2/output/final_rebuild"; dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
WANT <- c(line_ensemble_12 = "bbd5ca2dbe6327161d93dad5dc36edbd", motorlevel_l_full_31 = "90120c605cee98bb3545e0b7b4b9a128")

# Factors (as week2/R/29_motor_level.R) -------------------------------------------------------------------------------
G_BI <- 0.045; SH23 <- 266 / 449
F_TREND <- 1 + G_BI; F_BASE <- 1 + G_BI * SH23
F_DEV <- (266 * 1.007 + 183 * 1.031) / 449
ld <- fread("week2/output/08_loadings/x20_tblend/loadings.csv")[line == "motor"]
F_LL <- ld[peril == "bodily_injury", developed_load / emerging_load]
F_BI <- F_TREND * F_BASE * F_DEV * F_LL
F_NB <- ld$nb_ae_rel[1] / ld$nb_load[1]
cat(sprintf("F_BI = %.4f (trend %.4f x to-base %.4f x development %.4f x large-loss %.4f), F_NB = %.4f\n",
            F_BI, F_TREND, F_BASE, F_DEV, F_LL, F_NB))

# Components ----------------------------------------------------------------------------------------------------------
m <- as.data.table(read_parquet(file.path(FIN, "x20_tblend", "pred_2025_peril.parquet")))[line == "motor",
       .(row_id, peril, nb = new_business & !nb_factor, pred_B)]
p <- as.data.table(read_parquet(file.path(FIN, "rt_var_b8_floor_corrected", "pred_2025_peril.parquet")))[line != "motor"]
s12 <- rbind(m[, .(prediction = sum(pred_B)), by = row_id], p[, .(prediction = sum(pred_B)), by = row_id])
setorder(s12, row_id)

k <- rep(1, nrow(m))
k <- k * fifelse(m$peril == "bodily_injury", F_BI, 1)
k <- k * fifelse(m$nb, F_NB, 1)
m[, pred_B := pred_B * k]
s31 <- copy(s12)[m[, .(p = sum(pred_B)), by = row_id], prediction := i.p, on = "row_id"]

# Write and check -----------------------------------------------------------------------------------------------------
ok_all <- TRUE
for (nm in names(WANT)) {
  s <- if (nm == "line_ensemble_12") s12 else s31
  ok <- c(rows = nrow(s) == 209063L, unique = !anyDuplicated(s$row_id), no_missing = !anyNA(s$prediction),
          not_negative = all(s$prediction >= 0))
  f <- file.path(OUT, sprintf("submission_week2_%s.csv", nm))
  fwrite(s, f, scipen = 50); md5 <- unname(tools::md5sum(f))
  ok <- c(ok, md5 = md5 == WANT[[nm]]); ok_all <- ok_all && all(ok)
  cat(sprintf("%-4s %s MD5 %s%s\n", if (all(ok)) "OK" else "FAIL", basename(f), md5,
              if (all(ok)) " (= submitted file)" else paste0(" | failed: ", paste(names(ok)[!ok], collapse = ", "))))
}
im <- startsWith(s12$row_id, "M")
cat(sprintf("motor total #31 / #12 = %.4f; buildings and contents unchanged: %s\n",
            sum(s31$prediction[im]) / sum(s12$prediction[im]), identical(s31$prediction[!im], s12$prediction[!im])))
if (!ok_all) stop("A rebuilt file does not match the submitted file")
