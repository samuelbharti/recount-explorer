# PCA module: sample-level principal component analysis on the genes with the
# highest variance, coloured by any categorical metadata column.
#
# The module returns its current settings as a reactive so the export module
# can put them in the reproduction script.

pca_explorer_ui <- function(id) {
  ns <- NS(id)
  layout_sidebar(
    sidebar = sidebar(
      title = "Settings",
      width = 280,
      sliderInput(
        ns("n_genes"),
        "Top variable genes",
        min = 100,
        max = 2000,
        value = 500,
        step = 100,
        # A PCA over 2,000 genes is not something to run sixty times during one
        # drag, so it recomputes on release.
        ticks = FALSE
      ),
      selectInput(
        ns("color_by"),
        "Colour by",
        choices = c("No colouring" = "")
      ),
      downloadButton(ns("pdf"), "Download PDF", class = "btn-sm")
    ),
    layout_columns(
      col_widths = c(8, 4),
      card(
        card_header("PC1 against PC2"),
        card_body(plotOutput(ns("scatter"), height = "500px"))
      ),
      card(
        card_header("Variance explained"),
        card_body(plotOutput(ns("scree"), height = "500px"))
      )
    )
  )
}

pca_explorer_server <- function(id, study) {
  moduleServer(id, function(input, output, session) {
    observeEvent(study(), {
      updateSelectInput(
        session,
        "color_by",
        choices = c("No colouring" = "", metadata_group_choices(study()$rse))
      )
    })

    pca <- reactive({
      s <- study()
      req(s)
      run_pca(s$log_expr, n_genes = input$n_genes)
    })

    scores <- reactive({
      s <- study()
      req(s)
      df <- pca()$scores
      df$color <- if (isTruthy(input$color_by)) {
        as.character(
          as.data.frame(SummarizedExperiment::colData(s$rse))[[input$color_by]]
        )
      } else {
        "sample"
      }
      df
    })

    current_plot <- reactive({
      plot_pca_scatter(
        scores(),
        pca()$var_explained,
        color_label = if (isTruthy(input$color_by)) input$color_by else NULL
      )
    })

    output$scatter <- renderPlot({
      validate(need(study(), "Load a study from the Browse view first."))
      current_plot()
    })

    output$scree <- renderPlot({
      validate(need(study(), "Load a study from the Browse view first."))
      plot_pca_scree(pca()$var_explained)
    })

    output$pdf <- downloadHandler(
      filename = function() paste0(req(study())$project, "_pca.pdf"),
      content = function(file) {
        ggsave(file, plot = current_plot(), width = 9, height = 6)
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
