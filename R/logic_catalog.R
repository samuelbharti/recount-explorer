# Study catalog layer. Shiny-free: it reads the shipped catalog snapshot and
# fetches the study title and abstract for one project at a time.
#
# available_projects() gives accessions and sample counts but no title and no
# abstract. Those live in a separate metadata file for each project. Collecting
# all of them costs about 19,000 HTTP requests, so a build script does it once
# and writes data/recount3_catalog.rds. See data-raw/build_catalog.R.

CATALOG_SCHEMA_VERSION <- 1L

CATALOG_COLUMNS <- c(
  "uid",
  "project",
  "organism",
  "file_source",
  "project_home",
  "n_samples",
  "study_title",
  "study_abstract"
)

# Stable key for one study. available_projects() reuses accessions across
# organisms, so the organism has to be part of the key.
catalog_uid <- function(df) {
  paste(df$organism, df$file_source, df$project, sep = "/")
}

# Metadata URL for one project. locate_url(type = "metadata") returns several
# URLs. The project metadata file is <src>.<src>.<PROJ>.MD.gz. Select it by
# name, not by position, so a change to the file order upstream cannot quietly
# hand us the wrong file.
recount3_metadata_url <- function(
  project,
  project_home,
  organism,
  recount3_url = getOption("recount3_url", "http://duffel.rail.bio/recount3")
) {
  urls <- recount3::locate_url(
    project = project,
    project_home = project_home,
    type = "metadata",
    organism = organism,
    recount3_url = recount3_url
  )
  src <- basename(project_home)
  want <- paste0(src, ".", src, ".", project, ".MD.gz")
  unname(if (want %in% names(urls)) urls[[want]] else urls[[1L]])
}

# Read the header and the first data row of a gzipped metadata file.
#
# curl::curl(), not base::url(). The recount3 host answers the documented
# http:// address with a 301 to https://, and that answers with a 302 to S3.
# base::url() follows neither, so every request returns 404. curl follows both.
#
# This also deliberately does not call recount3::file_retrieve(). That function
# probes the URL with http_error() before it downloads, which doubles the
# request count, and it writes into the shared BiocFileCache database. Parallel
# workers would serialize on that database and leave several GB behind.
# read.delim(nrows = 1) stops after the first row, so the transfer ends early.
read_first_metadata_row <- function(url, timeout = 60) {
  handle <- curl::new_handle(
    followlocation = TRUE,
    timeout = timeout,
    connecttimeout = 20L,
    useragent = "recount-explorer catalog build (R)"
  )
  con <- gzcon(curl::curl(url, open = "rb", handle = handle))
  on.exit(try(close(con), silent = TRUE), add = TRUE)

  # readLines() rather than read.delim(con). read.delim() pushes back on the
  # connection to sniff the header, and a gzcon over a binary curl connection
  # refuses that. Two lines are the header and the first sample, which is all
  # the title and the abstract need, and the transfer stops there.
  lines <- readLines(con, n = 2L, warn = FALSE)
  if (length(lines) < 2L) {
    return(data.frame())
  }
  utils::read.delim(
    text = paste(lines, collapse = "\n"),
    sep = "\t",
    check.names = FALSE,
    quote = "",
    comment.char = "",
    stringsAsFactors = FALSE
  )
}

# Undo the markup that some submitters leave in study text.
#
# Only the HTML line break and paragraph tags are removed. Other angle bracket
# text in this data is not markup: study titles contain "IFN-<gamma>" and the
# mouse allele "Jundm2<tm2>", and a general tag strip would destroy both.
#
# The entity list is short on purpose. It covers what the recount3 metadata
# actually contains. &amp; is decoded last so that "&amp;lt;" cannot turn into
# a "<" on the second pass.
strip_markup <- function(x) {
  x <- gsub("</?(br|p)[[:space:]]*/?>", " ", x, ignore.case = TRUE)
  x <- gsub("&lt;", "<", x, fixed = TRUE)
  x <- gsub("&gt;", ">", x, fixed = TRUE)
  x <- gsub("&quot;", "\"", x, fixed = TRUE)
  x <- gsub("&#39;", "'", x, fixed = TRUE)
  x <- gsub("&nbsp;", " ", x, fixed = TRUE)
  gsub("&amp;", "&", x, fixed = TRUE)
}

