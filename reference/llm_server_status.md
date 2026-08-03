# Query a local vLLM server's model list

GETs `<base_url>/models` and returns the base URL and the served model
ids. Used by
[`resolve_backend()`](https://smorabit.github.io/llegir/reference/resolve_backend.md)
for model auto-discovery and by
[`local_backend()`](https://smorabit.github.io/llegir/reference/local_backend.md)
for connectivity pre-flight. Throws a clear, actionable error if the
server is unreachable so the failure site is visible at the top of the
call stack rather than buried in an httr2 connection error.

## Usage

``` r
llm_server_status(
  base_url = Sys.getenv("LLEGIR_LLM_URL", "http://127.0.0.1:8000/v1")
)
```

## Arguments

- base_url:

  Base URL of the OpenAI-compatible server (no trailing slash); defaults
  to `LLEGIR_LLM_URL` or `http://127.0.0.1:8000/v1`.

## Value

A list with two elements: `base_url` (character) and `models` (character
vector of served model ids as reported by the `/models` endpoint).

## Examples

``` r
if (FALSE) { # \dontrun{
status <- llm_server_status()
cat('Served models:', paste(status$models, collapse = ', '), '\n')
} # }
```
