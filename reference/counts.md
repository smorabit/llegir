# Underlying raw counts matrix backing a module set

Underlying raw counts matrix backing a module set

## Usage

``` r
counts(ms, ...)
```

## Arguments

- ms:

  A `ModuleSet` object.

- ...:

  Passed to methods.

## Value

A genes-by-cells (or genes-by-samples) numeric matrix of raw counts,
aligned to
[`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
or `NULL` if the adapter doesn't carry raw counts (see
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)`$counts`).
