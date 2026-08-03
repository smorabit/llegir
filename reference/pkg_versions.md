# Backend package versions for provenance logging

Backend package versions for provenance logging

## Usage

``` r
pkg_versions(ms, ...)
```

## Arguments

- ms:

  A `ModuleSet` object.

- ...:

  Passed to methods.

## Value

A named list of backend package versions (e.g. `hdWGCNA`, `Seurat`), so
core tools stay backend-agnostic while still recording which package
versions produced the evidence.
