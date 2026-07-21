## confidence fusion (docs/milestone_2.md task 4), evaluated on the M1
## spike-in controls: the deterministic evidence signals alone must separate
## the pDC positive control from the random negative control, independent of
## what the (mocked) model says -- this is the guardrail against a
## confidently-narrated random gene set.

make_confident_interpretation <- function(module_id, packet_hash, model_score = 0.9){
    interpretation(
        module_id = module_id, proposed_label = 'x', one_line_summary = 'x', dominant_biology = 'x',
        supporting_claims = list(list(claim = 'x', fragment_ids = 'top_genes', direction = 'na')),
        confidence = list(score = model_score, model_score = model_score, rationale = 'model self-report'),
        provenance = make_interpretation_provenance('mock', '0.1', 0, packet_hash)
    )
}

test_that('compute_evidence_signals() restricts max_effect_strength to bounded-scale fragment types', {
    bounded <- evidence_fragment(
        fragment_id = 'cluster_dme', tool_id = 'cluster_dme', module_id = 'MM1', type = 'state_expression',
        result = data.frame(x = 1), compact_summary = 'x', top_findings = list(),
        effect_strength = 0.4, significance = 0.001, direction = 'up',
        provenance = make_provenance('0.1')
    )
    unbounded_enrichment <- evidence_fragment(
        fragment_id = 'geneset_enrichment', tool_id = 'geneset_enrichment', module_id = 'MM1', type = 'geneset_enrichment',
        result = data.frame(term = 'x', fdr = 0.01, ngenes = 3), compact_summary = 'x', top_findings = list(),
        effect_strength = 50, significance = 0.001, direction = 'up',
        provenance = make_provenance('0.1')
    )
    packet <- build_evidence_packet('MM1', list(bounded, unbounded_enrichment), input_hash = 'abc')
    signals <- compute_evidence_signals(packet)
    # the enrichment fragment's effect_strength (50, an unbounded -log10(p))
    # must not leak into max_effect_strength
    expect_equal(signals$max_effect_strength, 0.4)
    expect_equal(signals$n_significant_enrichment_terms, 1)
})

test_that('compute_evidence_signals() requires a minimum gene overlap for an enrichment term to count', {
    single_gene_hit <- evidence_fragment(
        fragment_id = 'geneset_enrichment', tool_id = 'geneset_enrichment', module_id = 'MM1', type = 'geneset_enrichment',
        result = data.frame(term = c('narrow_term', 'broad_term'), fdr = c(0.001, 0.001), ngenes = c(1, 3)),
        compact_summary = 'x', top_findings = list(), effect_strength = 10, direction = 'up',
        provenance = make_provenance('0.1')
    )
    packet <- build_evidence_packet('MM1', list(single_gene_hit), input_hash = 'abc')
    signals <- compute_evidence_signals(packet)
    expect_equal(signals$n_significant_enrichment_terms, 1)
})

test_that('compute_evidence_signals() requires both significance and effect size to count as agreement signal', {
    # large-N artifact: significant p-value but a practically negligible effect
    weak_but_significant <- evidence_fragment(
        fragment_id = 'cluster_dme', tool_id = 'cluster_dme', module_id = 'MM1', type = 'state_expression',
        result = data.frame(x = 1), compact_summary = 'x', top_findings = list(),
        effect_strength = 0.1, significance = 1e-30, direction = 'up',
        provenance = make_provenance('0.1')
    )
    packet <- build_evidence_packet('MM1', list(weak_but_significant), input_hash = 'abc')
    signals <- compute_evidence_signals(packet)
    expect_equal(signals$n_tools_with_signal, 0)
    expect_equal(signals$cross_tool_agreement, 'convergent_null')
})

test_that('fuse_confidence() separates the pDC positive control from the random negative control', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    positive_packet <- build_spike_in_packet(positive_ms, 'pdc_module', length(pdc_genes))
    negative_packet <- build_spike_in_packet(negative_ms, 'random_module', length(pdc_genes))

    # both start from an equally (over)confident model self-report; only the
    # deterministic evidence should be able to tell them apart
    pos_interp <- make_confident_interpretation('pdc_module', positive_packet$packet_hash, model_score = 0.9)
    neg_interp <- make_confident_interpretation('random_module', negative_packet$packet_hash, model_score = 0.9)

    fused_pos <- fuse_confidence(pos_interp, positive_packet)
    fused_neg <- fuse_confidence(neg_interp, negative_packet)

    expect_true(fused_pos$confidence$score > fused_neg$confidence$score)
    expect_true(fused_pos$confidence$score > 0.5)
    expect_true(fused_neg$confidence$score <= 0.35)
    expect_true('insufficient_evidence' %in% unlist(fused_neg$flags))
    # the model was equally overconfident on both; disagreement with weak
    # deterministic evidence must route the negative control for review
    expect_true('needs_human_review' %in% unlist(fused_neg$flags))
    expect_true(needs_review(fused_neg))
})

