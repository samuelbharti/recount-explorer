test_that("the palette differs between light and dark", {
  light <- plot_palette(FALSE)
  dark <- plot_palette(TRUE)

  expect_false(identical(light$bg, dark$bg))
  expect_false(identical(light$fg, dark$fg))
  # Asserted against the brand rather than a fixed hex, because _brand.yml is
  # the source of truth and a palette change should not break this test.
  expect_equal(light$bg, brand_plot_palette(FALSE)$bg)
  expect_equal(dark$bg, brand_plot_palette(TRUE)$bg)
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
  # A figure going into a document belongs on a light background, so the
  # download handlers rely on this default rather than the screen mode.
  qc <- data.frame(library_size = 1e6, detected_genes = 100)
  light_bg <- brand_plot_palette(FALSE)$bg

  expect_equal(plot_qc(qc)$theme$plot.background$fill, light_bg)
  expect_equal(plot_pca_scree(c(0.5))$theme$plot.background$fill, light_bg)
})

test_that("a grouping column with more levels than the palette still builds", {
  # The reported bug: metadata_group_choices() offers up to 30 levels and
  # scale_fill_manual had only 8 values, so ggplot2 threw "Insufficient values
  # in manual scale" and Shiny painted a red block over the card. The plot is
  # built, not just constructed, because that error is raised at build time.
  df <- data.frame(
    group = factor(sprintf("g%02d", 1:20)),
    expression = as.numeric(1:20),
    sample = sprintf("s%02d", 1:20)
  )

  expect_no_error(ggplot2::ggplot_build(plot_gene_expression(df)))

  scores <- data.frame(
    PC1 = as.numeric(1:20),
    PC2 = as.numeric(20:1),
    color = factor(sprintf("g%02d", 1:20)),
    sample = sprintf("s%02d", 1:20)
  )
  expect_no_error(
    ggplot2::ggplot_build(plot_pca_scatter(
      scores,
      c(0.5, 0.3),
      color_label = "g"
    ))
  )
})

test_that("safe_plot turns an error into a figure instead of a red block", {
  built <- safe_plot(stop("no such column"), dark = FALSE)

  expect_s3_class(built, "ggplot")
  expect_equal(built$theme$plot.background$fill, plot_palette(FALSE)$bg)
  expect_no_error(ggplot2::ggplot_build(built))
})

test_that("safe_plot leaves a working plot alone", {
  qc <- data.frame(library_size = c(1e6, 2e6), detected_genes = c(100, 200))

  built <- safe_plot(plot_qc(qc), dark = FALSE)

  expect_length(built$layers, 1L)
})

test_that("plot_message paints for the mode it is given", {
  for (d in c(FALSE, TRUE)) {
    built <- plot_message("nothing to show", dark = d)
    expect_equal(built$theme$plot.background$fill, plot_palette(d)$bg)
  }
})

test_that("the quality builders paint their background for the mode given", {
  rse <- fixture_rse()
  study <- fixture_study()
  correlation <- correlation_long(sample_correlation(
    study$log_expr,
    n_genes = 50
  ))
  loadings <- pca_loadings(run_pca(study$log_expr, n_genes = 50, n_pcs = 4))

  builders <- list(
    function(d) plot_biotype_composition(biotype_composition(rse), dark = d),
    function(d) plot_qc_panel(qc_metrics(rse), dark = d),
    function(d) plot_sex_check(sex_signal(rse), dark = d),
    function(d) {
      plot_expression_distribution(
        expression_quantiles(study$log_expr),
        dark = d
      )
    },
    function(d) plot_sample_correlation(correlation, dark = d),
    function(d) plot_pca_loadings(loadings, dark = d)
  )

  for (build in builders) {
    for (d in c(FALSE, TRUE)) {
      built <- build(d)
      expect_equal(built$theme$plot.background$fill, plot_palette(d)$bg)
      expect_no_error(ggplot2::ggplot_build(built))
    }
  }
})

test_that("a quality builder given nothing draws the reason, not an error", {
  # Every one of these takes NULL when the study lacks the column it needs.
  builders <- list(
    plot_biotype_composition,
    plot_qc_panel,
    plot_sex_check,
    plot_expression_distribution,
    plot_sample_correlation,
    plot_pca_loadings
  )

  for (build in builders) {
    built <- build(NULL)
    expect_s3_class(built, "ggplot")
    expect_no_error(ggplot2::ggplot_build(built))
  }
})

test_that("labelling names every point when few, trims when there are many", {
  few <- data.frame(
    library_size = c(1e6, 2e6, 3e6),
    detected_genes = c(100, 200, 300),
    sample = c("s1", "s2", "s3")
  )

  labelled <- plot_qc(few, label = TRUE)

  expect_length(labelled$layers, 2L)
  expect_equal(nrow(labelled$layers[[2]]$data), 3L)

  # Past the cap only the outliers are named, so 500 points do not become a
  # solid mat of text.
  set.seed(1)
  many <- data.frame(
    library_size = runif(500, 1e6, 9e6),
    detected_genes = runif(500, 100, 9000),
    sample = sprintf("s%03d", 1:500)
  )
  expect_equal(nrow(plot_qc(many, label = TRUE)$layers[[2]]$data), 30L)
})

test_that("point size reaches the plot", {
  qc <- data.frame(library_size = 1e6, detected_genes = 100, sample = "s1")

  expect_equal(plot_qc(qc, point_size = 5)$layers[[1]]$aes_params$size, 5)
  expect_equal(plot_qc(qc)$layers[[1]]$aes_params$size, 2.2)
})

