# Build a fragment's provenance record

Build a fragment's provenance record

## Usage

``` r
make_provenance(
  tool_version,
  params = list(),
  input_hashes = list(),
  pkg_versions = list(),
  source = "computed",
  module_method = NA_character_
)
```

## Arguments

- tool_version:

  Version string for the tool that produced the fragment.

- params:

  Named list of the parameters the tool was called with.

- input_hashes:

  Named list of content hashes of relevant inputs.

- pkg_versions:

  Named list of backend package versions, typically from the
  `ModuleSet`'s own
  [`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md).

- source:

  `'computed'` (default, tool-produced) or `'user_supplied'` (set
  automatically by
  [`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md)).

- module_method:

  Optional free-form description of how the modules themselves were
  generated, e.g. `'cNMF factors, k=20'`; see
  [`dataset_description()`](https://smorabit.github.io/llegir/reference/dataset_description.md).
  Threaded through from
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md)
  /
  [`run_orchestrator()`](https://smorabit.github.io/llegir/reference/run_orchestrator.md)'s
  `module_method` argument, when given. Default `NA`.

## Value

A provenance list suitable for
[`evidence_fragment()`](https://smorabit.github.io/llegir/reference/evidence_fragment.md)'s
`provenance` argument.
