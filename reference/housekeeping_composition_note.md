# Housekeeping-composition note for a packet's hub-gene list

The fraction of a module's top hub genes that are cytoplasmic ribosomal
(`RPS*`/`RPL*`) or mitochondrially encoded (`MT-*`). Surfaced to
synthesis via
[`render_packet_compact()`](https://smorabit.github.io/llegir/reference/render_packet_compact.md)
as a short note appended to the `ranked_genes` fragment, so a module
whose hub list is part housekeeping reads as " AND ribosomal-high"
instead of having the housekeeping genes quietly dilute the biological
call. Deterministic, packet-only, and – unlike `.artifact_flagged()`'s
IEG pattern – never sets a flag on its own.

## Usage

``` r
housekeeping_composition_note(packet, top_n = 20, min_fraction = 0.15)
```

## Arguments

- packet:

  An evidence packet, as built by
  [`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md).

- top_n:

  Number of top hub genes to inspect. Default `20`.

- min_fraction:

  Fraction a family must reach to be worth noting. Default `0.15`.

## Value

A single-string note, or `NULL` when neither family clears
`min_fraction` or the packet carries no `ranked_genes` fragment.

## Examples

``` r
ms <- llegir_example_moduleset()
packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
housekeeping_composition_note(packet)
#> NULL
```
