## differential_module_activity: does a module's re-scored pseudo-bulk
## activity differ across a declared condition (ctx$params$contrast_col)?
## The DME successor for independent sample-level units
## (docs/milestones/milestone_pseudobulk.md Part 3) -- runs on
## pseudobulk_view(ms), never on correlated per-cell scores. Two engines:
## 'limma' (default) fits lmFit()/eBayes() once over the FULL module-score
## matrix so variance moderation borrows strength across every module,
## cached across the per-module orchestrator loop; 'nonparametric' reuses
## categorical_group_test() per module, no cross-module dependency.

.dma_fit_cache <- new.env(parent = emptyenv())

# lmFit()/eBayes() over the full modules x pseudo-bulk-units matrix, cached
# on a content hash of (scores_mat, design_df) -- identical across every
# per-module call within one orchestrator run, so the fit runs exactly once
.dma_limma_fit <- function(scores_mat, design_df){
    key <- digest::digest(list(scores_mat, design_df), algo = 'sha256')
    cached <- .dma_fit_cache[[key]]
    if (!is.null(cached)) return(cached)

    design <- stats::model.matrix(~ ., data = design_df)
    fit <- limma::eBayes(limma::lmFit(scores_mat, design))
    .dma_fit_cache[[key]] <- fit
    fit
}

# one row per non-reference level (logFC/p/fdr vs the reference level, the
# design's first factor level) plus a placeholder reference row, and an
# omnibus F-test p-value across every non-reference coefficient at once
.dma_limma_stats <- function(scores_mat, design_df, module_id){
    fit <- .dma_limma_fit(scores_mat, design_df)
    levels_use <- levels(design_df$contrast)
    coefs <- 2:length(levels_use)

    omnibus_tt <- limma::topTable(fit, coef = coefs, number = Inf, sort.by = 'none')
    omnibus_p <- unname(omnibus_tt[module_id, 'P.Value'])

    non_ref_rows <- do.call(rbind, lapply(coefs, function(j){
        row <- limma::topTable(fit, coef = j, number = Inf, sort.by = 'none')[module_id, ]
        data.frame(
            group = levels_use[j], effect = row$logFC, p_value = row$P.Value, fdr = row$adj.P.Val,
            direction = if (row$logFC > 0) 'up' else 'down'
        )
    }))
    ref_row <- data.frame(
        group = levels_use[1], effect = 0, p_value = NA_real_, fdr = NA_real_, direction = 'na'
    )
    list(per_group = rbind(ref_row, non_ref_rows), omnibus_p = omnibus_p)
}

# categorical_group_test()'s one-vs-rest table, renamed to this tool's
# generic 'effect' column so fragment assembly is agnostic to which engine
# produced the table
.dma_nonparametric_stats <- function(module_score, groups){
    test <- categorical_group_test(module_score, groups)
    per_group <- test$table
    per_group$effect <- per_group$rank_biserial
    per_group$rank_biserial <- NULL
    list(per_group = per_group, omnibus_p = test$omnibus_p)
}

