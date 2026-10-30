# score_w2.R -----------------------------------------------------------------------------------------------------
# Week 2 standard model scorecard (instructions: week2/instructions/output_model_instruction.md).
# Every week 2 model is scored on the validation fold (fit emerging 2023 (+ developed 2021-23), score emerging 2024)
# with local D2 for FREQUENCY, SEVERITY and COST, each at PERIL, LINE and ALL level:
#   frequency  Poisson deviance D2      actual = ultimate claims (reported / reported share), predicted = expected claims
#   severity   Gamma deviance D2        actual = each 2024 claim's net cost (uncapped), predicted = row's expected
#                                       severity for that peril (incl. large-claim loading); null = mean claim cost
#   cost       Tweedie p = 1.5 D2       actual = cost developed to ultimate (reported / share), predicted = expected cost
#                                       (d2_rep = reported basis: prediction x reported share vs reported cost)
# Line / ALL levels sum perils per row (frequency, cost) or pool the claims (severity). The null model in every cell
# is the cell's own average (rate per exposure, or mean claim cost), as in the competition metric.
#
# Use:
#   source("week2/R/score_w2.R")
#   pred <- data.table(row_id, line, peril, exposure, freq, sev)  # one row per emerging 2024 row x peril
#                                                                 # optional `cost` (blends: average of costs)
#   sc <- score_model_w2(pred, model = "MY_MODEL", desc = "one-line method summary", script = "week2/R/<script>.R")
#   record_scores_w2(sc)            # -> week2/output/scores/model_scores.csv (replaces rows of the same model)
#   cat(scorecard_md_w2(sc), sep = "\n")   # markdown tables to paste into week2/docs/week2_workflow.md

if (!exists("PATHS_W2")) source("week2/R/0_setup_w2.R")

poisson_dev <- function(y, mu) { mu <- pmax(mu, 1e-12); 2 * sum(ifelse(y > 0, y * log(y / mu), 0) - (y - mu)) }
gamma_dev <- function(y, mu) { mu <- pmax(mu, 1e-12); 2 * sum(-log(y / mu) + (y - mu) / mu) }
d2_poisson <- function(y, mu, exposure) 1 - poisson_dev(y, mu) / poisson_dev(y, exposure * sum(y) / sum(exposure))
d2_gamma <- function(y, mu) 1 - gamma_dev(y, mu) / gamma_dev(y, rep(mean(y), length(y)))

# 2024 validation actuals: per row x peril (claims and cost, developed and reported) and per claim
actuals_w2 <- function() {
  if (exists(".W2_ACT", envir = .GlobalEnv)) return(get(".W2_ACT", envir = .GlobalEnv))
  shares <- read_clean_w2("emerging_report_shares")
  rows <- rbindlist(lapply(LINES, function(ln) {
    tr <- read_clean_w2(paste0("emerging_train_", ln))[policy_year == 2024L]
    sh <- shares[line == ln][match(tr$row_id, row_id)]
    rbindlist(lapply(PERILS[[ln]], function(p) data.table(row_id = tr$row_id, line = ln, peril = p, share = sh[[paste0("s_", p)]],
      n_rep = tr[[paste0("y_n_", p)]], y_rep = tr[[paste0("y_cost_", p)]])))
  }))
  rows[, `:=`(n_dev = n_rep / share, y_dev = y_rep / share)]
  claims <- read_clean_w2("emerging_claims_matched")[counts & net_cost > 0 & row_id %in% rows$row_id, .(row_id, line, peril, net_cost)]
  act <- list(rows = rows, claims = claims)
  assign(".W2_ACT", act, envir = .GlobalEnv)
  act
}

