# eda_helpers.R ---------------------------------------------------------------
# Shared helpers for the column EDA sections (bottom of week1/R/1_eda.R raw data, bottom of week1/R/2_clean.R cleaned data).
# Source after week1/R/0_setup.R. The calling script sets STEP (its output folder) before using eda_columns(),
# write_eda_page() or write_page_index().
# One plot per column: the share of rows in each value or bin, for one set or two sets compared
# (2021-24 vs 2025, or raw vs cleaned), with summary statistics, warning flags and a PSI for two sets.

N_BINS <- 40          # equal-width bins for continuous numeric columns
MAX_DISCRETE <- 25    # numeric columns with at most this many distinct values are plotted value by value
MAX_LEVELS <- 25      # categorical levels shown (most frequent first); the rest are grouped into "(other)"
RARE_SHARE <- 0.005   # a categorical level below this share of rows counts as rare
SERIES_COLOURS <- c("#2a78d6", "#eb6834")  # first set blue, second set orange

# Plot type: categorical (text / yes-no), discrete (few numeric values) or continuous
column_kind <- function(x) {
  if (is.character(x) || is.logical(x) || is.factor(x)) return("categorical")
  if (uniqueN(x, na.rm = TRUE) <= MAX_DISCRETE) "discrete" else "continuous"
}

# Long right tail of non-negative values: bin on log10(x + 1) so the bulk is not squashed into one bar
use_log_scale <- function(x) {
  x <- x[is.finite(x)]
  length(x) > 0 && min(x) >= 0 && (max(x) + 1) / (median(x) + 1) >= 20
}

# Common bins for the two sets (b = NULL for a single set). Returns factors with identical levels; missing
# values get their own level so they count in the shares and the PSI. Continuous: bins span the full range,
# so outliers stretch the axis instead of being hidden in an end bin.
bin_column <- function(a, b, kind) {
  if (kind == "categorical") {
    xa <- as.character(a); xb <- as.character(b)
    xa[is.na(xa)] <- "missing"; xb[is.na(xb)] <- "missing"
    top <- names(sort(table(c(xa, xb)), decreasing = TRUE))
    keep <- head(top, MAX_LEVELS)
    if (length(top) > MAX_LEVELS) {
      other <- sprintf("(other %d levels)", length(top) - MAX_LEVELS)
      xa[!xa %in% keep] <- other; xb[!xb %in% keep] <- other
      keep <- c(keep, other)
    }
    return(list(a = factor(xa, keep), b = factor(xb, keep), log = FALSE))
  }
  if (kind == "discrete") {
    vals <- sort(unique(c(a[!is.na(a)], b[!is.na(b)])))
    lv <- as.character(vals)
    xa <- as.character(a); xb <- as.character(b)
    if (anyNA(xa) || anyNA(xb)) {
      xa[is.na(xa)] <- "missing"; xb[is.na(xb)] <- "missing"
      lv <- c(lv, "missing")
    }
    return(list(a = factor(xa, lv), b = factor(xb, lv), log = FALSE))
  }
  log <- use_log_scale(c(a, b))
  f <- if (log) function(v) log10(v + 1) else identity
  breaks <- seq(min(f(c(a, b)), na.rm = TRUE), max(f(c(a, b)), na.rm = TRUE), length.out = N_BINS + 1)
  lv <- c(as.character(seq_len(N_BINS)), "missing")
  to_bin <- function(v) {
    i <- as.character(findInterval(f(v), breaks, rightmost.closed = TRUE, all.inside = TRUE))
    i[is.na(i)] <- "missing"
    factor(i, lv)
  }
  list(a = to_bin(a), b = to_bin(b), log = log,
       mid = (head(breaks, -1) + tail(breaks, -1)) / 2, width = breaks[2] - breaks[1])
}

shares <- function(f) as.numeric(table(f)) / max(length(f), 1)

