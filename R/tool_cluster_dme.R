## cluster_dme: which cell states (a grouping column, e.g. lv2_annot) express
## this module. Touches only the ModuleSet adapter (module_scores, metadata,
## pkg_versions) plus the shared categorical_group_test() helper.

#' Evidence tool: which cell states express this module
#'
#' A core evidence tool. Touches only the `ModuleSet` adapter contract
#' ([module_scores()], [metadata()], [pkg_versions()]) plus the shared
#' [categorical_group_test()] helper, so it works against any backend.
#'
#' @param ctx A tool context list: `list(ms, module_id, params)`, as built by
#'   [run_module()]. `ctx$params$group_col` (or the ModuleSet's declared `group_col`) is the metadata column
#'   naming the cell-state grouping (e.g. `'lv2_annot'`).
#' @return An `evidence_fragment` of type `'state_expression'`, or `NULL` if
#'   `ctx$ms` lacks the `grouping` or `module_scores` capability (see
#'   [capabilities()]) -- a graceful skip, not an error.
#' @examples
#' ms <- llegir_example_moduleset()
#' cluster_dme_tool(list(ms = ms, module_id = modules(ms)[1], params = list(group_col = 'cell_type')))
#' @export
cluster_dme_tool <- function(ctx){
    group_col <- .param_col(ctx, 'group_col')
    if (is.null(group_col)) stop('cluster_dme requires a group_col (pass it as a parameter, or declare it on the ModuleSet)')

    scores <- module_scores(ctx$ms, module = ctx$module_id)
    groups <- metadata(ctx$ms)[[group_col]]
    if (is.null(groups)) stop('metadata column not found: ', group_col)

    keep <- !is.na(groups)
    test <- categorical_group_test(scores[keep], groups[keep])
    result <- test$table
    # markers must reflect upregulation only; a state where the module scores
    # lower than the rest is not a positive marker for that state
    result <- result[result$rank_biserial > 0, ]
    if (nrow(result) == 0) {
        message('cluster_dme: skipped, no state shows positive module enrichment')
        return(NULL)
    }
    top <- result[1, ]

    top_findings <- .top_findings(result, c(cluster = 'group', 'mean_score', 'rank_biserial', 'fdr'))

    compact_summary <- paste0(
        'strongest state: ', top$group,
        ' (r=', round(top$rank_biserial, 2), ', FDR=', signif(top$fdr, 2),
        '); omnibus Kruskal p=', signif(test$omnibus_p, 2)
    )

    module_fragment(
        ctx, 'cluster_dme',
        type = 'state_expression',
        result = result,
        compact_summary = compact_summary,
        top_findings = top_findings,
        effect_strength = abs(top$rank_biserial),
        significance = test$omnibus_p,
        direction = top$direction,
        # method = 'per_cell' now; a pseudobulk-aggregated variant can slot in
        # here later since categorical_group_test() only needs scores + groups
        params = list(group_col = group_col, method = 'per_cell'),
        tool_version = '0.1'
    )
}
