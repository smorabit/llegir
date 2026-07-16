## import_fragment: let a user inject an already-computed result table (DMEs,
## GO enrichment, etc.) as a validated evidence_fragment instead of
## recomputing it. Each `type` has a normalizer that derives compact_summary /
## top_findings / effect_strength / significance / direction from the user's
## table (column names configurable via `params`, since a user-supplied table
## won't share this repo's exact column names); provenance.source is set to
## 'user_supplied' so faithfulness/reproducibility checks can distinguish these
## from tool-computed fragments. The synthesis layer (M2) treats them
## identically. No adapter/backend dependency -- this only touches a table.

.import_normalizers <- list(
    geneset_enrichment = function(result, params){
        term_col <- params$term_col %||% 'term'
        p_col <- params$significance_col %||% 'fdr'
        effect_col <- params$effect_col %||% 'odds_ratio'
        required <- c(term_col, p_col, effect_col)
        missing_cols <- setdiff(required, colnames(result))
        if (length(missing_cols) > 0) {
            stop('import_fragment(geneset_enrichment) missing columns: ', paste(missing_cols, collapse = ', '))
        }

        ordered <- result[order(result[[p_col]]), ]
        top <- utils::head(ordered, params$n_top %||% 20)
        top_findings <- lapply(seq_len(min(5, nrow(top))), function(i){
            list(term = top[[term_col]][i], significance = top[[p_col]][i], effect = top[[effect_col]][i])
        })

        list(
            result = top,
            compact_summary = paste0('user-supplied enrichment: top terms: ', paste(utils::head(top[[term_col]], 5), collapse = '; ')),
            top_findings = top_findings,
            effect_strength = if (nrow(top) > 0) max(abs(top[[effect_col]]), na.rm = TRUE) else 0,
            significance = if (nrow(top) > 0) min(top[[p_col]], na.rm = TRUE) else NA_real_,
            direction = 'up'
        )
    },
    # shared by categorical_association and state_expression: both are a
    # group-level test result (one row per group/cluster) that differ only in
    # semantics (an arbitrary metadata group vs. a cell state/cluster) and in
    # which column name convention the source tool defaults to
    categorical_association = function(result, params){
        .import_group_test_normalizer(result, params, effect_default = 'rank_biserial')
    },
    state_expression = function(result, params){
        .import_group_test_normalizer(result, params, effect_default = 'avg_log2FC')
    },
    # a two-condition gene/feature-level DE table (Seurat FindMarkers, DESeq2,
    # edgeR): one row per feature rather than one row per group
    cross_condition_delta = function(result, params){
        feature_col <- params$feature_col %||% 'gene'
        effect_col <- params$effect_col %||% 'log2FC'
        p_col <- params$significance_col %||% 'padj'
        if (!(feature_col %in% colnames(result))) result[[feature_col]] <- rownames(result)
        required <- c(effect_col, p_col)
        missing_cols <- setdiff(required, colnames(result))
        if (length(missing_cols) > 0) {
            stop('import_fragment(cross_condition_delta) missing columns: ', paste(missing_cols, collapse = ', '))
        }

        ordered <- result[order(result[[p_col]]), ]
        top <- utils::head(ordered, params$n_top %||% 20)
        top_findings <- lapply(seq_len(min(5, nrow(top))), function(i){
            list(feature = top[[feature_col]][i], effect = top[[effect_col]][i], significance = top[[p_col]][i])
        })
        top1 <- if (nrow(top) > 0) top[1, ] else NULL

        list(
            result = top,
            compact_summary = paste0(
                'user-supplied condition contrast: top feature ',
                if (!is.null(top1)) top1[[feature_col]] else 'NA',
                ' (', effect_col, '=', if (!is.null(top1)) round(top1[[effect_col]], 2) else NA, ')'
            ),
            top_findings = top_findings,
            effect_strength = if (nrow(top) > 0) max(abs(top[[effect_col]]), na.rm = TRUE) else 0,
            significance = if (nrow(top) > 0) min(top[[p_col]], na.rm = TRUE) else NA_real_,
            direction = if (is.null(top1)) 'na' else if (top1[[effect_col]] > 0) 'up' else 'down'
        )
    }
)

