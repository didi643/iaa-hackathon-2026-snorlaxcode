# 03b_emerging_extra.R --------------------------------------------------------------------------------------------------
# Purpose : Emerging-only rating fields for the step 7 adjustments, kept apart from the shared feature tables (the developed
#           baseline never sees them): gender (approved by Wendy on 25 Oct 2026, decision D027) and self_employed.
# Inputs  : data/week_2/optionB/clean/emerging_{train,test}_<line>.parquet
# Outputs : data/week_2/optionB/features/emerging_extra_{train,test}_<line>.parquet (row_id, gender, self_employed)
# Run     : Rscript week2/R/03b_emerging_extra.R
# Time    : seconds

source("week2/R/00_setup_week2.R")
start_script("03b_emerging_extra.R")
for (ln in LINES) for (part in c("train", "test")) {
  d <- read_w2(file.path(W2$clean, sprintf("emerging_%s_%s.parquet", part, ln)))
  write_w2(d[, .(row_id, gender = fifelse(is.na(gender), "missing", gender), self_employed = as.character(self_employed))],
           file.path(W2$data, "features", sprintf("emerging_extra_%s_%s.parquet", part, ln)))
}
add_decision("D002", "0", "gender: APPROVED by Wendy (25 Oct 2026) for the emerging adjustments; the developed baseline cannot use it (not in developed data)",
             "Exclude gender", "chat 25 Oct 2026", "decided (was open)")
add_decision("D003", "0", "reference_policies.parquet = 20 test policies for the office premium build-up in Wendy's report (no labels); not used for modelling; expenses.parquet for the premium build-up only",
             "Use as training rows", "Wendy, 25 Oct 2026", "decided (was open)")
update_step_log("3b", "Emerging-only fields (gender, self_employed)", "- gender approved by Wendy; kept out of the developed baseline, offered to step 7 only.")
end_script()
