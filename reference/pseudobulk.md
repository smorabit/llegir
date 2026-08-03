# Attached pseudo-bulk view for a ModuleSet

Returns the pseudo-bulk `ModuleSet` attached via
[`with_pseudobulk()`](https://smorabit.github.io/llegir/reference/with_pseudobulk.md),
or `NULL` if none is attached. Most callers want
[`pseudobulk_view()`](https://smorabit.github.io/llegir/reference/pseudobulk_view.md)
instead, which also handles the case where `ms` is itself already a
pseudo-bulk set.

## Usage

``` r
pseudobulk(ms, ...)

# Default S3 method
pseudobulk(ms, ...)

# S3 method for class 'with_pseudobulk_ModuleSet'
pseudobulk(ms, ...)
```

## Arguments

- ms:

  A `ModuleSet` object.

- ...:

  Passed to methods.

## Value

A `ModuleSet`, or `NULL`.
