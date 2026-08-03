# Check citation faithfulness of an interpretation against its packet

Every fragment_id cited in `supporting_claims` / `metadata_associations`
must exist in the module's evidence packet, and a `supporting_claims`
entry's `direction` must match the direction actually reported by the
fragment(s) it cites. Pure and non-throwing; see
[`assert_faithfulness()`](https://smorabit.github.io/llegir/reference/assert_faithfulness.md)
for the hard-rejecting variant.

## Usage

``` r
check_faithfulness(interp, packet)
```

## Arguments

- interp:

  An `interpretation` object.

- packet:

  The evidence packet `interp` was synthesized from.

## Value

A list of violation records (empty if faithful); each record is a list
with `location`, `index`, `fragment_id`, `issue` (`'missing_fragment'`
or `'direction_mismatch'`), and, for `'direction_mismatch'`,
`claim_direction`/`fragment_direction`.

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
