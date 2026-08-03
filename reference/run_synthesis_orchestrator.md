# Run synthesis over a batch of evidence packets

Runs
[`synthesize_module()`](https://smorabit.github.io/llegir/reference/synthesize_module.md)
independently for each packet in `packets`, writing per-module
interpretation JSON and rendered Markdown paragraphs (via
[`render_paragraph()`](https://smorabit.github.io/llegir/reference/render_paragraph.md))
to `output_dir`, plus a run-level `review_queue.tsv`
([`write_review_queue()`](https://smorabit.github.io/llegir/reference/write_review_queue.md))
and `manifest.json`
([`write_synthesis_manifest()`](https://smorabit.github.io/llegir/reference/write_synthesis_manifest.md)).
One module's synthesis failure is warned and recorded as `NULL`,
mirroring
[`run_orchestrator()`](https://smorabit.github.io/llegir/reference/run_orchestrator.md)'s
failure isolation.

## Usage

``` r
run_synthesis_orchestrator(
  packets,
  desc,
  backend,
  output_dir,
  temperature = 0,
  seed = NA_real_,
  prompt_template_version = PROMPT_TEMPLATE_VERSION,
  schema_path = system.file("schemas", "interpretation.schema.json", package = "llegir"),
  dataset_context = NULL
)
```

## Arguments

- packets:

  A named list of evidence packets, e.g. the return value of
  [`run_orchestrator()`](https://smorabit.github.io/llegir/reference/run_orchestrator.md).

- desc:

  A `dataset_description`; see
  [`dataset_description()`](https://smorabit.github.io/llegir/reference/dataset_description.md).

- backend:

  A synthesis backend function; see
  [`mock_backend()`](https://smorabit.github.io/llegir/reference/mock_backend.md),
  [`ellmer_backend()`](https://smorabit.github.io/llegir/reference/ellmer_backend.md),
  [`resolve_backend()`](https://smorabit.github.io/llegir/reference/resolve_backend.md).

- output_dir:

  Directory to write per-module interpretations, paragraphs,
  `review_queue.tsv`, and `manifest.json`.

- temperature:

  Sampling temperature passed to the backend.

- seed:

  Optional seed, recorded on each interpretation's provenance.

- prompt_template_version:

  Prompt template version to record on each interpretation's provenance.

- schema_path:

  Path to the interpretation JSON schema; defaults to the schema shipped
  with the package.

- dataset_context:

  An optional dataset context, as built by
  [`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md)
  /
  [`run_dataset_context()`](https://smorabit.github.io/llegir/reference/run_dataset_context.md).
  Computed once and passed to every module's
  [`synthesize_module()`](https://smorabit.github.io/llegir/reference/synthesize_module.md)
  call, exactly like `desc`. `NULL` (default) omits the DATASET CONTEXT
  block.

## Value

Invisibly, a named list of interpretation objects (one per module;
`NULL` for any module whose synthesis failed).

## Examples

``` r
ms <- llegir_example_moduleset()
packets <- run_orchestrator(ms, list(list(fn = top_genes_tool, params = list())), output_dir = tempfile())
desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
run_synthesis_orchestrator(packets, desc, mock_backend(), output_dir = tempfile())
```
