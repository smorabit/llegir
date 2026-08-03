# Dataset tool: dataset-wide baseline expression and housekeeping signal

Distinguishes specific per-module biology from dataset-wide ambient /
housekeeping signal: mean expression, detection rate, and CV per gene
(`expression(ms)`, full matrix, never returned), the top-N globally
dominant genes by mean expression, ribosomal (`^RP[LS]`) / mitochondrial
(`^MT-`) mass, and a depth (`nCount`) distribution summary. Touches only
the `ModuleSet` adapter contract
([`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
[`counts()`](https://smorabit.github.io/llegir/reference/counts.md),
[`has_capability()`](https://smorabit.github.io/llegir/reference/has_capability.md),
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md)).
Does **not** set the per-module `hub_genes_are_housekeeping` caveat –
that is a judgment about one module's hub genes, made by synthesis after
reading the exposed dominant- gene list, not by this tool.

## Usage

``` r
dataset_baseline_expression_tool(ctx)
```

## Arguments

- ctx:

  A dataset tool context list: `list(ms, params, module_method)`, as
  built by
  [`run_dataset_context()`](https://smorabit.github.io/llegir/reference/run_dataset_context.md).
  `ctx$params$top_n` (default `15`) is the number of globally dominant
  genes (by mean expression) to keep in `result` and `top_findings` –
  this list doubles as the ubiquitous-gene set synthesis can cross-check
  a module's hub genes against.

## Value

A `dataset_fragment` of type `'baseline_expression'`, or `NULL` if
`ctx$ms` lacks the `expression` capability (see
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md))
– a graceful skip, not an error.

## Examples

``` r
ms <- llegir_example_moduleset()
dataset_baseline_expression_tool(list(ms = ms, params = list()))
#> $fragment_id
#> [1] "baseline_expression"
#> 
#> $tool_id
#> [1] "dataset_baseline_expression"
#> 
#> $type
#> [1] "baseline_expression"
#> 
#> $result
#>    gene_name mean_expr detection_rate        cv
#> 1     GENEA9 0.6814702          0.700 0.9788913
#> 2     GENEA6 0.6555608          0.715 0.9573628
#> 3     GENEA3 0.6549227          0.720 0.9859497
#> 4     GENEA8 0.6536075          0.705 0.9995474
#> 5     GENEA1 0.6533208          0.725 1.0038584
#> 6     GENEA5 0.6443494          0.685 0.9848878
#> 7     GENEA2 0.6439812          0.710 0.9904205
#> 8     GENEA4 0.6268506          0.720 0.9905032
#> 9    GENEA10 0.6251210          0.715 0.9796510
#> 10    GENEB2 0.6153008          0.670 1.0584346
#> 11    GENEA7 0.6146316          0.700 1.0260310
#> 12    GENEB3 0.6078200          0.720 1.0558462
#> 13    GENEB4 0.6075764          0.695 1.0380350
#> 14    GENEB1 0.6041303          0.690 1.0457950
#> 15    GENEB5 0.6012699          0.640 1.0787665
#> 
#> $compact_summary
#> [1] "baseline expression across 200 cells: most dominant gene GENEA9 (mean=0.68); ribosomal mass=0%, mitochondrial mass=0%; depth median=19.7"
#> 
#> $top_findings
#> $top_findings[[1]]
#> $top_findings[[1]]$gene_name
#> [1] "GENEA9"
#> 
#> $top_findings[[1]]$mean_expr
#> [1] 0.681
#> 
#> $top_findings[[1]]$detection_rate
#> [1] 0.7
#> 
#> 
#> $top_findings[[2]]
#> $top_findings[[2]]$gene_name
#> [1] "GENEA6"
#> 
#> $top_findings[[2]]$mean_expr
#> [1] 0.656
#> 
#> $top_findings[[2]]$detection_rate
#> [1] 0.715
#> 
#> 
#> $top_findings[[3]]
#> $top_findings[[3]]$gene_name
#> [1] "GENEA3"
#> 
#> $top_findings[[3]]$mean_expr
#> [1] 0.655
#> 
#> $top_findings[[3]]$detection_rate
#> [1] 0.72
#> 
#> 
#> $top_findings[[4]]
#> $top_findings[[4]]$gene_name
#> [1] "GENEA8"
#> 
#> $top_findings[[4]]$mean_expr
#> [1] 0.654
#> 
#> $top_findings[[4]]$detection_rate
#> [1] 0.705
#> 
#> 
#> $top_findings[[5]]
#> $top_findings[[5]]$gene_name
#> [1] "GENEA1"
#> 
#> $top_findings[[5]]$mean_expr
#> [1] 0.653
#> 
#> $top_findings[[5]]$detection_rate
#> [1] 0.725
#> 
#> 
#> $top_findings[[6]]
#> $top_findings[[6]]$gene_name
#> [1] "GENEA5"
#> 
#> $top_findings[[6]]$mean_expr
#> [1] 0.644
#> 
#> $top_findings[[6]]$detection_rate
#> [1] 0.685
#> 
#> 
#> $top_findings[[7]]
#> $top_findings[[7]]$gene_name
#> [1] "GENEA2"
#> 
#> $top_findings[[7]]$mean_expr
#> [1] 0.644
#> 
#> $top_findings[[7]]$detection_rate
#> [1] 0.71
#> 
#> 
#> $top_findings[[8]]
#> $top_findings[[8]]$gene_name
#> [1] "GENEA4"
#> 
#> $top_findings[[8]]$mean_expr
#> [1] 0.627
#> 
#> $top_findings[[8]]$detection_rate
#> [1] 0.72
#> 
#> 
#> $top_findings[[9]]
#> $top_findings[[9]]$gene_name
#> [1] "GENEA10"
#> 
#> $top_findings[[9]]$mean_expr
#> [1] 0.625
#> 
#> $top_findings[[9]]$detection_rate
#> [1] 0.715
#> 
#> 
#> $top_findings[[10]]
#> $top_findings[[10]]$gene_name
#> [1] "GENEB2"
#> 
#> $top_findings[[10]]$mean_expr
#> [1] 0.615
#> 
#> $top_findings[[10]]$detection_rate
#> [1] 0.67
#> 
#> 
#> $top_findings[[11]]
#> $top_findings[[11]]$gene_name
#> [1] "GENEA7"
#> 
#> $top_findings[[11]]$mean_expr
#> [1] 0.615
#> 
#> $top_findings[[11]]$detection_rate
#> [1] 0.7
#> 
#> 
#> $top_findings[[12]]
#> $top_findings[[12]]$gene_name
#> [1] "GENEB3"
#> 
#> $top_findings[[12]]$mean_expr
#> [1] 0.608
#> 
#> $top_findings[[12]]$detection_rate
#> [1] 0.72
#> 
#> 
#> $top_findings[[13]]
#> $top_findings[[13]]$gene_name
#> [1] "GENEB4"
#> 
#> $top_findings[[13]]$mean_expr
#> [1] 0.608
#> 
#> $top_findings[[13]]$detection_rate
#> [1] 0.695
#> 
#> 
#> $top_findings[[14]]
#> $top_findings[[14]]$gene_name
#> [1] "GENEB1"
#> 
#> $top_findings[[14]]$mean_expr
#> [1] 0.604
#> 
#> $top_findings[[14]]$detection_rate
#> [1] 0.69
#> 
#> 
#> $top_findings[[15]]
#> $top_findings[[15]]$gene_name
#> [1] "GENEB5"
#> 
#> $top_findings[[15]]$mean_expr
#> [1] 0.601
#> 
#> $top_findings[[15]]$detection_rate
#> [1] 0.64
#> 
#> 
#> $top_findings[[16]]
#> $top_findings[[16]]$metric
#> [1] "pct_ribo_mass"
#> 
#> $top_findings[[16]]$value
#> [1] 0
#> 
#> 
#> $top_findings[[17]]
#> $top_findings[[17]]$metric
#> [1] "pct_mito_mass"
#> 
#> $top_findings[[17]]$value
#> [1] 0
#> 
#> 
#> $top_findings[[18]]
#> $top_findings[[18]]$metric
#> [1] "depth_distribution"
#> 
#> $top_findings[[18]]$min
#> [1] 4.8
#> 
#> $top_findings[[18]]$median
#> [1] 19.7
#> 
#> $top_findings[[18]]$mean
#> [1] 20.2
#> 
#> $top_findings[[18]]$max
#> [1] 42.5
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
#> $provenance$params$top_n
#> [1] 15
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
#> [1] "2026-08-03T19:21:56+0200"
#> 
#> 
#> $plots
#> NULL
#> 
#> attr(,"class")
#> [1] "dataset_fragment"
```
