## paragraph renderer (docs/milestone_2.md task 5): a deterministic, versioned
## template that reads only interpretation-object fields. No model call here
## -- the same interpretation object always renders to the same paragraph.
## Also builds the review_queue summary and the run-level manifest
## (docs/milestone_2.md tasks 6-7).

#' Render template version
#'
#' Bumped whenever [render_paragraph()]'s template changes; recorded in the
#' run-level manifest ([build_synthesis_manifest()]).
#'
#' @export
RENDER_TEMPLATE_VERSION <- '0.1'

.na_or_empty <- function(x) is.null(x) || (length(x) == 1 && is.na(x))

#' Render an interpretation as a paragraph
#'
#' A deterministic, versioned template that reads only `interpretation`
#' object fields -- no model call here, so the same interpretation object
#' always renders to the same paragraph.
#'
#' @param interp An `interpretation` object.
#' @return A single character string (Markdown).
#' @examples
#' ms <- sentit_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = hub_genes_tool, params = list())))
#' desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
#' interp <- synthesize_interpretation(packet, desc, mock_backend())
#' cat(render_paragraph(interp))
#' @export
render_paragraph <- function(interp){
    validate_interpretation(interp)
    lines <- c(
        sprintf('**%s** (%s)', interp$proposed_label, interp$module_id),
        '',
        interp$one_line_summary,
        '',
        sprintf('Dominant biology: %s', interp$dominant_biology)
    )

    if (!.na_or_empty(interp$cell_state)) {
        lines <- c(lines, sprintf('Primarily expressed in: %s', interp$cell_state))
    }
    if (!.na_or_empty(interp$condition_dynamics)) {
        lines <- c(lines, sprintf('Condition dynamics: %s', interp$condition_dynamics))
    }

    if (length(interp$supporting_claims) > 0) {
        claim_lines <- vapply(interp$supporting_claims, function(claim){
            sprintf('- %s (%s; direction: %s)', claim$claim, paste(claim$fragment_ids, collapse = ', '), claim$direction)
        }, character(1))
        lines <- c(lines, '', 'Supporting evidence:', claim_lines)
    }

    if (length(interp$metadata_associations) > 0) {
        assoc_lines <- vapply(interp$metadata_associations, function(assoc){
            sprintf('- %s: %s (%s)', assoc$variable, assoc$summary, assoc$fragment_id)
        }, character(1))
        lines <- c(lines, '', 'Metadata associations:', assoc_lines)
    }

    lines <- c(
        lines, '',
        sprintf('Confidence: %.2f -- %s', interp$confidence$score, interp$confidence$rationale)
    )
    if (length(interp$flags) > 0) {
        lines <- c(lines, sprintf('Flags: %s', paste(unlist(interp$flags), collapse = ', ')))
    }

    paste(lines, collapse = '\n')
}

# short human-readable explanations for the review queue's `reason` column;
# every entry in .interpretation_flags (R/interpretation.R) must have one
.flag_reasons <- list(
    insufficient_evidence = 'deterministic evidence signals are weak (low effect size / few significant terms)',
    needs_human_review = 'model confidence and deterministic evidence disagree, or a citation issue was found',
    tool_conflict = 'evidence tools disagree on whether the module shows a real signal',
    possible_artifact = 'hub genes are dominated by stress/dissociation markers',
    label_low_specificity = 'the proposed label was flagged as too generic'
)

#' Describe an interpretation's flags in human-readable form
#'
#' @param flags A character vector (or list) of flags from the
#'   `.interpretation_flags` controlled vocabulary.
#' @return A single character string (flags' explanations joined with `'; '`),
#'   or `''` if `flags` is empty.
#' @examples
#' describe_flags(list('insufficient_evidence', 'tool_conflict'))
#' @export
describe_flags <- function(flags){
    flags <- unlist(flags)
    if (length(flags) == 0) return('')
    paste(unlist(.flag_reasons[flags]), collapse = '; ')
}

#' Build the review queue from a batch of interpretations
#'
#' Only flagged interpretations ([needs_review()]) -- this is a queue for a
#' human to triage, not a full summary of every module. Sorted
#' lowest-confidence first.
#'
#' @param interps A named list of interpretations, e.g. the return value of
#'   [run_synthesis_orchestrator()].
#' @return A data.frame: `module_id`, `confidence`, `flags`, `reason`.
#' @examples
#' ms <- sentit_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = hub_genes_tool, params = list())))
#' desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
#' interp <- synthesize_interpretation(packet, desc, mock_backend())
#' build_review_queue(list(m1 = interp))
#' @export
build_review_queue <- function(interps){
    flagged <- Filter(function(i) !is.null(i) && needs_review(i), interps)
    if (length(flagged) == 0) {
        return(data.frame(module_id = character(0), confidence = numeric(0), flags = character(0), reason = character(0)))
    }
    rows <- lapply(flagged, function(i){
        data.frame(
            module_id = i$module_id,
            confidence = round(i$confidence$score, 3),
            flags = paste(unlist(i$flags), collapse = ';'),
            reason = describe_flags(i$flags),
            stringsAsFactors = FALSE
        )
    })
    df <- do.call(rbind, rows)
    df[order(df$confidence), ]
}

#' Write the review queue to a TSV file
#'
#' @param interps A named list of interpretations; see [build_review_queue()].
#' @param path Output file path.
#' @return Invisibly, `path`.
#' @export
write_review_queue <- function(interps, path){
    df <- build_review_queue(interps)
    utils::write.table(df, path, sep = '\t', row.names = FALSE, quote = FALSE)
    invisible(path)
}

#' Build a run-level synthesis manifest
#'
#' Complements the per-interpretation provenance already attached by
#' [synthesize_interpretation()] with counts and the template versions used
#' to produce this batch of outputs.
#'
#' @param interps A named list of interpretations; see [build_review_queue()].
#' @param desc The `dataset_description` used for this synthesis run.
#' @param prompt_template_version Prompt template version to record.
#' @param render_template_version Render template version to record.
#' @return A list, suitable for [write_synthesis_manifest()].
#' @examples
#' ms <- sentit_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = hub_genes_tool, params = list())))
#' desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
#' interp <- synthesize_interpretation(packet, desc, mock_backend())
#' build_synthesis_manifest(list(m1 = interp), desc)
#' @export
build_synthesis_manifest <- function(interps, desc, prompt_template_version = PROMPT_TEMPLATE_VERSION,
                                      render_template_version = RENDER_TEMPLATE_VERSION){
    ok <- Filter(Negate(is.null), interps)
    models <- unique(vapply(ok, function(i) i$provenance$model, character(1)))
    list(
        n_modules = length(interps),
        n_synthesized = length(ok),
        n_flagged = sum(vapply(ok, needs_review, logical(1))),
        prompt_template_version = prompt_template_version,
        render_template_version = render_template_version,
        models = if (length(models) == 0) list() else as.list(models),
        dataset_description = unclass(desc),
        created_at = format(Sys.time(), '%Y-%m-%dT%H:%M:%S%z')
    )
}

#' Write a synthesis manifest to a JSON file
#'
#' @param manifest A manifest list, as built by [build_synthesis_manifest()].
#' @param path Output file path.
#' @return Invisibly, `path`.
#' @export
write_synthesis_manifest <- function(manifest, path){
    writeLines(jsonlite::toJSON(manifest, auto_unbox = TRUE, na = 'null', pretty = TRUE), path)
    invisible(path)
}
