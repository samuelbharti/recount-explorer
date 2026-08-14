# Recount Explorer

A Shiny app for exploring [recount3](https://bioconductor.org/packages/recount3/):
hundreds of thousands of uniformly processed human and mouse RNA-seq samples
from SRA, GTEx, and TCGA. Anyone can pick a study from the catalog, pull it
through the recount3 API, and visualize it, no code required.

## Views

- **Browse studies**: filter the catalog by organism, data source, and sample
  count, then load a study. Loading runs on a background process (ExtendedTask
  plus mirai), so the app stays responsive while a study downloads.
- **Study overview**: headline stats, curated sample metadata, and a
  library-size vs detected-genes QC scatter.
- **Gene explorer**: search any gene and plot its expression (log2 CPM) split
  by a metadata group.
- **PCA**: sample-level PCA on the top variable genes, colored by metadata.
- **Export**: download the RangedSummarizedExperiment (.rds), the log2 CPM
  matrix (.csv.gz), the full sample metadata (.csv), and a standalone R script
  that reproduces the current session with citation-ready provenance. The gene
  and PCA views also download their exact on-screen plot as PDF.

## Run it

```r
install.packages(c("shiny", "ggplot2", "DT", "mirai"))
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}
BiocManager::install("recount3")

shiny::runApp()
```

The first catalog fetch and each first study load download data from the
recount3 servers; recount3 caches everything locally via BiocFileCache, so
repeat loads are fast. Large studies (GTEx, TCGA) take a while and need a lot
of memory; start with an SRA study of a few dozen samples.

## Structure

The UI is classic Shiny (no bslib) with a small bespoke stylesheet.

```
app.R                    App layer: page layout, mirai daemons, module wiring
R/
  logic_recount.R        recount3 access: catalog, study load, log2 CPM (Shiny-free)
  logic_analysis.R       QC, PCA, per-gene expression frames (Shiny-free)
  logic_plots.R          Plot builders shared by views and PDF downloads (Shiny-free)
  logic_export.R         Reproducible script builder, CSV export frames (Shiny-free)
  mod_study_browser.R    Catalog browsing, async load, returns the shared `study` reactive
  mod_study_overview.R   Metadata and QC views
  mod_gene_explorer.R    Per-gene expression by group, plot PDF download
  mod_pca_explorer.R     Sample-level PCA, plot PDF download
  mod_export.R           Data downloads and reproducible script
  utils.R                Small helpers
www/app.css              Bespoke styles (stat tiles, spacing)
docs/plans/              Design plans
```

The design plan lives in
[docs/plans/recount-explorer.md](docs/plans/recount-explorer.md).
