# Resolve the pseudo-bulk view for a ModuleSet

The resolver every pseudo-bulk tool uses: returns `ms` itself when it is
already a pseudo-bulk set (built by
[`pseudobulk_ModuleSet()`](https://smorabit.github.io/llegir/reference/pseudobulk_ModuleSet.md)),
returns the attached view via
[`pseudobulk()`](https://smorabit.github.io/llegir/reference/pseudobulk.md)
when one exists, and `NULL` otherwise – the signal for a tool to skip
gracefully.

## Usage

``` r
pseudobulk_view(ms)
```

## Arguments

- ms:

  A `ModuleSet` object.

## Value

A `ModuleSet`, or `NULL`.
