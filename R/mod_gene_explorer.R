# Gene explorer module: pick one gene and plot its expression, split by any
# categorical metadata column.
#
# The module returns its current settings as a reactive so the export module
# can put them in the reproduction script.

gene_explorer_ui <- function(id) {
  ns <- NS(id)
  layout_sidebar(
    sidebar = sidebar(
      title = "Gene",
      width = 280,
      selectizeInput(
        ns("gene"),
        "Search for a gene",
        choices = NULL,
        options = list(
          placeholder = "Symbol or Ensembl id",
          maxOptions = 50
        )
      ),
      selectInput(ns("group_by"), "Group by", choices = c("No grouping" = "")),
      radioButtons(
        ns("geom"),
        "Plot",
        choices = c("Boxplot" = "box", "Violin" = "violin"),
        inline = TRUE
      ),
      downloadButton(ns("pdf"), "Download PDF", class = "btn-sm")
    ),
    card(
      card_header("Expression, log2 CPM"),
      card_body(plotOutput(ns("plot"), height = "540px"))
    )
  )
}

gene_explorer_server <- function(id, study) {
  moduleServer(id, function(input, output, session) {
    observeEvent(study(), {
      s <- study()
      # server = TRUE keeps the roughly 60,000 choices on this side and sends
      # only what the user's typing matches.
      updateSelectizeInput(
        session,
        "gene",
        choices = gene_choices(s$rse),
        server = TRUE
      )
      updateSelectInput(
        session,
        "group_by",
        choices = c("No grouping" = "", metadata_group_choices(s$rse))
      )
    })

    gene_label <- reactive({
      s <- study()
      req(s, input$gene)
      label <- names(which(gene_choices(s$rse) == input$gene))
      if (length(label)) label[[1L]] else input$gene
    })

    current_plot <- reactive({
      s <- study()
      req(s, input$gene)
      plot_gene_expression(
        gene_expression_df(s, input$gene, input$group_by),
        geom = input$geom %||% "box",
        gene_label = gene_label(),
        group_label = if (isTruthy(input$group_by)) input$group_by else NULL
      )
    })

    output$plot <- renderPlot({
      validate(need(study(), "Load a study from the Browse view first."))
      validate(need(input$gene, "Search for a gene in the sidebar."))
      current_plot()
    })

    output$pdf <- downloadHandler(
      filename = function() {
        paste0(req(study())$project, "_", req(input$gene), ".pdf")
      },
      content = function(file) {
        ggsave(file, plot = current_plot(), width = 9, height = 6)
      }
    )

    reactive({
      list(
        gene = input$gene %||% "",
        gene_label = if (isTruthy(input$gene)) gene_label() else "",
        group_by = input$group_by %||% "",
        geom = input$geom %||% "box"
      )
    })
  })
}
