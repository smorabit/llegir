# Write every fragment's full result table alongside a packet

Writes each fragment's full result table to
`<tables_dir>/<module_id>/<fragment_id>.tsv`, so a human can audit any
DME table / enrichment table / overlap directly.

## Usage

``` r
write_fragment_tables(packet, tables_dir)
```

## Arguments

- packet:

  An evidence packet, as returned by
  [`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md).

- tables_dir:

  Output directory.

## Value

`tables_dir`, invisibly.
