# Materialize every fragment's live plots to PNG files

The graphical sibling of
[`write_fragment_tables()`](https://smorabit.github.io/llegir/reference/write_fragment_tables.md):
renders each fragment's live `plot_obj` to
`<figures_dir>/<module_id>/<fragment_id>__<plot_id>.png` and records
that path back onto the spec as `image_path`, so a report rendered from
a re-read packet (where `plot_obj` has already been stripped; see
[`attach_plots()`](https://smorabit.github.io/llegir/reference/attach_plots.md))
can still embed the figure. Fragments with no plots are skipped.

## Usage

``` r
write_fragment_figures(packet, figures_dir)
```

## Arguments

- packet:

  An evidence packet, as returned by
  [`build_evidence_packet()`](https://smorabit.github.io/llegir/reference/build_evidence_packet.md).

- figures_dir:

  Output directory.

## Value

`packet`, with `image_path` filled in on every rendered plot spec.
