# Study browser module: search the recount3 catalog and load one study.
#
# The table is bound to the whole catalog, not to a filtered copy, and every
# filter runs inside DataTables. That is what keeps row selection honest.
# input$catalog_rows_selected indexes the frame handed to datatable(), before
# sorting and before search, so while that frame never changes the index always
# points at the study the user clicked. Rebuilding a filtered frame on each
# control change is what used to let the selection lag one flush behind.
#
# Loading runs off the main R process (ExtendedTask plus mirai daemon), so a
# slow download never blocks this session or any other. The server returns the
# app-wide `study` reactive:
# list(project, organism, source, rse, log_expr), NULL until a study is loaded.

# Columns the table renders, in order. study_abstract is present so the global
# search covers abstract text, and hidden through columnDefs. It has to stay in
# the data: the server-side filter compares the client column count against
# ncol(data) and returns an empty table when the two disagree.
BROWSER_COLUMNS <- c(
  "project",
  "organism",
  "file_source",
  "n_samples",
  "study_title",
  "study_abstract"
)

BROWSER_COLNAMES <- c(
  "Study",
  "Organism",
  "Source",
  "Samples",
  "Title",
  "Abstract"
)

study_browser_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(
      class = "browser-head",
      h4("Study catalog"),
      div(class = "browser-meta", textOutput(ns("provenance"), inline = TRUE))
    ),
    DT::DTOutput(ns("catalog")),
    div(class = "browser-meta", textOutput(ns("match_count"), inline = TRUE)),
    hr(),
    fluidRow(
      column(8, uiOutput(ns("details"))),
      column(
        4,
        actionButton(
          ns("load"),
          "Load selected study",
          class = "btn-primary btn-block"
        ),
        helpText(
          "Loading runs in the background.",
          "Keep browsing while the study downloads."
        )
      )
    )
  )
}

study_browser_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    # Read once for each process. Every session shares this one data frame, and
    # DT serves pages out of it without making a copy.
    catalog_all <- reactive({
      read_catalog()
    })

    output$provenance <- renderText({
      catalog_summary_line(catalog_all())
    })

    # The rendered frame differs from storage in one way: organism and source
    # become factors so DataTables draws a select box for them instead of a
    # free text box. Storage keeps them as character because create_rse()
    # rejects a factor, and selection resolves against storage, not this frame.
    display_df <- reactive({
      df <- catalog_all()
      req(df)
      out <- df[, BROWSER_COLUMNS, drop = FALSE]
      out$organism <- factor(out$organism)
      out$file_source <- factor(out$file_source)
      out
    })

    output$catalog <- DT::renderDT(
      {
        validate(need(
          recount3_available(),
          paste(
            "The recount3 package is not installed.",
            "Run BiocManager::install(\"recount3\") and restart the app."
          )
        ))
        validate(need(
          catalog_all(),
          paste(
            "No catalog snapshot was found at",
            paste0(catalog_snapshot_path(), "."),
            "Run Rscript data-raw/build_catalog.R to build one."
          )
        ))
        DT::datatable(
          display_df(),
          selection = "single",
          rownames = FALSE,
          filter = "top",
          colnames = BROWSER_COLNAMES,
          escape = TRUE,
          options = list(
            pageLength = 15,
            lengthMenu = c(10, 15, 25, 50, 100),
            order = list(list(3, "desc")),
            # The global search greps about 20 MB of abstract text in R on
            # every keystroke. Waiting for a pause in the typing turns that
            # into one pass for each search rather than one for each letter.
            searchDelay = 400,
            deferRender = TRUE,
            columnDefs = list(
              # Hidden but still searchable. DataTables treats visible and
              # searchable as independent, which is what lets a search match
              # abstract text without a column of prose on the screen.
              list(targets = 5, visible = FALSE),
              list(targets = 5, orderable = FALSE),
              list(targets = 4, width = "45%")
            )
          )
        )
      },
      server = TRUE
    )

    output$match_count <- renderText({
      df <- catalog_all()
      req(df)
      total <- format(nrow(df), big.mark = ",")
      shown <- length(input$catalog_rows_all)
      if (!shown || shown == nrow(df)) {
        return(sprintf("Showing all %s studies.", total))
      }
      sprintf("%s of %s studies match.", format(shown, big.mark = ","), total)
    })

    # Resolve the click against the master catalog, not against the rendered
    # frame. The bounds check covers the one moment the two can disagree: a
    # catalog reload clears the selection, but the input can lag by one flush.
    selected_row <- reactive({
      df <- catalog_all()
      i <- input$catalog_rows_selected
      if (is.null(df) || !length(i) || i < 1L || i > nrow(df)) {
        return(NULL)
      }
      df[i, , drop = FALSE]
    })

    output$details <- renderUI({
      row <- selected_row()
      if (is.null(row)) {
        return(p(
          class = "muted",
          "Select a study in the table to read its abstract."
        ))
      }
      links <- study_external_links(row)
      tagList(
        h4(row$study_title),
        div(
          class = "study-chips",
          span(class = "chip", row$project),
          span(class = "chip", row$organism),
          span(class = "chip", toupper(row$file_source)),
          span(
            class = "chip",
            paste(format(row$n_samples, big.mark = ","), "samples")
          )
        ),
        if (row$n_samples > 1000) {
          div(
            class = "study-warning",
            paste(
              "CAUTION: this study is large. It takes a long time to load",
              "and it needs a lot of memory."
            )
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
              names(links)[i]
            )
          })
        )
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
      row <- selected_row()
      if (is.null(row)) {
        showNotification("Select a study in the table first.", type = "warning")
        return()
      }
      # create_rse() reaches match.arg() through annotation_options(), and
      # match.arg() errors on a factor. catalog_proj_info() rebuilds the row as
      # plain character columns and restores the project_type that the stored
      # schema drops.
      info <- catalog_proj_info(row)
      pending(info)
      load_task$invoke(info)
      updateActionButton(session, "load", label = "Loading...")
      showNotification(
        paste(
          "Loading",
          info$project,
          "in the background.",
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
          info$project,
          "loaded:",
          ncol(res$rse),
          "samples.",
          "See the Study overview tab."
        ),
        type = "message"
      )
    })

    study
  })
}
