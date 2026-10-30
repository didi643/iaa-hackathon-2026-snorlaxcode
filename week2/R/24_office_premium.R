# 24_office_premium.R : office premium for the 20 reference policies from the final model's risk premium.
# Method: P = (RP x (1 + cat RI share) + fixed expense x exposure) / (1 - variable - commission - tax - profit).
# Inputs : SUB = submission file whose prediction is the risk premium (default: final #31 motorlevel_l_full, public 0.16840)
# Output : week2/output/office_premium_reference_policies.csv
# Run     : Rscript week2/R/24_office_premium.R   (from the repo root)
suppressPackageStartupMessages({library(arrow); library(data.table)})
f <- "data/week_2/raw data/emerging/"
ex <- as.data.table(read_parquet(paste0(f, "expenses.parquet")))
x <- setNames(ex$emerging, ex$item)
ref <- as.data.table(read_parquet(paste0(f, "reference_policies.parquet")))
SUB <- Sys.getenv("SUB", "week2/output/submission/submission_20261030_0905_week2_motorlevel_l_full.csv")
OUT <- Sys.getenv("OUT", "week2/output/office_premium_reference_policies.csv")
sub <- fread(SUB)
d <- merge(ref[, .(row_id, line, exposure, channel)], sub, by = "row_id")
d[, commission := fifelse(channel == "broker", x[["commission_broker"]], x[["commission_direct"]])]
d[, cat_ri := fifelse(line %in% c("buildings", "contents"), x[["cat_reinsurance"]] * prediction, 0)]
d[, fixed := x[["fixed_expense_per_policy"]] * exposure]
d[, denom := 1 - x[["variable_expense"]] - commission - x[["premium_tax"]] - x[["target_profit_margin"]]]
d[, office := (prediction + cat_ri + fixed) / denom]
d[, `:=`(variable = x[["variable_expense"]] * office, comm_cu = commission * office, tax = x[["premium_tax"]] * office,
         profit = x[["target_profit_margin"]] * office)]
d[, check := prediction + cat_ri + fixed + variable + comm_cu + tax + profit - office]
stopifnot(nrow(d) == nrow(ref), all(abs(d$check) < 1e-6))
setnames(d, "prediction", "risk_premium")
fwrite(d, OUT)
print(d[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
