# Parse an evidence fragment from JSON

Inverse of
[`fragment_to_json()`](https://smorabit.github.io/llegir/reference/fragment_to_json.md);
rebuilds the `evidence_fragment` class and defaults for fields that may
have been dropped by JSON's null handling.

## Usage

``` r
fragment_from_json(json_str)
```

## Arguments

- json_str:

  A JSON string as produced by
  [`fragment_to_json()`](https://smorabit.github.io/llegir/reference/fragment_to_json.md).

## Value

An `evidence_fragment` object.
