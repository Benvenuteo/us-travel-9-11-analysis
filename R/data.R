#' Read, validate and reshape the monthly travel dataset.
#'
#' @param path Path to the original-unit CSV file.
#' @return A monthly tsibble keyed by Travel, with positive numeric Value.
read_travel_data <- function(path) {
  if (!file.exists(path)) stop("Input CSV does not exist: ", path)
  expected_names <- c("Month", "Air RPM (000s)", "Rail PM", "VMT (billions)")
  wide <- readr::read_csv(
    path, col_types = readr::cols(.default = readr::col_double(),
                                Month = readr::col_date("%Y-%m-%d")),
    show_col_types = FALSE
  )
  if (!identical(names(wide), expected_names)) stop("Unexpected CSV columns.")
  if (nrow(readr::problems(wide)) > 0L) stop("CSV parsing problems detected.")
  if (anyNA(wide)) stop("Missing values require an explicit data decision.")
  if (anyDuplicated(wide$Month)) stop("Duplicate months detected.")
  if (any(lubridate::day(wide$Month) != 1L)) stop("Dates must mark month starts.")
  numeric_values <- as.matrix(wide[-1L])
  if (any(!is.finite(numeric_values)) || any(numeric_values <= 0)) {
    stop("All travel values must be finite and positive.")
  }
  wide <- wide |>
    dplyr::arrange(Month) |>
    dplyr::rename(Air = `Air RPM (000s)`, Rail = `Rail PM`, Car = `VMT (billions)`) |>
    dplyr::mutate(Month = tsibble::yearmonth(Month))
  expected_months <- seq(min(wide$Month), max(wide$Month), by = 1)
  if (!identical(as.character(wide$Month), as.character(expected_months))) {
    stop("Missing or irregular calendar months detected.")
  }
  wide |>
    tidyr::pivot_longer(-Month, names_to = "Travel", values_to = "Value") |>
    tsibble::as_tsibble(index = Month, key = Travel)
}

#' Compute seasonal scaling denominators using training observations only.
#'
#' @param history Monthly training tsibble.
#' @param period Seasonal period, normally 12 months.
#' @return One strictly positive seasonal absolute-error scale per series.
seasonal_scales <- function(history, period = 12L) {
  scales <- history |>
    tibble::as_tibble() |>
    dplyr::group_by(Travel) |>
    dplyr::arrange(Month, .by_group = TRUE) |>
    dplyr::summarise(
      Scale = mean(abs(Value - dplyr::lag(Value, period)), na.rm = TRUE),
      .groups = "drop"
    )
  if (any(!is.finite(scales$Scale) | scales$Scale <= 0)) {
    stop("Seasonal MASE is undefined for a constant or short training series.")
  }
  scales
}

#' Attach human-readable units and convert values for plotting only.
#'
#' @param data A data frame with a Travel column.
#' @return The same rows with PlotDivisor and SeriesLabel columns.
attach_units <- function(data) {
  data |>
    dplyr::left_join(tibble::tribble(
      ~Travel, ~PlotDivisor, ~SeriesLabel,
      "Air", 1e6, "Lotnictwo — mld pasażerom mil",
      "Rail", 1e6, "Kolej — mln pasażerom mil",
      "Car", 1, "Drogi — mld mil pojazdów"
    ), by = "Travel") |>
    dplyr::mutate(SeriesLabel = factor(SeriesLabel, levels = c(
      "Lotnictwo — mld pasażerom mil", "Kolej — mln pasażerom mil",
      "Drogi — mld mil pojazdów"
    )))
}
