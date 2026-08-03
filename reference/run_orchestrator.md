# Run a configured set of evidence tools over every module in a ModuleSet

Runs
[`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md)
independently for each module in `modules_use` (or every module in `ms`
if not given) and writes each validated, hashed evidence packet to
`output_dir` as JSON. One module's failure (e.g. a tool erroring on a
degenerate module) doesn't take down the whole batch; failures are
reported via [`warning()`](https://rdrr.io/r/base/warning.html) and
recorded as `NULL` in the returned list. `tables_dir`, when given, also
persists every fragment's result table (via
[`write_fragment_tables()`](https://smorabit.github.io/llegir/reference/write_fragment_tables.md))
alongside the JSON packets.

## Usage

``` r
run_orchestrator(
  ms,
  tool_config,
  output_dir,
  tables_dir = NULL,
  modules_use = NULL,
  input_hash = NA_character_,
  module_method = NA_character_,
  validate = TRUE
)
```

## Arguments

- ms:

  A `ModuleSet`.

- tool_config:

  A list of `list(fn, params)` specs; see
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md).

- output_dir:

  Directory to write one evidence packet JSON file per module.

- tables_dir:

  Optional directory to also persist every fragment's result table.

- modules_use:

  Optional subset of module ids to run; defaults to all modules in `ms`.

- input_hash:

  Optional hash of the input `ModuleSet`, recorded on each packet.

- module_method:

  Optional free-form description of how the modules themselves were
  generated; see
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md)
  /
  [`dataset_description()`](https://smorabit.github.io/llegir/reference/dataset_description.md).
  Passed through to every
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md)
  call. Default `NA`.

- validate:

  If `TRUE` (default), run
  [`validate_moduleset()`](https://smorabit.github.io/llegir/reference/validate_moduleset.md)
  on `ms` before doing anything else, so a malformed adapter fails
  loudly up front instead of partway through a batch.

## Value

Invisibly, a named list of evidence packets (one per module; `NULL` for
any module that failed).

## Examples

``` r
ms <- llegir_example_moduleset()
run_orchestrator(ms, list(list(fn = top_genes_tool, params = list())), output_dir = tempfile())
```
