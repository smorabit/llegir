## confidence fusion (docs/milestone_2.md task 4): the model's self-reported
## confidence is never trusted alone. It's blended with deterministic signals
## computed straight from the packet, and the blend is what can trigger
## review flags -- so a fluent, confident label over weak evidence (the
## failure mode implementation_guide.md #3/#4 calls out) gets caught even if
## the model never flags itself.

# immediate-early / dissociation-artifact genes (implementation_guide.md #3);
# a hub-gene list dominated by these is a stress/dissociation artifact, not a
# real biological program
.ieg_artifact_genes <- c(
    'FOS', 'FOSB', 'JUN', 'JUNB', 'JUND', 'EGR1', 'EGR2', 'EGR3',
    'NR4A1', 'NR4A2', 'NR4A3', 'IER2', 'IER3', 'DUSP1', 'HSPA1A', 'HSPA1B', 'ZFP36'
)

# fragment types whose effect_strength is a bounded, comparable magnitude
# (correlation / rank-biserial-like, ~[0, 1]). geneset_enrichment's
# effect_strength is -log10(p) on an unbounded scale and would otherwise
# swamp every other signal when pooled into the same max() -- it's captured
# separately via n_significant_enrichment_terms instead. ranked_genes (kME)
# is included since kME is itself a bounded correlation.
.bounded_effect_types <- c(
    'ranked_genes', 'state_expression', 'categorical_association',
    'continuous_correlation', 'signature_correlation'
)

# deterministic signals from the packet alone, independent of any model
# output: the three inputs docs/milestone_2.md task 4 names explicitly.
#
# Two guards against known false-positive patterns, not thresholds tuned to
# any one dataset: (1) a fragment only counts as "has signal" if it clears
# both a significance AND an effect-size bar -- large-N tests (e.g.
# cluster_dme on thousands of cells) can hit p~0 on a practically negligible
# effect, so significance alone overstates confidence; (2) an enrichment term
# only counts as significant with >= min_overlap_genes overlapping genes --
# a single-gene overlap against a narrow GO term is a classic false positive
# in a small hub-gene list (see docs/milestone_1.md spike-in notes).
#' Compute deterministic evidence signals from a packet
#'
#' Signals independent of any model output: the maximum bounded effect
#' strength across fragments, the number of significant enrichment terms,
#' and cross-tool agreement on whether the module shows a real signal.
#' Two guards against known false-positive patterns (not thresholds tuned to
#' any one dataset): a fragment only counts as "has signal" if it clears both
#' a significance AND an effect-size bar (large-N tests can hit p~0 on a
#' practically negligible effect), and an enrichment term only counts as
#' significant with at least `min_overlap_genes` overlapping genes (a
#' single-gene overlap against a narrow term is a classic false positive in
#' a small hub-gene list).
#'
#' @param packet An evidence packet, as built by [build_evidence_packet()].
#' @param sig_threshold Significance (p/FDR) cutoff.
#' @param effect_floor Minimum effect strength for a bounded fragment to
#'   count as "has signal".
#' @param min_overlap_genes Minimum overlap genes for an enrichment term to
#'   count as significant.
#' @return A list: `max_effect_strength`, `n_significant_enrichment_terms`,
#'   `n_testable_tools`, `n_tools_with_signal`, `cross_tool_agreement` (one of
#'   `'convergent_signal'`, `'convergent_null'`, `'conflicting'`, or `NA`).
#' @examples
#' ms <- llegir_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = hub_genes_tool, params = list())))
#' compute_evidence_signals(packet)
#' @export
compute_evidence_signals <- function(packet, sig_threshold = 0.05, effect_floor = 0.5, min_overlap_genes = 2){
    fragments <- packet$fragments

    bounded <- Filter(function(f) f$type %in% .bounded_effect_types, fragments)
    bounded_effects <- vapply(bounded, function(f) f$effect_strength, numeric(1))
    max_effect_strength <- if (length(bounded_effects) > 0) max(bounded_effects, na.rm = TRUE) else NA_real_

    enrich_frag <- Find(function(f) f$type == 'geneset_enrichment', fragments)
    n_significant_enrichment_terms <- if (!is.null(enrich_frag) && 'fdr' %in% names(enrich_frag$result)) {
        hits <- enrich_frag$result$fdr < sig_threshold
        if ('ngenes' %in% names(enrich_frag$result)) hits <- hits & (enrich_frag$result$ngenes >= min_overlap_genes)
        sum(hits, na.rm = TRUE)
    } else {
        0L
    }

    # only bounded, tested fragments (significance not NA) can "agree" or
    # "disagree" -- geneset_enrichment is excluded (different scale, already
    # captured above) and the descriptive metadata::sample fragment
    # (docs/milestone_1_5.md) is excluded by construction (significance NA)
    testable <- Filter(function(f) !is.null(f$significance) && !is.na(f$significance), bounded)
    has_signal <- function(f) f$significance < sig_threshold && f$effect_strength >= effect_floor

    # docs/dev_economy.md task 4: after the M1.5 pseudoreplication fix,
    # module_by_metadata is (correctly) non-significant on most modules --
    # that's an absence of association with one covariate (e.g. diagnosis),
    # a different question from "does this module have a real biological
    # signal", and must not read as a conflict against a present
    # cluster_dme/enrichment effect. A non-significant module_by_metadata
    # fragment is therefore dropped from the vote entirely; one that DOES
    # show a signal still joins it, either reinforcing convergence or (paired
    # with a null from a non-metadata tool) surfacing a genuine conflict.
    is_metadata_tool <- vapply(testable, function(f) identical(f$tool_id, 'module_by_metadata'), logical(1))
    voters <- c(testable[!is_metadata_tool], Filter(has_signal, testable[is_metadata_tool]))

    n_testable <- length(voters)
    n_with_signal <- sum(vapply(voters, has_signal, logical(1)))
    cross_tool_agreement <- if (n_testable == 0) {
        NA_character_
    } else if (n_with_signal == n_testable) {
        'convergent_signal'
    } else if (n_with_signal == 0) {
        'convergent_null'
    } else {
        'conflicting'
    }

    list(
        max_effect_strength = max_effect_strength,
        n_significant_enrichment_terms = n_significant_enrichment_terms,
        n_testable_tools = n_testable,
        n_tools_with_signal = n_with_signal,
        cross_tool_agreement = cross_tool_agreement
    )
}

