test_that("log_cpm normalizes every sample to a million counts", {
  rse <- fixture_rse()
  expr <- log_cpm(rse)

  expect_equal(dim(expr), dim(rse))
  expect_equal(rownames(expr), rownames(rse))
  expect_equal(colnames(expr), colnames(rse))

  # Undo the log and the +1 offset: each column should sum back to 1e6.
  expect_equal(unname(colSums(2^expr - 1)), rep(1e6, ncol(rse)))
})

test_that("log_cpm survives an empty sample without dividing by zero", {
  rse <- fixture_rse()
  SummarizedExperiment::assay(rse, "counts")[, 1] <- 0L

  expr <- log_cpm(rse)

  expect_true(all(is.finite(expr)))
  expect_equal(unname(expr[, 1]), rep(0, nrow(rse)))
})

test_that("gene_choices labels ids with their symbol", {
  rse <- fixture_rse()
  choices <- gene_choices(rse)

  expect_length(choices, nrow(rse))
  expect_equal(unname(choices), rownames(rse))
  expect_equal(names(choices)[1], "GENE1 (ENSG00000001.1)")
})

test_that("gene_choices falls back to the id for missing or blank symbols", {
  rse <- fixture_rse()
  choices <- gene_choices(rse)

  # Fixture gene 3 has an NA symbol, gene 4 an empty one.
  expect_equal(names(choices)[3], "ENSG00000003.1 (ENSG00000003.1)")
  expect_equal(names(choices)[4], "ENSG00000004.1 (ENSG00000004.1)")
})

test_that("metadata_group_choices keeps only usable categorical columns", {
  rse <- fixture_rse()

  expect_equal(
    metadata_group_choices(rse),
    c("tissue", "condition", "replicate_id")
  )
})

test_that("metadata_group_choices respects max_levels", {
  rse <- fixture_rse()

  # replicate_id has one level per sample, so it drops out below 12.
  expect_equal(
    metadata_group_choices(rse, max_levels = 5),
    c(
      "tissue",
      "condition"
    )
  )
})

test_that("metadata_table drops uninformative and list columns", {
  rse <- fixture_rse()
  tbl <- metadata_table(rse)

  expect_s3_class(tbl, "data.frame")
  expect_equal(nrow(tbl), ncol(rse))
  expect_equal(tbl$sample, colnames(rse))
  expect_equal(names(tbl), c("sample", "tissue", "condition", "replicate_id"))

  # batch is constant, all_na is empty, attributes is a list column.
  expect_false(any(c("batch", "all_na", "attributes") %in% names(tbl)))
})

test_that("metadata_table caps the column count", {
  rse <- fixture_rse()
  tbl <- metadata_table(rse, max_cols = 2)

  # The sample column is added on top of the cap.
  expect_equal(ncol(tbl), 3L)
  expect_equal(names(tbl)[1], "sample")
})

test_that("recount3_available reports on the installed namespace", {
  expect_type(recount3_available(), "logical")
  expect_length(recount3_available(), 1L)
})

test_that("recount3_installed answers without loading recount3", {
  # This is the whole point of the function. requireNamespace() answers the
  # same question but loads the package to do it, which costs 5.3 seconds and
  # 98 namespaces on a process that only wants to read a local catalog file.
  expect_type(recount3_installed(), "logical")
  expect_length(recount3_installed(), 1L)

  # Run it in a clean process so an already-loaded recount3 cannot hide a
  # regression. testthat runs with the working directory set to tests/testthat,
  # so the paths handed to the subprocess have to be absolute.
  root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  script <- c(
    sprintf("source('%s/R/logic_recount.R')", root),
    "invisible(recount3_installed())",
    "cat('recount3' %in% loadedNamespaces())"
  )
  f <- withr::local_tempfile(fileext = ".R")
  writeLines(script, f)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(f)),
    stdout = TRUE,
    stderr = TRUE
  ))
  expect_equal(tail(out, 1), "FALSE")
})
