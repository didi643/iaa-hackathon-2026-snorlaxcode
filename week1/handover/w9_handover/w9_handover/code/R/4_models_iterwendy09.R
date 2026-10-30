# 4_models_iterwendy09.R --------------------------------------------------------------------------------------------
# WENDY 9: ground-up per-peril ladder (LightGBM frequency x severity) blended per peril with WENDY 7 C5, per line
# with SAM 3, then the WENDY 8 credibility adjustment. R translation of python/wendy09/ (ladder register:
# docs/wendy09_ladder_register.xlsx; full build: docs/model_build_final2_w8_w9.xlsx). Submitted 23 Oct 2026 as #12:
# public 0.12964 (best).
#
#   Ladder findings built into the recipes (ALL-line D2, mean 2023-24 reported_raw):
#     burn cost 0.043 -> GBM frequency 0.087 -> + GBM severity with trend 0.093 -> leaves sized by expected claims
#     (min_sum_hessian) 0.095 -> drop previous_insurer / occupation 0.097 -> rate-ordered categoricals (motor) 0.099
#     -> tree depth per peril 0.100. The ladder alone stays below final2 (0.103); blended with C5 and SAM 3 it adds.
#   Frequency  LightGBM Poisson per peril; label = claims (net > 0) / (exposure x reported share), weight = exposure x
#              share (ultimate frequency; share from the peril's 2021-22 report lags, 16-point average over the row);
#              no frequency trend; balance factor to the training claim count; early stopping on a 10% policy holdout.
#   Severity   LightGBM Gamma per peril on claims capped at p99.5 (loading = total / capped), trended to the scored
#              year (log-linear yearly mean, clamp [0%, 10%], or fixed 5%), balance factor to the training mean.
#   Blend      per peril w x ladder + (1 - w) x C5 (grid 0 / .25 / .5 / .75 / 1, chosen on mean 2023-24 line D2),
#              per line LW x peril blend + (1 - LW) x SAM 3 (grid 0.1), then x (a + N) / (a + E) rescaled per line.
#              W_FIXED=1 uses the submitted weights instead of re-selecting.
#
# Run:      Rscript R/4_models_iterwendy09.R                (folds + final fit + submission; ~1-2 h on a laptop)
#           STEPS=folds | final | all (default all); W_FIXED=1 to reuse the submitted weights
# Needs:    R/0_setup.R, R/oof_io.R, R/wendy_ladder_core.R, data/week_1/*, models/wendy_iteration_08/history_<line>.parquet
#           (run R/4_models_iterwendy08.R first), output/4_check_reported/{wendy07_c5,sam03}/row_preds*.parquet,
#           models/wendy_iteration_07/c5/test_preds_peril.parquet, SAM 3 submission (SAM03_SUB=<csv> or its xlsx)
# Outputs:  models/wendy_iteration_09/ (preds/, weights, line_scores.csv, test_by_peril.csv, model_card.md),
#           output/4_check_reported/wendy09/, output/submission/submission_<run>_wendy09.csv

source("R/0_setup.R")
source("R/oof_io.R")
source("R/wendy_ladder_core.R")

ITERATION <- "WENDY 9"
RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M")
OUT <- wl_dir("wendy_iteration_09"); PRED_DIR <- file.path(OUT, "preds"); dir.create(PRED_DIR, showWarnings = FALSE)
STEPS <- Sys.getenv("STEPS", "all")
W_FIXED <- Sys.getenv("W_FIXED", "0") == "1"
C5_TAG <- Sys.getenv("C5_TAG", "wendy07_c5"); SAM_TAG <- Sys.getenv("SAM_TAG", "sam03")
C5_TEST <- Sys.getenv("C5_TEST", "models/wendy_iteration_07/c5/test_preds_peril.parquet")
FOLDS <- list(`2023` = 2021:2022, `2024` = 2021:2023)
FINAL_FY <- 2021:2024
A_CRED <- c(motor = 8, buildings = 5, contents = 5)   # WENDY 8

