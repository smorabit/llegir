## pseudobulk_ModuleSet() + attachment API (docs/milestone_pseudobulk.md
## Part 1): constructor from a raw matrix + metadata and from a
## SummarizedExperiment, decoupleR re-scoring (uniform vs weighted mor),
## validate_moduleset() on standalone and attached objects.

test_that('pseudobulk_ModuleSet() realizes data_level/aggregated/counts correctly', {
    expect_equal(pb_ms$data_level, 'pseudobulk')
    expect_true(pb_ms$aggregated)
    caps <- capabilities(pb_ms)
    expect_true(caps[['counts']])
    expect_true(caps[['module_scores']])
    expect_true(caps[['grouping']])
    expect_true(caps[['sample_ids']])
    # the pseudobulk_ModuleSet is already pseudo-bulk; it doesn't need an
    # attached view, so its own pseudobulk capability stays FALSE
    expect_false(caps[['pseudobulk']])
    expect_identical(dim(counts(pb_ms)), dim(expression(pb_ms)))
})

test_that('pseudobulk_ModuleSet() re-scores modules with decoupleR, not by averaging cell scores', {
    scores <- module_scores(pb_ms)
    expect_true(is.data.frame(scores))
    expect_equal(nrow(scores), ncol(counts(pb_ms)))
    expect_setequal(colnames(scores), c('module_a', 'module_b'))

    # module_a was simulated with 3x the count rate in 'case'; its re-scored
    # activity should track that, while module_b (no simulated signal) shouldn't
    meta <- metadata(pb_ms)
    mean_case <- mean(scores$module_a[meta$condition == 'case'])
    mean_control <- mean(scores$module_a[meta$condition == 'control'])
    expect_true(mean_case > mean_control)
})

test_that('pseudobulk_ModuleSet() maps a gene_table weight column to decoupleR mor', {
    expect_false(has_capability(pb_ms, 'gene_weights'))
    expect_true(all(is.na(gene_membership(pb_ms, 'module_a')$kme)))

    expect_true(has_capability(pb_ms_weighted, 'gene_weights'))
    gm <- gene_membership(pb_ms_weighted, 'module_a')
    expect_false(any(is.na(gm$kme)))
})

test_that('pseudobulk_ModuleSet() builds from a SummarizedExperiment equivalently to matrix + metadata', {
    skip_if_not(se_available, 'SummarizedExperiment not available')
    pb_ms_se <- pseudobulk_ModuleSet(pb_se, pb_gene_sets, group_col = 'condition', sample_col = 'sample')
    expect_equal(pb_ms_se$data_level, 'pseudobulk')
    expect_true(pb_ms_se$aggregated)
    expect_equal(dim(counts(pb_ms_se)), dim(counts(pb_ms)))
    expect_equal(metadata(pb_ms_se)[colnames(pb_fixture$meta)], pb_fixture$meta)
})

test_that('validate_moduleset() passes for a standalone pseudobulk_ModuleSet', {
    expect_true(validate_moduleset(pb_ms))
    expect_true(validate_moduleset(pb_ms_weighted))
})

test_that('with_pseudobulk() attaches a view and flips the pseudobulk capability', {
    expect_false(has_capability(pb_cell_ms, 'pseudobulk'))
    expect_null(pseudobulk(pb_cell_ms))

    attached_ms <- with_pseudobulk(pb_cell_ms, pb_ms)
    expect_true(has_capability(attached_ms, 'pseudobulk'))
    expect_identical(pseudobulk(attached_ms), pb_ms)

    # every other capability still comes from the wrapped cell-level ModuleSet
    cell_caps <- capabilities(pb_cell_ms)
    attached_caps <- capabilities(attached_ms)
    other_names <- setdiff(names(cell_caps), 'pseudobulk')
    expect_equal(attached_caps[other_names], cell_caps[other_names])
})

test_that('pseudobulk_view() resolves standalone, attached, and absent views', {
    expect_identical(pseudobulk_view(pb_ms), pb_ms)

    attached_ms <- with_pseudobulk(pb_cell_ms, pb_ms)
    expect_identical(pseudobulk_view(attached_ms), pb_ms)

    expect_null(pseudobulk_view(pb_cell_ms))
})

test_that('generics on an attached ModuleSet still dispatch to the wrapped adapter', {
    attached_ms <- with_pseudobulk(pb_cell_ms, pb_ms)
    expect_equal(modules(attached_ms), modules(pb_cell_ms))
    expect_equal(gene_membership(attached_ms, 'module_a'), gene_membership(pb_cell_ms, 'module_a'))
    expect_equal(expression(attached_ms), expression(pb_cell_ms))
    expect_equal(metadata(attached_ms), metadata(pb_cell_ms))
})

test_that('validate_moduleset() passes for a cell-level ModuleSet with an attached pseudobulk view', {
    attached_ms <- with_pseudobulk(pb_cell_ms, pb_ms)
    expect_true(validate_moduleset(attached_ms))
})