score_model_w2 <- function(pred, model, desc = "", script = "", fold = "valid") {
  stopifnot(fold == "valid", all(c("row_id", "line", "peril", "exposure", "freq", "sev") %in% names(pred)))
  act <- actuals_w2()
  x <- merge(as.data.table(pred), act$rows, by = c("row_id", "line", "peril"))
  if (nrow(x) != nrow(act$rows)) stop("prediction rows (", nrow(x), ") do not cover every 2024 row x peril (", nrow(act$rows), ")")
  if (!"cost" %in% names(x)) x[, cost := freq * sev]
  cl <- merge(act$claims, x[, .(row_id, line, peril, sev)], by = c("row_id", "line", "peril"))
  freq_cost <- function(d, lv, ln, pr) {
    r <- if (lv == "peril") d else d[, .(exposure = exposure[1], freq = sum(freq), n_dev = sum(n_dev), cost = sum(cost), y_dev = sum(y_dev),
                                         cost_rep = sum(cost * share), y_rep = sum(y_rep)), by = .(line, row_id)]
    if (lv == "peril") r[, cost_rep := cost * share]
    rbind(data.table(component = "frequency", n = nrow(r), actual = sum(r$n_dev), predicted = sum(r$freq), d2 = d2_poisson(r$n_dev, r$freq, r$exposure), d2_rep = NA_real_),
          data.table(component = "cost", n = nrow(r), actual = sum(r$y_dev), predicted = sum(r$cost), d2 = d2_tweedie(r$y_dev, r$cost, r$exposure),
                     d2_rep = d2_tweedie(r$y_rep, r$cost_rep, r$exposure)))[, `:=`(level = lv, line = ln, peril = pr)]
  }
  sev_row <- function(c, lv, ln, pr) data.table(component = "severity", n = nrow(c), actual = mean(c$net_cost), predicted = mean(c$sev),
                                                d2 = if (nrow(c) >= 2) d2_gamma(c$net_cost, c$sev) else NA_real_, d2_rep = NA_real_, level = lv, line = ln, peril = pr)
  out <- list()
  for (ln in LINES) {
    for (p in PERILS[[ln]]) out[[length(out) + 1]] <- rbind(freq_cost(x[line == ln & peril == p], "peril", ln, p), sev_row(cl[line == ln & peril == p], "peril", ln, p))
    out[[length(out) + 1]] <- rbind(freq_cost(x[line == ln], "line", ln, "(all)"), sev_row(cl[line == ln], "line", ln, "(all)"))
  }
  out[[length(out) + 1]] <- rbind(freq_cost(x, "all", "ALL", "(all)"), sev_row(cl, "all", "ALL", "(all)"))
  sc <- rbindlist(out)
  sc[, ae := actual / predicted]
  sc[, `:=`(model = model, fold = fold, description = desc, script = script, scored_at = format(Sys.time(), "%Y-%m-%d %H:%M"))]
  setcolorder(sc, c("model", "fold", "component", "level", "line", "peril", "n", "actual", "predicted", "ae", "d2", "d2_rep"))
  sc[]
}

record_scores_w2 <- function(sc, file = file.path(PATHS_W2$output, "scores", "model_scores.csv")) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  old <- if (file.exists(file)) fread(file)[!model %in% unique(sc$model)] else NULL
  fwrite(rbind(old, sc, fill = TRUE), file)
  log_msg("Scores recorded for ", paste(unique(sc$model), collapse = ", "), " -> ", file)
  invisible(file)
}

# Markdown scorecard: (1) D2 by component x line, (2) D2 by peril, (3) A/E by component x line
scorecard_md_w2 <- function(sc) {
  f4 <- function(v) ifelse(is.na(v), "", formatC(v, format = "f", digits = 4))
  lines_tab <- dcast(sc[level != "peril"], component ~ line, value.var = "d2")[, c("component", "ALL", LINES), with = FALSE]
  lines_tab <- lines_tab[match(c("frequency", "severity", "cost"), component)]
  rep_row <- sc[level != "peril" & component == "cost"][match(c("ALL", LINES), line), d2_rep]
  ae_tab <- dcast(sc[level != "peril"], component ~ line, value.var = "ae")[, c("component", "ALL", LINES), with = FALSE][match(c("frequency", "severity", "cost"), component)]
  per <- dcast(sc[level == "peril"], line + peril ~ component, value.var = c("d2", "ae"))
  per <- per[, .(line, peril, d2_frequency, d2_severity, d2_cost, ae_frequency, ae_severity, ae_cost)]
  per <- per[order(match(line, LINES))]
  fmt_tab <- function(d) { d <- copy(d); for (j in names(d)[sapply(d, is.numeric)]) set(d, j = j, value = f4(d[[j]])); md_table(d) }
  c(paste0("**", sc$model[1], "**: ", sc$description[1], " (script `", sc$script[1], "`, scored ", sc$scored_at[1], ")"), "",
    "D2 by component and line (validation 2024, developed basis):", "",
    fmt_tab(rbind(lines_tab, as.data.table(setNames(c(list("cost (reported basis)"), as.list(rep_row)), names(lines_tab))))),
    "A/E (actual / predicted):", "", fmt_tab(ae_tab),
    "D2 and A/E by peril:", "", fmt_tab(per))
}