# Population stability index of the second set against the first, over the same bins. Common rule of thumb:
# < 0.1 stable, 0.1-0.25 moderate, > 0.25 large. A convention for the size of a shift, not a statistical test.
psi <- function(p_a, p_b, floor = 1e-4) {
  p_a <- pmax(p_a, floor); p_b <- pmax(p_b, floor)
  sum((p_b - p_a) * log(p_b / p_a))
}

# % missing; cleaned text columns store missing values as the level "missing"
pct_missing <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_real_)
  100 * if (is.character(x)) mean(is.na(x) | x == "missing") else mean(is.na(x))
}

fnum <- function(x) {
  ifelse(is.na(x), "-", ifelse(abs(x - round(x)) < 1e-9, formatC(round(x), format = "d", big.mark = ","),
                               formatC(signif(x, 4), format = "fg", big.mark = ",")))
}

# Statistics and bins for one column. xb = NULL when the dataset has a single set or the column is absent
# from the second set. comparison = "drift" (2021-24 vs 2025) or "cleaning" (raw vs cleaned) sets the flag wording.
profile_column <- function(page, v, src, xa, xb, two_sets, comparison = "drift") {
  b_has <- !is.null(xb)
  kind <- column_kind(c(xa, xb))
  bins <- bin_column(xa, xb, kind)
  p_a <- shares(bins$a)
  num <- kind != "categorical"
  x <- c(xa, xb)
  num_stat <- function(fn, v) if (num && any(!is.na(v))) fn(v, na.rm = TRUE) else NA_real_
  st <- data.table(
    page = page, column = v, source = src, kind = kind, comparison = comparison, log_scale = bins$log,
    n_distinct = uniqueN(x, na.rm = TRUE),
    pct_missing_first = pct_missing(xa), pct_missing_second = if (b_has) pct_missing(xb) else NA_real_,
    top_value = if (kind == "continuous") NA_character_ else levels(bins$a)[which.max(p_a)],
    top_share = if (kind == "continuous") NA_real_ else max(p_a),
    n_rare_levels = if (kind == "categorical") sum(prop.table(table(xa)) < RARE_SHARE) else NA_integer_,
    pct_zero = if (num) 100 * mean(x == 0, na.rm = TRUE) else NA_real_,
    min = num_stat(min, x), median = num_stat(median, x), max = num_stat(max, x),
    mean_first = num_stat(mean, xa), mean_second = if (b_has) num_stat(mean, xb) else NA_real_,
    pct_second_unseen = if (b_has && kind != "continuous") 100 * mean(!(xb %in% xa)) else NA_real_,
    psi = if (b_has) psi(p_a, shares(bins$b)) else NA_real_,
    second_set_missing_column = two_sets && !b_has
  )
  list(stats = st, bins = bins)
}

flag_text <- function(s) {
  shift <- if (s$comparison == "drift") "drift" else "change from cleaning"
  f <- c(
    if (s$second_set_missing_column) "column only in the first set",
    if (s$n_distinct <= 1) "single value",
    if (s$n_distinct > 1 && !is.na(s$top_share) && s$top_share >= 0.95)
      sprintf("one value is %.0f%% of rows", 100 * s$top_share),
    if (max(s$pct_missing_first, s$pct_missing_second, na.rm = TRUE) >= 5) "missing >= 5%",
    if (s$kind == "continuous" && !is.na(s$pct_zero) && s$pct_zero >= 20) sprintf("%.0f%% zeros", s$pct_zero),
    if (s$kind == "categorical" && s$n_distinct > MAX_LEVELS) sprintf("%d levels (top %d shown)", s$n_distinct, MAX_LEVELS),
    if (s$comparison == "drift" && !is.na(s$pct_second_unseen) && s$pct_second_unseen > 0)
      sprintf("%s%% of 2025 rows have values not seen before", fnum(s$pct_second_unseen)),
    if (!is.na(s$psi) && s$psi >= 0.25) sprintf("large %s (PSI >= 0.25)", shift)
    else if (!is.na(s$psi) && s$psi >= 0.1) sprintf("moderate %s (PSI >= 0.1)", shift)
  )
  paste(f, collapse = "; ")
}

