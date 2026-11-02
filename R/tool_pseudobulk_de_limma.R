## pseudobulk_de_limma: gene-level differential expression, restricted to one
## module's own genes, via limma-voom on the pseudo-bulk raw counts matrix
## (docs/milestones/milestone_pseudobulk.md Part 4). Complements
## differential_module_activity_tool (module-level activity) by reporting
## which of the module's genes drive a condition shift. limma only -- no
## DESeq2/edgeR; a user who wants those imports a precomputed table via
## import_tool(format = 'seurat_markers') instead.

# genes with too little signal add noise to voom's mean-variance trend
# without adding power; kept in base R (no edgeR::filterByExpr) since this
# package is limma-only by design
.pbde_filter_low_count <- function(counts_mat, min_count, min_count_samples){
    keep <- rowSums(counts_mat >= min_count) >= min_count_samples
    counts_mat[keep, , drop = FALSE]
}

#' Evidence tool: gene-level pseudo-bulk differential expression (limma-voom)
#'
#' The gene-level complement to [differential_module_activity_tool()]: runs
#' limma-voom ([limma::voom()] / [limma::lmFit()] / [limma::eBayes()]) on the
#' pseudo-bulk **raw counts** ([counts()]) restricted to the current module's
#' own genes ([gene_membership()]), for the declared two-level
#' `ctx$params$condition_col`. Reports which genes drive the shift, rather
#' than the module-level activity [differential_module_activity_tool()]
#' already covers.
#'
#' @param ctx A tool context list: `list(ms, module_id, params)`, as built by
#'   [run_module()]. `ctx$params$condition_col` (required) is the pseudo-bulk
#'   metadata column naming the two-level condition to test.
#'   `ctx$params$covariates` is an optional character vector of additional
#'   metadata columns to adjust for. `ctx$params$min_count` (default `10`)
#'   and `ctx$params$min_count_samples` (default `3`) set the low-count gene
#'   filter: a gene needs at least `min_count` reads in at least
#'   `min_count_samples` of the tested pseudo-bulk units to be kept.
#' @return An `evidence_fragment` of type `'cross_condition_delta'` (one row
#'   per gene), or `NULL` if [pseudobulk_view()] can't resolve a pseudo-bulk
#'   view for `ctx$ms`, that view lacks the `counts` capability,
#'   `condition_col` isn't found or doesn't have exactly 2 levels, none of the
#'   module's genes are present in `counts()`, or no gene survives the
#'   low-count filter -- a graceful skip, not an error.
#' @examples
#' \dontrun{
#' pb_ms <- pseudobulk_ModuleSet(pb_counts, list(module_a = c('GENE1', 'GENE2')), pb_meta)
#' pseudobulk_de_limma_tool(list(
#'     ms = pb_ms, module_id = 'module_a', params = list(condition_col = 'condition')
#' ))
#' }
#' @export
pseudobulk_de_limma_tool <- function(ctx){
    condition_col <- .param_col(ctx, 'condition_col')
    if (is.null(condition_col)) stop('pseudobulk_de_limma requires params$condition_col')
    covariates <- ctx$params$covariates %||% character(0)
    min_count <- ctx$params$min_count %||% 10
    min_count_samples <- ctx$params$min_count_samples %||% 3

    pb_view <- pseudobulk_view(ctx$ms)
    if (is.null(pb_view)) {
        message('pseudobulk_de_limma: skipped, no pseudo-bulk view resolvable for this ModuleSet')
        return(NULL)
    }
    if (!has_capability(pb_view, 'counts')) {
        message('pseudobulk_de_limma: skipped, pseudo-bulk view lacks the counts capability')
        return(NULL)
    }
    meta <- metadata(pb_view)
    if (!(condition_col %in% colnames(meta))) {
        message('pseudobulk_de_limma: skipped, condition_col not found in pseudo-bulk metadata: ', condition_col)
        return(NULL)
    }

    genes <- intersect(gene_membership(ctx$ms, ctx$module_id)$gene_name, rownames(counts(pb_view)))
    if (length(genes) == 0) {
        message('pseudobulk_de_limma: skipped, none of module ', ctx$module_id, "'s genes found in pseudo-bulk counts")
        return(NULL)
    }

    keep_units <- !is.na(meta[[condition_col]])
    for (cov in covariates) keep_units <- keep_units & !is.na(meta[[cov]])
    groups <- droplevels(factor(meta[[condition_col]][keep_units]))
    if (nlevels(groups) != 2 || sum(keep_units) < 3) {
        message('pseudobulk_de_limma: skipped, condition_col needs exactly 2 levels and >= 3 complete pseudo-bulk units')
        return(NULL)
    }

    # library size from the FULL pseudo-bulk counts matrix, not the
    # module-restricted subset below -- normalizing a module's genes by their
    # own total would be circular and wash out a real shared fold change
    all_counts <- counts(pb_view)
    lib_size <- colSums(all_counts)[keep_units]

    mod_counts <- all_counts[genes, keep_units, drop = FALSE]
    mod_counts <- .pbde_filter_low_count(mod_counts, min_count, min_count_samples)
    if (nrow(mod_counts) == 0) {
        message('pseudobulk_de_limma: skipped, no genes pass the low-count filter for module ', ctx$module_id)
        return(NULL)
    }

    design_df <- data.frame(contrast = groups)
    for (cov in covariates) design_df[[cov]] <- meta[[cov]][keep_units]
    design <- stats::model.matrix(~ ., data = design_df)

    voom_fit <- limma::voom(mod_counts, design, lib.size = lib_size)
    fit <- limma::eBayes(limma::lmFit(voom_fit, design))
    tt <- limma::topTable(fit, coef = 2, number = Inf, sort.by = 'P')
    tt$gene_name <- rownames(tt)
    rownames(tt) <- NULL
    tt <- tt[, c('gene_name', setdiff(colnames(tt), 'gene_name'))]
    top <- tt[1, ]

    levels_use <- levels(groups)
    top_findings <- .top_findings(tt, c('gene_name', 'logFC', p_value = 'P.Value', fdr = 'adj.P.Val'))
    compact_summary <- paste0(
        condition_col, ' (limma-voom): ', levels_use[2], ' vs ', levels_use[1],
        ', top gene ', top$gene_name, ' (logFC=', round(top$logFC, 2), ', FDR=', signif(top$adj.P.Val, 2), ')'
    )

    module_fragment(
        ctx, 'pseudobulk_de_limma',
        type = 'cross_condition_delta',
        result = tt,
        compact_summary = compact_summary,
        top_findings = top_findings,
        effect_strength = max(abs(tt$logFC)),
        significance = min(tt$adj.P.Val),
        direction = if (top$logFC > 0) 'up' else 'down',
        params = list(
            condition_col = condition_col, covariates = covariates, min_count = min_count,
            min_count_samples = min_count_samples, n_genes_tested = nrow(mod_counts), n_units = sum(keep_units)
        ),
        tool_version = '0.1'
    )
}
