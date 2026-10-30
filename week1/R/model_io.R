# model_io.R -----------------------------------------------------------------
# Save, load and score fitted models without refitting. Shared by all week1/R/4_models_iterXX.R scripts (changes must
# keep earlier iterations' saved models scoring identically); can also be used
# on its own after source("week1/R/0_setup.R"):
#   art  <- load_model("week1/models/iteration_01/fitted", "motor_glm_freq_sev")
#   pred <- score_model(art, read_clean("test_motor"))
# Per-peril models (WENDY 3): load_model(dir, "motor_xgb_peril_sum") also loads every <line>_<peril>_xgb_tweedie.

# GLM factor encoding: numeric bins or categories, NA -> "missing", unseen/rare levels -> base level
encode_raw <- function(x, sp) {
  v <- if (sp$type == "bin") as.character(cut(x, sp$breaks)) else as.character(x)
  v[is.na(v)] <- "missing"
  v
}
encode_level <- function(x, sp) {
  v <- encode_raw(x, sp)
  v[!v %in% sp$levels] <- sp$base
  v
}

# Linear predictor from coefficients; base and aliased (NA) levels contribute 0, as in predict.glm
glm_link <- function(coefs, specs, dt) {
  eta <- rep(coefs[["(Intercept)"]], nrow(dt))
  for (f in names(specs)) {
    b <- coefs[paste0(f, encode_level(dt[[f]], specs[[f]]))]
    b[is.na(b)] <- 0
    eta <- eta + b
  }
  unname(eta)
}

lgb_matrix <- function(dt, feats, cat_levels, caps = NULL) {
  vapply(feats, function(f) {
    if (f %in% names(cat_levels)) return(as.numeric(match(dt[[f]], cat_levels[[f]]) - 1L))
    x <- as.numeric(dt[[f]])
    if (f %in% names(caps)) pmin(x, caps[[f]]) else x
  }, numeric(nrow(dt)))
}

# sam_iteration_02 parts ----------------------------------------------------------------------------
# GLM rate per exposure-year; the trend runs from year_ref to the row's policy_year (immaturity dummies score as 0)
sam02_glm_rate <- function(g, dt) {
  eta <- glm_link(g$coef, g$specs, dt)
  if (!is.null(g$year_coef) && g$year_coef != 0) eta <- eta + g$year_coef * (dt$policy_year - g$year_ref)
  exp(eta)
}

# Mean prediction of a bag of LightGBM or XGBoost boosters (rate per exposure-year)
sam02_tree_rate <- function(tm, dt) {
  X <- lgb_matrix(dt, tm$features, tm$cat_levels)
  Reduce(`+`, lapply(tm$boosters, function(b) predict(b, X))) / length(tm$boosters)
}

# Mean reported share over each row's days; days outside the table (e.g. 2025 test rows) count as fully reported
row_report_share <- function(rs, peril, start, end) {
  cs <- rs$cumshare[[peril]]
  n <- length(cs)
  i0 <- as.integer(start - rs$origin) + 1L
  i1 <- as.integer(end - rs$origin) + 1L
  a <- pmin(pmax(i0, 1L), n + 1L)
  b <- pmin(pmax(i1, 0L), n)
  inside <- pmax(b - a + 1L, 0L)
  s_in <- ifelse(inside > 0, cs[pmax(b, 1L)] - c(0, cs)[a], 0)
  days <- i1 - i0 + 1L
  (s_in + days - inside) / days
}

# Tree models give the shape, the trended GLM gives the level: tree rates are rescaled to the GLM total of the scored rows
sam02_peril_cost <- function(art, dt) {
  total <- 0
  for (p in art$perils) {
    f <- sam02_glm_rate(p$freq_glm, dt)
    if (!is.null(p$freq_tree)) {
      t <- sam02_tree_rate(p$freq_tree, dt)
      f <- t * sum(f * dt$exposure) / sum(t * dt$exposure)
      scale_exposure <- dt$exposure
      if (!is.null(art$row_share)) {
        scale_exposure <- dt$exposure * row_report_share(art$row_share, p$peril, dt$period_start, dt$period_end)
      } else if (isTRUE(art$effective_exposure) && !is.null(art$ibnr)) {
        keys <- paste(p$peril, dt$policy_year)
        ibnr_keys <- paste(art$ibnr$peril, art$ibnr$policy_year)
        factor <- art$ibnr$ibnr_factor[match(keys, ibnr_keys)]
        factor[is.na(factor)] <- 1
        scale_exposure <- dt$exposure / factor
      }
      f <- t * sum(f * scale_exposure) / sum(t * scale_exposure)
    }
    total <- total + f * sam02_glm_rate(p$sev_glm, dt) * p$loading
  }
  total * dt$exposure
}

