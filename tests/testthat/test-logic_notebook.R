notebook_study <- function() {
  rse <- fixture_rse()
  list(
    project = "SRP000001",
    organism = "human",
    source = "sra",
    title = "A fixture study",
    rse = rse,
    log_expr = log_cpm(rse)
  )
}

notebook_states <- function(rse) {
  list(
    gene = list(
      gene = rownames(rse)[1],
      gene_label = "GENE1",
      group_by = "tissue",
      geom = "violin"
    ),
    pca = list(n_genes = 250, color_by = "condition")
  )
}

test_that("every format is offered and maps to a file extension", {
  expect_setequal(unname(REPRODUCTION_FORMATS), c("r", "qmd", "rmd"))
  expect_equal(reproduction_extension("r"), "R")
  expect_equal(reproduction_extension("qmd"), "qmd")
  expect_equal(reproduction_extension("rmd"), "Rmd")
})

test_that("the notebooks carry every line of code the script has", {
  s <- notebook_study()
  st <- notebook_states(s$rse)

  code_lines <- function(txt) {
    lines <- strsplit(txt, "\n", fixed = TRUE)[[1L]]
    lines <- lines[!startsWith(lines, "#")]
    lines <- lines[!startsWith(lines, "```")]
    trimws(lines[nzchar(trimws(lines))])
  }

  script <- code_lines(build_reproduction(s, st$gene, st$pca, "r"))
  for (fmt in c("qmd", "rmd")) {
    notebook <- code_lines(build_reproduction(s, st$gene, st$pca, fmt))
    # The three formats come from one builder, so the code cannot drift.
    expect_true(all(script %in% notebook), info = fmt)
  }
})

test_that("a Quarto notebook opens with Quarto front matter", {
  s <- notebook_study()
  txt <- build_reproduction(s, format = "qmd")
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1L]]

  expect_equal(lines[[1L]], "---")
  expect_true(any(grepl("^title: ", lines)))
  expect_true(any(grepl("embed-resources: true", lines, fixed = TRUE)))
  expect_true(any(grepl("code-fold: show", lines, fixed = TRUE)))
})

test_that("an R Markdown notebook opens with rmarkdown front matter", {
  s <- notebook_study()
  txt <- build_reproduction(s, format = "rmd")
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1L]]

  expect_equal(lines[[1L]], "---")
  expect_true(any(grepl("html_document", lines, fixed = TRUE)))
  expect_true(any(grepl("knitr::opts_chunk", lines, fixed = TRUE)))
})

test_that("chunks are balanced, so the notebook is not truncated", {
  s <- notebook_study()
  st <- notebook_states(s$rse)

  for (fmt in c("qmd", "rmd")) {
    lines <- strsplit(
      build_reproduction(s, st$gene, st$pca, fmt),
      "\n",
      fixed = TRUE
    )[[1L]]
    fences <- sum(startsWith(lines, "```"))
    expect_equal(fences %% 2L, 0L, info = fmt)
    expect_gt(fences, 0L)
  }
})

test_that("the script header becomes prose, not a heading", {
  s <- notebook_study()
  lines <- strsplit(
    build_reproduction(s, format = "qmd"),
    "\n",
    fixed = TRUE
  )[[1L]]
  headings <- grep("^## ", lines, value = TRUE)

  # The accession and the citation belong in the front matter and the intro.
  # Left as a heading they would title the first code chunk, which is the
  # library calls.
  expect_false(any(grepl("Study accession", headings, fixed = TRUE)))
  expect_false(any(grepl("Reproduces a Recount", headings, fixed = TRUE)))
  expect_true(any(grepl("Load the study", headings, fixed = TRUE)))
})

test_that("the notebook names the study and keeps the citation", {
  s <- notebook_study()
  txt <- build_reproduction(s, format = "qmd")

  expect_match(txt, "SRP000001", fixed = TRUE)
  expect_match(txt, "10.1186/s13059-021-02533-6", fixed = TRUE)
  expect_match(txt, "12 samples", fixed = TRUE)
})

test_that("build_reproduction defaults to the plain script", {
  s <- notebook_study()

  expect_equal(
    build_reproduction(s),
    build_reproduction_script(s)
  )
})

test_that("script_sections drops comments and keeps the code", {
  script <- paste(
    "# Header line",
    "",
    "library(x)",
    "",
    "# A real heading",
    "y <- 1",
    sep = "\n"
  )

  sections <- script_sections(script)

  expect_length(sections, 2L)
  expect_null(sections[[1L]]$title)
  expect_equal(sections[[1L]]$code, "library(x)")
  expect_equal(sections[[2L]]$title, "A real heading")
  expect_equal(sections[[2L]]$code, "y <- 1")
})

test_that("trim_blank_ends leaves the middle alone", {
  expect_equal(trim_blank_ends(c("", "a", "", "b", "")), c("a", "", "b"))
  expect_equal(trim_blank_ends(character()), character())
  expect_equal(trim_blank_ends(c("", "")), character())
})

test_that("format_reads keeps the two digits that matter", {
  expect_equal(format_reads(8236451), "8.2 M")
  expect_equal(format_reads(24000000), "24.0 M")
  expect_equal(format_reads(4500), "4 K")
  expect_equal(format_reads(312), "312")
  expect_equal(format_reads(NA), "unknown")
})

test_that("study_link_row adapts a loaded study to the link table", {
  s <- notebook_study()

  row <- study_link_row(s)
  links <- study_external_links(row)

  expect_equal(row$file_source, "sra")
  expect_true("SRA" %in% names(links))
  expect_match(links[["SRA"]], "SRP000001", fixed = TRUE)
})
