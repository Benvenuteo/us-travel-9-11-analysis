#!/usr/bin/env Rscript
# Rebuild figures from cached numerical results without repeating validation.
suppressPackageStartupMessages({library(fpp3); library(ggtime); library(patchwork)})
for (module in c("data", "models", "plots")) {
  source(file.path("R", paste0(module, ".R")), encoding = "UTF-8")
}
path <- "outputs/results/analysis.rds"
if (!file.exists(path)) stop("Run scripts/run_analysis.R first.")
set.seed(20010911)
result <- readRDS(path)
if (is.null(result$fitted)) result$fitted <- fit_travel_models(result$train)
warnings_seen <- unique(trimws(gsub("[[:space:]]+", " ", result$warnings)))
withCallingHandlers(
  make_figures(result$data, result$train, result$fitted,
               list(main = result$cv_accuracy, by_horizon = result$cv_horizons),
               result$forecasts, result$best, result$selected_gaps,
               result$config$cutoff, "outputs/figures"),
  warning = function(warning) {
    warning_text <- trimws(gsub("[[:space:]]+", " ", conditionMessage(warning)))
    warnings_seen <<- unique(c(warnings_seen, warning_text))
    invokeRestart("muffleWarning")
  }
)
result$warnings <- warnings_seen
saveRDS(result, path, version = 3)
writeLines(if (length(warnings_seen)) warnings_seen else "No warnings.",
           "outputs/results/analysis-warnings.txt", useBytes = TRUE)
audit_path <- "outputs/results/analysis-audit.json"
audit <- jsonlite::read_json(audit_path)
audit$warning_count <- length(warnings_seen)
jsonlite::write_json(audit, audit_path, pretty = TRUE, auto_unbox = TRUE)
message("All figures rebuilt from the validated numerical results.")
