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

  # The group is a factor now, because collapse_levels() decides the level
  # order and the plot builders count levels off it.
  expect_equal(
    as.character(unique(gene_expression_df(study, gene)$group)),
    "all samples"
  )
  expect_equal(
    as.character(unique(gene_expression_df(study, gene, group_by = "")$group)),
    "all samples"
  )
  # A column that is not in colData should not error, it should fall back.
  expect_equal(
    as.character(unique(
      gene_expression_df(study, gene, group_by = "nope")$group
    )),
    "all samples"
  )
})

test_that("gene_expression_df labels missing group values, never drops", {
  study <- fixture_study()
  SummarizedExperiment::colData(study$rse)$tissue[1] <- NA
  gene <- rownames(study$rse)[1]

  df <- gene_expression_df(study, gene, group_by = "tissue")

  expect_equal(nrow(df), ncol(study$rse))
  # Spelled out rather than the literal "NA", so the legend reads as a group
  # rather than as a missing value.
  expect_true("not recorded" %in% as.character(df$group))
})

test_that("collapse_levels leaves a small column alone", {
  x <- c("a", "b", "a", "c")

  out <- collapse_levels(x)

  expect_s3_class(out, "factor")
  expect_setequal(levels(out), c("a", "b", "c"))
})

test_that("collapse_levels keeps the most frequent and lumps the rest", {
  # Ten levels, but "common" dominates. With a cap of 3 only the two most
  # frequent survive and the other eight become one level.
  x <- c(rep("common", 10), rep("second", 5), sprintf("rare%02d", 1:8))

  out <- collapse_levels(x, max_levels = 3)

  expect_equal(nlevels(out), 3L)
  expect_true(all(c("common", "second") %in% levels(out)))
  expect_true("other (8 more)" %in% levels(out))
  expect_equal(sum(out == "other (8 more)"), 8L)
})

test_that("collapse_levels makes missing values their own group", {
  # "not recorded" is usually the group worth seeing, so it must not vanish.
  out <- collapse_levels(c("a", NA, "b", ""))

  expect_true("not recorded" %in% levels(out))
  expect_equal(sum(out == "not recorded"), 2L)
})

test_that("gene_expression_df collapses a grouping column with many levels", {
  study <- fixture_study()
  gene <- rownames(study$rse)[[1]]

  df <- gene_expression_df(study, gene, group_by = "donor", max_levels = 4)

  expect_s3_class(df$group, "factor")
  expect_lte(nlevels(df$group), 4L)
  expect_equal(nrow(df), ncol(study$rse))
})

test_that("run_pca keeps the gene loadings", {
  study <- fixture_study()

  pca <- run_pca(study$log_expr, n_genes = 50, n_pcs = 4)

  expect_equal(dim(pca$loadings), c(50L, 4L))
  expect_true(all(rownames(pca$loadings) %in% rownames(study$rse)))
})

test_that("pca_loadings ranks on absolute loading but keeps the sign", {
  study <- fixture_study()
  pca <- run_pca(study$log_expr, n_genes = 50, n_pcs = 4)

  df <- pca_loadings(pca, n = 10)

  expect_equal(nrow(df), 10L)
  expect_equal(names(df), c("gene_id", "label", "loading", "direction"))
  expect_false(is.unsorted(rev(abs(df$loading))))
  expect_true(all(df$direction %in% c("positive", "negative")))
})

test_that("pca_loadings uses gene symbols when it is given them", {
  study <- fixture_study()
  pca <- run_pca(study$log_expr, n_genes = 50, n_pcs = 4)

  df <- pca_loadings(pca, symbols = gene_symbols(study$rse), n = 5)

  expect_false(identical(df$label, df$gene_id))
  expect_true(all(df$label %in% gene_symbols(study$rse)))
})

test_that("pca_loadings clamps a PC beyond the ones computed", {
  study <- fixture_study()
  pca <- run_pca(study$log_expr, n_genes = 50, n_pcs = 3)

  expect_no_error(pca_loadings(pca, pc = 99))
  expect_equal(nrow(pca_loadings(pca, pc = 99, n = 5)), 5L)
})