stats_line <- function(s) {
  miss <- if (is.na(s$pct_missing_second)) sprintf("missing %.1f%%", s$pct_missing_first)
          else sprintf("missing %.1f%% / %.1f%%", s$pct_missing_first, s$pct_missing_second)
  body <- if (s$kind == "categorical") {
    sprintf("%s levels; most common `%s` (%.1f%% of rows)", fnum(s$n_distinct), s$top_value, 100 * s$top_share)
  } else {
    mean_txt <- if (is.na(s$mean_second)) sprintf("mean %s", fnum(s$mean_first))
                else sprintf("mean %s / %s", fnum(s$mean_first), fnum(s$mean_second))
    sprintf("%s distinct; min %s, median %s, max %s; %s", fnum(s$n_distinct), fnum(s$min), fnum(s$median),
            fnum(s$max), mean_txt)
  }
  psi_txt <- if (is.na(s$psi)) "" else sprintf("; PSI %.3f", s$psi)
  paste0("*", s$kind, if (s$log_scale) ", log scale" else "", "* - ", body, "; ", miss, psi_txt)
}

plot_column <- function(s, bins, sets) {
  two <- length(sets) == 2 && !s$second_set_missing_column
  d <- data.table(set = sets[1], level = levels(bins$a), share = shares(bins$a))
  if (two) d <- rbind(d, data.table(set = sets[2], level = levels(bins$b), share = shares(bins$b)))
  d[, set := factor(set, sets)]
  cols <- setNames(SERIES_COLOURS[seq_along(sets)], sets)
  miss <- if (two) sprintf("missing %.1f%% / %.1f%%", s$pct_missing_first, s$pct_missing_second)
          else sprintf("missing %.1f%%", s$pct_missing_first)
  sub <- paste0(s$kind, if (s$log_scale) " (x axis log scale)" else "", " | ", miss,
                if (two) sprintf(" | PSI %.3f", s$psi) else "")

  if (s$kind == "continuous") {
    d <- d[level != "missing"][, x := bins$mid[as.integer(level)]]
    p <- ggplot(d[set == sets[1]], aes(x, share)) +
      geom_col(aes(fill = set), width = bins$width * 0.92)
    if (two) p <- p + geom_line(data = d[set == sets[2]], aes(colour = set), linewidth = 0.8) +
      geom_point(data = d[set == sets[2]], aes(colour = set), size = 1.4)
    lab <- if (bins$log) function(v) scales::label_comma(accuracy = 1)(10^v - 1) else scales::label_comma()
    p <- p + scale_x_continuous(labels = lab)
  } else {
    lv <- levels(bins$a)
    d[, level := factor(level, if (s$kind == "categorical") rev(lv) else lv)]
    p <- ggplot(d, aes(level, share, fill = set)) +
      geom_col(position = position_dodge(width = 0.85, preserve = "single"), width = 0.8)
    if (s$kind == "categorical") p <- p + coord_flip()
    else if (length(lv) > 12) p <- p + theme(axis.text.x = element_text(angle = 45, hjust = 1))
  }
  p + scale_fill_manual(values = cols, name = NULL) +
    scale_colour_manual(values = cols, name = NULL) +
    scale_y_continuous(labels = scales::label_percent(accuracy = 0.1), expand = expansion(mult = c(0, 0.05))) +
    labs(title = s$column, subtitle = sub, x = NULL, y = "share of rows") +
    theme(legend.position = if (two) "top" else "none", panel.grid.minor = element_blank())
}

plot_height <- function(s, bins) {
  if (s$kind == "categorical") max(3.5, 1.6 + 0.24 * nlevels(bins$a)) else 4
}

