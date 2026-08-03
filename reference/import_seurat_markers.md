# Import a Seurat / DESeq2 / edgeR differential-expression table

Sensible defaults for
[`Seurat::FindMarkers()`](https://satijalab.org/seurat/reference/FindMarkers.html)
output (`avg_log2FC`, `p_val_adj`, feature names as rownames). Point
`column_map` at a DESeq2 (`log2FoldChange`/`padj`) or edgeR
(`logFC`/`FDR`) table instead to reuse the same importer. If `result`
has a `group_col` (e.g. `cluster`, as in
[`Seurat::FindAllMarkers()`](https://satijalab.org/seurat/reference/FindAllMarkers.html)),
the fragment is a per-group `'categorical_association'`; otherwise it's
a single-contrast `'cross_condition_delta'` (one row per gene/feature).

## Usage

``` r
import_seurat_markers(
  module_id,
  result,
  group_col = "cluster",
  column_map = list(),
  source_file = NULL,
  ...
)
```

## Arguments

- module_id:

  The module this fragment describes.

- result:

  A tidy DE result data.frame.

- group_col:

  Column naming a group/cluster contrast, if any (default `'cluster'`).
  Only used if present in `result`.

- column_map:

  Named list of column overrides: `feature_col` (default `'gene'`, falls
  back to rownames if absent), `effect_col` (default `'avg_log2FC'`),
  `significance_col` (default `'p_val_adj'`).

- source_file:

  Optional path `result` was read from; see
  [`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md).

- ...:

  Passed to
  [`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md)
  (e.g. `fragment_id`, `tool_id`).

## Value

An `evidence_fragment` object.
