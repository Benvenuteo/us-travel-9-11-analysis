#' Save consistently styled figures with Unicode-capable raster text.
#' @param plot A ggplot or patchwork object.
#' @param name File name without the extension.
#' @param directory Output directory.
#' @param width,height Figure dimensions in inches.
save_figure <- function(plot, name, directory, width = 10, height = 7) {
  path <- file.path(directory, paste0(name, ".png"))
  temporary <- tempfile(pattern = paste0(name, "_"), fileext = ".png")
  on.exit(unlink(temporary), add = TRUE)
  grDevices::png(temporary, width = width, height = height, units = "in",
                 res = 160, type = "cairo", bg = "white")
  device <- grDevices::dev.cur()
  tryCatch(print(plot), finally = {
    if (device %in% grDevices::dev.list()) grDevices::dev.off(which = device)
  })
  if (!file.exists(temporary) || file.info(temporary)$size == 0) {
    stop("The graphics device did not produce a non-empty figure: ", path)
  }
  # Publish only fully closed graphics files, including across file systems.
  if (!file.copy(temporary, path, overwrite = TRUE)) {
    stop("Cannot publish the completed figure: ", path)
  }
}

#' Generate all report figures from computed results.
#' @param data Complete dataset.
#' @param train Pre-event data.
#' @param fitted Fitted pre-event models.
#' @param cv Validation results.
#' @param forecasts All post-event forecasts joined to actual values.
#' @param best Selected Travel/Model pairs.
#' @param selected_gaps Post-event gaps for the selected models.
#' @param cutoff Event month.
#' @param directory Figure directory.
make_figures <- function(data, train, fitted, cv, forecasts, best,
                         selected_gaps, cutoff, directory) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  ggplot2::theme_set(ggplot2::theme_minimal(base_size = 11, base_family = "DejaVu Sans") +
    ggplot2::theme(legend.position = "bottom", panel.grid.minor = ggplot2::element_blank(),
                   plot.title.position = "plot", strip.text = ggplot2::element_text(face = "bold")))
  event_date <- as.Date(cutoff)
  actual <- attach_units(data) |>
    dplyr::mutate(Date = as.Date(Month), DisplayValue = Value / PlotDivisor)
  overview <- ggplot2::ggplot(actual, ggplot2::aes(Date, DisplayValue)) +
    ggplot2::geom_line(colour = "#1e3a5f", linewidth = 0.55) +
    ggplot2::geom_vline(xintercept = event_date, colour = "#be123c", linetype = 2) +
    ggplot2::facet_wrap(~SeriesLabel, scales = "free_y", ncol = 1) +
    ggplot2::labs(title = "Transport w USA: miesięczna historia 1990–2004",
      subtitle = "Linia przerywana: wrzesień 2001 r. Każdy panel ma własną jednostkę i skalę.",
      x = NULL, y = NULL)
  save_figure(overview, "01_history", directory, height = 8)

  references <- train |>
    dplyr::filter(Month >= cutoff - 12L) |>
    tibble::as_tibble() |>
    dplyr::group_by(Travel) |>
    dplyr::summarise(Reference = mean(Value), .groups = "drop")
  indexed <- data |>
    tibble::as_tibble() |>
    dplyr::left_join(references, by = "Travel") |>
    dplyr::filter(Month >= cutoff - 24L) |>
    dplyr::mutate(Date = as.Date(Month), Index = 100 * Value / Reference)
  index_plot <- ggplot2::ggplot(indexed, ggplot2::aes(Date, Index, colour = Travel)) +
    ggplot2::geom_line(linewidth = 0.65) +
    ggplot2::geom_vline(xintercept = event_date, linetype = 2, colour = "#be123c") +
    ggplot2::scale_colour_manual(values = c(Air = "#2563eb", Rail = "#d97706", Car = "#059669")) +
    ggplot2::labs(title = "Porównanie zmian względnych",
      subtitle = "Średnia dla każdego szeregu z IX 2000–VIII 2001 = 100; sezonowość pozostaje widoczna.",
      x = NULL, y = "Indeks", colour = "Szereg")
  save_figure(index_plot, "02_indexed", directory, height = 5)

  for (travel in c("Air", "Rail", "Car")) {
    one <- train |> dplyr::filter(Travel == travel)
    title <- as.character(attach_units(tibble::tibble(Travel = travel))$SeriesLabel)
    divisor <- attach_units(tibble::tibble(Travel = travel))$PlotDivisor
    displayed <- one |> dplyr::mutate(Value = Value / divisor)
    seasonal <- ggtime::gg_season(displayed, Value) +
      ggplot2::labs(title = paste0(title, ": sezonowość przed zdarzeniem"), y = NULL, x = NULL)
    save_figure(seasonal, paste0("03_season_", travel), directory, height = 5)
    subseries <- ggtime::gg_subseries(displayed, Value) +
      ggplot2::labs(title = paste0(title, ": podszeregi miesięczne"), y = NULL, x = NULL)
    save_figure(subseries, paste0("04_subseries_", travel), directory, height = 5)
    decomposition <- one |>
      fabletools::model(STL = feasts::STL(Value ~ season(window = "periodic"))) |>
      fabletools::components()
    stl_plot <- ggplot2::autoplot(decomposition) +
      ggplot2::labs(title = paste0("STL przed zdarzeniem: ", travel),
        subtitle = "Dekompozycja addytywna w jednostkach źródłowych", x = NULL)
    save_figure(stl_plot, paste0("05_stl_", travel), directory, height = 7)
    model <- best$Model[best$Travel == travel]
    selected_fit <- fitted |>
      dplyr::filter(Travel == travel) |>
      dplyr::select(Travel, dplyr::all_of(model))
    residual_plot <- ggtime::gg_tsresiduals(selected_fit) +
      patchwork::plot_annotation(title = paste0("Reszty przed zdarzeniem: ", travel, " / ", model))
    save_figure(residual_plot, paste0("06_residuals_", travel), directory, height = 6)
  }

  acf_plot <- train |>
    feasts::ACF(Value, lag_max = 36L) |>
    ggplot2::autoplot() +
    ggplot2::labs(title = "Autokorelacja przed wrześniem 2001 r.",
      subtitle = "Zależność każdego szeregu od jego własnych opóźnień", y = "ACF")
  save_figure(acf_plot, "07_acf", directory, height = 7)

  validation_plot <- ggplot2::ggplot(cv$main, ggplot2::aes(Model, MASE, fill = Model)) +
    ggplot2::geom_col(width = 0.7, show.legend = FALSE) +
    ggplot2::geom_hline(yintercept = 1, linetype = 2, colour = "#64748b") +
    ggplot2::facet_wrap(~Travel, ncol = 1, scales = "free_y") +
    ggplot2::scale_fill_manual(values = c(Mean = "#94a3b8", Naive = "#f59e0b", SNaive = "#10b981",
      Drift = "#f43f5e", ETS = "#2563eb", ARIMA = "#7c3aed")) +
    ggplot2::labs(title = "Walidacja czasowa: horyzonty 1–12 miesięcy",
      subtitle = "Niższe MASE oznacza mniejszy błąd; wszystkie obserwacje pochodzą sprzed zdarzenia.",
      x = NULL, y = "Sezonowe MASE")
  save_figure(validation_plot, "08_validation", directory, height = 8)

  context <- actual |> dplyr::filter(Month >= cutoff - 36L)
  baseline <- forecasts |>
    dplyr::filter(Model %in% c("Mean", "Naive", "SNaive", "Drift")) |>
    attach_units() |>
    dplyr::mutate(Date = as.Date(Month), DisplayForecast = Forecast / PlotDivisor)
  baseline_plot <- ggplot2::ggplot(context, ggplot2::aes(Date, DisplayValue)) +
    ggplot2::geom_line(ggplot2::aes(colour = "Obserwacje"), linewidth = 0.75) +
    ggplot2::geom_line(data = baseline, ggplot2::aes(y = DisplayForecast, colour = Model),
                       linewidth = 0.6) +
    ggplot2::geom_vline(xintercept = event_date, linetype = 2) +
    ggplot2::facet_wrap(~SeriesLabel, scales = "free_y", ncol = 1) +
    ggplot2::scale_colour_manual(values = c(Obserwacje = "#0f172a", Mean = "#64748b",
      Naive = "#f59e0b", SNaive = "#059669", Drift = "#e11d48")) +
    ggplot2::labs(title = "Cztery metody z zadania i wartości rzeczywiste",
      subtitle = "Wszystkie prognozy rozpoczynają się we wrześniu 2001 r.",
      x = NULL, y = NULL, colour = NULL)
  save_figure(baseline_plot, "09_baselines", directory, height = 9)

  selected <- selected_gaps |>
    attach_units() |>
    dplyr::mutate(Date = as.Date(Month), DisplayForecast = Forecast / PlotDivisor)
  selected_plot <- ggplot2::ggplot() +
    ggplot2::geom_ribbon(data = selected,
      ggplot2::aes(Date, ymin = Lower95 / PlotDivisor, ymax = Upper95 / PlotDivisor, fill = "95%")) +
    ggplot2::geom_ribbon(data = selected,
      ggplot2::aes(Date, ymin = Lower80 / PlotDivisor, ymax = Upper80 / PlotDivisor, fill = "80%")) +
    ggplot2::geom_line(data = context,
      ggplot2::aes(Date, DisplayValue, colour = "Obserwacje"), linewidth = 0.65) +
    ggplot2::geom_line(data = selected,
      ggplot2::aes(Date, DisplayForecast, colour = "Prognoza"), linewidth = 0.65) +
    ggplot2::geom_vline(xintercept = event_date, linetype = 2, colour = "#be123c") +
    ggplot2::facet_wrap(~SeriesLabel, scales = "free_y", ncol = 1) +
    ggplot2::scale_fill_manual(values = c(`95%` = "#dbeafe", `80%` = "#93c5fd")) +
    ggplot2::scale_colour_manual(values = c(Obserwacje = "#0f172a", Prognoza = "#2563eb")) +
    ggplot2::labs(title = "Wybrane modele: prognozy i obserwacje po zdarzeniu",
      subtitle = "Model wybierano osobno dla każdego szeregu, wyłącznie w walidacji sprzed zdarzenia.",
      x = NULL, y = NULL, colour = NULL, fill = "Przedział predykcji")
  save_figure(selected_plot, "10_selected_forecasts", directory, height = 9)

  gap_plot <- ggplot2::ggplot(selected, ggplot2::aes(Date, GapPct)) +
    ggplot2::geom_hline(yintercept = 0, colour = "#64748b") +
    ggplot2::geom_line(colour = "#be123c", linewidth = 0.7) +
    ggplot2::geom_point(size = 1, colour = "#be123c") +
    ggplot2::facet_wrap(~Travel, ncol = 1) +
    ggplot2::labs(title = "Miesięczne odchylenie od prognozy",
      subtitle = "100 × (obserwacja − prognoza) / prognoza; ujemna wartość oznacza poziom poniżej prognozy.",
      x = NULL, y = "Odchylenie (%)")
  save_figure(gap_plot, "11_monthly_gaps", directory, height = 8)

  horizon_plot <- cv$by_horizon |>
    dplyr::filter(Horizon %in% c(1L, 3L, 6L, 12L, 24L, 32L)) |>
    ggplot2::ggplot(ggplot2::aes(Horizon, MASE, colour = Model)) +
    ggplot2::geom_line(linewidth = 0.6) + ggplot2::geom_point(size = 1.2) +
    ggplot2::facet_wrap(~Travel, scales = "free_y", ncol = 1) +
    ggplot2::labs(title = "Błąd a horyzont prognozy przed zdarzeniem",
      subtitle = "Przy dłuższych horyzontach dostępnych jest mniej pełnych okien walidacyjnych.",
      x = "Horyzont (miesiące)", y = "Sezonowe MASE", colour = "Model")
  save_figure(horizon_plot, "12_horizon_accuracy", directory, height = 8)
}
