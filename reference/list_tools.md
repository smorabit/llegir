# List every registered tool id

List every registered tool id

## Usage

``` r
list_tools(scope = NULL)
```

## Arguments

- scope:

  Filter by
  [`register_tool()`](https://smorabit.github.io/llegir/reference/register_tool.md)'s
  `scope`: `NULL` (default) returns every registered tool, `'module'` or
  `'dataset'` returns only tools registered with that scope.

## Value

A sorted character vector of tool ids.

## Examples

``` r
list_tools()
#> [1] "baseline_expression"          "cluster_dme"                 
#> [3] "composition"                  "differential_module_activity"
#> [5] "geneset_enrichment"           "pseudobulk_de_limma"         
#> [7] "signature_correlation"        "top_genes"                   
#> [9] "variance_structure"          
list_tools('dataset')
#> [1] "baseline_expression" "composition"         "variance_structure" 
```