#' Evidence tool: does a module's pseudo-bulk activity differ across a condition
#'
#' The module-level differential-activity test -- the DME successor: does
#' this module's re-scored *activity* differ across `ctx$params$contrast_col`,
#' tested on independent pseudo-bulk samples via [pseudobulk_view()] rather
#' than correlated per-cell scores. Emits a `'cross_condition_delta'`
#' fragment for a two-level contrast, or a `'categorical_association'`
#' fragment (one row per level, mirroring [cluster_dme_tool()]'s shape) for a
#' multi-level factor.
#'
#' `ctx$params$method` selects the statistic: `'limma'` (default) fits
#' [limma::lmFit()] / [limma::eBayes()] once over the **full**
#' `module_scores(pb_view)` matrix -- so variance moderation borrows strength
#' across every module -- and extracts the current module's row; the fit is
#' cached (on a content hash of the module-score matrix and design) across
#' the per-module orchestrator loop, so it runs exactly once per dataset, not
#' once per module. `'nonparametric'` reuses [categorical_group_test()]
#' (Kruskal-Wallis + one-vs-rest Wilcoxon, rank-biserial) directly on the
#' module's own pseudo-bulk scores, per module, with no cross-module step.
#'
#' @param ctx A tool context list: `list(ms, module_id, params)`, as built by
#'   [run_module()]. `ctx$params$contrast_col` (required) is the pseudo-bulk
#'   metadata column naming the condition to test. `ctx$params$covariates` is
#'   an optional character vector of additional metadata columns to adjust
#'   for (`'limma'` method only). `ctx$params$method` is `'limma'` (default)
#'   or `'nonparametric'`.
#' @return An `evidence_fragment` of type `'cross_condition_delta'` or
#'   `'categorical_association'`, or `NULL` if [pseudobulk_view()] can't
#'   resolve a pseudo-bulk view for `ctx$ms`, `contrast_col` isn't found in
#'   its metadata, or fewer than 2 contrast levels / 3 complete pseudo-bulk
#'   units remain -- a graceful skip, not an error.
#' @examples
#' \dontrun{
#' pb_ms <- pseudobulk_ModuleSet(pb_counts, list(module_a = c('GENE1', 'GENE2')), pb_meta)
#' differential_module_activity_tool(list(
#'     ms = pb_ms, module_id = 'module_a', params = list(contrast_col = 'condition')
#' ))
#' }
#' @export
differential_module_activity_tool <- function(ctx){
    contrast_col <- ctx$params$contrast_col
    if (is.null(contrast_col)) stop('differential_module_activity requires params$contrast_col')
    covariates <- ctx$params$covariates %||% character(0)
    method <- match.arg(ctx$params$method %||% 'limma', c('limma', 'nonparametric'))

    pb_view <- pseudobulk_view(ctx$ms)
    if (is.null(pb_view)) {
        message('differential_module_activity: skipped, no pseudo-bulk view resolvable for this ModuleSet')
        return(NULL)
    }
    meta <- metadata(pb_view)
    if (!(contrast_col %in% colnames(meta))) {
        message('differential_module_activity: skipped, contrast_col not found in pseudo-bulk metadata: ', contrast_col)
        return(NULL)
    }
    scores <- module_scores(pb_view)
    if (is.null(scores) || !(ctx$module_id %in% colnames(scores))) {
        message('differential_module_activity: skipped, module_scores unavailable for module ', ctx$module_id)
        return(NULL)
    }

    keep <- !is.na(meta[[contrast_col]])
    for (cov in covariates) keep <- keep & !is.na(meta[[cov]])
    groups <- droplevels(factor(meta[[contrast_col]][keep]))
    if (nlevels(groups) < 2 || sum(keep) < 3) {
        message('differential_module_activity: skipped, fewer than 2 contrast levels or 3 complete pseudo-bulk units')
        return(NULL)
    }

    if (method == 'nonparametric') {
        stats_result <- .dma_nonparametric_stats(scores[[ctx$module_id]][keep], groups)
    } else {
        design_df <- data.frame(contrast = groups)
        for (cov in covariates) design_df[[cov]] <- meta[[cov]][keep]
        scores_mat <- t(as.matrix(scores[keep, , drop = FALSE]))
        stats_result <- .dma_limma_stats(scores_mat, design_df, ctx$module_id)
    }

    per_group <- stats_result$per_group
    per_group <- per_group[order(-abs(per_group$effect)), ]
    rownames(per_group) <- NULL
    omnibus_p <- stats_result$omnibus_p
    levels_use <- levels(groups)
    nlevels_contrast <- length(levels_use)

    provenance <- make_provenance(
        tool_version = '0.1',
        params = list(contrast_col = contrast_col, covariates = covariates, method = method, n_units = sum(keep)),
        pkg_versions = pkg_versions(ctx$ms),
        module_method = ctx$module_method %||% NA_character_
    )

    if (nlevels_contrast == 2) {
        row <- per_group[per_group$group == levels_use[2], ][1, ]
        result <- data.frame(
            module = ctx$module_id, group1 = levels_use[1], group2 = levels_use[2],
            effect = row$effect, p_value = row$p_value, fdr = row$fdr
        )
        evidence_fragment(
            fragment_id = 'differential_module_activity',
            tool_id = 'differential_module_activity',
            module_id = ctx$module_id,
            type = 'cross_condition_delta',
            result = result,
            compact_summary = paste0(
                contrast_col, ' (', method, '): ', levels_use[2], ' vs ', levels_use[1],
                ' (effect=', round(row$effect, 2), ', FDR=', signif(row$fdr, 2), ')'
            ),
            top_findings = list(list(
                group1 = levels_use[1], group2 = levels_use[2], effect = row$effect, p_value = row$p_value
            )),
            effect_strength = abs(row$effect),
            significance = row$fdr,
            direction = row$direction,
            provenance = provenance
        )
    } else {
        top <- per_group[1, ]
        top_findings <- lapply(seq_len(min(5, nrow(per_group))), function(i){
            list(group = per_group$group[i], effect = per_group$effect[i])
        })
        evidence_fragment(
            fragment_id = 'differential_module_activity',
            tool_id = 'differential_module_activity',
            module_id = ctx$module_id,
            type = 'categorical_association',
            result = per_group,
            compact_summary = paste0(
                contrast_col, ' (', method, '): strongest level ', top$group,
                ' (effect=', round(top$effect, 2), '); omnibus p=', signif(omnibus_p, 2)
            ),
            top_findings = top_findings,
            effect_strength = abs(top$effect),
            significance = omnibus_p,
            direction = top$direction,
            provenance = provenance
        )
    }
}
