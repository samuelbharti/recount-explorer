# Export module: data downloads (RSE, log2 CPM, metadata) and a standalone R
# script that reproduces the current session outside the app, with citation
# and provenance in its header. Takes the shared `study` reactive plus the
# settings reactives returned by the gene and PCA modules.

export_ui <- function(id) {
  ns <- NS(id)
  fluidRow(
    column(
      4,
      h4("Data"),
      p(
        "Everything the app is showing, ready for downstream analysis in R",
        "or anywhere else."
      ),
      div(
        class = "download-list",
        downloadButton(ns("rds"), "RangedSummarizedExperiment (.rds)"),
        downloadButton(ns("counts"), "log2 CPM matrix (.csv.gz)"),
        downloadButton(ns("metadata"), "Sample metadata (.csv)")
      )
    ),
    column(
      8,
      h4("Reproducible script"),
      p(
        "A standalone R script (recount3 + ggplot2 only) that re-downloads",
        "the study and rebuilds the QC, PCA, and gene views with your current",
        "settings. Cite-ready provenance is in the header."
      ),
      downloadButton(ns("script"), "Reproduction script (.R)"),
      verbatimTextOutput(ns("preview"))
    )
  )
}

export_server <- function(id, study, gene_state, pca_state) {
  moduleServer(id, function(input, output, session) {
    script_text <- reactive({
      req(study())
      build_reproduction_script(
        study(),
        gene_state = gene_state(),
        pca_state = pca_state()
      )
    })

    output$preview <- renderText({
      validate(need(study(), "Load a study from the Browse studies tab first."))
      script_text()
    })

    output$rds <- downloadHandler(
      filename = function() paste0(req(study())$project, "_rse.rds"),
      content = function(file) {
        saveRDS(study()$rse, file)
      }
    )

    output$counts <- downloadHandler(
      filename = function() paste0(req(study())$project, "_log2cpm.csv.gz"),
      content = function(file) {
        con <- gzfile(file, "w")
        on.exit(close(con))
        utils::write.csv(expression_export_df(study()), con, row.names = FALSE)
      }
    )

    output$metadata <- downloadHandler(
      filename = function() paste0(req(study())$project, "_metadata.csv"),
      content = function(file) {
        utils::write.csv(flatten_coldata(study()$rse), file, row.names = FALSE)
      }
    )

    output$script <- downloadHandler(
      filename = function() {
        paste0("reproduce_", req(study())$project, ".R")
      },
      content = function(file) {
        writeLines(script_text(), file)
      }
    )
  })
}
