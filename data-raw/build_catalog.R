# Build data/recount3_catalog.rds: every recount3 study with its title and its
# abstract, ready for the app to read at startup.
#
# Run from the repository root:
#   Rscript data-raw/build_catalog.R
#   Rscript data-raw/build_catalog.R --workers 8 --chunk 25
#   Rscript data-raw/build_catalog.R --fresh        # ignore the resume files
#
# The project list always comes from available_projects(), which is the
# authoritative source for accessions and sample counts.
#
# Titles and abstracts come from up to three places, in this order:
#
#   1. A study explorer export in data-raw/, if one is present. The official
#      recount3 study explorer exports the whole catalog as CSV, which saves
#      about 18,800 HTTP requests. The export is a snapshot, so it lags the
#      live project list.
#   2. Curated text for the six sources that publish no abstract. Only SRA
#      studies carry study_title and study_abstract in their metadata files.
#   3. A direct fetch from the recount3 metadata files, for whatever is left.
#
# A second pass then records the download size of each study with a HEAD
# request, so the app can say what a study costs before anyone clicks.
#
# Without an export in data-raw/ the script falls back to step 3 for every
# study. That takes 20 to 40 minutes. With an export it takes about a minute.

stopifnot(dir.exists("R"), dir.exists("data-raw"))

suppressMessages({
  library(recount3)
})
source("R/logic_catalog.R")
source("data-raw/catalog_manual.R")

# ---- arguments --------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
arg_val <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}

workers <- as.integer(arg_val("--workers", "6"))
chunk_size <- as.integer(arg_val("--chunk", "25"))
pause <- as.numeric(arg_val("--pause", "0.05"))
out_path <- arg_val("--out", "data/recount3_catalog.rds")
parts_dir <- arg_val("--parts", "data-raw/parts")
limit <- as.integer(arg_val("--limit", "0"))
fresh <- "--fresh" %in% args

if (fresh) {
  unlink(parts_dir, recursive = TRUE)
}
dir.create(parts_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)

say <- function(...) {
  cat(format(Sys.time(), "%H:%M:%S"), "|", ..., "\n")
}

started <- Sys.time()

# ---- 1. the authoritative project list --------------------------------------

say("reading available_projects() for human and mouse")
projects <- do.call(
  rbind,
  lapply(c("human", "mouse"), function(org) {
    p <- recount3::available_projects(organism = org)
    p[p$project_type == "data_sources", , drop = FALSE]
  })
)
projects$n_samples <- as.integer(unname(projects$n_samples))
projects$uid <- catalog_uid(projects)
rownames(projects) <- NULL
say("project list:", nrow(projects), "studies")

projects$study_title <- NA_character_
projects$study_abstract <- NA_character_

# ---- 2. seed from a study explorer export, if present -----------------------

