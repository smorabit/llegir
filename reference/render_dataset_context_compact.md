# Render a dataset context as a compact model-facing text block

Renders only the compact, curated fields of each `dataset_fragment`
(`compact_summary`, `top_findings`, `caveats`) – never the raw `result`
tables – mirroring
[`render_packet_compact()`](https://smorabit.github.io/llegir/reference/render_packet_compact.md).
Injected once per dataset into every module's prompt via
[`build_user_prompt()`](https://smorabit.github.io/llegir/reference/build_user_prompt.md)'s
`dataset_context` argument; unlike the per-module evidence packet, this
block is global framing and never enters fusion or faithfulness.

## Usage

``` r
render_dataset_context_compact(dataset_context, max_findings = 8)
```

## Arguments

- dataset_context:

  A dataset context, as built by
  [`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md).

- max_findings:

  Maximum number of `top_findings` entries rendered per fragment.
  Default `8`.

## Value

A single character string.

## Examples

``` r
frag <- dataset_fragment(
    'composition', 'dataset_composition_tool', 'composition_summary',
    data.frame(group = 'A', n = 10), 'One group, 10 cells.', list(),
    provenance = make_provenance('dataset_composition_tool', '0.1', list(), list(), NA_character_)
)
ctx <- build_dataset_context(list(frag))
cat(render_dataset_context_compact(ctx))
#> DATASET CONTEXT (1 fragments):
#> 
#> [composition] type=composition_summary
#> One group, 10 cells.
#> top_findings: []
```
