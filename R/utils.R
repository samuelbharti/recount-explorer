# Small shared helpers.

# Null coalescing, defined locally so the app also runs on R < 4.4.
`%||%` <- function(x, y) if (is.null(x)) y else x
