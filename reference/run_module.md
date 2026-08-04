# Run one module's evidence tools and build its evidence packet

Runs every tool in `tool_config` against one module, in order, and
bundles the resulting evidence fragments into a validated, hashed
evidence packet via
[`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md).
One bad tool call fails the whole module – a partial packet would be
worse than no packet; a malformed fragment fails loudly the same way,
via
[`validate_evidence_fragment()`](https://smorabit.github.io/llegir/reference/validate_evidence_fragment.md).

## Usage

``` r
run_module(
  ms,
  module_id,
  tool_config,
  input_hash = NA_character_,
  module_method = NA_character_
)
```

## Arguments

- ms:

  A `ModuleSet`.

- module_id:

  A single module id (as returned by
  [`modules()`](https://smorabit.github.io/llegir/reference/modules.md)).

- tool_config:

  A list of tool specs, each one of:

  - `list(fn, params)` – a direct call to any
    `function(ctx) -> evidence_fragment` (or `NULL`, to skip); the tool
    is responsible for its own graceful capability-based skip, e.g.
    [`cluster_dme_tool()`](https://smorabit.github.io/llegir/reference/cluster_dme_tool.md).

  - `list(id, params)` – `id` is looked up in the tool registry (see
    [`register_tool()`](https://smorabit.github.io/llegir/reference/register_tool.md)),
    and `run_module()` itself checks the tool's declared required
    [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)
    before calling it. If unmet, the tool is skipped and the reason is
    recorded on the packet's `provenance$skipped` instead of the tool
    having to self-skip – core and custom tools registered via
    [`register_tool()`](https://smorabit.github.io/llegir/reference/register_tool.md)
    are run identically this way.

  Either form's `params` is passed through as `ctx$params`.

- input_hash:

  Optional hash of the input `ModuleSet`, recorded on the packet for
  provenance.

- module_method:

  Optional free-form description of how the modules themselves were
  generated, e.g. `'cNMF factors, k=20'`; see
  [`dataset_description()`](https://smorabit.github.io/llegir/reference/dataset_description.md).
  Passed through as `ctx$module_method`, and every core tool records it
  on its fragment's provenance via
  [`make_provenance()`](https://smorabit.github.io/llegir/reference/make_provenance.md).
  Default `NA`.

## Value

An evidence packet; see
[`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md).

## Examples

``` r
ms <- llegir_example_moduleset()
run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
#> $module_id
#> [1] "module_a"
#> 
#> $fragments
#> $fragments[[1]]
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
#> [1] 25
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
#> [1] "2026-08-04T18:45:47+0200"
#> 
#> 
#> $plots
#> NULL
#> 
#> attr(,"class")
#> [1] "evidence_fragment"
#> 
#> 
#> $packet_hash
#> [1] "0e711db672760f68549d5c63c8fffbd76a741d168ec1c8fbceab6241786bc9fc"
#> 
#> $schema_version
#> [1] "0.1"
#> 
#> $provenance
#> $provenance$created_at
#> [1] "2026-08-04T18:45:47+0200"
#> 
#> $provenance$input_hash
#> [1] NA
#> 
#> $provenance$tool_ids
#> [1] "top_genes"
#> 
#> $provenance$skipped
#> list()
#> 
#> 
run_module(ms, modules(ms)[1], list(list(id = 'top_genes', params = list())))
#> $module_id
#> [1] "module_a"
#> 
#> $fragments
#> $fragments[[1]]
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
#> [1] 25
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
#> [1] "2026-08-04T18:45:47+0200"
#> 
#> 
#> $plots
#> NULL
#> 
#> attr(,"class")
#> [1] "evidence_fragment"
#> 
#> 
#> $packet_hash
#> [1] "0e711db672760f68549d5c63c8fffbd76a741d168ec1c8fbceab6241786bc9fc"
#> 
#> $schema_version
#> [1] "0.1"
#> 
#> $provenance
#> $provenance$created_at
#> [1] "2026-08-04T18:45:47+0200"
#> 
#> $provenance$input_hash
#> [1] NA
#> 
#> $provenance$tool_ids
#> [1] "top_genes"
#> 
#> $provenance$skipped
#> list()
#> 
#> 
```
