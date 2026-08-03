# Build a ModuleSet from pseudo-bulk counts, re-scoring modules with decoupleR

Ingests a user-supplied pseudo-bulk counts matrix – llegir does not
build pseudo-bulk itself – and re-scores the module definitions directly
on it, rather than averaging cell-level module scores. Scoring runs on a
log2-CPM normalization of `counts` via
[`decoupleR::run_ulm()`](https://saezlab.github.io/decoupleR/reference/run_ulm.html):
each gene's `weight` in `gene_table` (e.g. hdWGCNA kME) becomes
decoupleR's mode-of-regulation (`mor`) when present, otherwise every
gene gets a uniform `mor = 1`. Builds on
[`components_ModuleSet()`](https://smorabit.github.io/llegir/reference/components_ModuleSet.md)
with `data_level = 'pseudobulk'` and `aggregated = TRUE`, so
[`validate_moduleset()`](https://smorabit.github.io/llegir/reference/validate_moduleset.md)
passes and
[`counts()`](https://smorabit.github.io/llegir/reference/counts.md)/`capabilities()$counts`
are populated.

## Usage

``` r
pseudobulk_ModuleSet(
  counts,
  gene_table,
  metadata = NULL,
  assay = "counts",
  group_col = NULL,
  sample_col = NULL,
  data_level = "pseudobulk"
)

# S3 method for class 'pseudobulk_ModuleSet'
pkg_versions(ms, ...)
```

## Arguments

- counts:

  Either a raw-counts matrix (genes x pseudo-bulk units) or a
  `SummarizedExperiment` (assay `assay`, `colData` becomes `metadata`,
  `rownames` are genes).

- gene_table:

  The module definitions to score: a tidy data.frame with `module`,
  `gene_name`, and an optional numeric `weight` column, or a named list
  of gene vectors (one per module, no weights). Normally the same
  modules found at cell level.

- metadata:

  A data.frame with one row per pseudo-bulk unit, aligned to the columns
  of `counts`. Required when `counts` is a raw matrix; ignored (taken
  from `colData`) when `counts` is a `SummarizedExperiment`.

- assay:

  Assay name to read counts from when `counts` is a
  `SummarizedExperiment`. Default `'counts'`.

- group_col:

  Optional name of a `metadata` column declared as the unit-state
  grouping (see
  [`components_ModuleSet()`](https://smorabit.github.io/llegir/reference/components_ModuleSet.md)).

- sample_col:

  Optional name of a `metadata` column declared as the sample id.

- data_level:

  Observation-unit descriptor. Default `'pseudobulk'`; override for
  finer-grained units, e.g. `'pseudobulk_sample_x_cluster'`.

- ms:

  A `ModuleSet` object; the dispatch target for
  [`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md).

- ...:

  Passed to methods.

## Value

A `pseudobulk_ModuleSet` object (a `components_ModuleSet` under the
hood).

## Examples

``` r
if (FALSE) { # \dontrun{
pb_ms <- pseudobulk_ModuleSet(pb_counts, list(module_a = c('GENE1', 'GENE2')), pb_meta)
validate_moduleset(pb_ms)
} # }
```
