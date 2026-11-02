## import_fragment: let a user inject an already-computed result table (DMEs,
## GO enrichment, etc.) as a validated evidence_fragment instead of
## recomputing it. Each `type` has a normalizer that derives compact_summary /
## top_findings / effect_strength / significance / direction from the user's
## table (column names configurable via `params`, since a user-supplied table
## won't share this repo's exact column names); provenance.source is set to
## 'user_supplied' so faithfulness/reproducibility checks can distinguish these
## from tool-computed fragments. The synthesis layer (M2) treats them
## identically. No adapter/backend dependency -- this only touches a table.

# an overlap column is either a count or an Enrichr/hdWGCNA-style 'k/n' or
# 'k|n' string; only the overlapping count k is kept
.overlap_count <- function(x){
    if (is.numeric(x)) return(x)
    suppressWarnings(as.numeric(sub('[/|].*$', '', as.character(x))))
}

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

        # tie-break by descending absolute effect: an imported overlap table
        # (e.g. CancerSEA) can have identical significance across every row,
        # and order()'s stable sort would otherwise silently keep whatever
        # rows came first in the input (alphabetical by term) instead of the
        # strongest ones
        ordered <- result[order(result[[p_col]], -abs(result[[effect_col]])), ]
        top <- utils::head(ordered, params$n_top %||% 20)
        alpha <- params$alpha %||% 0.05

        # overlap statistics are optional: common column names across GeneOverlap,
        # hdWGCNA and Enrichr exports are picked up unless the caller names one
        overlap_col <- params$overlap_col %||%
            utils::head(intersect(c('size_intersection', 'ngenes', 'n_overlap', 'overlap_size', 'Overlap', 'overlap'), colnames(top)), 1)
        jaccard_col <- params$jaccard_col %||% utils::head(intersect(c('jaccard', 'Jaccard'), colnames(top)), 1)
        n_overlap <- if (length(overlap_col) == 1) .overlap_count(top[[overlap_col]]) else NULL
        jaccard <- if (length(jaccard_col) == 1) as.numeric(top[[jaccard_col]]) else NULL

        # 3 rather than 5, matching geneset_enrichment_tool(): the overlap
        # statistics make each entry longer, and compact_summary names the same terms
        top_findings <- lapply(seq_len(min(3, nrow(top))), function(i){
            finding <- list(term = top[[term_col]][i], significance = top[[p_col]][i], effect = top[[effect_col]][i])
            if (!is.null(n_overlap)) finding$n_overlap <- n_overlap[i]
            if (!is.null(jaccard)) finding$jaccard <- jaccard[i]
            finding
        })

        list(
            result = top,
            compact_summary = .enrichment_compact_summary(
                top[[term_col]], top[[p_col]], n_overlap = n_overlap, jaccard = jaccard,
                odds_ratio = top[[effect_col]], n_tested = nrow(result), alpha = alpha,
                prefix = 'user-supplied enrichment: '
            ),
            top_findings = top_findings,
            effect_strength = if (nrow(top) > 0) max(abs(top[[effect_col]]), na.rm = TRUE) else 0,
            significance = if (nrow(top) > 0) min(top[[p_col]], na.rm = TRUE) else NA_real_,
            direction = .enrichment_direction(top[[p_col]], alpha)
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
    # a module-vs-signature correlation table (cGEP/program scores, curated
    # gene-set activities, ...): one row per named signature, mirroring
    # signature_correlation_tool()'s own top_findings shape (signature, r) so
    # an imported fragment reads identically to a computed one
    signature_correlation = function(result, params){
        sig_col <- params$signature_col %||% 'signature'
        effect_col <- params$effect_col %||% 'r'
        p_col <- params$significance_col %||% 'p'
        required <- c(sig_col, effect_col)
        missing_cols <- setdiff(required, colnames(result))
        if (length(missing_cols) > 0) {
            stop('import_fragment(signature_correlation) missing columns: ', paste(missing_cols, collapse = ', '))
        }

        ordered <- result[order(-abs(result[[effect_col]])), ]
        top <- ordered[1, ]
        top_findings <- lapply(seq_len(min(5, nrow(ordered))), function(i){
            list(signature = ordered[[sig_col]][i], r = ordered[[effect_col]][i])
        })

        list(
            result = ordered,
            compact_summary = paste0(
                'user-supplied signature correlation: top |r| signature ', top[[sig_col]],
                ' (r=', round(top[[effect_col]], 2), ')'
            ),
            top_findings = top_findings,
            effect_strength = abs(top[[effect_col]]),
            significance = if (p_col %in% colnames(result)) top[[p_col]] else NA_real_,
            direction = if (top[[effect_col]] > 0) 'up' else 'down'
        )
    },
    # a module's correlation with one (or a few) continuous variable(s) (ASA,
    # a clinical score, ...) rather than a named signature library; variable_col
    # is optional since the common case is already scoped to a single variable
    # (one row per module, e.g. an ASA correlation table)
    continuous_correlation = function(result, params){
        var_col <- params$variable_col
        effect_col <- params$effect_col %||% 'r'
        p_col <- params$significance_col %||% 'p'
        n_col <- params$n_col %||% 'n'
        if (!(effect_col %in% colnames(result))) {
            stop('import_fragment(continuous_correlation) missing columns: ', effect_col)
        }
        has_var_col <- !is.null(var_col) && var_col %in% colnames(result)

        ordered <- if (has_var_col) result[order(-abs(result[[effect_col]])), ] else result
        top <- ordered[1, ]
        variable_label <- if (has_var_col) top[[var_col]] else (params$variable_name %||% 'variable')
        top_findings <- lapply(seq_len(min(5, nrow(ordered))), function(i){
            entry <- list(r = ordered[[effect_col]][i])
            if (has_var_col) entry$variable <- ordered[[var_col]][i]
            if (n_col %in% colnames(result)) entry$n <- ordered[[n_col]][i]
            entry
        })

        list(
            result = ordered,
            compact_summary = paste0(
                'user-supplied continuous correlation: ', variable_label, ' (r=', round(top[[effect_col]], 2), ')'
            ),
            top_findings = top_findings,
            effect_strength = abs(top[[effect_col]]),
            significance = if (p_col %in% colnames(result)) top[[p_col]] else NA_real_,
            direction = if (top[[effect_col]] > 0) 'up' else 'down'
        )
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

# the normalized shape for a 0-row import: no findings, no effect, no direction
.empty_import <- function(type){
    list(
        result = data.frame(),
        compact_summary = paste0('user-supplied ', type, ': no rows'),
        top_findings = list(),
        effect_strength = NA_real_,
        significance = NA_real_,
        direction = 'na'
    )
}

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

#---------------------------------------------------------
# shared import internals
#---------------------------------------------------------

# runs the per-type normalizer, treating an empty table as a legitimate
# no-finding import (e.g. no significant rows for this module)
.normalize_import <- function(normalizers, type, result, params, caller){
    if (!is.data.frame(result)) stop(caller, ' requires result to be a data.frame')
    normalizer <- normalizers[[type]]
    if (is.null(normalizer)) {
        stop(caller, ' has no normalizer for type: ', type, ' (supported: ', paste(names(normalizers), collapse = ', '), ')')
    }
    if (nrow(result) == 0) .empty_import(type) else normalizer(result, params)
}

# provenance for an imported table: the normalizer options (never the table
# itself), the source file's content hash when there is one, and otherwise a
# hash of the table so the import stays traceable
.import_provenance <- function(params, result, source_file, module_method){
    input_hashes <- list()
    if (!is.null(source_file)) {
        params$source_file <- source_file
        if (file.exists(source_file)) input_hashes$source_file <- digest::digest(file = source_file, algo = 'sha256')
    }
    if (length(input_hashes) == 0) input_hashes$table <- digest::digest(result, algo = 'sha256')
    make_provenance(
        tool_version = NA_character_, params = params, input_hashes = input_hashes,
        pkg_versions = list(), source = 'user_supplied', module_method = module_method
    )
}

#' Import a user-supplied result table as an evidence fragment
#'
#' The low-level constructor behind [import_tool()]: turns one module's
#' already-computed result table into a validated [evidence_fragment()].
#' Most users want [import_tool()], which reads files, splits a table by
#' module and slots the import into [run_evidence()]. `provenance$source` is
#' `'user_supplied'`, so imported fragments stay distinguishable from
#' computed ones; the synthesis layer treats both identically.
#'
#' @param module_id The module this fragment describes.
#' @param type One of the supported fragment types: `'geneset_enrichment'`,
#'   `'categorical_association'`, `'state_expression'`, `'cross_condition_delta'`,
#'   `'signature_correlation'`, `'continuous_correlation'`.
#' @param result A tidy data.frame with the user's result table. A 0-row
#'   table gives a valid fragment with no findings.
#' @param fragment_id Unique id within the packet. Defaults to
#'   `paste0('imported::', type)`.
#' @param tool_id Tool id recorded on the fragment. Default `'import_fragment'`.
#' @param params Named list of column-name overrides (`term_col`,
#'   `effect_col`, `significance_col`, `group_col`, `feature_col`,
#'   `signature_col`, `variable_col`, `n_col`, `overlap_col`, `jaccard_col`)
#'   and normalizer options (`alpha`, `n_top`, `variable_name`). For
#'   `'geneset_enrichment'`, `alpha` (default 0.05) is the significance
#'   threshold stated in `compact_summary`, and overlap / Jaccard columns are
#'   auto-detected from common names when not given; `'k/n'` overlap strings
#'   are reduced to `k`.
#' @param source_file Optional path to the file `result` was read from;
#'   recorded and content-hashed in provenance. Without one, a hash of
#'   `result` is recorded instead.
#' @param module_method Optional description of how the modules were built;
#'   see [run_module()].
#' @return An `evidence_fragment` object.
#' @export
import_fragment <- function(module_id, type, result, fragment_id = NULL,
                             tool_id = 'import_fragment', params = list(),
                             source_file = NULL, module_method = NA_character_){
    norm <- .normalize_import(.import_normalizers, type, result, params, 'import_fragment')
    evidence_fragment(
        fragment_id = fragment_id %||% paste0('imported::', type),
        tool_id = tool_id,
        module_id = module_id,
        type = type,
        result = norm$result,
        compact_summary = norm$compact_summary,
        top_findings = norm$top_findings,
        effect_strength = norm$effect_strength,
        significance = norm$significance,
        direction = norm$direction,
        provenance = .import_provenance(params, result, source_file, module_method)
    )
}

## import_dataset_fragment: dataset-scope analog of import_fragment() above
## (docs/milestones/milestone_dataset_tools.md Part 4). Lets a user inject an
## already-computed compositional / differential-abundance result (miloR,
## propeller, sccomp, ...) as a validated dataset_fragment instead of
## computing it via dataset_composition_tool(). provenance$source is
## 'user_supplied', same distinction as import_fragment().

.import_dataset_normalizers <- list(
    # a group x condition differential-abundance result, one row per unit
    # tested (a miloR neighborhood, or already one row per cluster for
    # propeller/sccomp-style tables); aggregates per group_col so the
    # fragment's result is a small per-cell-state summary, never the raw
    # per-neighborhood table
    composition_summary = function(result, params){
        group_col <- params$group_col %||% 'celltype'
        effect_col <- params$effect_col %||% 'logFC'
        p_col <- params$significance_col %||% 'SpatialFDR'
        alpha <- params$alpha %||% 0.05
        required <- c(group_col, effect_col, p_col)
        missing_cols <- setdiff(required, colnames(result))
        if (length(missing_cols) > 0) {
            stop('import_dataset_fragment(composition_summary) missing columns: ', paste(missing_cols, collapse = ', '))
        }

        groups <- droplevels(as.factor(result[[group_col]]))
        summary_df <- do.call(rbind, lapply(levels(groups), function(g){
            rows <- result[groups == g, ]
            sig <- rows[[p_col]] < alpha
            n_sig <- sum(sig, na.rm = TRUE)
            mean_effect <- if (n_sig > 0) mean(rows[[effect_col]][sig], na.rm = TRUE) else mean(rows[[effect_col]], na.rm = TRUE)
            data.frame(
                group = g,
                n_tested = nrow(rows),
                n_sig = n_sig,
                mean_effect = mean_effect,
                direction = if (is.na(mean_effect)) 'na' else if (mean_effect > 0) 'up' else 'down'
            )
        }))
        summary_df <- summary_df[order(-summary_df$n_sig, -abs(summary_df$mean_effect)), ]
        rownames(summary_df) <- NULL

        top_findings <- lapply(seq_len(min(5, nrow(summary_df))), function(i){
            list(
                group = summary_df$group[i], n_sig = summary_df$n_sig[i],
                n_tested = summary_df$n_tested[i], effect = round(summary_df$mean_effect[i], 3),
                direction = summary_df$direction[i]
            )
        })

        shifted <- summary_df[summary_df$n_sig > 0, ]
        shift_desc <- if (nrow(shifted) > 0) paste(paste0(shifted$group, ' (', shifted$direction, ')'), collapse = '; ') else 'none'
        compact_summary <- paste0(
            'user-supplied differential abundance: ', nrow(shifted), ' of ', nrow(summary_df),
            ' cell states shift significantly (', p_col, '<', alpha, '): ', shift_desc
        )

        # a differential-abundance test with no significant hits anywhere is
        # as likely to reflect an underpowered contrast as a true null; flag
        # it rather than silently reporting "nothing shifted"
        caveats <- list()
        total_sig <- sum(summary_df$n_sig)
        if (total_sig == 0) {
            caveats[[length(caveats) + 1]] <- 'underpowered_contrast'
        } else if (max(summary_df$n_sig) / total_sig > 0.6) {
            caveats[[length(caveats) + 1]] <- 'cell_state_imbalanced_across_condition'
        }

        list(result = summary_df, compact_summary = compact_summary, top_findings = top_findings, caveats = caveats)
    }
)

#' Import a user-supplied result table as a dataset fragment
#'
#' Dataset-scope analog of [import_fragment()], and the low-level constructor
#' behind a dataset-scoped [import_tool()] (e.g. `format = 'milo_da'`): turns
#' an already-computed compositional / differential-abundance result into a
#' validated [dataset_fragment()].
#'
#' @param type One of the supported `dataset_fragment` types: currently
#'   `'composition_summary'`.
#' @param result A tidy data.frame with the user's result table.
#' @param fragment_id Unique id within the `dataset_context`. Defaults to
#'   `paste0('imported::', type)`.
#' @param tool_id Tool id recorded on the fragment. Default
#'   `'import_dataset_fragment'`.
#' @param params Named list of column-name overrides (`group_col`,
#'   `effect_col`, `significance_col`) and options (`alpha`).
#' @param source_file Optional path to the file `result` was read from;
#'   recorded and content-hashed in provenance.
#' @param module_method Optional description of how the modules were built.
#' @return A `dataset_fragment` object.
#' @export
import_dataset_fragment <- function(type, result, fragment_id = NULL,
                                     tool_id = 'import_dataset_fragment', params = list(),
                                     source_file = NULL, module_method = NA_character_){
    norm <- .normalize_import(.import_dataset_normalizers, type, result, params, 'import_dataset_fragment')
    dataset_fragment(
        fragment_id = fragment_id %||% paste0('imported::', type),
        tool_id = tool_id,
        type = type,
        result = norm$result,
        compact_summary = norm$compact_summary,
        top_findings = norm$top_findings,
        caveats = norm$caveats %||% list(),
        provenance = .import_provenance(params, result, source_file, module_method)
    )
}

#---------------------------------------------------------
# import_tool(): format presets, file reading, per-module splitting
#---------------------------------------------------------

# known export formats: the fragment type and scope each maps to, its column
# names, and the columns that identify it for format = 'auto' (checked in
# order, most specific first, since hdWGCNA DME tables are Seurat-shaped)
.import_formats <- list(
    hdwgcna_dme = list(
        type = 'state_expression', scope = 'module',
        columns = list(group = 'group', effect = 'avg_log2FC', significance = 'p_val_adj'),
        detect = c('module', 'group', 'avg_log2FC', 'p_val_adj')
    ),
    seurat_markers = list(
        type = 'cross_condition_delta', scope = 'module',
        columns = list(feature = 'gene', effect = 'avg_log2FC', significance = 'p_val_adj'),
        detect = c('avg_log2FC', 'p_val_adj')
    ),
    enrichr = list(
        type = 'geneset_enrichment', scope = 'module',
        columns = list(term = 'Term', effect = 'Odds.Ratio', significance = 'Adjusted.P.value'),
        detect = c('Term', 'Adjusted.P.value')
    ),
    milo_da = list(
        type = 'composition_summary', scope = 'dataset',
        columns = list(group = 'celltype', effect = 'logFC', significance = 'SpatialFDR'),
        detect = 'SpatialFDR'
    )
)

.detect_import_format <- function(table){
    for (format in names(.import_formats)) {
        if (all(.import_formats[[format]]$detect %in% colnames(table))) return(format)
    }
    stop(
        "import_tool(format = 'auto') could not recognize the table's columns; ",
        'pass format = (one of ', paste(names(.import_formats), collapse = ', '), ') or type = with columns ='
    )
}

.read_import_table <- function(path){
    if (!file.exists(path)) stop('import file not found: ', path)
    if (grepl('\\.csv(\\.gz)?$', path, ignore.case = TRUE)) {
        utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    } else {
        utils::read.delim(path, stringsAsFactors = FALSE, check.names = FALSE)
    }
}

# columns = list(term = 'Term') is the user-facing spelling of the
# normalizers' term_col = 'Term'
.columns_to_params <- function(columns){
    if (length(columns) == 0) return(list())
    stats::setNames(columns, paste0(names(columns), '_col'))
}

# a genome-wide gene-level table (FindMarkers, DESeq2, edgeR) says something
# about a module only through the module's own genes
.module_gene_rows <- function(table, params, ctx){
    feature_col <- params$feature_col %||% 'gene'
    genes <- if (feature_col %in% colnames(table)) table[[feature_col]] else rownames(table)
    table[genes %in% gene_membership(ctx$ms, ctx$module_id)$gene_name, , drop = FALSE]
}

# FindAllMarkers output restricted to one module's genes, summarised per
# cluster: how much of the module each cluster's markers cover
.markers_by_cluster <- function(rows, params, alpha){
    effect_col <- params$effect_col %||% 'avg_log2FC'
    p_col <- params$significance_col %||% 'p_val_adj'
    summary_df <- do.call(rbind, lapply(split(rows, rows$cluster), function(cl){
        up <- cl[[effect_col]] > 0 & cl[[p_col]] < alpha
        data.frame(
            group = as.character(cl$cluster[1]),
            n_module_genes_up = sum(up, na.rm = TRUE),
            mean_log2FC = mean(cl[[effect_col]], na.rm = TRUE),
            min_padj = min(cl[[p_col]], na.rm = TRUE)
        )
    }))
    summary_df[order(-summary_df$n_module_genes_up, summary_df$min_padj), , drop = FALSE]
}

#' Bring an existing result table into the tool chain
#'
#' Wraps a table computed elsewhere (Seurat markers, hdWGCNA DMEs, Enrichr,
#' miloR, or any per-module table) as a tool for [run_evidence()], so it
#' needs no hand-written wrapper. A file is read and hashed once, when the
#' tool is built.
#'
#' How the table reaches each module:
#' * with `module_col`, the table is split by that column and each module
#'   gets its own rows; a module with no rows is skipped (and recorded);
#' * a gene-level table (`format = 'seurat_markers'`, or
#'   `type = 'cross_condition_delta'`) without `module_col` is treated as
#'   genome-wide and filtered to each module's genes. `FindAllMarkers` output
#'   (with a `cluster` column) is summarised per cluster: how many of the
#'   module's genes are significant markers of each cluster;
#' * a dataset-scoped import (`format = 'milo_da'`) runs once for the whole
#'   dataset.
#'
#' @param x A data.frame, or the path to a `.csv` / tab-delimited file.
#' @param format A known export format: `'seurat_markers'`, `'hdwgcna_dme'`,
#'   `'enrichr'`, `'milo_da'`, or `'auto'` to detect it from the column
#'   names. Sets the fragment type and the default `columns`.
#' @param type The fragment type, for a table that matches no `format`: one
#'   of the [import_fragment()] types, or `'composition_summary'` (dataset
#'   scope).
#' @param module_col Column holding the module id, to split the table by
#'   module.
#' @param columns Named list mapping the importer's column roles to your
#'   column names: `term`, `effect`, `significance`, `group`, `feature`,
#'   `signature`, `variable`, `n`, `overlap`, `jaccard`. Overrides the
#'   format's defaults.
#' @param id The fragment id and tool id. Defaults to `format`, else `type`;
#'   give two imports of the same type different ids.
#' @param scope `'module'` or `'dataset'`. Defaults to the format's scope, or
#'   `'dataset'` for a dataset fragment type.
#' @param ... Normalizer options, e.g. `alpha` (significance threshold,
#'   default 0.05) or `n_top`.
#' @return A `llegir_tool_spec`, for the `tools` list of [run_evidence()].
#' @examples
#' dme <- data.frame(
#'     module = c('module_a', 'module_a', 'module_b'), group = c('t1', 't2', 't1'),
#'     avg_log2FC = c(1.2, -0.3, 0.8), p_val_adj = c(0.001, 0.4, 0.02)
#' )
#' ms <- llegir_example_moduleset()
#' import_tool(dme, format = 'auto', module_col = 'module')
#' @export
import_tool <- function(x, format = NULL, type = NULL, module_col = NULL, columns = list(),
                        id = NULL, scope = NULL, ...){
    source_file <- if (is.character(x) && length(x) == 1) x else NULL
    table <- if (!is.null(source_file)) .read_import_table(source_file) else x
    if (!is.data.frame(table)) stop('import_tool() takes a data.frame or a file path')
    if (identical(format, 'auto')) format <- .detect_import_format(table)
    preset <- list()
    if (!is.null(format)) {
        preset <- .import_formats[[format]]
        if (is.null(preset)) stop('unknown import format: ', format, ' (known: ', paste(names(.import_formats), collapse = ', '), ')')
    }
    type <- type %||% preset$type
    if (is.null(type)) stop('import_tool() needs a format or a type')
    scope <- scope %||% preset$scope %||% if (type %in% names(.import_dataset_normalizers)) 'dataset' else 'module'
    if (!is.null(module_col) && !(module_col %in% colnames(table))) stop('module_col not found in the table: ', module_col)
    params <- c(.columns_to_params(utils::modifyList(preset$columns %||% list(), columns)), list(...))
    id <- id %||% format %||% type

    fn <- if (scope == 'dataset') {
        function(ctx){
            import_dataset_fragment(
                type, table, fragment_id = id, tool_id = id, params = params,
                source_file = source_file, module_method = ctx$module_method %||% NA_character_
            )
        }
    } else {
        function(ctx){
            rows <- table
            frag_type <- type
            frag_params <- params
            if (!is.null(module_col)) {
                rows <- rows[as.character(rows[[module_col]]) == ctx$module_id, , drop = FALSE]
            } else if (frag_type == 'cross_condition_delta') {
                rows <- .module_gene_rows(rows, params, ctx)
            }
            if (nrow(rows) == 0) return(NULL)
            if (frag_type == 'cross_condition_delta' && 'cluster' %in% colnames(rows)) {
                rows <- .markers_by_cluster(rows, params, alpha = params$alpha %||% 0.05)
                if (max(rows$n_module_genes_up) == 0) return(NULL)
                frag_type <- 'state_expression'
                frag_params <- list(group_col = 'group', effect_col = 'n_module_genes_up', significance_col = 'min_padj')
            }
            import_fragment(
                ctx$module_id, frag_type, rows, fragment_id = id, tool_id = id, params = frag_params,
                source_file = source_file, module_method = ctx$module_method %||% NA_character_
            )
        }
    }
    structure(
        list(id = id, fn = fn, params = list(), requires = character(0), scope = scope, accepts = character(0)),
        class = 'llegir_tool_spec'
    )
}
