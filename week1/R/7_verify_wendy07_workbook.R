# 7_verify_wendy07_workbook.R -----------------------------------------------------------------------------------
# Checks that an exported WENDY 7 workbook (week1/R/7_export_wendy07_workbook.R) sets up exactly the same model as the
# environment-variable run it documents: week1/R/4_models_iterwendy07.R is run up to its validation section twice in
# separate R processes (A = base workbook + the run's environment edits, B = exported workbook, no edits) and the
# resulting feature map, Model_Spec, IBNR method / overrides, bag count and method mix are compared.
#
# Run:  MODEL=final2 Rscript week1/R/7_verify_wendy07_workbook.R      Out: console + week1/output/4_check_reported/workbook_check_<model>.csv

source("week1/R/0_setup.R")
MODEL <- Sys.getenv("MODEL", "final2")
if (Sys.getenv("W7_DUMP") != "") {                        # child process: build the engine state and dump it
  W7 <- "week1/R/4_models_iterwendy07.R"
  src <- readLines(W7, warn = FALSE); stop_line <- grep("^# 7\\. Validation", src)[1]
  ex <- parse(W7, keep.source = TRUE); st <- vapply(attr(ex, "srcref"), function(s) as.integer(s[1]), integer(1))
  for (e in ex[st < stop_line]) eval(e, envir = globalenv())
  mix <- if (METHOD_MIX == "sheet") rd("Method_Mix")[, .(line, peril, method)] else fread(METHOD_MIX)[, .(line, peril, method)]
  saveRDS(list(fmap = fmap[order(line, peril, column), .(line, peril, column, code, mono_freq, mono_sev)],
               spec = spec[order(line, peril)], ibnr = IBNR_METHOD, ibnr_peril = IBNR_PERIL[order(names(IBNR_PERIL))],
               bags = BAGS, mix = mix[order(line, peril)]), Sys.getenv("W7_DUMP"))
  quit(save = "no")
}
env_of <- list(
  sub10 = c(FEATURE_EDITS = "all:voluntary_excess=B", SPEC_EDITS = "motor/bodily_injury:freq_trend=none,sev_trend=none"),
  final2 = c(FEATURE_EDITS = paste("all:voluntary_excess=B", "buildings/flood:days_quote_to_inception=-", "buildings/flood:start_month=-",
                                   "motor/third_party_prop:freezing_days=-", "motor/third_party_prop:rainfall_mm=-", sep = ";"),
             SPEC_EDITS = paste("motor/bodily_injury:freq_trend=none,sev_trend=none", "buildings/escape_of_water:sev_model=gamma_glm",
                                "buildings/fire:freq_min_child_weight=15", "contents/theft:sev_model=gamma_glm",
                                "motor/theft:sev_model=gamma_glm", sep = ";"),
             METHOD_MIX = "week1/output/4_check_reported/peril_lab/method_mix.csv"))[[MODEL]]
common <- c(IBNR_METHOD = "chain_ladder", IBNR_OVERRIDE = "buildings/subsidence=report_share_days", BAGS = "5")
clear <- c("FEATURE_EDITS", "SPEC_EDITS", "IBNR_METHOD", "IBNR_OVERRIDE", "BAGS", "METHOD_MIX", "HIST_V2", "ASSUMPTIONS_XLSX")
run_child <- function(vars, out) {
  e <- c(vars, W7_DUMP = out)
  args <- c(paste("-u", setdiff(clear, names(e))), paste0(names(e), "=", shQuote(e)), "Rscript", "week1/R/7_verify_wendy07_workbook.R")
  log_f <- sub("\\.rds$", ".log", out)
  system2("env", args, stdout = log_f, stderr = log_f)
  if (!file.exists(out)) stop("Engine set-up failed:\n", paste(tail(readLines(log_f), 15), collapse = "\n"))
  readRDS(out)
}
tmp <- tempfile(fileext = c(".rds", ".rds"))
a <- run_child(c(common, env_of), tmp[1])
b <- run_child(c(ASSUMPTIONS_XLSX = sprintf("week1/docs/assumptions_wendy07_%s.xlsx", MODEL)), tmp[2])
chk <- rbindlist(lapply(names(a), function(k) data.table(item = k, identical = isTRUE(all.equal(a[[k]], b[[k]], check.attributes = FALSE)),
  detail = if (is.data.frame(a[[k]])) sprintf("%d vs %d rows", nrow(a[[k]]), nrow(b[[k]])) else paste(format(a[[k]]), "|", format(b[[k]]), collapse = "; "))))
print(chk)
fwrite(chk, file.path(PATHS$output, "4_check_reported", sprintf("workbook_check_%s.csv", MODEL)))
if (!all(chk$identical)) {
  if (!isTRUE(all.equal(a$fmap, b$fmap))) print(fsetdiff(rbind(a$fmap, b$fmap), fintersect(a$fmap, b$fmap)))
  stop("Workbook does not reproduce the run's setup")
}
log_msg("Workbook ", MODEL, " reproduces the run setup exactly")