test_that("font size reaches every builder's theme", {
  rse <- fixture_rse()
  study <- fixture_study()
  correlation <- correlation_long(sample_correlation(
    study$log_expr,
    n_genes = 50
  ))
  loadings <- pca_loadings(run_pca(study$log_expr, n_genes = 50, n_pcs = 4))
  qc <- data.frame(library_size = c(1e6, 2e6), detected_genes = c(100, 200))
  gene_df <- data.frame(
    group = c("a", "b"),
    expression = c(1, 2),
    sample = c("s1", "s2")
  )
  scores <- data.frame(PC1 = c(1, 2), PC2 = c(2, 1), color = c("a", "b"))

  # Every builder that draws text, looped the same way the dark-mode test
  # above loops builders over both modes.
  builders <- list(
    function(fs) plot_qc(qc, font_size = fs),
    function(fs) plot_gene_expression(gene_df, font_size = fs),
    function(fs) plot_pca_scatter(scores, c(0.5, 0.3), font_size = fs),
    function(fs) plot_pca_scree(c(0.5, 0.3), font_size = fs),
    function(fs) {
      plot_biotype_composition(biotype_composition(rse), font_size = fs)
    },
    function(fs) plot_qc_panel(qc_metrics(rse), font_size = fs),
    function(fs) plot_sex_check(sex_signal(rse), font_size = fs),
    function(fs) {
      plot_expression_distribution(
        expression_quantiles(study$log_expr),
        font_size = fs
      )
    },
    function(fs) plot_sample_correlation(correlation, font_size = fs),
    function(fs) plot_pca_loadings(loadings, font_size = fs)
  )

  for (build in builders) {
    small <- build(10)$theme$text$size
    large <- build(24)$theme$text$size
    expect_equal(small, 10)
    expect_equal(large, 24)
  }
})

test_that("font size defaults to 21, found legible on a plot-heavy page", {
  qc <- data.frame(library_size = 1e6, detected_genes = 100)

  expect_equal(plot_qc(qc)$theme$text$size, 21)
})

test_that("font size scales the parts theme_recount() cannot reach", {
  # geom_text_repel and annotate() measure size in mm, not the points
  # theme_recount() uses, so these are scaled by hand and need their own
  # check that the scaling actually moves.
  few <- data.frame(
    library_size = c(1e6, 2e6, 3e6),
    detected_genes = c(100, 200, 300),
    sample = c("s1", "s2", "s3")
  )
  label_size <- function(fs) {
    plot_qc(few, label = TRUE, font_size = fs)$layers[[2]]$aes_params$size
  }
  expect_gt(label_size(24), label_size(10))

  message_size <- function(fs) {
    plot_message("x", font_size = fs)$layers[[1]]$aes_params$size
  }
  expect_gt(message_size(24), message_size(10))

  rse <- fixture_rse()
  axis_size <- function(fs) {
    plot_biotype_composition(
      biotype_composition(rse),
      font_size = fs
    )$theme$axis.text.x$size
  }
  expect_gt(axis_size(24), axis_size(10))
})

test_that("safe_plot forwards font size to the error message it draws", {
  built <- safe_plot(stop("boom"), font_size = 22)

  expect_equal(built$layers[[1]]$aes_params$size, 22 / 14 * 4.5)
})

test_that("facet strip text follows the theme, not theme_minimal()'s grey", {
  # theme_minimal() sets strip.text to a fixed dark colour rather than
  # inheriting `text`, so without an explicit override the quality metrics
  # panel's facet titles stayed near-black and disappeared on a dark page.
  qc <- data.frame(
    metric = factor(c("a", "a", "b", "b")),
    value = c(1, 2, 3, 4),
    group = factor("all samples"),
    outlier = c(FALSE, FALSE, FALSE, FALSE)
  )

  for (dark in c(FALSE, TRUE)) {
    built <- plot_qc_panel(qc, dark = dark)
    expect_equal(
      built$theme$strip.text$colour,
      plot_palette(dark)$fg,
      info = dark
    )
    expect_equal(
      built$theme$strip.background$fill,
      plot_palette(dark)$bg,
      info = dark
    )
  }
})

test_that("the correlation heatmap fills its full background in both modes", {
  # coord_fixed() left the letterboxed margin around a square panel
  # undrawn, so Shiny's own white PNG default showed through there in every
  # mode. Rendering to a PNG and sampling the far corners is the only way to
  # catch this: the theme object alone looks correct even when it fails.
  skip_if_not_installed("png")
  m <- matrix(
    c(1, 0.2, 0.5, 0.2, 1, 0.3, 0.5, 0.3, 1),
    nrow = 3,
    dimnames = list(c("s1", "s2", "s3"), c("s1", "s2", "s3"))
  )
  df <- correlation_long(m)

  for (dark in c(FALSE, TRUE)) {
    f <- withr::local_tempfile(fileext = ".png")
    # Wide and short, like the real card, so a fixed-aspect panel would
    # letterbox on the sides the way it did in the app.
    ggplot2::ggsave(
      f,
      plot_sample_correlation(df, dark = dark),
      width = 10,
      height = 4,
      dpi = 72
    )
    img <- png::readPNG(f)
    h <- dim(img)[1]
    edge <- img[round(h / 2), 3, 1:3]
    expected <- as.numeric(grDevices::col2rgb(plot_palette(dark)$bg)) / 255
    expect_equal(edge, expected, tolerance = 0.02, info = dark)
  }
})
