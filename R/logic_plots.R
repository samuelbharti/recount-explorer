# Plot builders. Shiny-free: shared by the module renderers and the PDF
# download handlers so the exported figure is exactly what is on screen.

plot_qc <- function(qc) {
  ggplot2::ggplot(qc, ggplot2::aes(x = library_size, y = detected_genes)) +
    ggplot2::geom_point(alpha = 0.6, size = 2) +
    ggplot2::scale_x_log10(labels = scales::label_comma()) +
    ggplot2::scale_y_continuous(labels = scales::label_comma()) +
    ggplot2::labs(x = "Library size (log scale)", y = "Detected genes") +
    ggplot2::theme_minimal(base_size = 14)
}

plot_gene_expression <- function(df, geom = c("box", "violin"),
                                 gene_label = NULL, group_label = NULL) {
  geom <- match.arg(geom)
  gg <- ggplot2::ggplot(df, ggplot2::aes(x = group, y = expression, fill = group))
  gg <- if (geom == "violin") {
    gg + ggplot2::geom_violin(alpha = 0.7)
  } else {
    gg + ggplot2::geom_boxplot(alpha = 0.7, outlier.shape = NA)
  }
  gg +
    ggplot2::geom_jitter(width = 0.15, alpha = 0.4, size = 1.5) +
    ggplot2::labs(x = group_label, y = "log2 CPM", title = gene_label) +
    ggplot2::guides(fill = "none") +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
}

plot_pca_scatter <- function(scores, var_explained, color_label = NULL) {
  pct <- function(i) sprintf("PC%d (%.1f%%)", i, 100 * var_explained[i])
  gg <- ggplot2::ggplot(scores, ggplot2::aes(x = PC1, y = PC2, color = color)) +
    ggplot2::geom_point(alpha = 0.7, size = 2.5) +
    ggplot2::labs(x = pct(1), y = pct(2), color = color_label) +
    ggplot2::theme_minimal(base_size = 14)
  if (is.null(color_label)) {
    gg <- gg + ggplot2::guides(color = "none")
  }
  gg
}

plot_pca_scree <- function(var_explained) {
  df <- data.frame(
    pc = factor(seq_along(var_explained)),
    var = 100 * var_explained
  )
  ggplot2::ggplot(df, ggplot2::aes(x = pc, y = var)) +
    ggplot2::geom_col() +
    ggplot2::labs(x = "PC", y = "% variance") +
    ggplot2::theme_minimal(base_size = 14)
}
