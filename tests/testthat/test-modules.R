# Module server tests.
#
# The rest of the suite covers the Shiny-free layer, which leaves the wiring
# untested: an input id that no control sets, a reactive that never fires, an
# output that errors on its first render. testServer drives the real module
# server without a browser, so those show up here rather than in the app.

module_study <- function() {
  rse <- fixture_rse()
  list(
    project = "SRP000001",
    organism = "human",
    source = "sra",
    title = "A fixture study",
    rse = rse,
    log_expr = log_cpm(rse)
  )
}

# The fixture column with more levels than there are named brand colours. This
# is the case that used to error with "Insufficient values in manual scale".
MANY_LEVELS <- "donor"

test_that("the quality module builds all four figures", {
  study <- module_study()

  shiny::testServer(
    quality_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(
        group_by = "",
        top_biotypes = 8,
        cor_method = "spearman",
        point_size = 2.5,
        label_points = FALSE
      )

      expect_gt(nrow(metrics()), 0)
      expect_gt(nrow(biotype()), 0)
      expect_gt(nrow(sex()), 0)
      expect_gt(nrow(correlation()), 0)

      for (build in list(
        metrics_plot,
        biotype_plot,
        sex_plot,
        correlation_plot
      )) {
        expect_no_error(ggplot2::ggplot_build(build(FALSE)))
      }
    }
  )
})

test_that("the quality module survives a grouping column with many levels", {
  study <- module_study()

  shiny::testServer(
    quality_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(
        group_by = MANY_LEVELS,
        top_biotypes = 4,
        cor_method = "pearson",
        point_size = 4,
        label_points = TRUE
      )

      expect_no_error(ggplot2::ggplot_build(metrics_plot(FALSE)))
      expect_no_error(ggplot2::ggplot_build(sex_plot(FALSE)))
      expect_no_error(ggplot2::ggplot_build(biotype_plot(FALSE)))
    }
  )
})

test_that("the quality module reports its settings for the export script", {
  study <- module_study()

  shiny::testServer(
    quality_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(
        group_by = "tissue",
        top_biotypes = 6,
        cor_method = "pearson"
      )

      state <- session$getReturned()()
      expect_equal(state$group_by, "tissue")
      expect_equal(state$top_biotypes, 6)
      expect_equal(state$cor_method, "pearson")
    }
  )
})

test_that("the overview module drives its table from the selected row", {
  study <- module_study()
  # Captured out here: inside testServer, `study` is the module's reactive
  # argument rather than this list.
  rse <- study$rse
  second <- colnames(rse)[[2]]

  shiny::testServer(
    study_overview_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(
        point_size = 2.2,
        label_points = FALSE,
        columns = character(0)
      )

      expect_lte(length(columns()$default), 8L)
      # Nothing selected yet, so the detail card has nothing to show.
      expect_null(selected_sample())

      session$setInputs(metadata_rows_selected = 2L)

      expect_equal(selected_sample(), second)
      expect_gt(nrow(sample_detail(rse, selected_sample())), 0)
    }
  )
})

test_that("the overview module builds both of its figures", {
  study <- module_study()

  shiny::testServer(
    study_overview_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(point_size = 5, label_points = TRUE)

      expect_no_error(ggplot2::ggplot_build(qc_plot(FALSE)))
      expect_no_error(ggplot2::ggplot_build(distribution_plot(FALSE)))
      # The gene detection scan is memoised, so the dark mode toggle does not
      # send it over the whole counts matrix again.
      expect_type(detection()$everywhere, "integer")
    }
  )
})

test_that("the PCA module carries sample names through for labelling", {
  study <- module_study()

  shiny::testServer(
    pca_explorer_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(
        n_genes = 50,
        color_by = "",
        loading_pc = 1,
        point_size = 2.5,
        label_points = FALSE
      )

      # run_pca() leaves `sample` out of the scores frame on purpose; the
      # module adds it, and without it a labelled point has no name.
      expect_true("sample" %in% names(scores()))
      expect_equal(nrow(loadings()), 20L)
      expect_no_error(ggplot2::ggplot_build(current_plot(FALSE)))
      expect_no_error(ggplot2::ggplot_build(loadings_plot(FALSE)))
    }
  )
})

