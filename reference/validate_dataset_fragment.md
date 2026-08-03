# Validate a dataset fragment

Asserts required fields and basic types against
`inst/schemas/dataset_fragment.schema.json`.

## Usage

``` r
validate_dataset_fragment(frag)
```

## Arguments

- frag:

  A `dataset_fragment` object.

## Value

`TRUE`, invisibly, on success. Throws on the first violation.
