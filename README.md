# Recount Explorer

A Shiny app for exploring [recount3](https://bioconductor.org/packages/recount3/):
hundreds of thousands of uniformly processed human and mouse RNA-seq samples
from SRA, GTEx, and TCGA. Anyone can pick a study from the catalog, pull it
through the recount3 API, and visualize it, no code required.

## Views

- **Browse studies**: filter the catalog by organism, data source, and sample
  count, then load a study.
- **Study overview**: headline stats, curated sample metadata, and a
  library-size vs detected-genes QC scatter.
- **Gene explorer**: search any gene and plot its expression (log2 CPM) split
  by a metadata group.
- **PCA**: sample-level PCA on the top variable genes, colored by metadata.

## Run it

```r
install.packages(c("shiny", "ggplot2", "DT"))
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
app.R                    App layer: page layout and module wiring only
R/
  logic_recount.R        recount3 access: catalog, study load, log2 CPM (Shiny-free)
  logic_analysis.R       QC, PCA, per-gene expression frames (Shiny-free)
  mod_study_browser.R    Catalog browsing, returns the shared `study` reactive
  mod_study_overview.R   Metadata and QC views
  mod_gene_explorer.R    Per-gene expression by group
  mod_pca_explorer.R     Sample-level PCA
www/app.css              Bespoke styles (stat tiles, spacing)
docs/plans/              Design plans
```

The design plan lives in
[docs/plans/recount-explorer.md](docs/plans/recount-explorer.md).
