# Evidence tool: gene-set enrichment among a module's hub genes

Offline GO/pathway enrichment
([`GeneOverlap::newGOM()`](https://rdrr.io/pkg/GeneOverlap/man/newGOM.html))
over hub genes against local GMT gene-set libraries
([`fgsea::gmtPathways()`](https://rdrr.io/pkg/fgsea/man/gmtPathways.html))
– no runtime network access, so the tool is deterministic and CI-clean
by construction. Touches the `ModuleSet` adapter contract
([`gene_membership()`](https://smorabit.github.io/llegir/reference/gene_membership.md),
[`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md))
plus `ctx$params$db_files`, a named vector of local GMT file paths.

## Usage

``` r
geneset_enrichment_tool(ctx)
```

## Arguments

- ctx:

  A tool context list: `list(ms, module_id, params)`, as built by
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md).
  `ctx$params$n_hubs` (default 25) is the number of hub genes tested.
  `ctx$params$db_files` (required for a non-empty result) is a named
  character vector of local GMT file paths, e.g.
  `c(GO_BP = 'path/to/GO_Biological_Process.txt')`.

## Value

An `evidence_fragment` of type `'geneset_enrichment'`, or `NULL` if
`ctx$ms` lacks the `expression` capability (see
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md))
– a graceful skip, not an error.

## Examples

``` r
if (FALSE) { # \dontrun{
ms <- llegir_example_moduleset()
geneset_enrichment_tool(list(
    ms = ms, module_id = modules(ms)[1],
    params = list(n_hubs = 10, db_files = c(GO_BP = 'path/to/gene_sets.gmt'))
))
} # }
```
