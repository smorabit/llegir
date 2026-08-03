# Build a ModuleSet from tidy components

The general-purpose `ModuleSet` substrate: takes a module\<-\>gene
table, an optional module-scores matrix, an expression matrix, and
metadata directly, with no backend dependency. Other adapters (e.g.
[`hdWGCNA_ModuleSet()`](https://smorabit.github.io/llegir/reference/hdWGCNA_ModuleSet.md),
[`gene_list_ModuleSet()`](https://smorabit.github.io/llegir/reference/gene_list_ModuleSet.md))
build on this by extracting their own data into these same shapes and
delegating.

## Usage

``` r
components_ModuleSet(
  gene_table,
  expression = NULL,
  metadata,
  scores = NULL,
  counts = NULL,
  group_col = NULL,
  sample_col = NULL,
  pkg_versions = NULL,
  data_level = "cell",
  aggregated = FALSE
)

# S3 method for class 'components_ModuleSet'
modules(ms, ...)

# S3 method for class 'components_ModuleSet'
gene_membership(ms, module, ...)

# S3 method for class 'components_ModuleSet'
module_scores(ms, module = NULL, ...)

# S3 method for class 'components_ModuleSet'
expression(ms, ...)

# S3 method for class 'components_ModuleSet'
counts(ms, ...)

# S3 method for class 'components_ModuleSet'
metadata(ms, ...)

# S3 method for class 'components_ModuleSet'
pkg_versions(ms, ...)

# S3 method for class 'components_ModuleSet'
capabilities(ms, ...)
```

## Arguments

- gene_table:

  A data.frame with one row per module-gene assignment: `module`,
  `gene_name`, and an optional numeric `weight` column (e.g. kME). If
  `weight` is absent,
  [`gene_membership()`](https://smorabit.github.io/llegir/reference/gene_membership.md)
  reports `kme = NA_real_` for every gene and
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)`$gene_weights`
  is `FALSE`.

- expression:

  A genes-by-cells (or genes-by-samples) numeric matrix, or `NULL` for a
  reduced view with the backing matrix dropped (e.g.
  [`.make_moduleset_lite()`](https://smorabit.github.io/llegir/reference/dot-make_moduleset_lite.md)).
  If `NULL`,
  [`expression()`](https://smorabit.github.io/llegir/reference/expression.md)
  returns `NULL` and
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)`$expression`
  is `FALSE`.

- metadata:

  A data.frame with one row per cell/sample, aligned to the columns of
  `expression`.

- scores:

  Optional module-scores data.frame/matrix: one row per cell/sample
  (aligned to `expression`'s columns, same order), one column per module
  – the same shape
  [`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md)
  documents. If omitted,
  [`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md)
  returns `NULL` and
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)`$module_scores`
  is `FALSE`.

- counts:

  Optional genes-by-cells (or genes-by-samples) raw counts matrix, same
  dimensions as `expression`. If omitted,
  [`counts()`](https://smorabit.github.io/llegir/reference/counts.md)
  returns `NULL` and
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)`$counts`
  is `FALSE`.

- group_col:

  Optional name of a `metadata` column declared as the cell/sample-state
  grouping. This only drives
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)`$grouping`
  – core tools still take the grouping column name as a parameter (e.g.
  `cluster_dme_tool`'s `group_by`); declaring `group_col` is how this
  ModuleSet advertises that it supports the concept at all.

- sample_col:

  Optional name of a `metadata` column declared as the sample id,
  analogous to `group_col` for
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)`$sample_ids`.

- pkg_versions:

  Optional named list overriding what
  [`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md)
  reports (default `list(llegir = ...)`). Used by callers rebuilding a
  `components_ModuleSet` from another adapter (e.g. the agent workspace
  exporter's lite object) that want
  [`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md)
  to keep reporting the original backend's versions rather than falling
  back to `llegir` alone.

- data_level:

  Observation-unit descriptor, e.g. `'cell'` or `'sample'`. Default
  `'cell'`.

- aggregated:

  Whether `expression`/`scores` are already aggregated across cells
  (e.g. pseudobulk) rather than per-cell. Default `FALSE`.

- ms:

  A `ModuleSet` object; the dispatch target for the generic methods
  below
  ([`modules()`](https://smorabit.github.io/llegir/reference/modules.md),
  [`gene_membership()`](https://smorabit.github.io/llegir/reference/gene_membership.md),
  [`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md),
  [`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
  [`counts()`](https://smorabit.github.io/llegir/reference/counts.md),
  [`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
  [`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md),
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)).

- ...:

  Passed to methods.

- module:

  A single module id, as returned by
  [`modules()`](https://smorabit.github.io/llegir/reference/modules.md).

## Value

A `components_ModuleSet` object.

## Examples

``` r
gene_table <- data.frame(module = 'm1', gene_name = c('G1', 'G2'), weight = c(0.9, 0.5))
expr <- matrix(rnorm(20), nrow = 2, dimnames = list(c('G1', 'G2'), paste0('c', 1:10)))
meta <- data.frame(cell_type = rep(c('a', 'b'), 5), row.names = colnames(expr))
ms <- components_ModuleSet(gene_table, expr, meta, group_col = 'cell_type')
modules(ms)
#> [1] "m1"
```
