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

  # Named now, and sorted by group count. replicate_id is gone because one
  # level per sample is an identifier, not a grouping.
  expect_equal(
    unname(metadata_group_choices(rse)),
    c("condition", "tissue", "donor")
  )
})

test_that("metadata_group_choices respects max_levels", {
  rse <- fixture_rse()

  # donor has 10 levels, so it drops out below that.
  expect_equal(
    unname(metadata_group_choices(rse, max_levels = 5)),
    c("condition", "tissue")
  )
})

test_that("metadata_table shows a short chosen set, not everything", {
  rse <- fixture_rse()
  tbl <- metadata_table(rse)

  expect_s3_class(tbl, "data.frame")
  expect_equal(nrow(tbl), ncol(rse))
  expect_equal(tbl$sample, colnames(rse))
  # Short enough to fit without a horizontal scrollbar, which is the point.
  expect_lte(ncol(tbl), 8L)
  expect_equal(names(tbl)[1], "sample")

  # batch is constant and all_na is empty, so neither is ever offered.
  expect_false(any(c("batch", "all_na") %in% names(tbl)))
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

test_that("metadata_columns keeps the default short, leading with sample", {
  rse <- fixture_rse()

  cols <- metadata_columns(rse)

  expect_lte(length(cols$default), 8L)
  expect_equal(cols$default[[1]], "sample")
  expect_true(all(cols$default %in% cols$all))
  # The all-NA and constant columns carry nothing, so neither list offers them.
  expect_false("all_na" %in% cols$all)
  expect_false("batch" %in% cols$all)
})

test_that("metadata_columns prefers quality metrics over other columns", {
  rse <- fixture_rse()

  cols <- metadata_columns(rse)

  expect_true(any(unname(QC_METRICS) %in% cols$default))
})

test_that("metadata_table shows the columns asked for and nothing else", {
  rse <- fixture_rse()

  df <- metadata_table(rse, c("tissue", "condition"))

  expect_equal(names(df), c("sample", "tissue", "condition"))
  expect_equal(nrow(df), ncol(rse))
  # An unknown column is ignored rather than erroring, because the picker can
  # still hold a column from a study that has since been unloaded.
  expect_equal(
    names(metadata_table(rse, c("tissue", "nope"))),
    c("sample", "tissue")
  )
})

test_that("metadata_table flattens list columns instead of breaking on them", {
  rse <- fixture_rse()

  df <- metadata_table(rse, "attributes")

  expect_type(df$attributes, "character")
  expect_match(df$attributes[[1]], "key1")
})

test_that("sample_detail returns every recorded field for one sample", {
  rse <- fixture_rse()
  sample <- colnames(rse)[[2]]

  df <- sample_detail(rse, sample)

  expect_equal(names(df), c("field", "value"))
  expect_true("tissue" %in% df$field)
  expect_equal(df$value[df$field == "tissue"], "liver")
  # Fields with nothing in them are dropped, so the detail view is not padded
  # with rows that say nothing.
  expect_false("all_na" %in% df$field)
})

test_that("sample_detail returns NULL for a sample that is not there", {
  expect_null(sample_detail(fixture_rse(), "no-such-sample"))
})

test_that("metadata_group_choices labels each column with its group count", {
  rse <- fixture_rse()

  choices <- metadata_group_choices(rse)

  expect_true("tissue" %in% choices)
  expect_match(
    names(choices)[choices == "tissue"],
    "tissue (3 groups)",
    fixed = TRUE
  )
  # Sorted by count, so the two-level columns come first.
  counts <- as.integer(sub("^.*[(]([0-9]+) groups[)]$", "\\1", names(choices)))
  expect_false(is.unsorted(counts))
})

test_that("metadata_group_choices drops identifiers and constants", {
  rse <- fixture_rse()

  choices <- metadata_group_choices(rse)

  # One distinct value per sample: grouping by it makes one box per sample.
  expect_false("replicate_id" %in% choices)
  expect_false("batch" %in% choices)
  expect_false("all_na" %in% choices)
  # But a column that merely has many levels is still a real grouping.
  expect_true("donor" %in% choices)
})

test_that("gene_symbols falls back to the id where no symbol is recorded", {
  rse <- fixture_rse()

  symbols <- gene_symbols(rse)

  expect_equal(names(symbols), rownames(rse))
  # The fixture blanks the symbol on genes 3 and 4.
  expect_equal(unname(symbols[3]), rownames(rse)[3])
  expect_equal(unname(symbols[4]), rownames(rse)[4])
  expect_equal(unname(symbols[1]), "GENE1")
})
