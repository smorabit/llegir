# Check citation faithfulness of an interpretation against its packet

Every fragment_id cited in `supporting_claims` must exist in the
module's evidence packet, and a `supporting_claims` entry's `direction`
must match the direction actually reported by the fragment(s) it cites.
Significance wording ("significant", "enriched", "over-represented";
negated uses such as "not significant" are allowed) must be backed by a
fragment whose `significance` is below `alpha`:

- in a `supporting_claims` entry, when none of its cited fragments
  passes `alpha` and at least one of them is a tested result (non-`NA`
  significance, or a `geneset_enrichment` fragment) – so a claim that
  the hub genes are "enriched for ribosomal proteins", citing only a
  `ranked_genes` fragment, is not flagged;

- in each sentence of the `interpretation` text, when the fragments that
  sentence names (by `fragment_id`, or every `geneset_enrichment`
  fragment when it speaks of enrichment without naming one) include none
  that passes `alpha`.

## Usage

``` r
check_faithfulness(interp, packet, alpha = 0.05)
```

## Arguments

- interp:

  An `interpretation` object.

- packet:

  The evidence packet `interp` was synthesized from.

- alpha:

  Significance threshold for the wording check. Default 0.05.

## Value

A list of violation records (empty if faithful); each record is a list
with `location` (`'supporting_claims'` or `'interpretation'`), `index`
(claim or sentence number), `fragment_id`, `issue`
(`'missing_fragment'`, `'direction_mismatch'` or
`'unsupported_significance'`), and, for `'direction_mismatch'`,
`claim_direction`/`fragment_direction`.

## Details

Pure and non-throwing; see
[`assert_faithfulness()`](https://smorabit.github.io/llegir/reference/assert_faithfulness.md)
for the hard-rejecting variant.

## Examples

``` r
ms <- llegir_example_moduleset()
packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
interp <- synthesize_interpretation(packet, desc, mock_backend())
check_faithfulness(interp, packet)
#> [[1]]
#> [[1]]$location
#> [1] "supporting_claims"
#> 
#> [[1]]$index
#> [1] 2
#> 
#> [[1]]$fragment_id
#> [1] "geneset_enrichment"
#> 
#> [[1]]$issue
#> [1] "missing_fragment"
#> 
#> 
```
