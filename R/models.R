#' Fit the six pre-specified model classes independently for each series.
#'
#' @param history Training tsibble; no later observations are used.
#' @return A fable model table.
fit_travel_models <- function(history) {
  history |>
    fabletools::model(
      Mean = fable::MEAN(Value),
      Naive = fable::NAIVE(Value),
      SNaive = fable::SNAIVE(Value ~ lag("year")),
      Drift = fable::RW(Value ~ drift()),
      ETS = fable::ETS(Value),
      ARIMA = fable::ARIMA(Value, approximation = FALSE, stepwise = TRUE)
    )
}

#' Extract forecasts and central prediction intervals on the original scale.
#'
#' @param forecasts A fable forecast table with response Value.
#' @return A plain tibble suitable for validated joins and CSV export.
forecast_frame <- function(forecasts) {
  frame <- forecasts |>
    fabletools::hilo(level = c(80, 95)) |>
    fabletools::unpack_hilo(c(`80%`, `95%`)) |>
    tibble::as_tibble() |>
    dplyr::transmute(
      Travel, Model = .model, Month, Forecast = .mean,
      Lower80 = `80%_lower`, Upper80 = `80%_upper`,
      Lower95 = `95%_lower`, Upper95 = `95%_upper`
    )
  numeric_part <- frame |>
    dplyr::select(Forecast, Lower80, Upper80, Lower95, Upper95)
  if (any(!is.finite(as.matrix(numeric_part)))) stop("Non-finite forecasts detected.")
  if (any(frame$Lower95 > frame$Lower80 | frame$Lower80 > frame$Upper80 |
          frame$Upper80 > frame$Upper95)) stop("Invalid prediction intervals.")
  frame
}

#' Calculate original-unit errors and correctly scaled seasonal MASE.
#'
#' @param rows Data frame containing Actual, Forecast and positive Scale.
#' @param groups Grouping columns for the accuracy summary.
#' @return A tibble with sample sizes and accuracy measures.
score_forecasts <- function(rows, groups = c("Travel", "Model")) {
  if (any(!is.finite(rows$Actual) | !is.finite(rows$Forecast))) {
    stop("Non-finite values cannot be scored.")
  }
  if (any(rows$Actual <= 0 | !is.finite(rows$Scale) | rows$Scale <= 0)) {
    stop("MAPE and seasonal MASE require valid positive denominators.")
  }
  rows |>
    dplyr::mutate(Error = Actual - Forecast) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(groups))) |>
    dplyr::summarise(
      N = dplyr::n(), RMSE = sqrt(mean(Error^2)), MAE = mean(abs(Error)),
      MAPE = 100 * mean(abs(Error / Actual)),
      MASE = mean(abs(Error) / Scale), Bias = mean(Error), .groups = "drop"
    )
}

