# Study overview module: a header for the loaded study, the sample metadata,
# and a library-size against detected-genes quality plot.
#
# The header is one strip rather than a row of tiles. Four coloured boxes each
# holding a bare number is a dashboard convention that says very little: 63,856
# means nothing without "genes measured" beside it. Here the study title leads,
# the accession and source sit under it as quiet metadata, and every number
# carries a unit and a caption.

study_overview_ui <- function(id) {
  ns <- NS(id)
  tagList(
    uiOutput(ns("header")),
    layout_columns(
      col_widths = c(5, 7),
      card(
        card_header("Library size against detected genes"),
        card_body(plotOutput(ns("qc"), height = "520px"))
      ),
      card(
        card_header("Sample metadata"),
        card_body(DT::DTOutput(ns("metadata")))
      )
    )
  )
}

# One number, with the words that make it mean something.
stat_figure <- function(value, unit, caption) {
  div(
    class = "stat-figure",
    div(class = "stat-figure-value", value),
    div(class = "stat-figure-unit", unit),
    div(class = "stat-figure-caption", caption)
  )
}

study_overview_server <- function(id, study, dark = reactive(FALSE)) {
  moduleServer(id, function(input, output, session) {
    qc <- reactive({
      s <- study()
      req(s)
      sample_qc(s$rse)
    })

    output$header <- renderUI({
      s <- study()
      if (is.null(s)) {
        return(card(card_body(
          class = "text-muted",
          "Load a study from the Browse view first."
        )))
      }
      counts <- SummarizedExperiment::assay(s$rse, "counts")
      present <- rowSums(counts > 0)
      everywhere <- sum(present == ncol(s$rse))
      nowhere <- sum(present == 0)
      links <- study_external_links(study_link_row(s))

      div(
        class = "study-header",
        div(
          class = "study-header-top",
          div(
            h4(class = "study-header-title", s$title %||% s$project),
            div(
              class = "study-header-meta",
              paste(s$project, s$organism, toupper(s$source), sep = " · ")
            )
          ),
          div(
            class = "study-header-links",
            lapply(seq_along(links), function(i) {
              tags$a(
                href = links[[i]],
                target = "_blank",
                rel = "noopener",
                class = "btn btn-sm btn-outline-secondary",
                names(links)[i],
                bsicons::bs_icon("box-arrow-up-right")
              )
            })
          )
        ),
        div(
          class = "stat-figures",
          stat_figure(
            format(ncol(s$rse), big.mark = ","),
            "samples",
            "in this study"
          ),
          stat_figure(
            format(nrow(s$rse), big.mark = ","),
            "genes",
            "measured"
          ),
          stat_figure(
            format_reads(stats::median(qc()$library_size)),
            "median library",
            "reads per sample"
          ),
          stat_figure(
            format(everywhere, big.mark = ","),
            "genes",
            "detected in every sample"
          ),
          stat_figure(
            sprintf("%.0f%%", 100 * nowhere / nrow(s$rse)),
            "genes",
            "detected in no sample"
          )
        )
      )
    })

    output$qc <- renderPlot({
      s <- study()
      validate(need(s, "Load a study from the Browse view first."))
      plot_qc(qc(), dark = dark())
    })

    output$metadata <- DT::renderDT(
      {
        s <- study()
        validate(need(s, "Load a study from the Browse view first."))
        DT::datatable(
          metadata_table(s$rse),
          rownames = FALSE,
          selection = "none",
          options = list(
            pageLength = 25,
            scrollX = TRUE,
            scrollY = "430px",
            scrollCollapse = TRUE
          )
        )
      },
      server = TRUE
    )
  })
}
