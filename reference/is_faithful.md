# Is an interpretation faithful to its evidence packet?

Is an interpretation faithful to its evidence packet?

## Usage

``` r
is_faithful(interp, packet, alpha = 0.05)
```

## Arguments

- interp:

  An `interpretation` object.

- packet:

  The evidence packet `interp` was synthesized from.

- alpha:

  Significance threshold passed to
  [`check_faithfulness()`](https://smorabit.github.io/llegir/reference/check_faithfulness.md).

## Value

A single logical.
