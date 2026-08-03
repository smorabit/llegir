# Parse an interpretation from JSON

Inverse of
[`interpretation_to_json()`](https://smorabit.github.io/llegir/reference/interpretation_to_json.md);
rebuilds the `interpretation` class.

## Usage

``` r
interpretation_from_json(json_str)
```

## Arguments

- json_str:

  A JSON string as produced by
  [`interpretation_to_json()`](https://smorabit.github.io/llegir/reference/interpretation_to_json.md).

## Value

An `interpretation` object.
