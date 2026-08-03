# Resolve a synthesis backend from a provider name

Provider + model as a single config knob. `'mock'` is the offline/CI
backend
([`mock_backend()`](https://smorabit.github.io/llegir/reference/mock_backend.md));
`'github'` and `'gemini'` are both built on
[`ellmer_backend()`](https://smorabit.github.io/llegir/reference/ellmer_backend.md)
with the matching `ellmer::chat_*()` constructor and a default model id;
`'local'` points at a vLLM OpenAI-compatible server configured via the
`LLEGIR_LLM_URL` and `LLEGIR_LLM_MODEL` environment variables (see
`docs/local_llm_backend.md`). Callers never branch on provider.

## Usage

``` r
resolve_backend(provider = "github", model = NULL, temperature = 0)
```

## Arguments

- provider:

  One of `'github'` (default), `'gemini'`, `'mock'`, `'local'`.
  `'local'` targets an OpenAI-compatible vLLM server at `LLEGIR_LLM_URL`
  (see
  [`llm_server_status()`](https://smorabit.github.io/llegir/reference/llm_server_status.md)
  and
  [`local_backend()`](https://smorabit.github.io/llegir/reference/local_backend.md)).

- model:

  Optional model id override; defaults to a per-provider default. For
  `'local'`, `NULL` triggers model auto-discovery via
  [`llm_server_status()`](https://smorabit.github.io/llegir/reference/llm_server_status.md);
  a hard error is raised if zero or more than one models are served.

- temperature:

  Sampling temperature (ignored by the mock backend).

## Value

A backend function; see
[`mock_backend()`](https://smorabit.github.io/llegir/reference/mock_backend.md)
for the contract.

## Examples

``` r
backend <- resolve_backend(provider = 'mock')
if (FALSE) { # \dontrun{
backend <- resolve_backend(provider = 'gemini')
backend <- resolve_backend(provider = 'local')
} # }
```
