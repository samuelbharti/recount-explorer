# Study overview module: headline numbers, the sample metadata, and a
# library-size against detected-genes quality plot for the loaded study.

study_overview_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(
      fill = FALSE,
      value_box(
        "Study",
        textOutput(ns("v_project"), inline = TRUE),
        showcase = bsicons::bs_icon("folder2-open"),
        theme = "primary"
      ),
      value_box(
        "Samples",
        textOutput(ns("v_samples"), inline = TRUE),
        showcase = bsicons::bs_icon("collection")
      ),
      value_box(
        "Genes",
        textOutput(ns("v_genes"), inline = TRUE),
        showcase = bsicons::bs_icon("bar-chart-steps")
      ),
      value_box(
        "Source",
        textOutput(ns("v_source"), inline = TRUE),
        showcase = bsicons::bs_icon("database")
      )
    ),
    layout_columns(
      col_widths = c(5, 7),
      card(
        card_header("Quality control"),
        card_body(plotOutput(ns("qc"), height = "380px"))
      ),
      card(
        card_header("Sample metadata"),
        card_body(DT::DTOutput(ns("metadata")))
      )
    )
  )
}

study_overview_server <- function(id, study) {
  moduleServer(id, function(input, output, session) {
    output$v_project <- renderText(study()$project %||% "None")
    output$v_samples <- renderText({
      s <- study()
      if (is.null(s)) "0" else format(ncol(s$rse), big.mark = ",")
    })
    output$v_genes <- renderText({
      s <- study()
      if (is.null(s)) "0" else format(nrow(s$rse), big.mark = ",")
    })
    output$v_source <- renderText({
      s <- study()
      if (is.null(s)) "None" else toupper(s$source)
    })

    output$qc <- renderPlot({
      s <- study()
      validate(need(s, "Load a study from the Browse view first."))
      plot_qc(sample_qc(s$rse))
    })

    output$metadata <- DT::renderDT(
      {
        s <- study()
        validate(need(s, "Load a study from the Browse view first."))
        DT::datatable(
          metadata_table(s$rse),
          rownames = FALSE,
          selection = "none",
          options = list(pageLength = 10, scrollX = TRUE)
        )
      },
      server = TRUE
    )
  })
}