#' Run expanding-window validation entirely before the event date.
#'
#' Every main fold has all 12 future observations. Longer forecasts are
#' retained only when they also end before the event; comparisons at a given
#' horizon therefore use the same origins for every model.
#' @param pre_event Pre-event training tsibble.
#' @param initial Minimum training length in months.
#' @param step Number of months between forecast origins.
#' @param horizon Main validation horizon.
#' @param long_horizon Maximum additional horizon.
#' @return Point-level forecasts, fold boundaries and grouped accuracy tables.
validate_models <- function(pre_event, initial = 60L, step = 3L,
                            horizon = 12L, long_horizon = 32L) {
  months <- sort(unique(pre_event$Month))
  if (length(months) < initial + long_horizon) stop("Insufficient pre-event history.")
  origins <- seq.int(initial, length(months) - horizon, by = step)
  point_rows <- vector("list", length(origins))
  fold_rows <- vector("list", length(origins))
  for (i in seq_along(origins)) {
    origin <- origins[[i]]
    horizon_available <- min(long_horizon, length(months) - origin)
    history <- pre_event |> dplyr::filter(Month <= months[[origin]])
    future <- pre_event |>
      dplyr::filter(Month > months[[origin]], Month <= months[[origin + horizon_available]])
    message(sprintf("Validation fold %02d/%02d; training ends %s", i,
                    length(origins), months[[origin]]))
    # Remove future outcomes explicitly before giving dates to forecast().
    fitted <- fit_travel_models(history)
    predicted <- fitted |>
      fabletools::forecast(new_data = future |> dplyr::select(Travel, Month)) |>
      forecast_frame() |>
      dplyr::left_join(future |> tibble::as_tibble() |>
                        dplyr::rename(Actual = Value), by = c("Travel", "Month")) |>
      dplyr::left_join(seasonal_scales(history), by = "Travel") |>
      dplyr::group_by(Travel, Model) |>
      dplyr::arrange(Month, .by_group = TRUE) |>
      dplyr::mutate(Horizon = dplyr::row_number()) |>
      dplyr::ungroup() |>
      dplyr::mutate(Fold = i, Origin = months[[origin]],
                    CompleteLong = horizon_available == long_horizon)
    expected_rows <- 3L * 6L * horizon_available
    if (nrow(predicted) != expected_rows || anyNA(predicted$Actual)) {
      stop("Incomplete or misaligned validation forecasts.")
    }
    point_rows[[i]] <- predicted
    fold_rows[[i]] <- tibble::tibble(
      Fold = i, TrainStart = months[[1L]], TrainEnd = months[[origin]],
      ForecastStart = months[[origin + 1L]],
      ForecastEnd = months[[origin + horizon_available]],
      TrainMonths = origin, ForecastMonths = horizon_available
    )
  }
  points <- dplyr::bind_rows(point_rows)
  main <- points |> dplyr::filter(Horizon <= horizon)
  main_accuracy <- score_forecasts(main) |>
    dplyr::group_by(Travel) |>
    dplyr::arrange(MASE, RMSE, Model, .by_group = TRUE) |>
    dplyr::mutate(Rank = dplyr::row_number()) |>
    dplyr::ungroup()
  coverage <- main |>
    dplyr::group_by(Travel, Model) |>
    dplyr::summarise(
      Coverage80 = mean(Actual >= Lower80 & Actual <= Upper80),
      Coverage95 = mean(Actual >= Lower95 & Actual <= Upper95), .groups = "drop"
    )
  list(points = points, folds = dplyr::bind_rows(fold_rows),
       main = dplyr::left_join(main_accuracy, coverage, by = c("Travel", "Model")),
       long = score_forecasts(dplyr::filter(points, CompleteLong)),
       by_horizon = score_forecasts(points, c("Travel", "Model", "Horizon")))
}

#' Diagnose pre-event innovations for each validation-selected model.
#'
#' @param fitted Full pre-event model table.
#' @param best One Travel/Model pair for each series.
#' @param lag Ljung-Box lag in months.
#' @return Innovations and Ljung-Box summaries.
diagnose_models <- function(fitted, best, lag = 24L) {
  innovations <- fabletools::augment(fitted) |>
    tibble::as_tibble() |>
    dplyr::rename(Model = .model) |>
    dplyr::inner_join(best |> dplyr::select(Travel, Model), by = c("Travel", "Model"))
  coefficients <- generics::tidy(fitted) |> tibble::as_tibble()
  summaries <- lapply(seq_len(nrow(best)), function(i) {
    travel <- best$Travel[[i]]
    model <- best$Model[[i]]
    residuals <- innovations |>
      dplyr::filter(Travel == travel, Model == model, is.finite(.innov)) |>
      dplyr::pull(.innov)
    # ARIMA adjusts by the AR/MA orders; other models use the unadjusted test.
    dof <- if (model == "ARIMA") {
      sum(coefficients$Travel == travel & coefficients$.model == model &
            grepl("^(ar|ma|sar|sma)[0-9]+$", coefficients$term))
    } else 0L
    if (length(residuals) <= lag || dof >= lag) stop("Invalid Ljung-Box configuration.")
    test <- stats::Box.test(residuals, lag = lag, type = "Ljung-Box", fitdf = dof)
    tibble::tibble(
      Travel = travel, Model = model, N = length(residuals),
      MeanInnovation = mean(residuals), Lag = lag, FitDF = dof,
      Statistic = unname(test$statistic), PValue = test$p.value
    )
  })
  list(innovations = innovations, tests = dplyr::bind_rows(summaries))
}