# Frequency recipes (ladder codes). base = all clean features minus previous_insurer / occupation.
P2A <- list(num_leaves = 8, max_depth = 3, min_data_in_leaf = 100, min_sum_hessian_in_leaf = 60)
FREQ_RECIPES <- list(
  F8  = list(params = P2A, enc = "rate", feats = "base"),
  F11 = list(params = P2A, enc = "rate", feats = "base_no_prop_wx"),
  G4  = list(params = modifyList(P2A, list(num_leaves = 4, max_depth = 2)), enc = "line", feats = "base"),
  G5  = list(params = modifyList(P2A, list(num_leaves = 2, max_depth = 1, learning_rate = 0.1)), enc = "line", feats = "base"),
  G6  = list(params = modifyList(P2A, list(num_leaves = 4, max_depth = 2, min_sum_hessian_in_leaf = 150)), enc = "line", feats = "base"),
  G8  = list(params = modifyList(P2A, list(min_sum_hessian_in_leaf = 6)), enc = "line", feats = "base"))
# Severity recipes: SA = no HC, trend clamp [0, 10%]; S4 = all clean features, clamp [0, 10%]; S6 = all, fixed 5%
SEV_RECIPES <- list(SA = list(feats = "base", lo = 0, fixed = NULL), S4 = list(feats = "all", lo = 0, fixed = NULL),
                    S6 = list(feats = "all", lo = 0, fixed = 0.05))
# Submitted recipe per peril (best of 33 combinations per peril on the folds) and blend weights
COMBO <- list(
  motor = list(own_damage = c("G8", "S6"), third_party_prop = c("G4", "S6"), bodily_injury = c("F11", "SA"),
               theft = c("G8", "S6"), glass_hail = c("G8", "SA")),
  buildings = list(storm = c("G5", "SA"), flood = c("F8", "S6"), escape_of_water = c("G5", "SA"),
                   subsidence = c("G4", "S4"), fire = c("G5", "S4"), accidental_damage = c("G5", "S6")),
  contents = list(theft = c("G5", "SA"), escape_of_water = c("G6", "SA"), accidental_damage = c("G6", "SA"),
                  flood = c("G5", "S4")))
W_SUBMITTED <- list(motor = c(own_damage = 0, third_party_prop = 1, bodily_injury = 0, theft = 0, glass_hail = 1),
                    buildings = c(storm = 1, flood = 0, escape_of_water = 0, subsidence = 0.5, fire = 0.25, accidental_damage = 0.25),
                    contents = c(theft = 0, escape_of_water = 0.75, accidental_damage = 0, flood = 0.75))
LW_SUBMITTED <- c(motor = 0.9, buildings = 0.7, contents = 0.9)
C5_MIX <- list(motor = c(own_damage = "freq_sev", third_party_prop = "freq_sev", bodily_injury = "tweedie", theft = "freq_sev", glass_hail = "freq_sev"),
               buildings = setNames(rep("freq_sev", 6), PERILS$buildings),
               contents = c(theft = "freq_sev", escape_of_water = "tweedie", accidental_damage = "freq_sev", flood = "freq_sev"))

recipe_feats <- function(d, line, peril, what) {
  f <- wl_features(d)
  switch(what, all = f, base = setdiff(f, WL_HC),
         base_no_prop_wx = { g <- setdiff(f, c(WL_HC, WL_PROP))
           keep_wx <- if (peril == "glass_hail") c("hail_days", "wind_exposure_index", "freezing_days", "lr_hail_days") else character(0)
           setdiff(g, setdiff(WL_WX, keep_wx)) })
}
pred_file <- function(line, peril, comp, step, vy) file.path(PRED_DIR, sprintf("%s_%s_%s_%s_%s.parquet", line, peril, comp, step, vy))
fit_component <- function(d, line, peril, fstep, sstep, vy, fy) {
  ff <- pred_file(line, peril, "freq", fstep, vy); fs <- pred_file(line, peril, "sev", sstep, vy)
  sc <- wl_masks(d, vy, fy)$sc; ids <- d$row_id[sc]; info <- list()
  if (!file.exists(ff)) {
    r <- FREQ_RECIPES[[fstep]]
    enc <- if (r$enc == "line") (if (line == "motor") "rate" else "native") else r$enc
    o <- wl_fit_freq(d, peril, recipe_feats(d, line, peril, r$feats), vy, fy, modifyList(FREQ_BASE, r$params), enc)
    write_parquet(data.table(row_id = ids, pred = o$pred), ff); info$freq_rounds <- o$rounds
  }
  if (!file.exists(fs)) {
    r <- SEV_RECIPES[[sstep]]
    o <- wl_fit_sev(d, peril, recipe_feats(d, line, peril, r$feats), vy, fy, lo = r$lo, fixed_trend = r$fixed)
    write_parquet(data.table(row_id = ids, pred = o$pred), fs)
    info[c("sev_rounds", "sev_trend", "sev_cap", "sev_load")] <- list(o$rounds, o$trend, o$cap, o$load)
  }
  f <- as.data.table(read_parquet(ff)); s <- as.data.table(read_parquet(fs))
  stopifnot(identical(f$row_id, ids), identical(s$row_id, ids))
  list(pred = f$pred * s$pred, info = info)
}

