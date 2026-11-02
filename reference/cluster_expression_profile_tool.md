# Evidence tool: where each cell state sits in the module's global score distribution

A core evidence tool, and the non-differential sibling of
[`cluster_dme_tool()`](https://smorabit.github.io/llegir/reference/cluster_dme_tool.md).
[`cluster_dme_tool()`](https://smorabit.github.io/llegir/reference/cluster_dme_tool.md)
reports the single most enriched state from a one-vs-all test, which can
hide a state that expresses the module at a medium intensity. This tool
instead bins every cell's module score into deciles of the module's own
global score distribution (all cells in `ctx$ms`, not re-binned per
state) and reports, per state, the mean/median decile its cells occupy,
the mean raw module activity (eigengene) of its cells, and the share of
its cells in the top bin – a graded profile, not a contrast, so it
carries `direction = 'na'`. The raw `mean_activity` sits alongside the
rank-based `mean_decile` so a reader can tell an absolute activity
difference from a distributional one. Touches only the `ModuleSet`
adapter contract
([`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md),
[`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md))
plus base R quantile binning, so it works against any backend.

## Usage

``` r
cluster_expression_profile_tool(ctx)
```

## Arguments

- ctx:

  A tool context list: `list(ms, module_id, params)`, as built by
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md).
  `ctx$params$group_by` (required) is the metadata column naming the
  cell-state grouping (e.g. `'cell_type'`). `ctx$params$n_deciles`
  (default `10`) is the number of global bins requested; a module score
  distribution with heavy ties can realize fewer unique bins than
  requested, in which case the realized bin count is used throughout
  (see Details).

## Value

An `evidence_fragment` of type `'state_expression'`, or `NULL` if
`ctx$ms` lacks the `grouping` or `module_scores` capability (see
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)),
or if the module's score distribution has no spread at all (a single
unique value, so no bin boundaries exist) – both graceful skips, not
errors.

## Examples

``` r
ms <- llegir_example_moduleset()
cluster_expression_profile_tool(list(
    ms = ms, module_id = modules(ms)[1], params = list(group_by = 'cell_type')
))
#> $fragment_id
#> [1] "cluster_expression_profile"
#> 
#> $tool_id
#> [1] "cluster_expression_profile"
#> 
#> $module_id
#> [1] "module_a"
#> 
#> $type
#> [1] "state_expression"
#> 
#> $result
#>       group   n mean_activity mean_decile median_decile  pct_high
#> 1 myeloid_a  99    0.04339845    5.686869             6 0.1010101
#> 2 myeloid_b 101   -0.04253907    5.316832             5 0.0990099
#> 
#> $compact_summary
#> [1] "global module-score deciles (10 realized bins of 10 requested): highest state myeloid_a (mean_decile=5.7/10, mean_activity=0.0434, 10% of its cells in the top bin); 2 states profiled"
#> 
#> $top_findings
#> $top_findings[[1]]
#> $top_findings[[1]]$cluster
#> [1] "myeloid_a"
#> 
#> $top_findings[[1]]$mean_decile
#> [1] 5.686869
#> 
#> $top_findings[[1]]$mean_activity
#> [1] 0.04339845
#> 
#> $top_findings[[1]]$pct_high
#> [1] 0.1010101
#> 
#> 
#> $top_findings[[2]]
#> $top_findings[[2]]$cluster
#> [1] "myeloid_b"
#> 
#> $top_findings[[2]]$mean_decile
#> [1] 5.316832
#> 
#> $top_findings[[2]]$mean_activity
#> [1] -0.04253907
#> 
#> $top_findings[[2]]$pct_high
#> [1] 0.0990099
#> 
#> 
#> 
#> $effect_strength
#> [1] 0.5686869
#> 
#> $significance
#> [1] NA
#> 
#> $direction
#> [1] "na"
#> 
#> $provenance
#> $provenance$tool_version
#> [1] "0.1"
#> 
#> $provenance$params
#> $provenance$params$group_by
#> [1] "cell_type"
#> 
#> $provenance$params$n_deciles
#> [1] 10
#> 
#> $provenance$params$method
#> [1] "global_decile"
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
#> [1] "2026-11-02T18:54:40+0100"
#> 
#> 
#> $plots
#> NULL
#> 
#> attr(,"class")
#> [1] "evidence_fragment"
```
