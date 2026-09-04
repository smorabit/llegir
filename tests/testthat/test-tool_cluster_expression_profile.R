## cluster_expression_profile_tool: non-differential companion to
## cluster_dme_tool, against llegir_example_moduleset() (grouping +
## module_scores capabilities, group_by = 'cell_type').

test_that('cluster_expression_profile_tool() returns a valid state_expression fragment', {
    ms <- llegir_example_moduleset()
    ctx <- list(ms = ms, module_id = modules(ms)[1], params = list(group_by = 'cell_type'))
    frag <- cluster_expression_profile_tool(ctx)

    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'state_expression')
    expect_equal(frag$fragment_id, 'cluster_expression_profile')

    n_states <- length(unique(metadata(ms)$cell_type))
    expect_equal(nrow(frag$result), n_states)

    n_deciles <- 10
    expect_true(all(frag$result$mean_decile >= 1 & frag$result$mean_decile <= n_deciles))
    expect_true(frag$effect_strength >= 0 && frag$effect_strength <= 1)
    expect_equal(frag$direction, 'na')
})

test_that('cluster_expression_profile_tool() requires params$group_by', {
    ms <- llegir_example_moduleset()
    ctx <- list(ms = ms, module_id = modules(ms)[1], params = list())
    expect_error(cluster_expression_profile_tool(ctx), 'group_by')
})

test_that('cluster_expression_profile_tool() skips gracefully without grouping/module_scores', {
    ms <- llegir_example_moduleset()
    bare_ms <- components_ModuleSet(
        gene_table = data.frame(module = 'module_a', gene_name = c('GENE1', 'GENE2')),
        metadata = metadata(ms)
    )
    expect_false(has_capability(bare_ms, 'grouping'))
    expect_false(has_capability(bare_ms, 'module_scores'))

    ctx <- list(ms = bare_ms, module_id = 'module_a', params = list(group_by = 'cell_type'))
    expect_message(result <- cluster_expression_profile_tool(ctx), 'skipped')
    expect_null(result)
})
