# Validate an interpretation object

Asserts required fields and basic shape against
`inst/schemas/interpretation.schema.json`. Faithfulness (fragment_ids
exist in the packet, direction matches) is a separate check against the
packet (see
[`check_faithfulness()`](https://smorabit.github.io/llegir/reference/check_faithfulness.md)),
not enforced here.

## Usage

``` r
validate_interpretation(interp)
```

## Arguments

- interp:

  An `interpretation` object.

## Value

`TRUE`, invisibly, on success. Throws on the first violation.
