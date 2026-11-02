# Materialize a dataset context's live plots to PNG files

The dataset-level sibling of
[`write_fragment_figures()`](https://smorabit.github.io/llegir/reference/write_fragment_figures.md):
renders each `dataset_fragment`'s live `plot_obj` to
`<figures_dir>/dataset/<fragment_id>__<plot_id>.png` and records that
path back onto the spec as `image_path`, so a report rendered after the
live `plot_obj` has been stripped can still embed the figure. A spec's
own `width`/`height`/`dpi` (see
[`attach_plots()`](https://smorabit.github.io/llegir/reference/attach_plots.md))
are honored when set; otherwise `save_plot_to_png()`'s `7`/`4`/`150`
defaults apply. Fragments with no plots are skipped.

## Usage

``` r
write_dataset_figures(dataset_context, figures_dir)
```

## Arguments

- dataset_context:

  A dataset context, as returned by
  [`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md)
  /
  [`run_dataset_context()`](https://smorabit.github.io/llegir/reference/run_dataset_context.md).

- figures_dir:

  Output directory.

## Value

`dataset_context`, with `image_path` filled in on every rendered plot
spec.
