#!/usr/bin/env Rscript
# Run from the repository root: Rscript scripts/run_analysis.R
suppressPackageStartupMessages({
  library(fpp3)
  library(ggtime)
  library(readr)
  library(jsonlite)
  library(digest)
  library(patchwork)
})
if (!file.exists("data/raw/sept11_travel.csv")) {
  stop("Run this script from the repository root.")
}
set.seed(20010911)
options(width = 120, scipen = 8)
for (module in c("data", "models", "analysis", "plots")) {
  source(file.path("R", paste0(module, ".R")), encoding = "UTF-8")
}
config <- list(cutoff = tsibble::yearmonth("2001 Sep"), period = 12L,
               initial = 60L, step = 3L, main_horizon = 12L,
               long_horizon = 32L, ljung_lag = 24L, seed = 20010911L)
for (directory in c("outputs/tables", "outputs/figures", "outputs/results")) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
}
warnings_seen <- character()
results <- withCallingHandlers({
  data <- read_travel_data("data/raw/sept11_travel.csv")
  train <- data |> dplyr::filter(Month < config$cutoff)
  post <- data |> dplyr::filter(Month >= config$cutoff)
  if (length(unique(train$Month)) != 140L || length(unique(post$Month)) != 32L) {
    stop("Unexpected analysis period; update the protocol before changing the sample.")
  }
  cv <- validate_models(train, config$initial, config$step,
                        config$main_horizon, config$long_horizon)
  best <- cv$main |>
    dplyr::filter(Rank == 1L) |>
    dplyr::select(Travel, Model, MASE, RMSE, MAE, MAPE, Coverage80, Coverage95)
  message("Fitting the final pre-event models and forecasting the 32 post-event months.")
  fitted <- fit_travel_models(train)
  forecasts <- fitted |>
    fabletools::forecast(new_data = post |> dplyr::select(Travel, Month)) |>
    forecast_frame() |>
    dplyr::left_join(post |> tibble::as_tibble() |>
                      dplyr::rename(Actual = Value), by = c("Travel", "Month")) |>
    dplyr::left_join(seasonal_scales(train), by = "Travel")
  if (nrow(forecasts) != 576L || anyNA(forecasts$Actual)) stop("Misaligned post-event forecasts.")
  gaps_all <- calculate_gaps(forecasts)
  selected_gaps <- gaps_all |>
    dplyr::inner_join(best |> dplyr::select(Travel, Model), by = c("Travel", "Model"))
  diagnostics <- diagnose_models(fitted, best, config$ljung_lag)
  train_accuracy <- training_accuracy(fitted, train)
  post_accuracy <- score_forecasts(forecasts)
  impact <- summarise_gaps(selected_gaps)
  sensitivity <- summarise_gaps(gaps_all)
  description <- describe_travel(data)
  correlations <- travel_correlations(data, config$cutoff)
  amplitudes <- seasonal_amplitudes(train)
  list(config = config, description = description, correlations = correlations,
       amplitudes = amplitudes, best = best, cv_accuracy = cv$main,
       cv_long = cv$long, cv_horizons = cv$by_horizon, folds = cv$folds,
       train_accuracy = train_accuracy, post_accuracy = post_accuracy,
       diagnostics = diagnostics$tests, impact = impact, sensitivity = sensitivity,
       selected_gaps = selected_gaps, forecasts = forecasts,
       data = data, train = train, post = post,
       validation_predictions = cv$points,
       innovations = diagnostics$innovations,
       coefficients = generics::tidy(fitted) |> tibble::as_tibble(), fitted = fitted)
}, warning = function(warning) {
  # Preserve warnings as an output artifact while avoiding repeated console noise.
  warning_text <- trimws(gsub("[[:space:]]+", " ", conditionMessage(warning)))
  warnings_seen <<- unique(c(warnings_seen, warning_text))
  invokeRestart("muffleWarning")
})
results$warnings <- warnings_seen
tables <- list(
  descriptive_statistics = results$description, correlations = results$correlations,
  yearly_amplitudes = results$amplitudes, validation_accuracy = results$cv_accuracy,
  validation_long_horizon = results$cv_long, validation_by_horizon = results$cv_horizons,
  validation_folds = results$folds, selected_models = results$best,
  training_accuracy = results$train_accuracy, post_event_accuracy = results$post_accuracy,
  residual_diagnostics = results$diagnostics, event_window_gaps = results$impact,
  model_sensitivity = results$sensitivity, monthly_gaps = results$selected_gaps,
  post_event_forecasts = results$forecasts,
  validation_predictions = results$validation_predictions,
  selected_innovations = results$innovations, model_coefficients = results$coefficients
)
# Dates are exported as ISO month labels; distribution objects never enter CSVs.
for (name in names(tables)) {
  table <- tables[[name]] |>
    dplyr::mutate(dplyr::across(where(~ inherits(.x, "yearmonth")),
                              ~ format(as.Date(.x), "%Y-%m")))
  readr::write_csv(table, file.path("outputs/tables", paste0(name, ".csv")))
}
saveRDS(results, "outputs/results/analysis.rds", version = 3)
writeLines(capture.output(sessionInfo()), "outputs/results/session-info.txt", useBytes = TRUE)
writeLines(if (length(warnings_seen)) warnings_seen else "No warnings.",
           "outputs/results/analysis-warnings.txt", useBytes = TRUE)
model_reports <- unlist(lapply(seq_len(nrow(results$best)), function(i) {
  travel <- results$best$Travel[[i]]
  model <- results$best$Model[[i]]
  one <- fitted |> dplyr::filter(Travel == travel) |>
    dplyr::select(Travel, dplyr::all_of(model))
  c(paste("Series:", travel, "Model:", model), capture.output(fabletools::report(one)), "")
}))
writeLines(model_reports, "outputs/results/model-reports.txt", useBytes = TRUE)
# Persist numerical results before plotting so a device failure cannot discard them.
message("Rendering report figures.")
withCallingHandlers(
  make_figures(data, train, fitted, cv, forecasts, best, selected_gaps,
               config$cutoff, "outputs/figures"),
  warning = function(warning) {
    warning_text <- trimws(gsub("[[:space:]]+", " ", conditionMessage(warning)))
    warnings_seen <<- unique(c(warnings_seen, warning_text))
    invokeRestart("muffleWarning")
  }
)
results$warnings <- warnings_seen
saveRDS(results, "outputs/results/analysis.rds", version = 3)
writeLines(if (length(warnings_seen)) warnings_seen else "No warnings.",
           "outputs/results/analysis-warnings.txt", useBytes = TRUE)
audit <- list(
  source_sha256 = digest::digest(file = "data/raw/sept11_travel.csv", algo = "sha256"),
  complete_months = length(unique(results$data$Month)), series = 3L,
  train_months = 140L, post_months = 32L,
  folds = nrow(results$folds), complete_long_folds = sum(results$folds$ForecastMonths == 32L),
  latest_validation_month = as.character(max(results$validation_predictions$Month)),
  selected_models = as.data.frame(results$best |> dplyr::select(Travel, Model)),
  model_selection_uses_post_event_data = FALSE,
  warning_count = length(warnings_seen), R_version = as.character(getRversion())
)
jsonlite::write_json(audit, "outputs/results/analysis-audit.json", pretty = TRUE, auto_unbox = TRUE)
message("Analysis completed. Selected models:")
print(results$best)
message("First-year gaps (observed minus forecast):")
print(results$impact |> dplyr::filter(Months == 12L))
source("scripts/update_readme.R", encoding = "UTF-8")
