## dataset_description + prompt assembly (docs/milestone_2.md task 1).

test_that('validate_dataset_description() hard-errors when a required field is missing', {
    desc <- csf_dataset_description()
    desc$tissue <- NA_character_
    expect_error(validate_dataset_description(desc), 'tissue')
})

test_that('validate_dataset_description() hard-errors on an empty string field', {
    desc <- csf_dataset_description()
    desc$species <- '  '
    expect_error(validate_dataset_description(desc), 'species')
})

test_that('validate_dataset_description() passes a well-formed description', {
    expect_true(validate_dataset_description(csf_dataset_description()))
})

test_that('render_dataset_description() includes every required field', {
    txt <- render_dataset_description(csf_dataset_description())
    expect_true(grepl('cerebrospinal fluid', txt))
    expect_true(grepl('myeloid', txt))
    expect_true(grepl('single-cell RNA-seq', txt))
    expect_true(grepl('Glioblastoma', txt))
})

test_that('render_packet_compact() includes compact_summary and caps top_findings for a typical (non-ranked_genes) fragment', {
    top_findings <- lapply(1:10, function(i) list(term = paste0('term', i), fdr = i / 100))
    frag <- evidence_fragment(
        fragment_id = 'go', tool_id = 'go', module_id = 'M1', type = 'geneset_enrichment',
        result = data.frame(term = paste0('term', 1:10)), compact_summary = 'ten enriched terms',
        top_findings = top_findings, effect_strength = 1, direction = 'up',
        provenance = make_provenance(tool_version = '0.1')
    )
    packet <- build_evidence_packet('M1', list(frag), input_hash = 'abc')
    txt <- render_packet_compact(packet, max_findings = 8)
    expect_true(grepl(frag$fragment_id, txt, fixed = TRUE))
    expect_true(grepl(frag$compact_summary, txt, fixed = TRUE))
    # rank 1 term is within the cap; rank 10 is not
    expect_true(grepl('"term1"', txt, fixed = TRUE))
    expect_false(grepl('"term10"', txt, fixed = TRUE))
})

test_that('render_packet_compact() exempts ranked_genes fragments from the top_findings cap', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(n_hubs = 25))
    frag <- top_genes_tool(ctx)
    packet <- build_evidence_packet(mod_test, list(frag), input_hash = 'abc')
    txt <- render_packet_compact(packet, max_findings = 8)
    # top_genes_tool() deliberately carries all n_hubs genes (not "the top
    # few" like every other core tool), so rank 25 must still reach the
    # prompt -- a synthesis-time regression test for a real failure mode:
    # capping this fragment hid checkpoint/exhaustion marker genes ranked
    # 9-16 by kME from the model on a real SERPENTINE module
    expect_true(grepl(frag$result$gene_name[25], txt, fixed = TRUE))
})

test_that('build_system_prompt() states the faithfulness rule and controlled vocabularies', {
    txt <- build_system_prompt()
    expect_true(grepl('fragment_id', txt))
    expect_true(grepl('insufficient_evidence', txt))
    expect_true(grepl('ranked_genes', txt))
})

test_that('build_user_prompt() prepends the dataset description before the packet', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(n_hubs = 10))
    frag <- top_genes_tool(ctx)
    packet <- build_evidence_packet(mod_test, list(frag), input_hash = 'abc')
    desc <- csf_dataset_description()
    txt <- build_user_prompt(packet, desc)
    expect_true(which(grepl('Dataset context', strsplit(txt, '\n')[[1]])) <
                    which(grepl('evidence packet', strsplit(txt, '\n')[[1]])))
})

## fused evidence score shelved (Part 4.5): no EVIDENCE CONFIDENCE MATRIX in
## the prompt, model reports its own calibrated confidence

test_that('build_user_prompt() does not inject the EVIDENCE CONFIDENCE MATRIX', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(n_hubs = 10))
    frag <- top_genes_tool(ctx)
    packet <- build_evidence_packet(mod_test, list(frag), input_hash = 'abc')
    desc <- csf_dataset_description()
    txt <- build_user_prompt(packet, desc)
    expect_false(grepl('EVIDENCE CONFIDENCE MATRIX', txt))
    expect_false(grepl('E_evidence', txt))
    expect_false(grepl('CONSTRAINTS', txt))
})

test_that('build_user_prompt() ignores a passed fusion object', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(n_hubs = 10))
    frag <- top_genes_tool(ctx)
    packet <- build_evidence_packet(mod_test, list(frag), input_hash = 'abc')
    desc <- csf_dataset_description()

    fusion <- calculate_fusion_score(packet$fragments)
    expect_identical(build_user_prompt(packet, desc, fusion = fusion), build_user_prompt(packet, desc))
})

test_that('build_system_prompt() asks the model for its own calibrated confidence, not E_evidence', {
    txt <- build_system_prompt()
    expect_false(grepl('EVIDENCE CONFIDENCE MATRIX', txt))
    expect_false(grepl('E_evidence', txt))
    expect_true(grepl('calibrated certainty', txt))
})

test_that('render_packet_compact() appends the housekeeping note for a ribosomal-heavy hub list', {
    ribo_genes <- paste0('RPS', 1:20)
    frag <- evidence_fragment(
        fragment_id = 'top_genes', tool_id = 'top_genes', module_id = 'M1', type = 'ranked_genes',
        result = data.frame(gene_name = ribo_genes, kme = seq(0.9, by = -0.01, length.out = 20)),
        compact_summary = 'top 20 genes by kME', top_findings = lapply(ribo_genes, function(g) list(gene = g)),
        effect_strength = 0.9, direction = 'na', provenance = make_provenance(tool_version = '0.1')
    )
    packet <- build_evidence_packet('M1', list(frag), input_hash = 'abc')
    txt <- render_packet_compact(packet)
    expect_true(grepl('housekeeping note', txt))
    expect_true(grepl('ribosomal', txt))
})
