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
