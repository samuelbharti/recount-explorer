test_that("the palette differs between light and dark", {
  light <- plot_palette(FALSE)
  dark <- plot_palette(TRUE)

  expect_false(identical(light$bg, dark$bg))
  expect_false(identical(light$fg, dark$fg))
  # A dark background with dark text would be worse than not theming at all.
  expect_equal(light$bg, "#ffffff")
  expect_true(startsWith(dark$bg, "#1"))
})

test_that("every builder paints its background for the mode it is given", {
  qc <- data.frame(library_size = c(1e6, 2e6), detected_genes = c(100, 200))
  df <- data.frame(
    group = c("a", "b"),
    expression = c(1, 2),
    sample = c("s1", "s2")
  )
  scores <- data.frame(PC1 = c(1, 2), PC2 = c(2, 1), color = c("a", "b"))

  builders <- list(
    function(d) plot_qc(qc, dark = d),
    function(d) plot_gene_expression(df, dark = d),
    function(d) plot_pca_scatter(scores, c(0.5, 0.3), dark = d),
    function(d) plot_pca_scree(c(0.5, 0.3), dark = d)
  )

  for (build in builders) {
    for (d in c(FALSE, TRUE)) {
      bg <- build(d)$theme$plot.background$fill
      expect_equal(bg, plot_palette(d)$bg)
    }
  }
})

test_that("the builders default to light, which is what a PDF wants", {
  # A figure going into a document should not carry a dark background, so the
  # download handlers rely on this default rather than the screen mode.
  qc <- data.frame(library_size = 1e6, detected_genes = 100)

  expect_equal(plot_qc(qc)$theme$plot.background$fill, "#ffffff")
  expect_equal(plot_pca_scree(c(0.5))$theme$plot.background$fill, "#ffffff")
})
