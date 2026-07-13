## core tools: each must return a fragment that passes validate_evidence_fragment
## and carries the right `type`, run against a real module from the CSF object.

test_that('hub_genes_tool() returns a valid ranked_genes fragment', {
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(n_hubs = 10))
    frag <- hub_genes_tool(ctx)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'ranked_genes')
    expect_equal(nrow(frag$result), 10)
    expect_true(all(c('gene_name', 'kme') %in% colnames(frag$result)))
})

test_that('cluster_dme_tool() returns a valid state_expression fragment', {
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(group_by = 'lv2_annot'))
    frag <- cluster_dme_tool(ctx)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'state_expression')
    expect_true(frag$effect_strength >= 0)
    expect_true(frag$direction %in% c('up', 'down'))
})

test_that('cluster_dme_tool() errors without group_by', {
    ctx <- list(ms = ms_test, module_id = mod_test, params = list())
    expect_error(cluster_dme_tool(ctx), 'group_by')
})

test_that('module_by_metadata_tool() returns a valid categorical_association fragment', {
    ctx <- list(ms = ms_test, module_id = mod_test,
                params = list(column = 'diagnosis', column_type = 'categorical'))
    frag <- module_by_metadata_tool(ctx)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'categorical_association')
    expect_equal(frag$fragment_id, 'metadata::diagnosis')
})

test_that('module_by_metadata_tool() errors on an unknown column', {
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(column = 'not_a_column'))
    expect_error(module_by_metadata_tool(ctx), 'not found')
})

test_that('module_by_metadata_tool() auto-selects sample-level testing for a sample-constant variable', {
    # diagnosis is constant within every sample in the CSF object (verified against
    # the raw meta.data), so 'auto' should pick 'sample', not the pseudoreplicated 'cell'
    ctx <- list(ms = ms_test, module_id = mod_test,
                params = list(column = 'diagnosis', column_type = 'categorical'))
    frag <- module_by_metadata_tool(ctx)
    expect_equal(frag$provenance$params$level, 'sample')
    expect_equal(frag$provenance$params$n_units, length(unique(metadata(ms_test)$sample)))
})

test_that('module_by_metadata_tool() sample-level test is more conservative than cell-level on the same variable', {
    cell_ctx <- list(ms = ms_test, module_id = mod_test,
                      params = list(column = 'diagnosis', column_type = 'categorical', level = 'cell'))
    sample_ctx <- list(ms = ms_test, module_id = mod_test,
                        params = list(column = 'diagnosis', column_type = 'categorical', level = 'sample'))
    cell_frag <- module_by_metadata_tool(cell_ctx)
    sample_frag <- module_by_metadata_tool(sample_ctx)
    expect_equal(cell_frag$provenance$params$level, 'cell')
    expect_equal(sample_frag$provenance$params$level, 'sample')
    # cell-level pseudoreplicates (thousands of correlated cells); sample-level
    # collapses to n=15 samples first, so its omnibus p-value should not be smaller
    expect_true(sample_frag$significance >= cell_frag$significance)
})

test_that('module_by_metadata_tool() treats sample_col itself as descriptive, not a group test', {
    ctx <- list(ms = ms_test, module_id = mod_test,
                params = list(column = 'sample', column_type = 'categorical'))
    frag <- module_by_metadata_tool(ctx)
    expect_true(validate_evidence_fragment(frag))
    expect_true(is.na(frag$significance))
    expect_equal(frag$direction, 'na')
    expect_true(all(c('sample', 'mean_score') %in% colnames(frag$result)))
    expect_equal(nrow(frag$result), length(unique(metadata(ms_test)$sample)))
})

test_that('geneset_enrichment_tool() returns a valid geneset_enrichment fragment', {
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(n_hubs = 25, db_files = test_db_files))
    frag <- geneset_enrichment_tool(ctx)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'geneset_enrichment')
    expect_true(frag$effect_strength >= 0)
})

test_that('geneset_enrichment_tool() is deterministic across repeated runs', {
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(n_hubs = 25, db_files = test_db_files))
    frag_a <- geneset_enrichment_tool(ctx)
    frag_b <- geneset_enrichment_tool(ctx)
    expect_equal(frag_a$result, frag_b$result)
    expect_equal(frag_a$effect_strength, frag_b$effect_strength)
})
