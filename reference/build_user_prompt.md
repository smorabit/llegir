# Build the synthesis user prompt for one module

Concatenates the rendered
[`dataset_description()`](https://smorabit.github.io/llegir/reference/dataset_description.md),
the optional
[`render_dataset_context_compact()`](https://smorabit.github.io/llegir/reference/render_dataset_context_compact.md)
block, and the compact evidence packet
([`render_packet_compact()`](https://smorabit.github.io/llegir/reference/render_packet_compact.md)).
The deterministic EVIDENCE CONFIDENCE MATRIX is no longer injected (Part
4.5: the fused score is shelved); the model sets `confidence.score` from
its own calibrated certainty.

## Usage

``` r
build_user_prompt(
  packet,
  desc,
  fusion = NULL,
  data_level = "cell",
  aggregated = FALSE,
  user_weights = list(),
  dataset_context = NULL
)
```

## Arguments

- packet:

  An evidence packet, as built by
  [`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md).

- desc:

  A `dataset_description`; see
  [`dataset_description()`](https://smorabit.github.io/llegir/reference/dataset_description.md).

- fusion:

  Ignored; retained for call-site compatibility. The fused evidence
  matrix is no longer part of the prompt.

- data_level:

  Observation-unit descriptor of the `ModuleSet` the packet was built
  from; see
  [`render_dataset_description()`](https://smorabit.github.io/llegir/reference/render_dataset_description.md).
  Default `'cell'`.

- aggregated:

  Whether that `ModuleSet`'s expression/scores are already aggregated
  across cells; see
  [`render_dataset_description()`](https://smorabit.github.io/llegir/reference/render_dataset_description.md).
  Default `FALSE`.

- user_weights:

  Ignored; retained for call-site compatibility.

- dataset_context:

  An optional dataset context, as built by
  [`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md)
  /
  [`run_dataset_context()`](https://smorabit.github.io/llegir/reference/run_dataset_context.md).
  Rendered via
  [`render_dataset_context_compact()`](https://smorabit.github.io/llegir/reference/render_dataset_context_compact.md)
  between the dataset description and the evidence packet. `NULL`
  (default) omits the block entirely.

## Value

A single character string.

## Examples

``` r
ms <- llegir_example_moduleset()
packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
cat(build_user_prompt(packet, desc))
#> Dataset context:
#> - species: human
#> - tissue: CSF
#> - cell compartment: myeloid
#> - assay: scRNA-seq
#> - data level: cell
#> - aggregated: FALSE
#> 
#> Module module_a evidence packet (1 fragments):
#> 
#> [top_genes] type=ranked_genes direction=na effect_strength=0.9389 significance=NA
#> top 10 genes by kME: GENEA4, GENEA9, GENEA5, GENEA10, GENEA8, GENEA1, GENEA2, GENEA7, GENEA3, GENEA6
#> top_findings: [{"gene":"GENEA4","kme":0.9389},{"gene":"GENEA9","kme":0.9368},{"gene":"GENEA5","kme":0.9331},{"gene":"GENEA10","kme":0.9324},{"gene":"GENEA8","kme":0.9305},{"gene":"GENEA1","kme":0.93},{"gene":"GENEA2","kme":0.9243},{"gene":"GENEA7","kme":0.9236},{"gene":"GENEA3","kme":0.9158},{"gene":"GENEA6","kme":0.9102}]
```
