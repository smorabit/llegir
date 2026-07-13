## paragraph renderer (docs/milestone_2.md task 5): a deterministic, versioned
## template that reads only interpretation-object fields. No model call here
## -- the same interpretation object always renders to the same paragraph.
## Also builds the review_queue summary and the run-level manifest
## (docs/milestone_2.md tasks 6-7).

RENDER_TEMPLATE_VERSION <- '0.1'

.na_or_empty <- function(x) is.null(x) || (length(x) == 1 && is.na(x))

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

describe_flags <- function(flags){
    flags <- unlist(flags)
    if (length(flags) == 0) return('')
    paste(unlist(.flag_reasons[flags]), collapse = '; ')
}

# only flagged interpretations -- this is a queue for a human to triage, not
# a full summary of every module. Sorted lowest-confidence first.
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

write_review_queue <- function(interps, path){
    df <- build_review_queue(interps)
    utils::write.table(df, path, sep = '\t', row.names = FALSE, quote = FALSE)
    invisible(path)
}

# run-level summary (docs/milestone_2.md task 6): complements the per-interpretation
# provenance already attached by synthesize_interpretation() (R/synthesis.R)
# with counts and the template versions used to produce this batch of outputs
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

write_synthesis_manifest <- function(manifest, path){
    writeLines(jsonlite::toJSON(manifest, auto_unbox = TRUE, na = 'null', pretty = TRUE), path)
    invisible(path)
}
