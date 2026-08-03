# Genes assigned to a module, ranked by membership strength

Genes assigned to a module, ranked by membership strength

## Usage

``` r
gene_membership(ms, module, ...)
```

## Arguments

- ms:

  A `ModuleSet` object.

- module:

  A single module id, as returned by
  [`modules()`](https://smorabit.github.io/llegir/reference/modules.md).

- ...:

  Passed to methods.

## Value

A data.frame with one row per gene, ranked strongest membership first
(e.g. by hdWGCNA's kME).
