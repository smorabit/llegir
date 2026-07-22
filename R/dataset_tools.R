## dataset_tools.R: home for dataset-scope tools (docs/milestones/milestone_dataset_tools.md
## Part 3+). These run once per dataset via run_dataset_context(), never per
## module, and touch only the ModuleSet adapter contract (metadata(),
## has_capability(), pkg_versions()) -- never hdWGCNA/Seurat directly.

# shannon entropy (natural log) of a count vector; 0 when every unit falls
# into one group (maximally skewed), ln(k) when spread evenly across k groups
.shannon_entropy <- function(counts){
    p <- counts[counts > 0] / sum(counts)
    -sum(p * log(p))
}

#' Dataset tool: cell-state census and condition covariate balance
#'
#' A core dataset tool. Touches only the `ModuleSet` adapter contract
#' ([metadata()], [has_capability()], [pkg_versions()]). Summarizes how units
#' (cells or samples) distribute across `ctx$params$group_col` and, when
#' `ctx$params$condition_col` is given, whether that distribution is skewed
#' across condition levels -- the compositional-confounding check every
#' per-module synthesis should see as global framing before it interprets a
#' module as biology rather than cell-type imbalance.
#'
#' @param ctx A dataset tool context list: `list(ms, params, module_method)`,
#'   as built by [run_dataset_context()]. `ctx$params$group_col` (required) is
#'   the metadata column naming the cell-state/cluster grouping.
#'   `ctx$params$condition_col` (optional) is the metadata column to check the
#'   grouping for skew against; when omitted, only a group census is
#'   computed. `ctx$params$sample_col` (default `'sample'`) names the
#'   metadata sample-id column, consulted when the `sample_ids` capability
#'   holds. `ctx$params$residual_threshold` (default `2`) is the absolute
#'   chi-square standardized residual above which a group x condition cell is
#'   flagged. `ctx$params$min_samples` (default `3`) and
#'   `ctx$params$min_cells` (default `20`) are the per-condition minimums
#'   below which `'underpowered_contrast'` fires.
#' @return A `dataset_fragment` of type `'composition_summary'`, or `NULL` if
#'   `ctx$ms` lacks the `grouping` capability (see [capabilities()]) -- a
#'   graceful skip, not an error.
#' @examples
#' ms <- llegir_example_moduleset()
#' params <- list(group_col = 'cell_type', condition_col = 'diagnosis')
#' dataset_composition_tool(list(ms = ms, params = params))
#' @export
dataset_composition_tool <- function(ctx){
    group_col <- ctx$params$group_col
    if (is.null(group_col)) stop('dataset_composition requires params$group_col')
    condition_col <- ctx$params$condition_col
    sample_col <- ctx$params$sample_col %||% 'sample'
    residual_threshold <- ctx$params$residual_threshold %||% 2
    min_samples <- ctx$params$min_samples %||% 3
    min_cells <- ctx$params$min_cells %||% 20

    if (!has_capability(ctx$ms, 'grouping')) {
        message('dataset_composition: skipped, module set lacks the grouping capability')
        return(NULL)
    }

    meta <- metadata(ctx$ms)
    groups <- meta[[group_col]]
    if (is.null(groups)) stop('metadata column not found: ', group_col)
    groups <- droplevels(as.factor(groups))

    n_units <- length(groups)
    unit_label <- paste0(ctx$ms$data_level %||% 'cell', 's')
    group_counts <- table(groups)
    group_entropy <- .shannon_entropy(as.numeric(group_counts))
    caveats <- list()

    if (is.null(condition_col)) {
        result <- data.frame(
            group = names(group_counts),
            n = as.integer(group_counts),
            prop = as.numeric(group_counts) / n_units
        )
        result <- result[order(-result$n), ]
        rownames(result) <- NULL

        top_findings <- lapply(seq_len(min(5, nrow(result))), function(i){
            list(group = result$group[i], n = result$n[i], prop = round(result$prop[i], 3))
        })
        top_findings[[length(top_findings) + 1]] <- list(metric = 'shannon_entropy', value = round(group_entropy, 3))

        compact_summary <- paste0(
            'across ', format(n_units, big.mark = ','), ' ', unit_label, ': ',
            group_col, ' spans ', nlevels(groups), ' levels (entropy=', round(group_entropy, 2), ')'
        )
    } else {
        conditions <- meta[[condition_col]]
        if (is.null(conditions)) stop('metadata column not found: ', condition_col)
        conditions <- droplevels(as.factor(conditions))

        cross_tab <- table(groups, conditions)
        cond_totals <- colSums(cross_tab)
        # a chi-square test (and its standardized residuals) is undefined with
        # only one row or one column; fall back to NA residuals rather than error
        chisq_ok <- nrow(cross_tab) > 1 && ncol(cross_tab) > 1
        if (chisq_ok) {
            chisq <- suppressWarnings(stats::chisq.test(cross_tab))
            std_resid <- chisq$stdres
            expected <- chisq$expected
        } else {
            std_resid <- matrix(NA_real_, nrow(cross_tab), ncol(cross_tab), dimnames = dimnames(cross_tab))
            expected <- matrix(NA_real_, nrow(cross_tab), ncol(cross_tab), dimnames = dimnames(cross_tab))
        }

        result <- do.call(rbind, lapply(colnames(cross_tab), function(cnd){
            data.frame(
                group = rownames(cross_tab),
                condition = cnd,
                n = as.integer(cross_tab[, cnd]),
                prop_of_condition = as.numeric(cross_tab[, cnd]) / cond_totals[[cnd]],
                expected = as.numeric(expected[, cnd]),
                std_resid = as.numeric(std_resid[, cnd])
            )
        }))
        rownames(result) <- NULL
        ranked <- result[order(-abs(result$std_resid)), ]

        top_findings <- lapply(seq_len(min(5, nrow(ranked))), function(i){
            list(
                group = ranked$group[i], condition = ranked$condition[i], n = ranked$n[i],
                std_resid = round(ranked$std_resid[i], 2),
                direction = if (is.na(ranked$std_resid[i])) NA_character_ else if (ranked$std_resid[i] > 0) 'over' else 'under'
            )
        })
        top_findings[[length(top_findings) + 1]] <- list(metric = 'shannon_entropy', value = round(group_entropy, 3))

        if (chisq_ok && any(abs(result$std_resid) > residual_threshold, na.rm = TRUE)) {
            caveats[[length(caveats) + 1]] <- 'cell_state_imbalanced_across_condition'
        }

        underpowered <- any(cond_totals < min_cells)
        if (has_capability(ctx$ms, 'sample_ids') && !is.null(meta[[sample_col]])) {
            samples_per_condition <- tapply(meta[[sample_col]], conditions, function(x) length(unique(x)))
            for (cnd in names(samples_per_condition)) {
                top_findings[[length(top_findings) + 1]] <- list(
                    metric = 'samples_per_condition', condition = cnd,
                    n_samples = unname(samples_per_condition[[cnd]])
                )
            }
            underpowered <- underpowered || any(samples_per_condition < min_samples)
        }
        if (underpowered) caveats[[length(caveats) + 1]] <- 'underpowered_contrast'

        top_skew <- ranked[1, ]
        skew_desc <- if (chisq_ok) {
            paste0(
                '; strongest skew vs ', condition_col, ': ', top_skew$group, ' in ', top_skew$condition,
                ' (z=', round(top_skew$std_resid, 2), ')'
            )
        } else ''
        compact_summary <- paste0(
            'across ', format(n_units, big.mark = ','), ' ', unit_label, ': ',
            group_col, ' spans ', nlevels(groups), ' levels (entropy=', round(group_entropy, 2), ')', skew_desc
        )
    }

    dataset_fragment(
        fragment_id = 'composition',
        tool_id = 'dataset_composition',
        type = 'composition_summary',
        result = result,
        compact_summary = compact_summary,
        top_findings = top_findings,
        caveats = caveats,
        provenance = make_provenance(
            tool_version = '0.1',
            params = list(group_col = group_col, condition_col = condition_col %||% NA_character_),
            pkg_versions = pkg_versions(ctx$ms)
        )
    )
}
