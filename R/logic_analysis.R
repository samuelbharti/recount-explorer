# Analysis layer. Shiny-free: QC summaries, PCA, and per-gene expression
# frames consumed by the view modules.

row_variances <- function(mat) {
  rowSums((mat - rowMeans(mat))^2) / max(ncol(mat) - 1, 1)
}

top_variable_genes <- function(mat, n = 500) {
  v <- row_variances(mat)
  utils::head(order(v, decreasing = TRUE), min(n, nrow(mat)))
}

# PCA on the top variable genes of a genes x samples log-expression matrix.
# Returns sample scores for the first PCs plus variance explained.
run_pca <- function(log_expr, n_genes = 500, n_pcs = 10) {
  idx <- top_variable_genes(log_expr, n_genes)
  p <- stats::prcomp(t(log_expr[idx, , drop = FALSE]), center = TRUE)
  n_pcs <- min(n_pcs, ncol(p$x))
  list(
    scores = as.data.frame(p$x[, seq_len(n_pcs), drop = FALSE]),
    var_explained = (p$sdev^2 / sum(p$sdev^2))[seq_len(n_pcs)]
  )
}

# Per-sample QC: library size and number of detected genes.
sample_qc <- function(rse) {
  counts <- SummarizedExperiment::assay(rse, "counts")
  data.frame(
    sample = colnames(rse),
    library_size = colSums(counts),
    detected_genes = colSums(counts > 0)
  )
}

# Long data frame for one gene: expression plus a grouping column pulled from
# the sample metadata (or a single "all samples" group when none is chosen).
gene_expression_df <- function(study, gene_id, group_by = NULL) {
  cd <- as.data.frame(SummarizedExperiment::colData(study$rse))
  group <- if (!is.null(group_by) && nzchar(group_by) && group_by %in% names(cd)) {
    as.character(cd[[group_by]])
  } else {
    rep("all samples", ncol(study$rse))
  }
  group[is.na(group)] <- "NA"
  data.frame(
    sample = colnames(study$rse),
    expression = as.numeric(study$log_expr[gene_id, ]),
    group = group
  )
}
