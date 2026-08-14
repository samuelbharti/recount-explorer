# Study browser module: filter the recount3 catalog and load one study.
# Loading runs off the main R process (ExtendedTask + mirai daemon), so the UI
# stays responsive for this and every other session while a study downloads.
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
        "Loading runs in the background: keep browsing while it downloads.",
        "Large studies (GTEx, TCGA) take a while and need a lot of memory."
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
    pending <- reactiveVal(NULL)

    # Download and log2 CPM both happen on the daemon: mirai evaluates in a
    # clean process, so the two logic functions are passed in explicitly and
    # already namespace-qualify their recount3/SummarizedExperiment calls.
    load_task <- ExtendedTask$new(function(proj_info) {
      mirai::mirai(
        {
          rse <- load_study(proj_info)
          list(rse = rse, log_expr = log_cpm(rse))
        },
        .args = list(
          proj_info = proj_info,
          load_study = load_study,
          log_cpm = log_cpm
        )
      )
    })

    observeEvent(input$load, {
      if (identical(load_task$status(), "running")) {
        showNotification(
          paste("Still loading", pending()$project, ", one study at a time."),
          type = "warning"
        )
        return()
      }
      sel <- input$catalog_rows_selected
      if (!length(sel)) {
        showNotification("Select a study in the table first.", type = "warning")
        return()
      }
      info <- filtered()[sel, , drop = FALSE]
      pending(info)
      load_task$invoke(info)
      updateActionButton(session, "load", label = "Loading...")
      showNotification(
        paste(
          "Loading", info$project, "in the background.",
          "The app stays responsive; you will be notified when it is ready."
        ),
        type = "message"
      )
    })

    observeEvent(load_task$status(), {
      status <- load_task$status()
      if (!status %in% c("success", "error")) {
        return()
      }
      updateActionButton(session, "load", label = "Load selected study")
      info <- pending()
      pending(NULL)
      if (status == "error") {
        msg <- tryCatch(
          {
            load_task$result()
            "unknown error"
          },
          error = function(e) conditionMessage(e)
        )
        showNotification(
          paste("Failed to load", info$project, ":", msg),
          type = "error",
          duration = 10
        )
        return()
      }
      res <- load_task$result()
      study(list(
        project = info$project,
        organism = info$organism,
        source = info$file_source,
        rse = res$rse,
        log_expr = res$log_expr
      ))
      showNotification(
        paste(
          info$project, "loaded:", ncol(res$rse), "samples.",
          "See the Study overview tab."
        ),
        type = "message"
      )
    })

    study
  })
}
