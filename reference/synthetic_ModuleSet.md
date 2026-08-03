# Wrap a ModuleSet with hand-picked gene sets as synthetic modules

Wraps `base_ms` (any `ModuleSet`) and swaps in `gene_sets` as fake
"modules", so ground-truth gene sets can be run through the same core
tools as a real module. Delegates
[`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
[`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
and
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md)
to `base_ms`; module score is the mean z-scored expression across each
gene set per cell, and `kme` (returned by
[`gene_membership()`](https://smorabit.github.io/llegir/reference/gene_membership.md))
is each gene's correlation with that score – a simple, backend-agnostic
stand-in for a real module eigengene / kME.

## Usage

``` r
synthetic_ModuleSet(
  base_ms,
  gene_sets,
  data_level = "cell",
  aggregated = FALSE
)

# S3 method for class 'synthetic_ModuleSet'
modules(ms, ...)

# S3 method for class 'synthetic_ModuleSet'
module_scores(ms, module = NULL, ...)

# S3 method for class 'synthetic_ModuleSet'
gene_membership(ms, module, ...)

# S3 method for class 'synthetic_ModuleSet'
expression(ms, ...)

# S3 method for class 'synthetic_ModuleSet'
counts(ms, ...)

# S3 method for class 'synthetic_ModuleSet'
metadata(ms, ...)

# S3 method for class 'synthetic_ModuleSet'
pkg_versions(ms, ...)

# S3 method for class 'synthetic_ModuleSet'
capabilities(ms, ...)
```

## Arguments

- base_ms:

  A `ModuleSet` to delegate
  [`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
  [`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
  and
  [`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md)
  to.

- gene_sets:

  A named list of character vectors, one per synthetic module, e.g.
  `list(module_a = c('GENE1', 'GENE2'))`.

- data_level:

  Observation-unit descriptor, e.g. `'cell'` or `'sample'`. Default
  `'cell'`.

- aggregated:

  Whether
  [`expression()`](https://smorabit.github.io/llegir/reference/expression.md)
  is already aggregated across cells (e.g. pseudobulk) rather than
  per-cell. Default `FALSE`.

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

A `synthetic_ModuleSet` object.

## Examples

``` r
ms <- llegir_example_moduleset()
modules(ms)
#> [1] "module_a" "module_b"
```
