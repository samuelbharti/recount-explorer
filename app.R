# Recount Explorer: browse the recount3 catalog of uniformly processed RNA-seq
# studies and visualize any of them without writing code.
#
# The interface is React. shinyreact serves a built bundle from www/ and this
# process runs reactive logic only, with no Shiny UI objects. Computation lives
# in R/logic_*.R, which stays Shiny-free and testable. R/server_*.R publishes
# JSON with reactive_output() and renders the plots that the client mounts with
# ShinyOutput.
#
# The one data contract between the two server halves is the `study` reactive:
# list(project, organism, source, rse, log_expr), NULL until a study loads.

library(shiny)
library(shinyreact)
library(ggplot2)

for (f in list.files("R", pattern = "[.][Rr]$", full.names = TRUE)) {
  source(f)
}

# Study loading runs on mirai daemons through ExtendedTask, so a slow download
# never blocks this process. Two daemons: two studies can load at once across
# sessions, and further requests queue.
mirai::daemons(2)
onStop(function() mirai::daemons(0))

# Read the catalog and warm the search text once at startup rather than on the
# first user keystroke. Building the search text costs about half a second.
local({
  catalog <- read_catalog()
  if (is.null(catalog)) {
    warning(
      "No catalog snapshot at ",
      catalog_snapshot_path(),
      ". Run: Rscript data-raw/build_catalog.R",
      call. = FALSE
    )
  } else {
    invisible(catalog_haystack(catalog))
    message("Recount Explorer: ", catalog_summary_line(catalog))
  }
})

ui <- page_react_html("www/index.html")

server <- function(input, output, session) {
  # recount3_installed(), not recount3_available(): the second one loads the
  # package, and nothing on this path needs it loaded.
  if (!recount3_installed()) {
    showNotification(
      paste(
        "The recount3 package is not installed.",
        "Run BiocManager::install(\"recount3\") and restart the app."
      ),
      type = "error",
      duration = NULL
    )
  }

  study <- server_catalog(input, output, session)
  server_views(input, output, session, study)
}

shinyApp(ui, server)
