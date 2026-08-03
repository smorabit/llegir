# Fuse model and deterministic confidence into a final score and flags

The model's self-reported confidence (`interp$confidence$model_score`)
is never trusted alone. It's blended with
[`calculate_fusion_score()`](https://smorabit.github.io/llegir/reference/calculate_fusion_score.md)'s
deterministic `e_evidence` via a weighted geometric blend
(`model_score^lambda * e_evidence^(1 - lambda)`), and the blend is what
can trigger review flags – so a fluent, confident label over weak
evidence gets caught even if the model never flags itself. `fusion`
should be the same
[`calculate_fusion_score()`](https://smorabit.github.io/llegir/reference/calculate_fusion_score.md)
result already injected into the synthesis prompt (see `R/prompt.R`), so
the printed fusion string can never drift from what the model was shown;
passing `NULL` recomputes it from `packet` and `user_weights`. Mutates
and returns `interp`: `confidence$score` is overwritten (`model_score`
is preserved for audit), and `flags` are unioned with whatever the model
or
[`enforce_faithfulness()`](https://smorabit.github.io/llegir/reference/enforce_faithfulness.md)
already set.

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

  `e_evidence` floor below which the fused score is capped and
  `'insufficient_evidence'` is flagged.

- disagreement_threshold:

  Minimum `|model_score - e_evidence|` gap that flags
  `'needs_human_review'`.

- user_weights:

  Named list of per-`tool_id` weight multipliers passed to
  [`calculate_fusion_score()`](https://smorabit.github.io/llegir/reference/calculate_fusion_score.md)
  when `fusion` is `NULL`. Default
  [`list()`](https://rdrr.io/r/base/list.html).

- fusion:

  An optional pre-computed
  [`calculate_fusion_score()`](https://smorabit.github.io/llegir/reference/calculate_fusion_score.md)
  result (the same one shown to the model in the prompt); `NULL`
  (default) recomputes it from `packet` and `user_weights`.

## Value

`interp`, with `confidence$score`, `confidence$rationale`, and `flags`
updated.

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
#> [1] "2026-08-03T19:22:01+0200"
#> 
#> 
#> $schema_version
#> [1] "0.1"
#> 
#> attr(,"class")
#> [1] "interpretation"
```
