# Construct a dataset fragment

One dataset-level tool's global summary of the whole experiment. Sibling
of
[`evidence_fragment()`](https://smorabit.github.io/llegir/reference/evidence_fragment.md):
no `module_id`, no `effect_strength`/ `significance`/`direction` – it is
descriptive framing bundled into a `dataset_context`, never fused or
cited per module. See `inst/schemas/dataset_fragment.schema.json` for
the full contract.

## Usage

``` r
dataset_fragment(
  fragment_id,
  tool_id,
  type,
  result,
  compact_summary,
  top_findings,
  caveats = list(),
  provenance = list(),
  plots = NULL,
  render_max_findings = NULL
)
```

## Arguments

- fragment_id:

  Unique id within a dataset_context, e.g. `'composition'` or
  `'milo::abundance'`.

- tool_id:

  Which tool produced this fragment.

- type:

  One of the controlled vocabulary: `'composition_summary'`,
  `'baseline_expression'`, `'variance_structure'`, `'module_landscape'`.

- result:

  The small tidy summary (a data.frame); never the raw matrix.

- compact_summary:

  Short digest for the model (token-efficient, no raw tables).

- top_findings:

  A list of the few most salient items (cell states / covariates /
  genes).

- caveats:

  A list of machine-readable confounder flags, drawn from the controlled
  vocab. Default [`list()`](https://rdrr.io/r/base/list.html).

- provenance:

  A provenance list, typically built with
  [`make_provenance()`](https://smorabit.github.io/llegir/reference/make_provenance.md).

- plots:

  Optional named list of plot specs to attach; see
  [`attach_plots()`](https://smorabit.github.io/llegir/reference/attach_plots.md).
  Default `NULL`.

- render_max_findings:

  Optional override for how many `top_findings` entries
  `.render_dataset_fragment_compact()` renders for this fragment, for a
  fragment whose findings are a census (one entry per group) rather than
  a top-N ranking, e.g. a cluster reference card with one row per
  cluster. `NULL` (default) means "use the caller's cap"; see
  [`build_user_prompt()`](https://smorabit.github.io/llegir/reference/build_user_prompt.md).
  Never added to `required`, so a fragment that omits it validates,
  serializes, and hashes exactly as one built before this field existed.

## Value

A `dataset_fragment` object.
