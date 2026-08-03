# Validate an evidence fragment

Asserts required fields and basic types against
`inst/schemas/evidence_fragment.schema.json`.

## Usage

``` r
validate_evidence_fragment(frag)
```

## Arguments

- frag:

  An `evidence_fragment` object.

## Value

`TRUE`, invisibly, on success. Throws on the first violation.
