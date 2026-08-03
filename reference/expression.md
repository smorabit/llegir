# Underlying expression matrix backing a module set

Underlying expression matrix backing a module set

## Usage

``` r
expression(ms, ...)
```

## Arguments

- ms:

  A `ModuleSet` object.

- ...:

  Passed to methods.

## Value

A genes-by-cells (or genes-by-samples) numeric matrix.

## Note

Shadows [`base::expression()`](https://rdrr.io/r/base/expression.html)
once this package is attached; this package makes no use of
[`base::expression()`](https://rdrr.io/r/base/expression.html) /
plotmath. Flagged here as a known design tradeoff, not fixed in this
packaging pass.
