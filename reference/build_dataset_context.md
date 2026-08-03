# Assemble and hash a dataset context

Validates every fragment, then hashes the content (fragments minus
timestamps) so the hash is a reproducibility fingerprint, not just a
run-to-run-unique id. The once-per-dataset analog of
[`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md)
– computed once and injected into every module's synthesis prompt, never
entering fusion or faithfulness.

## Usage

``` r
build_dataset_context(
  dataset_fragments,
  input_hash = NA_character_,
  schema_version = "0.1",
  skipped = list()
)
```

## Arguments

- dataset_fragments:

  A list of `dataset_fragment` objects.

- input_hash:

  A content hash identifying the source dataset (e.g. of the backing
  `.rds`), for provenance.

- schema_version:

  Schema version tag. Default `'0.1'`.

- skipped:

  A list of `list(tool_id, reason)` entries for tools that were skipped
  because a required `ModuleSet`
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)
  was unmet, recorded on `provenance$skipped` for an audit trail.
  Default [`list()`](https://rdrr.io/r/base/list.html).

## Value

A list with `dataset_fragments`, `context_hash`, `schema_version`, and
`provenance`.
