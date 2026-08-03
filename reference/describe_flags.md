# Describe an interpretation's flags in human-readable form

Describe an interpretation's flags in human-readable form

## Usage

``` r
describe_flags(flags)
```

## Arguments

- flags:

  A character vector (or list) of flags from the `.interpretation_flags`
  controlled vocabulary.

## Value

A single character string (flags' explanations joined with `'; '`), or
`''` if `flags` is empty.

## Examples

``` r
describe_flags(list('insufficient_evidence', 'tool_conflict'))
#> [1] "deterministic evidence signals are weak (low effect size / few significant terms); evidence tools disagree on whether the module shows a real signal"
```
