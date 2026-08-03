# Dataset tool: how much dataset variance aligns with each metadata covariate

The trust prior for every downstream `cross_condition_delta`: runs PCA
on the pseudo-bulk expression matrix, then regresses each principal
component against each declared metadata covariate
(`lm(pc_scores ~ covariate)`), reporting `R2`/`adj_R2`/`fdr` per
covariate x PC pair. Lets the synthesis prompt tell whether a module's
cross-condition signal rides on real biology or on a technical axis
(batch, sequencing depth) that happens to dominate the same principal
component. Ported from `sample_code/pseudobulk_functions.R`
`PseudobulkPCA()` / `PCRegression()` (multi-covariate branch); see
`.pseudobulk_pca()` / `.pc_regression()`.

## Usage

``` r
dataset_variance_structure_tool(ctx)
```

## Arguments

- ctx:

  A dataset tool context list: `list(ms, params, module_method)`, as
  built by
  [`run_dataset_context()`](https://smorabit.github.io/llegir/reference/run_dataset_context.md).
  `ctx$params$covariates` (required) is a character vector of
  pseudo-bulk metadata columns to regress each PC against.
  `ctx$params$condition_col` (required) names the biological covariate
  among `covariates`; every other entry is treated as `'technical'` for
  the confounding check unless `ctx$params$technical_covariates`
  overrides that. `ctx$params$n_components` (default `10`) is the number
  of principal components to compute, clamped to what the pseudo-bulk
  matrix can support.

## Value

A `dataset_fragment` of type `'variance_structure'`, or `NULL` if
[`pseudobulk_view()`](https://smorabit.github.io/llegir/reference/pseudobulk_view.md)
can't resolve a pseudo-bulk view for `ctx$ms` – a graceful skip, not an
error.

## Examples

``` r
if (FALSE) { # \dontrun{
pb_ms <- pseudobulk_ModuleSet(pb_counts, list(module_a = c('GENE1', 'GENE2')), pb_meta)
dataset_variance_structure_tool(list(
    ms = pb_ms, params = list(covariates = c('condition', 'batch'), condition_col = 'condition')
))
} # }
```
