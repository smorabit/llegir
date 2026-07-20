## signature_correlation: does this module's activity co-vary with a
## signature's score? The co-variation sibling of geneset_enrichment (which
## asks whether a module CONTAINS a signature's genes, not whether it
## CO-VARIES with them). Reuses Part 1's .score_gene_sets() (UCell/decoupleR,
## from moduleset_gene_list.R) to score a signature library, then correlates
## each signature with the module's own module_scores().
##
## LEVEL: cell-level Pearson r is always reported as descriptive co-variation
## only (no p attached) -- cells within a sample are correlated, so a
## cell-level p on module activity would be inflated. When a pseudo-bulk view
## is resolvable via pseudobulk_view(ms) (docs/milestone_pseudobulk.md Part
## 1), the signature library is re-scored directly on that view's own
## (already re-scored) expression/module_scores and the correlation's p-value
## comes from there instead -- independent pseudo-bulk units, not averaged
## cell scores.

# a signature library file: named gene sets from a local .gmt
# (fgsea::gmtPathways) or .rds (a named list of character vectors)
.read_signature_library <- function(path){
    if (grepl('\\.rds$', path, ignore.case = TRUE)) {
        readRDS(path)
    } else {
        fgsea::gmtPathways(path)
    }
}

#' Evidence tool: correlate module activity with a signature library
#'
#' The co-variation sibling of [geneset_enrichment_tool()]: overlap asks
#' whether a module *contains* a signature's genes; this tool asks whether
#' the module's *activity* co-varies with the signature's. Scores every
#' signature in `ctx$params$library_files` across cells via
#' [UCell::ScoreSignatures_UCell()] or [decoupleR::run_ulm()] (the same
#' scoring [gene_list_ModuleSet()] uses), then correlates each signature's
#' score with this module's [module_scores()].
#'
#' Reports Pearson *r* as descriptive co-variation at the cell level always
#' (never a p-value there -- cells aren't independent). When
#' [pseudobulk_view()] resolves a pseudo-bulk view for `ctx$ms` (either
#' `ctx$ms` is itself a pseudo-bulk `ModuleSet`, or one is attached via
#' [with_pseudobulk()]), the signature library is re-scored on that view's
#' own expression and correlated against its own [module_scores()] instead,
#' with a real p-value from those independent pseudo-bulk units. With no
#' pseudo-bulk view available, only the descriptive cell-level *r* is
#' reported.
#'
#' @param ctx A tool context list: `list(ms, module_id, params)`, as built by
#'   [run_module()]. `ctx$params$library_files` (required) is a named
#'   character vector of local `.gmt` or `.rds` signature-library file paths,
#'   e.g. `c(Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt')`. An `.rds` file
#'   must contain a named list of character vectors (gene sets); a `.gmt` is
#'   read via [fgsea::gmtPathways()]. `ctx$params$method` is `'UCell'`
#'   (default) or `'decoupleR'`.
#' @return An `evidence_fragment` of type `'signature_correlation'`, or
#'   `NULL` if `ctx$ms` lacks the `module_scores` or `expression` capability
#'   (see [capabilities()]) -- a graceful skip, not an error.
#' @examples
#' \dontrun{
#' ms <- llegir_example_moduleset()
#' signature_correlation_tool(list(
#'     ms = ms, module_id = modules(ms)[1],
#'     params = list(library_files = c(Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt'))
#' ))
#' }
#' @export
signature_correlation_tool <- function(ctx){
    library_files <- ctx$params$library_files
    if (is.null(library_files)) stop('signature_correlation requires params$library_files')
    method <- ctx$params$method %||% 'UCell'

    if (!has_capability(ctx$ms, 'module_scores') || !has_capability(ctx$ms, 'expression')) {
        message('signature_correlation: skipped, module set lacks the module_scores/expression capability')
        return(NULL)
    }

    provenance <- make_provenance(
        tool_version = '0.2',
        params = list(library_files = unname(library_files), method = method),
        pkg_versions = pkg_versions(ctx$ms),
        module_method = ctx$module_method %||% NA_character_
    )

    libs <- lapply(library_files, .read_signature_library)
    all_gene_sets <- do.call(c, unname(libs))
    lib_of <- rep(names(library_files), vapply(libs, length, integer(1)))
    names(lib_of) <- names(all_gene_sets)

    if (length(all_gene_sets) == 0) {
        return(evidence_fragment(
            fragment_id = 'signature_correlation',
            tool_id = 'signature_correlation',
            module_id = ctx$module_id,
            type = 'signature_correlation',
            result = data.frame(),
            compact_summary = 'no signatures found in the supplied library files',
            top_findings = list(),
            effect_strength = 0,
            direction = 'na',
            provenance = provenance
        ))
    }

    expr <- expression(ctx$ms)
    module_score <- module_scores(ctx$ms, module = ctx$module_id)
    sig_scores <- .score_gene_sets(all_gene_sets, expr, method = method)

    # when a pseudo-bulk view is attached, re-score the same signature
    # library on ITS expression and read the module's activity from its own
    # module_scores() -- independent pseudo-bulk units, so cor.test()'s
    # p-value is valid, unlike a cell-level one
    pb_view <- pseudobulk_view(ctx$ms)
    if (!is.null(pb_view)) {
        pb_module_score <- module_scores(pb_view, module = ctx$module_id)
        pb_sig_scores <- .score_gene_sets(all_gene_sets, expression(pb_view), method = method)
    }

    result <- do.call(rbind, lapply(colnames(sig_scores), function(sig){
        sig_score <- sig_scores[[sig]]
        keep <- !is.na(module_score) & !is.na(sig_score)
        r_cell <- suppressWarnings(stats::cor(module_score[keep], sig_score[keep]))
        row <- data.frame(
            signature = sig, library = unname(lib_of[[sig]]), r = r_cell,
            n = sum(keep), level = 'cell', p = NA_real_
        )
        if (!is.null(pb_view)) {
            pb_sig_score <- pb_sig_scores[[sig]]
            pb_keep <- !is.na(pb_module_score) & !is.na(pb_sig_score)
            if (sum(pb_keep) >= 3) {
                test <- suppressWarnings(stats::cor.test(pb_module_score[pb_keep], pb_sig_score[pb_keep]))
                row$r <- unname(test$estimate)
                row$p <- test$p.value
                row$n <- sum(pb_keep)
                row$level <- pb_view$data_level
            }
        }
        row
    }))

    result$fdr <- stats::p.adjust(result$p, method = 'BH')
    result <- result[order(-abs(result$r)), ]
    rownames(result) <- NULL
    top <- result[1, ]

    top_findings <- lapply(seq_len(min(5, nrow(result))), function(i){
        list(signature = result$signature[i], library = result$library[i], r = result$r[i], level = result$level[i])
    })

    compact_summary <- paste0(
        'top |r| signatures: ',
        paste(sprintf(
            '%s (r=%.2f, %s)', utils::head(result$signature, 5), utils::head(result$r, 5), utils::head(result$level, 5)
        ), collapse = '; ')
    )

    evidence_fragment(
        fragment_id = 'signature_correlation',
        tool_id = 'signature_correlation',
        module_id = ctx$module_id,
        type = 'signature_correlation',
        result = result,
        compact_summary = compact_summary,
        top_findings = top_findings,
        effect_strength = abs(top$r),
        significance = top$fdr,
        direction = if (top$r > 0) 'up' else 'down',
        provenance = provenance
    )
}
