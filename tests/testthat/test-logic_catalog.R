# A small stand-in for the shipped catalog. Built here rather than saved as a
# fixture so the schema assertions fail loudly if CATALOG_COLUMNS changes.
fake_catalog <- function() {
  df <- data.frame(
    project = c("SRP000001", "SRP000002", "BRCA", "SRP000001"),
    organism = c("human", "human", "human", "mouse"),
    file_source = c("sra", "sra", "tcga", "sra"),
    project_home = c(
      "data_sources/sra",
      "data_sources/sra",
      "data_sources/tcga",
      "data_sources/sra"
    ),
    n_samples = c(12L, 400L, 1200L, 8L),
    study_title = c("First study", "Second study", "TCGA BRCA", "Mouse study"),
    study_abstract = c("Abstract one", "", "Cancer atlas", "Abstract four"),
    stringsAsFactors = FALSE
  )
  finalize_catalog(df, origin = "test")
}

test_that("catalog_uid separates the same accession across organisms", {
  df <- fake_catalog()

  # SRP000001 exists for both human and mouse in the fixture, so the accession
  # on its own is not a key.
  expect_false(any(duplicated(df$uid)))
  expect_equal(sum(df$project == "SRP000001"), 2L)
  expect_equal(
    catalog_uid(data.frame(
      organism = "human",
      file_source = "sra",
      project = "SRP000001"
    )),
    "human/sra/SRP000001"
  )
})

test_that("finalize_catalog turns a table of counts into an integer column", {
  # available_projects() returns n_samples as a subsetted table, not a vector.
  # A table carries names and serializes badly, so this coercion is required.
  counts <- table(c("a", "a", "b"))
  df <- data.frame(
    project = c("P1", "P2"),
    organism = "human",
    file_source = "sra",
    project_home = "data_sources/sra",
    study_title = "T",
    study_abstract = "A",
    stringsAsFactors = FALSE
  )
  df$n_samples <- counts[c("a", "b")]
  expect_s3_class(df$n_samples, "table")

  out <- finalize_catalog(df)

  expect_type(out$n_samples, "integer")
  expect_null(names(out$n_samples))
  expect_equal(unname(out$n_samples), c(2L, 1L))
})

test_that("finalize_catalog produces the storage schema and provenance", {
  df <- fake_catalog()

  expect_equal(names(df), CATALOG_COLUMNS)
  expect_true(valid_catalog(df))

  meta <- catalog_meta(df)
  expect_equal(meta$schema_version, CATALOG_SCHEMA_VERSION)
  expect_equal(meta$n_projects, nrow(df))
  expect_equal(meta$origin, "test")
  expect_s3_class(meta$built_at, "POSIXct")
})

test_that("row subsetting keeps provenance but column subsetting drops it", {
  df <- fake_catalog()

  # Verified against R 4.6.1: [.data.frame carries a custom attribute through
  # a row subset and through a reorder, but not through a column subset.
  # renderDT() selects columns, so the table it renders loses provenance.
  rows <- df[1:2, ]
  cols <- df[, c("project", "n_samples"), drop = FALSE]

  expect_equal(catalog_meta(rows)$origin, "test")
  expect_true(valid_catalog(rows))

  expect_null(attr(cols, "catalog_meta", exact = TRUE))
  expect_equal(catalog_meta(cols)$origin, "unknown")
  expect_identical(catalog_meta(cols)$schema_version, NA_integer_)
  expect_false(valid_catalog(cols))
})

test_that("catalog_meta reports the row count when provenance is gone", {
  df <- fake_catalog()
  cols <- df[, "project", drop = FALSE]

  expect_equal(catalog_meta(cols)$n_projects, nrow(df))
  expect_equal(catalog_meta("not a data frame")$n_projects, NA_integer_)
})

test_that("valid_catalog rejects a missing column or an old schema", {
  df <- fake_catalog()

  expect_true(valid_catalog(df))
  expect_false(valid_catalog(df[, setdiff(CATALOG_COLUMNS, "study_abstract")]))
  expect_false(valid_catalog(df[0, ]))
  expect_false(valid_catalog(NULL))

  stale <- df
  meta <- attr(stale, "catalog_meta")
  meta$schema_version <- CATALOG_SCHEMA_VERSION + 1L
  attr(stale, "catalog_meta") <- meta
  expect_false(valid_catalog(stale))
})

test_that("catalog_proj_info hands create_rse character columns, not factors", {
  # create_rse() reaches match.arg() through annotation_options(), and
  # match.arg() errors on a factor with "'arg' must be NULL or a character
  # vector". Storing organism as a factor would break study loading outright.
  df <- fake_catalog()
  row <- df[df$uid == "human/sra/SRP000001", , drop = FALSE]
  row$organism <- factor(row$organism, levels = c("human", "mouse"))
  row$file_source <- factor(row$file_source)

  info <- catalog_proj_info(row)

  expect_type(info$organism, "character")
  expect_type(info$file_source, "character")
  expect_type(info$project, "character")
  expect_type(info$project_home, "character")
  expect_type(info$n_samples, "integer")
  expect_equal(info$organism, "human")
  expect_equal(info$file_source, "sra")
})

