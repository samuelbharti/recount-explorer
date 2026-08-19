# Catalog half of the server: search, selection, and the background study load.
#
# There is no UI here. The React client owns every pixel; this file publishes
# JSON through reactive_output() and reads plain inputs the client sets. The
# return value is the app-wide `study` reactive that the view server consumes:
# list(project, organism, source, rse, log_expr), NULL until a study loads.

# Columns the client renders in the results table. The abstract is not sent
# with the page: at roughly 900 characters a row it would be most of the
# payload, and the client only needs it for the one selected study.
CATALOG_ROW_COLUMNS <- c(
  "uid",
  "project",
  "organism",
  "file_source",
  "n_samples",
  "study_title"
)

server_catalog <- function(input, output, session) {
  catalog <- read_catalog()

  output$catalog_ready <- reactive_output({
    !is.null(catalog)
  })

  output$catalog_summary <- reactive_output({
    catalog_summary_line(catalog)
  })

  # Everything the client needs to draw its filter controls, so no list of
  # organisms or sources is hardcoded in the front end.
  output$catalog_facets <- reactive_output({
    if (is.null(catalog)) {
      return(NULL)
    }
    list(
      # I() keeps these arrays when a filter leaves only one level. Without
      # it a length-1 vector serializes as a bare string and .map() fails.
      organisms = I(sort(unique(catalog$organism))),
      sources = I(catalog_sources(catalog)),
      total = nrow(catalog),
      max_samples = max(catalog$n_samples)
    )
  })

  results <- reactive({
    req(!is.null(catalog))
    catalog_search(
      catalog,
      query = input$q %||% "",
      organisms = input$organisms,
      sources = input$sources,
      min_samples = input$min_samples,
      max_samples = input$max_samples,
      sort_by = input$sort_by %||% "n_samples",
      sort_dir = input$sort_dir %||% "desc"
    )
  })

  output$catalog_page <- reactive_output({
    if (is.null(catalog)) {
      return(NULL)
    }
    page <- catalog_page(
      results(),
      page = input$page %||% 1L,
      page_size = input$page_size %||% 25L
    )
    list(
      rows = df_to_rows(page$rows[, CATALOG_ROW_COLUMNS, drop = FALSE]),
      matched = page$matched,
      total = nrow(catalog),
      page = page$page,
      pages = page$pages,
      from = page$from,
      to = page$to
    )
  })

  # Selection travels as a uid rather than a row number. A row number would go
  # stale the moment the query changed, and would point at a different study.
  selected <- reactive({
    uid <- input$selected_uid
    if (is.null(catalog) || is.null(uid) || !nzchar(uid)) {
      return(NULL)
    }
    row <- catalog[catalog$uid == uid, , drop = FALSE]
    if (nrow(row) != 1L) {
      return(NULL)
    }
    row
  })

  output$study_details <- reactive_output({
    row <- selected()
    if (is.null(row)) {
      return(NULL)
    }
    links <- study_external_links(row)
    list(
      uid = row$uid,
      project = row$project,
      organism = row$organism,
      source = row$file_source,
      n_samples = row$n_samples,
      title = row$study_title,
      abstract = row$study_abstract,
      large = row$n_samples > 1000,
      links = unname(lapply(
        seq_along(links),
        function(i) list(label = names(links)[i], href = unname(links[[i]]))
      ))
    )
  })

  study <- reactiveVal(NULL)
  pending <- reactiveVal(NULL)

  # Download and log2 CPM both run on a mirai daemon. mirai evaluates in a
  # clean process, so the two logic functions travel with the call and already
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
  })

  # The client reads this to drive its own busy state, so the button knows it
  # is loading without a second round trip.
  output$load_status <- reactive_output({
    list(
      status = load_task$status(),
      project = pending()$project %||% NULL
    )
  })

  observeEvent(input$load_study, {
    if (identical(load_task$status(), "running")) {
      showNotification(
        paste("Still loading", pending()$project, ", one study at a time."),
        type = "warning"
      )
      return()
    }
    row <- selected()
    if (is.null(row)) {
      showNotification("Select a study first.", type = "warning")
      return()
    }
    # create_rse() reaches match.arg() through annotation_options(), and
    # match.arg() rejects a factor. catalog_proj_info() rebuilds the row as
    # plain character columns and restores the dropped project_type.
    info <- catalog_proj_info(row)
    pending(info)
    load_task$invoke(info)
    showNotification(
      paste("Loading", info$project, "in the background."),
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
      paste(info$project, "loaded:", ncol(res$rse), "samples."),
      type = "message"
    )
  })

  study
}
