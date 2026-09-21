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

test_that('a non-significant geneset_enrichment summary lists fewer terms than a significant one', {
    non_sig <- data.frame(
        term = paste0('T', 1:6), odds_ratio = 6:1, fdr = rep(1, 6),
        size_intersection = c(4, 3, 3, 2, 2, 1)
    )
    frag <- import_fragment(module_id = 'MM1', type = 'geneset_enrichment', result = non_sig)
    expect_equal(lengths(regmatches(frag$compact_summary, gregexpr('genes overlap', frag$compact_summary)))[[1]], 3)

    sig <- transform(non_sig, fdr = c(rep(0.001, 5), 1))
    frag_sig <- import_fragment(module_id = 'MM1', type = 'geneset_enrichment', result = sig)
    expect_equal(lengths(regmatches(frag_sig$compact_summary, gregexpr('genes overlap', frag_sig$compact_summary)))[[1]], 5)
})

test_that('import_fragment() states when no geneset_enrichment term is significant and drops the direction', {
    user_table <- data.frame(
        term = c('Angiogenesis', 'DNA_damage', 'Apoptosis'),
        odds_ratio = c(1.1, 4.05, 3.31),
        fdr = c(1, 1, 1)
    )
    frag <- import_fragment(module_id = 'MM1', type = 'geneset_enrichment', result = user_table)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$direction, 'na')
    expect_match(frag$compact_summary, 'no term reaches FDR < 0.05', fixed = TRUE)
    expect_match(frag$compact_summary, 'NOT significant', fixed = TRUE)
    expect_false(grepl('top terms', frag$compact_summary))
})

test_that('import_fragment() counts significant geneset_enrichment terms against alpha', {
    user_table <- data.frame(
        term = c('Interferon Response', 'Dendritic Cell Activation', 'Cell Cycle'),
        odds_ratio = c(12.5, 8.1, 1.2),
        fdr = c(0.001, 0.02, 0.6)
    )
    frag <- import_fragment(module_id = 'MM1', type = 'geneset_enrichment', result = user_table)
    expect_match(frag$compact_summary, '2 of 3 tested terms reach FDR < 0.05', fixed = TRUE)
    expect_false(grepl('Cell Cycle', frag$compact_summary))

    strict <- import_fragment(module_id = 'MM1', type = 'geneset_enrichment', result = user_table, params = list(alpha = 0.01))
    expect_match(strict$compact_summary, '1 of 3 tested terms reach FDR < 0.01', fixed = TRUE)

    none <- import_fragment(module_id = 'MM1', type = 'geneset_enrichment', result = user_table, params = list(alpha = 1e-4))
    expect_equal(none$direction, 'na')
})

test_that('import_fragment() carries overlap size and Jaccard into geneset_enrichment findings and summary', {
    user_table <- data.frame(
        modules2 = c('DNA_damage', 'Apoptosis'),
        odds_ratio = c(4.05, 3.31),
        fdr = c(1, 1),
        size_intersection = c(2, 1),
        Jaccard = c(0.0106, 0.0052)
    )
    frag <- import_fragment(
        module_id = 'MM1', type = 'geneset_enrichment', result = user_table,
        params = list(term_col = 'modules2')
    )
    expect_equal(frag$top_findings[[1]]$n_overlap, 2)
    expect_equal(frag$top_findings[[1]]$jaccard, 0.0106)
    # Jaccard stays in top_findings; the prose keeps the overlap count and odds ratio
    expect_match(frag$compact_summary, 'DNA_damage (2 genes overlap, OR 4.05, FDR 1)', fixed = TRUE)
    expect_false(grepl('Jaccard', frag$compact_summary, fixed = TRUE))
})

test_that('import_enrichr() reduces an Overlap k/n string to the overlap count', {
    user_table <- data.frame(
        Term = c('Hypoxia', 'Glycolysis'),
        Overlap = c('7/200', '3/150'),
        Odds.Ratio = c(6.2, 2.1),
        Adjusted.P.value = c(0.004, 0.3)
    )
    frag <- import_enrichr(module_id = 'MM1', result = user_table)
    expect_equal(frag$top_findings[[1]]$n_overlap, 7)
    expect_null(frag$top_findings[[1]]$jaccard)
    expect_match(frag$compact_summary, 'Hypoxia (7 genes overlap, OR 6.2, FDR 0.004)', fixed = TRUE)
    expect_length(frag$top_findings, 2)
})

