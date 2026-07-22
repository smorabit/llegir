## import_dataset_fragment (docs/milestones/milestone_dataset_tools.md Part 4):
## user-supplied compositional / differential-abundance tables normalized into
## valid dataset_fragments, tagged provenance.source = 'user_supplied'. No
## ModuleSet dependency here -- these operate on tables directly, offline.

test_that('import_milo_da() normalizes a miloR-shaped neighborhood table into a composition_summary fragment', {
    milo_result <- data.frame(
        celltype = c(rep('pDC', 5), rep('Monocyte', 5), rep('Macrophage', 5)),
        logFC = c(rep(1.8, 4), 0.1, rep(-0.2, 5), rep(0.05, 5)),
        SpatialFDR = c(rep(0.001, 4), 0.9, rep(0.8, 5), rep(0.7, 5)),
        stringsAsFactors = FALSE
    )
    frag <- import_milo_da(result = milo_result)

    expect_true(validate_dataset_fragment(frag))
    expect_equal(frag$type, 'composition_summary')
    expect_equal(frag$provenance$source, 'user_supplied')
    expect_true(all(c('group', 'n_tested', 'n_sig', 'mean_effect', 'direction') %in% colnames(frag$result)))

    pdc_row <- frag$result[frag$result$group == 'pDC', ]
    expect_equal(pdc_row$n_sig, 4)
    expect_equal(pdc_row$direction, 'up')
    expect_true('cell_state_imbalanced_across_condition' %in% unlist(frag$caveats))
})

test_that('import_milo_da() respects column_map overrides for non-default miloR column names', {
    milo_result <- data.frame(
        annotation = c('pDC', 'pDC', 'Monocyte', 'Monocyte'),
        FC = c(2.0, 1.9, -0.1, -0.05),
        fdr = c(0.001, 0.002, 0.6, 0.7),
        stringsAsFactors = FALSE
    )
    frag <- import_milo_da(
        result = milo_result,
        column_map = list(group_col = 'annotation', effect_col = 'FC', significance_col = 'fdr')
    )

    expect_true(validate_dataset_fragment(frag))
    expect_equal(frag$provenance$params$group_col, 'annotation')
    pdc_row <- frag$result[frag$result$group == 'pDC', ]
    expect_equal(pdc_row$n_sig, 2)
    expect_equal(pdc_row$direction, 'up')
})

test_that('import_milo_da() flags underpowered_contrast when no neighborhoods are significant', {
    milo_result <- data.frame(
        celltype = c(rep('pDC', 3), rep('Monocyte', 3)),
        logFC = c(0.2, -0.1, 0.05, 0.1, -0.2, 0.05),
        SpatialFDR = rep(0.8, 6),
        stringsAsFactors = FALSE
    )
    frag <- import_milo_da(result = milo_result)

    expect_true('underpowered_contrast' %in% unlist(frag$caveats))
    expect_false('cell_state_imbalanced_across_condition' %in% unlist(frag$caveats))
})

test_that('import_dataset_fragment() errors on an unsupported type', {
    expect_error(
        import_dataset_fragment(type = 'baseline_expression', result = data.frame(x = 1)),
        'no normalizer'
    )
})

test_that('import_dataset_fragment() errors on a missing required column', {
    expect_error(
        import_dataset_fragment(type = 'composition_summary', result = data.frame(celltype = 'pDC')),
        'missing columns'
    )
})

test_that('import_dataset_fragment() records source_file path and content hash in provenance', {
    milo_result <- data.frame(celltype = c('pDC', 'Monocyte'), logFC = c(1.5, -0.2), SpatialFDR = c(0.001, 0.6))
    tmp <- tempfile(fileext = '.tsv')
    utils::write.table(milo_result, tmp, sep = '\t', row.names = FALSE)
    on.exit(unlink(tmp))

    frag <- import_dataset_fragment(type = 'composition_summary', result = milo_result, source_file = tmp)
    expect_equal(frag$provenance$params$source_file, tmp)
    expect_false(is.null(frag$provenance$input_hashes$source_file))
})

test_that('import_dataset_fragment_tool() wires import_milo_da into run_dataset_context() via a direct fn spec', {
    milo_result <- data.frame(
        celltype = c('pDC', 'pDC', 'Monocyte', 'Monocyte'),
        logFC = c(2.0, 1.8, -0.1, 0.05),
        SpatialFDR = c(0.001, 0.002, 0.7, 0.8),
        stringsAsFactors = FALSE
    )
    ms <- llegir_example_moduleset()
    dc <- run_dataset_context(
        ms,
        list(list(fn = import_dataset_fragment_tool, params = list(type = 'composition_summary', result = milo_result)))
    )

    expect_equal(length(dc$dataset_fragments), 1)
    frag <- dc$dataset_fragments[[1]]
    expect_equal(frag$type, 'composition_summary')
    expect_equal(frag$provenance$source, 'user_supplied')
})
