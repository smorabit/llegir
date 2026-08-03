# Build a ModuleSet from named gene lists, scoring on the fly

Takes named gene lists as the modules (no membership weights – every
gene counts equally) and computes per-cell/sample module scores on the
fly via
[`UCell::ScoreSignatures_UCell()`](https://rdrr.io/pkg/UCell/man/ScoreSignatures_UCell.html)
or
[`decoupleR::run_ulm()`](https://saezlab.github.io/decoupleR/reference/run_ulm.html).
Builds on
[`components_ModuleSet()`](https://smorabit.github.io/llegir/reference/components_ModuleSet.md);
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)`$gene_weights`
is `FALSE` (there's no kME-equivalent), `module_scores`/`expression` are
`TRUE`, and `grouping`/`sample_ids` follow `group_col`/`sample_col` as
usual.

## Usage

``` r
gene_list_ModuleSet(
  gene_sets,
  expression,
  metadata,
  counts = NULL,
  group_col = NULL,
  sample_col = NULL,
  method = c("UCell", "decoupleR"),
  data_level = "cell",
  aggregated = FALSE,
  ...
)

# S3 method for class 'gene_list_ModuleSet'
pkg_versions(ms, ...)
```

## Arguments

- gene_sets:

  A named list of character vectors, one per module, e.g.
  `list(module_a = c('GENE1', 'GENE2'))`. Genes not present in
  `expression` are dropped.

- expression:

  A genes-by-cells (or genes-by-samples) numeric matrix.

- metadata:

  A data.frame with one row per cell/sample, aligned to the columns of
  `expression`.

- counts:

  Optional genes-by-cells (or genes-by-samples) raw counts matrix, same
  dimensions as `expression`. If omitted,
  [`counts()`](https://smorabit.github.io/llegir/reference/counts.md)
  returns `NULL` and
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)`$counts`
  is `FALSE`.

- group_col:

  Optional name of a `metadata` column declared as the cell/sample-state
  grouping.

- sample_col:

  Optional name of a `metadata` column declared as the sample id.

- method:

  Scoring method: `'UCell'` (default,
  [`UCell::ScoreSignatures_UCell()`](https://rdrr.io/pkg/UCell/man/ScoreSignatures_UCell.html))
  or `'decoupleR'`
  ([`decoupleR::run_ulm()`](https://saezlab.github.io/decoupleR/reference/run_ulm.html)
  over a network built from `gene_sets` with a uniform
  mode-of-regulation, since these gene lists carry no signed weights).

- data_level:

  Observation-unit descriptor, e.g. `'cell'` or `'sample'`. Default
  `'cell'`.

- aggregated:

  Whether `expression` is already aggregated across cells (e.g.
  pseudobulk) rather than per-cell. Default `FALSE`.

- ...:

  Passed through to the scoring backend
  ([`UCell::ScoreSignatures_UCell()`](https://rdrr.io/pkg/UCell/man/ScoreSignatures_UCell.html)'s
  `...`, or
  [`decoupleR::run_ulm()`](https://saezlab.github.io/decoupleR/reference/run_ulm.html)'s
  `minsize` etc.).

- ms:

  A `ModuleSet` object; the dispatch target for
  [`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md).

## Value

A `gene_list_ModuleSet` object (a `components_ModuleSet` under the
hood).

## Examples

``` r
expr <- matrix(abs(rnorm(40)), nrow = 4, dimnames = list(paste0('G', 1:4), paste0('c', 1:10)))
meta <- data.frame(cell_type = rep(c('a', 'b'), 5), row.names = colnames(expr))
ms <- gene_list_ModuleSet(list(m1 = c('G1', 'G2')), expr, meta, group_col = 'cell_type')
modules(ms)
#> [1] "m1"
```
