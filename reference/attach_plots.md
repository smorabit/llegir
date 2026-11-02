# Attach plots to an evidence or dataset fragment

Decorates an existing fragment with one or more pre-rendered figures
without rebuilding it, then re-validates so a malformed spec fails at
attach time rather than deep in the report. `llegir` never generates or
inspects the figures themselves – `plot_obj` is an opaque payload
carried through to the report.

## Usage

``` r
attach_plots(frag, plots)
```

## Arguments

- frag:

  An `evidence_fragment` or `dataset_fragment` object.

- plots:

  A named list of plot specs. Each spec is a list with either a live
  `plot_obj` (a `ggplot`/`grob`/`gtable`/`patchwork`/`recordedplot`/
  `trellis` object) or a character `image_path`, plus optional `legend`
  (a single string), `placement` (`'above'` or `'below'`, default
  `'below'`), and `width`/`height`/`dpi` (single positive numbers,
  inches/inches/pixels-per-inch) honored by
  [`write_fragment_figures()`](https://smorabit.github.io/llegir/reference/write_fragment_figures.md)
  /
  [`write_dataset_figures()`](https://smorabit.github.io/llegir/reference/write_dataset_figures.md)
  when rendering a live `plot_obj` to PNG – default `7`/`4`/`150` (see
  `save_plot_to_png()`) when omitted.

## Value

`frag` with `plots` merged in.
