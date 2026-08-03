# Import a miloR differential-abundance neighborhood table

Sensible defaults for `miloR::testNhoods()` output merged with
`miloR::annotateNhoods()` (`logFC`, `SpatialFDR`, and a majority-vote
cell-type annotation column defaulting to `celltype`). Neighborhoods are
aggregated per annotation group into a `'composition_summary'`
[`dataset_fragment()`](https://smorabit.github.io/llegir/reference/dataset_fragment.md):
how many neighborhoods per cell state shift significantly and in which
direction – never the raw per-neighborhood table.

## Usage

``` r
import_milo_da(
  result,
  column_map = list(),
  alpha = 0.05,
  source_file = NULL,
  ...
)
```

## Arguments

- result:

  A tidy miloR DA neighborhood result data.frame (one row per
  neighborhood).

- column_map:

  Named list of column overrides: `group_col` (default `'celltype'`),
  `effect_col` (default `'logFC'`), `significance_col` (default
  `'SpatialFDR'`).

- alpha:

  Significance threshold for a neighborhood to count as shifted. Default
  `0.05`.

- source_file:

  Optional path `result` was read from; see
  [`import_dataset_fragment()`](https://smorabit.github.io/llegir/reference/import_dataset_fragment.md).

- ...:

  Passed to
  [`import_dataset_fragment()`](https://smorabit.github.io/llegir/reference/import_dataset_fragment.md)
  (e.g. `fragment_id`, `tool_id`).

## Value

A `dataset_fragment` object.
