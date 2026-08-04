# Build a dataset context once per dataset

The dataset-level analog of
[`run_orchestrator()`](https://smorabit.github.io/llegir/reference/run_orchestrator.md):
runs every tool in `dataset_tool_config` once against the whole
`ModuleSet` (never per module) and bundles the resulting
`dataset_fragment`s into a validated, hashed dataset context via
[`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md).
Mirrors
[`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md)'s
spec handling exactly, except `ctx` has no `module_id` – a dataset tool
reads `expression(ms)`/`metadata(ms)`/`module_scores(ms)` in full, not
for one module.

## Usage

``` r
run_dataset_context(
  ms,
  dataset_tool_config,
  input_hash = NA_character_,
  module_method = NA_character_,
  validate = TRUE
)
```

## Arguments

- ms:

  A `ModuleSet`.

- dataset_tool_config:

  A list of tool specs, each one of:

  - `list(fn, params)` – a direct call to any
    `function(ctx) -> dataset_fragment` (or `NULL`, to skip); the tool
    is responsible for its own graceful capability-based skip.

  - `list(id, params)` – `id` is looked up in the tool registry (see
    [`register_tool()`](https://smorabit.github.io/llegir/reference/register_tool.md)),
    and `run_dataset_context()` checks the tool's declared required
    [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)
    before calling it. If unmet, the tool is skipped and the reason is
    recorded on the context's `provenance$skipped`.

  Either form's `params` is passed through as `ctx$params`.

- input_hash:

  Optional hash of the input `ModuleSet`, recorded on the context for
  provenance.

- module_method:

  Optional free-form description of how the modules themselves were
  generated; see
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md)
  /
  [`dataset_description()`](https://smorabit.github.io/llegir/reference/dataset_description.md).
  Passed through as `ctx$module_method`. Default `NA`.

- validate:

  If `TRUE` (default), run
  [`validate_moduleset()`](https://smorabit.github.io/llegir/reference/validate_moduleset.md)
  on `ms` before doing anything else.

## Value

A dataset context; see
[`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md).

## Examples

``` r
ms <- llegir_example_moduleset()
run_dataset_context(ms, list())
#> $dataset_fragments
#> list()
#> 
#> $context_hash
#> [1] "28df520b992b4a4bead0a7a527ee2f4fc64fbcc2892ab364f676113761cbeefc"
#> 
#> $schema_version
#> [1] "0.1"
#> 
#> $provenance
#> $provenance$created_at
#> [1] "2026-08-04T17:22:53+0200"
#> 
#> $provenance$input_hash
#> [1] NA
#> 
#> $provenance$tool_ids
#> character(0)
#> 
#> $provenance$skipped
#> list()
#> 
#> 
```
