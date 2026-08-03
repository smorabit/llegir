# Build an interpretation's provenance record

Build an interpretation's provenance record

## Usage

``` r
make_interpretation_provenance(
  model,
  prompt_template_version,
  temperature,
  input_packet_hash,
  model_version = NA_character_,
  seed = NA_real_,
  ellmer_call = list()
)
```

## Arguments

- model:

  Model identifier (e.g. `'mock'`, a provider model id).

- prompt_template_version:

  Version of the system/user prompt template used.

- temperature:

  Sampling temperature used for the model call.

- input_packet_hash:

  The evidence packet's `packet_hash`.

- model_version:

  Provider-reported model version, if available.

- seed:

  Sampling seed, if available.

- ellmer_call:

  Arbitrary named list of backend call bookkeeping (e.g. token counts).

## Value

A provenance list suitable for
[`interpretation()`](https://smorabit.github.io/llegir/reference/interpretation.md)'s
`provenance` argument.
