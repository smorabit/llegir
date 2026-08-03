# Evidence tool: gene-level pseudo-bulk differential expression (limma-voom)

The gene-level complement to
[`differential_module_activity_tool()`](https://smorabit.github.io/llegir/reference/differential_module_activity_tool.md):
runs limma-voom
([`limma::voom()`](https://rdrr.io/pkg/limma/man/voom.html) /
[`limma::lmFit()`](https://rdrr.io/pkg/limma/man/lmFit.html) /
[`limma::eBayes()`](https://rdrr.io/pkg/limma/man/ebayes.html)) on the
pseudo-bulk **raw counts**
([`counts()`](https://smorabit.github.io/llegir/reference/counts.md))
restricted to the current module's own genes
([`gene_membership()`](https://smorabit.github.io/llegir/reference/gene_membership.md)),
for the declared two-level `ctx$params$contrast_col`. Reports which
genes drive the shift, rather than the module-level activity
[`differential_module_activity_tool()`](https://smorabit.github.io/llegir/reference/differential_module_activity_tool.md)
already covers.

## Usage

``` r
pseudobulk_de_limma_tool(ctx)
```

## Arguments

- ctx:

  A tool context list: `list(ms, module_id, params)`, as built by
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md).
  `ctx$params$contrast_col` (required) is the pseudo-bulk metadata
  column naming the two-level condition to test. `ctx$params$covariates`
  is an optional character vector of additional metadata columns to
  adjust for. `ctx$params$min_count` (default `10`) and
  `ctx$params$min_samples` (default `3`) set the low-count gene filter:
  a gene needs at least `min_count` reads in at least `min_samples` of
  the tested pseudo-bulk units to be kept.

## Value

An `evidence_fragment` of type `'cross_condition_delta'` (one row per
gene), or `NULL` if
[`pseudobulk_view()`](https://smorabit.github.io/llegir/reference/pseudobulk_view.md)
can't resolve a pseudo-bulk view for `ctx$ms`, that view lacks the
`counts` capability, `contrast_col` isn't found or doesn't have exactly
2 levels, none of the module's genes are present in
[`counts()`](https://smorabit.github.io/llegir/reference/counts.md), or
no gene survives the low-count filter – a graceful skip, not an error.

## Examples

``` r
if (FALSE) { # \dontrun{
pb_ms <- pseudobulk_ModuleSet(pb_counts, list(module_a = c('GENE1', 'GENE2')), pb_meta)
pseudobulk_de_limma_tool(list(
    ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'condition')
))
} # }
```
