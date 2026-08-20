# Warm the recount3 cache before the app needs it.
#
# Every study the app loads is downloaded once and then kept by BiocFileCache,
# so a study fetched here loads in about three seconds instead of ten or more.
# Useful before a demo, a workshop, or a deployment.
#
# Run from the repository root:
#   Rscript data-raw/prefetch_studies.R SRP107565 DRP000425
#   Rscript data-raw/prefetch_studies.R --max-samples 50 --limit 20
#   Rscript data-raw/prefetch_studies.R --max-samples 100 --limit 10 --dry-run
#
# CAUTION: study data is the bulk of the cache, at roughly 100 KB for each
# sample. Twenty studies of 50 samples is about 100 MB, but a single GTEx
# tissue is 296 MB and the largest mouse study is over 1 GB. Check the
# reported total before answering yes.

stopifnot(dir.exists("R"), dir.exists("data-raw"))

suppressMessages(library(recount3))
options(recount3_verbose = FALSE)
for (f in list.files("R", pattern = "[.][Rr]$", full.names = TRUE)) {
  source(f)
}

args <- commandArgs(trailingOnly = TRUE)
arg_val <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
flag <- function(name) name %in% args

max_samples <- as.numeric(arg_val("--max-samples", "100"))
limit <- as.integer(arg_val("--limit", "10"))
dry_run <- flag("--dry-run")
assume_yes <- flag("--yes")

# Anything that is not a flag or a flag's value is an accession.
flags_with_values <- c("--max-samples", "--limit")
consumed <- unlist(lapply(flags_with_values, function(f) {
  i <- match(f, args)
  if (is.na(i)) NULL else c(i, i + 1L)
}))
accessions <- setdiff(
  args[setdiff(seq_along(args), consumed)],
  c("--dry-run", "--yes")
)

say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), "|", ..., "\n")

catalog <- read_catalog()
if (is.null(catalog)) {
  stop(
    "No catalog snapshot. Run: Rscript data-raw/build_catalog.R",
    call. = FALSE
  )
}

if (length(accessions)) {
  chosen <- catalog[catalog$project %in% accessions, , drop = FALSE]
  missing <- setdiff(accessions, chosen$project)
  if (length(missing)) {
    say("not in the catalog:", paste(missing, collapse = ", "))
  }
} else {
  chosen <- catalog[catalog$n_samples <= max_samples, , drop = FALSE]
  # Largest first within the limit: the studies most worth warming are the ones
  # that would otherwise be slowest.
  chosen <- chosen[order(-chosen$n_samples), , drop = FALSE]
  chosen <- utils::head(chosen, limit)
}

if (nrow(chosen) == 0L) {
  say("nothing matched, nothing to do")
  quit(status = 0)
}

chosen$mb <- catalog_download_mb(chosen)
total_mb <- sum(chosen$mb, na.rm = TRUE)

say(sprintf(
  "%d studies, about %s in total",
  nrow(chosen),
  format_size_mb(total_mb)
))
for (i in seq_len(nrow(chosen))) {
  cat(sprintf(
    "  %-12s %-6s %6s samples  %8s\n",
    chosen$project[i],
    chosen$organism[i],
    format(chosen$n_samples[i], big.mark = ","),
    format_size_mb(chosen$mb[i])
  ))
}

if (dry_run) {
  say("dry run, nothing fetched")
  quit(status = 0)
}

if (total_mb > 2000 && !assume_yes) {
  stop(
    sprintf(
      "That is %s. Rerun with --yes if you meant it.",
      format_size_mb(total_mb)
    ),
    call. = FALSE
  )
}

say("warming the shared gene annotation")
prefetch_annotations(unique(chosen$organism))

started <- Sys.time()
done_mb <- 0
for (i in seq_len(nrow(chosen))) {
  row <- chosen[i, , drop = FALSE]
  t0 <- Sys.time()
  ok <- tryCatch(
    {
      prefetch_study_files(catalog_proj_info(row))
      TRUE
    },
    error = function(e) {
      say("  failed:", row$project, conditionMessage(e))
      FALSE
    }
  )
  if (ok) {
    done_mb <- done_mb + row$mb
  }
  cat(sprintf(
    "  [%d/%d] %-12s %8s  %5.1f s   running total %s\n",
    i,
    nrow(chosen),
    row$project,
    format_size_mb(row$mb),
    as.numeric(difftime(Sys.time(), t0, units = "secs")),
    format_size_mb(done_mb)
  ))
}

say(sprintf(
  "done: %s fetched in %.1f minutes",
  format_size_mb(done_mb),
  as.numeric(difftime(Sys.time(), started, units = "mins"))
))
