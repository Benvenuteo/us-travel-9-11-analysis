#!/usr/bin/env Rscript
# Run from the repository root after computing the analysis outputs.
suppressPackageStartupMessages({ library(fpp3); library(testthat) })
for (module in c("data", "models", "analysis")) {
  source(file.path("R", paste0(module, ".R")), encoding = "UTF-8")
}
# Tests refer to repository-root paths rather than changing directories.
Sys.setenv(TRAVEL_PROJECT_ROOT = normalizePath("."))
root_file <- function(...) file.path(Sys.getenv("TRAVEL_PROJECT_ROOT"), ...)
testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE,
                    load_helpers = FALSE, env = globalenv())
