# Build the review queue from a batch of interpretations

Only flagged interpretations
([`needs_review()`](https://smorabit.github.io/llegir/reference/needs_review.md))
– this is a queue for a human to triage, not a full summary of every
module. Sorted lowest-confidence first.

## Usage

``` r
build_review_queue(interps)
```

## Arguments

- interps:

  A named list of interpretations, e.g. the return value of
  [`run_synthesis_orchestrator()`](https://smorabit.github.io/llegir/reference/run_synthesis_orchestrator.md).

## Value

A data.frame: `module_id`, `confidence`, `flags`, `reason`.

## Examples

``` r
ms <- llegir_example_moduleset()
packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
interp <- synthesize_interpretation(packet, desc, mock_backend())
build_review_queue(list(m1 = interp))
#> [1] module_id  confidence flags      reason    
#> <0 rows> (or 0-length row.names)
```