# shared normalizer body for a one-row-per-group test result (categorical
# metadata association, or which cell state/cluster expresses a module); the
# only difference between formats is which column name a given tool defaults
# to for its effect size (e.g. hdWGCNA DME uses `avg_log2FC`, this package's
# own categorical_group_test() uses `rank_biserial`)
.import_group_test_normalizer <- function(result, params, effect_default){
    group_col <- params$group_col %||% 'group'
    effect_col <- params$effect_col %||% effect_default
    p_col <- params$significance_col %||% 'fdr'
    required <- c(group_col, effect_col)
    missing_cols <- setdiff(required, colnames(result))
    if (length(missing_cols) > 0) {
        stop('import_fragment missing columns: ', paste(missing_cols, collapse = ', '))
    }

    ordered <- result[order(-abs(result[[effect_col]])), ]
    top <- ordered[1, ]
    top_findings <- lapply(seq_len(min(5, nrow(ordered))), function(i){
        list(group = ordered[[group_col]][i], effect = ordered[[effect_col]][i])
    })

    list(
        result = ordered,
        compact_summary = paste0(
            'user-supplied association: strongest group ', top[[group_col]],
            ' (effect=', round(top[[effect_col]], 2), ')'
        ),
        top_findings = top_findings,
        effect_strength = abs(top[[effect_col]]),
        significance = if (p_col %in% colnames(result)) top[[p_col]] else NA_real_,
        direction = if (top[[effect_col]] > 0) 'up' else 'down'
    )
}

#' Import a user-supplied result table as an evidence fragment
#'
#' Lets a user inject an already-computed result table (DMEs, GO enrichment,
#' etc.) as a validated [evidence_fragment()] instead of recomputing it via a
#' core tool. `provenance$source` is set to `'user_supplied'` so
#' faithfulness/reproducibility checks can distinguish these from
#' tool-computed fragments; the synthesis layer treats both identically.
#'
#' @param module_id The module this fragment describes.
#' @param type One of the supported fragment types: `'geneset_enrichment'`,
#'   `'categorical_association'`.
#' @param result A tidy data.frame with the user's result table.
#' @param fragment_id Unique id within the packet. Defaults to
#'   `paste0('imported::', type)`.
#' @param tool_id Tool id recorded in provenance. Default `'import_fragment'`.
#' @param params Named list of column-name overrides (e.g. `term_col`,
#'   `significance_col`, `effect_col`) and other normalizer options (e.g.
#'   `n_top`), since a user-supplied table won't share this package's exact
#'   column names.
#' @param source_file Optional path to the file `result` was originally read
#'   from (e.g. a `FindMarkers()` CSV export). Recorded in
#'   `provenance$params$source_file`, and content-hashed into
#'   `provenance$input_hashes$source_file` if the file still exists, so the
#'   import is traceable back to its origin.
#' @return An `evidence_fragment` object.
#' @export
import_fragment <- function(module_id, type, result, fragment_id = NULL,
                             tool_id = 'import_fragment', params = list(),
                             source_file = NULL){
    if (!is.data.frame(result)) stop('import_fragment requires result to be a data.frame')
    normalizer <- .import_normalizers[[type]]
    if (is.null(normalizer)) {
        stop(
            'import_fragment has no normalizer for type: ', type,
            ' (supported: ', paste(names(.import_normalizers), collapse = ', '), ')'
        )
    }
    norm <- normalizer(result, params)
    if (is.null(fragment_id)) fragment_id <- paste0('imported::', type)

    input_hashes <- list()
    if (!is.null(source_file)) {
        params$source_file <- source_file
        if (file.exists(source_file)) {
            input_hashes$source_file <- digest::digest(file = source_file, algo = 'sha256')
        }
    }

    evidence_fragment(
        fragment_id = fragment_id,
        tool_id = tool_id,
        module_id = module_id,
        type = type,
        result = norm$result,
        compact_summary = norm$compact_summary,
        top_findings = norm$top_findings,
        effect_strength = norm$effect_strength,
        significance = norm$significance,
        direction = norm$direction,
        provenance = make_provenance(
            tool_version = NA_character_,
            params = params,
            input_hashes = input_hashes,
            pkg_versions = list(),
            source = 'user_supplied'
        )
    )
}

#' Import a Seurat / DESeq2 / edgeR differential-expression table
#'
#' Sensible defaults for `Seurat::FindMarkers()` output (`avg_log2FC`,
#' `p_val_adj`, feature names as rownames). Point `column_map` at a DESeq2
#' (`log2FoldChange`/`padj`) or edgeR (`logFC`/`FDR`) table instead to reuse
#' the same importer. If `result` has a `group_col` (e.g. `cluster`, as in
#' `Seurat::FindAllMarkers()`), the fragment is a per-group
#' `'categorical_association'`; otherwise it's a single-contrast
#' `'cross_condition_delta'` (one row per gene/feature).
#'
#' @param module_id The module this fragment describes.
#' @param result A tidy DE result data.frame.
#' @param group_col Column naming a group/cluster contrast, if any (default
#'   `'cluster'`). Only used if present in `result`.
#' @param column_map Named list of column overrides: `feature_col` (default
#'   `'gene'`, falls back to rownames if absent), `effect_col` (default
#'   `'avg_log2FC'`), `significance_col` (default `'p_val_adj'`).
#' @param source_file Optional path `result` was read from; see
#'   [import_fragment()].
#' @param ... Passed to [import_fragment()] (e.g. `fragment_id`, `tool_id`).
#' @return An `evidence_fragment` object.
#' @export
import_seurat_markers <- function(module_id, result, group_col = 'cluster',
                                   column_map = list(), source_file = NULL, ...){
    defaults <- list(feature_col = 'gene', effect_col = 'avg_log2FC', significance_col = 'p_val_adj')
    params <- utils::modifyList(defaults, column_map)

    has_group <- !is.null(group_col) && group_col %in% colnames(result)
    if (has_group) {
        type <- 'categorical_association'
        params$group_col <- group_col
    } else {
        type <- 'cross_condition_delta'
    }

    import_fragment(
        module_id = module_id, type = type, result = result,
        params = params, source_file = source_file, ...
    )
}

