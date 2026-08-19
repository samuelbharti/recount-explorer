test_that("flatten_coldata collapses list columns so write.csv survives", {
  rse <- fixture_rse()

  flat <- flatten_coldata(rse)

  expect_equal(nrow(flat), ncol(rse))
  expect_equal(flat$sample, colnames(rse))
  expect_false(any(vapply(flat, is.list, logical(1))))
  expect_equal(flat$attributes[1], "key1; value1")
})

test_that("flatten_coldata keeps every metadata column", {
  rse <- fixture_rse()
  cd <- SummarizedExperiment::colData(rse)

  # Unlike metadata_table(), the export keeps constant and empty columns too.
  expect_equal(names(flatten_coldata(rse)), c("sample", names(cd)))
})

test_that("expression_export_df puts gene ids in the first column", {
  study <- fixture_study()

  df <- expression_export_df(study)

  expect_equal(nrow(df), nrow(study$rse))
  expect_equal(ncol(df), ncol(study$rse) + 1L)
  expect_equal(names(df)[1], "gene_id")
  expect_equal(df$gene_id, rownames(study$rse))
})

test_that("the reproduction script is syntactically valid R", {
  study <- fixture_study()

  script <- build_reproduction_script(study)

  expect_type(script, "character")
  expect_length(script, 1L)
  expect_silent(parse(text = script))
})

test_that("the reproduction script records the study provenance", {
  study <- fixture_study()

  script <- build_reproduction_script(study)

  expect_match(script, "SRP000001", fixed = TRUE)
  expect_match(script, 'available_projects(organism = "human")', fixed = TRUE)
  expect_match(script, "10.1186/s13059-021-02533-6", fixed = TRUE)
})

test_that("the reproduction script stays valid with gene and PCA state", {
  study <- fixture_study()
  gene <- rownames(study$rse)[1]

  script <- build_reproduction_script(
    study,
    gene_state = list(
      gene = gene,
      gene_label = "GENE1 (ENSG00000001.1)",
      group_by = "tissue",
      geom = "violin"
    ),
    pca_state = list(n_genes = 250, color_by = "condition")
  )

  expect_silent(parse(text = script))
  expect_match(script, "geom_violin", fixed = TRUE)
  expect_match(
    script,
    "head(order(vars, decreasing = TRUE), 250)",
    fixed = TRUE
  )
  expect_match(script, 'colData(rse)[["condition"]]', fixed = TRUE)
  expect_match(script, 'colData(rse)[["tissue"]]', fixed = TRUE)
})

test_that("the reproduction script stays valid without grouping", {
  study <- fixture_study()
  gene <- rownames(study$rse)[1]

  script <- build_reproduction_script(
    study,
    gene_state = list(
      gene = gene,
      gene_label = "GENE1",
      group_by = "",
      geom = "boxplot"
    ),
    pca_state = list(n_genes = 500, color_by = "")
  )

  expect_silent(parse(text = script))
  expect_match(script, "geom_boxplot", fixed = TRUE)
  expect_match(script, 'group = "all samples"', fixed = TRUE)
  expect_match(script, 'pca_df$color <- "sample"', fixed = TRUE)
})

test_that("an unset gene leaves the gene block out entirely", {
  study <- fixture_study()

  script <- build_reproduction_script(
    study,
    gene_state = list(gene = "", gene_label = "", group_by = "", geom = "box")
  )

  expect_silent(parse(text = script))
  expect_no_match(script, "gene_df", fixed = TRUE)
})
