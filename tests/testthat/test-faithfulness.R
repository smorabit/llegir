## faithfulness auto-check (docs/milestone_2.md task 3): fabricated
## fragment_ids and direction mismatches must be caught, not waved through.

# geneset_enrichment reports 'up' only when a term passes FDR < 0.05, so the
# faithful fixture reads the direction back from the packet it cites
packet_direction <- function(packet, fragment_id){
    Filter(function(f) f$fragment_id == fragment_id, packet$fragments)[[1]]$direction
}

make_faithful_interpretation <- function(packet){
    interpretation(
        module_id = packet$module_id,
        proposed_label = 'x', dominant_biology = 'x', interpretation = 'x',
        supporting_claims = list(
            list(claim = 'top genes claim', fragment_ids = 'top_genes', direction = 'na'),
            list(claim = 'gene-set overlap claim', fragment_ids = 'geneset_enrichment',
                 direction = packet_direction(packet, 'geneset_enrichment'))
        ),
        confidence = list(score = 0.7, model_score = 0.7, rationale = 'x'),
        provenance = make_interpretation_provenance('mock', '0.1', 0, packet$packet_hash)
    )
}

test_that('check_faithfulness() finds no violations for correctly-cited claims', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    packet <- run_module(ms_test, mod_test, csf_tool_config, input_hash = 'abc')
    interp <- make_faithful_interpretation(packet)
    expect_equal(check_faithfulness(interp, packet), list())
    expect_true(is_faithful(interp, packet))
    expect_true(assert_faithfulness(interp, packet))
})

test_that('check_faithfulness() only inspects supporting_claims', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    packet <- run_module(ms_test, mod_test, csf_tool_config, input_hash = 'abc')
    interp <- make_faithful_interpretation(packet)
    # a stray field the model can no longer emit must not be walked
    interp$metadata_associations <- list(list(fragment_id = 'not_a_real_fragment'))
    expect_equal(check_faithfulness(interp, packet), list())
})

test_that('a fabricated fragment_id in supporting_claims is caught', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    packet <- run_module(ms_test, mod_test, csf_tool_config, input_hash = 'abc')
    interp <- make_faithful_interpretation(packet)
    interp$supporting_claims[[1]]$fragment_ids <- 'not_a_real_fragment'

    violations <- check_faithfulness(interp, packet)
    expect_equal(length(violations), 1)
    expect_equal(violations[[1]]$issue, 'missing_fragment')
    expect_false(is_faithful(interp, packet))
    expect_error(assert_faithfulness(interp, packet), 'missing_fragment')

    flagged <- enforce_faithfulness(interp, packet)
    expect_true('needs_human_review' %in% unlist(flagged$flags))
})

test_that('a wrong claim direction is caught', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    packet <- run_module(ms_test, mod_test, csf_tool_config, input_hash = 'abc')
    interp <- make_faithful_interpretation(packet)
    # geneset_enrichment is never direction 'down' ('up' or 'na'); claiming 'down' is a mismatch
    interp$supporting_claims[[2]]$direction <- 'down'

    violations <- check_faithfulness(interp, packet)
    expect_equal(length(violations), 1)
    expect_equal(violations[[1]]$issue, 'direction_mismatch')
    expect_equal(violations[[1]]$fragment_direction, packet_direction(packet, 'geneset_enrichment'))
    expect_error(assert_faithfulness(interp, packet), 'direction_mismatch')

    flagged <- enforce_faithfulness(interp, packet)
    expect_true('needs_human_review' %in% unlist(flagged$flags))
})

test_that('enforce_faithfulness() leaves flags untouched when the interpretation is faithful', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    packet <- run_module(ms_test, mod_test, csf_tool_config, input_hash = 'abc')
    interp <- make_faithful_interpretation(packet)
    flagged <- enforce_faithfulness(interp, packet)
    expect_equal(unlist(flagged$flags), unlist(interp$flags))
})

test_that('mock_backend() synthesis output passes the faithfulness check against a real packet', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    packet <- run_module(ms_test, mod_test, csf_tool_config, input_hash = 'abc')
    interp <- synthesize_interpretation(packet, csf_dataset_description(), backend = mock_backend(), schema_path = test_schema_path)
    expect_true(is_faithful(interp, packet))
})

## significance wording: "significant"/"enriched" must be backed by a cited
## fragment below alpha. Hand-built fragments, so these run without the CSF object.

