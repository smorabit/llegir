# Import a user-supplied result table as an evidence fragment

Lets a user inject an already-computed result table (DMEs, GO
enrichment, etc.) as a validated
[`evidence_fragment()`](https://smorabit.github.io/llegir/reference/evidence_fragment.md)
instead of recomputing it via a core tool. `provenance$source` is set to
`'user_supplied'` so faithfulness/reproducibility checks can distinguish
these from tool-computed fragments; the synthesis layer treats both
identically.

## Usage

``` r
import_fragment(
  module_id,
  type,
  result,
  fragment_id = NULL,
  tool_id = "import_fragment",
  params = list(),
  source_file = NULL
)
```

## Arguments

- module_id:

  The module this fragment describes.

- type:

  One of the supported fragment types: `'geneset_enrichment'`,
  `'categorical_association'`.

- result:

  A tidy data.frame with the user's result table.

- fragment_id:

  Unique id within the packet. Defaults to `paste0('imported::', type)`.

- tool_id:

  Tool id recorded in provenance. Default `'import_fragment'`.

- params:

  Named list of column-name overrides (e.g. `term_col`,
  `significance_col`, `effect_col`) and other normalizer options (e.g.
  `n_top`), since a user-supplied table won't share this package's exact
  column names.

- source_file:

  Optional path to the file `result` was originally read from (e.g. a
  [`FindMarkers()`](https://satijalab.org/seurat/reference/FindMarkers.html)
  CSV export). Recorded in `provenance$params$source_file`, and
  content-hashed into `provenance$input_hashes$source_file` if the file
  still exists, so the import is traceable back to its origin.

## Value

An `evidence_fragment` object.
