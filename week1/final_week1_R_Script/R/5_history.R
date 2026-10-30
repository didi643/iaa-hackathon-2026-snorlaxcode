# 5_history.R ------------------------------------------------------------------------------------------------------
# WENDY 8 claim history (R port of Wendy's Python prep.py, fe.py, prior.py, cred.py / cred3.py; code in R/w89_core.R):
#   prior   LightGBM Poisson claim count per row without history features (seed 11), 4 policy folds out of fold;
#           rounds by early stopping on fold 0 (submitted run: motor 389, buildings 279, contents 227)
#   N       the policy's own earlier claims (net > 0): loss before the row starts, reported before min(row start, 1 Jan 2025)
#   E       expected number of those claims: prior rate grossed up to ultimate (/ reported share at 1 Jan 2025, floor 0.05)
#           x share reported by the same cut-off, from the line's report-lag ECDF (mean over 16 points of each earlier row)
# Out: models/wendy_iteration_08/history_<line>.parquet (row_id, N, E for training and 2025 rows), data/w89/ (cache)

source("R/0_setup.R")
source("R/w89_core.R")
for (ln in LINES) {
  t0 <- Sys.time()
  h <- w_history(ln)
  log_msg(ln, ": history for ", nrow(h), " rows, mean N ", round(mean(h$N), 4), ", mean E ", round(mean(h$E), 4), " (",
          round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min)")
}
