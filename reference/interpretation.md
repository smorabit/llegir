# Construct an interpretation object

One module's filled schema, produced by the synthesis layer
([`synthesize_interpretation()`](https://smorabit.github.io/llegir/reference/synthesize_interpretation.md))
from a fixed evidence packet. `confidence$score` starts out equal to
`confidence$model_score` and is overwritten in place by confidence
fusion
([`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md));
`provenance` is attached by the orchestrator, never by the model itself.

## Usage

``` r
interpretation(
  module_id,
  proposed_label,
  one_line_summary,
  dominant_biology,
  supporting_claims,
  confidence,
  provenance,
  cell_state = NA_character_,
  condition_dynamics = NA_character_,
  metadata_associations = list(),
  literature = list(),
  flags = list(),
  schema_version = "0.1"
)
```

## Arguments

- module_id:

  The module this interpretation describes.

- proposed_label:

  Short program name, e.g. `'Interferon response'`.

- one_line_summary:

  A one-line summary of the module.

- dominant_biology:

  Description of the main program.

- supporting_claims:

  A list of claims, each
  `list(claim, fragment_ids, direction, strength)`.

- confidence:

  A confidence list: `list(score, model_score, rationale)`.

- provenance:

  A provenance list, typically built with
  [`make_interpretation_provenance()`](https://smorabit.github.io/llegir/reference/make_interpretation_provenance.md).

- cell_state:

  Where the module is expressed (from `cluster_dme`), if known.

- condition_dynamics:

  Condition-dependent dynamics, if applicable.

- metadata_associations:

  A list of `list(variable, summary, fragment_id)`.

- literature:

  A list of `list(statement, pmids)`. Always empty in the current
  synthesis layer.

- flags:

  A subset of the flag vocabulary: `'insufficient_evidence'`,
  `'needs_human_review'`, `'possible_artifact'`, `'tool_conflict'`,
  `'label_low_specificity'`.

- schema_version:

  Schema version tag. Default `'0.1'`.

## Value

An `interpretation` object.
