# Gene explorer module: server-side gene search, expression split by any
# categorical metadata column, boxplot or violin.

gene_explorer_ui <- function(id) {
  ns <- NS(id)
  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("Gene"),
      selectizeInput(
        ns("gene"), "Gene (symbol or Ensembl id)",
        choices = NULL,
        options = list(placeholder = "Type to search...")
      ),
      selectInput(ns("group_by"), "Group by", choices = c("None" = "")),
      radioButtons(
        ns("geom"), "Plot type",
        choices = c("Boxplot" = "box", "Violin" = "violin"),
        inline = TRUE
      )
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
        session, "gene",
        choices = gene_choices(s$rse),
        server = TRUE
      )
      updateSelectInput(
        session, "group_by",
        choices = c("None" = "", metadata_group_choices(s$rse))
      )
    })

    output$plot <- renderPlot({
      validate(need(study(), "Load a study from the Browse studies tab first."))
      req(input$gene)
      df <- gene_expression_df(study(), input$gene, input$group_by)
      gg <- ggplot(df, aes(x = group, y = expression, fill = group))
      gg <- if (identical(input$geom, "violin")) {
        gg + geom_violin(alpha = 0.7)
      } else {
        gg + geom_boxplot(alpha = 0.7, outlier.shape = NA)
      }
      gg +
        geom_jitter(width = 0.15, alpha = 0.4, size = 1.5) +
        labs(
          x = if (nzchar(input$group_by)) input$group_by else NULL,
          y = "log2 CPM",
          title = names(which(gene_choices(study()$rse) == input$gene))[1]
        ) +
        guides(fill = "none") +
        theme_minimal(base_size = 14) +
        theme(axis.text.x = element_text(angle = 30, hjust = 1))
    })
  })
}
