# Assemble and hash a module's evidence packet

Validates every fragment, then hashes the content (fragments minus
timestamps) so the hash is a reproducibility fingerprint, not just a
run-to-run-unique id.

## Usage

``` r
build_evidence_packet(
  module_id,
  fragments,
  input_hash = NA_character_,
  schema_version = "0.1",
  skipped = list()
)
```

## Arguments

- module_id:

  The module this packet describes.

- fragments:

  A list of `evidence_fragment` objects.

- input_hash:

  A content hash identifying the source dataset (e.g. of the backing
  `.rds`), for provenance.

- schema_version:

  Schema version tag. Default `'0.1'`.

- skipped:

  A list of `list(tool_id, reason)` entries for tools that were skipped
  because a required `ModuleSet`
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)
  was unmet (see
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md)),
  recorded on `provenance$skipped` for an audit trail of what didn't run
  and why. Default [`list()`](https://rdrr.io/r/base/list.html).

## Value

A list with `module_id`, `fragments`, `packet_hash`, `schema_version`,
and `provenance`.
