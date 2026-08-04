# Evidence tool: which cell states express this module

A core evidence tool. Touches only the `ModuleSet` adapter contract
([`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md),
[`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md))
plus the shared
[`categorical_group_test()`](https://smorabit.github.io/llegir/reference/categorical_group_test.md)
helper, so it works against any backend.

## Usage

``` r
cluster_dme_tool(ctx)
```

## Arguments

- ctx:

  A tool context list: `list(ms, module_id, params)`, as built by
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md).
  `ctx$params$group_by` (required) is the metadata column naming the
  cell-state grouping (e.g. `'lv2_annot'`).

## Value

An `evidence_fragment` of type `'state_expression'`, or `NULL` if
`ctx$ms` lacks the `grouping` or `module_scores` capability (see
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md))
– a graceful skip, not an error.

## Examples

``` r
ms <- llegir_example_moduleset()
cluster_dme_tool(list(ms = ms, module_id = modules(ms)[1], params = list(group_by = 'cell_type')))
#> $fragment_id
#> [1] "cluster_dme"
#> 
#> $tool_id
#> [1] "cluster_dme"
#> 
#> $module_id
#> [1] "module_a"
#> 
#> $type
#> [1] "state_expression"
#> 
#> $result
#>       group  n mean_score median_score rank_biserial   p_value       fdr
#> 2 myeloid_a 99 0.04339845  -0.07218409    0.06950695 0.3962589 0.3962589
#>   direction
#> 2        up
#> 
#> $compact_summary
#> [1] "strongest state: myeloid_a (r=0.07, FDR=0.4); omnibus Kruskal p=0.4"
#> 
#> $top_findings
#> $top_findings[[1]]
#> $top_findings[[1]]$cluster
#> [1] "myeloid_a"
#> 
#> $top_findings[[1]]$mean_score
#> [1] 0.04339845
#> 
#> $top_findings[[1]]$rank_biserial
#> [1] 0.06950695
#> 
#> $top_findings[[1]]$fdr
#> [1] 0.3962589
#> 
#> 
#> 
#> $effect_strength
#> [1] 0.06950695
#> 
#> $significance
#> [1] 0.3955787
#> 
#> $direction
#> [1] "up"
#> 
#> $provenance
#> $provenance$tool_version
#> [1] "0.1"
#> 
#> $provenance$params
#> $provenance$params$group_by
#> [1] "cell_type"
#> 
#> $provenance$params$method
#> [1] "per_cell"
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
#> [1] "2026-08-04T18:45:27+0200"
#> 
#> 
#> $plots
#> NULL
#> 
#> attr(,"class")
#> [1] "evidence_fragment"
```