test_that("the PCA module colours by a many-level column and switches PC", {
  study <- module_study()

  shiny::testServer(
    pca_explorer_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(
        n_genes = 50,
        color_by = MANY_LEVELS,
        loading_pc = 3,
        point_size = 2.5,
        label_points = TRUE
      )

      expect_no_error(ggplot2::ggplot_build(current_plot(FALSE)))
      expect_no_error(ggplot2::ggplot_build(loadings_plot(FALSE)))
    }
  )
})

test_that("the gene module groups by a many-level column without erroring", {
  study <- module_study()
  first_gene <- rownames(study$rse)[[1]]

  shiny::testServer(
    gene_explorer_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(
        gene = first_gene,
        geom = "box",
        group_by = MANY_LEVELS
      )

      expect_no_error(ggplot2::ggplot_build(current_plot(FALSE)))
    }
  )
})

test_that("the font size control reaches every plot in the gene module", {
  study <- module_study()
  first_gene <- rownames(study$rse)[[1]]

  shiny::testServer(
    gene_explorer_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(
        gene = first_gene,
        geom = "box",
        group_by = "",
        font_size = 14
      )
      small <- current_plot(FALSE)$theme$text$size
      session$setInputs(font_size = 22)
      large <- current_plot(FALSE)$theme$text$size

      expect_equal(small, 14)
      expect_equal(large, 22)
    }
  )
})

test_that("one font size control governs both plots on the overview page", {
  study <- module_study()

  shiny::testServer(
    study_overview_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(font_size = 14, point_size = 2.2, label_points = FALSE)
      qc_small <- qc_plot(FALSE)$theme$text$size
      dist_small <- distribution_plot(FALSE)$theme$text$size

      session$setInputs(font_size = 22)
      qc_large <- qc_plot(FALSE)$theme$text$size
      dist_large <- distribution_plot(FALSE)$theme$text$size

      # One control, not two: both plots move together from a single input,
      # the same way the shared toolbar above them implies.
      expect_equal(c(qc_small, dist_small), c(14, 14))
      expect_equal(c(qc_large, dist_large), c(22, 22))
    }
  )
})

test_that("one font size control governs all four plots in the quality module", {
  study <- module_study()

  shiny::testServer(
    quality_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(
        font_size = 14,
        group_by = "",
        top_biotypes = 8,
        cor_method = "spearman",
        point_size = 2.5,
        label_points = FALSE
      )
      small <- vapply(
        list(metrics_plot, biotype_plot, sex_plot, correlation_plot),
        function(f) f(FALSE)$theme$text$size,
        numeric(1)
      )

      session$setInputs(font_size = 22)
      large <- vapply(
        list(metrics_plot, biotype_plot, sex_plot, correlation_plot),
        function(f) f(FALSE)$theme$text$size,
        numeric(1)
      )

      expect_equal(small, rep(14, 4))
      expect_equal(large, rep(22, 4))
    }
  )
})

test_that("one font size control governs the scatter, scree and loadings in PCA", {
  study <- module_study()

  shiny::testServer(
    pca_explorer_server,
    args = list(study = reactive(study), dark = reactive(FALSE)),
    {
      session$setInputs(
        n_genes = 50,
        color_by = "",
        loading_pc = 1,
        font_size = 14,
        point_size = 2.5,
        label_points = FALSE
      )
      small <- vapply(
        list(current_plot, scree_plot, loadings_plot),
        function(f) f(FALSE)$theme$text$size,
        numeric(1)
      )

      session$setInputs(font_size = 22)
      large <- vapply(
        list(current_plot, scree_plot, loadings_plot),
        function(f) f(FALSE)$theme$text$size,
        numeric(1)
      )

      expect_equal(small, rep(14, 3))
      expect_equal(large, rep(22, 3))
    }
  )
})