sam02_pack <- function(x) {
  if (is.list(x) && !is.null(x$kind) && !is.null(x$boosters)) {
    x$blobs <- lapply(x$boosters, function(b) {
      if (x$kind == "xgb") xgboost::xgb.save.raw(b, raw_format = "ubj")
      else b$save_model_to_string(num_iteration = if (b$best_iter > 0) b$best_iter else NULL)
    })
    x$boosters <- NULL
    return(x)
  }
  if (is.list(x) && length(x) > 0) x[] <- lapply(x, sam02_pack)
  x
}

sam02_unpack <- function(x) {
  if (is.list(x) && !is.null(x$kind) && !is.null(x$blobs)) {
    x$boosters <- lapply(x$blobs, function(b) if (x$kind == "xgb") xgboost::xgb.load.raw(b) else lgb.load(model_str = b))
    x$blobs <- NULL
    return(x)
  }
  if (is.list(x) && length(x) > 0) x[] <- lapply(x, sam02_unpack)
  x
}

# Expected row cost (CU) for newdata; every model includes the large-loss cap loading
score_model <- function(art, dt) {
  switch(art$model,
    burn_cost = art$rate * dt$exposure * art$loading,
    premium_scaled = art$k * dt$written_premium * dt$exposure,
    glm_freq_sev = exp(glm_link(art$coef_freq, art$specs, dt)) * exp(glm_link(art$coef_sev, art$specs, dt)) *
      dt$exposure * art$loading,
    lgb_tweedie = predict(art$booster, lgb_matrix(dt, art$features, art$cat_levels)) * dt$exposure * art$loading,
    # xgboost predicts with the early-stopping best iteration, also after xgb.load()
    xgb_tweedie = predict(art$booster, lgb_matrix(dt, art$features, art$cat_levels, art$caps)) * dt$exposure * art$loading,
    glm_lgb_ensemble = {
      glm_rate <- score_model(art$glm_artifact, dt) / dt$exposure
      lgb_rate <- score_model(art$lgb_artifact, dt) / dt$exposure
      (art$glm_weight * glm_rate + art$lgb_weight * lgb_rate) * dt$exposure
    },
    # line cost = sum of one model per peril (each with its own cap loading)
    peril_sum = Reduce(`+`, lapply(art$components, score_model, dt = dt)),
    sam02_peril = sam02_peril_cost(art, dt),
    sam02_line_tree = {
      level <- score_model(art$level_artifact, dt)
      t <- sam02_tree_rate(art$tree, dt) * dt$exposure
      t * sum(level) / sum(t)
    },
    sam02_blend = Reduce(`+`, Map(function(a, w) w * score_model(a, dt), art$components, art$weights)),
    stop("Unknown model type: ", art$model))
}

save_model <- function(art, dir, name) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  if (startsWith(art$model, "sam02_")) return(invisible(saveRDS(sam02_pack(art), file.path(dir, paste0(name, ".rds")))))
  if (identical(art$model, "glm_lgb_ensemble")) {
    save_model(art$glm_artifact, dir, paste0(name, "_glm"))
    save_model(art$lgb_artifact, dir, paste0(name, "_lgb"))
    art$glm_artifact <- NULL
    art$lgb_artifact <- NULL
    art$glm_model_name <- paste0(name, "_glm")
    art$lgb_model_name <- paste0(name, "_lgb")
  }
  if (identical(art$model, "peril_sum")) {
    # each peril model is saved on its own as <line>_<peril>_<model>
    art$component_names <- setNames(vapply(names(art$components), function(pr) {
      paste(art$line, pr, art$components[[pr]]$model, sep = "_")
    }, character(1)), names(art$components))
    for (pr in names(art$components)) save_model(art$components[[pr]], dir, art$component_names[[pr]])
    art$components <- NULL
  }
  if (!is.null(art$booster)) {
    is_xgb <- art$model == "xgb_tweedie"
    art$model_file <- paste0(name, if (is_xgb) ".ubj" else ".txt")
    if (is_xgb) xgboost::xgb.save(art$booster, file.path(dir, art$model_file))
    else lgb.save(art$booster, file.path(dir, art$model_file))
    art$booster <- NULL
  }
  saveRDS(art, file.path(dir, paste0(name, ".rds")))
}

load_model <- function(dir, name) {
  art <- readRDS(file.path(dir, paste0(name, ".rds")))
  if (startsWith(art$model, "sam02_")) return(sam02_unpack(art))
  if (!is.null(art$model_file)) {
    f <- file.path(dir, art$model_file)
    art$booster <- if (art$model == "xgb_tweedie") xgboost::xgb.load(f) else lgb.load(f)
  }
  if (identical(art$model, "glm_lgb_ensemble")) {
    art$glm_artifact <- load_model(dir, art$glm_model_name)
    art$lgb_artifact <- load_model(dir, art$lgb_model_name)
  }
  if (identical(art$model, "peril_sum")) {
    art$components <- lapply(art$component_names, function(n) load_model(dir, n))
  }
  art
}