test_that('fuse_confidence() does not flag insufficient_evidence when the model is well-calibrated to strong evidence', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    positive_packet <- build_spike_in_packet(positive_ms, 'pdc_module', length(pdc_genes))
    interp <- make_confident_interpretation('pdc_module', positive_packet$packet_hash, model_score = 0.7)
    fused <- fuse_confidence(interp, positive_packet)
    expect_false('insufficient_evidence' %in% unlist(fused$flags))
})

test_that('fuse_confidence() does not flag tool_conflict when a metadata association is merely absent (docs/dev_economy.md task 4)', {
    signal_frag <- evidence_fragment(
        fragment_id = 'cluster_dme', tool_id = 'cluster_dme', module_id = 'MM1', type = 'state_expression',
        result = data.frame(x = 1), compact_summary = 'x', top_findings = list(),
        effect_strength = 0.9, significance = 0.001, direction = 'up',
        provenance = make_provenance('0.1')
    )
    null_metadata_frag <- evidence_fragment(
        fragment_id = 'metadata::diagnosis', tool_id = 'module_by_metadata', module_id = 'MM1', type = 'categorical_association',
        result = data.frame(x = 1), compact_summary = 'x', top_findings = list(),
        effect_strength = 0.1, significance = 0.9, direction = 'na',
        provenance = make_provenance('0.1')
    )
    packet <- build_evidence_packet('MM1', list(signal_frag, null_metadata_frag), input_hash = 'abc')
    signals <- compute_evidence_signals(packet)
    expect_equal(signals$cross_tool_agreement, 'convergent_signal')

    interp <- make_confident_interpretation('MM1', packet$packet_hash, model_score = 0.5)
    fused <- fuse_confidence(interp, packet)
    expect_false('tool_conflict' %in% unlist(fused$flags))
})

test_that('fuse_confidence() still flags tool_conflict when a non-metadata tool disagrees with a significant metadata association', {
    null_cluster_frag <- evidence_fragment(
        fragment_id = 'cluster_dme', tool_id = 'cluster_dme', module_id = 'MM1', type = 'state_expression',
        result = data.frame(x = 1), compact_summary = 'x', top_findings = list(),
        effect_strength = 0.1, significance = 0.9, direction = 'na',
        provenance = make_provenance('0.1')
    )
    signal_metadata_frag <- evidence_fragment(
        fragment_id = 'metadata::diagnosis', tool_id = 'module_by_metadata', module_id = 'MM1', type = 'categorical_association',
        result = data.frame(x = 1), compact_summary = 'x', top_findings = list(),
        effect_strength = 0.8, significance = 0.001, direction = 'up',
        provenance = make_provenance('0.1')
    )
    packet <- build_evidence_packet('MM1', list(null_cluster_frag, signal_metadata_frag), input_hash = 'abc')
    signals <- compute_evidence_signals(packet)
    expect_equal(signals$cross_tool_agreement, 'conflicting')

    interp <- make_confident_interpretation('MM1', packet$packet_hash, model_score = 0.5)
    fused <- fuse_confidence(interp, packet)
    expect_true('tool_conflict' %in% unlist(fused$flags))
})

test_that('fuse_confidence() flags possible_artifact when top genes are dominated by IEG/dissociation markers', {
    ieg_top <- evidence_fragment(
        fragment_id = 'top_genes', tool_id = 'top_genes', module_id = 'MM1', type = 'ranked_genes',
        result = data.frame(gene_name = c('FOS', 'JUN', 'EGR1', 'NR4A1', 'DUSP1', 'GENE6', 'GENE7', 'GENE8', 'GENE9', 'GENE10'), kme = 0.5),
        compact_summary = 'x', top_findings = list(), effect_strength = 0.5, provenance = make_provenance('0.1')
    )
    packet <- build_evidence_packet('MM1', list(ieg_top), input_hash = 'abc')
    interp <- make_confident_interpretation('MM1', packet$packet_hash, model_score = 0.5)
    fused <- fuse_confidence(interp, packet)
    expect_true('possible_artifact' %in% unlist(fused$flags))
})

