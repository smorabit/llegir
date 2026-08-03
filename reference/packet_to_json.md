# Serialize an evidence packet to JSON

Serialize an evidence packet to JSON

## Usage

``` r
packet_to_json(packet, pretty = TRUE)
```

## Arguments

- packet:

  An evidence packet, as returned by
  [`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md).

- pretty:

  Pretty-print the JSON. Default `TRUE`.

## Value

A JSON string (a `jsonlite::json` scalar).
