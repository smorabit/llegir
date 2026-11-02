# Apply deterministic review flags to an interpretation

The fused evidence score is shelved
(`docs/prompts/handoff_prompt_serpentine_tcell.md` Part 4.5): its two
known flaws – a non-significant dynamics fragment dragging down a
genuinely stable module, and `top_genes`' top-kME magnitude standing in
for interpretation confidence when it only measures hub tightness – made
the blended number misleading, so `confidence$score` is left as the
model's own calibrated value. This function now only unions the
deterministic `possible_artifact` flag (hub list dominated by
IEG/dissociation-stress markers, `.artifact_flagged()`) into
`interp$flags`;
[`enforce_faithfulness()`](https://smorabit.github.io/llegir/reference/enforce_faithfulness.md)
sets `needs_human_review` independently, and the model may still set
`insufficient_evidence` itself.
[`calculate_fusion_score()`](https://smorabit.github.io/llegir/reference/calculate_fusion_score.md)
and
[`compute_evidence_signals()`](https://smorabit.github.io/llegir/reference/compute_evidence_signals.md)
are retained, unused here, for a future redesign of the score.

## Usage

``` r
fuse_confidence(
  interp,
  packet,
  low_threshold = 0.35,
  disagreement_threshold = 0.35,
  user_weights = list(),
  fusion = NULL
)
```

## Arguments

- interp:

  An `interpretation` object, as returned by
  [`synthesize_interpretation()`](https://smorabit.github.io/llegir/reference/synthesize_interpretation.md)
  (after
  [`enforce_faithfulness()`](https://smorabit.github.io/llegir/reference/enforce_faithfulness.md)).

- packet:

  The evidence packet `interp` was synthesized from.

- low_threshold:

  Ignored; retained for call-site compatibility.

- disagreement_threshold:

  Ignored; retained for call-site compatibility.

- user_weights:

  Ignored; retained for call-site compatibility.

- fusion:

  Ignored; retained for call-site compatibility.

## Value

`interp`, with `flags` possibly extended by `'possible_artifact'`.

## Examples

``` r
ms <- llegir_example_moduleset()
packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
interp <- synthesize_interpretation(packet, desc, mock_backend())
fuse_confidence(interp, packet)
#> $module_id
#> [1] "module_a"
#> 
#> $proposed_label
#> [1] "Myeloid activation program (mock)"
#> 
#> $dominant_biology
#> [1] "Not evaluated by the mock backend."
#> 
#> $interpretation
#> [1] "Mock synthesis output for offline testing; not derived from the evidence packet."
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
#> [1] "Gene-set overlap was tested for the hub genes."
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
#> $literature
#> list()
#> 
#> $confidence
#> $confidence$score
#> [1] 0.5
#> 
#> $confidence$model_score
#> [1] 0.5
#> 
#> $confidence$rationale
#> [1] "Mock backend: fixed neutral confidence, not evidence-derived."
#> 
#> 
#> $flags
#> list()
#> 
#> $provenance
#> $provenance$model
#> [1] "mock"
#> 
#> $provenance$model_version
#> [1] "mock-0.1"
#> 
#> $provenance$prompt_template_version
#> [1] "1.3"
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
#> [1] "2026-11-02T18:54:50+0100"
#> 
#> 
#> $schema_version
#> [1] "0.2"
#> 
#> attr(,"class")
#> [1] "interpretation"
```