#' Import an hdWGCNA differential module eigengene (DME) table
#'
#' Sensible defaults for `hdWGCNA::FindAllDMEs()` output (`group`,
#' `avg_log2FC`, `p_val_adj`). Produces a `'state_expression'` fragment — the
#' same type [cluster_dme_tool()] produces — so an externally computed DME
#' table (run outside this package, or against a different grouping) feeds
#' the synthesis layer identically to the built-in tool.
#'
#' @param module_id The module this fragment describes.
#' @param result A tidy DME result data.frame (one row per group).
#' @param column_map Named list of column overrides: `group_col` (default
#'   `'group'`), `effect_col` (default `'avg_log2FC'`), `significance_col`
#'   (default `'p_val_adj'`).
#' @param source_file Optional path `result` was read from; see
#'   [import_fragment()].
#' @param ... Passed to [import_fragment()] (e.g. `fragment_id`, `tool_id`).
#' @return An `evidence_fragment` object.
#' @export
import_hdwgcna_dme <- function(module_id, result, column_map = list(), source_file = NULL, ...){
    defaults <- list(group_col = 'group', effect_col = 'avg_log2FC', significance_col = 'p_val_adj')
    params <- utils::modifyList(defaults, column_map)
    import_fragment(
        module_id = module_id, type = 'state_expression', result = result,
        params = params, source_file = source_file, ...
    )
}

#' Import an EnrichR / GeneOverlap enrichment table
#'
#' Sensible defaults for EnrichR output (`Term`, `Odds.Ratio`,
#' `Adjusted.P.value`). Point `column_map` at a `GeneOverlap`-style table
#' instead (e.g. `list(term_col = 'category', effect_col = 'odds.ratio',
#' significance_col = 'pval')`) to reuse the same importer.
#'
#' @param module_id The module this fragment describes.
#' @param result A tidy enrichment result data.frame.
#' @param column_map Named list of column overrides: `term_col` (default
#'   `'Term'`), `effect_col` (default `'Odds.Ratio'`), `significance_col`
#'   (default `'Adjusted.P.value'`).
#' @param source_file Optional path `result` was read from; see
#'   [import_fragment()].
#' @param ... Passed to [import_fragment()] (e.g. `fragment_id`, `tool_id`).
#' @return An `evidence_fragment` object.
#' @export
import_enrichr <- function(module_id, result, column_map = list(), source_file = NULL, ...){
    defaults <- list(term_col = 'Term', effect_col = 'Odds.Ratio', significance_col = 'Adjusted.P.value')
    params <- utils::modifyList(defaults, column_map)
    import_fragment(
        module_id = module_id, type = 'geneset_enrichment', result = result,
        params = params, source_file = source_file, ...
    )
}

#' `ctx`-compatible tool wrapper around [import_fragment()]
#'
#' Slots [import_fragment()] into an orchestrator's `tool_config` list exactly
#' like any other tool. Reads `ctx$params$result` (a data.frame) or
#' `ctx$params$result_path` (a delimited file) plus `ctx$params$type`.
#'
#' @param ctx A tool context list: `list(ms, module_id, params)`, as built by
#'   [run_module()].
#' @return An `evidence_fragment` object.
#' @export
import_fragment_tool <- function(ctx){
    type <- ctx$params$type
    if (is.null(type)) stop('import_fragment_tool requires params$type')

    result <- ctx$params$result
    if (is.null(result)) {
        result_path <- ctx$params$result_path
        if (is.null(result_path)) stop('import_fragment_tool requires params$result or params$result_path')
        result <- utils::read.delim(result_path, stringsAsFactors = FALSE)
    }

    import_fragment(
        module_id = ctx$module_id,
        type = type,
        result = result,
        fragment_id = ctx$params$fragment_id,
        tool_id = ctx$params$tool_id %||% 'import_fragment',
        params = ctx$params,
        source_file = ctx$params$result_path %||% ctx$params$source_file
    )
}
