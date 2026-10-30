# run_all.R ------------------------------------------------------------------------------------------------------
# Rebuilds the final selected submission from the raw Kaggle data:
#   submission_20261023_1636_w9_motor2_pre_m0.5.csv (public 0.12965, private 0.13923)
#   = WENDY 9 (C5 x ladder x SAM 3 x WENDY 8 credibility) with a MOTOR 2 member (m 0.5) on motor.
#
# Run from this folder (the parent project's data/week_1/raw data holds the raw data; RAW_DATA_DIR overrides):
#   cd final_week1_R_Script
#   Rscript run_all.R                         # every stage not yet done
#   STAGES=sam3,sam4 Rscript run_all.R        # only these stages; FORCE=1 re-runs stages already done
# Each stage runs in its own R session; log in run/logs/<stage>.log, marker run/done/<stage>, progress in run/status.log.
#
# Stage      Script                          Output (all inside this folder)                                  Time
# clean      R/2_clean.R                     data/clean/                                                     5 min
# ibnr       R/3b_ibnr_study.R               output/3b_ibnr/ (report pattern for MOTOR 2)                    20 min
# sam3       R/4_models_itersam03.R          data/sam03/, models/sam_iteration_03/, SAM 3 2025 file          4 h
# sam4       R/4_models_itersam04.R          models/sam_iteration_04/ (motor 2025 level used by MOTOR 2)     4 h
# c5         R/4_models_iterwendy07.R        models/wendy_iteration_07/c5/test_preds_peril.parquet           2 h
# motor2     R/4_models_itermotor02.R        MOTOR 2 2025 file                                               45 min
# history    R/5_history.R                   WENDY 8 N, E per row (models/wendy_iteration_08/)               10 min
# ladder     R/6_ladder.R                    WENDY 9 ladder 2025 freq x sev, 8 perils (models/wendy_iteration_09/) 15 min
# blend      R/9_final_blend.R               output/submission/submission_final_week1.csv + comparison        seconds

STAGES_ALL <- c("clean", "ibnr", "sam3", "sam4", "c5", "motor2", "history", "ladder", "blend")
stages <- strsplit(Sys.getenv("STAGES", paste(STAGES_ALL, collapse = ",")), ",")[[1]]
stopifnot(all(stages %in% STAGES_ALL), file.exists("R/0_setup.R"))
FORCE <- Sys.getenv("FORCE") == "1"
RSCRIPT <- file.path(R.home("bin"), "Rscript")
dir.create("run/logs", recursive = TRUE, showWarnings = FALSE)
dir.create("run/done", recursive = TRUE, showWarnings = FALSE)
dir.create("data", showWarnings = FALSE)   # R/0_setup.R checks the working directory has R/ and data/

note <- function(...) {
  line <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " | ", ...)
  cat(line, "\n", file = "run/status.log", append = TRUE); message(line)
}
need <- function(path, stage) if (!length(Sys.glob(path))) { note("FAILED ", stage, " - missing ", path); stop(stage, " output missing") }
run <- function(stage, script, envs = character()) {
  old <- Sys.getenv(names(envs), unset = NA, names = TRUE)
  if (length(envs)) do.call(Sys.setenv, as.list(envs))
  on.exit(for (k in names(old)) if (is.na(old[[k]])) Sys.unsetenv(k) else do.call(Sys.setenv, setNames(list(old[[k]]), k)))
  log <- file.path("run/logs", paste0(stage, ".log"))
  # via cmd redirection so the log can be read while the stage runs
  code <- system(sprintf('cmd /c ""%s" "%s" > "%s" 2>&1"', RSCRIPT, script, log))
  if (code != 0) { note("FAILED ", stage, " (", script, ", exit ", code, ") - see run/logs/", stage, ".log"); stop(stage, " failed") }
}
latest_csv <- function(summary_csv, prefix = "") {
  s <- read.csv(summary_csv); f <- s$file[nrow(s)]
  file.path("output", "submission", if (nzchar(prefix)) paste0(prefix, s$run_id[nrow(s)], ".csv") else f)
}

for (st in stages) {
  done <- file.path("run/done", st)
  if (file.exists(done) && !FORCE) { note("skip ", st, " (done)"); next }
  t0 <- Sys.time(); note("start ", st)
  switch(st,
    clean = { run(st, "R/2_clean.R"); need("data/clean/train_motor.parquet", st) },
    ibnr = { run(st, "R/3b_ibnr_study.R"); need("output/3b_ibnr/recommended_daily_share.csv", st) },
    sam3 = { run(st, "R/4_models_itersam03.R"); need("models/sam_iteration_03/fitted/motor_blend.rds", st)
             need(latest_csv("models/sam_iteration_03/summary.csv"), st) },
    sam4 = {
      dir.create("data/sam04", recursive = TRUE, showWarnings = FALSE)
      run(st, "R/4_models_itersam04.R", c(SAM04_REUSE_DATA = "1"))
      need("models/sam_iteration_04/test_prediction_summary.csv", st) },
    c5 = { run(st, "R/4_models_iterwendy07.R", c(ASSUMPTIONS_XLSX = "inputs/assumptions_wendy07_final2.xlsx", RUN_TAG = "c5",
                                                 FINAL_FIT = "1"))
           need("models/wendy_iteration_07/c5/test_preds_peril.parquet", st) },
    motor2 = { run(st, "R/4_models_itermotor02.R"); need(latest_csv("models/motor_iteration_02/summary.csv", "motor2_only_"), st) },
    history = { run(st, "R/5_history.R"); need("models/wendy_iteration_08/history_*.parquet", st) },
    ladder = { run(st, "R/6_ladder.R"); need("models/wendy_iteration_09/ladder_2025.parquet", st) },
    blend = { run(st, "R/9_final_blend.R"); need("output/submission/submission_final_week1.csv", st) })
  file.create(done)
  note(sprintf("done  %s in %.1f min", st, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
note("requested stages finished: ", paste(stages, collapse = ","))