# 1. Ladder predictions on the folds -------------------------------------------------------------------------------
DATA <- list()
get_data <- function(ln) {
  if (is.null(DATA[[ln]])) { d <- wl_rows(ln); DATA[[ln]] <<- d }
  DATA[[ln]]
}
lad <- list()
if (STEPS %in% c("folds", "all")) for (ln in LINES) {
  d <- get_data(ln)
  for (vy in names(FOLDS)) {
    sc <- wl_masks(d, as.integer(vy), FOLDS[[vy]])$sc
    x <- data.table(valid_year = as.integer(vy), line = ln, row_id = d$row_id[sc])
    for (p in PERILS[[ln]]) {
      cb <- COMBO[[ln]][[p]]
      x[, (paste0("lad_", p)) := fit_component(d, ln, p, cb[1], cb[2], as.integer(vy), FOLDS[[vy]])$pred]
      log_msg(ln, " ", p, " ", vy, " done")
    }
    lad[[paste(ln, vy)]] <- x
  }
}
LAD <- rbindlist(lad, fill = TRUE)

# 2. Blend with C5 per peril, SAM 3 per line, credibility ----------------------------------------------------------
c5 <- read_row_preds(C5_TAG, "peril"); sam <- read_row_preds(SAM_TAG)
H <- rbindlist(lapply(LINES, function(ln) as.data.table(read_parquet(file.path("models", "wendy_iteration_08", paste0("history_", ln, ".parquet"))))))
B <- merge(sam[, c(OOF_KEYS, OOF_BASES, "pred"), with = FALSE][, .(valid_year, line, row_id, policy_id, exposure,
           reported_raw, reported_adj, developed, sam = pred)], LAD, by = c("valid_year", "line", "row_id"))
B <- merge(B, H[, .(row_id, N, E)], by = "row_id", all.x = TRUE)
for (ln in LINES) for (p in PERILS[[ln]]) {
  col <- paste0("pred_", p, "_", C5_MIX[[ln]][[p]])
  m <- c5[line == ln, c("valid_year", "row_id", col), with = FALSE]
  B[m, on = .(valid_year, row_id), (paste0("c5_", p)) := get(paste0("i.", col))]
}
stopifnot(nrow(B) == nrow(sam))
pb <- function(x, ln, w) Reduce(`+`, lapply(PERILS[[ln]], function(p) w[[p]] * x[[paste0("lad_", p)]] + (1 - w[[p]]) * x[[paste0("c5_", p)]]))
line_d2 <- function(x, pred) mean(vapply(split(seq_len(nrow(x)), x$valid_year), function(i) oof_d2(x$reported_raw[i], pred[i], x$exposure[i]), numeric(1)))
W <- W_SUBMITTED; LW <- LW_SUBMITTED
if (!W_FIXED) for (ln in LINES) {
  x <- B[line == ln]
  for (p in PERILS[[ln]]) {
    sc <- vapply(c(0, .25, .5, .75, 1), function(w) { ww <- setNames(rep(0, length(PERILS[[ln]])), PERILS[[ln]]); ww[p] <- w; line_d2(x, pb(x, ln, ww)) }, numeric(1))
    W[[ln]][p] <- c(0, .25, .5, .75, 1)[which.max(sc)]
  }
  g <- seq(0, 1, 0.1); LW[ln] <- g[which.max(vapply(g, function(a) line_d2(x, a * pb(x, ln, W[[ln]]) + (1 - a) * x$sam), numeric(1)))]
}
wt <- rbindlist(lapply(LINES, function(ln) data.table(line = ln, peril = PERILS[[ln]], w_ladder = W[[ln]][PERILS[[ln]]], lw_peril_blend = LW[[ln]])))
fwrite(wt, file.path(OUT, "blend_weights.csv")); print(wt)
B[, pred := {
  ln <- line[1]; b <- LW[[ln]] * pb(.SD, ln, W[[ln]]) + (1 - LW[[ln]]) * sam
  q <- b * wl_cred(N, E, A_CRED[[ln]]); wl_rescale(q, b) }, by = .(valid_year, line)]
