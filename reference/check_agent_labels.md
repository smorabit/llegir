# Check an agent's label files against their evidence packets

For every module in a workspace exported with
`export_agent_workspace(mode = 'label')`, replays
`labels/<module_id>.json` through
[`synthesize_interpretation()`](https://smorabit.github.io/llegir/reference/synthesize_interpretation.md)
via
[`agent_label_backend()`](https://smorabit.github.io/llegir/reference/agent_label_backend.md),
runs
[`check_faithfulness()`](https://smorabit.github.io/llegir/reference/check_faithfulness.md)
against the module's packet, and checks the required `review` block
against the ModuleSet itself:

- every supporting hub is among the module's top 25 hubs, with the kME
  stated (within 0.01), and at least one is from the top 10;

- at least 3 expected markers, each with the right status (`in_module`,
  `in_network`, `unassigned`, `not_tested`; the last two are told apart
  only when the workspace ships the input feature set);

- the 3 display hubs are among the top 10 hubs, exclude housekeeping
  normalizers unless `review$display_hub_overrides` gives a reason, and
  do not repeat a gene family;

- `confidence$score` lies in the band of `review$confidence_level` (high
  0.75-0.95, moderate 0.5-0.75, low 0.25-0.5, very_low 0-0.25);

- a technical artifact gate, a `technical_artifact` evidence tier and
  the `possible_artifact` flag go together;

- a module meeting the artifact screen's dissociation-stress or
  depth-correlation threshold does not `pass` the gate, and one meeting
  the sample-concentration threshold is at most `moderate` and flagged
  `label_low_specificity`;

- working notes exist at `labels/notes/<module_id>.md`, and every script
  in `queries/<module_id>/` has its captured `.out` and is cited in
  them;

- no two modules in the workspace share a `proposed_label`, unless one's
  `review$related_module` names the other.

## Usage

``` r
check_agent_labels(workspace_dir, alpha = 0.05)
```

## Arguments

- workspace_dir:

  Path to the exported workspace.

- alpha:

  Significance threshold for the faithfulness wording check.

## Value

A data.frame with one row per module (plus one per unexpected label
file): `module_id`, `status` (`'ok'`, `'missing'`, `'invalid'`,
`'unfaithful'`, `'needs_revision'` or `'unexpected'`), `proposed_label`
and `detail`.

## Details

This is what the workspace's `validate_labels.R` runs, so an agent can
iterate until every module is `'ok'`.