# Collapse whitespace and turn placeholder values into NA.
clean_text <- function(x) {
  if (length(x) != 1L || is.na(x)) {
    return(NA_character_)
  }
  x <- gsub("[\r\n\t]+", " ", as.character(x))
  x <- strip_markup(x)
  x <- trimws(gsub("[[:space:]]{2,}", " ", x))
  if (!nzchar(x) || tolower(x) %in% c("na", "n/a", "null", "none")) {
    return(NA_character_)
  }
  x
}

# Study text carries characters like the Greek beta and the typographic
# apostrophe. R reads them as "unknown" encoding, which means the native
# locale, so a string written on Windows can render as mojibake on a Linux
# server. Declare UTF-8 so the meaning travels with the data.
mark_utf8 <- function(x) {
  x <- as.character(x)
  present <- !is.na(x)
  if (any(present) && all(validUTF8(x[present]))) {
    Encoding(x) <- "UTF-8"
  }
  x
}

# Vectorized clean_text(), for cleaning a whole column at once.
clean_text_vec <- function(x) {
  vapply(x, clean_text, character(1), USE.NAMES = FALSE)
}

# Title and abstract for one project. Never throws: it always returns one row,
# so the caller can tell "not attempted" apart from "attempted and failed".
fetch_study_metadata <- function(
  project,
  project_home,
  organism,
  retries = 3L,
  backoff = 1.5,
  recount3_url = getOption("recount3_url", "http://duffel.rail.bio/recount3")
) {
  out <- data.frame(
    project = project,
    organism = organism,
    file_source = basename(project_home),
    study_title = NA_character_,
    study_abstract = NA_character_,
    fetch_status = "ok",
    fetch_message = NA_character_,
    stringsAsFactors = FALSE
  )

  url <- tryCatch(
    recount3_metadata_url(project, project_home, organism, recount3_url),
    error = function(e) NULL
  )
  if (is.null(url)) {
    out$fetch_status <- "error"
    out$fetch_message <- "could not build the metadata url"
    return(out)
  }

  last <- NULL
  for (attempt in seq_len(retries)) {
    row <- tryCatch(read_first_metadata_row(url), error = function(e) e)
    if (!inherits(row, "error")) {
      if (nrow(row) == 0L) {
        out$fetch_status <- "empty"
        return(out)
      }
      nm <- tolower(names(row))
      has_title <- "study_title" %in% nm
      has_abstract <- "study_abstract" %in% nm
      if (has_title) {
        out$study_title <- clean_text(row[[which(nm == "study_title")[1L]]])
      }
      if (has_abstract) {
        out$study_abstract <- clean_text(
          row[[which(nm == "study_abstract")[1L]]]
        )
      }
      if (!has_title && !has_abstract) {
        out$fetch_status <- "no_fields"
      }
      return(out)
    }
    last <- row
    # Some sources have no <src>.<src> file at all. A 404 is permanent, so do
    # not spend three attempts and twenty seconds of backoff on it.
    if (grepl("404|[Nn]ot [Ff]ound", conditionMessage(last))) {
      break
    }
    Sys.sleep(backoff^attempt)
  }

  out$fetch_status <- "error"
  out$fetch_message <- conditionMessage(last)
  out
}

# Provenance travels with the data as an attribute. Row subsetting keeps that
# attribute, but column subsetting drops it, and renderDT() selects columns.
# So filtered rows keep their provenance and a column subset does not. Read
# provenance from the master object to be safe.
catalog_meta <- function(df) {
  meta <- attr(df, "catalog_meta", exact = TRUE)
  if (is.null(meta)) {
    return(list(
      schema_version = NA_integer_,
      built_at = as.POSIXct(NA),
      recount3_version = NA_character_,
      n_projects = if (is.data.frame(df)) nrow(df) else NA_integer_,
      origin = "unknown"
    ))
  }
  meta
}

valid_catalog <- function(df) {
  is.data.frame(df) &&
    nrow(df) > 0L &&
    all(CATALOG_COLUMNS %in% names(df)) &&
    identical(catalog_meta(df)$schema_version, CATALOG_SCHEMA_VERSION)
}

