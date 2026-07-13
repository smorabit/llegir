## import_fragment (milestone 1.5 task 3): user-supplied result tables
## normalized into valid evidence_fragments, tagged provenance.source =
## 'user_supplied'. No ModuleSet dependency here -- these operate on tables
## directly.

test_that('import_fragment() normalizes a geneset_enrichment table and tags it user_supplied', {
    user_table <- data.frame(
        term = c('Interferon Response', 'Dendritic Cell Activation', 'Cell Cycle'),
        odds_ratio = c(12.5, 8.1, 1.2),
        fdr = c(0.001, 0.02, 0.6)
    )
    frag <- import_fragment(module_id = 'MM1', type = 'geneset_enrichment', result = user_table)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'geneset_enrichment')
    expect_equal(frag$provenance$source, 'user_supplied')
    expect_equal(frag$direction, 'up')
    expect_equal(frag$significance, 0.001)
    expect_equal(frag$top_findings[[1]]$term, 'Interferon Response')
})

test_that('import_fragment() normalizes a categorical_association table (e.g. a pre-computed DME)', {
    user_table <- data.frame(
        group = c('pDC', 'Monocyte', 'Macrophage'),
        rank_biserial = c(0.71, -0.10, -0.30),
        fdr = c(0.001, 0.5, 0.2)
    )
    frag <- import_fragment(module_id = 'MM1', type = 'categorical_association', result = user_table)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$provenance$source, 'user_supplied')
    expect_equal(frag$direction, 'up')
    expect_equal(frag$effect_strength, 0.71)
})

test_that('import_fragment() respects custom column names via params', {
    user_table <- data.frame(pathway = c('A', 'B'), OR = c(5, 2), padj = c(0.01, 0.3))
    frag <- import_fragment(
        module_id = 'MM1', type = 'geneset_enrichment', result = user_table,
        params = list(term_col = 'pathway', effect_col = 'OR', significance_col = 'padj')
    )
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$top_findings[[1]]$term, 'A')
})

test_that('import_fragment() errors on an unsupported type', {
    expect_error(
        import_fragment(module_id = 'MM1', type = 'signature_correlation', result = data.frame(x = 1)),
        'no normalizer'
    )
})

test_that('import_fragment() errors on a missing required column', {
    expect_error(
        import_fragment(module_id = 'MM1', type = 'geneset_enrichment', result = data.frame(term = 'A')),
        'missing columns'
    )
})

test_that('import_fragment_tool() flows through the orchestrator unchanged', {
    user_table <- data.frame(
        term = c('Interferon Response', 'Cell Cycle'),
        odds_ratio = c(9, 1),
        fdr = c(0.01, 0.8)
    )
    tool_config <- list(
        list(fn = hub_genes_tool, params = list(n_hubs = 5)),
        list(fn = import_fragment_tool, params = list(type = 'geneset_enrichment', result = user_table))
    )
    packet <- run_module(ms_test, mod_test, tool_config)
    expect_equal(length(packet$fragments), 2)
    imported <- packet$fragments[[2]]
    expect_true(validate_evidence_fragment(imported))
    expect_equal(imported$provenance$source, 'user_supplied')
})
