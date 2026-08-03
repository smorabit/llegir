# Read an evidence packet from a JSON file

Reconstructs a packet (and each fragment's S3 class) from a JSON file
written by
[`write_evidence_packet()`](https://smorabit.github.io/llegir/reference/write_evidence_packet.md).

## Usage

``` r
read_evidence_packet(path)
```

## Arguments

- path:

  Path to a packet JSON file.

## Value

An evidence packet, as returned by
[`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md).
