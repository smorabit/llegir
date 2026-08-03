# Does an interpretation need human review?

Flagged interpretations are routed to the review queue
([`build_review_queue()`](https://smorabit.github.io/llegir/reference/build_review_queue.md));
exposed here so the output stage doesn't re-derive the rule.

## Usage

``` r
needs_review(interp)
```

## Arguments

- interp:

  An `interpretation` object.

## Value

A single logical: `TRUE` if `interp$flags` is non-empty.
