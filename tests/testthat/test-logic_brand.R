brand_file <- function(...) {
  f <- withr::local_tempfile(fileext = ".yml", .local_envir = parent.frame())
  writeLines(c("color:", "  palette:", ...), f)
  f
}

test_that("the shipped brand file parses and carries the coffee palette", {
  colors <- brand_colors(
    testthat::test_path("..", "..", "_brand.yml"),
    refresh = TRUE
  )

  expect_type(colors, "list")
  for (name in c("espresso", "caramel", "cream", "foam", "latte")) {
    expect_true(name %in% names(colors), info = name)
    expect_match(colors[[name]], "^#[0-9A-Fa-f]{6}$", info = name)
  }
})

test_that("light is dark text on a light ground, and dark inverts it", {
  light <- brand_plot_palette(FALSE)
  dark <- brand_plot_palette(TRUE)

  expect_named(light, c("bg", "fg", "muted", "grid", "point"))
  expect_named(dark, names(light))

  # A dark background with dark text would be worse than not theming at all,
  # so this checks the two modes really are opposites rather than just
  # different.
  expect_gt(
    mean(grDevices::col2rgb(light$bg)),
    mean(grDevices::col2rgb(light$fg))
  )
  expect_lt(
    mean(grDevices::col2rgb(dark$bg)),
    mean(grDevices::col2rgb(dark$fg))
  )
})

test_that("no role is the Bootstrap blue any more", {
  for (mode in c(FALSE, TRUE)) {
    p <- brand_plot_palette(mode)
    expect_false(tolower(p$point) %in% c("#0d6efd", "#2f6feb"), info = mode)
  }
})

test_that("a brand file drives the palette, so a swap changes everything", {
  f <- brand_file('    cream: "#001122"', '    caramel: "#FF0000"')

  p <- brand_plot_palette(FALSE, brand_colors(f, refresh = TRUE))

  expect_equal(p$bg, "#001122")
  expect_equal(p$point, "#FF0000")
})

test_that("a partial brand file falls back instead of emptying a role", {
  f <- brand_file('    caramel: "#FF0000"')

  colors <- brand_colors(f, refresh = TRUE)
  p <- brand_plot_palette(FALSE, colors)

  expect_equal(p$point, "#FF0000")
  # cream was not given, so it comes from the fallback.
  expect_equal(p$bg, BRAND_FALLBACK$cream)
  # And the fallback covers every name the app asks for, so no two roles
  # collapse onto the same placeholder grey.
  expect_equal(anyDuplicated(brand_qualitative(colors)), 0L)
})

test_that("a missing or unreadable brand file leaves the app usable", {
  # A broken brand should make the app look plain, not stop it from starting.
  missing <- brand_colors(
    file.path(tempdir(), "nope.yml"),
    refresh = TRUE
  )
  expect_equal(missing, BRAND_FALLBACK)

  bad <- withr::local_tempfile(fileext = ".yml")
  writeLines("this: [is not: valid", bad)
  expect_equal(brand_colors(bad, refresh = TRUE), BRAND_FALLBACK)
})

test_that("an unknown colour name gives grey rather than an error in a plot", {
  expect_equal(brand_color("no-such-colour"), "#888888")
})

test_that("the qualitative scale is warm and has no repeats", {
  # Explicitly against the shipped brand, so an earlier test that pointed the
  # cache at a stub file cannot make this one look broken.
  scale <- brand_qualitative(
    brand_colors(testthat::test_path("..", "..", "_brand.yml"), refresh = TRUE)
  )

  expect_gte(length(scale), 6L)
  expect_equal(anyDuplicated(scale), 0L)
  for (colour in scale) {
    expect_match(colour, "^#[0-9A-Fa-f]{6}$")
  }
  # Warm means red is not the smallest channel on average.
  rgb <- grDevices::col2rgb(scale)
  expect_gt(mean(rgb["red", ]), mean(rgb["blue", ]))
})

test_that("the brand path can be pointed elsewhere", {
  withr::local_envvar(RECOUNT_EXPLORER_BRAND = "somewhere/else.yml")

  expect_equal(brand_path(), "somewhere/else.yml")
})

test_that("plot builders take their colours from the brand", {
  qc <- data.frame(library_size = c(1e6, 5e6), detected_genes = c(100, 5000))

  for (mode in c(FALSE, TRUE)) {
    built <- plot_qc(qc, dark = mode)$theme$plot.background$fill
    expect_equal(built, brand_plot_palette(mode)$bg, info = mode)
  }
})

# Leave the cache holding the real brand, so later tests see the shipped file.
withr::defer(
  brand_colors(testthat::test_path("..", "..", "_brand.yml"), refresh = TRUE),
  teardown_env()
)

test_that("the qualitative scale stretches past its eight named colours", {
  # metadata_group_choices() offers columns with up to 30 levels, so a scale
  # that stops at eight is what made grouped plots error.
  for (n in c(9L, 12L, 30L)) {
    scale <- brand_qualitative(n = n)

    expect_length(scale, n)
    expect_false(any(is.na(scale)), info = n)
    for (colour in scale) {
      expect_match(colour, "^#[0-9A-Fa-f]{6}$", info = n)
    }
  }
})

test_that("asking for fewer colours takes them from the front unchanged", {
  full <- brand_qualitative()

  expect_equal(brand_qualitative(n = 3), full[1:3])
  expect_equal(brand_qualitative(n = 8), full)
  # A zero or negative count still has to give something usable back.
  expect_length(brand_qualitative(n = 0), 1L)
})

test_that("the sequential ramp runs light to dark and inverts for dark mode", {
  light <- brand_sequential(FALSE)
  dark <- brand_sequential(TRUE)

  expect_length(light, 3L)
  expect_length(dark, 3L)
  brightness <- function(x) mean(grDevices::col2rgb(x))
  # Light mode: pale low end, dark high end. Dark mode is the other way round,
  # so the low end never disappears into the page.
  expect_gt(brightness(light[1]), brightness(light[3]))
  expect_lt(brightness(dark[1]), brightness(dark[3]))
})
