# Construct an interpretation object

One module's filled schema, produced by the synthesis layer
([`synthesize_interpretation()`](https://smorabit.github.io/llegir/reference/synthesize_interpretation.md))
from a fixed evidence packet. `confidence$score` equals
`confidence$model_score` (the deterministic fused blend is shelved as of
Part 4.5;
[`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md)
now only adds review flags and leaves the score alone); `provenance` is
attached by the orchestrator, never by the model itself.

## Usage

``` r
interpretation(
  module_id,
  proposed_label,
  dominant_biology,
  interpretation,
  supporting_claims,
  confidence,
  provenance,
  literature = list(),
  flags = list(),
  review = NULL,
  schema_version = if (is.null(review)) "0.2" else "0.3"
)
```

## Arguments

- module_id:

  The module this interpretation describes.

- proposed_label:

  Short program name, e.g. `'Interferon response'`.

- dominant_biology:

  The main program, as a short label.

- interpretation:

  1-3 sentences of prose supporting the `dominant_biology` call,
  grounded in the cited fragments; folds in where the module is
  expressed and how its activity shifts across the tested condition
  where relevant.

- supporting_claims:

  A list of claims, each
  `list(claim, fragment_ids, direction, strength)`.

- confidence:

  A confidence list: `list(score, model_score, rationale)`.

- provenance:

  A provenance list, typically built with
  [`make_interpretation_provenance()`](https://smorabit.github.io/llegir/reference/make_interpretation_provenance.md).

- literature:

  A list of `list(statement, pmids)`. Always empty in the current
  synthesis layer.

- flags:

  A subset of the flag vocabulary: `'insufficient_evidence'`,
  `'needs_human_review'`, `'possible_artifact'`, `'tool_conflict'`,
  `'label_low_specificity'`.

- review:

  Optional structured self-review (schema 0.3), attached by an agent
  labelling run (see
  [`export_agent_workspace()`](https://smorabit.github.io/llegir/reference/export_agent_workspace.md)
  with `mode = 'label'`); `NULL` (default) for LLM synthesis.

- schema_version:

  Schema version tag. Defaults to `'0.2'`, or `'0.3'` when `review` is
  supplied (the only 0.3 addition).

## Value

An `interpretation` object.
