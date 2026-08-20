# Study browser module: search the recount3 catalog and load one study.
#
# Three panes. Filters on the left, results in the middle, the selected study
# on the right. The right pane is a bslib sidebar rather than a card under the
# table, so reading an abstract never pushes the results off the screen.
#
# Loading runs off the main R process (ExtendedTask plus mirai daemon), so a
# slow download never blocks this session or any other. The server returns the
# app-wide `study` reactive:
# list(project, organism, source, rse, log_expr), NULL until a study is loaded.

# Presets rather than a slider. The median study has 11 samples and the largest
# has 28,706, so a linear control over that range is unusable.
SAMPLE_PRESETS <- c(
  "Any size" = "any",
  "Up to 20 samples" = "0-20",
  "20 to 100" = "20-100",
  "100 to 500" = "100-500",
  "Over 500" = "500-Inf"
)

study_browser_ui <- function(id) {
  ns <- NS(id)
  layout_sidebar(
    sidebar = sidebar(
      title = "Filters",
      width = 260,
      accordion(
        id = ns("filters"),
        multiple = TRUE,
        # Organism and source open by default. Size is the one people reach
        # for least, so it starts folded.
        open = c("organism", "source"),
        accordion_panel(
          "Organism",
          value = "organism",
          icon = bsicons::bs_icon("bezier2"),
          checkboxGroupInput(ns("organisms"), NULL, choices = character(0))
        ),
        accordion_panel(
          "Data source",
          value = "source",
          icon = bsicons::bs_icon("hdd-stack"),
          checkboxGroupInput(ns("sources"), NULL, choices = character(0))
        ),
        accordion_panel(
          "Study size",
          value = "size",
          icon = bsicons::bs_icon("rulers"),
          radioButtons(
            ns("samples"),
            NULL,
            choices = SAMPLE_PRESETS,
            selected = "any"
          )
        )
      ),
      actionLink(ns("clear"), "Clear all filters", class = "small")
    ),
    layout_sidebar(
      sidebar = sidebar(
        title = "Selected study",
        position = "right",
        width = 360,
        open = "closed",
        id = ns("details_pane"),
        uiOutput(ns("details"))
      ),
      div(
        class = "browse-main",
        div(
          class = "search-row",
          textInput(
            ns("q"),
            NULL,
            placeholder = "Search accession, title or abstract",
            width = "100%"
          )
        ),
        div(
          class = "catalog-meta",
          textOutput(ns("match_count"), inline = TRUE)
        ),
        DT::DTOutput(ns("catalog"), fill = TRUE)
      )
    )
  )
}

