## cluster_expression_profile: non-differential companion to cluster_dme --
## instead of a one-vs-all winner, bins every cell's module score into GLOBAL
## deciles (computed once over all cells in the ModuleSet, not per state) and
## reports where each state's cells land on that shared scale, so a state
## that expresses the module at a medium intensity stays visible instead of
## being collapsed away by cluster_dme's winner-take-all contrast. Touches
## only the ModuleSet adapter (module_scores, metadata, pkg_versions).

#' Evidence tool: where each cell state sits in the module's global score distribution
#'
#' A core evidence tool, and the non-differential sibling of [cluster_dme_tool()].
#' `cluster_dme_tool()` reports the single most enriched state from a one-vs-all
#' test, which can hide a state that expresses the module at a medium intensity.
#' This tool instead bins every cell's module score into deciles of the
#' module's own global score distribution (all cells in `ctx$ms`, not
#' re-binned per state) and reports, per state, the mean/median decile its
#' cells occupy and the share of its cells in the top bin -- a graded profile,
#' not a contrast, so it carries `direction = 'na'`. Touches only the
#' `ModuleSet` adapter contract ([module_scores()], [metadata()],
#' [pkg_versions()]) plus base R quantile binning, so it works against any
#' backend.
#'
#' @param ctx A tool context list: `list(ms, module_id, params)`, as built by
#'   [run_module()]. `ctx$params$group_by` (required) is the metadata column
#'   naming the cell-state grouping (e.g. `'cell_type'`). `ctx$params$n_deciles`
#'   (default `10`) is the number of global bins requested; a module score
#'   distribution with heavy ties can realize fewer unique bins than
#'   requested, in which case the realized bin count is used throughout (see
#'   Details).
#' @return An `evidence_fragment` of type `'state_expression'`, or `NULL` if
#'   `ctx$ms` lacks the `grouping` or `module_scores` capability (see
#'   [capabilities()]), or if the module's score distribution has no spread
#'   at all (a single unique value, so no bin boundaries exist) -- both
#'   graceful skips, not errors.
#' @examples
#' ms <- llegir_example_moduleset()
#' cluster_expression_profile_tool(list(
#'     ms = ms, module_id = modules(ms)[1], params = list(group_by = 'cell_type')
#' ))
#' @export
cluster_expression_profile_tool <- function(ctx){
    group_by <- ctx$params$group_by
    if (is.null(group_by)) stop('cluster_expression_profile requires params$group_by')
    n_deciles <- ctx$params$n_deciles %||% 10

    if (!has_capability(ctx$ms, 'grouping') || !has_capability(ctx$ms, 'module_scores')) {
        message('cluster_expression_profile: skipped, module set lacks the grouping/module_scores capability')
        return(NULL)
    }

    scores <- module_scores(ctx$ms, module = ctx$module_id)
    groups <- metadata(ctx$ms)[[group_by]]
    if (is.null(groups)) stop('metadata column not found: ', group_by)

    keep <- !is.na(groups) & !is.na(scores)
    scores <- scores[keep]
    groups <- as.character(groups[keep])

    # global breaks, computed once over every kept cell regardless of state;
    # heavy ties (e.g. many cells at score 0) can collapse requested breaks
    # to fewer unique values, so n_bins (the realized count) rather than the
    # nominal n_deciles anchors both the decile range and the top-bin
    # threshold below -- otherwise pct_high would compare against a bin that
    # was never actually realized
    breaks <- unique(stats::quantile(scores, probs = seq(0, 1, length.out = n_deciles + 1), na.rm = TRUE))
    if (length(breaks) < 2) {
        message('cluster_expression_profile: skipped, module score distribution has no spread')
        return(NULL)
    }
    n_bins <- length(breaks) - 1
    decile <- cut(scores, breaks = breaks, labels = FALSE, include.lowest = TRUE)

    result <- data.frame(group = groups, decile = decile, score = scores) %>%
        dplyr::group_by(.data$group) %>%
        dplyr::summarise(
            n = dplyr::n(),
            mean_score = mean(.data$score),
            mean_decile = mean(.data$decile),
            median_decile = stats::median(.data$decile),
            pct_high = mean(.data$decile == n_bins),
            .groups = 'drop'
        ) %>%
        dplyr::arrange(dplyr::desc(.data$mean_decile)) %>%
        as.data.frame()

    top <- result[1, ]

    top_findings <- lapply(seq_len(min(5, nrow(result))), function(i){
        list(
            cluster = result$group[i],
            mean_decile = result$mean_decile[i],
            pct_high = result$pct_high[i]
        )
    })

    compact_summary <- paste0(
        'global module-score deciles (', n_bins, ' realized bins of ', n_deciles, ' requested): ',
        'highest state ', top$group, ' (mean_decile=', round(top$mean_decile, 1),
        '/', n_bins, ', ', round(100 * top$pct_high), '% of its cells in the top bin); ',
        nrow(result), ' states profiled'
    )

    evidence_fragment(
        fragment_id = 'cluster_expression_profile',
        tool_id = 'cluster_expression_profile',
        module_id = ctx$module_id,
        type = 'state_expression',
        result = result,
        compact_summary = compact_summary,
        top_findings = top_findings,
        # peak expression height: the top state's mean global decile, scaled
        # by the realized bin count so this stays comparable across modules
        # (and in [0,1]) even when ties collapse the requested n_deciles
        effect_strength = top$mean_decile / n_bins,
        direction = 'na',
        provenance = make_provenance(
            tool_version = '0.1',
            params = list(group_by = group_by, n_deciles = n_deciles, method = 'global_decile'),
            pkg_versions = pkg_versions(ctx$ms),
            module_method = ctx$module_method %||% NA_character_
        )
    )
}
