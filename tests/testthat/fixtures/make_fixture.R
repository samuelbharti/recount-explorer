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
  # One level per sample but two samples short of unique, so it is a real
  # grouping column with more levels than the eight named brand colours. This
  # is the case that used to error with "Insufficient values in manual scale".
  donor = c(sprintf("d%02d", seq_len(n_samples - 2L)), "d01", "d02"),
  stringsAsFactors = FALSE
)
col_data$attributes <- lapply(
  seq_len(n_samples),
  function(i) c(paste0("key", i), paste0("value", i))
)

# The recount3 quality metrics the Quality view reads. Named exactly as
# recount3 names them, because the app looks them up by name.
col_data[["recount_qc.star.uniquely_mapped_reads_."]] <-
  round(seq(88, 94, length.out = n_samples), 2)
col_data[["recount_qc.gene_fc.all_."]] <-
  round(seq(80, 89, length.out = n_samples), 2)
col_data[["recount_qc.aligned_reads..chrm"]] <-
  round(seq(2.1, 8.9, length.out = n_samples), 2)
col_data[["recount_qc.intron_sum_."]] <-
  round(seq(1.3, 4.9, length.out = n_samples), 2)
col_data[["recount_qc.star.._of_reads_mapped_to_multiple_loci"]] <-
  round(seq(2.9, 7.2, length.out = n_samples), 2)
col_data[["recount_qc.bc_frag.mean_length"]] <-
  round(seq(966, 5202, length.out = n_samples), 2)

# Chromosome X and Y percentages, deliberately two clouds, so the sex check
# has something to separate.
col_data[["recount_qc.aligned_reads..chrx"]] <-
  c(rep(4.1, 6), rep(2.2, 6))
col_data[["recount_qc.aligned_reads..chry"]] <-
  c(rep(0.01, 6), rep(0.8, 6))

# recount3 ships ".2" suffixed copies of several star.* columns filled with
# zeros. usable_metric_columns() has to drop this one.
col_data[["recount_qc.star.uniquely_mapped_reads_..2"]] <- rep(0, n_samples)

rownames(col_data) <- colnames(counts)

# Gene biotypes, so library composition has something to compose. Two rare
# ones past the top few, so the "other" lumping is exercised.
gene_type <- rep(
  c(
    "protein_coding",
    "lncRNA",
    "processed_pseudogene",
    "misc_RNA",
    "snRNA",
    "miRNA",
    "rRNA_pseudogene",
    "snoRNA",
    "scaRNA",
    "vault_RNA"
  ),
  length.out = n_genes
)

rse <- SummarizedExperiment::SummarizedExperiment(
  assays = list(counts = counts),
  rowData = S4Vectors::DataFrame(
    gene_name = gene_name,
    gene_type = gene_type,
    bp_length = as.integer(round(seq(200, 12000, length.out = n_genes)))
  ),
  colData = S4Vectors::DataFrame(col_data)
)
rownames(rse) <- rownames(counts)

out <- file.path("tests", "testthat", "fixtures", "rse_small.rds")
saveRDS(rse, out, compress = "xz")
cat("wrote", out, "-", nrow(rse), "genes x", ncol(rse), "samples\n")
