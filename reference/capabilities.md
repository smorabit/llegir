# Which capabilities a ModuleSet provides

Reports which of a fixed vocabulary this module set supports:
`gene_weights` (real per-gene membership weights, e.g. kME, not a
uniform placeholder), `module_scores` (per-cell/sample module scores are
available), `expression` (the backing expression matrix is available),
`counts` (a raw counts matrix is available, see
[`counts()`](https://smorabit.github.io/llegir/reference/counts.md)),
`grouping` (a cell/sample-state grouping column was declared to the
adapter), `sample_ids` (a sample-id column was declared), and
`pseudobulk` (a pseudo-bulk view is resolvable via
[`pseudobulk_view()`](https://smorabit.github.io/llegir/reference/pseudobulk_view.md)
– `TRUE` for a
[`pseudobulk_ModuleSet()`](https://smorabit.github.io/llegir/reference/pseudobulk_ModuleSet.md)'s
own attached-view wrapper produced by
[`with_pseudobulk()`](https://smorabit.github.io/llegir/reference/with_pseudobulk.md),
`FALSE` otherwise, including for a standalone `pseudobulk_ModuleSet`
itself, which resolves via `data_level`/`aggregated` rather than an
attachment). Capabilities are declared by the adapter, not inferred from
probing
[`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md)
– declaring `grouping`/`sample_ids` is how a source advertises that it
supports that concept at all, independent of which particular metadata
column a tool is asked to use. Core tools consult this
([`has_capability()`](https://smorabit.github.io/llegir/reference/has_capability.md))
before running so they can skip gracefully instead of erroring when a
capability the source doesn't support is required. See
[`validate_moduleset()`](https://smorabit.github.io/llegir/reference/validate_moduleset.md)
for the full contract check, including that this vector covers the whole
vocabulary.

## Usage

``` r
capabilities(ms, ...)
```

## Arguments

- ms:

  A `ModuleSet` object.

- ...:

  Passed to methods.

## Value

A named logical vector over
`c('gene_weights', 'module_scores', 'expression', 'counts', 'grouping', 'sample_ids', 'pseudobulk')`.
