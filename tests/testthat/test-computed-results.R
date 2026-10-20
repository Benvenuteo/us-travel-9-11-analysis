testthat::test_that("validation outcomes precede the event and follow their origins", {
  testthat::skip_if_not(file.exists(root_file("outputs/results/analysis.rds")), "Run the analysis first.")
  result <- readRDS(root_file("outputs/results/analysis.rds"))
  validation <- result$validation_predictions
  testthat::expect_true(all(validation$Month < result$config$cutoff))
  testthat::expect_true(all(validation$Month > validation$Origin))
  testthat::expect_equal(nrow(result$folds), 23L)
  testthat::expect_equal(sum(result$folds$ForecastMonths == 32L), 17L)
  main_counts <- validation |> dplyr::filter(Horizon <= 12L) |>
    dplyr::count(Travel, Model)
  testthat::expect_true(all(main_counts$n == 23L * 12L))
})

testthat::test_that("selected models minimise the pre-specified validation score", {
  testthat::skip_if_not(file.exists(root_file("outputs/results/analysis.rds")))
  result <- readRDS(root_file("outputs/results/analysis.rds"))
  expected <- result$cv_accuracy |>
    dplyr::group_by(Travel) |>
    dplyr::arrange(MASE, RMSE, Model, .by_group = TRUE) |>
    dplyr::slice_head(n = 1L) |>
    dplyr::ungroup() |>
    dplyr::select(Travel, Model)
  actual <- result$best |> dplyr::select(Travel, Model)
  testthat::expect_equal(actual, expected)
})

testthat::test_that("post-event forecasts have aligned dates and ordered intervals", {
  testthat::skip_if_not(file.exists(root_file("outputs/results/analysis.rds")))
  result <- readRDS(root_file("outputs/results/analysis.rds"))
  predictions <- result$forecasts
  testthat::expect_equal(nrow(predictions), 3L * 6L * 32L)
  testthat::expect_equal(nrow(result$selected_gaps), 3L * 32L)
  testthat::expect_false(anyNA(predictions))
  testthat::expect_true(all(predictions$Month >= result$config$cutoff))
  testthat::expect_true(all(predictions$Lower95 <= predictions$Lower80))
  testthat::expect_true(all(predictions$Upper80 <= predictions$Upper95))
})
