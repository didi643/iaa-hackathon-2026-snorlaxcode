source("week1/R/0_setup.R")
source("week1/R/model_io.R")

origin <- as.Date("2024-01-01")
share <- seq(1, 0.1, length.out = 366)
rs <- list(origin = origin, cumshare = list(theft = cumsum(share)))
start <- as.Date(c("2024-01-01", "2024-06-01", "2024-12-31", "2025-01-01", "2024-12-01"))
end <- as.Date(c("2024-12-31", "2024-06-30", "2024-12-31", "2025-12-31", "2025-01-31"))

got <- row_report_share(rs, "theft", start, end)
day_share <- function(d) ifelse(d > as.Date("2024-12-31"), 1, share[as.integer(d - origin) + 1L])
expected <- mapply(function(s, e) mean(day_share(seq(s, e, by = "day"))), start, end)
stopifnot(max(abs(got - expected)) < 1e-12, got[4] == 1)

cat("row_report_share passed\n")
