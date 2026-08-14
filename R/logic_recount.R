# recount3 access layer. Shiny-free: plain arguments in, plain data structures
# out, so everything here can be tested without a running app.

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
