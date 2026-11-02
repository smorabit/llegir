# Model-facing interpretation schema, derived from the canonical schema

The interpretation JSON schema minus fields the model shouldn't fill:
`provenance`/`schema_version` are orchestrator bookkeeping, and
`confidence$model_score` just duplicates `confidence$score` for audit –
asking the model to fill it twice invites drift. Derived from the one
canonical schema file (rather than hand-duplicated) so the two never
diverge, and normalized to a schema dialect supported across providers.
The optional `review` block (schema 0.3) is dropped by default: it is
the agent-labelling self-review, which LLM synthesis never fills.

## Usage

``` r
model_output_schema_json(
  schema_path = system.file("schemas", "interpretation.schema.json", package = "llegir"),
  include_review = FALSE
)
```

## Arguments

- schema_path:

  Path to the canonical `interpretation.schema.json`; defaults to the
  schema shipped with the package.

- include_review:

  Keep the `review` block and make it required, as the label schema of
  `export_agent_workspace(mode = 'label')` does. Default `FALSE`.

## Value

A JSON string (a
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
scalar) of the model-facing schema.

## Examples

``` r
model_output_schema_json()
#> {"title":"interpretation","description":"Produced by the synthesis layer. As of schema 0.2 the model fills a single free-text `interpretation` field (1-3 sentences supporting the dominant-biology call, folding in cell-state localization and condition dynamics where relevant) in place of the former `one_line_summary` / `cell_state` / `condition_dynamics` / `metadata_associations` fields. `confidence` still separates the model's raw score from the (currently shelved) fused final score; `provenance` is required and attached by the synthesis orchestrator, never filled by the model.","type":"object","required":["module_id","proposed_label","dominant_biology","interpretation","supporting_claims","confidence"],"properties":{"module_id":{"type":"string"},"proposed_label":{"type":"string","description":"short program name, e.g. 'Interferon response'"},"dominant_biology":{"type":"string","description":"the main program, as a short label"},"interpretation":{"type":"string","description":"1-3 sentences of prose supporting the dominant-biology call, grounded in the cited fragments; folds in where the module is expressed and how its activity shifts across the tested condition where relevant"},"supporting_claims":{"type":"array","description":"every fragment_id cited here must exist in the module's packet and its direction must match (faithfulness invariant); may be empty only when flags includes insufficient_evidence","items":{"type":"object","required":["claim","fragment_ids","direction"],"properties":{"claim":{"type":"string"},"fragment_ids":{"type":"array","items":{"type":"string"},"minItems":1},"direction":{"enum":["up","down","mixed","na"],"type":"string"},"strength":{"type":"number","nullable":true}}}},"literature":{"type":"array","description":"empty/unused in M2 (deferred to M3)","items":{"type":"object","required":["statement","pmids"],"properties":{"statement":{"type":"string"},"pmids":{"type":"array","items":{"type":"string"}}}}},"confidence":{"type":"object","required":["score","rationale"],"properties":{"score":{"type":"number","minimum":0,"maximum":1,"description":"final confidence; equals model_score while the deterministic fusion is shelved (Part 4.5)"},"rationale":{"type":"string"}}},"flags":{"type":"array","items":{"enum":["insufficient_evidence","needs_human_review","possible_artifact","tool_conflict","label_low_specificity"],"type":"string"}}}} 
```
