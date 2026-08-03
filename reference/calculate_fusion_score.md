# Calculate the deterministic fused evidence confidence for a packet

Normalizes every fragment onto a unified `[0, 1]` scale
(`.fragment_score()`: a type-aware magnitude link times a significance-
reliability factor), pools them with a weighted power mean
(`.pool_evidence()`) using tool-tier + `user_weights` importance
(`.tool_weight()`), and applies a mass-weighted directional-conflict
penalty (`.directional_coherence()`). Computed straight from the packet
*before* synthesis, so the result is reproducible from the packet hash
alone; it's injected into the synthesis prompt as ground truth
(`.render_confidence_matrix()`) and re-used by
[`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md)
as the evidence term, so the printed fusion string can never drift from
the math.

## Usage

``` r
calculate_fusion_score(
  fragments,
  user_weights = list(),
  beta = 0.5,
  lambda = 0.35,
  kappa = 0.5
)
```

## Arguments

- fragments:

  A list of `evidence_fragment` objects (a packet's `fragments`).

- user_weights:

  Named list of per-`tool_id` weight multipliers on top of the
  structural tier base (see
  [`register_tool()`](https://smorabit.github.io/llegir/reference/register_tool.md)'s
  `tier` argument). Default [`list()`](https://rdrr.io/r/base/list.html)
  (all tiers unmodified).

- beta:

  Corroboration exponent for the power mean; lower is more conjunctive
  (a single weak tool can't be offset by a strong one), higher is more
  compensatory. Default `0.5`.

- lambda:

  Model-trust weight in the final geometric blend
  ([`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md));
  threaded through only for provenance on the returned list. Default
  `0.35`.

- kappa:

  Maximum directional-conflict penalty. Default `0.5`.

## Value

A list: `e_evidence` (the final empirical evidence term), `e_pool`
(pooled evidence before the directional penalty), `p_agree` (the
directional penalty factor), `c_dir` (directional coherence), `lambda`,
`params` (`beta`, `kappa`), and `matrix` (a per-fragment `data.frame`
for prompt rendering and audit).

## Examples

``` r
ms <- llegir_example_moduleset()
packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
calculate_fusion_score(packet$fragments)
#> $e_evidence
#> [1] 0.9389462
#> 
#> $e_pool
#> [1] 0.9389462
#> 
#> $p_agree
#> [1] 1
#> 
#> $c_dir
#> [1] 1
#> 
#> $lambda
#> [1] 0.35
#> 
#> $params
#> $params$beta
#> [1] 0.5
#> 
#> $params$kappa
#> [1] 0.5
#> 
#> 
#> $matrix
#>   fragment_id         type weight magnitude reliability e_score direction
#> 1   top_genes ranked_genes    0.6     0.939           1   0.939        na
#> 
```
