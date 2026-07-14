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

test_that('render_packet_compact() includes compact_summary but caps top_findings instead of dumping the full result table', {
    skip_if_not(csf_data_available, 'CSF dev object not available')
    ctx <- list(ms = ms_test, module_id = mod_test, params = list(n_hubs = 25))
    frag <- hub_genes_tool(ctx)
    packet <- build_evidence_packet(mod_test, list(frag), input_hash = 'abc')
    txt <- render_packet_compact(packet, max_findings = 8)
    expect_true(grepl(frag$fragment_id, txt, fixed = TRUE))
    expect_true(grepl(frag$compact_summary, txt, fixed = TRUE))
    # rank 1 hub gene is within the cap; the full 25-gene result table would
    # also include rank 25, which the capped rendering must exclude
    expect_true(grepl(frag$result$gene_name[1], txt, fixed = TRUE))
    expect_false(grepl(frag$result$gene_name[25], txt, fixed = TRUE))
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
    frag <- hub_genes_tool(ctx)
    packet <- build_evidence_packet(mod_test, list(frag), input_hash = 'abc')
    desc <- csf_dataset_description()
    txt <- build_user_prompt(packet, desc)
    expect_true(which(grepl('Dataset context', strsplit(txt, '\n')[[1]])) <
                    which(grepl('evidence packet', strsplit(txt, '\n')[[1]])))
})
