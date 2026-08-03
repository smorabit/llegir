# Render an interpretation as a paragraph

A deterministic, versioned template that reads only `interpretation`
object fields – no model call here, so the same interpretation object
always renders to the same paragraph.

## Usage

``` r
render_paragraph(interp)
```

## Arguments

- interp:

  An `interpretation` object.

## Value

A single character string (Markdown).

## Examples

``` r
ms <- llegir_example_moduleset()
packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
interp <- synthesize_interpretation(packet, desc, mock_backend())
cat(render_paragraph(interp))
#> **Myeloid activation program (mock)** (module_a)
#> 
#> Mock synthesis output for offline testing; not derived from the evidence packet.
#> 
#> Dominant biology: Not evaluated by the mock backend.
#> 
#> Supporting evidence:
#> - Top genes were computed by the deterministic core. (top_genes; direction: na)
#> - The module has enriched gene-set terms. (geneset_enrichment; direction: up)
#> 
#> Confidence: 0.50 -- Mock backend: fixed neutral confidence, not evidence-derived.
```
