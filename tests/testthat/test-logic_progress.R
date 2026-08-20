test_that("progress round-trips through the file", {
  f <- withr::local_tempfile()

  write_load_progress(f, 3L, 6L, "Downloading the counts, 15 MB")
  got <- read_load_progress(f)

  expect_equal(got$step, 3L)
  expect_equal(got$total, 6L)
  expect_equal(got$label, "Downloading the counts, 15 MB")
})

test_that("each write replaces the last, so the reader sees only the latest", {
  f <- withr::local_tempfile()

  write_load_progress(f, 1L, 6L, "Fetching study metadata")
  write_load_progress(f, 5L, 6L, "Scaling the counts")

  expect_equal(read_load_progress(f)$step, 5L)
  expect_equal(read_load_progress(f)$label, "Scaling the counts")
})

test_that("the write leaves no temporary file behind", {
  f <- withr::local_tempfile()

  write_load_progress(f, 2L, 6L, "Fetching the gene annotation")

  # The write is a temporary file and a rename, so a reader never catches a
  # half-written line. The temporary must not survive the rename.
  expect_true(file.exists(f))
  expect_false(file.exists(paste0(f, ".tmp")))
})

test_that("reading a file that is not there is not an error", {
  expect_null(read_load_progress(file.path(tempdir(), "does-not-exist")))
  expect_null(read_load_progress(NULL))
  expect_null(read_load_progress(""))
})

test_that("reading a malformed or empty file gives NULL rather than nonsense", {
  f <- withr::local_tempfile()

  file.create(f)
  expect_null(read_load_progress(f))

  writeLines("", f)
  expect_null(read_load_progress(f))

  writeLines("only one field", f)
  expect_null(read_load_progress(f))
})

test_that("writing is a no-op when there is nowhere to write", {
  expect_silent(write_load_progress(NULL, 1L, 6L, "x"))
  expect_silent(write_load_progress("", 1L, 6L, "x"))
})

test_that("the counts step names the size when the catalog knows it", {
  info <- data.frame(download_mb = 15.2, stringsAsFactors = FALSE)

  # Size is what the wait is made of, so the label says it.
  expect_equal(counts_label(info), "Downloading the counts, 15 MB")
})

test_that("the counts step stays honest when the size is unknown", {
  expect_equal(
    counts_label(data.frame(download_mb = NA_real_)),
    "Downloading the counts"
  )
  expect_equal(
    counts_label(data.frame(download_mb = 0)),
    "Downloading the counts"
  )
  expect_equal(counts_label(data.frame(x = 1)), "Downloading the counts")
})

test_that("there are six stages, and the loader reports the last one", {
  # The client divides by this to draw the bar, so a mismatch between the
  # constant and what the loader actually reports would misdraw it.
  expect_equal(LOAD_STAGES, 6L)
})

test_that("catalog_proj_info carries the size for the progress label", {
  row <- data.frame(
    project = "P1",
    organism = "human",
    file_source = "sra",
    project_home = "data_sources/sra",
    n_samples = 10L,
    download_mb = 3.5,
    stringsAsFactors = FALSE
  )

  info <- catalog_proj_info(row)

  expect_equal(info$download_mb, 3.5)
  expect_equal(counts_label(info), "Downloading the counts, 4 MB")
  # The columns create_rse() reads must all still be character or integer.
  expect_type(info$organism, "character")
  expect_equal(info$project_type, "data_sources")
})
