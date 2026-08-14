# PCA explorer module: sample-level PCA on the top variable genes, colored by
# a metadata column, with a variance-explained scree bar.

pca_explorer_ui <- function(id) {
  ns <- NS(id)
  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("PCA settings"),
      sliderInput(
        ns("n_genes"), "Top variable genes",
        min = 100, max = 2000, value = 500, step = 100
      ),
      selectInput(ns("color_by"), "Color by", choices = c("None" = ""))
    ),
    mainPanel(
      width = 9,
      fluidRow(
        column(
          8,
          h4("PC1 vs PC2"),
          plotOutput(ns("scatter"), height = "480px")
        ),
        column(
          4,
          h4("Variance explained"),
          plotOutput(ns("scree"), height = "480px")
        )
      )
    )
  )
}

pca_explorer_server <- function(id, study) {
  moduleServer(id, function(input, output, session) {
    observeEvent(study(), {
      updateSelectInput(
        session, "color_by",
        choices = c("None" = "", metadata_group_choices(study()$rse))
      )
    })

    pca <- reactive({
      req(study())
      withProgress(message = "Running PCA...", value = NULL, {
        run_pca(study()$log_expr, n_genes = input$n_genes)
      })
    })

    output$scatter <- renderPlot({
      validate(need(study(), "Load a study from the Browse studies tab first."))
      p <- pca()
      df <- p$scores
      cd <- as.data.frame(SummarizedExperiment::colData(study()$rse))
      if (nzchar(input$color_by) && input$color_by %in% names(cd)) {
        df$color <- as.character(cd[[input$color_by]])
      } else {
        df$color <- "sample"
      }
      pct <- function(i) sprintf("PC%d (%.1f%%)", i, 100 * p$var_explained[i])
      gg <- ggplot(df, aes(x = PC1, y = PC2, color = color)) +
        geom_point(alpha = 0.7, size = 2.5) +
        labs(
          x = pct(1), y = pct(2),
          color = if (nzchar(input$color_by)) input$color_by else NULL
        ) +
        theme_minimal(base_size = 14)
      if (!nzchar(input$color_by)) {
        gg <- gg + guides(color = "none")
      }
      gg
    })

    output$scree <- renderPlot({
      validate(need(study(), "Load a study from the Browse studies tab first."))
      p <- pca()
      df <- data.frame(
        pc = factor(seq_along(p$var_explained)),
        var = 100 * p$var_explained
      )
      ggplot(df, aes(x = pc, y = var)) +
        geom_col() +
        labs(x = "PC", y = "% variance") +
        theme_minimal(base_size = 14)
    })
  })
}
