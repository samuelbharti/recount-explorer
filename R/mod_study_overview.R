# Study overview module: headline stat tiles, curated sample metadata, and a
# library-size vs detected-genes QC scatter for the loaded study.

stat_tile <- function(label, value_output) {
  div(
    class = "stat-tile",
    div(class = "stat-label", label),
    div(class = "stat-value", value_output)
  )
}

study_overview_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(
      class = "stat-grid",
      stat_tile("Study", textOutput(ns("project"), inline = TRUE)),
      stat_tile("Samples", textOutput(ns("n_samples"), inline = TRUE)),
      stat_tile("Genes", textOutput(ns("n_genes"), inline = TRUE)),
      stat_tile("Source", textOutput(ns("source"), inline = TRUE))
    ),
    fluidRow(
      column(
        7,
        h4("Sample metadata"),
        DT::DTOutput(ns("metadata"))
      ),
      column(
        5,
        h4("QC: library size vs detected genes"),
        plotOutput(ns("qc"), height = "420px")
      )
    )
  )
}

study_overview_server <- function(id, study) {
  moduleServer(id, function(input, output, session) {
    output$project <- renderText(req(study())$project)
    output$n_samples <- renderText(format(ncol(req(study())$rse), big.mark = ","))
    output$n_genes <- renderText(format(nrow(req(study())$rse), big.mark = ","))
    output$source <- renderText({
      s <- req(study())
      paste0(toupper(s$source), " (", s$organism, ")")
    })

    output$metadata <- DT::renderDT({
      validate(need(study(), "Load a study from the Browse studies tab first."))
      DT::datatable(
        metadata_table(study()$rse),
        rownames = FALSE,
        options = list(pageLength = 10, scrollX = TRUE)
      )
    })

    output$qc <- renderPlot({
      validate(need(study(), "Load a study from the Browse studies tab first."))
      plot_qc(sample_qc(study()$rse))
    })
  })
}
