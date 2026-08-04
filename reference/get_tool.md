# Look up a registered tool spec by id

Look up a registered tool spec by id

## Usage

``` r
get_tool(id)
```

## Arguments

- id:

  A tool id, as passed to
  [`register_tool()`](https://smorabit.github.io/llegir/reference/register_tool.md).

## Value

A `tool_spec` object: `list(id, fn, type, description, requires)`.

## Examples

``` r
get_tool('top_genes')
#> $id
#> [1] "top_genes"
#> 
#> $fn
#> function (ctx) 
#> {
#>     n_hubs <- ctx$params$n_hubs %||% 25
#>     gm <- gene_membership(ctx$ms, ctx$module_id)
#>     top <- utils::head(gm, n_hubs)
#>     top_findings <- lapply(seq_len(nrow(top)), function(i) {
#>         list(gene = top$gene_name[i], kme = top$kme[i])
#>     })
#>     compact_summary <- paste0("top ", nrow(top), " genes by kME: ", 
#>         paste(utils::head(top$gene_name, 10), collapse = ", "), 
#>         if (nrow(top) > 10) 
#>             ", ..."
#>         else "")
#>     evidence_fragment(fragment_id = "top_genes", tool_id = "top_genes", 
#>         module_id = ctx$module_id, type = "ranked_genes", result = top, 
#>         compact_summary = compact_summary, top_findings = top_findings, 
#>         effect_strength = if (nrow(top) > 0) 
#>             max(top$kme)
#>         else 0, direction = "na", provenance = make_provenance(tool_version = "0.1", 
#>             params = list(n_hubs = n_hubs), pkg_versions = pkg_versions(ctx$ms), 
#>             module_method = ctx$module_method %||% NA_character_))
#> }
#> <bytecode: 0x55cb73d838d8>
#> <environment: namespace:llegir>
#> 
#> $type
#> [1] "ranked_genes"
#> 
#> $description
#> [1] "Top module genes ranked by membership (kME)"
#> 
#> $requires
#> character(0)
#> 
#> $tier
#> [1] "medium"
#> 
#> $scope
#> [1] "module"
#> 
#> attr(,"class")
#> [1] "tool_spec"
```
