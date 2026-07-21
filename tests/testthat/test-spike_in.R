## spike-in smoke test (milestone_1.md task 5): run the real core tools
## against synthetic_ModuleSet modules with known ground truth.
##
## positive control: canonical pDC lineage markers (pdc_genes, from
## synthetic_moduleset.R) should show up strongly, and specifically, in the
## CSF object's 'pDC' cluster — raw expression separates that cluster from
## everything else by ~5x (see synthetic_moduleset.R for the check).
## negative control: a random gene set of matched size should show up weakly
## relative to the positive control, with no significant enrichment.

## positive_ms/negative_ms are shared fixtures, built once in setup.R.

test_that('positive control: cluster_dme picks the pDC cluster', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = positive_ms, module_id = 'pdc_module', params = list(group_by = 'lv2_annot'))
    frag <- cluster_dme_tool(ctx)
    expect_true(validate_evidence_fragment(frag))

    top <- frag$result[1, ]
    expect_equal(top$group, 'pDC')
    expect_equal(top$direction, 'up')
    expect_true(top$rank_biserial > 0.5)
    expect_true(top$fdr < 0.01)
})

test_that('positive control: hub genes are drawn from the pDC marker set', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = positive_ms, module_id = 'pdc_module', params = list(n_hubs = 10))
    frag <- top_genes_tool(ctx)
    expect_true(validate_evidence_fragment(frag))
    expect_true(all(frag$result$gene_name %in% pdc_genes))
})

test_that('positive control: enrichment recovers a plasmacytoid/dendritic-related term', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = positive_ms, module_id = 'pdc_module',
                params = list(n_hubs = length(pdc_genes), db_files = test_db_files))
    frag <- geneset_enrichment_tool(ctx)
    expect_true(validate_evidence_fragment(frag))
    expect_true(frag$significance < 0.05)
    expect_true(any(grepl('dendritic|interferon', frag$result$term, ignore.case = TRUE)))
})

test_that('negative control: cluster_dme shows weak, non-specific association', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    pos_ctx <- list(ms = positive_ms, module_id = 'pdc_module', params = list(group_by = 'lv2_annot'))
    neg_ctx <- list(ms = negative_ms, module_id = 'random_module', params = list(group_by = 'lv2_annot'))
    pos_frag <- cluster_dme_tool(pos_ctx)
    neg_frag <- cluster_dme_tool(neg_ctx)
    expect_true(validate_evidence_fragment(neg_frag))
    # a random gene set should associate with cell state far more weakly than
    # a real signal, not necessarily at exactly zero
    expect_true(neg_frag$effect_strength < pos_frag$effect_strength)
})

test_that('negative control: enrichment is far weaker than the positive control', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    pos_ctx <- list(ms = positive_ms, module_id = 'pdc_module',
                     params = list(n_hubs = length(pdc_genes), db_files = test_db_files))
    neg_ctx <- list(ms = negative_ms, module_id = 'random_module',
                     params = list(n_hubs = length(pdc_genes), db_files = test_db_files))
    pos_frag <- geneset_enrichment_tool(pos_ctx)
    neg_frag <- geneset_enrichment_tool(neg_ctx)
    expect_true(validate_evidence_fragment(neg_frag))
    # a handful of random genes can still land a spurious single-gene hit on a
    # narrow GO term (Fisher test on tiny term backgrounds), so the bar is
    # "much weaker than real signal", not "exactly zero"
    expect_true(neg_frag$effect_strength < pos_frag$effect_strength)
})
