# `ctx`-compatible tool wrapper around [`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md)

Slots
[`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md)
into an orchestrator's `tool_config` list exactly like any other tool.
Reads `ctx$params$result` (a data.frame) or `ctx$params$result_path` (a
delimited file) plus `ctx$params$type`.

## Usage

``` r
import_fragment_tool(ctx)
```

## Arguments

- ctx:

  A tool context list: `list(ms, module_id, params)`, as built by
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md).

## Value

An `evidence_fragment` object.
