# Read a dataset context from a JSON file

Reconstructs a context (and each fragment's S3 class) from a JSON file
written by
[`write_dataset_context()`](https://smorabit.github.io/llegir/reference/write_dataset_context.md).

## Usage

``` r
read_dataset_context(path)
```

## Arguments

- path:

  Path to a context JSON file.

## Value

A dataset context, as returned by
[`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md).
