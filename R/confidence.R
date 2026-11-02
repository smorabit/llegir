## confidence fusion (docs/milestones/milestone_fused_confidence.md): the
## model's self-reported confidence is never trusted alone. It's blended with
## a deterministic fused evidence score computed straight from the packet
## before synthesis, and the blend is what can trigger review flags -- so a
## fluent, confident label over weak evidence (the failure mode
## implementation_guide.md #3/#4 calls out) gets caught even if the model
## never flags itself.

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

#---------------------------------------------------------
# normalization constants (milestone_fused_confidence.md S1)
#---------------------------------------------------------

# scale family per fragment type; extends .bounded_effect_types so the
# magnitude link (.magnitude_score()) knows which squash to apply -- corr
# types are already bounded, enrich/fc are unbounded and need saturation
.scale_family <- list(
    ranked_genes = 'corr', state_expression = 'corr',
    categorical_association = 'corr', continuous_correlation = 'corr',
    signature_correlation = 'corr', geneset_enrichment = 'enrich',
    cross_condition_delta = 'fc'
)

# tool importance tier base weights (R/registry.R's register_tool tier);
# a tool with no declared tier resolves to 'medium'
.tier_weights <- list(high = 1.0, medium = 0.6, low = 0.3)

#---------------------------------------------------------
# per-fragment normalization
#---------------------------------------------------------

# hill saturation: half-max at k, steepness h, bounded [0, 1)
.hill <- function(x, k, h = 2){
    xh <- x^h
    xh / (xh + k^h)
}

# magnitude link: corr fragments are already bounded and just clip; enrich/fc
# fragments are unbounded and saturate on a biologically anchored half-max so
# geneset_enrichment's -log10(p) cannot swamp the pool
.magnitude_score <- function(frag, gamma = 1, k_enrich = -log10(0.05), k_fc = 1){
    family <- .scale_family[[frag$type]] %||% 'corr'
    s <- abs(frag$effect_strength)
    switch(family,
        corr = min(s, 1)^gamma,
        enrich = .hill(s, k_enrich),
        fc = .hill(s, k_fc)
    )
}

# significance reliability: partial credit at nominal alpha, saturating at a
# strong reference p; descriptive fragments (significance NA, no inferential
# test) take na_reliability instead
.reliability_score <- function(frag, alpha_ref = 1e-4, na_reliability = 1){
    p <- frag$significance
    if (is.null(p) || is.na(p)) return(na_reliability)
    max(min(-log10(p) / -log10(alpha_ref), 1), 0)
}

# combined per-fragment evidence score: effect AND test, multiplicatively --
# a real effect with no test, or a test with no real effect, both stay low
.fragment_score <- function(frag, params){
    m <- .magnitude_score(frag, params$gamma, params$k_enrich, params$k_fc)
    r <- .reliability_score(frag, params$alpha_ref, params$na_reliability)
    m * r
}

#---------------------------------------------------------
# tool weights (tier base x user override)
#---------------------------------------------------------

# tier is read from the registry spec; unregistered tools or those missing a
# tier (e.g. a custom tool that predates the tier field) fall back to medium
.tool_weight <- function(frag, user_weights){
    tier <- tryCatch(get_tool(frag$tool_id)$tier, error = function(e) NULL) %||% 'medium'
    base <- .tier_weights[[tier]] %||% .tier_weights$medium
    override <- user_weights[[frag$tool_id]] %||% 1
    base * override
}

#---------------------------------------------------------
# pooling and directional penalty
#---------------------------------------------------------

# weighted power mean of per-fragment scores; beta -> 1 is arithmetic
# (compensatory), beta -> 0 approaches the corroborative geometric mean. the
# floor keeps the geometric limit well-defined when a fragment scores exactly 0
.pool_evidence <- function(scores, weights, beta = 0.5, floor = 1e-3){
    e <- pmax(scores, floor)
    (sum(weights * e^beta) / sum(weights))^(1 / beta)
}

# mass-weighted directional coherence: two strong opposed tools collapse it,
# a faint dissenter barely moves it; non-directional fragments (direction
# na/mixed, e.g. all ranked_genes) never vote. with <= 1 directional
# fragment there's nothing to disagree with, so coherence is trivially 1
.directional_coherence <- function(frags, masses){
    sign_map <- c(up = 1, down = -1, mixed = 0, na = 0)
    sigma <- sign_map[vapply(frags, function(f) f$direction %||% 'na', character(1))]
    directional <- sigma != 0
    if (sum(directional) <= 1) return(1)
    a <- masses[directional]
    abs(sum(sigma[directional] * a)) / sum(a)
}

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
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
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

