# Validate a dataset description

Hard-errors on a missing/empty required field (`species`, `tissue`,
`cell_compartment`, `assay`); `conditions`/`notes` may be empty, since
not every dataset has discrete conditions. A missing/empty description
is a hard error, not a default, since it's required biological context
for synthesis.

## Usage

``` r
validate_dataset_description(desc)
```

## Arguments

- desc:

  A `dataset_description` object.

## Value

Invisibly `TRUE` if valid; otherwise throws.

## Examples

``` r
validate_dataset_description(dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq'))
```
