# 7_score_models_w2.R --------------------------------------------------------------------------------------------
# Week 2: standard scorecard (week2/R/score_w2.R) for the submitted models and their components, on the validation
# fold (fit 2023, score 2024). Frequency and severity are kept separate so each can be scored on its own.
#   BURN    emerging averages (step 5 F0 x S0), reference
#   S6      submission 1: step 5 transfer, 50/50 level-only / level + boost, step 6 credibility (k_freq 200, k_sev 100)
#   J3c     joint XGBoost with week 1 C5 settings x step 6 credibility (step 5b)
#   B4c     transfer + stronger emerging boost x step 6 credibility (step 5b)
#   BLEND3  submission 2: (S6 + J3c + B4c) / 3. Frequency = mean of the three frequencies; cost = mean of the three
#           costs; severity = cost / frequency (the severity implied by the blend)
# Needs: 5_models_w2.R and 5b_joint_w2.R (valid fold, saved with _f / _s parts).
# Run:  Rscript week2/R/7_score_models_w2.R
# Out:  week2/output/scores/model_scores.csv (all models, long), week2/output/scores/scorecards.md

source("week2/R/0_setup_w2.R")
source("week2/R/score_w2.R")
STEP <- "scores"

info5 <- fread(file.path(PATHS_W2$output, "5_models", "fit_info_valid.csv"))
p5 <- read_clean_w2("w2_preds_valid"); pj <- read_clean_w2("w2_joint_preds_valid")
if (!"J3_f" %in% names(pj)) stop("w2_joint_preds_valid has no frequency / severity parts: rerun 5b_joint_w2.R (W2_FOLDS=valid)")

# step 6 credibility factors, frequency (af) and severity (as) separately (same as 6_blend_w2.R)
s0 <- p5[, .(s0 = S0[1]), by = .(line, peril)]
lv <- merge(info5, s0, by = c("line", "peril"))
lv[, sum_ye := sev_claims_e * s0 / cap_loading][, `:=`(E_f = claims_e / level_freq, E_s = sum_ye / level_sev)]
lv[, `:=`(line_f = sum(claims_e) / sum(E_f), line_s = sum(sum_ye) / sum(E_s)), by = line]
cred <- function(lev, n, line_lev, k) { z <- n / (n + k); z * lev + (1 - z) * line_lev }
lv[, `:=`(af = cred(level_freq, claims_e, line_f, 200) / level_freq, as = cred(level_sev, sev_claims_e, line_s, 100) / level_sev)]

x <- merge(p5, pj[, !"exposure"], by = c("row_id", "line", "peril"))
x <- merge(x, lv[, .(line, peril, af, as)], by = c("line", "peril"))
x[, `:=`(S6_f = 0.5 * (F2 + F3) * af, S6_s = 0.5 * (S2 + S3) * as, J3c_f = J3_f * af, J3c_s = J3_s * as, B4c_f = B4_f * af, B4c_s = B4_s * as)]
x[, `:=`(BL_f = (S6_f + J3c_f + B4c_f) / 3, BL_cost = (S6_f * S6_s + J3c_f * J3c_s + B4c_f * B4c_s) / 3)]
x[, BL_s := BL_cost / pmax(BL_f, 1e-12)]

key <- c("row_id", "line", "peril", "exposure")
models <- list(
  BURN = list(x[, c(key, "F0", "S0"), with = FALSE], "F0", "S0", "Emerging average frequency x mean capped severity (reference)", "week2/R/5_models_w2.R"),
  S6 = list(x[, c(key, "S6_f", "S6_s"), with = FALSE], "S6_f", "S6_s",
            "Submission 1 (public 0.14860): developed LightGBM x emerging level, 50/50 level / boost, credibility k_freq 200 k_sev 100", "week2/R/6_blend_w2.R"),
  J3c = list(x[, c(key, "J3c_f", "J3c_s"), with = FALSE], "J3c_f", "J3c_s",
             "Joint developed + emerging XGBoost, week 1 C5 settings, emerging weight x5, 3 bags, step 6 credibility", "week2/R/5b_joint_w2.R"),
  B4c = list(x[, c(key, "B4c_f", "B4c_s"), with = FALSE], "B4c_f", "B4c_s",
             "Step 5 transfer + stronger emerging LightGBM boost, step 6 credibility", "week2/R/5b_joint_w2.R"),
  BLEND3 = list(x[, c(key, "BL_f", "BL_s", "BL_cost"), with = FALSE], "BL_f", "BL_s",
                "Submission 2 (public 0.15387): (S6 + J3c + B4c) / 3; severity = blended cost / blended frequency", "week2/R/6b_blend_joint_w2.R"))

scs <- rbindlist(lapply(names(models), function(m) {
  d <- copy(models[[m]][[1]]); setnames(d, c(models[[m]][[2]], models[[m]][[3]]), c("freq", "sev"))
  if ("BL_cost" %in% names(d)) setnames(d, "BL_cost", "cost")
  sc <- score_model_w2(d, m, models[[m]][[4]], models[[m]][[5]])
  record_scores_w2(sc)
  sc
}))

cmp <- dcast(scs[level != "peril"], model ~ component + line, value.var = "d2")
cmp <- cmp[match(names(models), model), c("model", paste0(rep(c("frequency", "severity", "cost"), each = 4), "_", c("ALL", LINES))), with = FALSE]
write_md_w2(c(
  "# Week 2 - model scorecards (validation: fit 2023, score 2024)", "",
  paste("Generated", format(Sys.time(), "%Y-%m-%d %H:%M"), "by `week2/R/7_score_models_w2.R` with `week2/R/score_w2.R`.",
        "Definitions: `week2/instructions/output_model_instruction.md`."), "",
  "## Comparison: D2 by component and line", "", md_table(cmp, 4),
  unlist(lapply(unique(scs$model), function(m) c(paste("##", m), "", scorecard_md_w2(scs[model == m]))))
), STEP, "scorecards.md")
print(cmp)
log_msg("Scorecards: ", out_w2(STEP, "scorecards.md"))
