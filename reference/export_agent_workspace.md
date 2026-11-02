# Export a self-contained agent workspace and manifest

Serializes the run's `ModuleSet`, dataset context, and evidence packets
to `out_dir`, then renders `.llegir_agent_manifest.md`: a static
launchpad an external terminal coding agent points at to run open-ended,
read-only queries against this analysis. The API and tool cheat-sheets
are generated from the live registry and this `ModuleSet`'s
capabilities, so a workspace exported after a user registers a custom
tool documents that tool with no manual step. Pure exporter: writes
files and returns a path, never calls `ellmer` or spends budget.

## Usage

``` r
export_agent_workspace(
  ms,
  dataset_context,
  packets,
  desc,
  interps = NULL,
  out_dir = "agent_workspace",
  write_json = TRUE,
  mode = c("explore", "label"),
  sample_col = .ms_sample_col(ms),
  depth_cols = NULL,
  feature_genes = NULL
)
```

## Arguments

- ms:

  A validated `ModuleSet`.

- dataset_context:

  A `dataset_context` (see
  [`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md)).

- packets:

  A named list of evidence packets, keyed by module id (e.g. the return
  value of
  [`run_orchestrator()`](https://smorabit.github.io/llegir/reference/run_orchestrator.md)).

- desc:

  The `dataset_description` for this run.

- interps:

  A named list of `interpretation` objects, keyed by module id (e.g. the
  return value of
  [`run_synthesis_orchestrator()`](https://smorabit.github.io/llegir/reference/run_synthesis_orchestrator.md)),
  or `NULL` (default) when this run didn't synthesize any. When `NULL`,
  no interpretation artifacts are written and the manifest records that
  this run shipped no interpretations, so the guest agent does not
  mock-synthesize one.

- out_dir:

  Destination workspace directory. Default `'agent_workspace'`.

- write_json:

  Also emit portable JSON copies of the context, packets, and (if
  present) interpretations. Default `TRUE`.

- mode:

  `'explore'` (default) exports the read-only query workspace described
  above, unchanged. `'label'` additionally commissions the agent to
  write module labels: the manifest gains a Labeling Task section
  carrying the synthesis prompt's rules
  ([`build_system_prompt()`](https://smorabit.github.io/llegir/reference/build_system_prompt.md))
  and the model-facing schema, each module's packet is rendered to
  `artifacts/label_evidence/<module_id>.md` exactly as the synthesis
  model sees it, a `labels/` directory is created for the agent's output
  (one `<module_id>.json` per module), and `validate_labels.R` is
  shipped so the agent can check its labels with
  [`check_agent_labels()`](https://smorabit.github.io/llegir/reference/check_agent_labels.md).
  The manifest also sets a refinement protocol (artifact gate, evidence
  hierarchy, falsification against expected markers, anchored
  confidence, unique labels), each label must carry the interpretation's
  `review` block, and each evidence file ends with a deterministic
  artifact screen. Supplying `interps` in label mode ships them as
  drafts for the agent to refine. Collect the result with
  [`collect_agent_labels()`](https://smorabit.github.io/llegir/reference/collect_agent_labels.md).

- sample_col:

  Label mode only: metadata column naming the biological sample (e.g.
  patient) for the artifact screen's single-sample share of a module's
  top-decile activity. Defaults to the `ModuleSet`'s declared sample-id
  column, if any; `NULL` skips that line.

- depth_cols:

  Label mode only: metadata columns holding per-cell sequencing depth
  (e.g. `c('nCount_RNA', 'nFeature_RNA')`), for the artifact screen's
  module-score/depth correlation. `NULL` (default) skips that line.

- feature_genes:

  Label mode only: every gene that was eligible for module assignment
  (e.g.
  [`hdWGCNA::GetWGCNAGenes()`](https://smorabit.github.io/hdWGCNA/reference/GetWGCNAGenes.html),
  grey included), so a marker in no module can be classed `unassigned`
  rather than `not_tested`. `NULL` (default) accepts either for such a
  gene.

## Value

The absolute path to the written manifest, invisibly.

## Details

The `ModuleSet` is serialized twice: `artifacts/moduleset_lite.qs2` (a
[`.make_moduleset_lite()`](https://smorabit.github.io/llegir/reference/dot-make_moduleset_lite.md)
reduction with the backing expression/counts matrices dropped – what
`query_example.R` loads by default) and `artifacts/moduleset_full.qs2`
(`ms` unchanged, for the rare
[`expression()`](https://smorabit.github.io/llegir/reference/expression.md)/[`counts()`](https://smorabit.github.io/llegir/reference/counts.md)
query). Every cheat-sheet row, tool-registry row, and recipe rung is
still generated against `ms`'s full capabilities – nothing is dropped
from the docs – but is tagged `(full object only)` when it needs
something the lite object doesn't carry.
