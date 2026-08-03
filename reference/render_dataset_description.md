# Render a dataset description as a compact text block

Prepended to the synthesis prompt; see
[`build_user_prompt()`](https://smorabit.github.io/llegir/reference/build_user_prompt.md).

## Usage

``` r
render_dataset_description(desc, data_level = "cell", aggregated = FALSE)
```

## Arguments

- desc:

  A `dataset_description` object.

- data_level:

  Observation-unit descriptor of the `ModuleSet` the evidence packet was
  built from, e.g. `'cell'` or `'sample'`; see
  [`components_ModuleSet()`](https://smorabit.github.io/llegir/reference/components_ModuleSet.md).
  Default `'cell'`.

- aggregated:

  Whether that `ModuleSet`'s expression/scores are already aggregated
  across cells (e.g. pseudobulk) rather than per-cell. Default `FALSE`.

## Value

A single character string.

## Examples

``` r
cat(render_dataset_description(dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')))
#> Dataset context:
#> - species: human
#> - tissue: CSF
#> - cell compartment: myeloid
#> - assay: scRNA-seq
#> - data level: cell
#> - aggregated: FALSE
```
