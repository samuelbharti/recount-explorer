# Plot builders. Shiny-free: shared by the view renderers and the PDF download
# handlers so the exported figure is exactly what is on screen.
#
# Every builder takes `dark`. ggplot2 draws on a white canvas whatever the page
# looks like, so without this the figures glare in dark mode. The colours come
# from _brand.yml through R/logic_brand.R, the same file bslib reads for the
# Bootstrap theme, so the figures and the interface cannot drift apart.
#
# `dark` defaults to FALSE, which is what the PDF downloads want: a figure
# going into a document or onto paper should be light whatever the screen was.

plot_palette <- function(dark = FALSE) {
  brand_plot_palette(dark)
}

theme_recount <- function(dark = FALSE, base_size = 14) {
  col <- plot_palette(dark)
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = col$bg, colour = NA),
      panel.background = ggplot2::element_rect(fill = col$bg, colour = NA),
      legend.background = ggplot2::element_rect(fill = col$bg, colour = NA),
      legend.key = ggplot2::element_rect(fill = col$bg, colour = NA),
      text = ggplot2::element_text(colour = col$fg),
      axis.text = ggplot2::element_text(colour = col$muted),
      axis.title = ggplot2::element_text(colour = col$fg),
      plot.title = ggplot2::element_text(colour = col$fg),
      legend.text = ggplot2::element_text(colour = col$muted),
      legend.title = ggplot2::element_text(colour = col$fg),
      panel.grid.major = ggplot2::element_line(colour = col$grid),
      panel.grid.minor = ggplot2::element_line(
        colour = col$grid,
        linewidth = 0.25
      )
    )
}

plot_qc <- function(qc, dark = FALSE) {
  col <- plot_palette(dark)
  ggplot2::ggplot(qc, ggplot2::aes(x = library_size, y = detected_genes)) +
    ggplot2::geom_point(alpha = 0.7, size = 2.2, colour = col$point) +
    ggplot2::scale_x_log10(labels = scales::label_comma()) +
    ggplot2::scale_y_continuous(labels = scales::label_comma()) +
    ggplot2::labs(x = "Library size (log scale)", y = "Detected genes") +
    theme_recount(dark)
}

plot_gene_expression <- function(
  df,
  geom = c("box", "violin"),
  gene_label = NULL,
  group_label = NULL,
  dark = FALSE
) {
  geom <- match.arg(geom)
  col <- plot_palette(dark)
  gg <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = group, y = expression, fill = group)
  )
  gg <- if (geom == "violin") {
    gg + ggplot2::geom_violin(alpha = 0.75, colour = NA)
  } else {
    gg +
      ggplot2::geom_boxplot(
        alpha = 0.75,
        outlier.shape = NA,
        colour = col$muted
      )
  }
  gg +
    ggplot2::geom_jitter(
      width = 0.15,
      alpha = 0.45,
      size = 1.5,
      colour = col$fg
    ) +
    ggplot2::labs(x = group_label, y = "log2 CPM", title = gene_label) +
    ggplot2::guides(fill = "none") +
    brand_fill_scale() +
    theme_recount(dark) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 30, hjust = 1)
    )
}

plot_pca_scatter <- function(
  scores,
  var_explained,
  color_label = NULL,
  dark = FALSE
) {
  col <- plot_palette(dark)
  pct <- function(i) sprintf("PC%d (%.1f%%)", i, 100 * var_explained[i])
  gg <- ggplot2::ggplot(scores, ggplot2::aes(x = PC1, y = PC2, color = color)) +
    ggplot2::geom_point(alpha = 0.8, size = 2.5) +
    ggplot2::labs(x = pct(1), y = pct(2), color = color_label) +
    theme_recount(dark)
  if (is.null(color_label)) {
    return(
      gg +
        ggplot2::guides(color = "none") +
        ggplot2::scale_color_manual(values = col$point)
    )
  }
  gg + brand_colour_scale()
}

plot_pca_scree <- function(var_explained, dark = FALSE) {
  col <- plot_palette(dark)
  df <- data.frame(
    pc = factor(seq_along(var_explained)),
    var = 100 * var_explained
  )
  ggplot2::ggplot(df, ggplot2::aes(x = pc, y = var)) +
    ggplot2::geom_col(fill = col$point) +
    ggplot2::labs(x = "PC", y = "% variance") +
    theme_recount(dark)
}

# Warm categorical scales, so a grouped plot does not fall back to ggplot2's
# default hues and undo the brand.
brand_fill_scale <- function() {
  ggplot2::scale_fill_manual(
    values = brand_qualitative(),
    na.value = "#888888"
  )
}

brand_colour_scale <- function() {
  ggplot2::scale_colour_manual(
    values = brand_qualitative(),
    na.value = "#888888"
  )
}
