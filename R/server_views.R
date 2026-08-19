# View half of the server: overview, gene expression, PCA and export.
#
# The plots stay server-rendered. ggplot2 draws them, renderPlot ships the
# image, and the React client mounts it with ShinyOutput. That keeps
# logic_plots.R as the single source for both the figure on the screen and the
# figure in the downloaded PDF, which is what makes them identical.
#
# Everything that is not a picture travels as JSON through reactive_output().

server_views <- function(input, output, session, study) {
  # ---- study state -----------------------------------------------------------

  # One object the whole client reads to know whether a study is loaded and
  # what the pickers should offer.
  output$study_state <- reactive_output({
    s <- study()
    if (is.null(s)) {
      return(list(loaded = FALSE))
    }
    choices <- gene_choices(s$rse)
    groups <- metadata_group_choices(s$rse)
    list(
      loaded = TRUE,
      project = s$project,
      organism = s$organism,
      source = s$source,
      n_samples = ncol(s$rse),
      n_genes = nrow(s$rse),
      # The gene picker is searched on the client, so it gets labels and ids
      # together. 60,000 genes is a large payload, so it is sent once for each
      # study rather than on every keystroke.
      genes = unname(lapply(
        seq_along(choices),
        function(i) list(id = unname(choices[[i]]), label = names(choices)[i])
      )),
      groups = I(groups)
    )
  })

  # ---- overview --------------------------------------------------------------

  output$metadata_table <- reactive_output({
    s <- study()
    if (is.null(s)) {
      return(NULL)
    }
    tbl <- metadata_table(s$rse)
    list(
      columns = I(names(tbl)),
      rows = df_to_rows(utils::head(tbl, 200)),
      truncated = nrow(tbl) > 200,
      n_rows = nrow(tbl)
    )
  })

  output$qc_plot <- renderPlot({
    s <- study()
    validate(need(s, "Load a study first."))
    plot_qc(sample_qc(s$rse))
  })

  # ---- gene explorer ---------------------------------------------------------

  gene_label <- reactive({
    s <- study()
    if (is.null(s) || !isTruthy(input$gene)) {
      return("")
    }
    label <- names(which(gene_choices(s$rse) == input$gene))
    if (length(label)) label[[1L]] else input$gene
  })

  gene_plot_obj <- reactive({
    s <- study()
    req(s, input$gene)
    df <- gene_expression_df(s, input$gene, input$group_by)
    plot_gene_expression(
      df,
      geom = input$geom %||% "box",
      gene_label = gene_label(),
      group_label = if (isTruthy(input$group_by)) input$group_by else NULL
    )
  })

  output$gene_plot <- renderPlot({
    validate(need(study(), "Load a study first."))
    validate(need(input$gene, "Search for a gene."))
    gene_plot_obj()
  })

  # ---- PCA -------------------------------------------------------------------

  pca <- reactive({
    s <- study()
    req(s)
    run_pca(s$log_expr, n_genes = input$n_genes %||% 500)
  })

  pca_frame <- reactive({
    s <- study()
    req(s)
    scores <- pca()$scores
    color_by <- input$color_by
    scores$color <- if (isTruthy(color_by)) {
      as.character(as.data.frame(SummarizedExperiment::colData(s$rse))[[
        color_by
      ]])
    } else {
      "sample"
    }
    scores
  })

  pca_plot_obj <- reactive({
    plot_pca_scatter(
      pca_frame(),
      pca()$var_explained,
      color_label = if (isTruthy(input$color_by)) input$color_by else NULL
    )
  })

  output$pca_plot <- renderPlot({
    validate(need(study(), "Load a study first."))
    pca_plot_obj()
  })

  output$scree_plot <- renderPlot({
    validate(need(study(), "Load a study first."))
    plot_pca_scree(pca()$var_explained)
  })

  # ---- export ----------------------------------------------------------------

  gene_state <- reactive({
    list(
      gene = input$gene %||% "",
      gene_label = gene_label(),
      group_by = input$group_by %||% "",
      geom = input$geom %||% "box"
    )
  })

  pca_state <- reactive({
    list(
      n_genes = input$n_genes %||% 500,
      color_by = input$color_by %||% ""
    )
  })

  output$reproduction_script <- reactive_output({
    s <- study()
    if (is.null(s)) {
      return(NULL)
    }
    build_reproduction_script(s, gene_state(), pca_state())
  })

  output$download_rse <- downloadHandler(
    filename = function() paste0(req(study())$project, ".rds"),
    content = function(file) saveRDS(req(study())$rse, file)
  )

  output$download_expression <- downloadHandler(
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

  output$download_metadata <- downloadHandler(
    filename = function() paste0(req(study())$project, "_metadata.csv"),
    content = function(file) {
      utils::write.csv(
        flatten_coldata(req(study())$rse),
        file,
        row.names = FALSE
      )
    }
  )

  output$download_script <- downloadHandler(
    filename = function() paste0(req(study())$project, "_recount_explorer.R"),
    content = function(file) {
      writeLines(
        build_reproduction_script(req(study()), gene_state(), pca_state()),
        file
      )
    }
  )

  output$download_gene_pdf <- downloadHandler(
    filename = function() {
      paste0(req(study())$project, "_", req(input$gene), ".pdf")
    },
    content = function(file) {
      ggplot2::ggsave(file, plot = gene_plot_obj(), width = 9, height = 6)
    }
  )

  output$download_pca_pdf <- downloadHandler(
    filename = function() paste0(req(study())$project, "_pca.pdf"),
    content = function(file) {
      ggplot2::ggsave(file, plot = pca_plot_obj(), width = 9, height = 6)
    }
  )

  invisible(NULL)
}
