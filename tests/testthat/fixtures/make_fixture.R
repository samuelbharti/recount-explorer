# Builds the small RangedSummarizedExperiment the tests run against, so no
# test ever needs the network or a real recount3 download.
#
# Regenerate with:
#   Rscript tests/testthat/fixtures/make_fixture.R
#
# The colData is deliberately awkward: a constant column, an all-NA column, a
# list column and a column with one level per sample, because those are the
# cases metadata_table() and metadata_group_choices() exist to handle.

set.seed(20260819)

n_genes <- 200
n_samples <- 12

counts <- matrix(
  rpois(n_genes * n_samples, lambda = 40),
  nrow = n_genes,
  dimnames = list(
    sprintf("ENSG%08d.1", seq_len(n_genes)),
    sprintf("SRR%07d", seq_len(n_samples))
  )
)

# A few genes get much larger counts in half the samples so the variance
# ranking used by top_variable_genes() has something real to find.
counts[1:5, 1:6] <- counts[1:5, 1:6] + 5000L

gene_name <- sprintf("GENE%d", seq_len(n_genes))
# gene_choices() falls back to the id when the symbol is missing or blank.
gene_name[3] <- NA_character_
gene_name[4] <- ""

col_data <- data.frame(
  tissue = rep(c("liver", "brain", "muscle"), each = 4),
  condition = rep(c("control", "treated"), times = 6),
  batch = rep("b1", n_samples),
  all_na = rep(NA_character_, n_samples),
  replicate_id = sprintf("rep%02d", seq_len(n_samples)),
  stringsAsFactors = FALSE
)
col_data$attributes <- lapply(
  seq_len(n_samples),
  function(i) c(paste0("key", i), paste0("value", i))
)
rownames(col_data) <- colnames(counts)

rse <- SummarizedExperiment::SummarizedExperiment(
  assays = list(counts = counts),
  rowData = S4Vectors::DataFrame(gene_name = gene_name),
  colData = S4Vectors::DataFrame(col_data)
)
rownames(rse) <- rownames(counts)

out <- file.path("tests", "testthat", "fixtures", "rse_small.rds")
saveRDS(rse, out, compress = "xz")
cat("wrote", out, "-", nrow(rse), "genes x", ncol(rse), "samples\n")