dir <- write_row_preds(B[, c(OOF_KEYS, "pred", OOF_BASES), with = FALSE], NULL, "wendy09")
ls <- score_row_preds(B)[, iteration := "wendy09"]; fwrite(ls, file.path(dir, "line_scores.csv")); fwrite(ls, file.path(OUT, "line_scores.csv"))
log_msg("local mean reported_raw D2 ALL: ", round(ls[basis == "reported_raw" & line == "ALL", mean(d2)], 5))

# 3. Final fit 2021-24 -> 2025 and submission ----------------------------------------------------------------------
if (STEPS %in% c("final", "all")) {
  tc5 <- as.data.table(read_parquet(C5_TEST))
  sam_sub <- Sys.getenv("SAM03_SUB", "")
  ts <- if (nzchar(sam_sub)) fread(sam_sub, colClasses = list(character = "row_id")) else
    as.data.table(openxlsx::read.xlsx("models/sam_iteration_03/sam_iteration_03_model_summary.xlsx", "Submission"))
  ts <- ts[, .(row_id, sam = prediction)]
  res <- list(); burn <- list()
  for (ln in LINES) {
    d <- get_data(ln); sc <- d$is_test == 1L
    x <- data.table(row_id = d$row_id[sc], exposure = d$exposure[sc])
    x <- merge(x, tc5[, c("row_id", paste0("pred_", PERILS[[ln]])), with = FALSE], by = "row_id", sort = FALSE)
    x <- merge(x, ts, by = "row_id", sort = FALSE); x <- merge(x, H[, .(row_id, N, E)], by = "row_id", sort = FALSE)
    stopifnot(nrow(x) == sum(sc))
    x <- x[match(d$row_id[sc], row_id)]
    tot <- 0
    for (p in PERILS[[ln]]) {
      w <- W[[ln]][[p]]; c5p <- x[[paste0("pred_", p)]]
      lp <- if (w > 0) { cb <- COMBO[[ln]][[p]]; fit_component(d, ln, p, cb[1], cb[2], 2025L, FINAL_FY)$pred } else 0
      bp <- w * lp + (1 - w) * c5p; tot <- tot + bp
      burn[[paste(ln, p)]] <- data.table(line = ln, peril = p, w_ladder = w, burn_ladder = sum(lp) / sum(x$exposure),
                                         burn_c5 = sum(c5p) / sum(x$exposure), burn_peril_blend = sum(bp) / sum(x$exposure))
    }
    b <- LW[[ln]] * tot + (1 - LW[[ln]]) * x$sam
    q <- wl_rescale(b * wl_cred(x$N, x$E, A_CRED[[ln]]), b)
    log_msg(ln, ": burn peril blend ", round(sum(tot) / sum(x$exposure), 1), ", SAM 3 ", round(sum(x$sam) / sum(x$exposure), 1),
            ", final ", round(sum(q) / sum(x$exposure), 1))
    res[[ln]] <- data.table(row_id = x$row_id, prediction = q)
  }
  fwrite(rbindlist(burn), file.path(OUT, "test_by_peril.csv"))
  sample_sub <- read_raw("sample_submission")
  sub <- rbindlist(res)[match(sample_sub$row_id, row_id)]
  stopifnot(nrow(sub) == nrow(sample_sub), !anyNA(sub$prediction), all(sub$prediction >= 0), !anyDuplicated(sub$row_id))
  f <- out_file("submission", paste0("submission_", RUN_ID, "_wendy09.csv"))
  fwrite(sub, f, scipen = 50)
  log_msg("WENDY 9 file: ", f, " MD5 ", unname(tools::md5sum(f)))
  writeLines(c(paste0("# ", ITERATION, " (run ", RUN_ID, ")"), "", "## Blend weights", md_table(wt, 2),
               "## Line scores", md_table(ls[basis %in% c("reported_raw", "developed")], 5),
               "## 2025 burn by peril", md_table(rbindlist(burn), 1), paste0("Submission: `", f, "`")),
             file.path(OUT, "model_card.md"))
}
