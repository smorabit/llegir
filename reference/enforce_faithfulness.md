# Flag (rather than reject) an interpretation with faithfulness violations

The pipeline variant of
[`assert_faithfulness()`](https://smorabit.github.io/llegir/reference/assert_faithfulness.md):
does not throw, so one bad claim doesn't take down a whole batch run.
Instead unions `'needs_human_review'` into `interp$flags`, which
[`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md)
folds into the final routing decision.

## Usage

``` r
enforce_faithfulness(interp, packet)
```

## Arguments

- interp:

  An `interpretation` object.

- packet:

  The evidence packet `interp` was synthesized from.

## Value

`interp`, with `flags` updated if any violation was found.
