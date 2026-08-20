# Regenerate manifest.json for a Posit Connect / Connect Cloud deployment.
#
# rsconnect::writeManifest() delegates its per-package dependency snapshot to
# the legacy packrat package, which resolves each Bioconductor package's
# Repository URL on its own, independently of renv and this project's
# renv/settings.json. It always points at Bioconductor's current overall
# release rather than the release renv.lock actually pins, so every
# Bioconductor package ends up tagged with a repository URL one release
# ahead of the version actually recorded. That mismatch is what a Connect
# deploy fails on: "repository Bioconductor X.XX cannot be resolved to a
# URL". The package version rsconnect records is correct; only this URL is
# wrong, so it is patched afterwards rather than the resolution re-run.
#
# Read renv/settings.json directly rather than calling renv::settings(): this
# script is excluded from the deployment bundle via .rscignore, but not from
# writeManifest()'s own dependency scan, which walks the whole project's R
# code independently of that file. A literal renv:: reference here got picked
# up as a project dependency, and Connect Cloud rejects a manifest that
# declares one, since it does not run renv to set up the environment.
library(rsconnect)

settings <- jsonlite::fromJSON("renv/settings.json")
bioc_version <- settings$bioconductor.version
if (!length(bioc_version)) {
  stop("renv/settings.json has no bioconductor.version set.")
}

writeManifest(appDir = ".", appPrimaryDoc = "app.R")

wrong_repo <- "https://bioconductor\\.org/packages/[0-9.]+/"
right_repo <- sprintf("https://bioconductor.org/packages/%s/", bioc_version)

lines <- readLines("manifest.json", warn = FALSE)
matches <- sum(grepl(wrong_repo, lines))
lines <- gsub(wrong_repo, right_repo, lines)
writeLines(lines, "manifest.json")

cat(sprintf(
  "manifest.json written for Bioconductor %s (%d repository URLs corrected)\n",
  bioc_version,
  matches
))
