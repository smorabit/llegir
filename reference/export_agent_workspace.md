# Export a self-contained agent workspace and manifest

Serializes the run's `ModuleSet`, dataset context, and evidence packets
to `out_dir`, then renders `.llegir_agent_manifest.md`: a static
launchpad an external terminal coding agent points at to run open-ended,
read-only queries against this analysis. The API and tool cheat-sheets
are generated from the live registry and this `ModuleSet`'s
capabilities, so a workspace exported after a user registers a custom
tool documents that tool with no manual step. Pure exporter: writes
files and returns a path, never calls `ellmer` or spends budget.

## Usage

``` r
export_agent_workspace(
  ms,
  dataset_context,
  packets,
  desc,
  interps = NULL,
  out_dir = "agent_workspace",
  write_json = TRUE
)
```

## Arguments

- ms:

  A validated `ModuleSet`.

- dataset_context:

  A `dataset_context` (see
  [`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md)).

- packets:

  A named list of evidence packets, keyed by module id (e.g. the return
  value of
  [`run_orchestrator()`](https://smorabit.github.io/llegir/reference/run_orchestrator.md)).

- desc:

  The `dataset_description` for this run.

- interps:

  A named list of `interpretation` objects, keyed by module id (e.g. the
  return value of
  [`run_synthesis_orchestrator()`](https://smorabit.github.io/llegir/reference/run_synthesis_orchestrator.md)),
  or `NULL` (default) when this run didn't synthesize any. When `NULL`,
  no interpretation artifacts are written and the manifest records that
  this run shipped no interpretations, so the guest agent does not
  mock-synthesize one.

- out_dir:

  Destination workspace directory. Default `'agent_workspace'`.

- write_json:

  Also emit portable JSON copies of the context, packets, and (if
  present) interpretations. Default `TRUE`.

## Value

The absolute path to the written manifest, invisibly.

## Details

The `ModuleSet` is serialized twice: `artifacts/moduleset_lite.qs2` (a
[`.make_moduleset_lite()`](https://smorabit.github.io/llegir/reference/dot-make_moduleset_lite.md)
reduction with the backing expression/counts matrices dropped – what
`query_example.R` loads by default) and `artifacts/moduleset_full.qs2`
(`ms` unchanged, for the rare
[`expression()`](https://smorabit.github.io/llegir/reference/expression.md)/[`counts()`](https://smorabit.github.io/llegir/reference/counts.md)
query). Every cheat-sheet row, tool-registry row, and recipe rung is
still generated against `ms`'s full capabilities – nothing is dropped
from the docs – but is tagged `(full object only)` when it needs
something the lite object doesn't carry.
