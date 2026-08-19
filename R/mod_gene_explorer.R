# Gene explorer module: server-side gene search, expression split by any
# categorical metadata column, boxplot or violin, PDF download of the exact
# on-screen plot. The server returns a reactive of the current settings
# (gene, gene_label, group_by, geom) for the reproducible-script export.

gene_explorer_ui <- function(id) {
  ns <- NS(id)
  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("Gene"),
      selectizeInput(
        ns("gene"),
        "Gene (symbol or Ensembl id)",
        choices = NULL,
        options = list(placeholder = "Type to search...")
      ),
      selectInput(ns("group_by"), "Group by", choices = c("None" = "")),
      radioButtons(
        ns("geom"),
        "Plot type",
        choices = c("Boxplot" = "box", "Violin" = "violin"),
        inline = TRUE
      ),
      downloadButton(ns("download_pdf"), "Download plot (PDF)")
    ),
    mainPanel(
      width = 9,
      h4("Expression (log2 CPM)"),
      plotOutput(ns("plot"), height = "520px")
    )
  )
}

gene_explorer_server <- function(id, study) {
  moduleServer(id, function(input, output, session) {
    observeEvent(study(), {
      s <- study()
      updateSelectizeInput(
        session,
        "gene",
        choices = gene_choices(s$rse),
        server = TRUE
      )
      updateSelectInput(
        session,
        "group_by",
        choices = c("None" = "", metadata_group_choices(s$rse))
      )
    })

    gene_label <- reactive({
      req(study(), input$gene)
      names(which(gene_choices(study()$rse) == input$gene))[1]
    })

    current_plot <- reactive({
      req(study(), input$gene)
      df <- gene_expression_df(study(), input$gene, input$group_by)
      plot_gene_expression(
        df,
        geom = input$geom,
        gene_label = gene_label(),
        group_label = if (nzchar(input$group_by)) input$group_by else NULL
      )
    })

    output$plot <- renderPlot({
      validate(need(study(), "Load a study from the Browse studies tab first."))
      validate(need(input$gene, "Search for a gene in the sidebar."))
      current_plot()
    })

    output$download_pdf <- downloadHandler(
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