test_that('import_fragment() leaves geneset_enrichment findings unchanged when no overlap columns exist', {
    user_table <- data.frame(term = c('A', 'B'), odds_ratio = c(5, 2), fdr = c(0.01, 0.3))
    frag <- import_fragment(module_id = 'MM1', type = 'geneset_enrichment', result = user_table)
    expect_setequal(names(frag$top_findings[[1]]), c('term', 'significance', 'effect'))
    expect_match(frag$compact_summary, 'A (OR 5, FDR 0.01)', fixed = TRUE)
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

test_that('import_fragment() breaks geneset_enrichment significance ties by descending effect', {
    user_table <- data.frame(
        term = c('Angiogenesis', 'DNA Repair', 'Hypoxia', 'Inflammation', 'Invasion', 'Quiescence'),
        odds_ratio = c(1.1, 1.3, 9.4, 1.0, 1.2, 0.9),
        fdr = rep(1, 6)
    )
    frag <- import_fragment(module_id = 'MM1', type = 'geneset_enrichment', result = user_table)
    expect_equal(frag$top_findings[[1]]$term, 'Hypoxia')
    expect_true(frag$top_findings[[1]]$effect >= frag$top_findings[[2]]$effect)
    expect_false(identical(frag$top_findings[[1]]$term, 'Angiogenesis'))
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
        import_fragment(module_id = 'MM1', type = 'ranked_genes', result = data.frame(x = 1)),
        'no normalizer'
    )
})

## SERPENTINE T-cell milestone Part 3 (docs/milestones/milestone_serpentine_tcell.md):
## signature_correlation (cGEP-style, many signatures per module) and
## continuous_correlation (ASA-style, a single continuous variable per module).

test_that('import_fragment() normalizes a signature_correlation table (e.g. a cGEP correlation table)', {
    user_table <- data.frame(
        signature = c('Exhaustion', 'Cytotoxic', 'Naive'),
        r = c(0.45, 0.05, -0.29)
    )
    frag <- import_fragment(module_id = 'MM1', type = 'signature_correlation', result = user_table)
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'signature_correlation')
    expect_equal(frag$provenance$source, 'user_supplied')
    expect_equal(frag$direction, 'up')
    expect_equal(frag$effect_strength, 0.45)
    expect_equal(frag$top_findings[[1]]$signature, 'Exhaustion')
})

test_that('import_fragment() respects column_map overrides for signature_correlation (e.g. a cgep column)', {
    user_table <- data.frame(module = 'MM1', cgep = c('Mito', 'HLA'), r = c(-0.72, 0.55))
    frag <- import_fragment(
        module_id = 'MM1', type = 'signature_correlation', result = user_table,
        params = list(signature_col = 'cgep')
    )
    expect_equal(frag$direction, 'down')
    expect_equal(frag$effect_strength, 0.72)
    expect_equal(frag$top_findings[[1]]$signature, 'Mito')
})

test_that('import_fragment() normalizes a single-row continuous_correlation table (e.g. an ASA correlation)', {
    user_table <- data.frame(r = 0.49, n_samples = 515)
    frag <- import_fragment(
        module_id = 'MM1', type = 'continuous_correlation', result = user_table,
        params = list(n_col = 'n_samples', variable_name = 'ASA')
    )
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'continuous_correlation')
    expect_equal(frag$provenance$source, 'user_supplied')
    expect_equal(frag$direction, 'up')
    expect_equal(frag$effect_strength, 0.49)
    expect_equal(frag$top_findings[[1]]$n, 515)
})

test_that('import_fragment() normalizes a multi-row continuous_correlation table via variable_col', {
    user_table <- data.frame(variable = c('ASA', 'clonal_frac'), r = c(-0.6, 0.2))
    frag <- import_fragment(
        module_id = 'MM1', type = 'continuous_correlation', result = user_table,
        params = list(variable_col = 'variable')
    )
    expect_equal(frag$direction, 'down')
    expect_equal(frag$effect_strength, 0.6)
    expect_equal(frag$top_findings[[1]]$variable, 'ASA')
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
        list(fn = top_genes_tool, params = list(n_hubs = 5)),
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
