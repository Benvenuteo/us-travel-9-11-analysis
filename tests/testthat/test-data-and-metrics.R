testthat::test_that("the original input has a continuous monthly key", {
  data <- read_travel_data(root_file("data/raw/sept11_travel.csv"))
  testthat::expect_equal(nrow(data), 516L)
  testthat::expect_equal(length(unique(data$Month)), 172L)
  testthat::expect_equal(sort(unique(data$Travel)), c("Air", "Car", "Rail"))
  testthat::expect_false(any(tsibble::has_gaps(data)$.gaps))
})

testthat::test_that("duplicate months and missing values are rejected", {
  original <- readr::read_csv(root_file("data/raw/sept11_travel.csv"), show_col_types = FALSE)
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  duplicated <- dplyr::bind_rows(original, original[1L, ])
  readr::write_csv(duplicated, path)
  testthat::expect_error(read_travel_data(path), "Duplicate months")
  original[[2L]][1L] <- NA_real_
  readr::write_csv(original, path)
  testthat::expect_error(read_travel_data(path), "Missing values")
})

testthat::test_that("seasonal scaling uses lag twelve on the supplied history", {
  data <- tibble::tibble(
    Month = tsibble::yearmonth("1990 Jan") + 0:23,
    Travel = "Air", Value = as.double(1:24)
  ) |> tsibble::as_tsibble(index = Month, key = Travel)
  testthat::expect_equal(seasonal_scales(data)$Scale, 12)
  constant <- data |> dplyr::mutate(Value = 10)
  testthat::expect_error(seasonal_scales(constant), "undefined")
})

testthat::test_that("accuracy measures agree with a hand-calculated example", {
  rows <- tibble::tibble(Travel = "Air", Model = "Example",
                         Actual = c(100, 200), Forecast = c(90, 160), Scale = 10)
  scored <- score_forecasts(rows)
  testthat::expect_equal(scored$MAE, 25)
  testthat::expect_equal(scored$RMSE, sqrt(850))
  testthat::expect_equal(scored$MAPE, 15)
  testthat::expect_equal(scored$MASE, 2.5)
  testthat::expect_equal(scored$Bias, 25)
})

testthat::test_that("cumulative percentage uses sums instead of averaging percentages", {
  forecasts <- tibble::tibble(
    Travel = "Air", Model = "Example",
    Month = tsibble::yearmonth("2001 Sep") + 0:1,
    Actual = c(80, 190), Forecast = c(100, 200),
    Lower95 = c(50, 100), Upper95 = c(150, 300)
  )
  gaps <- calculate_gaps(forecasts)
  totals <- summarise_gaps(gaps, windows = 2L)
  testthat::expect_equal(gaps$GapPct, c(-20, -5))
  testthat::expect_equal(totals$GapTotal, -30)
  testthat::expect_equal(totals$GapPct, -10)
  testthat::expect_false(isTRUE(all.equal(totals$GapPct, mean(gaps$GapPct))))
})
