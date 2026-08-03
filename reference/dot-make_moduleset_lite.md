# Build a reduced ModuleSet carrying only the token-safe views

Rebuilds a `components_ModuleSet` from `ms`'s own getters, carrying the
full gene-membership tables (every module), module scores, metadata, the
declared grouping/sample-id columns,
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md),
`data_level`/ `aggregated`, and the pseudobulk view when one is attached
and already small – but never the backing expression/counts matrices.
This is the artifact an agent workspace loads by default
(`moduleset_lite.qs2`); the full `ms` still ships alongside it
(`moduleset_full.qs2`) for the rare
[`expression()`](https://smorabit.github.io/llegir/reference/expression.md)/[`counts()`](https://smorabit.github.io/llegir/reference/counts.md)
query.

## Usage

``` r
.make_moduleset_lite(ms)
```

## Arguments

- ms:

  A validated `ModuleSet`.

## Value

A `components_ModuleSet` with `capabilities()$expression` and `$counts`
`FALSE`.

## Details

Reuses
[`components_ModuleSet()`](https://smorabit.github.io/llegir/reference/components_ModuleSet.md)
rather than a bespoke class so every `ModuleSet` generic keeps
dispatching unchanged against the reduced object.
