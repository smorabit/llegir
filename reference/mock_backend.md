# Offline mock synthesis backend

A canned, fixed-response backend: the first-class offline backend used
by tests and CI, and never touches the network. It cites fragment_ids
`'top_genes'` (always direction `'na'`) and `'geneset_enrichment'`,
whose direction (`'up'` only when a term reaches significance, else
`'na'`) is read back from the rendered packet in the user prompt, and
its claim text avoids significance wording, so it passes
[`check_faithfulness()`](https://smorabit.github.io/llegir/reference/check_faithfulness.md)
against any real evidence packet without per-module logic.

## Usage

``` r
mock_backend()
```

## Value

A backend function with the signature
`function(system_prompt, user_prompt, schema_json, packet_hash) -> list(content, meta)`,
suitable for
[`synthesize_interpretation()`](https://smorabit.github.io/llegir/reference/synthesize_interpretation.md).

## Examples

``` r
backend <- mock_backend()
backend('system prompt', 'user prompt', '{}')$content$proposed_label
#> [1] "Myeloid activation program (mock)"
```
