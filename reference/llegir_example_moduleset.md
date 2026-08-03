# A small, self-contained synthetic ModuleSet for examples and the vignette

Builds a tiny simulated single-cell-like dataset (no Seurat/hdWGCNA
involved, no external data file) with two co-expressed gene modules –
`'module_a'`, associated with a simulated `diagnosis` column, and
`'module_b'`, associated with a simulated `cell_type` column – plus
background noise genes, and wraps it as a `ModuleSet` via
[`synthetic_ModuleSet()`](https://smorabit.github.io/llegir/reference/synthetic_ModuleSet.md).
Runs fully offline and deterministically (fixed seed), so it is safe to
use in `@examples`, tests, and the package vignette without any real
dataset.

## Usage

``` r
llegir_example_moduleset(seed = 1)
```

## Arguments

- seed:

  Random seed for reproducibility. Default `1`.

## Value

A `synthetic_ModuleSet` object with two modules, `'module_a'` and
`'module_b'`.

## Details

The simulated
[`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md)
includes `diagnosis`, `cell_type`, and `sample` columns, matching what
[`cluster_dme_tool()`](https://smorabit.github.io/llegir/reference/cluster_dme_tool.md)
expects.

## Examples

``` r
ms <- llegir_example_moduleset()
modules(ms)
#> [1] "module_a" "module_b"
gene_membership(ms, 'module_a')
#>    gene_name   module       kme
#> 4     GENEA4 module_a 0.9389462
#> 9     GENEA9 module_a 0.9368404
#> 5     GENEA5 module_a 0.9330942
#> 10   GENEA10 module_a 0.9324491
#> 8     GENEA8 module_a 0.9304695
#> 1     GENEA1 module_a 0.9299657
#> 2     GENEA2 module_a 0.9242594
#> 7     GENEA7 module_a 0.9236174
#> 3     GENEA3 module_a 0.9157541
#> 6     GENEA6 module_a 0.9102198
```
