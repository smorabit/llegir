## dataset_composition_tool() (docs/milestones/milestone_dataset_tools.md Part 3):
## cell-state census + condition covariate balance, computed from metadata(ms)
## only. Offline throughout -- llegir_example_moduleset() plus small hand-built
## fixtures, no live syntheses.

make_no_grouping_ms <- function(){
    structure(list(), class = 'no_grouping_ModuleSet')
}
capabilities.no_grouping_ModuleSet <- function(ms, ...) c(grouping = FALSE)
registerS3method('capabilities', 'no_grouping_ModuleSet', capabilities.no_grouping_ModuleSet)

# an extreme cell-state x condition skew: state_x is almost all 'case',
# state_y is almost all 'control', so chi-square standardized residuals blow
# past the default threshold. Six distinct samples per condition and 100
# cells per condition keep it well above the underpowered_contrast floor, so
# only the imbalance caveat should fire.
make_skewed_ms <- function(){
    group <- c(rep('state_x', 90), rep('state_y', 10), rep('state_x', 10), rep('state_y', 90))
    condition <- c(rep('case', 100), rep('control', 100))
    sample_id <- c(rep(paste0('case_s', 1:6), length.out = 100), rep(paste0('ctrl_s', 1:6), length.out = 100))
    meta <- data.frame(cell_type = group, diagnosis = condition, sample = sample_id, stringsAsFactors = FALSE)
    structure(list(meta = meta, data_level = 'cell', aggregated = FALSE), class = 'skewed_ModuleSet')
}
metadata.skewed_ModuleSet <- function(ms, ...) ms$meta
capabilities.skewed_ModuleSet <- function(ms, ...) c(grouping = TRUE, sample_ids = TRUE)
pkg_versions.skewed_ModuleSet <- function(ms, ...) list(dummy = '1.0')
registerS3method('metadata', 'skewed_ModuleSet', metadata.skewed_ModuleSet)
registerS3method('capabilities', 'skewed_ModuleSet', capabilities.skewed_ModuleSet)
registerS3method('pkg_versions', 'skewed_ModuleSet', pkg_versions.skewed_ModuleSet)

test_that('dataset_composition_tool() returns a valid composition_summary fragment without a condition_col', {
    ms <- llegir_example_moduleset()
    ctx <- list(ms = ms, params = list(group_col = 'cell_type'))
    frag <- dataset_composition_tool(ctx)

    expect_true(validate_dataset_fragment(frag))
    expect_equal(frag$type, 'composition_summary')
    expect_true(all(c('group', 'n', 'prop') %in% colnames(frag$result)))
    expect_true(grepl('cells', frag$compact_summary, fixed = TRUE))
})

test_that('dataset_composition_tool() cross-tabs against a condition_col and reports sample power', {
    ms <- llegir_example_moduleset()
    ctx <- list(ms = ms, params = list(group_col = 'cell_type', condition_col = 'diagnosis'))
    frag <- dataset_composition_tool(ctx)

    expect_true(validate_dataset_fragment(frag))
    expect_true(all(c('group', 'condition', 'n', 'prop_of_condition', 'expected', 'std_resid') %in% colnames(frag$result)))

    metrics <- vapply(frag$top_findings, function(f) f$metric %||% NA_character_, character(1))
    expect_true('shannon_entropy' %in% metrics)
    expect_true('samples_per_condition' %in% metrics)
})

test_that('dataset_composition_tool() skips gracefully without the grouping capability', {
    ctx <- list(ms = make_no_grouping_ms(), params = list(group_col = 'cell_type'))
    expect_message(result <- dataset_composition_tool(ctx), 'skipped')
    expect_null(result)
})

test_that('dataset_composition_tool() errors without group_col', {
    ms <- llegir_example_moduleset()
    expect_error(dataset_composition_tool(list(ms = ms, params = list())), 'group_col')
})

test_that('dataset_composition_tool() flags cell_state_imbalanced_across_condition on a skewed fixture', {
    ctx <- list(ms = make_skewed_ms(), params = list(group_col = 'cell_type', condition_col = 'diagnosis'))
    frag <- dataset_composition_tool(ctx)

    expect_true(validate_dataset_fragment(frag))
    expect_true('cell_state_imbalanced_across_condition' %in% unlist(frag$caveats))
    expect_false('underpowered_contrast' %in% unlist(frag$caveats))
})

test_that('dataset_composition_tool() flags underpowered_contrast when a condition has too few cells', {
    meta <- data.frame(
        cell_type = c(rep('state_x', 15), rep('state_y', 15), rep('state_x', 3), rep('state_y', 2)),
        diagnosis = c(rep('case', 30), rep('control', 5)),
        sample = c(rep('s1', 15), rep('s2', 15), rep('s3', 3), rep('s4', 2)),
        stringsAsFactors = FALSE
    )
    ms <- structure(list(meta = meta, data_level = 'cell', aggregated = FALSE), class = 'skewed_ModuleSet')
    ctx <- list(ms = ms, params = list(group_col = 'cell_type', condition_col = 'diagnosis'))
    frag <- dataset_composition_tool(ctx)

    expect_true('underpowered_contrast' %in% unlist(frag$caveats))
})

test_that('run_dataset_context() runs the registered composition tool end to end', {
    ms <- llegir_example_moduleset()
    dc <- run_dataset_context(ms, list(list(id = 'composition', params = list(group_col = 'cell_type', condition_col = 'diagnosis'))))

    expect_equal(length(dc$dataset_fragments), 1)
    expect_equal(dc$dataset_fragments[[1]]$type, 'composition_summary')
})
