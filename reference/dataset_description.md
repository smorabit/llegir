# Construct a dataset description

The required biological context prepended to every synthesis prompt (see
[`render_dataset_description()`](https://smorabit.github.io/llegir/reference/render_dataset_description.md),
[`build_user_prompt()`](https://smorabit.github.io/llegir/reference/build_user_prompt.md))
so the model interprets a module in the right frame – e.g. CSF myeloid
vs. tumor changes what a given program means, and disambiguates gene
function like microglia vs. macrophage.

## Usage

``` r
dataset_description(
  species,
  tissue,
  cell_compartment,
  assay,
  conditions = character(0),
  notes = NA_character_,
  module_method = NA_character_
)
```

## Arguments

- species:

  Species, e.g. `'human'`.

- tissue:

  Tissue, e.g. `'CSF'`.

- cell_compartment:

  Cell compartment / lineage, e.g. `'myeloid'`.

- assay:

  Assay, e.g. `'scRNA-seq'`.

- conditions:

  Optional character vector of conditions/groups present in the dataset.

- notes:

  Optional free-text notes.

- module_method:

  Optional free-form description of how the modules themselves were
  generated, e.g. `'hdWGCNA co-expression modules'` or
  `'cNMF factors, k=20'` – disambiguates what a "module" means for this
  run (a co-expression program vs. a factorization component) since that
  changes how the model should interpret gene weights/usages.

## Value

A `dataset_description` object.

## Examples

``` r
dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq', conditions = c('MS', 'control'))
#> $species
#> [1] "human"
#> 
#> $tissue
#> [1] "CSF"
#> 
#> $cell_compartment
#> [1] "myeloid"
#> 
#> $assay
#> [1] "scRNA-seq"
#> 
#> $conditions
#> [1] "MS"      "control"
#> 
#> $notes
#> [1] NA
#> 
#> $module_method
#> [1] NA
#> 
#> attr(,"class")
#> [1] "dataset_description"
```
