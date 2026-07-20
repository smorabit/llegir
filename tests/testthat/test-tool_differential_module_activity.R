## differential_module_activity_tool: the module-level DME successor
## (docs/milestones/milestone_pseudobulk.md Part 3), run on pseudobulk_view(ms).
## Reuses pb_ms/pb_gene_sets (synthetic_pseudobulk.R): module_a is simulated
## with a 3x count rate in 'case' vs 'control' (a real 2-level signal),
## module_b carries none. A separate 3-level mock fixture below exercises the
## multi-level -> categorical_association path.

test_that('differential_module_activity_tool() skips gracefully without a resolvable pseudo-bulk view', {
    expect_null(pseudobulk_view(pb_cell_ms))
    ctx <- list(ms = pb_cell_ms, module_id = modules(pb_cell_ms)[1], params = list(contrast_col = 'diagnosis'))
    expect_message(result <- differential_module_activity_tool(ctx), 'skipped')
    expect_null(result)
})

test_that('differential_module_activity_tool() skips gracefully when contrast_col is missing from pseudo-bulk metadata', {
    ctx <- list(ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'not_a_real_column'))
    expect_message(result <- differential_module_activity_tool(ctx), 'skipped')
    expect_null(result)
})

test_that('differential_module_activity_tool() requires params$contrast_col', {
    ctx <- list(ms = pb_ms, module_id = 'module_a', params = list())
    expect_error(differential_module_activity_tool(ctx), 'contrast_col')
})

test_that('differential_module_activity_tool() (limma) finds module_a differential across condition', {
    frag <- differential_module_activity_tool(list(
        ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'condition', method = 'limma')
    ))
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'cross_condition_delta')
    # 'case' sorts alphabetically first -> the reference level; module_a's
    # count rate is 3x higher there (synthetic_pseudobulk.R), so 'control'
    # (group2) vs 'case' (group1, the reference) is a real, negative delta
    expect_equal(frag$result$group1, 'case')
    expect_equal(frag$result$group2, 'control')
    expect_equal(frag$direction, 'down')
    expect_true(frag$significance < 0.05)
    expect_true(all(c('group1', 'group2', 'effect', 'p_value', 'fdr') %in% colnames(frag$result)))
})

test_that('differential_module_activity_tool() (nonparametric) finds module_a differential across condition', {
    frag <- differential_module_activity_tool(list(
        ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'condition', method = 'nonparametric')
    ))
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'cross_condition_delta')
    expect_equal(frag$direction, 'down')
})

test_that('differential_module_activity_tool() shows a weaker effect for module_b (no simulated signal)', {
    frag_a <- differential_module_activity_tool(list(
        ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'condition')
    ))
    frag_b <- differential_module_activity_tool(list(
        ms = pb_ms, module_id = 'module_b', params = list(contrast_col = 'condition')
    ))
    expect_true(frag_b$effect_strength < frag_a$effect_strength)
})

test_that('differential_module_activity_tool() (limma) caches the fit across the per-module loop', {
    differential_module_activity_tool(list(ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'condition')))
    n_after_first <- length(ls(.dma_fit_cache))

    differential_module_activity_tool(list(ms = pb_ms, module_id = 'module_b', params = list(contrast_col = 'condition')))
    n_after_second <- length(ls(.dma_fit_cache))
    # same scores matrix + design as the module_a call above -> same cache key, no new entry
    expect_equal(n_after_second, n_after_first)
})

test_that('differential_module_activity_tool() accepts an optional covariate without erroring', {
    frag <- differential_module_activity_tool(list(
        ms = pb_ms, module_id = 'module_a',
        params = list(contrast_col = 'condition', covariates = 'n_cells')
    ))
    expect_true(validate_evidence_fragment(frag))
})

test_that('differential_module_activity_tool() is registered and runs end to end through run_module()', {
    expect_true('differential_module_activity' %in% list_tools())
    packet <- run_module(
        pb_ms, 'module_a',
        list(list(id = 'differential_module_activity', params = list(contrast_col = 'condition'))),
        input_hash = 'dma_test'
    )
    expect_equal(length(packet$fragments), 1)
    expect_true(validate_evidence_fragment(packet$fragments[[1]]))
    expect_equal(packet$fragments[[1]]$tool_id, 'differential_module_activity')
})

## a 3-level mock pseudo-bulk fixture, built the same way as pb_fixture
## (synthetic_pseudobulk.R) but with a 3-level contrast, to exercise the
## multi-level -> categorical_association path
.dma_three_level_fixture <- function(seed = 3, n_per_level = 4){
    set.seed(seed)
    n_samples <- n_per_level * 3
    # label prefixes keep alphabetical order == biological (lambda) order, so
    # 'c1_low' is the reference level and effects vs it read as increasing
    condition <- rep(c('c1_low', 'c2_mid', 'c3_high'), each = n_per_level)
    sample_id <- paste0('dmasample', seq_len(n_samples))

    base_lambda <- 200
    lambda_a <- base_lambda * c(c1_low = 1, c2_mid = 2, c3_high = 4)[condition]

    gene_counts <- function(lambda_vec, n_genes){
        t(vapply(seq_len(n_genes), function(i) stats::rpois(n_samples, lambda_vec), numeric(n_samples)))
    }

    counts <- rbind(
        gene_counts(lambda_a, length(pb_gene_sets$module_a)),
        gene_counts(rep(base_lambda, n_samples), length(pb_gene_sets$module_b))
    )
    rownames(counts) <- c(pb_gene_sets$module_a, pb_gene_sets$module_b)
    colnames(counts) <- sample_id
    meta <- data.frame(sample = sample_id, condition = condition, row.names = sample_id)
    list(counts = counts, meta = meta)
}

dma_three_level <- .dma_three_level_fixture()
dma_pb_ms_three_level <- pseudobulk_ModuleSet(
    dma_three_level$counts, pb_gene_sets, dma_three_level$meta, group_col = 'condition', sample_col = 'sample'
)

test_that('differential_module_activity_tool() (limma) handles a multi-level contrast as categorical_association', {
    frag <- differential_module_activity_tool(list(
        ms = dma_pb_ms_three_level, module_id = 'module_a', params = list(contrast_col = 'condition', method = 'limma')
    ))
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'categorical_association')
    expect_setequal(frag$result$group, c('c1_low', 'c2_mid', 'c3_high'))
    expect_true(is.numeric(frag$significance))
    expect_equal(frag$direction, 'up')
})

test_that('differential_module_activity_tool() (nonparametric) handles a multi-level contrast as categorical_association', {
    frag <- differential_module_activity_tool(list(
        ms = dma_pb_ms_three_level, module_id = 'module_a',
        params = list(contrast_col = 'condition', method = 'nonparametric')
    ))
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'categorical_association')
    expect_setequal(frag$result$group, c('c1_low', 'c2_mid', 'c3_high'))
})
