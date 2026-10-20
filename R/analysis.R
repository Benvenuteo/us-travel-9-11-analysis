#' Describe the original data without changing their measurement units.
#' @param data Complete monthly travel tsibble.
#' @return Per-series sample sizes, range and summary statistics.
describe_travel <- function(data) {
  data |>
    tibble::as_tibble() |>
    dplyr::group_by(Travel) |>
    dplyr::summarise(
      N = dplyr::n(), Start = min(Month), End = max(Month),
      Minimum = min(Value), Maximum = max(Value), Mean = mean(Value),
      Median = stats::median(Value), SD = stats::sd(Value), .groups = "drop"
    )
}

#' Calculate descriptive correlations for levels and annual log changes.
#' @param data Complete data, used only for descriptive comparisons.
#' @param cutoff Month of the event.
#' @return Pairwise correlations and explicit effective sample sizes.
travel_correlations <- function(data, cutoff) {
  transformed <- data |>
    dplyr::group_by(Travel) |>
    dplyr::mutate(AnnualLogChange = log(Value) - dplyr::lag(log(Value), 12L)) |>
    dplyr::ungroup() |>
    tibble::as_tibble() |>
    dplyr::mutate(Period = ifelse(Month < cutoff, "Pre", "Post"))
  rows <- list()
  for (period in c("Pre", "Post")) {
    for (measure in c("Value", "AnnualLogChange")) {
      wide <- transformed |>
        dplyr::filter(Period == period) |>
        dplyr::select(Month, Travel, dplyr::all_of(measure)) |>
        tidyr::pivot_wider(names_from = Travel, values_from = dplyr::all_of(measure)) |>
        dplyr::filter(stats::complete.cases(dplyr::pick(Air, Rail, Car)))
      for (pair in list(c("Air", "Rail"), c("Air", "Car"), c("Rail", "Car"))) {
        rows[[length(rows) + 1L]] <- tibble::tibble(
          Period = period, Measure = measure, First = pair[[1L]],
          Second = pair[[2L]], N = nrow(wide),
          Correlation = stats::cor(wide[[pair[[1L]]]], wide[[pair[[2L]]]])
        )
      }
    }
  }
  dplyr::bind_rows(rows)
}

#' Evaluate fitted errors on common months for every model.
#' @param fitted Full pre-event model table.
#' @param train Full pre-event data.
#' @return Original-scale training accuracy on months 13 through T.
training_accuracy <- function(fitted, train) {
  first_common_month <- min(train$Month) + 12L
  fitted |>
    fabletools::augment() |>
    tibble::as_tibble() |>
    dplyr::transmute(Travel, Model = .model, Month, Actual = Value, Forecast = .fitted) |>
    dplyr::filter(Month >= first_common_month) |>
    dplyr::left_join(seasonal_scales(train), by = "Travel") |>
    score_forecasts()
}

#' Calculate model-dependent post-event gaps without causal attribution.
#' @param forecast_rows Joined forecasts and actual values.
#' @return The same rows with signed absolute and percentage gaps.
calculate_gaps <- function(forecast_rows) {
  if (any(!is.finite(forecast_rows$Forecast) | forecast_rows$Forecast <= 0)) {
    stop("Percentage gaps require strictly positive finite forecasts.")
  }
  forecast_rows |>
    dplyr::group_by(Travel, Model) |>
    dplyr::arrange(Month, .by_group = TRUE) |>
    dplyr::mutate(
      Horizon = dplyr::row_number(), Gap = Actual - Forecast,
      GapPct = 100 * Gap / Forecast, CumulativeGap = cumsum(Gap),
      Below95 = Actual < Lower95, Above95 = Actual > Upper95
    ) |>
    dplyr::ungroup()
}

#' Summarise signed cumulative gaps over pre-defined event windows.
#' @param gaps Point-level gaps for one or more models.
#' @param windows Window lengths measured from September 2001.
#' @return Point estimates for sums; monthly interval endpoints are not added.
summarise_gaps <- function(gaps, windows = c(3L, 6L, 12L, 32L)) {
  dplyr::bind_rows(lapply(windows, function(window) {
    subset <- gaps |> dplyr::filter(Horizon <= window)
    summary <- subset |>
      dplyr::group_by(Travel, Model) |>
      dplyr::summarise(
        Months = dplyr::n(), ActualTotal = sum(Actual),
        ForecastTotal = sum(Forecast), GapTotal = sum(Gap),
        GapPct = 100 * sum(Gap) / sum(Forecast),
        MonthsBelow95 = sum(Below95), MonthsAbove95 = sum(Above95),
        .groups = "drop"
      )
    if (any(summary$Months != window)) stop("Incomplete event window.")
    summary
  }))
}

#' Summarise yearly within-year amplitudes using complete pre-event years.
#' @param train Pre-event observations.
#' @return A descriptive table; no additive/multiplicative hypothesis test.
seasonal_amplitudes <- function(train) {
  train |>
    tibble::as_tibble() |>
    dplyr::mutate(Year = lubridate::year(as.Date(Month))) |>
    dplyr::group_by(Travel, Year) |>
    dplyr::summarise(
      Months = dplyr::n(), Level = mean(Value), Range = max(Value) - min(Value),
      RelativeRange = (max(Value) - min(Value)) / mean(Value), .groups = "drop"
    ) |>
    dplyr::filter(Months == 12L)
}
