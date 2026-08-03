# Import an hdWGCNA differential module eigengene (DME) table

Sensible defaults for
[`hdWGCNA::FindAllDMEs()`](https://smorabit.github.io/hdWGCNA/reference/FindAllDMEs.html)
output (`group`, `avg_log2FC`, `p_val_adj`). Produces a
`'state_expression'` fragment — the same type
[`cluster_dme_tool()`](https://smorabit.github.io/llegir/reference/cluster_dme_tool.md)
produces — so an externally computed DME table (run outside this
package, or against a different grouping) feeds the synthesis layer
identically to the built-in tool.

## Usage

``` r
import_hdwgcna_dme(
  module_id,
  result,
  column_map = list(),
  source_file = NULL,
  ...
)
```

## Arguments

- module_id:

  The module this fragment describes.

- result:

  A tidy DME result data.frame (one row per group).

- column_map:

  Named list of column overrides: `group_col` (default `'group'`),
  `effect_col` (default `'avg_log2FC'`), `significance_col` (default
  `'p_val_adj'`).

- source_file:

  Optional path `result` was read from; see
  [`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md).

- ...:

  Passed to
  [`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md)
  (e.g. `fragment_id`, `tool_id`).

## Value

An `evidence_fragment` object.
