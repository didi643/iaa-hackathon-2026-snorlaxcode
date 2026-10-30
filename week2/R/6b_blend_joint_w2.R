# 6b_blend_joint_w2.R --------------------------------------------------------------------------------------------
# Week 2 step 6b: 2025 file = equal-weight average of three models (best blend in step 5b validation, ALL D2 0.1120 vs
# 0.1106 for the submitted step 6 model, gain +0.0014 +/- 0.0011):
#   S6   step 6 model, the submitted file (public 0.14860)
#   J3c  joint XGBoost (developed + emerging rows, week 1 C5 settings) x step 6 credibility adjustment
#   B4c  step 5 transfer + stronger emerging boost x step 6 credibility adjustment
# The credibility adjustment per peril (k_freq 200, k_sev 100) uses the final-fold levels from step 5, as step 6 does.
# Needs: 6_blend_w2.R output (S6 file) and 5b_joint_w2.R with W2_FOLDS=final. Local only: never submitted without Wendy.
# Run:  Rscript week2/R/6b_blend_joint_w2.R          (W2_S6_FILE overrides the step 6 file)
# Out:  week2/output/submission/submission_w2_blend3_<run>.csv, week2/output/6b_blend/

source("week2/R/0_setup_w2.R")
STEP <- "6b_blend"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
S6_FILE <- Sys.getenv("W2_S6_FILE", out_w2("submission", "submission_w2_20261025_1816.csv"))

info5 <- fread(file.path(PATHS_W2$output, "5_models", "fit_info_final.csv"))
p5 <- read_clean_w2("w2_preds_final"); pj <- read_clean_w2("w2_joint_preds_final")
s0 <- p5[, .(s0 = S0[1]), by = .(line, peril)]
lv <- merge(info5, s0, by = c("line", "peril"))
lv[, sum_ye := sev_claims_e * s0 / cap_loading][, `:=`(E_f = claims_e / level_freq, E_s = sum_ye / level_sev)]
lv[, `:=`(line_f = sum(claims_e) / sum(E_f), line_s = sum(sum_ye) / sum(E_s)), by = line]
cred <- function(lev, n, line_lev, k) { z <- n / (n + k); z * lev + (1 - z) * line_lev }
lv[, adj := cred(level_freq, claims_e, line_f, 200) / level_freq * cred(level_sev, sev_claims_e, line_s, 100) / level_sev]

x <- merge(pj, lv[, .(line, peril, adj)], by = c("line", "peril"))
rows <- x[, .(J3c = sum(J3 * adj), B4c = sum(B4 * adj)), by = .(line, row_id)]
s6 <- fread(S6_FILE)
rows[, S6 := s6$prediction[match(row_id, s6$row_id)]]
rows[, prediction := (S6 + J3c + B4c) / 3]

ss <- read_e("sample_submission")
sub <- data.table(row_id = ss$row_id, prediction = rows$prediction[match(ss$row_id, rows$row_id)])
stopifnot(nrow(sub) == 209063L, !anyNA(sub$prediction), all(is.finite(sub$prediction)), all(sub$prediction >= 0), !anyDuplicated(sub$row_id))
f_sub <- out_w2("submission", paste0("submission_w2_blend3_", RUN_ID, ".csv"))
fwrite(sub, f_sub, scipen = 50)

expo <- rbindlist(lapply(LINES, function(ln) read_e(paste0("test_", ln))[, .(row_id, exposure, new_business, line = ln)]))
r <- merge(rows, expo, by = c("line", "row_id"))
burn <- r[, .(rows = .N, S6 = sum(S6) / sum(exposure), J3c = sum(J3c) / sum(exposure), B4c = sum(B4c) / sum(exposure),
              blend = sum(prediction) / sum(exposure), blend_new_business = sum(prediction[new_business]) / sum(exposure[new_business]),
              blend_renewal = sum(prediction[!new_business]) / sum(exposure[!new_business]),
              spearman_S6_J3c = cor(S6, J3c, method = "spearman"), spearman_S6_B4c = cor(S6, B4c, method = "spearman")), by = line]
save_csv_w2(burn, STEP, "burn_2025.csv")
write_md_w2(list(
  "# Week 2 - Step 6b: three-model blend for 2025", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "by `week2/R/6b_blend_joint_w2.R`. File:", paste0("`", f_sub, "`"), "(local; not submitted)."), "",
  "prediction = (S6 + J3c + B4c) / 3; validation evidence in `week2/output/5b_joint/validation_report.md`.", "",
  "## 2025 burn cost per unit of exposure, and rank agreement with S6", "", md_table(burn, 3)
), STEP, "blend_report.md")
print(burn)
log_msg("Submission written: ", f_sub)
