## faithfulness auto-check (docs/milestone_2.md task 3): every fragment_id
## cited in supporting_claims must exist in the module's evidence packet, and
## a supporting_claims direction must match the direction actually reported by
## the fragment it cites. Significance wording ("significant", "enriched",
## "over-represented") must also be backed by a cited fragment that actually
## passes alpha. A mismatch is a hard failure, not a warning.

# negated uses ("not significant", "no significant enrichment", "lacks
# enrichment") are the honest phrasing the prompt asks for, so they are
# stripped before looking for an affirmative significance claim
.significance_negation <- '\\b(not|no|non|without|lacks?|lacking|absent)\\b[- ]+(\\w+[- ]+){0,3}?(significan|enrich|over-?represent)\\w*([- ]+(significan|enrich|over-?represent)\\w*)*'
.significance_wording <- '\\bsignifican(t|tly|ce)\\b|\\benrich(ed|ment)\\b|\\bover-?represent'
.enrichment_wording <- '\\benrich(ed|ment)\\b|\\bover-?represent'

.claims_significance <- function(text, pattern = .significance_wording){
    stripped <- gsub(.significance_negation, ' ', tolower(text), perl = TRUE)
    grepl(pattern, stripped, perl = TRUE)
}

.fragment_passes <- function(frag, alpha){
    !is.null(frag$significance) && !is.na(frag$significance) && frag$significance < alpha
}

# fragments a sentence of free prose refers to: by fragment_id (underscores or
# spaces, case-insensitive), falling back to every geneset_enrichment-type
# fragment when the sentence talks about enrichment without naming one
.fragments_referenced <- function(sentence, fragments){
    sentence <- tolower(sentence)
    named <- Filter(function(f){
        fid <- tolower(f$fragment_id)
        grepl(fid, sentence, fixed = TRUE) || grepl(gsub('_', ' ', fid), sentence, fixed = TRUE)
    }, fragments)
    if (length(named) > 0) return(named)
    if (.claims_significance(sentence, .enrichment_wording)) {
        return(Filter(function(f) identical(f$type, 'geneset_enrichment'), fragments))
    }
    list()
}

#' Check citation faithfulness of an interpretation against its packet
#'
#' Every fragment_id cited in `supporting_claims` must exist in the module's
#' evidence packet, and a `supporting_claims` entry's `direction` must match
#' the direction actually reported by the fragment(s) it cites. Significance
#' wording ("significant", "enriched", "over-represented"; negated uses such
#' as "not significant" are allowed) must be backed by a fragment whose
#' `significance` is below `alpha`:
#' * in a `supporting_claims` entry, when none of its cited fragments passes
#'   `alpha` and at least one of them is a tested result (non-`NA`
#'   significance, or a `geneset_enrichment` fragment) -- so a claim that the
#'   hub genes are "enriched for ribosomal proteins", citing only a
#'   `ranked_genes` fragment, is not flagged;
#' * in each sentence of the `interpretation` text, when the fragments that
#'   sentence names (by `fragment_id`, or every `geneset_enrichment` fragment
#'   when it speaks of enrichment without naming one) include none that passes
#'   `alpha`.
#'
#' Pure and non-throwing; see [assert_faithfulness()] for the hard-rejecting
#' variant.
#'
#' @param interp An `interpretation` object.
#' @param packet The evidence packet `interp` was synthesized from.
#' @param alpha Significance threshold for the wording check. Default 0.05.
#' @return A list of violation records (empty if faithful); each record is a
#'   list with `location` (`'supporting_claims'` or `'interpretation'`),
#'   `index` (claim or sentence number), `fragment_id`, `issue`
#'   (`'missing_fragment'`, `'direction_mismatch'` or
#'   `'unsupported_significance'`), and, for `'direction_mismatch'`,
#'   `claim_direction`/`fragment_direction`.
#' @examples
#' ms <- llegir_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
#' desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
#' interp <- synthesize_interpretation(packet, desc, mock_backend())
#' check_faithfulness(interp, packet)
#' @export
check_faithfulness <- function(interp, packet, alpha = 0.05){
    frag_by_id <- stats::setNames(packet$fragments, vapply(packet$fragments, function(f) f$fragment_id, character(1)))
    violations <- list()

    for (i in seq_along(interp$supporting_claims)) {
        claim <- interp$supporting_claims[[i]]
        for (fid in claim$fragment_ids) {
            if (!(fid %in% names(frag_by_id))) {
                violations[[length(violations) + 1]] <- list(
                    location = 'supporting_claims', index = i, fragment_id = fid, issue = 'missing_fragment'
                )
            } else if (!identical(claim$direction, frag_by_id[[fid]]$direction)) {
                violations[[length(violations) + 1]] <- list(
                    location = 'supporting_claims', index = i, fragment_id = fid, issue = 'direction_mismatch',
                    claim_direction = claim$direction, fragment_direction = frag_by_id[[fid]]$direction
                )
            }
        }

        cited <- frag_by_id[intersect(unlist(claim$fragment_ids), names(frag_by_id))]
        is_tested <- vapply(cited, function(f){
            identical(f$type, 'geneset_enrichment') || (!is.null(f$significance) && !is.na(f$significance))
        }, logical(1))
        if (.claims_significance(claim$claim) && any(is_tested) &&
            !any(vapply(cited, .fragment_passes, logical(1), alpha = alpha))) {
            violations[[length(violations) + 1]] <- list(
                location = 'supporting_claims', index = i,
                fragment_id = paste(names(cited), collapse = ','), issue = 'unsupported_significance'
            )
        }
    }

    sentences <- unlist(strsplit(interp$interpretation %||% '', '(?<=[.!?])\\s+', perl = TRUE))
    for (j in seq_along(sentences)) {
        if (!.claims_significance(sentences[j])) next
        referenced <- .fragments_referenced(sentences[j], packet$fragments)
        if (length(referenced) == 0) next
        if (!any(vapply(referenced, .fragment_passes, logical(1), alpha = alpha))) {
            violations[[length(violations) + 1]] <- list(
                location = 'interpretation', index = j,
                fragment_id = paste(vapply(referenced, function(f) f$fragment_id, character(1)), collapse = ','),
                issue = 'unsupported_significance'
            )
        }
    }

    violations
}

