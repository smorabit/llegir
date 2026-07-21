## core tools: each must return a fragment that passes validate_evidence_fragment
## and carries the right `type`, run against a real module from the CSF object.

test_that('top_genes_tool() returns a valid ranked_genes fragment', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(n_hubs = 10))
    frag <- top_genes_tool(ctx)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'ranked_genes')
    expect_equal(nrow(frag$result), 10)
    expect_true(all(c('gene_name', 'kme') %in% colnames(frag$result)))
})

test_that('cluster_dme_tool() returns a valid state_expression fragment', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(group_by = 'lv2_annot'))
    frag <- cluster_dme_tool(ctx)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'state_expression')
    expect_true(frag$effect_strength >= 0)
    expect_true(frag$direction %in% c('up', 'down'))
})

test_that('cluster_dme_tool() errors without group_by', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = ms_test, module_id = mod_test, params = list())
    expect_error(cluster_dme_tool(ctx), 'group_by')
})

test_that('geneset_enrichment_tool() returns a valid geneset_enrichment fragment', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(n_hubs = 25, db_files = test_db_files))
    frag <- geneset_enrichment_tool(ctx)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'geneset_enrichment')
    expect_true(frag$effect_strength >= 0)
})

test_that('geneset_enrichment_tool() is deterministic across repeated runs', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(n_hubs = 25, db_files = test_db_files))
    frag_a <- geneset_enrichment_tool(ctx)
    frag_b <- geneset_enrichment_tool(ctx)
    expect_equal(frag_a$result, frag_b$result)
    expect_equal(frag_a$effect_strength, frag_b$effect_strength)
})
