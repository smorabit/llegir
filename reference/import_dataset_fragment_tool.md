# `ctx`-compatible tool wrapper around [`import_dataset_fragment()`](https://smorabit.github.io/llegir/reference/import_dataset_fragment.md)

Slots
[`import_dataset_fragment()`](https://smorabit.github.io/llegir/reference/import_dataset_fragment.md)
into a `dataset_tool_config` list exactly like any other dataset tool
(see
[`run_dataset_context()`](https://smorabit.github.io/llegir/reference/run_dataset_context.md)).
Reads `ctx$params$result` (a data.frame) or `ctx$params$result_path` (a
delimited file) plus `ctx$params$type`.

## Usage

``` r
import_dataset_fragment_tool(ctx)
```

## Arguments

- ctx:

  A dataset tool context list: `list(ms, params, module_method)`, as
  built by
  [`run_dataset_context()`](https://smorabit.github.io/llegir/reference/run_dataset_context.md).

## Value

A `dataset_fragment` object.
