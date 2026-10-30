# Use the parent project's renv library (built for R 4.6) when R starts in this folder (Windows, macOS or Linux).
local({
  ver <- paste0("R-", R.version$major, ".", sub("\\..*", "", R.version$minor))
  libs <- Sys.glob(file.path("..", "..", "renv", "library", "*", ver, R.version$platform))
  if (length(libs)) .libPaths(c(normalizePath(libs[1]), .libPaths()))
})
