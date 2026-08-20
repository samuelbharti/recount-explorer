limits_row <- function(n_samples, organism = "human", download_mb = NA_real_) {
  data.frame(
    uid = paste0(organism, "/sra/P1"),
    project = "P1",
    organism = organism,
    file_source = "sra",
    project_home = "data_sources/sra",
    n_samples = as.integer(n_samples),
    download_mb = as.numeric(download_mb),
    study_title = "T",
    study_abstract = "A",
    stringsAsFactors = FALSE
  )
}

test_that("the memory estimate matches what a real study occupies", {
  # Measured on ERP112751: 63,856 genes by 100 samples took 194.2 MB in R,
  # 137.5 for the RangedSummarizedExperiment plus 56.7 for the log2 CPM matrix.
  # If this drifts, the cap stops meaning what it says.
  expect_equal(estimated_memory_mb(100, "human"), 194.2, tolerance = 0.01)

  # Mouse has fewer genes, so the same sample count costs less.
  expect_lt(
    estimated_memory_mb(100, "mouse"),
    estimated_memory_mb(100, "human")
  )
})

test_that("the memory estimate is linear in the sample count", {
  expect_equal(
    estimated_memory_mb(200, "human"),
    2 * estimated_memory_mb(100, "human")
  )
})

test_that("an unknown organism falls back to the larger annotation", {
  # Guessing low would let a study through the cap that should not pass.
  expect_equal(
    estimated_memory_mb(100, "zebrafish"),
    estimated_memory_mb(100, "human")
  )
})

test_that("the download estimate prefers a recorded size", {
  expect_equal(
    study_download_estimate_mb(limits_row(100, download_mb = 42)),
    42
  )
})

test_that("the download estimate falls back to the per-sample rate", {
  # Measured at roughly 100 KB for each sample across eight studies.
  expect_equal(study_download_estimate_mb(limits_row(100)), 10)
  expect_equal(
    study_download_estimate_mb(limits_row(100, download_mb = NA)),
    10
  )
  expect_equal(study_download_estimate_mb(limits_row(100, download_mb = 0)), 10)
})

test_that("the default cap is 500 samples", {
  withr::local_envvar(RECOUNT_EXPLORER_MAX_SAMPLES = NA)

  expect_equal(study_limits()$max_samples, 500)
})

test_that("the environment variable moves the cap", {
  withr::local_envvar(RECOUNT_EXPLORER_MAX_SAMPLES = "5000")

  expect_equal(study_limits()$max_samples, 5000)
})

test_that("a nonsense cap falls back to the default rather than to no cap", {
  for (bad in c("", "abc", "0", "-10")) {
    withr::local_envvar(RECOUNT_EXPLORER_MAX_SAMPLES = bad)
    expect_equal(study_limits()$max_samples, 500)
  }
})

test_that("study_load_block allows anything at or under the cap", {
  expect_null(study_load_block(limits_row(1)))
  expect_null(study_load_block(limits_row(499)))
  expect_null(study_load_block(limits_row(500)))
})

test_that("study_load_block refuses one sample over the cap", {
  blocked <- study_load_block(limits_row(501))

  expect_type(blocked, "list")
  expect_named(blocked, c("reason", "detail"))
})

test_that("the refusal carries the numbers, not just the word large", {
  # A message that says "too large" and stops there tells the reader nothing
  # about what to do next.
  blocked <- study_load_block(limits_row(2931, download_mb = 295.76))

  expect_match(blocked$reason, "2,931", fixed = TRUE)
  expect_match(blocked$reason, "500", fixed = TRUE)
  expect_match(blocked$detail, "296 MB", fixed = TRUE)
  expect_match(blocked$detail, "GB", fixed = TRUE)
  expect_match(blocked$detail, "RECOUNT_EXPLORER_MAX_SAMPLES", fixed = TRUE)
})

test_that("raising the cap unblocks a study", {
  row <- limits_row(2931)
  expect_false(is.null(study_load_block(row)))

  withr::local_envvar(RECOUNT_EXPLORER_MAX_SAMPLES = "5000")
  expect_null(study_load_block(row, study_limits()))
})

test_that("study_load_block refuses anything other than one row", {
  expect_error(study_load_block(rbind(limits_row(1), limits_row(2))))
  expect_error(study_load_block(limits_row(1)[0, ]))
})

test_that("format_size_mb switches to GB where GB reads better", {
  expect_equal(format_size_mb(0.7), "1 MB")
  expect_equal(format_size_mb(296), "296 MB")
  expect_equal(format_size_mb(1024), "1.0 GB")
  expect_equal(format_size_mb(2048), "2.0 GB")
  expect_equal(format_size_mb(NA), "an unknown amount")
})

test_that("format_download_time uses the measured rate, not a link speed", {
  # 1.3 MB/s, measured against the recount3 servers. A nominal 50 Mbit/s would
  # promise "under a minute" for a GTEx tissue that really takes four.
  expect_equal(format_download_time(10), "a few seconds")
  expect_equal(format_download_time(60), "under a minute")
  expect_equal(format_download_time(296), "about 4 minutes")
  expect_equal(format_download_time(1014), "about 13 minutes")
})

test_that("catalog_download_mb fills gaps without touching recorded sizes", {
  df <- rbind(
    limits_row(100, download_mb = 42),
    limits_row(100, download_mb = NA),
    limits_row(50, download_mb = 0)
  )

  mb <- catalog_download_mb(df)

  expect_equal(mb, c(42, 10, 5))
})

test_that("catalog_display puts the size between the count and the title", {
  df <- finalize_catalog(limits_row(100, download_mb = 42), origin = "test")

  out <- catalog_display(df)

  expect_equal(
    names(out),
    c(
      "project",
      "organism",
      "file_source",
      "n_samples",
      "download",
      "study_title"
    )
  )
  expect_equal(out$download, "42 MB")
})

test_that("preset_range turns a bucket into bounds", {
  expect_equal(preset_range("any"), list(min = NULL, max = NULL))
  expect_equal(preset_range(NULL), list(min = NULL, max = NULL))
  expect_equal(preset_range("10-50"), list(min = 10, max = 50))
  expect_equal(preset_range("200-Inf"), list(min = 200, max = NULL))
})

test_that("the stored schema carries download_mb", {
  df <- finalize_catalog(limits_row(10, download_mb = 1.5), origin = "test")

  expect_true("download_mb" %in% CATALOG_COLUMNS)
  expect_type(df$download_mb, "double")
  expect_equal(df$download_mb, 1.5)
  expect_true(valid_catalog(df))
})

test_that("a catalog built before the size column still finalizes", {
  row <- limits_row(10)
  row$download_mb <- NULL

  df <- finalize_catalog(row, origin = "test")

  expect_true("download_mb" %in% names(df))
  expect_true(is.na(df$download_mb))
})
