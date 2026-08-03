# Import an EnrichR / GeneOverlap enrichment table

Sensible defaults for EnrichR output (`Term`, `Odds.Ratio`,
`Adjusted.P.value`). Point `column_map` at a `GeneOverlap`-style table
instead (e.g.
`list(term_col = 'category', effect_col = 'odds.ratio', significance_col = 'pval')`)
to reuse the same importer.

## Usage

``` r
import_enrichr(module_id, result, column_map = list(), source_file = NULL, ...)
```

## Arguments

- module_id:

  The module this fragment describes.

- result:

  A tidy enrichment result data.frame.

- column_map:

  Named list of column overrides: `term_col` (default `'Term'`),
  `effect_col` (default `'Odds.Ratio'`), `significance_col` (default
  `'Adjusted.P.value'`).

- source_file:

  Optional path `result` was read from; see
  [`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md).

- ...:

  Passed to
  [`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md)
  (e.g. `fragment_id`, `tool_id`).

## Value

An `evidence_fragment` object.