# maps the deterministic signals to a single 0-1 evidence score; a crude but
# transparent heuristic, not a fitted model.
.evidence_score <- function(signals){
    effect_score <- if (is.na(signals$max_effect_strength)) 0 else min(signals$max_effect_strength, 1)
    enrichment_score <- min(signals$n_significant_enrichment_terms / 5, 1)
    agreement_score <- switch(
        signals$cross_tool_agreement %||% 'na',
        convergent_signal = 1,
        convergent_null = 0,
        conflicting = 0.3,
        0.5
    )
    list(
        score = mean(c(effect_score, enrichment_score, agreement_score)),
        effect_score = effect_score,
        enrichment_score = enrichment_score,
        agreement_score = agreement_score
    )
}

# TRUE if the module's hub genes are dominated by IEG/dissociation-stress
# markers rather than a coherent biological program
.artifact_flagged <- function(packet, top_n = 10, frac_threshold = 0.3){
    hub_frag <- Find(function(f) f$type == 'ranked_genes', packet$fragments)
    if (is.null(hub_frag) || !('gene_name' %in% names(hub_frag$result))) return(FALSE)
    top_genes <- utils::head(hub_frag$result$gene_name, top_n)
    mean(toupper(top_genes) %in% .ieg_artifact_genes) >= frac_threshold
}

#' Fuse model and deterministic confidence into a final score and flags
#'
#' The model's self-reported confidence (`interp$confidence$model_score`) is
#' never trusted alone. It's blended with [compute_evidence_signals()], and
#' the blend is what can trigger review flags -- so a fluent, confident label
#' over weak evidence gets caught even if the model never flags itself.
#' Mutates and returns `interp`: `confidence$score` is overwritten
#' (`model_score` is preserved for audit), and `flags` are unioned with
#' whatever the model or [enforce_faithfulness()] already set.
#'
#' @param interp An `interpretation` object, as returned by
#'   [synthesize_interpretation()] (after [enforce_faithfulness()]).
#' @param packet The evidence packet `interp` was synthesized from.
#' @param low_threshold Evidence-score floor below which the fused score is
#'   capped and `'insufficient_evidence'` is flagged.
#' @param disagreement_threshold Minimum `|model_score - evidence_score|` gap
#'   that flags `'needs_human_review'`.
#' @return `interp`, with `confidence$score`, `confidence$rationale`, and
#'   `flags` updated.
#' @examples
#' ms <- llegir_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = hub_genes_tool, params = list())))
#' desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
#' interp <- synthesize_interpretation(packet, desc, mock_backend())
#' fuse_confidence(interp, packet)
#' @export
fuse_confidence <- function(interp, packet, low_threshold = 0.35, disagreement_threshold = 0.35){
    signals <- compute_evidence_signals(packet)
    evidence <- .evidence_score(signals)
    model_score <- interp$confidence$model_score
    fused_score <- 0.5 * model_score + 0.5 * evidence$score

    flags <- unlist(interp$flags)

    # weak evidence caps the final score regardless of how confident the
    # model sounded -- this is the guardrail against a fluent story over a
    # random gene set (docs/implementation_guide.md #4 negative control)
    if (evidence$score < low_threshold) {
        flags <- union(flags, 'insufficient_evidence')
        fused_score <- min(fused_score, low_threshold)
    }
    if (abs(model_score - evidence$score) > disagreement_threshold) {
        flags <- union(flags, 'needs_human_review')
    }
    if (identical(signals$cross_tool_agreement, 'conflicting')) {
        flags <- union(flags, 'tool_conflict')
    }
    if (.artifact_flagged(packet)) {
        flags <- union(flags, 'possible_artifact')
    }

    interp$confidence$score <- fused_score
    interp$confidence$rationale <- sprintf(
        '%s [fusion: model=%.2f, evidence=%.2f (effect=%.2f, enrichment=%.2f, agreement=%.2f/%s), fused=%.2f]',
        interp$confidence$rationale, model_score, evidence$score, evidence$effect_score,
        evidence$enrichment_score, evidence$agreement_score, signals$cross_tool_agreement %||% 'na', fused_score
    )
    interp$flags <- as.list(flags)
    interp
}

#' Does an interpretation need human review?
#'
#' Flagged interpretations are routed to the review queue
#' ([build_review_queue()]); exposed here so the output stage doesn't
#' re-derive the rule.
#'
#' @param interp An `interpretation` object.
#' @return A single logical: `TRUE` if `interp$flags` is non-empty.
#' @export
needs_review <- function(interp) length(unlist(interp$flags)) > 0
