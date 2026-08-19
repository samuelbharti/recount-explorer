search_catalog <- function() {
  df <- data.frame(
    project = c("SRP000001", "SRP000002", "BRCA", "SRP000003"),
    organism = c("human", "human", "human", "mouse"),
    file_source = c("sra", "sra", "tcga", "sra"),
    project_home = c(
      "data_sources/sra",
      "data_sources/sra",
      "data_sources/tcga",
      "data_sources/sra"
    ),
    n_samples = c(10L, 400L, 1200L, 4L),
    study_title = c(
      "Glioblastoma single cell atlas",
      "Liver development",
      "TCGA BRCA: Breast invasive carcinoma",
      "Mouse cortex development"
    ),
    study_abstract = c(
      "We profiled tumour cells.",
      "CRISPR screen in hepatocytes.",
      "Cancer atlas.",
      "Development of the mouse brain."
    ),
    stringsAsFactors = FALSE
  )
  finalize_catalog(df, origin = "test")
}

test_that("search matches the accession, the title and the abstract", {
  df <- search_catalog()

  expect_equal(catalog_search(df, "SRP000002")$project, "SRP000002")
  expect_equal(catalog_search(df, "glioblastoma")$project, "SRP000001")
  # CRISPR appears only in an abstract, never in a title. This is the whole
  # reason the abstract is in the catalog at all.
  expect_equal(catalog_search(df, "crispr")$project, "SRP000002")
})

test_that("search is case insensitive and ignores surrounding space", {
  df <- search_catalog()

  expect_equal(nrow(catalog_search(df, "GLIOBLASTOMA")), 1L)
  expect_equal(nrow(catalog_search(df, "  glioblastoma  ")), 1L)
})

test_that("every word has to match, so more words narrow the result", {
  df <- search_catalog()

  expect_equal(nrow(catalog_search(df, "development")), 2L)
  expect_equal(nrow(catalog_search(df, "development mouse")), 1L)
  expect_equal(nrow(catalog_search(df, "development nonsense")), 0L)
})

test_that("an empty query returns everything", {
  df <- search_catalog()

  expect_equal(nrow(catalog_search(df, "")), nrow(df))
  expect_equal(nrow(catalog_search(df, "   ")), nrow(df))
  expect_equal(nrow(catalog_search(df, NA)), nrow(df))
  expect_equal(nrow(catalog_search(df)), nrow(df))
})

test_that("filters stack with each other and with the query", {
  df <- search_catalog()

  expect_equal(nrow(catalog_search(df, organisms = "mouse")), 1L)
  expect_equal(nrow(catalog_search(df, sources = "tcga")), 1L)
  expect_equal(nrow(catalog_search(df, sources = c("sra", "tcga"))), 4L)
  expect_equal(nrow(catalog_search(df, min_samples = 100)), 2L)
  expect_equal(nrow(catalog_search(df, max_samples = 100)), 2L)
  expect_equal(
    nrow(catalog_search(df, min_samples = 5, max_samples = 500)),
    2L
  )
  expect_equal(
    nrow(catalog_search(df, "development", organisms = "mouse")),
    1L
  )
})

test_that("sorting follows the requested column and direction", {
  df <- search_catalog()

  expect_equal(
    catalog_search(df, sort_by = "n_samples", sort_dir = "desc")$n_samples,
    c(1200L, 400L, 10L, 4L)
  )
  expect_equal(
    catalog_search(df, sort_by = "n_samples", sort_dir = "asc")$n_samples,
    c(4L, 10L, 400L, 1200L)
  )
  expect_equal(
    catalog_search(df, sort_by = "project", sort_dir = "asc")$project[1],
    "BRCA"
  )
})

test_that("an unknown sort column falls back rather than erroring", {
  df <- search_catalog()

  expect_no_error(catalog_search(df, sort_by = "not_a_column"))
  expect_equal(
    catalog_search(df, sort_by = "not_a_column")$n_samples,
    c(1200L, 400L, 10L, 4L)
  )
})

test_that("catalog_page slices and reports the counts the pager needs", {
  df <- search_catalog()

  p <- catalog_page(catalog_search(df), page = 1, page_size = 2)
  expect_equal(nrow(p$rows), 2L)
  expect_equal(p$matched, 4L)
  expect_equal(p$pages, 2L)
  expect_equal(p$from, 1L)
  expect_equal(p$to, 2L)

  p2 <- catalog_page(catalog_search(df), page = 2, page_size = 2)
  expect_equal(p2$from, 3L)
  expect_equal(p2$to, 4L)
})

test_that("catalog_page clamps a page number that is out of range", {
  df <- search_catalog()

  expect_equal(catalog_page(df, page = 999, page_size = 2)$page, 2L)
  expect_equal(catalog_page(df, page = 0, page_size = 2)$page, 1L)
  expect_equal(catalog_page(df, page = -5, page_size = 2)$page, 1L)
})

test_that("catalog_page survives an empty result", {
  df <- search_catalog()
  empty <- catalog_search(df, "nothingmatchesthis")

  p <- catalog_page(empty, page = 1, page_size = 25)

  expect_equal(nrow(p$rows), 0L)
  expect_equal(p$matched, 0L)
  expect_equal(p$pages, 1L)
  expect_equal(p$from, 0L)
  expect_equal(p$to, 0L)
})

test_that("df_to_rows produces one object per row, not parallel arrays", {
  df <- search_catalog()

  rows <- df_to_rows(df[1:2, c("project", "n_samples")])

  # Shiny serializes a data frame column wise. The client needs an array of
  # row objects, so anything sent to it goes through this first.
  expect_type(rows, "list")
  expect_length(rows, 2L)
  expect_null(names(rows))
  expect_equal(rows[[1]]$project, df$project[1])
  expect_equal(rows[[1]]$n_samples, df$n_samples[1])
  expect_setequal(names(rows[[1]]), c("project", "n_samples"))
})

test_that("df_to_rows returns an empty list for an empty frame", {
  df <- search_catalog()

  expect_identical(df_to_rows(df[0, ]), list())
})

test_that("the search text cache returns the same vector for one catalog", {
  df <- search_catalog()

  first <- catalog_haystack(df)
  second <- catalog_haystack(df)

  expect_identical(first, second)
  expect_length(first, nrow(df))
  expect_true(all(first == tolower(first)))
})
