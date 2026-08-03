# Build a ModuleSet from a Seurat object with an hdWGCNA experiment

The only `ModuleSet` adapter that touches Seurat/hdWGCNA directly; every
core evidence tool depends only on the generic `ModuleSet` contract
([`modules()`](https://smorabit.github.io/llegir/reference/modules.md),
[`gene_membership()`](https://smorabit.github.io/llegir/reference/gene_membership.md),
[`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md),
[`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
[`counts()`](https://smorabit.github.io/llegir/reference/counts.md),
[`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md)),
never on this backend.

## Usage

``` r
hdWGCNA_ModuleSet(
  seurat_obj,
  wgcna_name = NULL,
  data_level = "cell",
  aggregated = FALSE
)

# S3 method for class 'hdWGCNA_ModuleSet'
modules(ms, include_grey = FALSE, ...)

# S3 method for class 'hdWGCNA_ModuleSet'
gene_membership(ms, module, ...)

# S3 method for class 'hdWGCNA_ModuleSet'
module_scores(ms, module = NULL, ...)

# S3 method for class 'hdWGCNA_ModuleSet'
expression(ms, ...)

# S3 method for class 'hdWGCNA_ModuleSet'
counts(ms, ...)

# S3 method for class 'hdWGCNA_ModuleSet'
metadata(ms, ...)

# S3 method for class 'hdWGCNA_ModuleSet'
pkg_versions(ms, ...)

# S3 method for class 'hdWGCNA_ModuleSet'
capabilities(ms, ...)
```

## Arguments

- seurat_obj:

  A `Seurat` object with an hdWGCNA experiment attached (i.e. run
  through the hdWGCNA pipeline).

- wgcna_name:

  Name of the hdWGCNA experiment to read from. Defaults to whichever
  experiment is currently active on `seurat_obj`.

- data_level:

  Observation-unit descriptor, e.g. `'cell'` or `'sample'`. Default
  `'cell'`.

- aggregated:

  Whether
  [`expression()`](https://smorabit.github.io/llegir/reference/expression.md)/[`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md)
  are already aggregated across cells (e.g. pseudobulk) rather than
  per-cell. Default `FALSE`.

- ms:

  A `ModuleSet` object; the dispatch target for the generic methods
  below
  ([`modules()`](https://smorabit.github.io/llegir/reference/modules.md),
  [`gene_membership()`](https://smorabit.github.io/llegir/reference/gene_membership.md),
  [`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md),
  [`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
  [`counts()`](https://smorabit.github.io/llegir/reference/counts.md),
  [`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
  [`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md),
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)).

- include_grey:

  Include hdWGCNA's 'grey' bucket for unassigned genes (not a real
  co-expression module). Default `FALSE`.

- ...:

  Passed to methods.

- module:

  A single module id, as returned by
  [`modules()`](https://smorabit.github.io/llegir/reference/modules.md).

## Value

An `hdWGCNA_ModuleSet` object.

## Examples

``` r
if (FALSE) { # \dontrun{
library(Seurat)
seurat_obj <- readRDS('my_hdwgcna_object.rds')
ms <- hdWGCNA_ModuleSet(seurat_obj)
modules(ms)
} # }
```
