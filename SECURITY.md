# Security policy

## Report a vulnerability

Send the details to <samuelbharti.io@gmail.com>. Do not open a public issue for
a security problem. You get an acknowledgement within one week.

## Scope

Recount Explorer is a Shiny app that reads public data. This is what the app
does and what it does not do:

- The app makes outbound HTTPS requests to the recount3 data servers
  (`duffel.rail.bio`) and to Bioconductor. It contacts no other host.
- The app has no accounts, no authentication, and no database.
- The app stores two things on disk. The first is the recount3 downloads that
  BiocFileCache manages. The second is a catalog snapshot under
  `tools::R_user_dir()`.
- Study titles and abstracts are third party text from SRA. The app escapes
  this text before it renders it. A report of a path that does not escape this
  text is in scope.

CAUTION: A large study allocates a lot of memory in the server process. If you
deploy this app in public, size the host for that memory and set a limit on the
sample count.

## Supported versions

The `main` branch is the supported version.
