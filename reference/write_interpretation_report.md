# Write a combined interpretation + evidence HTML report

Renders every module's synthesized interpretation alongside the raw
deterministic evidence it was drawn from into one human-readable HTML
file. Modules are paired by matching the names of `interps` and
`packets`.

## Usage

``` r
write_interpretation_report(
  interps,
  packets,
  desc,
  output_file = "output/report.html",
  quiet = TRUE
)
```

## Arguments

- interps:

  A named list of `interpretation` objects, keyed by module id (e.g. the
  return value of
  [`run_synthesis_orchestrator()`](https://smorabit.github.io/llegir/reference/run_synthesis_orchestrator.md)).

- packets:

  A named list of evidence packets, keyed by module id (e.g. the return
  value of
  [`run_orchestrator()`](https://smorabit.github.io/llegir/reference/run_orchestrator.md)).

- desc:

  The `dataset_description` used for this synthesis run.

- output_file:

  Destination HTML path. Default `'output/report.html'`.

- quiet:

  Suppress the pandoc/knitr progress output. Default `TRUE`.

## Value

The rendered file path, invisibly.
