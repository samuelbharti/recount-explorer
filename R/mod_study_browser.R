# Study browser module: filter the recount3 catalog and load one study.
# The server returns the app-wide `study` reactive:
# list(project, organism, source, rse, log_expr), NULL until a study is loaded.

study_browser_ui <- function(id) {
  ns <- NS(id)
  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("Filter catalog"),
      selectInput(
        ns("organism"), "Organism",
        choices = c("Human" = "human", "Mouse" = "mouse")
      ),
      checkboxGroupInput(
        ns("source"), "Data source",
        choices = c("SRA" = "sra", "GTEx" = "gtex", "TCGA" = "tcga"),
        selected = "sra"
      ),
      numericInput(ns("min_n"), "Min samples", value = 2, min = 1, step = 1),
      numericInput(ns("max_n"), "Max samples", value = 500, min = 1, step = 1),
      actionButton(ns("load"), "Load selected study", class = "btn-primary"),
      helpText(
        "Large studies (GTEx, TCGA) take a while to download",
        "and need a lot of memory."
      )
    ),
    mainPanel(
      width = 9,
      h4("Available studies"),
      DT::DTOutput(ns("catalog"))
    )
  )
}

study_browser_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    catalog <- reactive({
      req(recount3_available(), input$organism)
      withProgress(message = "Fetching recount3 catalog...", value = NULL, {
        fetch_project_catalog(input$organism)
      })
    })

    filtered <- reactive({
      df <- catalog()
      if (length(input$source)) {
        df <- df[df$file_source %in% input$source, , drop = FALSE]
      }
      if (isTruthy(input$min_n)) {
        df <- df[df$n_samples >= input$min_n, , drop = FALSE]
      }
      if (isTruthy(input$max_n)) {
        df <- df[df$n_samples <= input$max_n, , drop = FALSE]
      }
      df
    })

    output$catalog <- DT::renderDT({
      validate(need(
        recount3_available(),
        paste(
          "The recount3 package is not installed.",
          "Run BiocManager::install(\"recount3\") and restart the app."
        )
      ))
      DT::datatable(
        filtered()[, c("project", "organism", "file_source", "n_samples")],
        selection = "single",
        rownames = FALSE,
        options = list(pageLength = 15, order = list(list(3, "desc")))
      )
    })

    study <- reactiveVal(NULL)

    observeEvent(input$load, {
      sel <- input$catalog_rows_selected
      if (!length(sel)) {
        showNotification("Select a study in the table first.", type = "warning")
        return()
      }
      info <- filtered()[sel, , drop = FALSE]
      result <- withProgress(
        message = paste("Loading", info$project),
        detail = "Downloading counts and metadata from recount3...",
        value = NULL,
        tryCatch(load_study(info), error = function(e) e)
      )
      if (inherits(result, "error")) {
        showNotification(
          paste("Failed to load", info$project, ":", conditionMessage(result)),
          type = "error",
          duration = 10
        )
        return()
      }
      study(list(
        project = info$project,
        organism = info$organism,
        source = info$file_source,
        rse = result,
        log_expr = log_cpm(result)
      ))
      showNotification(
        paste(
          info$project, "loaded:", ncol(result), "samples.",
          "See the Study overview tab."
        ),
        type = "message"
      )
    })

    study
  })
}
