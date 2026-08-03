# Live synthesis backend via ellmer structured output

Not exercised by the offline test suite (needs network + a provider API
key). Provider and model are config-selected via `chat_fn`/`model`;
credentials are picked up by `ellmer` itself from the provider's
environment variable (e.g. `GEMINI_API_KEY`, `GITHUB_PAT`) and are never
handled here. `schema_transform` adapts the one canonical schema to a
provider's structured-output dialect (e.g. the internal
`.to_openai_strict_schema()` used by
[`resolve_backend()`](https://smorabit.github.io/llegir/reference/resolve_backend.md)
for GitHub Models) without forking the schema itself.

## Usage

``` r
ellmer_backend(
  chat_fn = ellmer::chat_google_gemini,
  model = "gemini-3.5-flash",
  temperature = 0,
  credentials = NULL,
  schema_transform = identity
)
```

## Arguments

- chat_fn:

  An `ellmer::chat_*()` constructor, e.g.
  [`ellmer::chat_google_gemini`](https://ellmer.tidyverse.org/reference/chat_google_gemini.html)
  or
  [`ellmer::chat_github`](https://ellmer.tidyverse.org/reference/chat_github.html).

- model:

  Model id passed to `chat_fn`.

- temperature:

  Sampling temperature.

- credentials:

  Optional credentials passed to `chat_fn`; `NULL` uses the provider's
  default environment-variable lookup.

- schema_transform:

  A `function(schema_list) -> schema_list` applied to the parsed
  canonical schema before it's sent to the provider.

## Value

A backend function; see
[`mock_backend()`](https://smorabit.github.io/llegir/reference/mock_backend.md)
for the contract.

## Examples

``` r
if (FALSE) { # \dontrun{
backend <- ellmer_backend(ellmer::chat_google_gemini, model = 'gemini-3.5-flash')
} # }
```
