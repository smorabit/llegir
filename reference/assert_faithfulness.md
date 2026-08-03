# Hard-reject an interpretation with any faithfulness violation

Throws if
[`check_faithfulness()`](https://smorabit.github.io/llegir/reference/check_faithfulness.md)
finds any fabricated or direction-mismatched citation.

## Usage

``` r
assert_faithfulness(interp, packet)
```

## Arguments

- interp:

  An `interpretation` object.

- packet:

  The evidence packet `interp` was synthesized from.

## Value

Invisibly `TRUE` if faithful; otherwise throws.
