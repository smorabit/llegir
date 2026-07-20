## pseudobulk_de_limma_tool: gene-level limma-voom DE within a module
## (docs/milestones/milestone_pseudobulk.md Part 4). Reuses pb_ms
## (synthetic_pseudobulk.R): module_a's genes are simulated with a uniform 3x
## count rate in 'case' vs 'control', module_b's carry none.

test_that('pseudobulk_de_limma_tool() requires params$contrast_col', {
    expect_error(pseudobulk_de_limma_tool(list(ms = pb_ms, module_id = 'module_a', params = list())), 'contrast_col')
})

test_that('pseudobulk_de_limma_tool() skips gracefully without a resolvable pseudo-bulk view', {
    expect_null(pseudobulk_view(pb_cell_ms))
    ctx <- list(ms = pb_cell_ms, module_id = modules(pb_cell_ms)[1], params = list(contrast_col = 'diagnosis'))
    expect_message(result <- pseudobulk_de_limma_tool(ctx), 'skipped')
    expect_null(result)
})

test_that('pseudobulk_de_limma_tool() skips gracefully when the pseudo-bulk view lacks counts', {
    no_counts_pb <- components_ModuleSet(
        data.frame(module = 'module_a', gene_name = pb_gene_sets$module_a),
        expression = pb_fixture$counts, metadata = pb_fixture$meta,
        group_col = 'condition', sample_col = 'sample', data_level = 'pseudobulk', aggregated = TRUE
    )
    expect_false(has_capability(no_counts_pb, 'counts'))
    attached_ms <- with_pseudobulk(pb_cell_ms, no_counts_pb)
    expect_false(is.null(pseudobulk_view(attached_ms)))

    ctx <- list(ms = attached_ms, module_id = modules(pb_cell_ms)[1], params = list(contrast_col = 'condition'))
    expect_message(result <- pseudobulk_de_limma_tool(ctx), 'skipped')
    expect_null(result)
})

test_that('pseudobulk_de_limma_tool() skips gracefully when contrast_col is missing from pseudo-bulk metadata', {
    ctx <- list(ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'not_a_real_column'))
    expect_message(result <- pseudobulk_de_limma_tool(ctx), 'skipped')
    expect_null(result)
})

test_that('pseudobulk_de_limma_tool() skips gracefully when none of the module\'s genes are in pseudo-bulk counts', {
    # pb_cell_ms's own modules use GENE1..GENE20 (example_moduleset.R), disjoint
    # from pb_ms's PBGENEA*/PBGENEB* genes -- a genuine gene-panel mismatch
    attached_ms <- with_pseudobulk(pb_cell_ms, pb_ms)
    ctx <- list(ms = attached_ms, module_id = modules(pb_cell_ms)[1], params = list(contrast_col = 'condition'))
    expect_message(result <- pseudobulk_de_limma_tool(ctx), 'skipped')
    expect_null(result)
})

test_that('pseudobulk_de_limma_tool() skips gracefully when no gene survives the low-count filter', {
    ctx <- list(ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'condition', min_count = 1e6))
    expect_message(result <- pseudobulk_de_limma_tool(ctx), 'skipped')
    expect_null(result)
})

test_that('pseudobulk_de_limma_tool() finds module_a genes differentially expressed across condition', {
    frag <- pseudobulk_de_limma_tool(list(ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'condition')))
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'cross_condition_delta')
    expect_true(all(frag$result$gene_name %in% pb_gene_sets$module_a))
    expect_true(all(c('gene_name', 'logFC', 'P.Value', 'adj.P.Val') %in% colnames(frag$result)))
    expect_true(frag$significance < 0.01)
    # 'case' is the reference level (alphabetically first); module_a's count
    # rate is 3x higher there, so 'control' vs 'case' is a real negative delta
    expect_equal(frag$direction, 'down')
})

test_that('pseudobulk_de_limma_tool() shows a much weaker effect for module_b (no simulated signal)', {
    frag_a <- pseudobulk_de_limma_tool(list(ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'condition')))
    frag_b <- pseudobulk_de_limma_tool(list(ms = pb_ms, module_id = 'module_b', params = list(contrast_col = 'condition')))
    expect_true(frag_b$significance > frag_a$significance)
    expect_true(frag_b$effect_strength < frag_a$effect_strength)
})

test_that('pseudobulk_de_limma_tool() accepts an optional covariate without erroring', {
    frag <- pseudobulk_de_limma_tool(list(
        ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'condition', covariates = 'n_cells')
    ))
    expect_true(validate_evidence_fragment(frag))
})

test_that('pseudobulk_de_limma_tool() is registered and runs end to end through run_module()', {
    expect_true('pseudobulk_de_limma' %in% list_tools())
    packet <- run_module(
        pb_ms, 'module_a',
        list(list(id = 'pseudobulk_de_limma', params = list(contrast_col = 'condition'))),
        input_hash = 'pbde_test'
    )
    expect_equal(length(packet$fragments), 1)
    expect_true(validate_evidence_fragment(packet$fragments[[1]]))
    expect_equal(packet$fragments[[1]]$tool_id, 'pseudobulk_de_limma')
})
