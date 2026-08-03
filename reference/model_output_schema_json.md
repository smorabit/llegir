# Model-facing interpretation schema, derived from the canonical schema

The interpretation JSON schema minus fields the model shouldn't fill:
`provenance`/`schema_version` are orchestrator bookkeeping, and
`confidence$model_score` just duplicates `confidence$score` for audit –
asking the model to fill it twice invites drift. Derived from the one
canonical schema file (rather than hand-duplicated) so the two never
diverge, and normalized to a schema dialect supported across providers.

## Usage

``` r
model_output_schema_json(
  schema_path = system.file("schemas", "interpretation.schema.json", package = "llegir")
)
```

## Arguments

- schema_path:

  Path to the canonical `interpretation.schema.json`; defaults to the
  schema shipped with the package.

## Value

A JSON string (a
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
scalar) of the model-facing schema.

## Examples

``` r
model_output_schema_json()
#> {"title":"interpretation","description":"Produced by the synthesis layer (Milestone 2). Finalized from the M1 draft: confidence now separates the model's raw score from the fused final score, and provenance is required (attached by the synthesis orchestrator, never filled by the model).","type":"object","required":["module_id","proposed_label","one_line_summary","dominant_biology","supporting_claims","confidence"],"properties":{"module_id":{"type":"string"},"proposed_label":{"type":"string","description":"short program name, e.g. 'Interferon response'"},"one_line_summary":{"type":"string"},"dominant_biology":{"type":"string","description":"the main program"},"supporting_claims":{"type":"array","description":"every fragment_id cited here must exist in the module's packet and its direction must match (faithfulness invariant); may be empty only when flags includes insufficient_evidence","items":{"type":"object","required":["claim","fragment_ids","direction"],"properties":{"claim":{"type":"string"},"fragment_ids":{"type":"array","items":{"type":"string"},"minItems":1},"direction":{"enum":["up","down","mixed","na"],"type":"string"},"strength":{"type":"number","nullable":true}}}},"cell_state":{"type":"string","description":"where expressed, from cluster_dme","nullable":true},"condition_dynamics":{"type":"string","nullable":true},"metadata_associations":{"type":"array","items":{"type":"object","required":["variable","summary","fragment_id"],"properties":{"variable":{"type":"string"},"summary":{"type":"string"},"fragment_id":{"type":"string"}}}},"literature":{"type":"array","description":"empty/unused in M2 (deferred to M3)","items":{"type":"object","required":["statement","pmids"],"properties":{"statement":{"type":"string"},"pmids":{"type":"array","items":{"type":"string"}}}}},"confidence":{"type":"object","required":["score","rationale"],"properties":{"score":{"type":"number","minimum":0,"maximum":1,"description":"final fused confidence (docs/milestone_2.md task 4); equal to model_score until fusion runs"},"rationale":{"type":"string"}}},"flags":{"type":"array","items":{"enum":["insufficient_evidence","needs_human_review","possible_artifact","tool_conflict","label_low_specificity"],"type":"string"}}}} 
```