test_that('fuse_confidence() preserves prior flags (e.g. from enforce_faithfulness())', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    positive_packet <- build_spike_in_packet(positive_ms, 'pdc_module', length(pdc_genes))
    interp <- make_confident_interpretation('pdc_module', positive_packet$packet_hash, model_score = 0.7)
    interp$flags <- list('label_low_specificity')
    fused <- fuse_confidence(interp, positive_packet)
    expect_true('label_low_specificity' %in% unlist(fused$flags))
})

test_that('needs_review() reflects whether any flag is set', {
    expect_false(needs_review(make_confident_interpretation('MM1', 'abc')))
    flagged <- make_confident_interpretation('MM1', 'abc')
    flagged$flags <- list('needs_human_review')
    expect_true(needs_review(flagged))
})

## deterministic fused evidence confidence (docs/milestones/milestone_fused_confidence.md)

make_frag <- function(type, effect_strength, significance = NA_real_, direction = 'na', tool_id = 'top_genes', fragment_id = tool_id){
    evidence_fragment(
        fragment_id = fragment_id, tool_id = tool_id, module_id = 'MM1', type = type,
        result = data.frame(x = 1), compact_summary = 'x', top_findings = list(),
        effect_strength = effect_strength, significance = significance, direction = direction,
        provenance = make_provenance('0.1')
    )
}

test_that('.magnitude_score() clips corr-family effects to [0, 1] and is monotone', {
    weak <- make_frag('state_expression', 0.2)
    strong <- make_frag('state_expression', 0.8)
    over_bound <- make_frag('state_expression', 5)
    expect_true(.magnitude_score(strong) > .magnitude_score(weak))
    expect_equal(.magnitude_score(over_bound), 1)
})

test_that('.magnitude_score() saturates enrich/fc families in [0, 1) and is monotone', {
    weak <- make_frag('geneset_enrichment', 1)
    strong <- make_frag('geneset_enrichment', 20)
    expect_true(.magnitude_score(strong) > .magnitude_score(weak))
    expect_true(.magnitude_score(strong) < 1)
    expect_true(.magnitude_score(weak) >= 0)

    fc_weak <- make_frag('cross_condition_delta', 0.5)
    fc_strong <- make_frag('cross_condition_delta', 4)
    expect_true(.magnitude_score(fc_strong) > .magnitude_score(fc_weak))
    expect_true(.magnitude_score(fc_strong) < 1)
})

test_that('.reliability_score() is bounded, monotone in significance, and falls back for NA', {
    strong_p <- make_frag('state_expression', 0.5, significance = 1e-6)
    weak_p <- make_frag('state_expression', 0.5, significance = 0.049)
    descriptive <- make_frag('ranked_genes', 0.5, significance = NA_real_)
    expect_true(.reliability_score(strong_p) > .reliability_score(weak_p))
    expect_true(.reliability_score(strong_p) <= 1)
    expect_true(.reliability_score(weak_p) >= 0)
    expect_equal(.reliability_score(descriptive), 1)
    expect_equal(.reliability_score(descriptive, na_reliability = 0.4), 0.4)
})

test_that('geneset_enrichment at FDR = 0.05 maps near 0.5 and cannot dominate an equal-weight bounded correlation', {
    enrich_frag <- make_frag('geneset_enrichment', -log10(0.05), significance = 0.05, direction = 'up', tool_id = 'geneset_enrichment')
    expect_equal(.magnitude_score(enrich_frag), 0.5, tolerance = 1e-6)

    corr_frag <- make_frag('signature_correlation', 0.9, significance = 1e-5, direction = 'up', tool_id = 'signature_correlation')
    # equalize tier weights via user_weights so the comparison isolates the
    # normalization link, not the tier system
    fusion <- calculate_fusion_score(
        list(enrich_frag, corr_frag),
        user_weights = list(geneset_enrichment = 2, signature_correlation = 1)
    )
    expect_true(fusion$e_pool < .fragment_score(corr_frag, list(gamma = 1, k_enrich = -log10(0.05), k_fc = 1, alpha_ref = 1e-4, na_reliability = 1)))
})

test_that('calculate_fusion_score() geometric blend vetoes a confident model over near-zero evidence', {
    weak_frag <- make_frag('ranked_genes', 0.001, significance = NA_real_, direction = 'na')
    fusion <- calculate_fusion_score(list(weak_frag))
    expect_true(fusion$e_evidence < 0.01)

    fused_score <- 1^fusion$lambda * fusion$e_evidence^(1 - fusion$lambda)
    expect_true(fused_score < 0.05)
})

