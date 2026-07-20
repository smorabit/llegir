## faithfulness auto-check (docs/milestone_2.md task 3): fabricated
## fragment_ids and direction mismatches must be caught, not waved through.

make_faithful_interpretation <- function(packet){
    interpretation(
        module_id = packet$module_id,
        proposed_label = 'x', one_line_summary = 'x', dominant_biology = 'x',
        supporting_claims = list(
            list(claim = 'hub genes claim', fragment_ids = 'hub_genes', direction = 'na'),
            list(claim = 'enrichment claim', fragment_ids = 'geneset_enrichment', direction = 'up')
        ),
        metadata_associations = list(
            list(variable = 'cell_state', summary = 'x', fragment_id = 'cluster_dme')
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
    # geneset_enrichment is always direction 'up' (docs/milestone_1_5.md); claiming 'down' is a mismatch
    interp$supporting_claims[[2]]$direction <- 'down'

    violations <- check_faithfulness(interp, packet)
    expect_equal(length(violations), 1)
    expect_equal(violations[[1]]$issue, 'direction_mismatch')
    expect_equal(violations[[1]]$fragment_direction, 'up')
    expect_error(assert_faithfulness(interp, packet), 'direction_mismatch')

    flagged <- enforce_faithfulness(interp, packet)
    expect_true('needs_human_review' %in% unlist(flagged$flags))
})

test_that('a fabricated fragment_id in metadata_associations is caught', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    packet <- run_module(ms_test, mod_test, csf_tool_config, input_hash = 'abc')
    interp <- make_faithful_interpretation(packet)
    interp$metadata_associations[[1]]$fragment_id <- 'metadata::not_a_real_column'

    violations <- check_faithfulness(interp, packet)
    expect_equal(length(violations), 1)
    expect_equal(violations[[1]]$location, 'metadata_associations')
    expect_equal(violations[[1]]$issue, 'missing_fragment')
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
