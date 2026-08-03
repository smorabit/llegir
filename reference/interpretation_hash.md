# Hash an interpretation

Hash an interpretation

## Usage

``` r
interpretation_hash(interp)
```

## Arguments

- interp:

  An `interpretation` object.

## Value

A sha256 hash string, stable across reruns (volatile fields like
timestamps are stripped before hashing).