export_files <- list.files(
  "data-raw",
  pattern = "^recount3_selection.*[.]csv$",
  full.names = TRUE
)
if (length(export_files)) {
  export_path <- export_files[[1L]]
  say("seeding from", basename(export_path))
  export <- utils::read.csv(
    export_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  export$file_source <- basename(export$project_home)
  export$uid <- catalog_uid(export)
  export <- export[!duplicated(export$uid), , drop = FALSE]

  i <- match(projects$uid, export$uid)
  hit <- !is.na(i)
  projects$study_title[hit] <- clean_text_vec(export$study_title[i[hit]])
  projects$study_abstract[hit] <- clean_text_vec(export$study_abstract[i[hit]])
  say("seeded", sum(hit), "of", nrow(projects), "studies from the export")
} else {
  say("no study explorer export in data-raw/, every study needs a fetch")
}

# ---- 3. curated text for the sources with no abstract -----------------------

manual <- catalog_manual(projects)
if (!is.null(manual)) {
  j <- match(manual$uid, projects$uid)
  projects$study_title[j] <- manual$study_title
  projects$study_abstract[j] <- manual$study_abstract
  say("applied curated text to", nrow(manual), "non-SRA studies")
}

# ---- 4. fetch whatever is still missing -------------------------------------

needs_fetch <- projects$file_source == "sra" &
  (is.na(projects$study_title) | is.na(projects$study_abstract))
todo <- projects[needs_fetch, , drop = FALSE]

if (limit > 0L && nrow(todo) > limit) {
  say("--limit", limit, "in effect, trimming from", nrow(todo))
  todo <- todo[seq_len(limit), , drop = FALSE]
}

read_parts <- function(dir) {
  files <- list.files(dir, pattern = "^part-.*[.]rds$", full.names = TRUE)
  if (!length(files)) {
    return(NULL)
  }
  parts <- lapply(files, function(f) {
    tryCatch(readRDS(f), error = function(e) NULL)
  })
  df <- do.call(rbind, Filter(Negate(is.null), parts))
  if (is.null(df)) {
    return(NULL)
  }
  df[!duplicated(df$uid, fromLast = TRUE), , drop = FALSE]
}

done <- read_parts(parts_dir)
if (!is.null(done)) {
  # Retry anything that failed for a transient reason. Keep the permanent
  # outcomes so a rerun does not hammer studies that will never have a title.
  settled <- done$uid[done$fetch_status != "error"]
  say("resume: ", length(settled), " studies already settled")
  todo <- todo[!todo$uid %in% settled, , drop = FALSE]
}

say("to fetch:", nrow(todo), "studies")

if (nrow(todo) > 0L) {
  chunks <- split(todo, ceiling(seq_len(nrow(todo)) / chunk_size))
  stamp <- format(started, "%Y%m%d%H%M%S")
  for (k in seq_along(chunks)) {
    chunks[[k]]$chunk_id <- sprintf("%s-%05d", stamp, k)
  }
  say("fetching in", length(chunks), "chunks over", workers, "workers")

  mirai::daemons(workers)
  on.exit(mirai::daemons(0), add = TRUE)

  # locate_url() resolves its project_home default through project_homes(),
  # which reads an index over the network on the first call in a process.
  # Warm it once per worker instead of once per study.
  mirai::everywhere({
    options(timeout = 120)
    suppressMessages(invisible(recount3::project_homes("human")))
    suppressMessages(invisible(recount3::project_homes("mouse")))
  })

  fetch_chunk <- function(chunk, parts_dir, pause, retries) {
    rows <- lapply(seq_len(nrow(chunk)), function(i) {
      r <- fetch_study_metadata(
        project = chunk$project[i],
        project_home = chunk$project_home[i],
        organism = chunk$organism[i],
        retries = retries
      )
      Sys.sleep(pause)
      r
    })
    df <- do.call(rbind, rows)
    df$uid <- chunk$uid

    f <- file.path(parts_dir, sprintf("part-%s.rds", chunk$chunk_id[1L]))
    tmp <- paste0(f, ".tmp")
    saveRDS(df, tmp, compress = "gzip")
    if (!file.rename(tmp, f)) {
      file.copy(tmp, f, overwrite = TRUE)
      unlink(tmp)
    }
    c(n = nrow(df), ok = sum(df$fetch_status == "ok"))
  }

  # These go through `...` rather than `.args` on purpose. mirai puts `...`
  # into the daemon's global environment, which is the enclosure every one of
  # these functions resolves against. `.args` binds only in the evaluation
  # frame, so the nested calls inside fetch_chunk() would not find each other.
  res <- mirai::mirai_map(
    .x = chunks,
    .f = fetch_chunk,
    fetch_study_metadata = fetch_study_metadata,
    recount3_metadata_url = recount3_metadata_url,
    read_first_metadata_row = read_first_metadata_row,
    clean_text = clean_text,
    .args = list(parts_dir = parts_dir, pause = pause, retries = 3L)
  )[mirai::.progress]

  mirai::daemons(0)
  say("fetch finished")
}

# ---- 5. merge the fetched text back in --------------------------------------

fetched <- read_parts(parts_dir)
if (!is.null(fetched)) {
  # match() gives NA where a study was never fetched, and indexing with NA
  # yields NA, so the two fill masks below need no special casing.
  i <- match(projects$uid, fetched$uid)
  new_title <- fetched$study_title[i]
  new_abstract <- fetched$study_abstract[i]

  # A fetch only fills a gap. It never overwrites text that is already there.
  fill_t <- is.na(projects$study_title) & !is.na(new_title)
  fill_a <- is.na(projects$study_abstract) & !is.na(new_abstract)
  projects$study_title[fill_t] <- new_title[fill_t]
  projects$study_abstract[fill_a] <- new_abstract[fill_a]

  say("filled", sum(fill_t), "titles and", sum(fill_a), "abstracts by fetch")
  say(
    "statuses:",
    paste(
      names(table(fetched$fetch_status)),
      table(fetched$fetch_status),
      sep = "=",
      collapse = " "
    )
  )
}

# ---- 5b. record the download size of each study ------------------------------

# A HEAD request for each study, so the catalog can say what a study costs
# before anyone clicks. The body is never transferred, so this pass moves a few
# kilobytes of headers rather than the 79 GB the counts files add up to.
#
# Its own parts directory, so adding this pass does not invalidate the title
# and abstract work already on disk.

size_parts <- paste0(parts_dir, "-size")
dir.create(size_parts, showWarnings = FALSE, recursive = TRUE)

size_done <- read_parts(size_parts)
size_todo <- projects
if (!is.null(size_done)) {
  settled <- size_done$uid[!is.na(size_done$download_mb)]
  say("resume: ", length(settled), " sizes already recorded")
  size_todo <- size_todo[!size_todo$uid %in% settled, , drop = FALSE]
}
if (limit > 0L && nrow(size_todo) > limit) {
  size_todo <- size_todo[seq_len(limit), , drop = FALSE]
}
say("sizes to record:", nrow(size_todo))

# Learn the storage prefix and prove the shortcut agrees with locate_url
# before trusting it on 19,000 studies. Falling back is slower but correct.
fast_base <- NULL
if (nrow(size_todo) > 0L) {
  sample_url <- recount3_counts_url(
    projects$project[1],
    projects$project_home[1],
    projects$organism[1]
  )
  fast_base <- recount3_storage_base(sample_url)
  if (!is.null(fast_base) && verify_fast_urls(projects, fast_base, n = 3L)) {
    say("fast size lookup verified, base:", fast_base)
  } else {
    say("fast size lookup did not verify, falling back to locate_url")
    fast_base <- NULL
  }
}

if (nrow(size_todo) > 0L) {
  size_chunks <- split(
    size_todo,
    ceiling(seq_len(nrow(size_todo)) / chunk_size)
  )
  stamp <- format(started, "%Y%m%d%H%M%S")
  for (k in seq_along(size_chunks)) {
    size_chunks[[k]]$chunk_id <- sprintf("size-%s-%05d", stamp, k)
  }
  say(
    "HEAD requests in",
    length(size_chunks),
    "chunks over",
    workers,
    "workers"
  )

  mirai::daemons(workers)
  on.exit(mirai::daemons(0), add = TRUE)
  mirai::everywhere({
    options(timeout = 120)
    suppressMessages(invisible(recount3::project_homes("human")))
    suppressMessages(invisible(recount3::project_homes("mouse")))
  })

  size_chunk <- function(chunk, parts_dir, pause, base) {
    # One handle for the whole chunk, so the TLS handshake is paid once rather
    # than once for each study.
    handle <- if (is.null(base)) {
      NULL
    } else {
      curl::new_handle(
        nobody = TRUE,
        followlocation = FALSE,
        timeout = 30,
        connecttimeout = 15L,
        useragent = "recount-explorer catalog build (R)"
      )
    }
    mb <- vapply(
      seq_len(nrow(chunk)),
      function(i) {
        v <- if (is.null(base)) {
          study_download_mb(
            chunk$project[i],
            chunk$project_home[i],
            chunk$organism[i]
          )
        } else {
          content_length_mb(
            recount3_counts_url_fast(
              chunk$project[i],
              chunk$project_home[i],
              chunk$organism[i],
              base
            ),
            handle
          )
        }
        Sys.sleep(pause)
        v
      },
      numeric(1)
    )
    df <- data.frame(
      uid = chunk$uid,
      download_mb = mb,
      stringsAsFactors = FALSE
    )

    f <- file.path(parts_dir, sprintf("part-%s.rds", chunk$chunk_id[1L]))
    tmp <- paste0(f, ".tmp")
    saveRDS(df, tmp, compress = "gzip")
    if (!file.rename(tmp, f)) {
      file.copy(tmp, f, overwrite = TRUE)
      unlink(tmp)
    }
    c(n = nrow(df), ok = sum(!is.na(mb)))
  }

  # Through `...`, not `.args`: mirai puts these in the daemon global
  # environment, which is what the nested calls inside size_chunk() resolve
  # against.
  invisible(mirai::mirai_map(
    .x = size_chunks,
    .f = size_chunk,
    study_download_mb = study_download_mb,
    recount3_counts_url = recount3_counts_url,
    recount3_counts_url_fast = recount3_counts_url_fast,
    recount3_annotation_code = recount3_annotation_code,
    content_length_mb = content_length_mb,
    .args = list(parts_dir = size_parts, pause = pause, base = fast_base)
  )[mirai::.progress])

  mirai::daemons(0)
  say("size pass finished")
}

size_all <- read_parts(size_parts)
if (!is.null(size_all)) {
  i <- match(projects$uid, size_all$uid)
  projects$download_mb <- size_all$download_mb[i]
  say(sprintf(
    "sizes recorded for %d of %d studies (%.1f%%)",
    sum(!is.na(projects$download_mb)),
    nrow(projects),
    100 * mean(!is.na(projects$download_mb))
  ))
}

# ---- 6. fall back, finalize, write ------------------------------------------

blank_title <- is.na(projects$study_title) | !nzchar(projects$study_title)
if (any(blank_title)) {
  say(sum(blank_title), "studies have no title, generating one")
  projects$study_title[blank_title] <- paste0(
    toupper(projects$file_source[blank_title]),
    " study ",
    projects$project[blank_title]
  )
}
projects$study_abstract[is.na(projects$study_abstract)] <- ""

catalog <- finalize_catalog(projects, origin = "build", built_at = started)

stopifnot(
  nrow(catalog) == nrow(projects),
  !any(duplicated(catalog$uid)),
  !any(is.na(catalog$n_samples)),
  all(nzchar(catalog$study_title))
)

tmp <- paste0(out_path, ".tmp")
saveRDS(catalog, tmp, compress = "xz")
if (!file.rename(tmp, out_path)) {
  file.copy(tmp, out_path, overwrite = TRUE)
  unlink(tmp)
}

meta <- catalog_meta(catalog)
jsonlite::write_json(
  lapply(meta, function(x) {
    if (inherits(x, "POSIXct")) format(x, "%Y-%m-%dT%H:%M:%SZ") else x
  }),
  sub("[.]rds$", "_meta.json", out_path),
  auto_unbox = TRUE,
  pretty = TRUE
)

say("wrote", out_path)
say(sprintf(
  "%d studies | %d with an abstract (%.1f%%) | %.1f MB | %.1f min",
  nrow(catalog),
  meta$n_with_abstract,
  100 * meta$n_with_abstract / nrow(catalog),
  file.size(out_path) / 1e6,
  as.numeric(difftime(Sys.time(), started, units = "mins"))
))
print(table(catalog$organism, catalog$file_source))
