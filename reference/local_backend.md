# Convenience constructor for the local vLLM backend

Combines connectivity pre-flight
([`llm_server_status()`](https://smorabit.github.io/llegir/reference/llm_server_status.md)),
model auto-discovery,
[`resolve_backend()`](https://smorabit.github.io/llegir/reference/resolve_backend.md)
for `'local'`, and
[`cached_backend()`](https://smorabit.github.io/llegir/reference/cached_backend.md)
into a single call. Returns a ready-to-use cached backend suitable for
[`synthesize_interpretation()`](https://smorabit.github.io/llegir/reference/synthesize_interpretation.md)
and
[`run_synthesis_orchestrator()`](https://smorabit.github.io/llegir/reference/run_synthesis_orchestrator.md).

## Usage

``` r
local_backend(
  model = NULL,
  cache = TRUE,
  force_refresh = FALSE,
  prompt_template_version = PROMPT_TEMPLATE_VERSION
)
```

## Arguments

- model:

  Model id served by the vLLM server. When `NULL` (default), the
  server's model list is queried via
  [`llm_server_status()`](https://smorabit.github.io/llegir/reference/llm_server_status.md);
  a hard error is raised if zero or more than one models are served so
  the correct id can be specified explicitly.

- cache:

  If `TRUE` (default), wraps the live backend with
  [`cached_backend()`](https://smorabit.github.io/llegir/reference/cached_backend.md)
  keyed on provider, model, and prompt template version.

- force_refresh:

  Passed to
  [`cached_backend()`](https://smorabit.github.io/llegir/reference/cached_backend.md);
  if `TRUE`, bypasses any cached response and always calls the live
  server.

- prompt_template_version:

  Cache-key component passed to
  [`cached_backend()`](https://smorabit.github.io/llegir/reference/cached_backend.md);
  defaults to the package-level
  [PROMPT_TEMPLATE_VERSION](https://smorabit.github.io/llegir/reference/PROMPT_TEMPLATE_VERSION.md).

## Value

A backend function; see
[`mock_backend()`](https://smorabit.github.io/llegir/reference/mock_backend.md)
for the contract.

## Examples

``` r
if (FALSE) { # \dontrun{
backend <- local_backend()
} # }
```
