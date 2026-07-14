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
    categorical_association = function(result, params){
        group_col <- params$group_col %||% 'group'
        effect_col <- params$effect_col %||% 'rank_biserial'
        p_col <- params$significance_col %||% 'fdr'
        required <- c(group_col, effect_col)
        missing_cols <- setdiff(required, colnames(result))
        if (length(missing_cols) > 0) {
            stop('import_fragment(categorical_association) missing columns: ', paste(missing_cols, collapse = ', '))
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
)

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
#' @return An `evidence_fragment` object.
#' @export
import_fragment <- function(module_id, type, result, fragment_id = NULL,
                             tool_id = 'import_fragment', params = list()){
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
            pkg_versions = list(),
            source = 'user_supplied'
        )
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
        params = ctx$params
    )
}
