# Construct an evidence fragment

One tool's result for one module; every core/custom tool must return one
of these. See
[`vignette('getting-started', package = 'llegir')`](https://smorabit.github.io/llegir/articles/getting-started.md)
and `inst/schemas/evidence_fragment.schema.json` for the full contract.

## Usage

``` r
evidence_fragment(
  fragment_id,
  tool_id,
  module_id,
  type,
  result,
  compact_summary,
  top_findings,
  effect_strength,
  significance = NA_real_,
  direction = "na",
  provenance = list(),
  plots = NULL
)
```

## Arguments

- fragment_id:

  Unique id within a packet, e.g. `'cluster_dme'` or
  `'metadata::diagnosis'`.

- tool_id:

  Which tool produced this fragment.

- module_id:

  The module this fragment describes.

- type:

  One of the controlled vocabulary: `'ranked_genes'`,
  `'categorical_association'`, `'continuous_correlation'`,
  `'geneset_enrichment'`, `'signature_correlation'`,
  `'cross_condition_delta'`, `'state_expression'`.

- result:

  The full tidy result (a data.frame).

- compact_summary:

  Short digest for the model (token-efficient, no raw tables).

- top_findings:

  A list of the few most salient items (genes / terms / groups).

- effect_strength:

  A comparable magnitude, e.g. `max(abs(r))`, top `log2FC`, or top
  `-log10(FDR)`.

- significance:

  p / FDR where applicable, else `NA_real_`.

- direction:

  One of `'up'`, `'down'`, `'mixed'`, `'na'`.

- provenance:

  A provenance list, typically built with
  [`make_provenance()`](https://smorabit.github.io/llegir/reference/make_provenance.md).

- plots:

  Optional named list of plot specs to attach; see
  [`attach_plots()`](https://smorabit.github.io/llegir/reference/attach_plots.md).
  Default `NULL`.

## Value

An `evidence_fragment` object.