#' Is an interpretation faithful to its evidence packet?
#'
#' @param interp An `interpretation` object.
#' @param packet The evidence packet `interp` was synthesized from.
#' @param alpha Significance threshold passed to [check_faithfulness()].
#' @return A single logical.
#' @export
is_faithful <- function(interp, packet, alpha = 0.05) length(check_faithfulness(interp, packet, alpha = alpha)) == 0

.describe_violation <- function(v){
    detail <- switch(
        v$issue,
        direction_mismatch = sprintf('claim direction=%s, fragment direction=%s', v$claim_direction, v$fragment_direction),
        unsupported_significance = 'significance wording without a significant fragment behind it',
        'fragment_id not found in packet'
    )
    sprintf('%s[%d] fragment_id=%s issue=%s (%s)', v$location, v$index, v$fragment_id, v$issue, detail)
}

#' Hard-reject an interpretation with any faithfulness violation
#'
#' Throws if [check_faithfulness()] finds any fabricated or
#' direction-mismatched citation, or significance wording that no significant
#' fragment supports.
#'
#' @param interp An `interpretation` object.
#' @param packet The evidence packet `interp` was synthesized from.
#' @return Invisibly `TRUE` if faithful; otherwise throws.
#' @export
assert_faithfulness <- function(interp, packet){
    violations <- check_faithfulness(interp, packet)
    if (length(violations) > 0) {
        stop('faithfulness violation(s): ', paste(vapply(violations, .describe_violation, character(1)), collapse = '; '))
    }
    invisible(TRUE)
}

#' Flag (rather than reject) an interpretation with faithfulness violations
#'
#' The pipeline variant of [assert_faithfulness()]: does not throw, so one
#' bad claim doesn't take down a whole batch run. Instead unions
#' `'needs_human_review'` into `interp$flags`, which [fuse_confidence()]
#' folds into the final routing decision.
#'
#' @param interp An `interpretation` object.
#' @param packet The evidence packet `interp` was synthesized from.
#' @return `interp`, with `flags` updated if any violation was found.
#' @export
enforce_faithfulness <- function(interp, packet){
    violations <- check_faithfulness(interp, packet)
    if (length(violations) > 0) {
        interp$flags <- as.list(union(unlist(interp$flags), 'needs_human_review'))
    }
    interp
}