test_that("catalog_proj_info restores the project_type create_rse expects", {
  df <- fake_catalog()
  info <- catalog_proj_info(df[1, , drop = FALSE])

  # project_type is dropped from storage because it is constant, so
  # catalog_proj_info has to put it back.
  expect_equal(info$project_type, "data_sources")
  expect_equal(nrow(info), 1L)
})

test_that("catalog_proj_info refuses anything other than one row", {
  df <- fake_catalog()

  expect_error(catalog_proj_info(df))
  expect_error(catalog_proj_info(df[0, ]))
})

test_that("clean_text collapses whitespace and drops placeholders", {
  expect_equal(clean_text("  a   b  "), "a b")
  expect_equal(clean_text("line\nbreak\there"), "line break here")
  expect_true(is.na(clean_text(NA)))
  expect_true(is.na(clean_text("")))
  expect_true(is.na(clean_text("   ")))
  expect_true(is.na(clean_text("NA")))
  expect_true(is.na(clean_text("n/a")))
  expect_true(is.na(clean_text("NULL")))
  expect_true(is.na(clean_text(character(0))))
})

test_that("clean_text_vec cleans a whole column and keeps its length", {
  x <- c("  a  b ", NA, "NA", "fine")

  out <- clean_text_vec(x)

  expect_length(out, 4L)
  expect_type(out, "character")
  expect_equal(out, c("a b", NA, NA, "fine"))
  expect_null(names(out))
})

test_that("recount3_metadata_url picks the project file by name", {
  skip_if_not_installed("recount3")
  # The one test here that needs the network. locate_url() resolves its
  # project_home argument through project_homes(), which reads an index over
  # HTTP. Skipped on CI so the suite there stays offline, as CONTRIBUTING says.
  skip_on_ci()
  skip_if_offline()

  url <- recount3_metadata_url(
    project = "SRP107565",
    project_home = "data_sources/sra",
    organism = "human"
  )

  # Selected by name rather than by position, so a change to the upstream file
  # order cannot quietly hand us a different file.
  expect_match(url, "sra\\.sra\\.SRP107565\\.MD\\.gz$")
  expect_length(url, 1L)
  expect_null(names(url))
})

test_that("strip_markup removes HTML breaks but keeps scientific notation", {
  expect_equal(strip_markup("one<br>two"), "one two")
  expect_equal(strip_markup("one</br>two"), "one two")
  expect_equal(strip_markup("one<br />two"), "one two")
  expect_equal(strip_markup("one<p/>two"), "one two")
  expect_equal(strip_markup("one<P>two"), "one two")

  # Angle brackets in this data are usually not markup. A general tag strip
  # would destroy both of these, which are real values in the catalog.
  expect_equal(strip_markup("IFN-<gamma>-dependent"), "IFN-<gamma>-dependent")
  expect_equal(strip_markup("B6.129P2-Jundm2<tm2>"), "B6.129P2-Jundm2<tm2>")
})

test_that("strip_markup decodes the entities the metadata contains", {
  expect_equal(strip_markup("Smith &amp; Jones"), "Smith & Jones")
  expect_equal(strip_markup("p &lt; 0.05"), "p < 0.05")
  expect_equal(strip_markup("n &gt; 10"), "n > 10")
  expect_equal(strip_markup("&quot;quoted&quot;"), "\"quoted\"")
  expect_equal(strip_markup("it&#39;s"), "it's")
  expect_equal(strip_markup("a&nbsp;b"), "a b")

  # &amp; is decoded last, so a double-encoded "<" stays visible rather than
  # turning into a bracket that later markup handling would act on.
  expect_equal(strip_markup("&amp;lt;"), "&lt;")
})

test_that("clean_text runs the markup pass before it decides on NA", {
  expect_equal(clean_text("a &amp;  b"), "a & b")
  expect_equal(clean_text("text<br>more"), "text more")
  # An abstract that is nothing but a tag has no content.
  expect_true(is.na(clean_text("<br>")))
  expect_true(is.na(clean_text("<p/>  ")))
})

test_that("mark_utf8 declares an encoding for non-ASCII study text", {
  x <- c("plain ascii", "TGF-ß pathway", NA)

  out <- mark_utf8(x)

  expect_true(all(validUTF8(out[!is.na(out)])))
  # R only keeps the marker on strings that carry non-ASCII bytes. ASCII is
  # unambiguous, so "unknown" on those is correct rather than a gap.
  expect_equal(Encoding(out[2]), "UTF-8")
  expect_equal(out[1], "plain ascii")
  expect_true(is.na(out[3]))
})

test_that("finalize_catalog normalizes study text from every source", {
  df <- data.frame(
    project = c("P1", "P2"),
    organism = "human",
    file_source = "sra",
    project_home = "data_sources/sra",
    n_samples = c(1L, 2L),
    study_title = c("Title<br>here", "  spaced   out  "),
    study_abstract = c("A &amp; B", "keep <gamma> intact"),
    stringsAsFactors = FALSE
  )

  out <- finalize_catalog(df)

  expect_equal(out$study_title, c("Title here", "spaced out"))
  expect_equal(out$study_abstract, c("A & B", "keep <gamma> intact"))
})
