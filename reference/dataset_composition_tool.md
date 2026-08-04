# Dataset tool: cell-state census and condition covariate balance

A core dataset tool. Touches only the `ModuleSet` adapter contract
([`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
[`has_capability()`](https://smorabit.github.io/llegir/reference/has_capability.md),
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md)).
Summarizes how units (cells or samples) distribute across
`ctx$params$group_col` and, when `ctx$params$condition_col` is given,
whether that distribution is skewed across condition levels – the
compositional-confounding check every per-module synthesis should see as
global framing before it interprets a module as biology rather than
cell-type imbalance.

## Usage

``` r
dataset_composition_tool(ctx)
```

## Arguments

- ctx:

  A dataset tool context list: `list(ms, params, module_method)`, as
  built by
  [`run_dataset_context()`](https://smorabit.github.io/llegir/reference/run_dataset_context.md).
  `ctx$params$group_col` (required) is the metadata column naming the
  cell-state/cluster grouping. `ctx$params$condition_col` (optional) is
  the metadata column to check the grouping for skew against; when
  omitted, only a group census is computed. `ctx$params$sample_col`
  (default `'sample'`) names the metadata sample-id column, consulted
  when the `sample_ids` capability holds.
  `ctx$params$residual_threshold` (default `2`) is the absolute
  chi-square standardized residual above which a group x condition cell
  is flagged. `ctx$params$min_samples` (default `3`) and
  `ctx$params$min_cells` (default `20`) are the per-condition minimums
  below which `'underpowered_contrast'` fires.

## Value

A `dataset_fragment` of type `'composition_summary'`, or `NULL` if
`ctx$ms` lacks the `grouping` capability (see
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md))
– a graceful skip, not an error.

## Examples

``` r
ms <- llegir_example_moduleset()
params <- list(group_col = 'cell_type', condition_col = 'diagnosis')
dataset_composition_tool(list(ms = ms, params = params))
#> $fragment_id
#> [1] "composition"
#> 
#> $tool_id
#> [1] "dataset_composition"
#> 
#> $type
#> [1] "composition_summary"
#> 
#> $result
#>       group condition  n prop_of_condition expected  std_resid
#> 1 myeloid_a      case 53         0.5196078    50.49  0.7101127
#> 2 myeloid_b      case 49         0.4803922    51.51 -0.7101127
#> 3 myeloid_a   control 46         0.4693878    48.51 -0.7101127
#> 4 myeloid_b   control 52         0.5306122    49.49  0.7101127
#> 
#> $compact_summary
#> [1] "across 200 cells: cell_type spans 2 levels (entropy=0.69); strongest skew vs diagnosis: myeloid_a in case (z=0.71)"
#> 
#> $top_findings
#> $top_findings[[1]]
#> $top_findings[[1]]$group
#> [1] "myeloid_a"
#> 
#> $top_findings[[1]]$condition
#> [1] "case"
#> 
#> $top_findings[[1]]$n
#> [1] 53
#> 
#> $top_findings[[1]]$std_resid
#> [1] 0.71
#> 
#> $top_findings[[1]]$direction
#> [1] "over"
#> 
#> 
#> $top_findings[[2]]
#> $top_findings[[2]]$group
#> [1] "myeloid_b"
#> 
#> $top_findings[[2]]$condition
#> [1] "case"
#> 
#> $top_findings[[2]]$n
#> [1] 49
#> 
#> $top_findings[[2]]$std_resid
#> [1] -0.71
#> 
#> $top_findings[[2]]$direction
#> [1] "under"
#> 
#> 
#> $top_findings[[3]]
#> $top_findings[[3]]$group
#> [1] "myeloid_a"
#> 
#> $top_findings[[3]]$condition
#> [1] "control"
#> 
#> $top_findings[[3]]$n
#> [1] 46
#> 
#> $top_findings[[3]]$std_resid
#> [1] -0.71
#> 
#> $top_findings[[3]]$direction
#> [1] "under"
#> 
#> 
#> $top_findings[[4]]
#> $top_findings[[4]]$group
#> [1] "myeloid_b"
#> 
#> $top_findings[[4]]$condition
#> [1] "control"
#> 
#> $top_findings[[4]]$n
#> [1] 52
#> 
#> $top_findings[[4]]$std_resid
#> [1] 0.71
#> 
#> $top_findings[[4]]$direction
#> [1] "over"
#> 
#> 
#> $top_findings[[5]]
#> $top_findings[[5]]$metric
#> [1] "shannon_entropy"
#> 
#> $top_findings[[5]]$value
#> [1] 0.693
#> 
#> 
#> $top_findings[[6]]
#> $top_findings[[6]]$metric
#> [1] "samples_per_condition"
#> 
#> $top_findings[[6]]$condition
#> [1] "case"
#> 
#> $top_findings[[6]]$n_samples
#> [1] 4
#> 
#> 
#> $top_findings[[7]]
#> $top_findings[[7]]$metric
#> [1] "samples_per_condition"
#> 
#> $top_findings[[7]]$condition
#> [1] "control"
#> 
#> $top_findings[[7]]$n_samples
#> [1] 4
#> 
#> 
#> 
#> $caveats
#> list()
#> 
#> $provenance
#> $provenance$tool_version
#> [1] "0.1"
#> 
#> $provenance$params
#> $provenance$params$group_col
#> [1] "cell_type"
#> 
#> $provenance$params$condition_col
#> [1] "diagnosis"
#> 
#> 
#> $provenance$input_hashes
#> list()
#> 
#> $provenance$pkg_versions
#> $provenance$pkg_versions$llegir
#> [1] "0.0.0.9000"
#> 
#> 
#> $provenance$source
#> [1] "computed"
#> 
#> $provenance$module_method
#> [1] NA
#> 
#> $provenance$timestamp
#> [1] "2026-08-04T17:22:36+0200"
#> 
#> 
#> $plots
#> NULL
#> 
#> attr(,"class")
#> [1] "dataset_fragment"
```
