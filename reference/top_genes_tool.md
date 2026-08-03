# Evidence tool: top module genes ranked by membership (kME)

A core evidence tool. Touches only the `ModuleSet` adapter contract
([`gene_membership()`](https://smorabit.github.io/llegir/reference/gene_membership.md),
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md)),
so it works against any backend.

## Usage

``` r
top_genes_tool(ctx)
```

## Arguments

- ctx:

  A tool context list: `list(ms, module_id, params)`, as built by
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md).
  `ctx$params$n_hubs` (default 25) is the number of top genes to keep.

## Value

An `evidence_fragment` of type `'ranked_genes'`.

## Examples

``` r
ms <- llegir_example_moduleset()
top_genes_tool(list(ms = ms, module_id = modules(ms)[1], params = list(n_hubs = 10)))
#> $fragment_id
#> [1] "top_genes"
#> 
#> $tool_id
#> [1] "top_genes"
#> 
#> $module_id
#> [1] "module_a"
#> 
#> $type
#> [1] "ranked_genes"
#> 
#> $result
#>    gene_name   module       kme
#> 4     GENEA4 module_a 0.9389462
#> 9     GENEA9 module_a 0.9368404
#> 5     GENEA5 module_a 0.9330942
#> 10   GENEA10 module_a 0.9324491
#> 8     GENEA8 module_a 0.9304695
#> 1     GENEA1 module_a 0.9299657
#> 2     GENEA2 module_a 0.9242594
#> 7     GENEA7 module_a 0.9236174
#> 3     GENEA3 module_a 0.9157541
#> 6     GENEA6 module_a 0.9102198
#> 
#> $compact_summary
#> [1] "top 10 genes by kME: GENEA4, GENEA9, GENEA5, GENEA10, GENEA8, GENEA1, GENEA2, GENEA7, GENEA3, GENEA6"
#> 
#> $top_findings
#> $top_findings[[1]]
#> $top_findings[[1]]$gene
#> [1] "GENEA4"
#> 
#> $top_findings[[1]]$kme
#> [1] 0.9389462
#> 
#> 
#> $top_findings[[2]]
#> $top_findings[[2]]$gene
#> [1] "GENEA9"
#> 
#> $top_findings[[2]]$kme
#> [1] 0.9368404
#> 
#> 
#> $top_findings[[3]]
#> $top_findings[[3]]$gene
#> [1] "GENEA5"
#> 
#> $top_findings[[3]]$kme
#> [1] 0.9330942
#> 
#> 
#> $top_findings[[4]]
#> $top_findings[[4]]$gene
#> [1] "GENEA10"
#> 
#> $top_findings[[4]]$kme
#> [1] 0.9324491
#> 
#> 
#> $top_findings[[5]]
#> $top_findings[[5]]$gene
#> [1] "GENEA8"
#> 
#> $top_findings[[5]]$kme
#> [1] 0.9304695
#> 
#> 
#> $top_findings[[6]]
#> $top_findings[[6]]$gene
#> [1] "GENEA1"
#> 
#> $top_findings[[6]]$kme
#> [1] 0.9299657
#> 
#> 
#> $top_findings[[7]]
#> $top_findings[[7]]$gene
#> [1] "GENEA2"
#> 
#> $top_findings[[7]]$kme
#> [1] 0.9242594
#> 
#> 
#> $top_findings[[8]]
#> $top_findings[[8]]$gene
#> [1] "GENEA7"
#> 
#> $top_findings[[8]]$kme
#> [1] 0.9236174
#> 
#> 
#> $top_findings[[9]]
#> $top_findings[[9]]$gene
#> [1] "GENEA3"
#> 
#> $top_findings[[9]]$kme
#> [1] 0.9157541
#> 
#> 
#> $top_findings[[10]]
#> $top_findings[[10]]$gene
#> [1] "GENEA6"
#> 
#> $top_findings[[10]]$kme
#> [1] 0.9102198
#> 
#> 
#> 
#> $effect_strength
#> [1] 0.9389462
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
#> $provenance$params$n_hubs
#> [1] 10
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
#> [1] "2026-08-03T19:20:45+0200"
#> 
#> 
#> $plots
#> NULL
#> 
#> attr(,"class")
#> [1] "evidence_fragment"
```
