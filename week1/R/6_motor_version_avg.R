# 6_motor_version_avg.R ------------------------------------------------------------------------------------
# Cheap variance reduction for the MOTOR 4 candidate: per peril, average the frequency versions instead of picking
# one (no refits). Adds to MOTOR 4's components:
#   avg3_<peril>  mean of glm / lgb / boost (each rescaled to the glm total first)
#   avg2_<peril>  mean of glm / boost
#   m46_<peril>   mean of MOTOR 4 and MOTOR 6 (telematics) boost versions
# Writes week1/models/motor_iteration_07/components.parquet; judge with
#   MOTOR04_DIR=week1/models/motor_iteration_07 EVAL_TAG=motor07 M4_VERS=glm,lgb,boost,avg3,avg2,m46 Rscript week1/R/6_w9_motor04_eval.R

source("week1/R/0_setup.R")
PRM <- PERILS$motor
c4 <- as.data.table(read_parquet(file.path("week1", "models", "motor_iteration_04", "components.parquet")))
c6 <- as.data.table(read_parquet(file.path("week1", "models", "motor_iteration_06", "components.parquet")))[, c("valid_year", "row_id", paste0("boost_", PRM)), with = FALSE]
setnames(c6, paste0("boost_", PRM), paste0("b6_", PRM))
x <- merge(c4, c6, by = c("valid_year", "row_id"), sort = FALSE)
stopifnot(nrow(x) == nrow(c4))
for (p in PRM) {
  g <- x[[paste0("glm_", p)]]
  sc <- function(v) ave(v, x$valid_year, FUN = function(z) z) * ave(g, x$valid_year, FUN = sum) / ave(v, x$valid_year, FUN = sum)
  l <- sc(x[[paste0("lgb_", p)]]); b <- sc(x[[paste0("boost_", p)]]); b6 <- sc(x[[paste0("b6_", p)]])
  set(x, j = paste0("avg3_", p), value = (g + l + b) / 3)
  set(x, j = paste0("avg2_", p), value = (g + b) / 2)
  set(x, j = paste0("m46_", p), value = (b + b6) / 2)
}
x[, (paste0("b6_", PRM)) := NULL]
dir.create(file.path("week1", "models", "motor_iteration_07"), showWarnings = FALSE)
write_parquet(x, file.path("week1", "models", "motor_iteration_07", "components.parquet"))
log_msg("Wrote week1/models/motor_iteration_07/components.parquet (", nrow(x), " rows)")
