source("week1/R/0_setup.R")
source("week1/R/model_io.R")

dt <- data.table(
  exposure = c(1, 2, 0.5),
  segment = c("a", "unseen", NA_character_),
  written_premium = c(10, 20, 30)
)
glm_artifact <- list(
  model = "glm_freq_sev", line = "motor", loading = 1,
  specs = list(segment = list(type = "cat", levels = c("a", "missing"), base = "a")),
  coef_freq = c("(Intercept)" = log(2), segmentmissing = log(3)),
  coef_sev = c("(Intercept)" = log(5), segmentmissing = log(2))
)
lgb_artifact <- list(model = "burn_cost", line = "motor", loading = 1, rate = 4)
ensemble <- list(model = "glm_lgb_ensemble", line = "motor", glm_weight = 0.25, lgb_weight = 0.75,
                 glm_artifact = glm_artifact, lgb_artifact = lgb_artifact)

glm_pred <- score_model(glm_artifact, dt)
lgb_pred <- score_model(lgb_artifact, dt)
pred <- score_model(ensemble, dt)
expected <- (0.25 * glm_pred / dt$exposure + 0.75 * lgb_pred / dt$exposure) * dt$exposure
stopifnot(all(is.finite(glm_pred)), all(is.finite(lgb_pred)), all(is.finite(pred)),
          all(pred >= 0), max(abs(pred - expected)) < 1e-12,
          ensemble$glm_weight + ensemble$lgb_weight == 1)

dir <- tempfile("ensemble_io_")
save_model(ensemble, dir, "motor_glm_lgb_ensemble")
reloaded <- load_model(dir, "motor_glm_lgb_ensemble")
reloaded_pred <- score_model(reloaded, dt)
stopifnot(max(abs(pred - reloaded_pred)) < 1e-12,
          identical(reloaded$glm_artifact$model, "glm_freq_sev"),
          identical(reloaded$lgb_artifact$model, "burn_cost"))

cat("ensemble model I/O passed\n")

# sam_iteration_02 types: per-peril GLM x tree frequency, line tree bag and blend survive save / load unchanged
set.seed(1)
n <- 400
sd <- data.table(exposure = runif(n, 0.2, 1), policy_year = sample(2023:2025, n, TRUE),
                 x1 = rnorm(n), seg = sample(c("a", "b"), n, TRUE))
sd[, y := rpois(n, exposure * exp(-1 + 0.5 * x1))]
X <- lgb_matrix(sd, c("x1", "seg"), list(seg = c("a", "b")))
lgb_b <- lgb.train(list(objective = "poisson", verbosity = -1, min_data_in_leaf = 20, num_threads = 1),
                   lgb.Dataset(X, label = sd$y / sd$exposure, weight = sd$exposure), nrounds = 5)
xgb_b <- xgboost::xgb.train(list(objective = "count:poisson", nthread = 1),
                            xgboost::xgb.DMatrix(X, label = sd$y / sd$exposure, weight = sd$exposure), nrounds = 5, verbose = 0)
g <- list(specs = list(seg = list(type = "cat", levels = c("a", "b"), base = "a")),
          coef = c("(Intercept)" = log(0.3), segb = log(1.2)), year_ref = 2024, year_coef = log(1.05))
s <- list(specs = list(), coef = c("(Intercept)" = log(1000)), year_ref = 2024, year_coef = 0)
tree <- function(kind, b) list(kind = kind, boosters = list(b), features = c("x1", "seg"), cat_levels = list(seg = c("a", "b")))
peril_glm <- list(model = "sam02_peril", line = "motor",
                  perils = list(theft = list(peril = "theft", freq_glm = g, sev_glm = s, loading = 1.02)))
peril_lgb <- peril_glm
peril_lgb$perils$theft$freq_tree <- tree("lgb", lgb_b)
line_xgb <- list(model = "sam02_line_tree", line = "motor", tree = tree("xgb", xgb_b), level_artifact = peril_glm)
blend <- list(model = "sam02_blend", line = "motor", components = list(peril_glm, peril_lgb, line_xgb), weights = c(0.2, 0.5, 0.3))
p_glm <- score_model(peril_glm, sd)
stopifnot(max(abs(p_glm - 0.3 * 1.2^(sd$seg == "b") * 1.05^(sd$policy_year - 2024) * 1000 * 1.02 * sd$exposure)) < 1e-9,
          abs(sum(score_model(peril_lgb, sd)) - sum(p_glm)) < 1e-6,
          abs(sum(score_model(line_xgb, sd)) - sum(p_glm)) < 1e-6)
p_blend <- score_model(blend, sd)
dir <- tempfile("sam02_io_")
save_model(blend, dir, "motor_blend")
re <- load_model(dir, "motor_blend")
stopifnot(max(abs(score_model(re, sd) - p_blend)) < 1e-9)
cat("sam02 model I/O passed\n")

# Iteration 2's saved XGBoost models must reload as XGBoost (lgb.load used to overwrite them)
if (file.exists("week1/models/iteration_02/fitted/motor_xgb_tweedie.rds")) {
  stopifnot(inherits(load_model("week1/models/iteration_02/fitted", "motor_xgb_tweedie")$booster, "xgb.Booster"))
  cat("iteration 2 XGBoost reload passed\n")
}