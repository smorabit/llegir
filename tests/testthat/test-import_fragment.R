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
    skip_if_not(csf_data_available, 'CSF dev object not available')
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

## milestone_extensibility Part 3: format-specific importers with sensible
## per-format defaults (Seurat/DESeq2/edgeR DE tables, hdWGCNA DME, EnrichR/
## GeneOverlap enrichment), all funneling through import_fragment().

test_that('import_fragment() normalizes a cross_condition_delta table (gene-level DE contrast)', {
    user_table <- data.frame(
        gene = c('IFIT3', 'ISG15', 'ACTB'),
        log2FC = c(2.1, 1.8, 0.05),
        padj = c(0.001, 0.01, 0.9)
    )
    frag <- import_fragment(module_id = 'MM1', type = 'cross_condition_delta', result = user_table)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'cross_condition_delta')
    expect_equal(frag$provenance$source, 'user_supplied')
    expect_equal(frag$direction, 'up')
    expect_equal(frag$significance, 0.001)
    expect_equal(frag$top_findings[[1]]$feature, 'IFIT3')
})

test_that('import_fragment() falls back to rownames for cross_condition_delta feature_col', {
    user_table <- data.frame(log2FC = c(-2.5, 0.1), padj = c(0.002, 0.7), row.names = c('CX3CR1', 'ACTB'))
    frag <- import_fragment(module_id = 'MM1', type = 'cross_condition_delta', result = user_table)
    expect_equal(frag$top_findings[[1]]$feature, 'CX3CR1')
    expect_equal(frag$direction, 'down')
})

test_that('import_fragment() normalizes a state_expression table (e.g. an externally-run DME)', {
    user_table <- data.frame(
        group = c('pDC', 'Monocyte', 'Macrophage'),
        avg_log2FC = c(1.4, -0.2, -0.5),
        p_val_adj = c(0.001, 0.5, 0.2)
    )
    frag <- import_fragment(module_id = 'MM1', type = 'state_expression', result = user_table)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'state_expression')
    expect_equal(frag$provenance$source, 'user_supplied')
    expect_equal(frag$direction, 'up')
    expect_equal(frag$effect_strength, 1.4)
})

test_that('import_seurat_markers() defaults to Seurat FindMarkers column names and yields cross_condition_delta with no group_col', {
    user_table <- data.frame(
        gene = c('IFIT3', 'ACTB'),
        avg_log2FC = c(2.0, 0.02),
        p_val_adj = c(0.001, 0.95)
    )
    frag <- import_seurat_markers(module_id = 'MM1', result = user_table)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'cross_condition_delta')
    expect_equal(frag$provenance$source, 'user_supplied')
    expect_equal(frag$provenance$params$effect_col, 'avg_log2FC')
})

test_that('import_seurat_markers() yields categorical_association when a group_col is present (e.g. FindAllMarkers)', {
    user_table <- data.frame(
        gene = c('IFIT3', 'RPL13', 'CX3CR1'),
        cluster = c('pDC', 'Monocyte', 'Macrophage'),
        avg_log2FC = c(2.0, 1.5, -0.8),
        p_val_adj = c(0.001, 0.02, 0.3)
    )
    frag <- import_seurat_markers(module_id = 'MM1', result = user_table)
    expect_equal(frag$type, 'categorical_association')
    expect_equal(frag$provenance$params$group_col, 'cluster')
})

test_that('import_seurat_markers() reuses the same importer for a DESeq2 table via column_map', {
    user_table <- data.frame(
        gene = c('IFIT3', 'ACTB'),
        log2FoldChange = c(1.9, -0.1),
        padj = c(0.003, 0.8)
    )
    frag <- import_seurat_markers(
        module_id = 'MM1', result = user_table,
        column_map = list(effect_col = 'log2FoldChange', significance_col = 'padj')
    )
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'cross_condition_delta')
    expect_equal(frag$direction, 'up')
})

test_that('import_seurat_markers() reuses the same importer for an edgeR table via column_map', {
    user_table <- data.frame(
        gene = c('IFIT3', 'ACTB'),
        logFC = c(-1.6, 0.05),
        FDR = c(0.004, 0.9)
    )
    frag <- import_seurat_markers(
        module_id = 'MM1', result = user_table,
        column_map = list(effect_col = 'logFC', significance_col = 'FDR')
    )
    expect_equal(frag$direction, 'down')
})

test_that('import_hdwgcna_dme() defaults to hdWGCNA FindAllDMEs column names', {
    user_table <- data.frame(
        group = c('pDC', 'Monocyte'),
        avg_log2FC = c(1.4, -0.3),
        p_val_adj = c(0.001, 0.4)
    )
    frag <- import_hdwgcna_dme(module_id = 'MM1', result = user_table)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'state_expression')
    expect_equal(frag$provenance$source, 'user_supplied')
    expect_equal(frag$top_findings[[1]]$group, 'pDC')
})

test_that('import_hdwgcna_dme() respects column_map overrides', {
    user_table <- data.frame(cell_state = c('pDC', 'Monocyte'), fc = c(2.0, -0.1), fdr = c(0.001, 0.6))
    frag <- import_hdwgcna_dme(
        module_id = 'MM1', result = user_table,
        column_map = list(group_col = 'cell_state', effect_col = 'fc', significance_col = 'fdr')
    )
    expect_equal(frag$type, 'state_expression')
    expect_equal(frag$effect_strength, 2.0)
})

test_that('import_enrichr() defaults to EnrichR column names', {
    user_table <- data.frame(
        Term = c('Interferon Response', 'Cell Cycle'),
        Odds.Ratio = c(12.5, 1.1),
        Adjusted.P.value = c(0.001, 0.7)
    )
    frag <- import_enrichr(module_id = 'MM1', result = user_table)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'geneset_enrichment')
    expect_equal(frag$provenance$source, 'user_supplied')
    expect_equal(frag$top_findings[[1]]$term, 'Interferon Response')
})

test_that('import_enrichr() reuses the same importer for a GeneOverlap table via column_map', {
    user_table <- data.frame(
        category = c('HALLMARK_INTERFERON_GAMMA_RESPONSE', 'HALLMARK_E2F_TARGETS'),
        odds.ratio = c(8.2, 0.9),
        pval = c(0.002, 0.6)
    )
    frag <- import_enrichr(
        module_id = 'MM1', result = user_table,
        column_map = list(term_col = 'category', effect_col = 'odds.ratio', significance_col = 'pval')
    )
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$top_findings[[1]]$term, 'HALLMARK_INTERFERON_GAMMA_RESPONSE')
})

test_that('import_fragment() records source_file path and content hash in provenance', {
    user_table <- data.frame(term = 'A', odds_ratio = 5, fdr = 0.01)
    tmp <- tempfile(fileext = '.tsv')
    utils::write.table(user_table, tmp, sep = '\t', row.names = FALSE)
    on.exit(unlink(tmp))

    frag <- import_fragment(module_id = 'MM1', type = 'geneset_enrichment', result = user_table, source_file = tmp)
    expect_equal(frag$provenance$params$source_file, tmp)
    expect_false(is.null(frag$provenance$input_hashes$source_file))
})
