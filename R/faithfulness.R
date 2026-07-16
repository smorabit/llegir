## faithfulness auto-check (docs/milestone_2.md task 3): every fragment_id
## cited in supporting_claims / metadata_associations must exist in the
## module's evidence packet, and a supporting_claims direction must match the
## direction actually reported by the fragment it cites. A mismatch is a hard
## failure, not a warning.

#' Check citation faithfulness of an interpretation against its packet
#'
#' Every fragment_id cited in `supporting_claims` / `metadata_associations`
#' must exist in the module's evidence packet, and a `supporting_claims`
#' entry's `direction` must match the direction actually reported by the
#' fragment(s) it cites. Pure and non-throwing; see [assert_faithfulness()]
#' for the hard-rejecting variant.
#'
#' @param interp An `interpretation` object.
#' @param packet The evidence packet `interp` was synthesized from.
#' @return A list of violation records (empty if faithful); each record is a
#'   list with `location`, `index`, `fragment_id`, `issue`
#'   (`'missing_fragment'` or `'direction_mismatch'`), and, for
#'   `'direction_mismatch'`, `claim_direction`/`fragment_direction`.
#' @examples
#' ms <- llegir_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = hub_genes_tool, params = list())))
#' desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
#' interp <- synthesize_interpretation(packet, desc, mock_backend())
#' check_faithfulness(interp, packet)
#' @export
check_faithfulness <- function(interp, packet){
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
    }

    for (i in seq_along(interp$metadata_associations)) {
        fid <- interp$metadata_associations[[i]]$fragment_id
        if (!(fid %in% names(frag_by_id))) {
            violations[[length(violations) + 1]] <- list(
                location = 'metadata_associations', index = i, fragment_id = fid, issue = 'missing_fragment'
            )
        }
    }

    violations
}

#' Is an interpretation faithful to its evidence packet?
#'
#' @param interp An `interpretation` object.
#' @param packet The evidence packet `interp` was synthesized from.
#' @return A single logical.
#' @export
is_faithful <- function(interp, packet) length(check_faithfulness(interp, packet)) == 0

.describe_violation <- function(v){
    detail <- if (v$issue == 'direction_mismatch') {
        sprintf('claim direction=%s, fragment direction=%s', v$claim_direction, v$fragment_direction)
    } else {
        'fragment_id not found in packet'
    }
    sprintf('%s[%d] fragment_id=%s issue=%s (%s)', v$location, v$index, v$fragment_id, v$issue, detail)
}

#' Hard-reject an interpretation with any faithfulness violation
#'
#' Throws if [check_faithfulness()] finds any fabricated or
#' direction-mismatched citation.
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
