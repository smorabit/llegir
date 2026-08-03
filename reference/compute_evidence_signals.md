# Compute deterministic evidence signals from a packet

Signals independent of any model output: the maximum bounded effect
strength across fragments, the number of significant enrichment terms,
and cross-tool agreement on whether the module shows a real signal. Two
guards against known false-positive patterns (not thresholds tuned to
any one dataset): a fragment only counts as "has signal" if it clears
both a significance AND an effect-size bar (large-N tests can hit p~0 on
a practically negligible effect), and an enrichment term only counts as
significant with at least `min_overlap_genes` overlapping genes (a
single-gene overlap against a narrow term is a classic false positive in
a small hub-gene list).

## Usage

``` r
compute_evidence_signals(
  packet,
  sig_threshold = 0.05,
  effect_floor = 0.5,
  min_overlap_genes = 2
)
```

## Arguments

- packet:

  An evidence packet, as built by
  [`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md).

- sig_threshold:

  Significance (p/FDR) cutoff.

- effect_floor:

  Minimum effect strength for a bounded fragment to count as "has
  signal".

- min_overlap_genes:

  Minimum overlap genes for an enrichment term to count as significant.

## Value

A list: `max_effect_strength`, `n_significant_enrichment_terms`,
`n_testable_tools`, `n_tools_with_signal`, `cross_tool_agreement` (one
of `'convergent_signal'`, `'convergent_null'`, `'conflicting'`, or
`NA`).

## Examples

``` r
ms <- llegir_example_moduleset()
packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
compute_evidence_signals(packet)
#> $max_effect_strength
#> [1] 0.9389462
#> 
#> $n_significant_enrichment_terms
#> [1] 0
#> 
#> $n_testable_tools
#> [1] 0
#> 
#> $n_tools_with_signal
#> [1] 0
#> 
#> $cross_tool_agreement
#> [1] NA
#> 
```
