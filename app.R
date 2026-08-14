# Recount Explorer: browse the recount3 catalog of uniformly processed RNA-seq
# studies and visualize any of them without writing code.
#
# App layer: page layout and module wiring only. Data access and computation
# live in R/logic_*.R (Shiny-free); each view is a module in R/mod_*.R. The
# single data contract between modules is the `study` reactive returned by the
# browser module: list(project, organism, source, rse, log_expr).
#
# UI is classic Shiny (no bslib) with a small bespoke stylesheet in www/app.css.

library(shiny)
library(ggplot2)

for (f in list.files("R", pattern = "[.][Rr]$", full.names = TRUE)) {
  source(f)
}

# Study loading runs on mirai daemons via ExtendedTask, so a slow download
# never blocks this process. Two daemons: two studies can load concurrently
# across sessions; further requests queue.
mirai::daemons(2)
onStop(function() mirai::daemons(0))

ui <- navbarPage(
  title = "Recount Explorer",
  header = tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "app.css")
  ),
  tabPanel("Browse studies", study_browser_ui("browser")),
  tabPanel("Study overview", study_overview_ui("overview")),
  tabPanel("Gene explorer", gene_explorer_ui("gene")),
  tabPanel("PCA", pca_explorer_ui("pca")),
  tabPanel("Export", export_ui("export"))
)

server <- function(input, output, session) {
  if (!recount3_available()) {
    showNotification(
      paste(
        "The recount3 package is not installed.",
        "Run BiocManager::install(\"recount3\") and restart the app."
      ),
      type = "error",
      duration = NULL
    )
  }

  study <- study_browser_server("browser")
  study_overview_server("overview", study)
  gene_state <- gene_explorer_server("gene", study)
  pca_state <- pca_explorer_server("pca", study)
  export_server("export", study, gene_state, pca_state)
}

shinyApp(ui, server)
