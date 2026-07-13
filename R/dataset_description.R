## dataset_description: the REQUIRED biological context prepended to every
## synthesis prompt (docs/milestone_2.md task 1) so the model interprets a
## module in the right frame (e.g. CSF myeloid vs. tumor changes what a given
## program means, and disambiguates gene function like microglia vs. macrophage).
## A missing/empty description is a hard error, not a default.

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

# hard-errors on missing/empty required fields; `conditions`/`notes` may be
# empty (not every dataset has discrete conditions), but the rest must be set
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

# compact text block prepended to the synthesis prompt (R/prompt.R)
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
