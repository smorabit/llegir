# Evidence tool: does a module's pseudo-bulk activity differ across a condition

The module-level differential-activity test – the DME successor: does
this module's re-scored *activity* differ across
`ctx$params$contrast_col`, tested on independent pseudo-bulk samples via
[`pseudobulk_view()`](https://smorabit.github.io/llegir/reference/pseudobulk_view.md)
rather than correlated per-cell scores. Emits a
`'cross_condition_delta'` fragment for a two-level contrast, or a
`'categorical_association'` fragment (one row per level, mirroring
[`cluster_dme_tool()`](https://smorabit.github.io/llegir/reference/cluster_dme_tool.md)'s
shape) for a multi-level factor.

## Usage

``` r
differential_module_activity_tool(ctx)
```

## Arguments

- ctx:

  A tool context list: `list(ms, module_id, params)`, as built by
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md).
  `ctx$params$contrast_col` (required) is the pseudo-bulk metadata
  column naming the condition to test. `ctx$params$covariates` is an
  optional character vector of additional metadata columns to adjust for
  (`'limma'` method only). `ctx$params$method` is `'limma'` (default) or
  `'nonparametric'`.

## Value

An `evidence_fragment` of type `'cross_condition_delta'` or
`'categorical_association'`, or `NULL` if
[`pseudobulk_view()`](https://smorabit.github.io/llegir/reference/pseudobulk_view.md)
can't resolve a pseudo-bulk view for `ctx$ms`, `contrast_col` isn't
found in its metadata, or fewer than 2 contrast levels / 3 complete
pseudo-bulk units remain – a graceful skip, not an error.

## Details

`ctx$params$method` selects the statistic: `'limma'` (default) fits
[`limma::lmFit()`](https://rdrr.io/pkg/limma/man/lmFit.html) /
[`limma::eBayes()`](https://rdrr.io/pkg/limma/man/ebayes.html) once over
the **full** `module_scores(pb_view)` matrix – so variance moderation
borrows strength across every module – and extracts the current module's
row; the fit is cached (on a content hash of the module-score matrix and
design) across the per-module orchestrator loop, so it runs exactly once
per dataset, not once per module. `'nonparametric'` reuses
[`categorical_group_test()`](https://smorabit.github.io/llegir/reference/categorical_group_test.md)
(Kruskal-Wallis + one-vs-rest Wilcoxon, rank-biserial) directly on the
module's own pseudo-bulk scores, per module, with no cross-module step.

## Examples

``` r
if (FALSE) { # \dontrun{
pb_ms <- pseudobulk_ModuleSet(pb_counts, list(module_a = c('GENE1', 'GENE2')), pb_meta)
differential_module_activity_tool(list(
    ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'condition')
))
} # }
```
