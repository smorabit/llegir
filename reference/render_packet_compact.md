# Render an evidence packet as a compact model-facing text block

Renders only the compact, curated fields of each fragment
(`compact_summary`, `top_findings`, `effect_strength`/`significance`) –
never the raw `result` tables – so the prompt stays small and the model
only sees pre-summarized evidence.

## Usage

``` r
render_packet_compact(packet, max_findings = 8)
```

## Arguments

- packet:

  An evidence packet, as built by
  [`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md).

- max_findings:

  Maximum number of `top_findings` entries rendered per fragment; a
  token-efficiency backstop, since tools already curate `top_findings`
  to a handful of entries.

## Value

A single character string.

## Examples

``` r
ms <- llegir_example_moduleset()
packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
cat(render_packet_compact(packet))
#> Module module_a evidence packet (1 fragments):
#> 
#> [top_genes] type=ranked_genes direction=na effect_strength=0.9389 significance=NA
#> top 10 genes by kME: GENEA4, GENEA9, GENEA5, GENEA10, GENEA8, GENEA1, GENEA2, GENEA7, GENEA3, GENEA6
#> top_findings: [{"gene":"GENEA4","kme":0.9389},{"gene":"GENEA9","kme":0.9368},{"gene":"GENEA5","kme":0.9331},{"gene":"GENEA10","kme":0.9324},{"gene":"GENEA8","kme":0.9305},{"gene":"GENEA1","kme":0.93},{"gene":"GENEA2","kme":0.9243},{"gene":"GENEA7","kme":0.9236}]
```
