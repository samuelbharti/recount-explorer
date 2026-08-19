# Load the app's Shiny-free logic layer. The app itself sources R/ from
# app.R; tests source the same files so they exercise the shipped code.
for (f in list.files(
  testthat::test_path("..", "..", "R"),
  pattern = "[.][Rr]$",
  full.names = TRUE
)) {
  source(f)
}

# The 200 gene x 12 sample fixture built by fixtures/make_fixture.R.
fixture_rse <- function() {
  readRDS(testthat::test_path("fixtures", "rse_small.rds"))
}

# The `study` list that modules pass around: the browser module builds this
# same shape at R/mod_study_browser.R.
fixture_study <- function() {
  rse <- fixture_rse()
  list(
    project = "SRP000001",
    organism = "human",
    source = "sra",
    rse = rse,
    log_expr = log_cpm(rse)
  )
}
