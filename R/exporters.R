## HTML report exporter: compiles a batch of interpretations and their paired
## evidence packets into a single self-contained report via the packaged
## inst/templates/summary_report.Rmd template.

#' Write a combined interpretation + evidence HTML report
#'
#' Renders every module's synthesized interpretation alongside the raw
#' deterministic evidence it was drawn from into one human-readable HTML file.
#' Modules are paired by matching the names of `interps` and `packets`.
#'
#' @param interps A named list of `interpretation` objects, keyed by module id
#'   (e.g. the return value of [run_synthesis_orchestrator()]).
#' @param packets A named list of evidence packets, keyed by module id (e.g. the
#'   return value of [run_orchestrator()]).
#' @param desc The `dataset_description` used for this synthesis run.
#' @param output_file Destination HTML path. Default `'output/report.html'`.
#' @param quiet Suppress the pandoc/knitr progress output. Default `TRUE`.
#' @return The rendered file path, invisibly.
#' @export
write_interpretation_report <- function(interps, packets, desc,
                                        output_file = 'output/report.html',
                                        quiet = TRUE){
    if (!is.list(interps)) stop('interps must be a list of interpretation objects')
    if (!is.list(packets)) stop('packets must be a list of evidence packets')

    template <- system.file('templates/summary_report.Rmd', package = 'llegir')
    if (!nzchar(template)) stop('could not locate summary_report.Rmd in the installed llegir package')

    # guarantee the output directory exists, then resolve it to an absolute
    # path: render() otherwise resolves a relative output path against the
    # template's own (installed-package) directory, not the caller's cwd
    output_dir <- dirname(output_file)
    dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
    output_dir <- normalizePath(output_dir, mustWork = TRUE)

    rmarkdown::render(
        input = template,
        output_file = basename(output_file),
        output_dir = output_dir,
        params = list(interps = interps, packets = packets, desc = desc),
        quiet = quiet,
        envir = new.env(parent = globalenv())
    )
    invisible(file.path(output_dir, basename(output_file)))
}
