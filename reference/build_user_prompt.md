# Build the synthesis user prompt for one module

Concatenates the rendered
[`dataset_description()`](https://smorabit.github.io/llegir/reference/dataset_description.md),
the optional
[`render_dataset_context_compact()`](https://smorabit.github.io/llegir/reference/render_dataset_context_compact.md)
block, the compact evidence packet
([`render_packet_compact()`](https://smorabit.github.io/llegir/reference/render_packet_compact.md)),
and the deterministic EVIDENCE CONFIDENCE MATRIX
([`calculate_fusion_score()`](https://smorabit.github.io/llegir/reference/calculate_fusion_score.md))
that grounds the model's `confidence.score` in the same numbers
[`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md)
later re-derives the final fused score from.

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

  An optional pre-computed
  [`calculate_fusion_score()`](https://smorabit.github.io/llegir/reference/calculate_fusion_score.md)
  result; `NULL` (default) computes it from `packet$fragments` and
  `user_weights`. Pass the same object used later by
  [`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md)
  so the prompt and the final score are guaranteed to agree.

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

  Named list of per-`tool_id` weight multipliers passed to
  [`calculate_fusion_score()`](https://smorabit.github.io/llegir/reference/calculate_fusion_score.md)
  when `fusion` is `NULL`. Default
  [`list()`](https://rdrr.io/r/base/list.html).

- dataset_context:

  An optional dataset context, as built by
  [`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md)
  /
  [`run_dataset_context()`](https://smorabit.github.io/llegir/reference/run_dataset_context.md).
  Rendered via
  [`render_dataset_context_compact()`](https://smorabit.github.io/llegir/reference/render_dataset_context_compact.md)
  between the dataset description and the evidence packet. `NULL`
  (default) omits the block entirely, matching prior prompt output
  exactly.

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
#> top_findings: [{"gene":"GENEA4","kme":0.9389},{"gene":"GENEA9","kme":0.9368},{"gene":"GENEA5","kme":0.9331},{"gene":"GENEA10","kme":0.9324},{"gene":"GENEA8","kme":0.9305},{"gene":"GENEA1","kme":0.93},{"gene":"GENEA2","kme":0.9243},{"gene":"GENEA7","kme":0.9236}]
#> 
#> EVIDENCE CONFIDENCE MATRIX  (computed deterministically upstream -- treat as ground truth, do not recompute or contradict)
#> 
#> fragment_id        type               weight magnitude reliability e_score direction
#> top_genes          ranked_genes         0.60      0.94        1.00    0.94 na
#> 
#> pooled_evidence  E_pool  = 0.94   (weighted power mean, beta = 0.50)
#> directional      C_dir   = 1.00  ->  P_agree = 1.00
#> empirical        E_evidence      = 0.94
#> model_trust      lambda          = 0.35
#> 
#> CONSTRAINTS:
#> - confidence.score must be consistent with E_evidence; it may not exceed E_evidence + 0.10 (E_evidence = 0.94).
#> - Any directional claim must agree with the sign of the directional mass above (coherence 1.00, net "none").
#> - If E_evidence < 0.35, set flags to include insufficient_evidence and keep supporting_claims minimal.
#> - Explain what the numbers mean for this module; do not restate or recompute them.
```
