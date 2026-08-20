test_that("register_plot_downloads wires a PDF and a PNG handler under one prefix", {
  # shiny's own output object has reference semantics (it behaves like an
  # environment), so the fake here has to as well: a plain list would not
  # see the assignment made inside the function.
  output <- new.env()

  register_plot_downloads(
    output,
    "qc",
    filename = function() "SRP000001_qc",
    builder = function(dark_mode) ggplot2::ggplot()
  )

  expect_true(is.function(output$qc_pdf))
  expect_true(is.function(output$qc_png))
  expect_s3_class(output$qc_pdf, "shiny.render.function")
  expect_s3_class(output$qc_png, "shiny.render.function")
})

test_that("plot_download_ui names its buttons after the id prefix it is given", {
  ui <- plot_download_ui(shiny::NS("mod"), "correlation")
  html <- as.character(ui)

  expect_match(html, "mod-correlation_pdf", fixed = TRUE)
  expect_match(html, "mod-correlation_png", fixed = TRUE)
})

test_that("font_size_ui and plot_controls_ui default to 21", {
  # sliderInput's initial value is the ionRangeSlider `data-from` attribute,
  # not a plain HTML value= like a text input would carry.
  slider_value <- function(html) {
    as.numeric(sub('.*data-from="([0-9.]+)".*', "\\1", html))
  }

  font_html <- as.character(font_size_ui(shiny::NS("mod")))
  expect_equal(slider_value(font_html), 21)

  # include_font = FALSE is what the overview module uses, since its font
  # size control lives in a shared sidebar rather than inside this block.
  no_font <- as.character(plot_controls_ui(
    shiny::NS("mod"),
    include_font = FALSE
  ))
  expect_false(grepl("Font size", no_font, fixed = TRUE))

  with_font <- as.character(plot_controls_ui(shiny::NS("mod")))
  expect_true(grepl("Font size", with_font, fixed = TRUE))
})
