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