make_wording_packet <- function(overlap_fdr = 1){
    top <- evidence_fragment(
        fragment_id = 'top_genes', tool_id = 'top_genes', module_id = 'MM1', type = 'ranked_genes',
        result = data.frame(gene_name = c('ZSWIM6', 'PPP3CA'), kme = c(0.7, 0.6)),
        compact_summary = 'top genes', top_findings = list(), effect_strength = 0.7,
        direction = 'na', provenance = make_provenance('0.1')
    )
    overlap <- import_fragment(
        module_id = 'MM1', type = 'geneset_enrichment', fragment_id = 'cancersea_overlap',
        result = data.frame(
            modules2 = c('DNA_damage', 'Apoptosis'), odds_ratio = c(4.05, 3.31),
            fdr = c(overlap_fdr, 1), size_intersection = c(2, 1), Jaccard = c(0.01, 0.005)
        ),
        params = list(term_col = 'modules2')
    )
    build_evidence_packet('MM1', list(top, overlap), input_hash = 'wording')
}

make_wording_interpretation <- function(text, claim, direction = 'na'){
    interpretation(
        module_id = 'MM1', proposed_label = 'x', dominant_biology = 'x', interpretation = text,
        supporting_claims = list(
            list(claim = 'hub genes ZSWIM6 and PPP3CA', fragment_ids = 'top_genes', direction = 'na'),
            list(claim = claim, fragment_ids = 'cancersea_overlap', direction = direction)
        ),
        confidence = list(score = 0.5, model_score = 0.5, rationale = 'x'),
        provenance = make_interpretation_provenance('mock', '0.1', 0, 'wording')
    )
}

test_that('significance wording citing a non-significant enrichment fragment is caught', {
    packet <- make_wording_packet()
    interp <- make_wording_interpretation(
        text = 'The hub genes suggest a stress program. This is supported by the significant enrichment of DNA damage terms in the CancerSEA overlap fragment.',
        claim = 'significant enrichment of DNA_damage in cancersea_overlap'
    )
    violations <- check_faithfulness(interp, packet)
    issues <- vapply(violations, function(v) paste(v$location, v$index, v$issue), character(1))
    expect_setequal(issues, c('supporting_claims 2 unsupported_significance', 'interpretation 2 unsupported_significance'))
    expect_false(is_faithful(interp, packet))
    expect_error(assert_faithfulness(interp, packet), 'unsupported_significance')
    expect_true('needs_human_review' %in% unlist(enforce_faithfulness(interp, packet)$flags))
})

test_that('unnamed enrichment wording in the interpretation falls back to geneset_enrichment fragments', {
    packet <- make_wording_packet()
    interp <- make_wording_interpretation(
        text = 'Apoptosis terms are enriched among the hub genes.',
        claim = 'a weak overlap with DNA_damage'
    )
    violations <- check_faithfulness(interp, packet)
    expect_equal(length(violations), 1)
    expect_equal(violations[[1]]$location, 'interpretation')
    expect_equal(violations[[1]]$fragment_id, 'cancersea_overlap')
})

test_that('negated significance wording is allowed', {
    packet <- make_wording_packet()
    interp <- make_wording_interpretation(
        text = 'The CancerSEA overlap is not significant, and no term reaches significant enrichment; a non-significant 2-gene overlap with DNA_damage is descriptive only.',
        claim = 'a non-significant 2-gene overlap with DNA_damage, no significant enrichment'
    )
    expect_equal(check_faithfulness(interp, packet), list())
})

test_that('significance wording is allowed when the cited fragment passes alpha', {
    packet <- make_wording_packet(overlap_fdr = 0.001)
    interp <- make_wording_interpretation(
        text = 'DNA damage terms are significantly enriched in the cancersea_overlap fragment.',
        claim = 'significant enrichment of DNA_damage', direction = 'up'
    )
    expect_equal(check_faithfulness(interp, packet), list())
    # a stricter alpha turns the same wording into a violation
    expect_false(is_faithful(interp, packet, alpha = 1e-4))
})

test_that('enrichment wording that cites only an untested ranked_genes fragment is not flagged', {
    packet <- make_wording_packet()
    interp <- make_wording_interpretation(text = 'x', claim = 'a weak overlap')
    interp$supporting_claims[[1]]$claim <- 'the hub genes are enriched for calcineurin signalling components'
    expect_equal(check_faithfulness(interp, packet), list())
})
