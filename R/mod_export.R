# Export module: data downloads and the reproduction script.
#
# The script only needs recount3 and ggplot2, not this app, so a reader can
# rerun the session without installing anything from here.

export_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = c(4, 8),
    card(
      card_header("Downloads"),
      card_body(
        class = "download-list",
        download_row(
          ns("rse"),
          "RangedSummarizedExperiment (.rds)",
          "Counts, metadata and gene annotation in one R object."
        ),
        download_row(
          ns("expression"),
          "log2 CPM matrix (.csv.gz)",
          "Genes by samples, the values every view plots."
        ),
        download_row(
          ns("metadata"),
          "Sample metadata (.csv)",
          "Every colData column, list columns flattened."
        ),
        download_row(
          ns("script"),
          "Reproduction script (.R)",
          "Repeats this session with recount3 and ggplot2 only."
        )
      )
    ),
    card(
      card_header("Reproduction script"),
      card_body(verbatimTextOutput(ns("preview")))
    )
  )
}

# One download button plus the sentence that says what it gives you.
download_row <- function(id, label, hint) {
  div(
    class = "download-row",
    downloadButton(id, label, class = "btn-outline-primary w-100"),
    div(class = "text-muted small mt-1", hint)
  )
}

export_server <- function(id, study, gene_state, pca_state) {
  moduleServer(id, function(input, output, session) {
    script <- reactive({
      s <- study()
      req(s)
      build_reproduction_script(s, gene_state(), pca_state())
    })

    output$preview <- renderText({
      validate(need(study(), "Load a study from the Browse view first."))
      script()
    })

    output$rse <- downloadHandler(
      filename = function() paste0(req(study())$project, ".rds"),
      content = function(file) saveRDS(req(study())$rse, file)
    )

    output$expression <- downloadHandler(
      filename = function() paste0(req(study())$project, "_log2cpm.csv.gz"),
      content = function(file) {
        con <- gzfile(file, "w")
        on.exit(close(con), add = TRUE)
        utils::write.csv(
          expression_export_df(req(study())),
          con,
          row.names = FALSE
        )
      }
    )

    output$metadata <- downloadHandler(
      filename = function() paste0(req(study())$project, "_metadata.csv"),
      content = function(file) {
        utils::write.csv(
          flatten_coldata(req(study())$rse),
          file,
          row.names = FALSE
        )
      }
    )

    output$script <- downloadHandler(
      filename = function() paste0(req(study())$project, "_recount_explorer.R"),
      content = function(file) writeLines(script(), file)
    )
  })
}
