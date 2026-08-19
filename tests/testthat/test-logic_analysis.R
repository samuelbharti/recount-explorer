test_that("row_variances matches apply(mat, 1, var)", {
  set.seed(1)
  mat <- matrix(rnorm(50), nrow = 10)

  expect_equal(row_variances(mat), apply(mat, 1, stats::var))
})

test_that("row_variances does not divide by zero on a single column", {
  mat <- matrix(c(1, 2, 3), ncol = 1)

  expect_equal(row_variances(mat), c(0, 0, 0))
})

test_that("top_variable_genes returns the most variable rows first", {
  rse <- fixture_rse()
  expr <- log_cpm(rse)

  idx <- top_variable_genes(expr, n = 5)

  expect_length(idx, 5L)
  # The fixture spikes genes 1 to 5 in half the samples, so they should win.
  expect_setequal(idx, 1:5)
})

test_that("top_variable_genes never asks for more rows than exist", {
  mat <- matrix(rnorm(30), nrow = 3)

  expect_length(top_variable_genes(mat, n = 500), 3L)
})

test_that("run_pca returns sample scores and variance explained", {
  study <- fixture_study()

  pca <- run_pca(study$log_expr, n_genes = 50, n_pcs = 4)

  expect_equal(nrow(pca$scores), ncol(study$rse))
  expect_equal(rownames(pca$scores), colnames(study$rse))
  expect_equal(ncol(pca$scores), 4L)
  expect_length(pca$var_explained, 4L)
  expect_true(all(pca$var_explained >= 0))
  expect_lte(sum(pca$var_explained), 1)
  # Variance explained is monotonically decreasing across components.
  expect_false(is.unsorted(rev(pca$var_explained)))
})

test_that("run_pca caps n_pcs at the number of available components", {
  study <- fixture_study()

  pca <- run_pca(study$log_expr, n_genes = 50, n_pcs = 100)

  expect_lte(ncol(pca$scores), ncol(study$rse))
  expect_equal(length(pca$var_explained), ncol(pca$scores))
})

test_that("sample_qc reports library size and detected genes per sample", {
  rse <- fixture_rse()
  counts <- SummarizedExperiment::assay(rse, "counts")

  qc <- sample_qc(rse)

  expect_equal(nrow(qc), ncol(rse))
  expect_equal(qc$sample, colnames(rse))
  expect_equal(unname(qc$library_size), unname(colSums(counts)))
  expect_equal(unname(qc$detected_genes), unname(colSums(counts > 0)))
})

test_that("gene_expression_df splits expression by a metadata column", {
  study <- fixture_study()
  gene <- rownames(study$rse)[1]

  df <- gene_expression_df(study, gene, group_by = "tissue")

  expect_equal(nrow(df), ncol(study$rse))
  expect_equal(df$sample, colnames(study$rse))
  expect_equal(df$expression, unname(study$log_expr[gene, ]))
  expect_setequal(unique(df$group), c("liver", "brain", "muscle"))
})

test_that("gene_expression_df falls back to one group when none is given", {
  study <- fixture_study()
  gene <- rownames(study$rse)[1]

  expect_equal(
    unique(gene_expression_df(study, gene)$group),
    "all samples"
  )
  expect_equal(
    unique(gene_expression_df(study, gene, group_by = "")$group),
    "all samples"
  )
  # A column that is not in colData should not error, it should fall back.
  expect_equal(
    unique(gene_expression_df(study, gene, group_by = "nope")$group),
    "all samples"
  )
})

test_that("gene_expression_df labels missing group values, never drops", {
  study <- fixture_study()
  SummarizedExperiment::colData(study$rse)$tissue[1] <- NA
  gene <- rownames(study$rse)[1]

  df <- gene_expression_df(study, gene, group_by = "tissue")

  expect_equal(nrow(df), ncol(study$rse))
  expect_true("NA" %in% df$group)
})
