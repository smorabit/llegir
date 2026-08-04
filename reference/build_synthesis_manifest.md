# Build a run-level synthesis manifest

Complements the per-interpretation provenance already attached by
[`synthesize_interpretation()`](https://smorabit.github.io/llegir/reference/synthesize_interpretation.md)
with counts and the template versions used to produce this batch of
outputs.

## Usage

``` r
build_synthesis_manifest(
  interps,
  desc,
  prompt_template_version = PROMPT_TEMPLATE_VERSION,
  render_template_version = RENDER_TEMPLATE_VERSION
)
```

## Arguments

- interps:

  A named list of interpretations; see
  [`build_review_queue()`](https://smorabit.github.io/llegir/reference/build_review_queue.md).

- desc:

  The `dataset_description` used for this synthesis run.

- prompt_template_version:

  Prompt template version to record.

- render_template_version:

  Render template version to record.

## Value

A list, suitable for
[`write_synthesis_manifest()`](https://smorabit.github.io/llegir/reference/write_synthesis_manifest.md).

## Examples

``` r
ms <- llegir_example_moduleset()
packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
interp <- synthesize_interpretation(packet, desc, mock_backend())
build_synthesis_manifest(list(m1 = interp), desc)
#> $n_modules
#> [1] 1
#> 
#> $n_synthesized
#> [1] 1
#> 
#> $n_flagged
#> [1] 0
#> 
#> $prompt_template_version
#> [1] "0.4"
#> 
#> $render_template_version
#> [1] "0.1"
#> 
#> $models
#> $models[[1]]
#> [1] "mock"
#> 
#> 
#> $dataset_description
#> $dataset_description$species
#> [1] "human"
#> 
#> $dataset_description$tissue
#> [1] "CSF"
#> 
#> $dataset_description$cell_compartment
#> [1] "myeloid"
#> 
#> $dataset_description$assay
#> [1] "scRNA-seq"
#> 
#> $dataset_description$conditions
#> character(0)
#> 
#> $dataset_description$notes
#> [1] NA
#> 
#> $dataset_description$module_method
#> [1] NA
#> 
#> 
#> $created_at
#> [1] "2026-08-04T18:45:00+0200"
#> 
```
