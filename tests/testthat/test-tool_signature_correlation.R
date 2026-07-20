## signature_correlation_tool: the co-variation sibling of geneset_enrichment
## (docs/milestone_extensibility.md Part 2a; refactored onto pseudobulk_view()
## in docs/milestone_pseudobulk.md Part 2). Uses the tiny synthetic signature
## library from synthetic_extensibility.R, where module_a's own gene set is
## included as one signature -- a spike-in-style sanity check that it should
## come back with the top |r| -- at both the cell level and, once a
## pseudo-bulk view is attached, the pseudo-bulk level.

test_that('signature_correlation_tool() skips gracefully without module_scores/expression', {
    skip_if_not(go_data_available, 'GO Biological Process data not available')

    bare_ms <- components_ModuleSet(go_components_gene_table, go_fixture$expr, go_fixture$meta)
    expect_false(has_capability(bare_ms, 'module_scores'))
    ctx <- list(ms = bare_ms, module_id = 'module_a', params = list(library_files = go_test_signature_files))
    expect_message(result <- signature_correlation_tool(ctx), 'skipped')
    expect_null(result)
})

test_that('signature_correlation_tool() requires params$library_files', {
    skip_if_not(go_data_available, 'GO Biological Process data not available')
    ctx <- list(ms = go_components_ms, module_id = 'module_a', params = list())
    expect_error(signature_correlation_tool(ctx), 'library_files')
})

test_that('signature_correlation_tool() finds a module\'s own gene set as its top |r| signature (cell level)', {
    skip_if_not(go_data_available, 'GO Biological Process data not available')

    # no pseudo-bulk view attached -> cell-level correlation, no p attached
    nocap_ms <- components_ModuleSet(
        go_components_gene_table, go_fixture$expr, go_fixture$meta, scores = go_components_scores
    )
    frag <- signature_correlation_tool(list(
        ms = nocap_ms, module_id = 'module_a',
        params = list(library_files = go_test_signature_files)
    ))
    expect_true(validate_evidence_fragment(frag))
    expect_equal(frag$type, 'signature_correlation')
    expect_true(all(frag$result$level == 'cell'))
    expect_true(all(is.na(frag$result$p)))

    top <- frag$result[which.max(abs(frag$result$r)), ]
    expect_equal(top$signature, 'sig_match_a')
    expect_gt(top$r, 0.5)
    expect_equal(frag$direction, 'up')
})

test_that('signature_correlation_tool() is cell-level-only when no pseudo-bulk view is resolvable', {
    skip_if_not(go_data_available, 'GO Biological Process data not available')

    # go_components_ms has sample_ids/grouping capabilities but no attached
    # pseudo-bulk view -- capability alone must not trigger sample-level
    # inference, only pseudobulk_view() resolving to something real does
    expect_null(pseudobulk_view(go_components_ms))
    frag <- signature_correlation_tool(list(
        ms = go_components_ms, module_id = 'module_a',
        params = list(library_files = go_test_signature_files)
    ))
    expect_true(validate_evidence_fragment(frag))
    expect_true(all(frag$result$level == 'cell'))
    expect_true(all(is.na(frag$result$p)))
})

test_that('signature_correlation_tool() uses pseudo-bulk correlation (with p) when a pseudo-bulk view is attached', {
    skip_if_not(go_data_available, 'GO Biological Process data not available')

    expect_identical(pseudobulk_view(go_components_ms_with_pb), go_pb_ms)
    frag <- signature_correlation_tool(list(
        ms = go_components_ms_with_pb, module_id = 'module_a',
        params = list(library_files = go_test_signature_files)
    ))
    expect_true(validate_evidence_fragment(frag))
    expect_true(all(frag$result$level == go_pb_ms$data_level))
    expect_true(all(!is.na(frag$result$p)))
    expect_true(all(frag$result$n <= ncol(counts(go_pb_ms))))

    top <- frag$result[which.max(abs(frag$result$r)), ]
    expect_equal(top$signature, 'sig_match_a')
    expect_gt(top$r, 0.5)
})

test_that('signature_correlation_tool() runs on gene_list_ModuleSet and shows strong co-variation with its own gene set', {
    skip_if_not(go_data_available, 'GO Biological Process data not available')

    # neither ModuleSet has a pseudo-bulk view attached, so this exercises
    # the cell-level path (n = 120 cells) -- noisy enough that the two
    # scoring backends can disagree on the exact #1 rank between the two
    # module-derived signatures, so this only asserts sig_match_a co-varies
    # positively and ranks among the top 2 signatures by |r|, not that it's
    # always exactly #1
    for (ms in list(go_gene_list_ms_ucell, go_gene_list_ms_decoupler)) {
        frag <- signature_correlation_tool(list(
            ms = ms, module_id = 'module_a',
            params = list(library_files = go_test_signature_files)
        ))
        expect_true(validate_evidence_fragment(frag))
        match_row <- frag$result[frag$result$signature == 'sig_match_a', ]
        expect_gt(match_row$r, 0)
        expect_lte(match(match_row$signature, frag$result$signature), 2)
    }
})

test_that('signature_correlation_tool() runs end to end through run_module()', {
    skip_if_not(go_data_available, 'GO Biological Process data not available')

    tool_config <- c(go_tool_config(), list(list(
        fn = signature_correlation_tool,
        params = list(library_files = go_test_signature_files)
    )))
    packet <- run_module(go_components_ms, 'module_a', tool_config, input_hash = 'go_signature_test')
    ids <- vapply(packet$fragments, function(f) f$fragment_id, character(1))
    expect_true('signature_correlation' %in% ids)
    for (frag in packet$fragments) expect_true(validate_evidence_fragment(frag))
})
