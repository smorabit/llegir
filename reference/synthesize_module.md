# Synthesize one evidence packet into a validated interpretation

Runs the full packet -\> interpretation pipeline for one module: calls
`backend` via
[`synthesize_interpretation()`](https://smorabit.github.io/llegir/reference/synthesize_interpretation.md),
enforces citation faithfulness via
[`enforce_faithfulness()`](https://smorabit.github.io/llegir/reference/enforce_faithfulness.md),
fuses model and deterministic confidence via
[`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md),
and validates the result. These three steps always run together – an
interpretation that skipped faithfulness or fusion isn't one this engine
should emit.

## Usage

``` r
synthesize_module(
  packet,
  desc,
  backend,
  temperature = 0,
  seed = NA_real_,
  prompt_template_version = PROMPT_TEMPLATE_VERSION,
  schema_path = system.file("schemas", "interpretation.schema.json", package = "llegir"),
  user_weights = list(),
  dataset_context = NULL
)
```

## Arguments

- packet:

  An evidence packet, as built by
  [`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md)
  /
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md).

- desc:

  A `dataset_description`; see
  [`dataset_description()`](https://smorabit.github.io/llegir/reference/dataset_description.md).

- backend:

  A synthesis backend function; see
  [`mock_backend()`](https://smorabit.github.io/llegir/reference/mock_backend.md),
  [`ellmer_backend()`](https://smorabit.github.io/llegir/reference/ellmer_backend.md),
  [`resolve_backend()`](https://smorabit.github.io/llegir/reference/resolve_backend.md).

- temperature:

  Sampling temperature passed to the backend.

- seed:

  Optional seed, recorded on the interpretation's provenance.

- prompt_template_version:

  Prompt template version to record on the interpretation's provenance.

- schema_path:

  Path to the interpretation JSON schema; defaults to the schema shipped
  with the package.

- user_weights:

  Named list of per-`tool_id` weight multipliers for
  [`calculate_fusion_score()`](https://smorabit.github.io/llegir/reference/calculate_fusion_score.md).
  Computed once here and shared between the prompt's EVIDENCE CONFIDENCE
  MATRIX and
  [`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md),
  so the printed fusion string can never drift from what the model was
  shown. Default [`list()`](https://rdrr.io/r/base/list.html).

- dataset_context:

  An optional dataset context, as built by
  [`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md)
  /
  [`run_dataset_context()`](https://smorabit.github.io/llegir/reference/run_dataset_context.md),
  threaded into
  [`build_user_prompt()`](https://smorabit.github.io/llegir/reference/build_user_prompt.md)
  as global framing. Never enters
  [`calculate_fusion_score()`](https://smorabit.github.io/llegir/reference/calculate_fusion_score.md)
  or
  [`enforce_faithfulness()`](https://smorabit.github.io/llegir/reference/enforce_faithfulness.md).
  `NULL` (default) omits the DATASET CONTEXT block.

## Value

A validated `interpretation` object.

## Examples

``` r
ms <- llegir_example_moduleset()
packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
synthesize_module(packet, desc, mock_backend())
#> $module_id
#> [1] "module_a"
#> 
#> $proposed_label
#> [1] "Myeloid activation program (mock)"
#> 
#> $one_line_summary
#> [1] "Mock synthesis output for offline testing; not derived from the evidence packet."
#> 
#> $dominant_biology
#> [1] "Not evaluated by the mock backend."
#> 
#> $supporting_claims
#> $supporting_claims[[1]]
#> $supporting_claims[[1]]$claim
#> [1] "Top genes were computed by the deterministic core."
#> 
#> $supporting_claims[[1]]$fragment_ids
#> [1] "top_genes"
#> 
#> $supporting_claims[[1]]$direction
#> [1] "na"
#> 
#> $supporting_claims[[1]]$strength
#> [1] NA
#> 
#> 
#> $supporting_claims[[2]]
#> $supporting_claims[[2]]$claim
#> [1] "The module has enriched gene-set terms."
#> 
#> $supporting_claims[[2]]$fragment_ids
#> [1] "geneset_enrichment"
#> 
#> $supporting_claims[[2]]$direction
#> [1] "up"
#> 
#> $supporting_claims[[2]]$strength
#> [1] NA
#> 
#> 
#> 
#> $cell_state
#> [1] NA
#> 
#> $condition_dynamics
#> [1] NA
#> 
#> $metadata_associations
#> list()
#> 
#> $literature
#> list()
#> 
#> $confidence
#> $confidence$score
#> [1] 0.7531057
#> 
#> $confidence$model_score
#> [1] 0.5
#> 
#> $confidence$rationale
#> [1] "Mock backend: fixed neutral confidence, not evidence-derived. [fusion: model=0.50, evidence=0.94 (E_pool=0.94, P_agree=1.00, C_dir=1.00), lambda=0.35, fused=0.75]"
#> 
#> 
#> $flags
#> $flags[[1]]
#> [1] "needs_human_review"
#> 
#> 
#> $provenance
#> $provenance$model
#> [1] "mock"
#> 
#> $provenance$model_version
#> [1] "mock-0.1"
#> 
#> $provenance$prompt_template_version
#> [1] "0.4"
#> 
#> $provenance$temperature
#> [1] 0
#> 
#> $provenance$seed
#> [1] NA
#> 
#> $provenance$input_packet_hash
#> [1] "0e711db672760f68549d5c63c8fffbd76a741d168ec1c8fbceab6241786bc9fc"
#> 
#> $provenance$ellmer_call
#> $provenance$ellmer_call$backend
#> [1] "mock"
#> 
#> 
#> $provenance$timestamp
#> [1] "2026-08-04T18:45:48+0200"
#> 
#> 
#> $schema_version
#> [1] "0.1"
#> 
#> attr(,"class")
#> [1] "interpretation"
```
