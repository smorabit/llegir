## dataset_description: the REQUIRED biological context prepended to every
## synthesis prompt (docs/milestone_2.md task 1) so the model interprets a
## module in the right frame (e.g. CSF myeloid vs. tumor changes what a given
## program means, and disambiguates gene function like microglia vs. macrophage).
## A missing/empty description is a hard error, not a default.

#' Construct a dataset description
#'
#' The required biological context prepended to every synthesis prompt (see
#' [render_dataset_description()], [build_user_prompt()]) so the model
#' interprets a module in the right frame -- e.g. CSF myeloid vs. tumor
#' changes what a given program means, and disambiguates gene function like
#' microglia vs. macrophage.
#'
#' @param species Species, e.g. `'human'`.
#' @param tissue Tissue, e.g. `'CSF'`.
#' @param cell_compartment Cell compartment / lineage, e.g. `'myeloid'`.
#' @param assay Assay, e.g. `'scRNA-seq'`.
#' @param conditions Optional character vector of conditions/groups present
#'   in the dataset.
#' @param notes Optional free-text notes.
#' @return A `dataset_description` object.
#' @examples
#' dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq', conditions = c('MS', 'control'))
#' @export
dataset_description <- function(species, tissue, cell_compartment, assay,
                                 conditions = character(0), notes = NA_character_){
    desc <- list(
        species = species,
        tissue = tissue,
        cell_compartment = cell_compartment,
        assay = assay,
        conditions = conditions,
        notes = notes
    )
    structure(desc, class = 'dataset_description')
}

#' Validate a dataset description
#'
#' Hard-errors on a missing/empty required field (`species`, `tissue`,
#' `cell_compartment`, `assay`); `conditions`/`notes` may be empty, since not
#' every dataset has discrete conditions. A missing/empty description is a
#' hard error, not a default, since it's required biological context for synthesis.
#'
#' @param desc A `dataset_description` object.
#' @return Invisibly `TRUE` if valid; otherwise throws.
#' @examples
#' validate_dataset_description(dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq'))
#' @export
validate_dataset_description <- function(desc){
    if (!inherits(desc, 'dataset_description')) stop('object is not class dataset_description')
    required <- c('species', 'tissue', 'cell_compartment', 'assay')
    for (field in required) {
        value <- desc[[field]]
        if (is.null(value) || !is.character(value) || length(value) != 1 || is.na(value) || !nzchar(trimws(value))) {
            stop('dataset_description$', field, ' is required and must be a non-empty string')
        }
    }
    invisible(TRUE)
}

#' Render a dataset description as a compact text block
#'
#' Prepended to the synthesis prompt; see [build_user_prompt()].
#'
#' @param desc A `dataset_description` object.
#' @return A single character string.
#' @examples
#' cat(render_dataset_description(dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')))
#' @export
render_dataset_description <- function(desc){
    validate_dataset_description(desc)
    lines <- c(
        'Dataset context:',
        paste0('- species: ', desc$species),
        paste0('- tissue: ', desc$tissue),
        paste0('- cell compartment: ', desc$cell_compartment),
        paste0('- assay: ', desc$assay)
    )
    if (length(desc$conditions) > 0) {
        lines <- c(lines, paste0('- conditions: ', paste(desc$conditions, collapse = ', ')))
    }
    if (!is.null(desc$notes) && !is.na(desc$notes) && nzchar(trimws(desc$notes))) {
        lines <- c(lines, paste0('- notes: ', desc$notes))
    }
    paste(lines, collapse = '\n')
}