study_browser_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    # Read once for each process. Every session shares this one data frame.
    catalog <- read_catalog()

    observeEvent(TRUE, once = TRUE, {
      if (is.null(catalog)) {
        showNotification(
          paste(
            "No catalog snapshot at",
            paste0(catalog_snapshot_path(), "."),
            "Run Rscript data-raw/build_catalog.R to build one."
          ),
          type = "error",
          duration = NULL
        )
        return()
      }
      # Choices come from the data, so a new recount3 source appears on its own
      # rather than after someone edits a hardcoded list.
      organisms <- sort(unique(catalog$organism))
      sources <- catalog_sources(catalog)
      updateCheckboxGroupInput(
        session,
        "organisms",
        choices = labelled_counts(organisms, catalog$organism)
      )
      updateCheckboxGroupInput(
        session,
        "sources",
        choices = labelled_counts(sources, catalog$file_source)
      )
    })

    # Typing greps roughly 20 MB of abstract text in R. Waiting for a pause
    # turns that into one pass for each search rather than one for each letter.
    query <- reactive(input$q) |> debounce(350)

    sample_range <- reactive({
      preset <- input$samples %||% "any"
      if (identical(preset, "any")) {
        return(list(min = NULL, max = NULL))
      }
      parts <- strsplit(preset, "-", fixed = TRUE)[[1L]]
      list(
        min = as.numeric(parts[[1L]]),
        max = if (parts[[2L]] == "Inf") NULL else as.numeric(parts[[2L]])
      )
    })

    filtered <- reactive({
      req(!is.null(catalog))
      rng <- sample_range()
      catalog_search(
        catalog,
        query = query() %||% "",
        organisms = input$organisms,
        sources = input$sources,
        min_samples = rng$min,
        max_samples = rng$max
      )
    })

    observeEvent(input$clear, {
      updateTextInput(session, "q", value = "")
      updateCheckboxGroupInput(session, "organisms", selected = character(0))
      updateCheckboxGroupInput(session, "sources", selected = character(0))
      updateRadioButtons(session, "samples", selected = "any")
    })

    output$catalog <- DT::renderDT(
      {
        validate(need(
          !is.null(catalog),
          "No catalog snapshot. Run Rscript data-raw/build_catalog.R"
        ))
        DT::datatable(
          filtered()[, CATALOG_TABLE_COLUMNS, drop = FALSE],
          selection = "single",
          rownames = FALSE,
          colnames = c("Study", "Organism", "Source", "Samples", "Title"),
          escape = TRUE,
          options = list(
            pageLength = 25,
            lengthMenu = c(10, 25, 50, 100),
            order = list(list(3, "desc")),
            scrollX = TRUE,
            columnDefs = list(list(targets = 4, width = "50%"))
          )
        )
      },
      server = TRUE
    )

    proxy <- DT::dataTableProxy("catalog")

    # Clearing the selection whenever the filters change is what keeps
    # selection honest. input$catalog_rows_selected indexes the frame that was
    # last rendered, so leaving a stale index in place while the data underneath
    # changes is how a click ends up resolving to the wrong study.
    observeEvent(filtered(), {
      DT::selectRows(proxy, NULL)
    })

    output$match_count <- renderText({
      req(!is.null(catalog))
      total <- format(nrow(catalog), big.mark = ",")
      shown <- nrow(filtered())
      if (shown == nrow(catalog)) {
        sprintf("Showing all %s studies.", total)
      } else {
        sprintf("%s of %s studies match.", format(shown, big.mark = ","), total)
      }
    })

    selected_row <- reactive({
      df <- filtered()
      i <- input$catalog_rows_selected
      if (!length(i) || i < 1L || i > nrow(df)) {
        return(NULL)
      }
      df[i, , drop = FALSE]
    })

    # Open the right pane on selection and close it when the selection goes.
    observeEvent(selected_row(), ignoreNULL = FALSE, {
      toggle_sidebar(
        "details_pane",
        open = !is.null(selected_row()),
        session = session
      )
    })

    output$details <- renderUI({
      row <- selected_row()
      if (is.null(row)) {
        return(p(class = "text-muted small", "Select a study in the table."))
      }
      links <- study_external_links(row)
      tagList(
        h5(row$study_title),
        div(
          class = "study-badges",
          span(class = "badge text-bg-light", row$project),
          span(class = "badge text-bg-light", row$organism),
          span(class = "badge text-bg-light", toupper(row$file_source)),
          span(
            class = "badge text-bg-light",
            paste(format(row$n_samples, big.mark = ","), "samples")
          )
        ),
        if (row$n_samples > 1000) {
          div(
            class = "alert alert-warning py-2 px-3 small",
            bsicons::bs_icon("exclamation-triangle"),
            " This study is large. It takes a long time to load and it needs a",
            " lot of memory."
          )
        },
        div(
          class = "abstract-box",
          if (nzchar(row$study_abstract)) {
            row$study_abstract
          } else {
            em("recount3 has no abstract for this study.")
          }
        ),
        div(
          class = "study-links",
          lapply(seq_along(links), function(i) {
            tags$a(
              href = links[[i]],
              target = "_blank",
              rel = "noopener",
              class = "small",
              names(links)[i],
              bsicons::bs_icon("box-arrow-up-right")
            )
          })
        ),
        input_task_button(
          session$ns("load"),
          "Load this study",
          icon = bsicons::bs_icon("download"),
          label_busy = "Loading...",
          class = "w-100 mt-3"
        )
      )
    })

    study <- reactiveVal(NULL)
    pending <- reactiveVal(NULL)

    # Download and log2 CPM both run on the daemon. mirai evaluates in a clean
    # process, so the two logic functions travel with the call and already
    # namespace-qualify their recount3 and SummarizedExperiment calls.
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
    }) |>
      bind_task_button("load")

    observeEvent(input$load, {
      row <- selected_row()
      if (is.null(row)) {
        showNotification("Select a study in the table first.", type = "warning")
        return()
      }
      # create_rse() reaches match.arg() through annotation_options(), and
      # match.arg() rejects a factor. catalog_proj_info() rebuilds the row as
      # plain character columns and restores the dropped project_type.
      info <- catalog_proj_info(row)
      pending(info)
      load_task$invoke(info)
      showNotification(
        paste(
          "Loading",
          info$project,
          "in the background.",
          "Keep browsing; you will be told when it is ready."
        ),
        type = "message"
      )
    })

    observeEvent(load_task$status(), {
      status <- load_task$status()
      if (!status %in% c("success", "error")) {
        return()
      }
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
          info$project,
          "loaded:",
          ncol(res$rse),
          "samples.",
          "See the Overview view."
        ),
        type = "message"
      )
    })

    study
  })
}
