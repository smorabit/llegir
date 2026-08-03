# Validate that a ModuleSet satisfies the full adapter contract

Asserts that every required generic
([`modules()`](https://smorabit.github.io/llegir/reference/modules.md),
[`gene_membership()`](https://smorabit.github.io/llegir/reference/gene_membership.md),
[`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md),
[`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
[`counts()`](https://smorabit.github.io/llegir/reference/counts.md),
[`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md),
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md))
dispatches for `ms`'s class and returns the documented shape; that
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)
covers the full vocabulary (see
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)),
with
[`pseudobulk_view()`](https://smorabit.github.io/llegir/reference/pseudobulk_view.md)
resolving to a real `ModuleSet` whenever `pseudobulk = TRUE`; that
`ms$data_level` / `ms$aggregated` are a length-1 character / logical;
and that
[`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
[`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
[`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md),
and [`counts()`](https://smorabit.github.io/llegir/reference/counts.md)
agree in dimensions wherever their capability is declared `TRUE`.
Intended as a one-shot check for anyone writing a new adapter, and run
automatically at the top of
[`run_orchestrator()`](https://smorabit.github.io/llegir/reference/run_orchestrator.md).

## Usage

``` r
validate_moduleset(ms)
```

## Arguments

- ms:

  A `ModuleSet` object.

## Value

Invisibly `TRUE` if valid; otherwise throws with the specific contract
violation.

## Examples

``` r
validate_moduleset(llegir_example_moduleset())
```
