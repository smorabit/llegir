## confidence fusion (docs/milestone_2.md task 4), evaluated on the M1
## spike-in controls: the deterministic evidence signals alone must separate
## the pDC positive control from the random negative control, independent of
## what the (mocked) model says -- this is the guardrail against a
## confidently-narrated random gene set.

make_confident_interpretation <- function(module_id, packet_hash, model_score = 0.9){
    interpretation(
        module_id = module_id, proposed_label = 'x', one_line_summary = 'x', dominant_biology = 'x',
        supporting_claims = list(list(claim = 'x', fragment_ids = 'hub_genes', direction = 'na')),
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

test_that('fuse_confidence() flags possible_artifact when hub genes are dominated by IEG/dissociation markers', {
    ieg_hub <- evidence_fragment(
        fragment_id = 'hub_genes', tool_id = 'hub_genes', module_id = 'MM1', type = 'ranked_genes',
        result = data.frame(gene_name = c('FOS', 'JUN', 'EGR1', 'NR4A1', 'DUSP1', 'GENE6', 'GENE7', 'GENE8', 'GENE9', 'GENE10'), kme = 0.5),
        compact_summary = 'x', top_findings = list(), effect_strength = 0.5, provenance = make_provenance('0.1')
    )
    packet <- build_evidence_packet('MM1', list(ieg_hub), input_hash = 'abc')
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
