# Import a user-supplied result table as a dataset fragment

Dataset-scope analog of
[`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md):
lets a user inject an already-computed compositional /
differential-abundance result as a validated
[`dataset_fragment()`](https://smorabit.github.io/llegir/reference/dataset_fragment.md)
instead of computing it via a core dataset tool (e.g.
[`dataset_composition_tool()`](https://smorabit.github.io/llegir/reference/dataset_composition_tool.md)).
`provenance$source` is set to `'user_supplied'`, same distinction
[`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md)
makes for evidence fragments.

## Usage

``` r
import_dataset_fragment(
  type,
  result,
  fragment_id = NULL,
  tool_id = "import_dataset_fragment",
  params = list(),
  source_file = NULL
)
```

## Arguments

- type:

  One of the supported `dataset_fragment` types: currently
  `'composition_summary'`.

- result:

  A tidy data.frame with the user's result table.

- fragment_id:

  Unique id within the `dataset_context`. Defaults to
  `paste0('imported::', type)`.

- tool_id:

  Tool id recorded in provenance. Default `'import_dataset_fragment'`.

- params:

  Named list of column-name overrides (e.g. `group_col`, `effect_col`,
  `significance_col`, `alpha`), since a user-supplied table won't share
  this repo's exact column names.

- source_file:

  Optional path to the file `result` was originally read from. Recorded
  in `provenance$params$source_file`, and content-hashed into
  `provenance$input_hashes$source_file` if the file still exists.

## Value

A `dataset_fragment` object.