test_that('.directional_coherence() collapses under a strong opposed pair but barely moves for a weak dissenter', {
    strong_up <- make_frag('state_expression', 0.9, significance = 1e-6, direction = 'up', tool_id = 'cluster_dme')
    strong_down <- make_frag('cross_condition_delta', 3, significance = 1e-6, direction = 'down', tool_id = 'pseudobulk_de_limma')
    weak_down <- make_frag('categorical_association', 0.1, significance = 0.5, direction = 'down', tool_id = 'top_genes')

    opposed <- calculate_fusion_score(list(strong_up, strong_down))
    dissent <- calculate_fusion_score(list(strong_up, weak_down))

    expect_true(opposed$c_dir < 0.2)
    expect_true(dissent$c_dir > 0.9)
})

test_that('.directional_coherence() is trivially 1 with at most one directional fragment', {
    lone <- make_frag('state_expression', 0.7, significance = 0.01, direction = 'up', tool_id = 'cluster_dme')
    fusion <- calculate_fusion_score(list(lone))
    expect_equal(fusion$c_dir, 1)
})

test_that('.tool_weight() reads tier from the registry, applies user_weights, and defaults unknown tools to medium', {
    high_frag <- make_frag('state_expression', 0.5, tool_id = 'cluster_dme')
    low_frag <- make_frag('geneset_enrichment', 0.5, tool_id = 'geneset_enrichment')
    unknown_frag <- make_frag('state_expression', 0.5, tool_id = 'not_a_registered_tool')

    expect_equal(.tool_weight(high_frag, list()), 1.0)
    expect_equal(.tool_weight(low_frag, list()), 0.3)
    expect_equal(.tool_weight(unknown_frag, list()), 0.6)
    expect_equal(.tool_weight(high_frag, list(cluster_dme = 0.5)), 0.5)
})

test_that('user_weights = 0 mutes a tool\'s contribution to the pooled evidence', {
    signal_frag <- make_frag('state_expression', 0.9, significance = 1e-6, direction = 'up', tool_id = 'cluster_dme')
    noisy_frag <- make_frag('geneset_enrichment', 0.001, significance = 0.99, direction = 'up', tool_id = 'geneset_enrichment')

    muted <- calculate_fusion_score(list(signal_frag, noisy_frag), user_weights = list(geneset_enrichment = 0))
    full_weight <- calculate_fusion_score(list(signal_frag, noisy_frag))

    expect_equal(muted$matrix$weight[muted$matrix$fragment_id == 'geneset_enrichment'], 0)
    # muting the noisy tool should never leave the pooled evidence any worse
    # than including it at full (nonzero) weight
    expect_true(muted$e_pool >= full_weight$e_pool)
})

test_that('fuse_confidence() flags insufficient_evidence and caps the score when e_evidence is below low_threshold', {
    weak_frag <- make_frag('ranked_genes', 0.05, significance = NA_real_, direction = 'na')
    packet <- build_evidence_packet('MM1', list(weak_frag), input_hash = 'abc')
    interp <- make_confident_interpretation('MM1', packet$packet_hash, model_score = 0.9)
    fused <- fuse_confidence(interp, packet)
    expect_true('insufficient_evidence' %in% unlist(fused$flags))
    expect_true(fused$confidence$score <= 0.35)
})

test_that('fuse_confidence() flags needs_human_review when the model diverges from e_evidence', {
    weak_frag <- make_frag('ranked_genes', 0.05, significance = NA_real_, direction = 'na')
    packet <- build_evidence_packet('MM1', list(weak_frag), input_hash = 'abc')
    interp <- make_confident_interpretation('MM1', packet$packet_hash, model_score = 0.95)
    fused <- fuse_confidence(interp, packet)
    expect_true('needs_human_review' %in% unlist(fused$flags))
})

test_that('fuse_confidence() rationale keeps the deterministic fusion-string shape', {
    signal_frag <- make_frag('state_expression', 0.8, significance = 0.001, direction = 'up', tool_id = 'cluster_dme')
    packet <- build_evidence_packet('MM1', list(signal_frag), input_hash = 'abc')
    interp <- make_confident_interpretation('MM1', packet$packet_hash, model_score = 0.7)
    fused <- fuse_confidence(interp, packet)
    expect_match(
        fused$confidence$rationale,
        '\\[fusion: model=[0-9.]+, evidence=[0-9.]+ \\(E_pool=[0-9.]+, P_agree=[0-9.]+, C_dir=[0-9.]+\\), lambda=[0-9.]+, fused=[0-9.]+\\]$'
    )
})
