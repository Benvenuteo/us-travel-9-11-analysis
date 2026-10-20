# Install the project dependencies once, separately from the analysis itself.
if (getRversion() < "4.4.0") stop("R >= 4.4.0 is required by the plotting stack.")
options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 600)
# mixtime links against tzdb headers; older preinstalled headers need updating.
if (!requireNamespace("tzdb", quietly = TRUE) ||
    utils::packageVersion("tzdb") < "0.5.0") install.packages("tzdb")
packages <- c("fpp3", "ggtime", "readr", "jsonlite", "digest", "renv",
              "knitr", "rmarkdown", "testthat", "patchwork", "urca")
missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) install.packages(missing_packages)
message("Dependencies ready. Run Rscript scripts/run_analysis.R from the project root.")
