# Small shared helpers.

# Null coalescing, defined locally so the app also runs on R < 4.4.
`%||%` <- function(x, y) if (is.null(x)) y else x

# Named choices for a checkbox group, with the number of studies behind each
# option. Seeing "gtex (32)" before clicking saves a click that returns almost
# nothing.
labelled_counts <- function(values, column) {
  counts <- table(column)
  labels <- vapply(
    values,
    function(v) {
      n <- if (v %in% names(counts)) counts[[v]] else 0L
      sprintf("%s (%s)", v, format(n, big.mark = ","))
    },
    character(1)
  )
  stats::setNames(values, labels)
}

# Turn a "10-50" or "200-Inf" preset into a range. "any" means no bound.
preset_range <- function(preset) {
  preset <- preset %||% "any"
  if (identical(preset, "any")) {
    return(list(min = NULL, max = NULL))
  }
  parts <- strsplit(preset, "-", fixed = TRUE)[[1L]]
  list(
    min = as.numeric(parts[[1L]]),
    max = if (identical(parts[[2L]], "Inf")) NULL else as.numeric(parts[[2L]])
  )
}

# 8236451 becomes "8.2 M". Read counts run to tens of millions, and the digits
# past the first two carry no meaning for a reader scanning a header.
format_reads <- function(n) {
  n <- as.numeric(n)
  if (length(n) != 1L || is.na(n)) {
    return("unknown")
  }
  if (n >= 1e9) {
    return(sprintf("%.1f B", n / 1e9))
  }
  if (n >= 1e6) {
    return(sprintf("%.1f M", n / 1e6))
  }
  if (n >= 1e3) {
    return(sprintf("%.0f K", n / 1e3))
  }
  format(round(n), big.mark = ",")
}

# The pair of controls every scatter view needs.
#
# Point size and labelling are the two things a reader wants to change on a
# scatter, and three views offer them, so the control block is written once
# here rather than three times in the modules.
plot_controls_ui <- function(ns, size_default = 2.2, label_default = FALSE) {
  shiny::tagList(
    shiny::sliderInput(
      ns("point_size"),
      "Point size",
      min = 0.5,
      max = 6,
      value = size_default,
      step = 0.5,
      ticks = FALSE
    ),
    shiny::checkboxInput(
      ns("label_points"),
      "Label points",
      value = label_default
    ),
    shiny::helpText(
      "Above 30 points only the samples furthest from the middle are named."
    )
  )
}
