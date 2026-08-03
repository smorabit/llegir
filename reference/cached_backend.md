# Cache a synthesis backend's raw model calls on disk

Wraps any backend with a cache keyed on `packet_hash` + `provider` +
`model` + `prompt_template_version`: on a hit, the inner backend (the
live API call) is skipped entirely. Deliberately caches only the raw
model call, not the full synthesized interpretation – faithfulness,
confidence fusion, and rendering are cheap and deterministic and still
re-run every time on top of the cached content, so only an actual
packet/provider/model/prompt change ever costs an API call.

## Usage

``` r
cached_backend(
  backend,
  provider,
  model,
  prompt_template_version,
  cache_dir = "output/cache",
  force_refresh = FALSE
)
```

## Arguments

- backend:

  The backend function to wrap; see
  [`mock_backend()`](https://smorabit.github.io/llegir/reference/mock_backend.md)
  for the contract.

- provider:

  Provider name, used only as a cache-key component.

- model:

  Model id, used only as a cache-key component.

- prompt_template_version:

  Prompt template version, used only as a cache-key component.

- cache_dir:

  Directory to store cached `.rds` responses in.

- force_refresh:

  If `TRUE`, bypass the cache and always call `backend`.

## Value

A backend function; see
[`mock_backend()`](https://smorabit.github.io/llegir/reference/mock_backend.md)
for the contract.

## Examples

``` r
backend <- cached_backend(mock_backend(), provider = 'mock', model = 'mock',
    prompt_template_version = '0.2', cache_dir = tempfile())
```
