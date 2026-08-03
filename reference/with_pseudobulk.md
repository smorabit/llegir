# Attach a pseudo-bulk ModuleSet view to a cell-level ModuleSet

Stores `pb_ms` on `cell_ms` and flips `cell_ms`'s `pseudobulk`
capability to `TRUE`, so cell-level tools keep using `cell_ms` as their
primary view while pseudo-bulk-specific tools pull the sample-level view
via
[`pseudobulk()`](https://smorabit.github.io/llegir/reference/pseudobulk.md)
/
[`pseudobulk_view()`](https://smorabit.github.io/llegir/reference/pseudobulk_view.md).
Implemented by prepending a decorator class rather than rewriting every
adapter:
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)
and
[`pseudobulk()`](https://smorabit.github.io/llegir/reference/pseudobulk.md)
get an override, every other generic
([`modules()`](https://smorabit.github.io/llegir/reference/modules.md),
[`gene_membership()`](https://smorabit.github.io/llegir/reference/gene_membership.md),
[`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md),
[`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
[`counts()`](https://smorabit.github.io/llegir/reference/counts.md),
[`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md))
falls through unchanged to `cell_ms`'s own method.

## Usage

``` r
with_pseudobulk(cell_ms, pb_ms)

# S3 method for class 'with_pseudobulk_ModuleSet'
capabilities(ms, ...)
```

## Arguments

- cell_ms:

  A cell-level `ModuleSet` (e.g. built by
  [`hdWGCNA_ModuleSet()`](https://smorabit.github.io/llegir/reference/hdWGCNA_ModuleSet.md)).

- pb_ms:

  A pseudo-bulk `ModuleSet`, normally built by
  [`pseudobulk_ModuleSet()`](https://smorabit.github.io/llegir/reference/pseudobulk_ModuleSet.md).

- ms:

  A `ModuleSet` object; the dispatch target for
  `capabilities.with_pseudobulk_ModuleSet()`.

- ...:

  Passed to methods.

## Value

`cell_ms`, with `pb_ms` attached.

## Examples

``` r
if (FALSE) { # \dontrun{
ms <- with_pseudobulk(cell_ms, pb_ms)
has_capability(ms, 'pseudobulk')
pseudobulk(ms)
} # }
```
