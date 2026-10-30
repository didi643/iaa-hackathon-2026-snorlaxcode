source("week1/R/0_setup.R")
source("week1/R/model_io.R")
suppressPackageStartupMessages(library(xgboost))

set.seed(1)
n <- 500
dt <- data.table(exposure = runif(n, 0.2, 1), age = runif(n, 18, 80), region = sample(c("a", "b", "c"), n, TRUE))
make_xgb <- function(peril, loading) {
  X <- lgb_matrix(dt, c("age", "region"), list(region = c("a", "b", "c")))
  y <- rgamma(n, 1, 0.01) * rbinom(n, 1, 0.1)
  m <- xgb.train(params = xgb.params(objective = "reg:tweedie", max_depth = 2, nthread = 1),
                 data = xgb.DMatrix(X, label = y / dt$exposure, weight = dt$exposure), nrounds = 5)
  list(model = "xgb_tweedie", line = "motor", peril = peril, loading = loading, features = c("age", "region"),
       cat_levels = list(region = c("a", "b", "c")), booster = m)
}
comps <- list(theft = make_xgb("theft", 1.1), glass_hail = list(model = "burn_cost", line = "motor", rate = 3, loading = 1))
art <- list(model = "peril_sum", line = "motor", perils = names(comps), components = comps)

pred <- score_model(art, dt)
expected <- score_model(comps$theft, dt) + score_model(comps$glass_hail, dt)
stopifnot(all(is.finite(pred)), all(pred >= 0), max(abs(pred - expected)) < 1e-12)

dir <- tempfile("peril_io_")
save_model(art, dir, "motor_xgb_peril_sum")
stopifnot(file.exists(file.path(dir, c("motor_theft_xgb_tweedie.rds", "motor_theft_xgb_tweedie.ubj",
                                       "motor_glass_hail_burn_cost.rds"))))
reloaded <- load_model(dir, "motor_xgb_peril_sum")
stopifnot(identical(names(reloaded$components), names(comps)),
          inherits(reloaded$components$theft$booster, "xgb.Booster"),
          max(abs(score_model(reloaded, dt) - pred)) < 1e-6)

cat("peril_sum model I/O passed\n")
