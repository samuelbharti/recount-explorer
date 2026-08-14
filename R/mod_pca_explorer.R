# PCA explorer module: sample-level PCA on the top variable genes, colored by
# a metadata column, variance-explained scree bar, PDF download of the exact
# on-screen scatter. The server returns a reactive of the current settings
# (n_genes, color_by) for the reproducible-script export.

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
      selectInput(ns("color_by"), "Color by", choices = c("None" = "")),
      downloadButton(ns("download_pdf"), "Download plot (PDF)")
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

    current_scatter <- reactive({
      p <- pca()
      df <- p$scores
      cd <- as.data.frame(SummarizedExperiment::colData(study()$rse))
      color_label <- NULL
      if (nzchar(input$color_by) && input$color_by %in% names(cd)) {
        df$color <- as.character(cd[[input$color_by]])
        color_label <- input$color_by
      } else {
        df$color <- "sample"
      }
      plot_pca_scatter(df, p$var_explained, color_label)
    })

    output$scatter <- renderPlot({
      validate(need(study(), "Load a study from the Browse studies tab first."))
      current_scatter()
    })

    output$scree <- renderPlot({
      validate(need(study(), "Load a study from the Browse studies tab first."))
      plot_pca_scree(pca()$var_explained)
    })

    output$download_pdf <- downloadHandler(
      filename = function() {
        paste0(req(study())$project, "_pca.pdf")
      },
      content = function(file) {
        ggsave(file, plot = current_scatter(), width = 8, height = 6)
      }
    )

    reactive({
      list(
        n_genes = input$n_genes %||% 500,
        color_by = input$color_by %||% ""
      )
    })
  })
}