#' Calculate the deterministic fused evidence confidence for a packet
#'
#' Normalizes every fragment onto a unified `[0, 1]` scale
#' ([.fragment_score()]: a type-aware magnitude link times a significance-
#' reliability factor), pools them with a weighted power mean
#' ([.pool_evidence()]) using tool-tier + `user_weights` importance
#' ([.tool_weight()]), and applies a mass-weighted directional-conflict
#' penalty ([.directional_coherence()]). Computed straight from the packet,
#' so the result is reproducible from the packet hash alone.
#'
#' Shelved as of Part 4.5
#' (`docs/prompts/handoff_prompt_serpentine_tcell.md`): no longer injected
#' into the synthesis prompt and no longer consumed by [fuse_confidence()].
#' Kept intact, with [compute_evidence_signals()], for a future redesign of
#' the evidence score.
#'
#' @param fragments A list of `evidence_fragment` objects (a packet's `fragments`).
#' @param user_weights Named list of per-`tool_id` weight multipliers on top of
#'   the structural tier base (see [register_tool()]'s `tier` argument).
#'   Default `list()` (all tiers unmodified).
#' @param beta Corroboration exponent for the power mean; lower is more
#'   conjunctive (a single weak tool can't be offset by a strong one), higher
#'   is more compensatory. Default `0.5`.
#' @param lambda Model-trust weight in the final geometric blend
#'   ([fuse_confidence()]); threaded through only for provenance on the
#'   returned list. Default `0.35`.
#' @param kappa Maximum directional-conflict penalty. Default `0.5`.
#' @return A list: `e_evidence` (the final empirical evidence term),
#'   `e_pool` (pooled evidence before the directional penalty), `p_agree`
#'   (the directional penalty factor), `c_dir` (directional coherence),
#'   `lambda`, `params` (`beta`, `kappa`), and `matrix` (a per-fragment
#'   `data.frame` for prompt rendering and audit).
#' @examples
#' ms <- llegir_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
#' calculate_fusion_score(packet$fragments)
#' @export
calculate_fusion_score <- function(fragments, user_weights = list(), beta = 0.5,
                                    lambda = 0.35, kappa = 0.5){
    params <- list(
        gamma = 1, k_enrich = -log10(0.05), k_fc = 1,
        alpha_ref = 1e-4, na_reliability = 1
    )

    scores <- vapply(fragments, .fragment_score, numeric(1), params = params)
    weights <- vapply(fragments, .tool_weight, numeric(1), user_weights = user_weights)
    masses <- weights * scores

    e_pool <- .pool_evidence(scores, weights, beta = beta)
    c_dir <- .directional_coherence(fragments, masses)
    p_agree <- 1 - kappa * (1 - c_dir)
    e_evidence <- p_agree * e_pool

    # per-fragment audit matrix; also the block rendered into the prompt
    # (R/prompt.R's .render_confidence_matrix())
    matrix <- data.frame(
        fragment_id = vapply(fragments, function(f) f$fragment_id, character(1)),
        type = vapply(fragments, function(f) f$type, character(1)),
        weight = round(weights, 3),
        magnitude = round(vapply(fragments, .magnitude_score, numeric(1), gamma = params$gamma, k_enrich = params$k_enrich, k_fc = params$k_fc), 3),
        reliability = round(vapply(fragments, .reliability_score, numeric(1), alpha_ref = params$alpha_ref, na_reliability = params$na_reliability), 3),
        e_score = round(scores, 3),
        direction = vapply(fragments, function(f) f$direction %||% 'na', character(1)),
        stringsAsFactors = FALSE
    )

    list(
        e_evidence = e_evidence, e_pool = e_pool, p_agree = p_agree,
        c_dir = c_dir, lambda = lambda, params = list(beta = beta, kappa = kappa),
        matrix = matrix
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

# fraction of a gene vector that is cytoplasmic ribosomal protein (RPS*/RPL*,
# also catches the RPS6K* kinases -- accepted for regex simplicity) or
# mitochondrially encoded (MT-*). A hub list can be part housekeeping without
# being an artifact, so unlike .ieg_artifact_genes this is reported, not flagged
.housekeeping_gene_fractions <- function(genes){
    genes <- toupper(genes)
    list(
        ribosomal = mean(grepl('^RP[SL]', genes)),
        mitochondrial = mean(grepl('^MT-', genes))
    )
}

#' Housekeeping-composition note for a packet's hub-gene list
#'
#' The fraction of a module's top hub genes that are cytoplasmic ribosomal
#' (`RPS*`/`RPL*`) or mitochondrially encoded (`MT-*`). Surfaced to synthesis
#' via [render_packet_compact()] as a short note appended to the
#' `ranked_genes` fragment, so a module whose hub list is part housekeeping
#' reads as "<program> AND ribosomal-high" instead of having the housekeeping
#' genes quietly dilute the biological call. Deterministic, packet-only, and
#' -- unlike `.artifact_flagged()`'s IEG pattern -- never sets a flag on its own.
#'
#' @param packet An evidence packet, as built by [build_evidence_packet()].
#' @param top_n Number of top hub genes to inspect. Default `20`.
#' @param min_fraction Fraction a family must reach to be worth noting.
#'   Default `0.15`.
#' @return A single-string note, or `NULL` when neither family clears
#'   `min_fraction` or the packet carries no `ranked_genes` fragment.
#' @examples
#' ms <- llegir_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
#' housekeeping_composition_note(packet)
#' @export
housekeeping_composition_note <- function(packet, top_n = 20, min_fraction = 0.15){
    hub_frag <- Find(function(f) f$type == 'ranked_genes', packet$fragments)
    if (is.null(hub_frag) || !('gene_name' %in% names(hub_frag$result))) return(NULL)
    top_genes <- utils::head(hub_frag$result$gene_name, top_n)
    fr <- .housekeeping_gene_fractions(top_genes)

    parts <- character(0)
    if (fr$ribosomal >= min_fraction) {
        parts <- c(parts, sprintf('%d%% ribosomal protein genes (RPS/RPL)', round(100 * fr$ribosomal)))
    }
    if (fr$mitochondrial >= min_fraction) {
        parts <- c(parts, sprintf('%d%% mitochondrial genes (MT-)', round(100 * fr$mitochondrial)))
    }
    if (length(parts) == 0) return(NULL)

    sprintf(
        'housekeeping note: %s among the top %d hub genes -- read this as a co-occurring housekeeping program alongside the module\'s biology, not automatically an artifact',
        paste(parts, collapse = ' and '), top_n
    )
}

#' Apply deterministic review flags to an interpretation
#'
#' The fused evidence score is shelved
#' (`docs/prompts/handoff_prompt_serpentine_tcell.md` Part 4.5): its two known
#' flaws -- a non-significant dynamics fragment dragging down a genuinely
#' stable module, and `top_genes`' top-kME magnitude standing in for
#' interpretation confidence when it only measures hub tightness -- made the
#' blended number misleading, so `confidence$score` is left as the model's own
#' calibrated value. This function now only unions the deterministic
#' `possible_artifact` flag (hub list dominated by IEG/dissociation-stress
#' markers, `.artifact_flagged()`) into `interp$flags`; [enforce_faithfulness()]
#' sets `needs_human_review` independently, and the model may still set
#' `insufficient_evidence` itself. [calculate_fusion_score()] and
#' [compute_evidence_signals()] are retained, unused here, for a future
#' redesign of the score.
#'
#' @param interp An `interpretation` object, as returned by
#'   [synthesize_interpretation()] (after [enforce_faithfulness()]).
#' @param packet The evidence packet `interp` was synthesized from.
#' @param low_threshold Ignored; retained for call-site compatibility.
#' @param disagreement_threshold Ignored; retained for call-site compatibility.
#' @param user_weights Ignored; retained for call-site compatibility.
#' @param fusion Ignored; retained for call-site compatibility.
#' @return `interp`, with `flags` possibly extended by `'possible_artifact'`.
#' @examples
#' ms <- llegir_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
#' desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
#' interp <- synthesize_interpretation(packet, desc, mock_backend())
#' fuse_confidence(interp, packet)
#' @export
fuse_confidence <- function(interp, packet, low_threshold = 0.35, disagreement_threshold = 0.35,
                             user_weights = list(), fusion = NULL){
    flags <- unlist(interp$flags)
    if (.artifact_flagged(packet)) {
        flags <- union(flags, 'possible_artifact')
    }
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
