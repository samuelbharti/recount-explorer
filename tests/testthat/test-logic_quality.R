test_that("qc_metrics returns one row per sample per usable metric", {
  rse <- fixture_rse()

  df <- qc_metrics(rse)

  expect_true(all(c("sample", "metric", "value", "group") %in% names(df)))
  expect_equal(nrow(df), ncol(rse) * nlevels(df$metric))
  expect_true(all(is.finite(df$value)))
  # No grouping was asked for, so every sample lands in one group.
  expect_equal(nlevels(df$group), 1L)
})

test_that("qc_metrics drops the zero-filled duplicate columns recount3 ships", {
  rse <- fixture_rse()
  cd <- as.data.frame(SummarizedExperiment::colData(rse))
  duplicate <- "recount_qc.star.uniquely_mapped_reads_..2"

  # The fixture carries the duplicate, so this test proves the filter runs
  # rather than passing because the column was never there.
  expect_true(duplicate %in% names(cd))
  expect_true(all(cd[[duplicate]] == 0))

  expect_false(duplicate %in% usable_metric_columns(cd, c(dup = duplicate)))
  expect_length(usable_metric_columns(cd, c(dup = duplicate)), 0L)
})

test_that("qc_metrics carries the grouping column through", {
  rse <- fixture_rse()

  df <- qc_metrics(rse, group_by = "tissue")

  expect_setequal(as.character(unique(df$group)), c("liver", "brain", "muscle"))
})

test_that("qc_metrics returns NULL when the study has no quality metrics", {
  rse <- fixture_rse()
  SummarizedExperiment::colData(rse) <-
    SummarizedExperiment::colData(rse)[, c("tissue", "condition")]

  expect_null(qc_metrics(rse))
})

test_that("flag_outliers uses the 1.5 IQR rule within each metric", {
  df <- data.frame(
    metric = rep(c("a", "b"), each = 6),
    # One obvious outlier in "a", none in "b".
    value = c(1, 2, 3, 4, 5, 500, 10, 11, 12, 13, 14, 15)
  )

  flagged <- flag_outliers(df)

  expect_equal(sum(flagged[df$metric == "a"]), 1L)
  expect_equal(sum(flagged[df$metric == "b"]), 0L)
  expect_true(flagged[6])
})

test_that("biotype shares add up to 100 percent for every sample", {
  rse <- fixture_rse()

  df <- biotype_composition(rse, top_n = 20)

  totals <- as.numeric(tapply(df$share, df$sample, sum))
  expect_equal(totals, rep(100, ncol(rse)), tolerance = 1e-8)
})

test_that("biotype_composition lumps the tail once past top_n", {
  rse <- fixture_rse()

  df <- biotype_composition(rse, top_n = 4)

  expect_equal(nlevels(df$biotype), 5L)
  expect_match(levels(df$biotype)[5], "^other \\([0-9]+ more\\)$")
  # Lumping must not lose reads.
  totals <- as.numeric(tapply(df$share, df$sample, sum))
  expect_equal(totals, rep(100, ncol(rse)), tolerance = 1e-8)
})

test_that("biotype_composition returns NULL without a gene_type column", {
  rse <- fixture_rse()
  rd <- SummarizedExperiment::rowData(rse)
  SummarizedExperiment::rowData(rse) <- rd[, setdiff(names(rd), "gene_type")]

  expect_null(biotype_composition(rse))
})

test_that("sex_signal reads both chromosome percentages", {
  rse <- fixture_rse()

  df <- sex_signal(rse)

  expect_equal(nrow(df), ncol(rse))
  expect_setequal(names(df), c("sample", "chrx", "chry"))
  # The fixture is built as two clouds, which is what the plot exists to show.
  expect_equal(sum(df$chry > 0.3), 6L)
})

test_that("sex_signal returns NULL when a chromosome column is missing", {
  rse <- fixture_rse()
  cd <- SummarizedExperiment::colData(rse)
  SummarizedExperiment::colData(rse) <-
    cd[, setdiff(names(cd), "recount_qc.aligned_reads..chry")]

  expect_null(sex_signal(rse))
})

test_that("expression_quantiles gives a rising five-number summary per sample", {
  study <- fixture_study()

  df <- expression_quantiles(study$log_expr)

  expect_equal(nrow(df), ncol(study$rse))
  rising <- df$ymin <= df$lower &
    df$lower <= df$middle &
    df$middle <= df$upper &
    df$upper <= df$ymax
  expect_true(all(rising))
})

test_that("expression_quantiles orders samples by median", {
  study <- fixture_study()

  df <- expression_quantiles(study$log_expr)

  medians <- df$middle[order(match(df$sample, levels(df$sample)))]
  expect_false(is.unsorted(medians))
})

test_that("sample_correlation is symmetric with a unit diagonal", {
  study <- fixture_study()

  m <- sample_correlation(study$log_expr, n_genes = 50)

  expect_equal(dim(m), c(ncol(study$rse), ncol(study$rse)))
  expect_equal(diag(m), rep(1, ncol(study$rse)), ignore_attr = TRUE)
  expect_equal(m, t(m), ignore_attr = TRUE)
  # Clustering reorders, so the same samples must still all be present.
  expect_setequal(colnames(m), colnames(study$rse))
})

test_that("sample_correlation refuses fewer than three samples", {
  study <- fixture_study()

  expect_null(sample_correlation(study$log_expr[, 1:2, drop = FALSE]))
})

test_that("correlation_long gives one row per cell", {
  study <- fixture_study()
  m <- sample_correlation(study$log_expr, n_genes = 50)

  df <- correlation_long(m)

  expect_equal(nrow(df), ncol(m)^2)
  expect_equal(nlevels(df$row), ncol(m))
  expect_true(all(is.finite(df$correlation)))
})
