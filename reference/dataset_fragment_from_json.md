# Parse a dataset fragment from JSON

Inverse of
[`dataset_fragment_to_json()`](https://smorabit.github.io/llegir/reference/dataset_fragment_to_json.md);
rebuilds the `dataset_fragment` class and defaults for fields that may
have been dropped by JSON's null handling.

## Usage

``` r
dataset_fragment_from_json(json_str)
```

## Arguments

- json_str:

  A JSON string as produced by
  [`dataset_fragment_to_json()`](https://smorabit.github.io/llegir/reference/dataset_fragment_to_json.md).

## Value

A `dataset_fragment` object.