# Coerce to the storage schema and attach provenance. n_samples arrives from
# available_projects() as a subsetted table, not an integer vector, so the
# unname() and the as.integer() are both load bearing.
finalize_catalog <- function(df, origin = "build", built_at = Sys.time()) {
  df$n_samples <- as.integer(unname(df$n_samples))
  df$organism <- as.character(df$organism)
  df$file_source <- as.character(df$file_source)
  df$project <- as.character(df$project)
  df$project_home <- as.character(df$project_home)
  # Normalize the study text here rather than at each source. Titles arrive
  # from a CSV export, from curated text, and from the metadata files, and all
  # three have to end up in the same shape.
  df$study_title <- mark_utf8(strip_markup(as.character(df$study_title)))
  df$study_abstract <- mark_utf8(strip_markup(as.character(df$study_abstract)))
  df$study_title <- trimws(gsub("[[:space:]]{2,}", " ", df$study_title))
  df$study_abstract <- trimws(gsub("[[:space:]]{2,}", " ", df$study_abstract))
  df$uid <- catalog_uid(df)

  df <- df[, CATALOG_COLUMNS, drop = FALSE]
  df <- df[order(df$organism, df$file_source, df$project), , drop = FALSE]
  rownames(df) <- NULL

  attr(df, "catalog_meta") <- list(
    schema_version = CATALOG_SCHEMA_VERSION,
    built_at = as.POSIXct(built_at, tz = "UTC"),
    recount3_version = as.character(utils::packageVersion("recount3")),
    r_version = as.character(getRversion()),
    n_projects = nrow(df),
    n_with_abstract = sum(nzchar(df$study_abstract)),
    origin = origin
  )
  df
}

# create_rse() reaches match.arg() through annotation_options(). match.arg()
# rejects a factor, so the row handed to load_study() must be character only.
catalog_proj_info <- function(row) {
  stopifnot(is.data.frame(row), nrow(row) == 1L)
  data.frame(
    project = as.character(row$project),
    organism = as.character(row$organism),
    file_source = as.character(row$file_source),
    project_home = as.character(row$project_home),
    project_type = "data_sources",
    n_samples = as.integer(row$n_samples),
    stringsAsFactors = FALSE
  )
}

# ---- runtime -----------------------------------------------------------------

# Where the shipped snapshot lives. The environment variable is an escape
# hatch for a deployment that keeps the catalog outside the app bundle.
catalog_snapshot_path <- function() {
  Sys.getenv("RECOUNT_EXPLORER_CATALOG", "data/recount3_catalog.rds")
}

read_catalog_file <- function(path) {
  if (!nzchar(path) || !file.exists(path)) {
    return(NULL)
  }
  df <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(df) || !valid_catalog(df)) {
    return(NULL)
  }
  df
}

# The catalog the app runs on. Read once for each process, not once for each
# session, so every session shares one copy of the 19,000 rows.
read_catalog <- local({
  cached <- NULL
  function(path = catalog_snapshot_path(), refresh = FALSE) {
    if (refresh || is.null(cached)) {
      cached <<- read_catalog_file(path)
    }
    cached
  }
})

# One line of provenance for under the table.
catalog_summary_line <- function(df) {
  if (is.null(df)) {
    return("No catalog snapshot found.")
  }
  meta <- catalog_meta(df)
  built <- if (is.na(meta$built_at)) {
    "unknown date"
  } else {
    format(meta$built_at, "%Y-%m-%d")
  }
  sprintf(
    "%s studies, built %s with recount3 %s.",
    format(nrow(df), big.mark = ","),
    built,
    meta$recount3_version
  )
}

# Sorted source names for the filter control, so a new recount3 source appears
# on its own rather than after someone edits a hardcoded list.
catalog_sources <- function(df) {
  sort(unique(as.character(df$file_source)))
}

# Links out to the archive that published the study.
study_external_links <- function(row) {
  project <- as.character(row$project)
  source <- as.character(row$file_source)
  if (source == "sra") {
    return(c(
      "SRA" = paste0(
        "https://trace.ncbi.nlm.nih.gov/Traces/study/?acc=",
        project
      ),
      "ENA" = paste0("https://www.ebi.ac.uk/ena/browser/view/", project)
    ))
  }
  if (source == "gtex") {
    return(c("GTEx Portal" = "https://gtexportal.org/home/"))
  }
  if (source == "tcga") {
    return(c(
      "GDC Portal" = paste0(
        "https://portal.gdc.cancer.gov/projects/TCGA-",
        project
      )
    ))
  }
  c("recount3" = "https://rna.recount.bio/")
}
