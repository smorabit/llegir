## import_fragment (milestone 1.5 task 3): user-supplied result tables
## normalized into valid evidence_fragments, tagged provenance.source =
## 'user_supplied'. No ModuleSet dependency here -- these operate on tables
## directly.

# runs an import_tool() spec for one module the way run_evidence() would
imported_fragment <- function(spec, module_id = 'MM1', ms = NULL){
    spec$fn(list(ms = ms, module_id = module_id, params = list(), module_method = NA_character_))
}

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

test_that('import_tool(format = "enrichr") reduces an Overlap k/n string to the overlap count', {
    user_table <- data.frame(
        Term = c('Hypoxia', 'Glycolysis'),
        Overlap = c('7/200', '3/150'),
        Odds.Ratio = c(6.2, 2.1),
        Adjusted.P.value = c(0.004, 0.3)
    )
    frag <- imported_fragment(import_tool(user_table, format = 'enrichr'))
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

## import_tool(): format presets, format = 'auto', per-module splitting,
## genome-wide gene-level filtering, file reading and provenance.

test_that('import_tool() splits a table by module_col and skips modules with no rows', {
    ms <- llegir_example_moduleset()
    mods <- modules(ms)
    dme <- data.frame(
        module = mods[1], group = c('t1', 't2'),
        avg_log2FC = c(1.4, -0.3), p_val_adj = c(0.001, 0.4)
    )
    spec <- import_tool(dme, format = 'auto', module_col = 'module')
    expect_equal(spec$id, 'hdwgcna_dme')
    ev <- run_evidence(ms, list(spec), modules_use = mods[1:2])
    frag <- ev$packets[[mods[1]]]$fragments[[1]]
    expect_equal(frag$type, 'state_expression')
    expect_equal(frag$fragment_id, 'hdwgcna_dme')
    expect_equal(frag$top_findings[[1]]$group, 't1')
    expect_equal(nrow(frag$result), 2)
    expect_length(ev$packets[[mods[2]]]$fragments, 0)
    expect_equal(ev$packets[[mods[2]]]$provenance$skipped[[1]]$tool_id, 'hdwgcna_dme')
})

test_that('import_tool() filters a genome-wide marker table to each module\'s genes', {
    ms <- llegir_example_moduleset()
    mod <- modules(ms)[1]
    own <- gene_membership(ms, mod)$gene_name[1:2]
    markers <- data.frame(
        gene = c(own, 'NOT_A_MODULE_GENE'), avg_log2FC = c(2.0, -0.5, 5.0), p_val_adj = c(0.001, 0.2, 1e-10)
    )
    frag <- imported_fragment(import_tool(markers, format = 'seurat_markers'), module_id = mod, ms = ms)
    expect_equal(frag$type, 'cross_condition_delta')
    expect_setequal(frag$result$gene, own)
    expect_equal(frag$direction, 'up')

    no_overlap <- markers[3, ]
    expect_null(imported_fragment(import_tool(no_overlap, format = 'seurat_markers'), module_id = mod, ms = ms))
})

test_that('import_tool() summarises FindAllMarkers output per cluster over the module\'s genes', {
    ms <- llegir_example_moduleset()
    mod <- modules(ms)[1]
    own <- gene_membership(ms, mod)$gene_name[1:3]
    markers <- data.frame(
        gene = c(own, own[1]), cluster = c('c1', 'c1', 'c1', 'c2'),
        avg_log2FC = c(1.5, 1.2, 0.9, 0.4), p_val_adj = c(0.001, 0.01, 0.02, 0.5)
    )
    frag <- imported_fragment(import_tool(markers, format = 'seurat_markers'), module_id = mod, ms = ms)
    expect_equal(frag$type, 'state_expression')
    expect_equal(frag$top_findings[[1]]$group, 'c1')
    expect_equal(frag$top_findings[[1]]$effect, 3)
    expect_true(all(c('n_module_genes_up', 'mean_log2FC', 'min_padj') %in% colnames(frag$result)))
})

test_that('import_tool() maps arbitrary column names through columns =', {
    deseq <- data.frame(gene = c('IFIT3', 'ACTB'), log2FoldChange = c(1.9, -0.1), padj = c(0.003, 0.8))
    spec <- import_tool(deseq, type = 'geneset_enrichment', columns = list(term = 'gene', effect = 'log2FoldChange', significance = 'padj'))
    frag <- imported_fragment(spec)
    expect_equal(frag$top_findings[[1]]$term, 'IFIT3')
    expect_equal(frag$provenance$params$term_col, 'gene')

    overlap <- data.frame(category = c('HALLMARK_IFNG', 'HALLMARK_E2F'), odds.ratio = c(8.2, 0.9), pval = c(0.002, 0.6))
    frag <- imported_fragment(import_tool(
        overlap, format = 'enrichr', columns = list(term = 'category', effect = 'odds.ratio', significance = 'pval')
    ))
    expect_equal(frag$top_findings[[1]]$term, 'HALLMARK_IFNG')
})

test_that('import_tool() reads CSV and TSV files and records the file hash, never the table', {
    tbl <- data.frame(Term = paste0('T', 1:500), Odds.Ratio = runif(500, 1, 5), Adjusted.P.value = runif(500))
    csv <- tempfile(fileext = '.csv')
    tsv <- tempfile(fileext = '.tsv')
    utils::write.csv(tbl, csv, row.names = FALSE)
    utils::write.table(tbl, tsv, sep = '\t', row.names = FALSE, quote = FALSE)
    for (path in c(csv, tsv)) {
        frag <- imported_fragment(import_tool(path, format = 'auto'))
        expect_equal(frag$type, 'geneset_enrichment')
        expect_equal(frag$provenance$params$source_file, path)
        expect_true(nzchar(frag$provenance$input_hashes$source_file))
        expect_null(frag$provenance$params$result)
    }
    expect_lt(as.numeric(utils::object.size(frag$provenance)), 5000)

    frag <- imported_fragment(import_tool(tbl, format = 'enrichr'))
    expect_true(nzchar(frag$provenance$input_hashes$table))
})

test_that('import_tool() reports what it cannot recognize or find', {
    expect_error(import_tool(data.frame(x = 1), format = 'auto'), 'could not recognize')
    expect_error(import_tool(data.frame(x = 1), format = 'nope'), 'unknown import format')
    expect_error(import_tool(data.frame(x = 1)), 'needs a format or a type')
    expect_error(import_tool(data.frame(x = 1), type = 'geneset_enrichment', module_col = 'module'), 'module_col not found')
    expect_error(import_tool(tempfile(fileext = '.csv'), format = 'auto'), 'not found')
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

test_that('import_fragment() turns an empty table into a valid no-finding fragment for every type', {
    for (type in c('geneset_enrichment', 'categorical_association', 'state_expression',
                   'signature_correlation', 'continuous_correlation', 'cross_condition_delta')) {
        frag <- import_fragment(module_id = 'MM1', type = type, result = data.frame())
        expect_true(validate_evidence_fragment(frag), info = type)
        expect_equal(frag$direction, 'na', info = type)
        expect_length(frag$top_findings, 0)
        expect_true(is.na(frag$effect_strength), info = type)
    }
})

test_that('build_evidence_packet() rejects fragments that share a fragment_id', {
    tbl <- data.frame(term = 'A', odds_ratio = 2, fdr = 0.01)
    frag_1 <- import_fragment('MM1', 'geneset_enrichment', tbl)
    frag_2 <- import_fragment('MM1', 'geneset_enrichment', tbl)
    expect_error(build_evidence_packet('MM1', list(frag_1, frag_2)), 'duplicate fragment_id')
    frag_2$fragment_id <- 'imported::second'
    expect_silent(build_evidence_packet('MM1', list(frag_1, frag_2)))
})
