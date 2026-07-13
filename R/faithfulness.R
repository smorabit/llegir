## faithfulness auto-check (docs/milestone_2.md task 3): every fragment_id
## cited in supporting_claims / metadata_associations must exist in the
## module's evidence packet, and a supporting_claims direction must match the
## direction actually reported by the fragment it cites. A mismatch is a hard
## failure, not a warning.

# pure, non-throwing: returns a list of violation records (empty list if
# faithful). Each record: list(location, index, fragment_id, issue, ...).
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

is_faithful <- function(interp, packet) length(check_faithfulness(interp, packet)) == 0

.describe_violation <- function(v){
    detail <- if (v$issue == 'direction_mismatch') {
        sprintf('claim direction=%s, fragment direction=%s', v$claim_direction, v$fragment_direction)
    } else {
        'fragment_id not found in packet'
    }
    sprintf('%s[%d] fragment_id=%s issue=%s (%s)', v$location, v$index, v$fragment_id, v$issue, detail)
}

# hard rejection: throws if any citation is fabricated or direction-mismatched
assert_faithfulness <- function(interp, packet){
    violations <- check_faithfulness(interp, packet)
    if (length(violations) > 0) {
        stop('faithfulness violation(s): ', paste(vapply(violations, .describe_violation, character(1)), collapse = '; '))
    }
    invisible(TRUE)
}

# pipeline variant: does not throw, so one bad claim doesn't take down a whole
# batch run; instead flags the interpretation for human review. Confidence
# fusion (R/confidence.R) folds this flag into the final routing decision.
enforce_faithfulness <- function(interp, packet){
    violations <- check_faithfulness(interp, packet)
    if (length(violations) > 0) {
        interp$flags <- as.list(union(unlist(interp$flags), 'needs_human_review'))
    }
    interp
}
