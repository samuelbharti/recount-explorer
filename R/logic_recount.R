# recount3 access layer. Shiny-free: plain arguments in, plain data structures
# out, so everything here can be tested without a running app.

# Is recount3 installed? Answered without loading it.
#
# system.file() looks on disk and returns "" when the package is absent. Use
# this on the main process. requireNamespace() would answer the same question
# but loads the package to do it, which costs 5.3 seconds and pulls in 98
# namespaces. Browsing the catalog never needs recount3: the catalog is a local
# file and create_rse() runs on a mirai daemon in its own process.
recount3_installed <- function() {
  nzchar(system.file(package = "recount3"))
}

# Is recount3 loadable? Call this only where loading it is wanted anyway,
# which means the daemon, never the main process during a browse.
recount3_available <- function() {
  requireNamespace("recount3", quietly = TRUE)
}

# Catalog of available studies for one organism. Returns a data.frame with
# project, organism, file_source, project_home, project_type, n_samples.
# recount3 caches the catalog via BiocFileCache, so only the first call
# per machine hits the network.
fetch_project_catalog <- function(organism = c("human", "mouse")) {
  organism <- match.arg(organism)
  projects <- recount3::available_projects(organism = organism)
  projects[projects$project_type == "data_sources", , drop = FALSE]
}

# Load one study (a single row of the catalog) as a RangedSummarizedExperiment
# with a "counts" assay of scaled read counts.
load_study <- function(proj_info) {
  stopifnot(is.data.frame(proj_info), nrow(proj_info) == 1)
  rse <- recount3::create_rse(proj_info)
  SummarizedExperiment::assay(rse, "counts") <- recount3::transform_counts(rse)
  rse
}

# log2 CPM from the scaled counts, computed once at load time and shared by
# the gene explorer and PCA modules.
log_cpm <- function(rse) {
  counts <- SummarizedExperiment::assay(rse, "counts")
  lib <- pmax(colSums(counts), 1)
  log2(sweep(counts, 2, lib, "/") * 1e6 + 1)
}

# Named vector for the gene selectize: values are gene ids, labels are
# "symbol (id)" so both are searchable.
gene_choices <- function(rse) {
  rd <- SummarizedExperiment::rowData(rse)
  ids <- rownames(rse)
  symbols <- if ("gene_name" %in% names(rd)) as.character(rd$gene_name) else ids
  symbols[is.na(symbols) | symbols == ""] <- ids[is.na(symbols) | symbols == ""]
  stats::setNames(ids, paste0(symbols, " (", ids, ")"))
}

# Metadata columns usable for grouping: categorical, with a sane number of
# levels for a boxplot or a color scale.
metadata_group_choices <- function(rse, max_levels = 30) {
  cd <- as.data.frame(SummarizedExperiment::colData(rse))
  ok <- vapply(
    cd,
    function(x) {
      x <- x[!is.na(x)]
      (is.character(x) || is.factor(x) || is.logical(x)) &&
        length(unique(x)) >= 2 &&
        length(unique(x)) <= max_levels
    },
    logical(1)
  )
  names(cd)[ok]
}

# Curated sample metadata for display: drop columns that are all NA or
# constant, cap the column count so DT stays responsive.
metadata_table <- function(rse, max_cols = 40) {
  cd <- as.data.frame(SummarizedExperiment::colData(rse))
  informative <- vapply(
    cd,
    function(x) {
      x <- x[!is.na(x)]
      length(x) > 0 && length(unique(x)) > 1 && !is.list(x)
    },
    logical(1)
  )
  keep <- names(cd)[informative]
  keep <- utils::head(keep, max_cols)
  cbind(sample = colnames(rse), cd[, keep, drop = FALSE])
}

# ---- staged loading ----------------------------------------------------------

# Loading happens on a mirai daemon, which is a separate process with no way to
# push a value back before it finishes. So the daemon writes its current step
# to a small file and the main process reads it. Returning intermediate values
# instead would mean serializing the whole RangedSummarizedExperiment twice.
#
# The write is atomic: a temporary file and a rename, so a reader never catches
# a half-written line.
write_load_progress <- function(path, step, total, label) {
  if (is.null(path) || !nzchar(path)) {
    return(invisible(NULL))
  }
  tmp <- paste0(path, ".tmp")
  writeLines(paste(step, total, label, sep = "\t"), tmp)
  if (!file.rename(tmp, path)) {
    file.copy(tmp, path, overwrite = TRUE)
    unlink(tmp)
  }
  invisible(NULL)
}

read_load_progress <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    return(NULL)
  }
  line <- tryCatch(
    readLines(path, n = 1L, warn = FALSE),
    error = function(e) character()
  )
  if (!length(line) || !nzchar(line[[1L]])) {
    return(NULL)
  }
  parts <- strsplit(line[[1L]], "\t", fixed = TRUE)[[1L]]
  if (length(parts) < 3L) {
    return(NULL)
  }
  list(
    step = as.integer(parts[[1L]]),
    total = as.integer(parts[[2L]]),
    label = parts[[3L]]
  )
}

LOAD_STAGES <- 6L

# Load one study, reporting each step as it goes.
#
# The first three steps are the files create_rse() needs, fetched here rather
# than inside it, which is what turns one opaque call into named progress. The
# last three are the work that happens once the files are on disk.
load_study_staged <- function(proj_info, progress_file = NULL) {
  note <- function(step, label) {
    write_load_progress(progress_file, step, LOAD_STAGES, label)
  }

  prefetch_study_files(
    proj_info,
    on_stage = function(step, total, label) note(step, label)
  )

  note(4L, "Building the study object")
  rse <- recount3::create_rse(proj_info)

  note(5L, "Scaling the counts")
  SummarizedExperiment::assay(rse, "counts") <- recount3::transform_counts(rse)

  note(6L, "Computing log2 CPM")
  list(rse = rse, log_expr = log_cpm(rse))
}
