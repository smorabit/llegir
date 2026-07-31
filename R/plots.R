## plots slot: shared machinery for attaching pre-rendered figures to an
## evidence_fragment or dataset_fragment. llegir ships no plotting functions
## and gains none here -- it is strictly an asset container. docs/schemas.md,
## docs/milestones/milestone_plot_ingestion.md

# graphics classes the report can render; patchwork/cowplot compositions
# inherit from ggplot/gtable, so they are covered without enumerating add-ons
.plot_classes <- c(
    'ggplot', 'ggplot2::ggplot', 'grob', 'gTree', 'gtable',
    'patchwork', 'recordedplot', 'trellis'
)

# drop each spec's live plot_obj before a fragment reaches jsonlite/digest; a
# raw grob holds environments and external pointers and must never enter
# either, or the content hash stops being reproducible across sessions
.strip_plot_objs <- function(frag){
    if (is.null(frag$plots) || length(frag$plots) == 0) return(frag)
    frag$plots <- lapply(frag$plots, function(spec) {
        spec$plot_obj <- NULL
        spec
    })
    frag
}

# NULL/empty is valid (the backward-compatibility guarantee); otherwise plots
# must be a named list of specs, each carrying either a live plot_obj or a
# stripped image_path. inherits() is the only inspection ever done on
# plot_obj -- it reads the class attribute without evaluating, printing, or
# coercing the object
.validate_plots <- function(plots, context){
    if (is.null(plots) || length(plots) == 0) return(invisible(TRUE))
    plot_names <- names(plots)
    if (is.null(plot_names) || any(plot_names == '')) {
        stop(context, ': plots must be a named list')
    }
    for (plot_id in plot_names) {
        spec <- plots[[plot_id]]
        if (!is.list(spec)) stop(context, ': plot \'', plot_id, '\' must be a list')
        has_obj <- !is.null(spec$plot_obj)
        has_img <- is.character(spec$image_path) && length(spec$image_path) == 1
        if (!has_obj && !has_img) {
            stop(context, ': plot \'', plot_id, '\' must carry either plot_obj or image_path')
        }
        if (has_obj && !inherits(spec$plot_obj, .plot_classes)) {
            stop(context, ': plot \'', plot_id, '\' plot_obj is not a supported graphics object')
        }
        if (!is.null(spec$legend) && (!is.character(spec$legend) || length(spec$legend) != 1)) {
            stop(context, ': plot \'', plot_id, '\' legend must be a single string')
        }
        if (!is.null(spec$placement) && !(spec$placement %in% c('above', 'below'))) {
            stop(context, ': plot \'', plot_id, '\' placement must be \'above\' or \'below\'')
        }
    }
    invisible(TRUE)
}

# the one device helper shared by write_fragment_figures() and the report
# template (Part 3); dispatches on p's class since a ggplot needs its own
# device pipeline, a recordedplot replays onto the current device, and
# everything else (grob/gTree/gtable/patchwork) draws directly with grid
save_plot_to_png <- function(p, path, width = 7, height = 4, dpi = 150){
    if (inherits(p, c('ggplot', 'ggplot2::ggplot'))) {
        if (!requireNamespace('ggplot2', quietly = TRUE)) {
            stop('save_plot_to_png: ggplot2 is required to render a ggplot object but is not installed')
        }
        ggplot2::ggsave(filename = path, plot = p, width = width, height = height, dpi = dpi)
        return(invisible(path))
    }
    grDevices::png(path, width = width, height = height, units = 'in', res = dpi)
    on.exit(grDevices::dev.off())
    if (inherits(p, 'recordedplot')) {
        grDevices::replayPlot(p)
    } else {
        grid::grid.newpage()
        grid::grid.draw(p)
    }
    invisible(path)
}

#' Attach plots to an evidence or dataset fragment
#'
#' Decorates an existing fragment with one or more pre-rendered figures
#' without rebuilding it, then re-validates so a malformed spec fails at
#' attach time rather than deep in the report. `llegir` never generates or
#' inspects the figures themselves -- `plot_obj` is an opaque payload carried
#' through to the report.
#'
#' @param frag An `evidence_fragment` or `dataset_fragment` object.
#' @param plots A named list of plot specs. Each spec is a list with either a
#'   live `plot_obj` (a `ggplot`/`grob`/`gtable`/`patchwork`/`recordedplot`/
#'   `trellis` object) or a character `image_path`, plus optional `legend`
#'   (a single string) and `placement` (`'above'` or `'below'`, default
#'   `'below'`).
#' @return `frag` with `plots` merged in.
#' @export
attach_plots <- function(frag, plots){
    frag$plots <- c(frag$plots, plots)
    if (inherits(frag, 'evidence_fragment')) {
        validate_evidence_fragment(frag)
    } else if (inherits(frag, 'dataset_fragment')) {
        validate_dataset_fragment(frag)
    } else {
        stop('attach_plots: frag must be an evidence_fragment or dataset_fragment')
    }
    frag
}