# Profile and plot each column into week1/output/<STEP>/<page>/NN_<column>.png; returns the column statistics.
# b = NULL for a single set; src (one per column) groups the page into sections; start = first plot number.
eda_columns <- function(page, a, b, sets, cols, src = rep(page, length(cols)), comparison = "drift", start = 1L) {
  log_msg(page, ": ", length(cols), " columns")
  rows <- vector("list", length(cols))
  for (i in seq_along(cols)) {
    v <- cols[i]
    xb <- if (!is.null(b) && v %in% names(b)) b[[v]] else NULL
    res <- profile_column(page, v, src[i], a[[v]], xb, two_sets = !is.null(b), comparison)
    n <- start + i - 1L
    png <- sprintf("%s/%02d_%s.png", page, n, v)
    save_plot(plot_column(res$stats, res$bins, sets), STEP, png, width = 8, height = plot_height(res$stats, res$bins))
    rows[[i]] <- res$stats[, `:=`(plot = png, order = n)]
  }
  st <- rbindlist(rows)
  st[, flags := vapply(seq_len(.N), function(k) flag_text(st[k]), character(1))]
  st
}

# Write week1/output/<STEP>/<page>.md: one section per source (section_labels = named labels, NULL = no sections),
# one heading, statistics line, flags and plot per column. Returns the statistics with the page title added.
write_eda_page <- function(page, page_title, intro, st, overview, section_labels = NULL) {
  groups <- if (is.null(section_labels)) unique(st$source) else intersect(names(section_labels), unique(st$source))
  body <- c()
  for (g in groups) {
    if (!is.null(section_labels)) body <- c(body, paste0("## ", section_labels[[g]]), "")
    for (k in which(st$source == g)) {
      s <- st[k]
      body <- c(body, paste0("### ", s$column), "", stats_line(s), "",
                if (nzchar(s$flags)) c(paste0("**Flags:** ", s$flags), ""),
                paste0("![](", s$plot, "){width=90%}"), "")
    }
  }
  write_md(c(paste0("# ", page_title), "", intro, "", paste0("Back to the [overview](", overview, ")."), "", body),
           STEP, paste0(page, ".md"))
  st[, title := page_title][]
}

# Sentence explaining the colours of a two-set page
two_set_intro <- function(first, second) paste0(
  "Blue = ", first, ", orange = ", second, ". Bars and line show the share of rows in each value or bin; ",
  "means and % missing are given as ", first, " / ", second, ".")

# Method bullets shared by the overview reports
method_lines <- function() c(
  paste0("- **Continuous** numeric columns: ", N_BINS, " equal-width bins over the full range, so outliers stretch",
         " the axis; columns that are non-negative with a long right tail use log10(x + 1) bins."),
  paste0("- **Discrete** numeric columns (at most ", MAX_DISCRETE, " distinct values): one bar per value."),
  paste0("- **Categorical** columns (text, yes/no): the ", MAX_LEVELS, " most frequent levels, the rest grouped as",
         " `(other)`. Missing values are shown as their own bar. Shares are of rows, not exposure."),
  paste0("- **PSI** (population stability index) = sum over bins of (second share - first share) x ln(second share /",
         " first share), missing as its own bin. Rule of thumb: below 0.1 stable, 0.1-0.25 moderate, above 0.25",
         " large. It is a convention for the size of a shift, not a statistical test; with about a million rows",
         " almost any difference is 'significant'."),
  paste0("- **Flags:** single value, one value >= 95% of rows, >= 5% missing, >= 20% zeros, more than ", MAX_LEVELS,
         " levels, 2025 values not seen in 2021-24, moderate or large shift."), "")

# Links to the pages and flagged-column table for the overview report
page_links <- function(st, pages) {
  pg <- st[page %in% pages, .(title = title[1], columns = .N, flagged = sum(nzchar(flags))), by = page]
  c(paste0("- [", pg$title, "](", pg$page, ".md): ", pg$columns, " columns, ", pg$flagged, " flagged"), "")
}
flag_table <- function(st, pages) {
  md_table(st[page %in% pages & nzchar(flags),
              .(page, column, kind, flags, pct_missing_first, pct_missing_second, psi)], 3)
}

# Page order for week1/R/5_build_site.R, and the full statistics table
write_page_index <- function(st, pages) {
  save_csv(data.table(page = pages), STEP, "pages.csv")
  save_csv(st[, !"order"], STEP, "column_summary.csv")
}
