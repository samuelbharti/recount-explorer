# Recount Explorer is an app, not a package, so there is no test_check() here.
# Run the suite from the repo root with testthat::test_dir on tests/testthat.
library(testthat)

test_dir("testthat", stop_on_failure = TRUE)
